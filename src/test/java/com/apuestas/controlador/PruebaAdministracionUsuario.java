package com.apuestas.controlador;

import com.apuestas.dao.AdministracionUsuarioDAO;
import com.apuestas.modelo.OperacionAdministracionUsuario;
import com.apuestas.seguridad.ControlAccesoAdministrativo;
import com.apuestas.servicio.AdministracionUsuarioServicio;
import com.fasterxml.jackson.databind.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import javax.servlet.http.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;

/** Cada caso atraviesa HTTP -> servicio -> DAO real -> JDBC simulado. Sin red ni datos reales. */
public class PruebaAdministracionUsuario {
    private static int casos;
    private static final ObjectMapper JSON=new ObjectMapper();
    private static final String PRIVADO="SECRETO_SQL_PRIVADO";
    private static Map<String,Object> fila(Object... pares){
        Map<String,Object> r=new LinkedHashMap<>();
        for(int i=0;i<pares.length;i+=2)r.put((String)pares[i],pares[i+1]);return r;
    }
    private static Timestamp fecha(){return Timestamp.valueOf("2026-01-02 03:04:05");}
    private static Map<String,Object> pendiente(){
        return fila("IdUsuario",19,"Correo","cliente@example.test","CorreoVerificado",false,
                "EstadoUsuario","PENDIENTE","Nombre","Nombre","Apellido","Apellido",
                "FechaNacimiento",java.sql.Date.valueOf("1990-01-01"),"TipoDocumento","PASAPORTE","NumeroDocumento","LOCAL",
                "CodigoISO2","GT","Pais","Guatemala","Departamento",null,"Municipio",null,
                "CiudadExterior",null,"Direccion","Direccion","IdVerificacion",23,"EstadoVerificacion","PENDIENTE",
                "FechaSolicitud",fecha(),"FechaInicioRevision",null,"IdUsuarioRevisor",null,"UsuarioRevisor",null);
    }
    private static Map<String,Object> cuenta(){
        Map<String,Object> r=fila("IdUsuario",19,"Correo","cliente@example.test","CorreoVerificado",false,
                "FechaRegistro",fecha(),"Rol","USUARIO","EstadoUsuario","PENDIENTE","NombreEstadoUsuario","Pendiente",
                "SaldoVirtualTotal",BigDecimal.ZERO);
        for(String s:new String[]{"Nombre","Apellido","FechaNacimiento","Genero","Telefono","TipoDocumento",
                "NumeroDocumento","IdPais","CodigoISO2","Pais","IdDepartamento","Departamento","IdMunicipio",
                "Municipio","CiudadExterior","Direccion","FechaActualizacion","IdBilletera","SaldoDisponible","SaldoComprometido"})r.put(s,null);
        r.put("IntentosFallidos",5);r.put("BloqueadoHasta",fecha());r.put("UltimoAcceso",fecha());
        r.put("Contrasena",PRIVADO);r.put("Token",PRIVADO);return r;
    }
    private static Map<String,Object> verificacion(){
        return fila("IdVerificacion",23,"EstadoVerificacion","PENDIENTE","NombreEstadoVerificacion","Pendiente",
                "FechaSolicitud",fecha(),"FechaInicioRevision",null,"FechaResolucion",null,
                "IdUsuarioRevisor",null,"UsuarioRevisor",null,"Observacion",null);
    }
    private static Map<String,Object> restriccion(){
        return fila("IdRestriccion",29,"TipoRestriccion","APOSTAR","Motivo","Motivo","FechaInicio",fecha(),
                "FechaFin",null,"Activa",true,"FechaRegistro",fecha(),"IdUsuarioRegistro",7,
                "UsuarioRegistro","admin@example.test","Vigente",true);
    }
    private static Map<String,Object> resultado(OperacionAdministracionUsuario op){
        switch(op){
            case INICIAR:return fila("IdUsuario",19,"IdVerificacion",23,"EstadoVerificacion","EN_REVISION","SinCambios",false);
            case APROBAR:return fila("IdUsuario",19,"IdVerificacion",23,"EstadoVerificacion","APROBADA","EstadoUsuario","PENDIENTE","CorreoVerificado",false,"SinCambios",false);
            case RECHAZAR:return fila("IdUsuario",19,"IdVerificacion",23,"EstadoVerificacion","RECHAZADA","EstadoUsuario","PENDIENTE","SinCambios",false);
            case REABRIR:return fila("IdUsuario",19,"IdVerificacion",24,"EstadoVerificacion","PENDIENTE");
            case ESTADO:return fila("IdUsuario",19,"EstadoAnterior","PENDIENTE","EstadoActual","ACTIVO","SinCambios",false);
            case AGREGAR:return fila("IdUsuario",19,"IdRestriccion",29,"TipoRestriccion","APOSTAR","Motivo","Motivo","FechaFin",null,"Activa",true);
            case LEVANTAR:return fila("IdUsuario",19,"IdRestriccion",29,"TipoRestriccion","APOSTAR","Activa",false,"SinCambios",false);
            default:throw new AssertionError();
        }
    }
    static class Jdbc {
        final OperacionAdministracionUsuario op;
        List<List<Map<String,Object>>> resultados=new ArrayList<>();
        Map<Integer,Object> parametros=new LinkedHashMap<>();
        int llamadas,abiertos,cerrados,indice,codigo;boolean conexionCerrada,statementCerrado,runtime,conteo;
        Jdbc(OperacionAdministracionUsuario op){
            this.op=op;
            if(op==OperacionAdministracionUsuario.PENDIENTES)resultados.add(new ArrayList<>(Arrays.asList(pendiente())));
            else if(op==OperacionAdministracionUsuario.DETALLE){
                resultados.add(new ArrayList<>(Arrays.asList(cuenta())));
                resultados.add(new ArrayList<>(Arrays.asList(verificacion())));
                resultados.add(new ArrayList<>(Arrays.asList(restriccion())));
            }else resultados.add(new ArrayList<>(Arrays.asList(resultado(op))));
        }
        Connection conexion(){
            llamadas++;
            return proxy(Connection.class,(p,m,a)->{
                if(m.getName().equals("close")){conexionCerrada=true;return null;}
                if(m.getName().equals("prepareCall")){
                    String sql=(String)a[0];
                    int n=op.lectura()?2:op==OperacionAdministracionUsuario.AGREGAR?6:op==OperacionAdministracionUsuario.ESTADO?5:4;
                    exigir(sql.equals("{call dbo."+op.procedimiento+"("+String.join(", ",Collections.nCopies(n,"?"))+")}"));
                    return sentencia();
                }throw new AssertionError(m.getName());
            });
        }
        CallableStatement sentencia(){
            return proxy(CallableStatement.class,(p,m,a)->{
                switch(m.getName()){
                    case "setInt":case "setString":case "setTimestamp":parametros.put((Integer)a[0],a[1]);return null;
                    case "setNull":parametros.put((Integer)a[0],null);return null;
                    case "execute":
                        if(runtime)throw new IllegalStateException(PRIVADO);
                        if(codigo!=0)throw new SQLException(PRIVADO,"TEST",codigo);
                        indice=conteo?-1:0;return indice>=0&&!resultados.isEmpty();
                    case "getMoreResults":return ++indice<resultados.size();
                    case "getUpdateCount":return indice==-1?1:-1;
                    case "getResultSet":return rs(resultados.get(indice));
                    case "close":statementCerrado=true;return null;
                    default:throw new AssertionError(m.getName());
                }
            });
        }
        ResultSet rs(List<Map<String,Object>> datos){
            abiertos++;int[] pos={-1};boolean[] nulo={false};
            return proxy(ResultSet.class,(p,m,a)->{
                switch(m.getName()){
                    case "close":cerrados++;return null;
                    case "next":return ++pos[0]<datos.size();
                    case "wasNull":return nulo[0];
                }
                Map<String,Object> r=datos.get(pos[0]);String col=(String)a[0];
                if(!r.containsKey(col))throw new SQLException(PRIVADO);
                Object v=r.get(col);nulo[0]=v==null;
                switch(m.getName()){
                    case "getInt":return v==null?0:(Integer)v;
                    case "getBoolean":return v==null?false:(Boolean)v;
                    case "getString":return (String)v;
                    case "getTimestamp":return (Timestamp)v;
                    case "getDate":return (java.sql.Date)v;
                    case "getBigDecimal":return (BigDecimal)v;
                    default:throw new AssertionError(m.getName());
                }
            });
        }
    }
    static class Caso {
        final Http h=new Http();
        final Jdbc j;final Map<String,String[]> parametros=new LinkedHashMap<>();
        final OperacionAdministracionUsuario op;
        final HttpServletRequest req;
        boolean directo;
        Caso(OperacionAdministracionUsuario op){
            this.op=op;j=new Jdbc(op);h.method=op.metodo;h.ruta=op.ruta;
            h.previa=new Sesion();h.previa.datos.put("adminIdUsuario",7);h.previa.datos.put("adminIdRol",3);
            h.previa.datos.put("adminCorreo","admin@example.test");h.previa.datos.put("adminRol","ADMINISTRADOR");
            h.previa.datos.put("adminEstadoUsuario","ACTIVO");
            if(op==OperacionAdministracionUsuario.DETALLE||op==OperacionAdministracionUsuario.REABRIR
                    ||op==OperacionAdministracionUsuario.ESTADO||op==OperacionAdministracionUsuario.AGREGAR)p("idUsuario","19");
            if(op==OperacionAdministracionUsuario.INICIAR||op==OperacionAdministracionUsuario.APROBAR||op==OperacionAdministracionUsuario.RECHAZAR)p("idVerificacion","23");
            if(op==OperacionAdministracionUsuario.LEVANTAR){p("idRestriccion","29");p("motivoLevantamiento","Motivo");}
            if(op==OperacionAdministracionUsuario.RECHAZAR||op==OperacionAdministracionUsuario.AGREGAR)p("motivo","Motivo");
            if(op==OperacionAdministracionUsuario.ESTADO)p("nuevoEstado","ACTIVO");
            if(op==OperacionAdministracionUsuario.AGREGAR)p("tipoRestriccion","APOSTAR");
            req=proxy(HttpServletRequest.class,(p,m,a)->{
                if(m.getName().equals("getParameterMap"))return parametros;
                if(m.getName().equals("getRemoteAddr"))return "127.0.0.1";
                try{return m.invoke(h.req,a);}catch(InvocationTargetException e){throw e.getCause();}
            });
        }
        void p(String k,String... v){if(v==null)parametros.remove(k);else parametros.put(k,v);}
        JsonNode ejecutar(int esperado)throws Exception {
            AdministracionUsuarioDAO dao=new AdministracionUsuarioDAO(){@Override protected Connection obtenerConexion(){return j.conexion();}};
            AdministracionUsuarioServlet s=new AdministracionUsuarioServlet();
            Field f=AdministracionUsuarioServlet.class.getDeclaredField("servicio");f.setAccessible(true);
            f.set(s,new AdministracionUsuarioServicio(dao));
            if(directo)s.service(req,h.res);
            else new ControlAccesoAdministrativo().doFilter(req,h.res,(r,res)->s.service((HttpServletRequest)r,(HttpServletResponse)res));
            exigir(h.status==esperado&&h.creaciones==0);
            exigir("application/json;charset=UTF-8".equals(h.tipo));
            exigir("no-store".equals(h.headers.get("Cache-Control")));
            String cuerpo=h.body.toString();exigir(!cuerpo.contains(PRIVADO)&&!cuerpo.contains("SQLException")&&!cuerpo.contains("dbo."));
            JsonNode json=JSON.readTree(cuerpo);exigir(json.get("ok").asBoolean()==(esperado==200));
            if(esperado!=200)exigir(json.size()==2&&json.has("mensaje"));
            if(j.llamadas>0){
                exigir(j.llamadas==1&&j.conexionCerrada&&j.statementCerrado&&j.abiertos==j.cerrados);
                exigir(j.parametros.get(1).equals(7));
                if(!op.lectura())exigir(j.parametros.get(op==OperacionAdministracionUsuario.AGREGAR?6:op==OperacionAdministracionUsuario.ESTADO?5:4).equals("127.0.0.1"));
            }
            casos++;return json;
        }
    }
    private static int esperadoSql(int codigo){
        int[][] grupos={
            {400,63001,63005,63006,63012,63016,63020,63025,63030,63031,63036,63042,63043,63044,63052,63053,63054,63055,63060,63061},
            {403,63002,63003,63004,63007,63008,63009,63011,63013,63014,63015,63019,63023,63039,63047,63057},
            {404,63010,63018,63022,63028,63034,63038,63046,63056,63062},
            {409,63024,63029,63035,63040,63041,63048,63049,63050,63051,63058,63059}
        };
        for(int[] g:grupos)for(int i=1;i<g.length;i++)if(g[i]==codigo)return g[0];return 500;
    }
    public static void main(String[] args)throws Exception {
        if(args.length>0){
            Caso c=new Caso(OperacionAdministracionUsuario.PENDIENTES);c.h.previa=null;c.ejecutar(401);
            System.out.println("Filtro APIs JSON: OK");return;
        }
        for(OperacionAdministracionUsuario op:OperacionAdministracionUsuario.values()){
            Caso c=new Caso(op);JsonNode json=c.ejecutar(200);
            if(op==OperacionAdministracionUsuario.DETALLE){
                exigir(json.get("detalle").size()==3);
                exigir(json.at("/detalle/usuario/idPais").isNull());
                exigir(!json.at("/detalle/usuario").has("intentosFallidos"));
                exigir(!json.at("/detalle/usuario").has("bloqueadoHasta"));
                exigir(!json.at("/detalle/usuario").has("ultimoAcceso"));
                exigir(json.at("/detalle/verificaciones/0/idUsuarioRevisor").isNull());
            }
            if(op==OperacionAdministracionUsuario.PENDIENTES)exigir(json.get("cantidad").asInt()==1);
            c=new Caso(op);c.j.conteo=true;c.ejecutar(200);
            c=new Caso(op);c.h.previa=null;c.ejecutar(401);exigir(c.j.llamadas==0);
            c=new Caso(op);c.h.previa.expirada=true;c.ejecutar(401);exigir(c.j.llamadas==0);
            c=new Caso(op);c.directo=true;c.h.previa=null;c.ejecutar(401);
            c=new Caso(op);c.h.previa.falloLectura=true;c.ejecutar(500);
            for(String rol:new String[]{"USUARIO","CASA","OPERADOR_EVENTOS","CAJERO","AUDITOR"}){
                c=new Caso(op);c.h.previa.datos.put("adminRol",rol);
                c.ejecutar(op.lectura()&&rol.equals("AUDITOR")?200:403);
            }
            for(String metodo:new String[]{"GET","POST","PUT","DELETE","PATCH","HEAD"}){
                if(metodo.equals(op.metodo))continue;
                c=new Caso(op);c.h.method=metodo;c.ejecutar(405);exigir(c.j.llamadas==0&&op.metodo.equals(c.h.headers.get("Allow")));
            }
            for(String intruso:new String[]{"idUsuarioProceso","idAdministrador","usuarioProceso","correoAdministrador","rolAdministrador","IpOrigen","ipOrigen"}){
                c=new Caso(op);c.p(intruso,"99");c.ejecutar(400);exigir(c.j.llamadas==0);
            }
            for(String k:op.parametros){
                c=new Caso(op);c.p(k,"1","2");c.ejecutar(400);exigir(c.j.llamadas==0);
            }
            c=new Caso(op);c.j.codigo=99999;c.ejecutar(500);
            c=new Caso(op);c.j.runtime=true;c.ejecutar(500);
            c=new Caso(op);c.j.resultados.clear();c.ejecutar(500);
            c=new Caso(op);c.j.resultados.add(new ArrayList<>());c.ejecutar(500);
            for(int indice=0;indice<(op==OperacionAdministracionUsuario.DETALLE?3:1);indice++){
                c=new Caso(op);c.j.resultados.get(indice).add(new LinkedHashMap<>(c.j.resultados.get(indice).get(0)));c.ejecutar(500);
                Map<String,Object> base=new Caso(op).j.resultados.get(indice).get(0);
                for(String col:base.keySet()){
                    if(Arrays.asList("IntentosFallidos","BloqueadoHasta","UltimoAcceso","Contrasena","Token").contains(col))continue;
                    c=new Caso(op);c.j.resultados.get(indice).get(0).remove(col);c.ejecutar(500);
                    if(base.get(col)!=null){
                        c=new Caso(op);c.j.resultados.get(indice).get(0).put(col,null);c.ejecutar(500);
                    }
                }
            }
        }
        for(int codigo=63001;codigo<=63062;codigo++){
            Caso c=new Caso(OperacionAdministracionUsuario.INICIAR);c.j.codigo=codigo;c.ejecutar(esperadoSql(codigo));
        }
        for(OperacionAdministracionUsuario op:OperacionAdministracionUsuario.values()){
            if(op==OperacionAdministracionUsuario.PENDIENTES)continue;
            String id=op.parametros.contains("idUsuario")?"idUsuario":op.parametros.contains("idVerificacion")?"idVerificacion":"idRestriccion";
            for(String valor:new String[]{null,""," ","0","-1","abc","1.5","2147483648","1 OR 1=1"}){
                Caso c=new Caso(op);if(valor==null)c.parametros.remove(id);else c.p(id,valor);
                c.ejecutar(400);exigir(c.j.llamadas==0);
            }
        }
        Caso c=new Caso(OperacionAdministracionUsuario.PENDIENTES);c.j.resultados.get(0).clear();
        exigir(c.ejecutar(200).get("cantidad").asInt()==0);
        for(String n:new String[]{"0","501","abc","","-1","2147483648"}){
            c=new Caso(OperacionAdministracionUsuario.PENDIENTES);c.p("cantidad",n);c.ejecutar(400);
        }
        for(String n:new String[]{"1","500"}){
            c=new Caso(OperacionAdministracionUsuario.PENDIENTES);c.p("cantidad",n);c.ejecutar(200);exigir(c.j.parametros.get(2).equals(Integer.valueOf(n)));
        }
        c=new Caso(OperacionAdministracionUsuario.DETALLE);c.j.resultados.get(0).clear();c.ejecutar(500);
        c=new Caso(OperacionAdministracionUsuario.DETALLE);c.j.resultados.remove(2);c.ejecutar(500);
        c=new Caso(OperacionAdministracionUsuario.DETALLE);c.j.resultados.get(1).clear();c.j.resultados.get(2).clear();c.ejecutar(200);
        c=new Caso(OperacionAdministracionUsuario.DETALLE);c.j.resultados.get(0).get(0).put("IdUsuario",88);c.ejecutar(500);
        for(OperacionAdministracionUsuario op:new OperacionAdministracionUsuario[]{OperacionAdministracionUsuario.RECHAZAR,OperacionAdministracionUsuario.AGREGAR,OperacionAdministracionUsuario.LEVANTAR}){
            String nombre=op==OperacionAdministracionUsuario.LEVANTAR?"motivoLevantamiento":"motivo";
            for(String motivo:new String[]{null,""," ","a".repeat(501)}){
                c=new Caso(op);if(motivo==null)c.parametros.remove(nombre);else c.p(nombre,motivo);c.ejecutar(400);
            }
        }
        for(OperacionAdministracionUsuario op:new OperacionAdministracionUsuario[]{OperacionAdministracionUsuario.INICIAR,OperacionAdministracionUsuario.APROBAR,OperacionAdministracionUsuario.REABRIR}){
            c=new Caso(op);c.p("observacion","a".repeat(501));c.ejecutar(400);
            c=new Caso(op);c.p("observacion","  ");c.ejecutar(200);exigir(c.j.parametros.get(3)==null);
        }
        for(String estado:new String[]{"PENDIENTE","ACTIVO","SUSPENDIDO","CERRADO"}){
            c=new Caso(OperacionAdministracionUsuario.ESTADO);c.p("nuevoEstado",estado);c.p("motivo","Motivo");
            c.j.resultados.get(0).get(0).put("EstadoActual",estado);c.ejecutar(200);
        }
        for(String estado:new String[]{null,"","DESCONOCIDO","INACTIVO"}){
            c=new Caso(OperacionAdministracionUsuario.ESTADO);if(estado==null)c.parametros.remove("nuevoEstado");else c.p("nuevoEstado",estado);c.ejecutar(400);
        }
        for(String estado:new String[]{"SUSPENDIDO","CERRADO"}){
            c=new Caso(OperacionAdministracionUsuario.ESTADO);c.p("nuevoEstado",estado);c.ejecutar(400);
        }
        for(String tipo:new String[]{null,"","LOGIN","OTRA"}){
            c=new Caso(OperacionAdministracionUsuario.AGREGAR);if(tipo==null)c.parametros.remove("tipoRestriccion");else c.p("tipoRestriccion",tipo);c.ejecutar(400);
        }
        c=new Caso(OperacionAdministracionUsuario.AGREGAR);c.p("tipoRestriccion"," todas_operaciones ");
        c.j.resultados.get(0).get(0).put("TipoRestriccion","TODAS_OPERACIONES");c.ejecutar(200);
        for(String fecha:new String[]{"abc","2026-02-30T00:00:00","2026-01-01","0000-01-01T00:00:00","2026-01-01T00:00:00Z"}){
            c=new Caso(OperacionAdministracionUsuario.AGREGAR);c.p("fechaFin",fecha);c.ejecutar(400);
        }
        c=new Caso(OperacionAdministracionUsuario.AGREGAR);c.p("fechaFin","2099-01-01T00:00:00.1234567");
        c.j.resultados.get(0).get(0).put("FechaFin",Timestamp.valueOf("2099-01-01 00:00:00.1234567"));c.ejecutar(200);
        c=new Caso(OperacionAdministracionUsuario.AGREGAR);c.p("fechaFin","2000-01-01T00:00:00");c.j.codigo=63055;c.ejecutar(400);
        for(OperacionAdministracionUsuario op:OperacionAdministracionUsuario.values()){
            if(op.lectura()||op==OperacionAdministracionUsuario.REABRIR||op==OperacionAdministracionUsuario.AGREGAR)continue;
            c=new Caso(op);c.j.resultados.get(0).get(0).put("SinCambios",true);
            exigir(c.ejecutar(200).at("/resultado/sinCambios").asBoolean());
        }
        for(Object id:new Object[]{null,0,-1,"7",7L}){
            c=new Caso(OperacionAdministracionUsuario.DETALLE);c.h.previa.datos.put("adminIdUsuario",id);c.ejecutar(403);
        }
        c=new Caso(OperacionAdministracionUsuario.DETALLE);c.h.previa.datos.put("idUsuario",7);c.h.previa.datos.put("rol","USUARIO");c.ejecutar(403);
        // Listas completas, limites de texto y precision: no solo una fila feliz.
        c=new Caso(OperacionAdministracionUsuario.PENDIENTES);
        Map<String,Object> segundo=pendiente();segundo.put("IdUsuario",20);segundo.put("IdVerificacion",24);
        c.j.resultados.get(0).add(segundo);
        exigir(c.ejecutar(200).get("usuarios").size()==2);
        c=new Caso(OperacionAdministracionUsuario.PENDIENTES);c.p("cantidad","1");c.j.resultados.get(0).add(segundo);c.ejecutar(500);
        for(OperacionAdministracionUsuario op:new OperacionAdministracionUsuario[]{OperacionAdministracionUsuario.INICIAR,OperacionAdministracionUsuario.APROBAR,OperacionAdministracionUsuario.REABRIR}){
            c=new Caso(op);c.p("observacion","a".repeat(500));c.ejecutar(200);exigir(c.j.parametros.get(3).equals("a".repeat(500)));
        }
        c=new Caso(OperacionAdministracionUsuario.RECHAZAR);c.p("motivo","  Motivo  ");c.ejecutar(200);exigir(c.j.parametros.get(3).equals("Motivo"));
        c=new Caso(OperacionAdministracionUsuario.AGREGAR);String control="Texto \"citado\"\n\u0001";
        c.p("motivo",control);c.j.resultados.get(0).get(0).put("Motivo",control.trim());
        exigir(c.ejecutar(200).at("/resultado/motivo").asText().equals(control.trim()));
        c=new Caso(OperacionAdministracionUsuario.PENDIENTES);
        c.j.resultados.get(0).get(0).put("IdUsuarioRevisor",0);c.ejecutar(500);
        for(OperacionAdministracionUsuario op:OperacionAdministracionUsuario.values()){
            String identificador=op==OperacionAdministracionUsuario.INICIAR||op==OperacionAdministracionUsuario.APROBAR
                    ||op==OperacionAdministracionUsuario.RECHAZAR?"IdVerificacion":
                    op==OperacionAdministracionUsuario.LEVANTAR?"IdRestriccion":"IdUsuario";
            for(int id:new int[]{0,-1}){
                c=new Caso(op);c.j.resultados.get(0).get(0).put(identificador,id);c.ejecutar(500);
            }
            if(!op.lectura()){
                c=new Caso(op);c.j.resultados.get(0).get(0).put(identificador,999);c.ejecutar(500);
            }
        }
        for(String campo:new String[]{"adminIdRol","adminCorreo","adminRol","adminEstadoUsuario"}){
            c=new Caso(OperacionAdministracionUsuario.PENDIENTES);c.h.previa.datos.remove(campo);c.ejecutar(403);
        }
        c=new Caso(OperacionAdministracionUsuario.PENDIENTES);c.h.previa.datos.put("adminEstadoUsuario","SUSPENDIDO");c.ejecutar(403);
        c=new Caso(OperacionAdministracionUsuario.PENDIENTES);c.directo=true;c.h.previa.expirada=true;c.ejecutar(401);
        System.out.println("Administracion usuario: "+casos+" casos, 0 fallos.");
    }
}