/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;

import com.apuestas.modelo.Boleto;
import com.apuestas.modelo.CotizacionApuesta;
import com.apuestas.modelo.DetalleBoleto;
import com.apuestas.modelo.DetalleCotizacionApuesta;
import com.apuestas.modelo.ResultadoApuesta;

import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 *
 * @author farfa
 */
public class ApuestaDAO {

    public CotizacionApuesta cotizarApuesta(
            String seleccionesJson,
            BigDecimal monto)
            throws SQLException {

        String sql =
                "{call dbo.sp_CotizarApuesta(?, ?)}";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             CallableStatement cs =
                     conexion.prepareCall(sql)) {

            cs.setString(
                    1,
                    seleccionesJson
            );

            cs.setBigDecimal(
                    2,
                    monto
            );

            boolean tieneResultados =
                    cs.execute();

            if (!tieneResultados) {
                throw new SQLException(
                        "El procedimiento sp_CotizarApuesta "
                        + "no devolvió la cotización."
                );
            }

            CotizacionApuesta cotizacion =
                    new CotizacionApuesta();

            try (ResultSet rs =
                         cs.getResultSet()) {

                if (!rs.next()) {
                    throw new SQLException(
                            "El procedimiento sp_CotizarApuesta "
                            + "no devolvió el resumen "
                            + "de la cotización."
                    );
                }

                cotizacion.setTipoBoleto(
                        rs.getString(
                                "TipoBoleto"
                        )
                );

                cotizacion.setCantidadSelecciones(
                        rs.getInt(
                                "CantidadSelecciones"
                        )
                );

                cotizacion.setMontoApostado(
                        rs.getBigDecimal(
                                "MontoApostado"
                        )
                );

                cotizacion.setComisionServicioPorcentaje(
                        rs.getBigDecimal(
                                "ComisionServicioPorcentaje"
                        )
                );

                cotizacion.setComisionServicio(
                        rs.getBigDecimal(
                                "ComisionServicio"
                        )
                );

                cotizacion.setTotalCargo(
                        rs.getBigDecimal(
                                "TotalCargo"
                        )
                );

                cotizacion.setCuotaTotal(
                        rs.getBigDecimal(
                                "CuotaTotal"
                        )
                );

                cotizacion.setGananciaPotencial(
                        rs.getBigDecimal(
                                "GananciaPotencial"
                        )
                );
            }

            boolean tieneDetalle =
                    cs.getMoreResults();

            List<DetalleCotizacionApuesta> detalles =
                    new ArrayList<>();

            if (tieneDetalle) {

                try (ResultSet rs =
                             cs.getResultSet()) {

                    while (rs.next()) {

                        DetalleCotizacionApuesta detalle =
                                new DetalleCotizacionApuesta();

                        detalle.setOrden(
                                rs.getInt(
                                        "Orden"
                                )
                        );

                        detalle.setIdEvento(
                                rs.getInt(
                                        "IdEvento"
                                )
                        );

                        detalle.setNombreEvento(
                                rs.getString(
                                        "NombreEvento"
                                )
                        );

                        detalle.setIdMercado(
                                rs.getInt(
                                        "IdMercado"
                                )
                        );

                        detalle.setNombreMercado(
                                rs.getString(
                                        "NombreMercado"
                                )
                        );

                        detalle.setIdSeleccion(
                                rs.getInt(
                                        "IdSeleccion"
                                )
                        );

                        detalle.setNombreSeleccion(
                                rs.getString(
                                        "NombreSeleccion"
                                )
                        );

                        detalle.setIdCuota(
                                rs.getInt(
                                        "IdCuota"
                                )
                        );

                        detalle.setCuota(
                                rs.getBigDecimal(
                                        "Cuota"
                                )
                        );

                        detalles.add(
                                detalle
                        );
                    }
                }
            }

            cotizacion.setDetalles(
                    detalles
            );

            return cotizacion;
        }
    }

    public ResultadoApuesta realizarApuesta(
            int idUsuario,
            String seleccionesJson,
            BigDecimal monto,
            UUID referenciaOperacion,
            String ipOrigen)
            throws SQLException {

        String sql =
                "{call dbo.sp_RealizarApuesta(?, ?, ?, ?, ?)}";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             CallableStatement cs =
                     conexion.prepareCall(sql)) {

            cs.setInt(
                    1,
                    idUsuario
            );

            cs.setString(
                    2,
                    seleccionesJson
            );

            cs.setBigDecimal(
                    3,
                    monto
            );

            cs.setObject(
                    4,
                    referenciaOperacion
            );

            establecerIp(
                    cs,
                    5,
                    ipOrigen
            );

            boolean tieneResultados =
                    cs.execute();

            if (!tieneResultados) {
                throw new SQLException(
                        "El procedimiento sp_RealizarApuesta "
                        + "no devolvió el boleto generado."
                );
            }

            try (ResultSet rs =
                         cs.getResultSet()) {

                if (rs.next()) {

                    ResultadoApuesta resultado =
                            new ResultadoApuesta();

                    resultado.setIdBoleto(
                            rs.getInt(
                                    "IdBoleto"
                            )
                    );

                    resultado.setCodigoBoleto(
                            rs.getString(
                                    "CodigoBoleto"
                            )
                    );

                    resultado.setTipoBoleto(
                            rs.getString(
                                    "TipoBoleto"
                            )
                    );

                    resultado.setCantidadSelecciones(
                            rs.getInt(
                                    "CantidadSelecciones"
                            )
                    );

                    resultado.setMontoApostado(
                            rs.getBigDecimal(
                                    "MontoApostado"
                            )
                    );

                    resultado.setComisionServicioPorcentaje(
                            rs.getBigDecimal(
                                    "ComisionServicioPorcentaje"
                            )
                    );

                    resultado.setComisionServicio(
                            rs.getBigDecimal(
                                    "ComisionServicio"
                            )
                    );

                    resultado.setTotalCargo(
                            rs.getBigDecimal(
                                    "TotalCargo"
                            )
                    );

                    resultado.setCuotaTotal(
                            rs.getBigDecimal(
                                    "CuotaTotal"
                            )
                    );

                    resultado.setGananciaPotencial(
                            rs.getBigDecimal(
                                    "GananciaPotencial"
                            )
                    );

                    return resultado;
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_RealizarApuesta "
                + "no devolvió el boleto generado."
        );
    }

    public Boleto obtenerBoleto(
            int idUsuarioSolicitante,
            Integer idBoleto,
            String codigoBoleto)
            throws SQLException {

        String sql =
                "{call dbo.sp_ObtenerBoleto(?, ?, ?)}";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             CallableStatement cs =
                     conexion.prepareCall(sql)) {

            cs.setInt(
                    1,
                    idUsuarioSolicitante
            );

            if (idBoleto != null) {

                cs.setInt(
                        2,
                        idBoleto
                );

            } else {

                cs.setNull(
                        2,
                        Types.INTEGER
                );
            }

            if (codigoBoleto != null
                    && !codigoBoleto.trim().isEmpty()) {

                cs.setString(
                        3,
                        codigoBoleto.trim()
                );

            } else {

                cs.setNull(
                        3,
                        Types.VARCHAR
                );
            }

            boolean tieneResultados =
                    cs.execute();

            if (!tieneResultados) {

                throw new SQLException(
                        "El procedimiento sp_ObtenerBoleto "
                        + "no devolvió el encabezado."
                );
            }

            Boleto boleto =
                    new Boleto();

            try (ResultSet rs =
                         cs.getResultSet()) {

                if (!rs.next()) {

                    throw new SQLException(
                            "El procedimiento sp_ObtenerBoleto "
                            + "no devolvió información "
                            + "del boleto."
                    );
                }

                boleto.setIdBoleto(
                        rs.getInt(
                                "IdBoleto"
                        )
                );

                boleto.setCodigoBoleto(
                        rs.getString(
                                "CodigoBoleto"
                        )
                );

                boleto.setIdUsuario(
                        rs.getInt(
                                "IdUsuario"
                        )
                );

                boleto.setCorreo(
                        rs.getString(
                                "Correo"
                        )
                );

                boleto.setTipoBoleto(
                        rs.getString(
                                "TipoBoleto"
                        )
                );

                boleto.setMontoApostado(
                        rs.getBigDecimal(
                                "MontoApostado"
                        )
                );

                boleto.setComisionServicio(
                        rs.getBigDecimal(
                                "ComisionServicio"
                        )
                );

                boleto.setTotalCargo(
                        rs.getBigDecimal(
                                "TotalCargo"
                        )
                );

                boleto.setCuotaTotal(
                        rs.getBigDecimal(
                                "CuotaTotal"
                        )
                );

                boleto.setGananciaPotencial(
                        rs.getBigDecimal(
                                "GananciaPotencial"
                        )
                );

                boleto.setResultado(
                        rs.getString(
                                "Resultado"
                        )
                );

                boleto.setEstadoBoleto(
                        rs.getString(
                                "EstadoBoleto"
                        )
                );

                Timestamp fechaCreacion =
                        rs.getTimestamp(
                                "FechaCreacion"
                        );

                if (fechaCreacion != null) {

                    boleto.setFechaCreacion(
                            fechaCreacion
                                    .toLocalDateTime()
                    );
                }

                Timestamp fechaLiquidacion =
                        rs.getTimestamp(
                                "FechaLiquidacion"
                        );

                if (fechaLiquidacion != null) {

                    boleto.setFechaLiquidacion(
                            fechaLiquidacion
                                    .toLocalDateTime()
                    );
                }

                boleto.setReferenciaOperacion(
                        rs.getString(
                                "ReferenciaOperacion"
                        )
                );
            }

            List<DetalleBoleto> detalles =
                    new ArrayList<>();

            if (cs.getMoreResults()) {

                try (ResultSet rs =
                             cs.getResultSet()) {

                    while (rs.next()) {

                        DetalleBoleto detalle =
                                new DetalleBoleto();

                        detalle.setIdDetalle(
                                rs.getInt(
                                        "IdDetalle"
                                )
                        );

                        detalle.setIdEvento(
                                rs.getInt(
                                        "IdEvento"
                                )
                        );

                        detalle.setEvento(
                                rs.getString(
                                        "Evento"
                                )
                        );

                        detalle.setIdMercado(
                                rs.getInt(
                                        "IdMercado"
                                )
                        );

                        detalle.setMercado(
                                rs.getString(
                                        "Mercado"
                                )
                        );

                        detalle.setIdSeleccion(
                                rs.getInt(
                                        "IdSeleccion"
                                )
                        );

                        detalle.setSeleccion(
                                rs.getString(
                                        "Seleccion"
                                )
                        );

                        detalle.setCuotaAplicada(
                                rs.getBigDecimal(
                                        "CuotaAplicada"
                                )
                        );

                        detalle.setResultado(
                                rs.getString(
                                        "Resultado"
                                )
                        );

                        detalles.add(
                                detalle
                        );
                    }
                }
            }

            boleto.setDetalles(
                    detalles
            );

            return boleto;
        }
    }

    private void establecerIp(
            CallableStatement cs,
            int parametro,
            String ipOrigen)
            throws SQLException {

        if (ipOrigen != null
                && !ipOrigen.trim().isEmpty()) {

            cs.setString(
                    parametro,
                    ipOrigen.trim()
            );

        } else {

            cs.setNull(
                    parametro,
                    Types.VARCHAR
            );
        }
    }
}