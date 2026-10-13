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

    public CotizacionApuesta cotizarApuesta(String seleccionesJson, BigDecimal monto) throws SQLException {
        return cotizarApuesta(seleccionesJson, monto, null, null);
    }

    public CotizacionApuesta cotizarApuesta(String seleccionesJson, BigDecimal monto,
            Integer pronosticoA, Integer pronosticoB) throws SQLException {
        try(Connection c=obtenerConexion(); CallableStatement cs=c.prepareCall(
                "{call dbo.sp_CotizarApuesta(?, ?, ?, ?)}")) {
            cs.setString(1,seleccionesJson); cs.setBigDecimal(2,monto);
            pronostico(cs,3,pronosticoA); pronostico(cs,4,pronosticoB);
            CotizacionApuesta r=new CotizacionApuesta();
            try(ResultSet rs=resultadoCotizacion(cs,true,
                    "TipoBoleto,CantidadSelecciones,MontoApostado,ComisionServicioPorcentaje,ComisionServicio,TotalCargo,CuotaTotal,GananciaPotencial")) {
                if(!rs.next()) throw contratoApuesta();
                r.setTipoBoleto(dato(rs,"TipoBoleto",String.class,false));
                r.setCantidadSelecciones(dato(rs,"CantidadSelecciones",Integer.class,false));
                r.setMontoApostado(dato(rs,"MontoApostado",BigDecimal.class,false));
                r.setComisionServicioPorcentaje(dato(rs,"ComisionServicioPorcentaje",BigDecimal.class,false));
                r.setComisionServicio(dato(rs,"ComisionServicio",BigDecimal.class,false));
                r.setTotalCargo(dato(rs,"TotalCargo",BigDecimal.class,false));
                r.setCuotaTotal(dato(rs,"CuotaTotal",BigDecimal.class,false));
                r.setGananciaPotencial(dato(rs,"GananciaPotencial",BigDecimal.class,false));
                if(rs.next() || r.getCantidadSelecciones()<1 || r.getMontoApostado().compareTo(monto)!=0
                        || !r.getTipoBoleto().equals(r.getCantidadSelecciones()==1?"SIMPLE":"COMPUESTO")) throw contratoApuesta();
            }
            List<DetalleCotizacionApuesta> detalles=new ArrayList<>();
            java.util.Set<Integer> ids=new java.util.HashSet<>(), ordenes=new java.util.HashSet<>();
            try(ResultSet rs=resultadoCotizacion(cs,false,
                    "Orden,IdEvento,NombreEvento,IdMercado,NombreMercado,IdSeleccion,NombreSeleccion,IdCuota,Cuota")) {
                while(rs.next()) {
                    DetalleCotizacionApuesta d=new DetalleCotizacionApuesta();
                    d.setOrden(dato(rs,"Orden",Integer.class,false));
                    d.setIdEvento(dato(rs,"IdEvento",Integer.class,false));
                    d.setNombreEvento(dato(rs,"NombreEvento",String.class,false));
                    d.setIdMercado(dato(rs,"IdMercado",Integer.class,false));
                    d.setNombreMercado(dato(rs,"NombreMercado",String.class,false));
                    d.setIdSeleccion(dato(rs,"IdSeleccion",Integer.class,false));
                    d.setNombreSeleccion(dato(rs,"NombreSeleccion",String.class,false));
                    d.setIdCuota(dato(rs,"IdCuota",Integer.class,false));
                    d.setCuota(dato(rs,"Cuota",BigDecimal.class,false));
                    if(d.getIdEvento()<=0 || d.getIdMercado()<=0 || d.getIdSeleccion()<=0 || d.getIdCuota()<=0
                            || d.getOrden()<1 || d.getOrden()>r.getCantidadSelecciones()
                            || !ids.add(d.getIdSeleccion()) || !ordenes.add(d.getOrden())) throw contratoApuesta();
                    detalles.add(d);
                }
            }
            if(detalles.size()!=r.getCantidadSelecciones()) throw contratoApuesta();
            r.setDetalles(java.util.Collections.unmodifiableList(detalles));
            try(ResultSet rs=resultadoCotizacion(cs,false,
                    "TipoMercado,PronosticoA,PronosticoB,CuotaResultado,PremioResultadoPotencial,PremioExactoOMaximo")) {
                if(!rs.next()) throw contratoApuesta();
                r.setTipoMercado(dato(rs,"TipoMercado",String.class,false));
                r.setPronosticoA(dato(rs,"PronosticoA",Integer.class,true));
                r.setPronosticoB(dato(rs,"PronosticoB",Integer.class,true));
                r.setCuotaResultado(dato(rs,"CuotaResultado",BigDecimal.class,true));
                r.setPremioResultadoPotencial(dato(rs,"PremioResultadoPotencial",BigDecimal.class,true));
                r.setPremioExactoOMaximo(dato(rs,"PremioExactoOMaximo",BigDecimal.class,false));
                if(rs.next() || !java.util.Arrays.asList("CONVENCIONAL","MARCADOR_FINAL","PRIMERA_ANOTACION").contains(r.getTipoMercado())
                        || !java.util.Objects.equals(pronosticoA,r.getPronosticoA())
                        || !java.util.Objects.equals(pronosticoB,r.getPronosticoB())
                        || r.getPremioExactoOMaximo().compareTo(r.getGananciaPotencial())!=0) throw contratoApuesta();
                boolean marcador="MARCADOR_FINAL".equals(r.getTipoMercado());
                if(!"CONVENCIONAL".equals(r.getTipoMercado()) && r.getCantidadSelecciones()!=1) throw contratoApuesta();
                if(marcador) {
                    if(pronosticoA==null || pronosticoB==null || pronosticoA<0 || pronosticoB<0
                            || r.getCuotaResultado()==null || r.getPremioResultadoPotencial()==null
                            || r.getCuotaResultado().compareTo(BigDecimal.ONE)<=0
                            || r.getCuotaResultado().compareTo(r.getCuotaTotal())>=0) throw contratoApuesta();
                } else if(pronosticoA!=null || pronosticoB!=null || r.getCuotaResultado()!=null
                        || r.getPremioResultadoPotencial()!=null) throw contratoApuesta();
            }
            comprobarFinConsulta(cs); return r;
        }
    }

    private static SQLException contratoApuesta() { return new SQLException("Respuesta de apuesta inconsistente."); }
    private static <T> T dato(ResultSet rs,String columna,Class<T> tipo,boolean nullable) throws SQLException {
        Object valor=rs.getObject(columna);
        if(valor==null && nullable) return null;
        if(!tipo.isInstance(valor)) throw contratoApuesta(); return tipo.cast(valor);
    }
    private static void pronostico(CallableStatement cs,int posicion,Integer valor) throws SQLException {
        if(valor==null) cs.setNull(posicion,Types.INTEGER); else cs.setInt(posicion,valor);
    }
    private static ResultSet resultadoCotizacion(CallableStatement cs,boolean primero,String columnas) throws SQLException {
        boolean hay=primero?cs.execute():cs.getMoreResults();
        while(!hay && cs.getUpdateCount()!=-1) hay=cs.getMoreResults();
        if(!hay) throw contratoApuesta();
        ResultSet rs=cs.getResultSet(); if(rs==null) throw contratoApuesta();
        try {
            java.sql.ResultSetMetaData md=rs.getMetaData();
            java.util.Set<String> nombres=new java.util.HashSet<>();
            for(int n=1;n<=md.getColumnCount();n++) nombres.add(md.getColumnLabel(n));
            for(String columna:columnas.split(",")) if(!nombres.contains(columna)) throw contratoApuesta();
            return rs;
        } catch(SQLException | RuntimeException e) { rs.close(); throw contratoApuesta(); }
    }

    public ResultadoApuesta realizarApuesta(
            int idUsuario, String seleccionesJson, BigDecimal monto,
            UUID referenciaOperacion, String ipOrigen) throws SQLException {
        return realizarApuesta(idUsuario,seleccionesJson,monto,referenciaOperacion,ipOrigen,null,null);
    }

    public ResultadoApuesta realizarApuesta(int idUsuario,String seleccionesJson,BigDecimal monto,
            UUID referenciaOperacion,String ipOrigen,Integer pronosticoA,Integer pronosticoB) throws SQLException {
        try (Connection conexion = obtenerConexion();
             CallableStatement cs = conexion.prepareCall(
                     "{call dbo.sp_RealizarApuesta(?, ?, ?, ?, ?, ?, ?)}")) {
            cs.setInt(1, idUsuario);
            cs.setString(2, seleccionesJson);
            cs.setBigDecimal(3, monto);
            // Representacion explicita para UNIQUEIDENTIFIER en el driver SQL Server.
            cs.setString(4, referenciaOperacion.toString());
            establecerIp(cs, 5, ipOrigen);
            pronostico(cs,6,pronosticoA); pronostico(cs,7,pronosticoB);

            boolean hayResultado = cs.execute();
            while (!hayResultado && cs.getUpdateCount() != -1) {
                hayResultado = cs.getMoreResults();
            }
            if (!hayResultado) throw new SQLException("No se recibio el resultado de la apuesta.");

            ResultadoApuesta resultado = new ResultadoApuesta();
            try (ResultSet rs = cs.getResultSet()) {
                if (!rs.next()) throw new SQLException("No se recibio el boleto.");
                boolean idempotente = dato(rs,"SolicitudIdempotente",Boolean.class,false);
                resultado.setSolicitudIdempotente(idempotente);
                String referencia = rs.getString("ReferenciaOperacion");
                if (referencia == null
                        || !referenciaOperacion.toString().equalsIgnoreCase(referencia)) {
                    throw new SQLException("La referencia devuelta no coincide con la solicitud.");
                }
                resultado.setReferenciaOperacion(referencia);
                resultado.setIdBoleto(dato(rs,"IdBoleto",Integer.class,false));
                resultado.setCodigoBoleto(dato(rs,"CodigoBoleto",String.class,false));
                resultado.setTipoBoleto(dato(rs,"TipoBoleto",String.class,false));
                resultado.setMontoApostado(dato(rs,"MontoApostado",BigDecimal.class,false));
                resultado.setComisionServicio(dato(rs,"ComisionServicio",BigDecimal.class,false));
                resultado.setTotalCargo(dato(rs,"TotalCargo",BigDecimal.class,false));
                resultado.setCuotaTotal(dato(rs,"CuotaTotal",BigDecimal.class,false));
                resultado.setGananciaPotencial(dato(rs,"GananciaPotencial",BigDecimal.class,false));

                // La rama idempotente actual omite estas dos columnas.
                if (!idempotente || tieneColumna(rs, "CantidadSelecciones")) {
                    resultado.setCantidadSelecciones(dato(rs,"CantidadSelecciones",Integer.class,false));
                    if (resultado.getCantidadSelecciones() <= 0) {
                        throw new SQLException("Cantidad de selecciones invalida.");
                    }
                }
                if (!idempotente || tieneColumna(rs, "ComisionServicioPorcentaje")) {
                    resultado.setComisionServicioPorcentaje(
                            dato(rs,"ComisionServicioPorcentaje",BigDecimal.class,false));
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
            if(resultado.getMontoApostado().compareTo(monto)!=0
                    || !java.util.Arrays.asList("SIMPLE","COMPUESTO").contains(resultado.getTipoBoleto())
                    || (pronosticoA!=null && !"SIMPLE".equals(resultado.getTipoBoleto()))) throw contratoApuesta();
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