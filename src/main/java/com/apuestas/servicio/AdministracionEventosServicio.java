package com.apuestas.servicio;

import com.apuestas.dao.AdministracionEventosDAO;
import com.apuestas.modelo.AdministracionEventosModelos.*;
import com.apuestas.modelo.OperacionAdministracionEventos;
import java.math.BigDecimal;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.*;

/** Primera barrera de permisos y estructura; SQL conserva transiciones, auditoria e historico. */
public class AdministracionEventosServicio {
    private final AdministracionEventosDAO dao;
    public AdministracionEventosServicio() { this(new AdministracionEventosDAO()); }
    public AdministracionEventosServicio(AdministracionEventosDAO dao) { this.dao=Objects.requireNonNull(dao); }
    public static void autorizar(int actor,String rol) {
        if(actor<=0 || !("ADMINISTRADOR".equals(rol)||"OPERADOR_EVENTOS".equals(rol)))
            throw new SecurityException();
    }
    public Resultado ejecutar(OperacionAdministracionEventos op,int actor,String rol,Map<String,String[]> parametros,String ip)
            throws SQLException {
        autorizar(actor,rol);
        if(op==null || parametros==null) throw new IllegalArgumentException();
        for(Map.Entry<String,String[]> e:parametros.entrySet())
            if(!op.parametros.contains(e.getKey()) || e.getValue()==null || e.getValue().length!=1
                    || e.getValue()[0]==null) throw new IllegalArgumentException();
        Solicitud s=new Solicitud();
        for(String campo:op.parametros) {
            String[] valores=parametros.get(campo);
            String v=valores==null?null:valores[0];
            switch(campo) {
                case "idDeporte":s.idDeporte=id(v,false);break;
                case "idLiga":s.idLiga=id(v,false);break;
                case "idPais":s.idPais=id(v,true);break;
                case "idParticipante":s.idParticipante=id(v,false);break;
                case "idEvento":s.idEvento=id(v,false);break;
                case "idMercado":s.idMercado=id(v,false);break;
                case "idSeleccion":s.idSeleccion=id(v,false);break;
                case "ordenParticipante":
                    s.ordenParticipante=id(v,false);
                    if(s.ordenParticipante>255) throw new IllegalArgumentException();break;
                case "nombre":s.nombre=texto(v,op==OperacionAdministracionEventos.CREAR_EVENTO
                        || op==OperacionAdministracionEventos.ACTUALIZAR_EVENTO?200:150,true);break;
                case "descripcion":s.descripcion=texto(v,250,false);break;
                case "motivo":s.motivo=texto(v,250,false);break;
                case "tipoParticipante":
                    s.tipoParticipante=texto(v,30,true).toUpperCase(Locale.ROOT);
                    if(!Arrays.asList("EQUIPO","ATLETA").contains(s.tipoParticipante)) throw new IllegalArgumentException();break;
                case "nuevoEstado":
                    s.nuevoEstado=texto(v,40,true).toUpperCase(Locale.ROOT);
                    Set<String> estados=op==OperacionAdministracionEventos.ESTADO_EVENTO?
                            estadosEvento():estadosMercado();
                    if(!estados.contains(s.nuevoEstado)) throw new IllegalArgumentException();break;
                case "activo":s.activo=bit(v,false);break;
                case "esLocal":s.esLocal=bit(v,true);break;
                case "fechaInicio":s.fechaInicio=fecha(v,false);break;
                case "fechaFin":s.fechaFin=fecha(v,true);break;
                case "valor":
                    String decimal=texto(v,32,true);
                    if(!decimal.matches("[0-9]+(\\.[0-9]{1,4})?")) throw new IllegalArgumentException();
                    s.valor=new BigDecimal(decimal);
                    if(s.valor.compareTo(BigDecimal.ONE)<=0 || s.valor.compareTo(new BigDecimal("999999.9999"))>0)
                        throw new IllegalArgumentException();break;
                default:throw new IllegalArgumentException();
            }
        }
        return Objects.requireNonNull(dao.ejecutar(op,actor,s,texto(ip,45,false)));
    }
    public static Set<String> estadosEvento() {
        return Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
                "BORRADOR","PROGRAMADO","EN_VIVO","SUSPENDIDO","PENDIENTE_RESULTADO","FINALIZADO","CANCELADO")));
    }
    public static Set<String> estadosMercado() {
        return Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
                "BORRADOR","ABIERTO","SUSPENDIDO","CERRADO","LIQUIDADO","ANULADO")));
    }
    private static String texto(String v,int max,boolean requerido) {
        String limpio=v==null?null:v.trim();
        if(limpio!=null&&limpio.isEmpty()) limpio=null;
        if((requerido&&limpio==null)||(limpio!=null&&limpio.length()>max)) throw new IllegalArgumentException();
        return limpio;
    }
    private static Integer id(String v,boolean nullable) {
        String limpio=texto(v,10,!nullable);
        if(limpio==null) return null;
        if(!limpio.matches("[0-9]+")) throw new IllegalArgumentException();
        int id=Integer.parseInt(limpio);
        if(id<=0) throw new IllegalArgumentException();
        return id;
    }
    private static Boolean bit(String v,boolean nullable) {
        String limpio=texto(v,5,!nullable);
        if(limpio==null) return null;
        if("true".equals(limpio)||"1".equals(limpio)) return true;
        if("false".equals(limpio)||"0".equals(limpio)) return false;
        throw new IllegalArgumentException();
    }
    private static LocalDateTime fecha(String v,boolean nullable) {
        String limpio=texto(v,27,!nullable);
        if(limpio==null) return null;
        if(!limpio.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{1,7})?"))
            throw new IllegalArgumentException();
        LocalDateTime fecha=LocalDateTime.parse(limpio);
        if(fecha.getYear()<1) throw new IllegalArgumentException();
        return fecha;
    }
}