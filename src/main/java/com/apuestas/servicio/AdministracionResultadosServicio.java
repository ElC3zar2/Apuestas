package com.apuestas.servicio;

import com.apuestas.dao.AdministracionResultadosDAO;
import com.apuestas.modelo.AdministracionResultadosModelos.*;
import com.apuestas.modelo.OperacionAdministracionResultados;
import java.sql.SQLException;
import java.util.*;

/** Valida estructura y rol; no encadena acciones ni reproduce transacciones o reglas deportivas. */
public class AdministracionResultadosServicio {
    private final AdministracionResultadosDAO dao;
    public AdministracionResultadosServicio() { this(new AdministracionResultadosDAO()); }
    public AdministracionResultadosServicio(AdministracionResultadosDAO dao) { this.dao=Objects.requireNonNull(dao); }
    public static void autorizar(OperacionAdministracionResultados op,int actor,String rol) {
        if(op==null) throw new IllegalArgumentException();
        if(actor<=0 || !("ADMINISTRADOR".equals(rol)
                ||(!op.soloAdministrador&&"OPERADOR_EVENTOS".equals(rol)))) throw new SecurityException();
    }
    /** Permisos exclusivamente de lectura; no modifica la autorizacion de los POST. */
    public com.apuestas.modelo.ConsultaResultadoEvento consultarPorEvento(int actor,String rol,Map<String,String[]> p)
            throws SQLException {
        if(actor<=0||!("ADMINISTRADOR".equals(rol)||"OPERADOR_EVENTOS".equals(rol)||"AUDITOR".equals(rol)))
            throw new SecurityException();
        if(p==null||p.size()!=1||!p.containsKey("idEvento"))throw new IllegalArgumentException();
        String[] valores=p.get("idEvento");
        if(valores==null||valores.length!=1||valores[0]==null||!valores[0].matches("[0-9]{1,10}"))
            throw new IllegalArgumentException();
        int evento=Integer.parseInt(valores[0]);if(evento<=0)throw new IllegalArgumentException();
        com.apuestas.modelo.ConsultaResultadoEvento consulta=dao.consultarPorEvento(evento);
        if(consulta==null)throw new NoSuchElementException();
        if(consulta.idEvento!=evento)throw new SQLException("Respuesta de consulta inconsistente.");
        return consulta;
    }

    public Resultado ejecutar(OperacionAdministracionResultados op,int actor,String rol,Map<String,String[]> parametros,String ip)
            throws SQLException {
        autorizar(op,actor,rol);
        if(parametros==null) throw new IllegalArgumentException();
        for(Map.Entry<String,String[]> e:parametros.entrySet())
            if(!op.parametros.contains(e.getKey())||e.getValue()==null||e.getValue().length!=1
                    ||e.getValue()[0]==null) throw new IllegalArgumentException();
        Solicitud solicitud=new Solicitud();
        for(String campo:op.parametros) {
            String[] valores=parametros.get(campo);
            String v=valores==null?null:valores[0];
            switch(campo) {
                case "idEvento":solicitud.idEvento=id(v);break;
                case "idResultadoEvento":solicitud.idResultadoEvento=id(v);break;
                case "idSeleccion":solicitud.idSeleccion=id(v);break;
                case "resultadoTexto":solicitud.resultadoTexto=texto(v,250,true);break;
                case "nuevoResultadoTexto":solicitud.nuevoResultadoTexto=texto(v,250,true);break;
                case "observacion":solicitud.observacion=texto(v,500,false);break;
                case "motivo":solicitud.motivo=texto(v,500,true);break;
                case "resultado":
                    solicitud.resultado=texto(v,20,true).toUpperCase(Locale.ROOT);
                    if(!Arrays.asList("GANADA","PERDIDA","ANULADA").contains(solicitud.resultado))
                        throw new IllegalArgumentException();
                    break;
                default:throw new IllegalArgumentException();
            }
        }
        return Objects.requireNonNull(dao.ejecutar(op,actor,solicitud,texto(ip,45,false)));
    }
    private static String texto(String v,int max,boolean requerido) {
        String limpio=v==null?null:v.trim();
        if(limpio!=null&&limpio.isEmpty()) limpio=null;
        if((requerido&&limpio==null)||(limpio!=null&&limpio.length()>max)) throw new IllegalArgumentException();
        return limpio;
    }
    private static Integer id(String v) {
        String limpio=texto(v,10,true);
        if(!limpio.matches("[0-9]+")) throw new IllegalArgumentException();
        int valor=Integer.parseInt(limpio);
        if(valor<=0) throw new IllegalArgumentException();
        return valor;
    }
}