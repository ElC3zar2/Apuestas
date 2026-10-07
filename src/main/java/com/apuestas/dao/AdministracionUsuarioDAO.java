package com.apuestas.dao;
import com.apuestas.modelo.AdministracionUsuarioModelos.*;
import com.apuestas.modelo.OperacionAdministracionUsuario;
import java.sql.*;
import java.time.*;
import java.math.BigDecimal;
import java.util.*;

/** Solo SP oficiales; todos los recursos acotados por try-with-resources. */
public class AdministracionUsuarioDAO {
    protected Connection obtenerConexion() throws SQLException {return ConexionBD.obtenerConexion();}
    private static SQLException contrato(){return new SQLException("Respuesta administrativa inconsistente.");}
    private static boolean siguiente(CallableStatement cs,boolean primero)throws SQLException {
        boolean hay=primero?cs.execute():cs.getMoreResults();
        while(!hay && cs.getUpdateCount()!=-1)hay=cs.getMoreResults();
        return hay;
    }
    private static void fin(CallableStatement cs)throws SQLException {
        if(siguiente(cs,false)){try(ResultSet extra=cs.getResultSet()){throw contrato();}}
    }
    private static void requerido(CallableStatement cs,boolean primero)throws SQLException {
        if(!siguiente(cs,primero))throw contrato();
    }
    private static void unica(ResultSet rs)throws SQLException{if(!rs.next())throw contrato();}
    private static void ultima(ResultSet rs)throws SQLException{if(rs.next())throw contrato();}
    // getObject impide conversiones silenciosas (p. ej. DECIMAL 19.9 a INT 19).
    private static <T> T valor(ResultSet r,String c,boolean nullable,Class<T> tipo)throws SQLException {
        Object v=r.getObject(c);
        if(v==null&&nullable)return null;
        if(!tipo.isInstance(v))throw contrato();
        return tipo.cast(v);
    }
    private static Integer id(ResultSet r,String c,boolean nullable)throws SQLException {
        Integer v=valor(r,c,nullable,Integer.class);
        if(v!=null&&v<=0)throw contrato();return v;
    }
    private static String texto(ResultSet r,String c,boolean nullable)throws SQLException {
        String v=valor(r,c,nullable,String.class);
        if(!nullable&&v.trim().isEmpty())throw contrato();return v;
    }
    private static Boolean bit(ResultSet r,String c,boolean nullable)throws SQLException {
        return valor(r,c,nullable,Boolean.class);
    }
    private static LocalDateTime fecha(ResultSet r,String c,boolean nullable)throws SQLException {
        Timestamp v=valor(r,c,nullable,Timestamp.class);return v==null?null:v.toLocalDateTime();
    }
    private static LocalDate dia(ResultSet r,String c,boolean nullable)throws SQLException {
        java.sql.Date v=valor(r,c,nullable,java.sql.Date.class);return v==null?null:v.toLocalDate();
    }
    private static BigDecimal decimal(ResultSet r,String c,boolean nullable)throws SQLException {
        return valor(r,c,nullable,BigDecimal.class);
    }
    private static void cadena(CallableStatement cs,int i,String s)throws SQLException {
        if(s==null)cs.setNull(i,Types.VARCHAR);else cs.setString(i,s);
    }
    public List<Pendiente> pendientes(int actor,int cantidad)throws SQLException {
        try(Connection c=obtenerConexion();CallableStatement cs=c.prepareCall(
                "{call dbo.sp_ObtenerUsuariosPendientesVerificacion(?, ?)}")){
            cs.setInt(1,actor);cs.setInt(2,cantidad);requerido(cs,true);
            List<Pendiente> datos=new ArrayList<>();Set<Integer> ids=new HashSet<>();
            try(ResultSet rs=cs.getResultSet()){
                while(rs.next()){
                    Pendiente v=leerPendiente(rs);
                    if(!ids.add(v.idUsuario)||datos.size()>=cantidad)throw contrato();datos.add(v);
                }
            }
            fin(cs);return datos;
        }
    }
    public Detalle detalle(int actor,int objetivo)throws SQLException {
        try(Connection c=obtenerConexion();CallableStatement cs=c.prepareCall(
                "{call dbo.sp_ObtenerDetalleAdministrativoUsuario(?, ?)}")){
            cs.setInt(1,actor);cs.setInt(2,objetivo);requerido(cs,true);
            Detalle d=new Detalle();
            try(ResultSet rs=cs.getResultSet()){
                unica(rs);d.usuario=leerCuenta(rs);ultima(rs);
                if(d.usuario.idUsuario!=objetivo || !"USUARIO".equals(d.usuario.rol))throw contrato();
            }
            requerido(cs,false);d.verificaciones=new ArrayList<>();Set<Integer> ids=new HashSet<>();
            try(ResultSet rs=cs.getResultSet()){
                while(rs.next()){Verificacion v=leerVerificacion(rs);if(!ids.add(v.idVerificacion))throw contrato();d.verificaciones.add(v);}
            }
            requerido(cs,false);d.restricciones=new ArrayList<>();ids.clear();
            try(ResultSet rs=cs.getResultSet()){
                while(rs.next()){Restriccion v=leerRestriccion(rs);if(!ids.add(v.idRestriccion))throw contrato();d.restricciones.add(v);}
            }
            fin(cs);return d;
        }
    }
    public ResultadoAccion accion(OperacionAdministracionUsuario op,int actor,int objetivo,
            String texto,String clasificacion,LocalDateTime fechaFin,String ip)throws SQLException {
        if(op==null||op.lectura())throw new IllegalArgumentException();
        String marcadores=op==OperacionAdministracionUsuario.AGREGAR?"?, ?, ?, ?, ?, ?":
                op==OperacionAdministracionUsuario.ESTADO?"?, ?, ?, ?, ?":"?, ?, ?, ?";
        try(Connection c=obtenerConexion();CallableStatement cs=c.prepareCall(
                "{call dbo."+op.procedimiento+"("+marcadores+")}")){
            cs.setInt(1,actor);cs.setInt(2,objetivo);
            if(op==OperacionAdministracionUsuario.AGREGAR){
                cadena(cs,3,clasificacion);cadena(cs,4,texto);
                if(fechaFin==null)cs.setNull(5,Types.TIMESTAMP);else cs.setTimestamp(5,Timestamp.valueOf(fechaFin));
                cadena(cs,6,ip);
            }else if(op==OperacionAdministracionUsuario.ESTADO){
                cadena(cs,3,clasificacion);cadena(cs,4,texto);cadena(cs,5,ip);
            }else{cadena(cs,3,texto);cadena(cs,4,ip);}
            requerido(cs,true);ResultadoAccion r;
            try(ResultSet rs=cs.getResultSet()){
                unica(rs);
                switch(op){
                    case INICIAR: {
                        Revision v=leerRevision(rs);
                        if(v.idVerificacion!=objetivo||!"EN_REVISION".equals(v.estadoVerificacion))throw contrato();r=v;break;
                    }
                    case APROBAR: {
                        Aprobacion v=leerAprobacion(rs);
                        if(v.idVerificacion!=objetivo||!"APROBADA".equals(v.estadoVerificacion))throw contrato();r=v;break;
                    }
                    case RECHAZAR: {
                        Rechazo v=leerRechazo(rs);
                        if(v.idVerificacion!=objetivo||!"RECHAZADA".equals(v.estadoVerificacion))throw contrato();r=v;break;
                    }
                    case REABRIR: {
                        Reapertura v=leerReapertura(rs);
                        if(v.idUsuario!=objetivo||!"PENDIENTE".equals(v.estadoVerificacion))throw contrato();r=v;break;
                    }
                    case ESTADO: {
                        CambioEstado v=leerCambioEstado(rs);
                        if(v.idUsuario!=objetivo||!Objects.equals(clasificacion,v.estadoActual))throw contrato();r=v;break;
                    }
                    case AGREGAR: {
                        RestriccionAgregada v=leerRestriccionAgregada(rs);
                        if(v.idUsuario!=objetivo||!v.activa||!Objects.equals(clasificacion,v.tipoRestriccion)
                                ||!Objects.equals(texto,v.motivo)||!Objects.equals(fechaFin,v.fechaFin))throw contrato();r=v;break;
                    }
                    case LEVANTAR: {
                        RestriccionLevantada v=leerRestriccionLevantada(rs);
                        if(v.idRestriccion!=objetivo||v.activa)throw contrato();r=v;break;
                    }
                    default:throw contrato();
                }
                ultima(rs);
            }
            fin(cs);return r;
        }
    }
 private static Cuenta leerCuenta(ResultSet rs) throws SQLException {
  Cuenta v=new Cuenta();
  v.idUsuario=id(rs,"IdUsuario",false);
  v.correo=texto(rs,"Correo",false);
  v.correoVerificado=bit(rs,"CorreoVerificado",false);
  v.fechaRegistro=fecha(rs,"FechaRegistro",false);
  v.rol=texto(rs,"Rol",false);
  v.estadoUsuario=texto(rs,"EstadoUsuario",false);
  v.nombreEstadoUsuario=texto(rs,"NombreEstadoUsuario",false);
  v.nombre=texto(rs,"Nombre",true);
  v.apellido=texto(rs,"Apellido",true);
  v.fechaNacimiento=dia(rs,"FechaNacimiento",true);
  v.genero=texto(rs,"Genero",true);
  v.telefono=texto(rs,"Telefono",true);
  v.tipoDocumento=texto(rs,"TipoDocumento",true);
  v.numeroDocumento=texto(rs,"NumeroDocumento",true);
  v.idPais=id(rs,"IdPais",true);
  v.codigoISO2=texto(rs,"CodigoISO2",true);
  v.pais=texto(rs,"Pais",true);
  v.idDepartamento=id(rs,"IdDepartamento",true);
  v.departamento=texto(rs,"Departamento",true);
  v.idMunicipio=id(rs,"IdMunicipio",true);
  v.municipio=texto(rs,"Municipio",true);
  v.ciudadExterior=texto(rs,"CiudadExterior",true);
  v.direccion=texto(rs,"Direccion",true);
  v.fechaActualizacion=fecha(rs,"FechaActualizacion",true);
  v.idBilletera=id(rs,"IdBilletera",true);
  v.saldoDisponible=decimal(rs,"SaldoDisponible",true);
  v.saldoComprometido=decimal(rs,"SaldoComprometido",true);
  v.saldoVirtualTotal=decimal(rs,"SaldoVirtualTotal",false);
  return v; }
 private static Pendiente leerPendiente(ResultSet rs) throws SQLException {
  Pendiente v=new Pendiente();
  v.idUsuario=id(rs,"IdUsuario",false);
  v.correo=texto(rs,"Correo",false);
  v.correoVerificado=bit(rs,"CorreoVerificado",false);
  v.estadoUsuario=texto(rs,"EstadoUsuario",false);
  v.nombre=texto(rs,"Nombre",false);
  v.apellido=texto(rs,"Apellido",false);
  v.fechaNacimiento=dia(rs,"FechaNacimiento",false);
  v.tipoDocumento=texto(rs,"TipoDocumento",false);
  v.numeroDocumento=texto(rs,"NumeroDocumento",false);
  v.codigoISO2=texto(rs,"CodigoISO2",false);
  v.pais=texto(rs,"Pais",false);
  v.departamento=texto(rs,"Departamento",true);
  v.municipio=texto(rs,"Municipio",true);
  v.ciudadExterior=texto(rs,"CiudadExterior",true);
  v.direccion=texto(rs,"Direccion",false);
  v.idVerificacion=id(rs,"IdVerificacion",false);
  v.estadoVerificacion=texto(rs,"EstadoVerificacion",false);
  v.fechaSolicitud=fecha(rs,"FechaSolicitud",false);
  v.fechaInicioRevision=fecha(rs,"FechaInicioRevision",true);
  v.idUsuarioRevisor=id(rs,"IdUsuarioRevisor",true);
  v.usuarioRevisor=texto(rs,"UsuarioRevisor",true);
  return v; }
 private static Verificacion leerVerificacion(ResultSet rs) throws SQLException {
  Verificacion v=new Verificacion();
  v.idVerificacion=id(rs,"IdVerificacion",false);
  v.estadoVerificacion=texto(rs,"EstadoVerificacion",false);
  v.nombreEstadoVerificacion=texto(rs,"NombreEstadoVerificacion",false);
  v.fechaSolicitud=fecha(rs,"FechaSolicitud",false);
  v.fechaInicioRevision=fecha(rs,"FechaInicioRevision",true);
  v.fechaResolucion=fecha(rs,"FechaResolucion",true);
  v.idUsuarioRevisor=id(rs,"IdUsuarioRevisor",true);
  v.usuarioRevisor=texto(rs,"UsuarioRevisor",true);
  v.observacion=texto(rs,"Observacion",true);
  return v; }
 private static Restriccion leerRestriccion(ResultSet rs) throws SQLException {
  Restriccion v=new Restriccion();
  v.idRestriccion=id(rs,"IdRestriccion",false);
  v.tipoRestriccion=texto(rs,"TipoRestriccion",false);
  v.motivo=texto(rs,"Motivo",false);
  v.fechaInicio=fecha(rs,"FechaInicio",false);
  v.fechaFin=fecha(rs,"FechaFin",true);
  v.activa=bit(rs,"Activa",false);
  v.fechaRegistro=fecha(rs,"FechaRegistro",false);
  v.idUsuarioRegistro=id(rs,"IdUsuarioRegistro",false);
  v.usuarioRegistro=texto(rs,"UsuarioRegistro",false);
  v.vigente=bit(rs,"Vigente",false);
  return v; }
 private static Revision leerRevision(ResultSet rs) throws SQLException {
  Revision v=new Revision();
  v.idUsuario=id(rs,"IdUsuario",false);
  v.idVerificacion=id(rs,"IdVerificacion",false);
  v.estadoVerificacion=texto(rs,"EstadoVerificacion",false);
  v.sinCambios=bit(rs,"SinCambios",false);
  return v; }
 private static Aprobacion leerAprobacion(ResultSet rs) throws SQLException {
  Aprobacion v=new Aprobacion();
  v.idUsuario=id(rs,"IdUsuario",false);
  v.idVerificacion=id(rs,"IdVerificacion",false);
  v.estadoVerificacion=texto(rs,"EstadoVerificacion",false);
  v.estadoUsuario=texto(rs,"EstadoUsuario",false);
  v.correoVerificado=bit(rs,"CorreoVerificado",false);
  v.sinCambios=bit(rs,"SinCambios",false);
  return v; }
 private static Rechazo leerRechazo(ResultSet rs) throws SQLException {
  Rechazo v=new Rechazo();
  v.idUsuario=id(rs,"IdUsuario",false);
  v.idVerificacion=id(rs,"IdVerificacion",false);
  v.estadoVerificacion=texto(rs,"EstadoVerificacion",false);
  v.estadoUsuario=texto(rs,"EstadoUsuario",false);
  v.sinCambios=bit(rs,"SinCambios",false);
  return v; }
 private static Reapertura leerReapertura(ResultSet rs) throws SQLException {
  Reapertura v=new Reapertura();
  v.idUsuario=id(rs,"IdUsuario",false);
  v.idVerificacion=id(rs,"IdVerificacion",false);
  v.estadoVerificacion=texto(rs,"EstadoVerificacion",false);
  return v; }
 private static CambioEstado leerCambioEstado(ResultSet rs) throws SQLException {
  CambioEstado v=new CambioEstado();
  v.idUsuario=id(rs,"IdUsuario",false);
  v.estadoAnterior=texto(rs,"EstadoAnterior",false);
  v.estadoActual=texto(rs,"EstadoActual",false);
  v.sinCambios=bit(rs,"SinCambios",false);
  return v; }
 private static RestriccionAgregada leerRestriccionAgregada(ResultSet rs) throws SQLException {
  RestriccionAgregada v=new RestriccionAgregada();
  v.idUsuario=id(rs,"IdUsuario",false);
  v.idRestriccion=id(rs,"IdRestriccion",false);
  v.tipoRestriccion=texto(rs,"TipoRestriccion",false);
  v.motivo=texto(rs,"Motivo",false);
  v.fechaFin=fecha(rs,"FechaFin",true);
  v.activa=bit(rs,"Activa",false);
  return v; }
 private static RestriccionLevantada leerRestriccionLevantada(ResultSet rs) throws SQLException {
  RestriccionLevantada v=new RestriccionLevantada();
  v.idUsuario=id(rs,"IdUsuario",false);
  v.idRestriccion=id(rs,"IdRestriccion",false);
  v.tipoRestriccion=texto(rs,"TipoRestriccion",false);
  v.activa=bit(rs,"Activa",false);
  v.sinCambios=bit(rs,"SinCambios",false);
  return v; }
}