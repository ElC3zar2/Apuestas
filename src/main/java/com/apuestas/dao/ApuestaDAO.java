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
                     obtenerConexion();
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
                if (rs.next()) throw new SQLException("Cotizacion duplicada.");
            }

            boolean tieneDetalle =
                    cs.getMoreResults();

            List<DetalleCotizacionApuesta> detalles =
                    new ArrayList<>();

            if (!tieneDetalle) throw new SQLException("Falta el detalle de cotizacion.");
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

            comprobarFinConsulta(cs);
            return cotizacion;
        }
    }

    public ResultadoApuesta realizarApuesta(
            int idUsuario, String seleccionesJson, BigDecimal monto,
            UUID referenciaOperacion, String ipOrigen) throws SQLException {
        try (Connection conexion = obtenerConexion();
             CallableStatement cs = conexion.prepareCall(
                     "{call dbo.sp_RealizarApuesta(?, ?, ?, ?, ?)}")) {
            cs.setInt(1, idUsuario);
            cs.setString(2, seleccionesJson);
            cs.setBigDecimal(3, monto);
            // Representacion explicita para UNIQUEIDENTIFIER en el driver SQL Server.
            cs.setString(4, referenciaOperacion.toString());
            establecerIp(cs, 5, ipOrigen);

            boolean hayResultado = cs.execute();
            while (!hayResultado && cs.getUpdateCount() != -1) {
                hayResultado = cs.getMoreResults();
            }
            if (!hayResultado) throw new SQLException("No se recibio el resultado de la apuesta.");

            ResultadoApuesta resultado = new ResultadoApuesta();
            try (ResultSet rs = cs.getResultSet()) {
                if (!rs.next()) throw new SQLException("No se recibio el boleto.");
                boolean idempotente = rs.getBoolean("SolicitudIdempotente");
                if (rs.wasNull()) throw new SQLException("Falta el indicador de idempotencia.");
                resultado.setSolicitudIdempotente(idempotente);
                String referencia = rs.getString("ReferenciaOperacion");
                if (referencia == null
                        || !referenciaOperacion.toString().equalsIgnoreCase(referencia)) {
                    throw new SQLException("La referencia devuelta no coincide con la solicitud.");
                }
                resultado.setReferenciaOperacion(referencia);
                resultado.setIdBoleto(rs.getInt("IdBoleto"));
                resultado.setCodigoBoleto(rs.getString("CodigoBoleto"));
                resultado.setTipoBoleto(rs.getString("TipoBoleto"));
                resultado.setMontoApostado(rs.getBigDecimal("MontoApostado"));
                resultado.setComisionServicio(rs.getBigDecimal("ComisionServicio"));
                resultado.setTotalCargo(rs.getBigDecimal("TotalCargo"));
                resultado.setCuotaTotal(rs.getBigDecimal("CuotaTotal"));
                resultado.setGananciaPotencial(rs.getBigDecimal("GananciaPotencial"));

                // La rama idempotente actual omite estas dos columnas.
                if (!idempotente || tieneColumna(rs, "CantidadSelecciones")) {
                    resultado.setCantidadSelecciones(rs.getInt("CantidadSelecciones"));
                    if (rs.wasNull() || resultado.getCantidadSelecciones() <= 0) {
                        throw new SQLException("Cantidad de selecciones invalida.");
                    }
                }
                if (!idempotente || tieneColumna(rs, "ComisionServicioPorcentaje")) {
                    resultado.setComisionServicioPorcentaje(
                            rs.getBigDecimal("ComisionServicioPorcentaje"));
                    if (resultado.getComisionServicioPorcentaje() == null) {
                        throw new SQLException("Porcentaje de comision nulo.");
                    }
                }
                if (resultado.getIdBoleto() <= 0 || resultado.getCodigoBoleto() == null
                        || resultado.getTipoBoleto() == null || resultado.getMontoApostado() == null
                        || resultado.getComisionServicio() == null || resultado.getTotalCargo() == null
                        || resultado.getCuotaTotal() == null || resultado.getGananciaPotencial() == null) {
                    throw new SQLException("Resultado de apuesta incompleto.");
                }
                if (rs.next()) throw new SQLException("Se recibieron varios boletos.");
            }
            boolean adicional = cs.getMoreResults();
            while (adicional || cs.getUpdateCount() != -1) {
                if (adicional) throw new SQLException("Resultado adicional inesperado.");
                adicional = cs.getMoreResults();
            }
            return resultado;
        }
    }

    protected Connection obtenerConexion() throws SQLException {
        return ConexionBD.obtenerConexion();
    }

    private boolean tieneColumna(ResultSet rs, String nombre) throws SQLException {
        java.sql.ResultSetMetaData metadata = rs.getMetaData();
        for (int i = 1; i <= metadata.getColumnCount(); i++) {
            if (nombre.equalsIgnoreCase(metadata.getColumnLabel(i))) return true;
        }
        return false;
    }

    public Boleto obtenerBoleto(
            int idUsuarioSolicitante,
            Integer idBoleto,
            String codigoBoleto)
            throws SQLException {

        String sql =
                "{call dbo.sp_ObtenerBoleto(?, ?, ?)}";

        try (Connection conexion =
                     obtenerConexion();
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
                if (rs.next()) throw new SQLException("Encabezado de boleto duplicado.");
            }

            List<DetalleBoleto> detalles =
                    new ArrayList<>();

            if (!cs.getMoreResults()) throw new SQLException("Falta el detalle del boleto.");
            {

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

            comprobarFinConsulta(cs);
            return boleto;
        }
    }

    private void comprobarFinConsulta(CallableStatement cs) throws SQLException {
        boolean resultado = cs.getMoreResults();
        while (resultado || cs.getUpdateCount() != -1) {
            if (resultado) {
                try (ResultSet adicional = cs.getResultSet()) {
                    throw new SQLException("Resultado adicional inesperado.");
                }
            }
            resultado = cs.getMoreResults();
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