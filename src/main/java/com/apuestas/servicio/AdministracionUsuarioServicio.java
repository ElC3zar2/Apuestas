package com.apuestas.servicio;

import com.apuestas.dao.AdministracionUsuarioDAO;
import com.apuestas.modelo.AdministracionUsuarioModelos.*;
import com.apuestas.modelo.OperacionAdministracionUsuario;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.*;

/** Validaciones estructurales y primera barrera de permisos; transiciones solo en SQL. */
public class AdministracionUsuarioServicio {
    private final AdministracionUsuarioDAO dao;
    public AdministracionUsuarioServicio(){this(new AdministracionUsuarioDAO());}
    public AdministracionUsuarioServicio(AdministracionUsuarioDAO dao){this.dao=Objects.requireNonNull(dao);}
    public static void autorizar(int actor,String rol,boolean lectura){
        if(actor<=0||!("ADMINISTRADOR".equals(rol)||(lectura&&"AUDITOR".equals(rol))))
            throw new SecurityException();
    }
    public List<Pendiente> pendientes(int actor,String rol,int cantidad)throws SQLException {
        autorizar(actor,rol,true);
        if(cantidad<1||cantidad>500)throw new IllegalArgumentException();
        return Objects.requireNonNull(dao.pendientes(actor,cantidad));
    }
    public Detalle detalle(int actor,String rol,int objetivo)throws SQLException {
        autorizar(actor,rol,true);positivo(objetivo);
        return Objects.requireNonNull(dao.detalle(actor,objetivo));
    }
    public ResultadoAccion accion(OperacionAdministracionUsuario op,int actor,String rol,int objetivo,
            String texto,String clasificacion,LocalDateTime fechaFin,String ip)throws SQLException {
        autorizar(actor,rol,false);positivo(objetivo);
        if(op==null||op.lectura())throw new IllegalArgumentException();
        texto=texto(texto,500,false);ip=texto(ip,45,false);
        if(op==OperacionAdministracionUsuario.ESTADO){
            clasificacion=codigo(clasificacion,40);
            if(!Arrays.asList("PENDIENTE","ACTIVO","SUSPENDIDO","CERRADO").contains(clasificacion))
                throw new IllegalArgumentException();
            if("SUSPENDIDO".equals(clasificacion)||"CERRADO".equals(clasificacion))texto=texto(texto,500,true);
        }else if(op==OperacionAdministracionUsuario.AGREGAR){
            clasificacion=codigo(clasificacion,30);
            if(!Arrays.asList("APOSTAR","TODAS_OPERACIONES").contains(clasificacion))throw new IllegalArgumentException();
            texto=texto(texto,500,true);
            if(fechaFin!=null&&(fechaFin.getYear()<1||fechaFin.getYear()>9999||fechaFin.getNano()%100!=0))
                throw new IllegalArgumentException();
        }else if(op==OperacionAdministracionUsuario.RECHAZAR||op==OperacionAdministracionUsuario.LEVANTAR){
            texto=texto(texto,500,true);
        }
        // La aprobacion aplica la habilitacion dentro del SP. No repetir sincronizacion ni UPDATE.
        return Objects.requireNonNull(dao.accion(op,actor,objetivo,texto,clasificacion,fechaFin,ip));
    }
    private static void positivo(int id){if(id<=0)throw new IllegalArgumentException();}
    private static String codigo(String s,int max){return texto(s,max,true).toUpperCase(Locale.ROOT);}
    private static String texto(String s,int max,boolean obligatorio){
        String limpio=s==null?null:s.trim();
        if(limpio!=null&&limpio.isEmpty())limpio=null;
        if((obligatorio&&limpio==null)||(limpio!=null&&limpio.length()>max))throw new IllegalArgumentException();
        return limpio;
    }
}