package com.apuestas.dao;

import com.apuestas.modelo.*;
import java.sql.*;
import java.math.BigDecimal;
import java.util.*;

/** Lectura estricta de los contratos de consulta de boletos y analitica. */
final class LecturaUsuarioSQL {
    private LecturaUsuarioSQL() { }
    static SQLException error() { return new SQLException("Respuesta de consulta inconsistente."); }
    static <T> T dato(ResultSet rs,String columna,Class<T> tipo,boolean nullable) throws SQLException {
        Object valor=rs.getObject(columna);
        if(valor==null) { if(nullable)return null; throw error(); }
        if(!tipo.isInstance(valor))throw error();
        return tipo.cast(valor);
    }
    static ResultSet resultado(CallableStatement cs,boolean primero,String columnas) throws SQLException {
        boolean hay=primero?cs.execute():cs.getMoreResults();
        while(!hay && cs.getUpdateCount()!=-1)hay=cs.getMoreResults();
        if(!hay)throw error();
        ResultSet rs=cs.getResultSet();
        try {
            columnas(rs,columnas);
            return rs;
        }catch(SQLException|RuntimeException e){rs.close();throw e;}
    }
    static void columnas(ResultSet rs,String columnas) throws SQLException {
        ResultSetMetaData md=rs.getMetaData();Set<String> nombres=new HashSet<>();
        for(int i=1;i<=md.getColumnCount();i++)nombres.add(md.getColumnLabel(i).toLowerCase(Locale.ROOT));
        for(String c:columnas.split(","))if(!nombres.contains(c.toLowerCase(Locale.ROOT)))throw error();
    }
    static final String MODALIDAD="TipoMercadoAplicado,PronosticoA,PronosticoB,CuotaResultadoAplicada,CuotaLiquidacion,ClasificacionAcierto,NombreEventoAplicado,NombreParticipanteAAplicado,NombreParticipanteBAplicado,NombreSeleccionAplicada";
    static void modalidad(ResultSet rs,DatosModalidadBoleto d) throws SQLException {
        d.setTipoMercadoAplicado(dato(rs,"TipoMercadoAplicado",String.class,false));
        if(!Arrays.asList("CONVENCIONAL","MARCADOR_FINAL","PRIMERA_ANOTACION").contains(d.getTipoMercadoAplicado()))throw error();
        d.setPronosticoA(dato(rs,"PronosticoA",Integer.class,true));
        d.setPronosticoB(dato(rs,"PronosticoB",Integer.class,true));
        d.setCuotaResultadoAplicada(dato(rs,"CuotaResultadoAplicada",BigDecimal.class,true));
        d.setCuotaLiquidacion(dato(rs,"CuotaLiquidacion",BigDecimal.class,true));
        d.setClasificacionAcierto(dato(rs,"ClasificacionAcierto",String.class,true));
        if(d.getClasificacionAcierto()!=null && !Arrays.asList("EXACTO","RESULTADO","PRIMERA_ANOTACION","NO_ACIERTO","ANULADO").contains(d.getClasificacionAcierto()))throw error();
        d.setNombreEventoAplicado(dato(rs,"NombreEventoAplicado",String.class,true));
        d.setNombreParticipanteAAplicado(dato(rs,"NombreParticipanteAAplicado",String.class,true));
        d.setNombreParticipanteBAplicado(dato(rs,"NombreParticipanteBAplicado",String.class,true));
        d.setNombreSeleccionAplicada(dato(rs,"NombreSeleccionAplicada",String.class,true));
        boolean marcador="MARCADOR_FINAL".equals(d.getTipoMercadoAplicado());
        if(marcador) {
            if(d.getPronosticoA()==null || d.getPronosticoB()==null || d.getPronosticoA()<0 || d.getPronosticoB()<0 || d.getCuotaResultadoAplicada()==null)throw error();
        }else if(d.getPronosticoA()!=null || d.getPronosticoB()!=null || d.getCuotaResultadoAplicada()!=null)throw error();
    }
    static List<MetricasModalidadUsuario> metricas(CallableStatement cs) throws SQLException {
        List<MetricasModalidadUsuario> lista=new ArrayList<>();Set<String> tipos=new HashSet<>();
        try(ResultSet rs=resultado(cs,false,"TipoMercadoAplicado,CantidadDetalles,MarcadoresExactos,AciertosResultado,AciertosPrimeraAnotacion")) {
            while(rs.next()) {
                String tipo=dato(rs,"TipoMercadoAplicado",String.class,false);
                long cantidad=dato(rs,"CantidadDetalles",Long.class,false);
                int exactos=dato(rs,"MarcadoresExactos",Integer.class,false),resultado=dato(rs,"AciertosResultado",Integer.class,false),primera=dato(rs,"AciertosPrimeraAnotacion",Integer.class,false);
                if(!Arrays.asList("CONVENCIONAL","MARCADOR_FINAL","PRIMERA_ANOTACION").contains(tipo) || !tipos.add(tipo) || cantidad<0 || exactos<0 || resultado<0 || primera<0)throw error();
                lista.add(new MetricasModalidadUsuario(tipo,cantidad,exactos,resultado,primera));
            }
        }return lista;
    }
}
