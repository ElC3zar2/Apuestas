package com.apuestas.controlador;

import java.sql.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.util.*;

/** Fixtures sinteticas: ninguna conexion ni escritura real. */
final class DatosPruebaConsultasUsuario {
    static Map<String,Object> modalidad(String tipo,String clasificacion) {
        Map<String,Object> f=new LinkedHashMap<>();boolean marcador="MARCADOR_FINAL".equals(tipo);
        f.put("TipoMercadoAplicado",tipo);f.put("PronosticoA",marcador?0:null);f.put("PronosticoB",marcador?2:null);
        f.put("CuotaResultadoAplicada",marcador?new BigDecimal("2.5000"):null);
        f.put("CuotaLiquidacion",clasificacion==null?null:new BigDecimal("1.0000"));
        f.put("ClasificacionAcierto",clasificacion);f.put("NombreEventoAplicado","Evento congelado");
        f.put("NombreParticipanteAAplicado","Participante A");f.put("NombreParticipanteBAplicado","Participante B");
        f.put("NombreSeleccionAplicada","Seleccion congelada");return f;
    }
    static Map<String,Object> metrica() {
        Map<String,Object> f=new LinkedHashMap<>();f.put("TipoMercadoAplicado","CONVENCIONAL");
        f.put("CantidadDetalles",8L);f.put("MarcadoresExactos",0);f.put("AciertosResultado",0);f.put("AciertosPrimeraAnotacion",0);return f;
    }
    static List<Map<String,Object>> historicos(List<Map<String,Object>> detalles,List<Map<String,Object>> boletos,int usuario) {
        List<Map<String,Object>> lista=new ArrayList<>();
        for(Map<String,Object> d:detalles) {
            Map<String,Object> f=new LinkedHashMap<>(d);f.remove("ProbabilidadImplicitaSeleccionPorcentaje");
            f.put("ResultadoDetalle",f.remove("ResultadoSeleccion"));f.put("IdUsuario",usuario);
            Object tipo="SIMPLE";for(Map<String,Object> b:boletos)if(Objects.equals(b.get("IdBoleto"),d.get("IdBoleto")))tipo=b.get("TipoBoleto");
            f.put("TipoBoleto",tipo);f.putAll(modalidad("CONVENCIONAL",null));f.put("DescripcionAcierto","Pendiente");lista.add(f);
        }return lista;
    }
    static ResultSetMetaData metadata(Collection<String> columnas) {
        List<String> lista=new ArrayList<>(columnas);
        return (ResultSetMetaData)Proxy.newProxyInstance(ResultSetMetaData.class.getClassLoader(),new Class<?>[]{ResultSetMetaData.class},(p,m,a)->{
            if(m.getName().equals("getColumnCount"))return lista.size();
            if(m.getName().equals("getColumnLabel"))return lista.get((Integer)a[0]-1);
            throw new AssertionError(m.getName());
        });
    }
}
