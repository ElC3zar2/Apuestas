package com.apuestas.controlador;

import com.apuestas.dao.UsuarioDAO;
import com.apuestas.modelo.*;
import com.apuestas.servicio.AutenticacionAdministrativaServicio;
import com.apuestas.seguridad.SesionAdministrativa;
import java.io.*;
import java.lang.reflect.*;
import java.sql.*;
import java.time.LocalDateTime;
import java.util.*;
import javax.servlet.*;
import javax.servlet.http.*;
import org.mindrot.jbcrypt.BCrypt;

/** Sin SQL/red: servicio real, BCrypt y dependencias simuladas estrictas. */
public class PruebaLoginAdministrativo {
    static int casos;
    static final String CLAVE="ClaveLocal123";
    static final String HASH=BCrypt.hashpw(CLAVE,BCrypt.gensalt(4));
    static final String RECHAZO="No fue posible iniciar sesión con los datos proporcionados.";
    static void exigir(boolean b){if(!b)throw new AssertionError("Contrato administrativo incumplido");}
    @SuppressWarnings("unchecked") static <T>T proxy(Class<T> t,InvocationHandler h){
        return (T)Proxy.newProxyInstance(t.getClassLoader(),new Class<?>[]{t},h);
    }
    static UsuarioAutenticacion usuario(int id,int rolId,String rol,String estado,String hash,boolean bloqueo){
        return new UsuarioAutenticacion(id,"admin@example.test",hash,false,bloqueo?5:0,
                bloqueo?LocalDateTime.of(2099,1,1,0,0):null,null,rolId,rol,1,estado,estado,bloqueo,!bloqueo);
    }
    static ResultadoIntentoLogin intento(int id,int fallos,boolean bloqueo,boolean permiso,String estado){
        return new ResultadoIntentoLogin(id,fallos,bloqueo?LocalDateTime.of(2099,1,1,0,0):null,bloqueo,permiso,estado);
    }
    static class Dao extends UsuarioDAO {
        UsuarioAutenticacion u=usuario(7,3,"ADMINISTRADOR","ACTIVO",HASH,false);
        ResultadoIntentoLogin r=intento(7,0,false,true,"ACTIVO");
        int consultas,intentos,fallo; Boolean exitoso;String correo,ip;
        @Override public UsuarioAutenticacion obtenerUsuarioAutenticacion(String c)throws SQLException {
            consultas++;correo=c;
            if(fallo==1)throw new SQLException("SECRETO_INTERNO","TEST",57004);
            if(fallo==2)throw new IllegalStateException("SECRETO_INTERNO");
            if(fallo==4)throw new ExceptionInInitializerError("SECRETO_INTERNO");
            return u;
        }
        @Override public ResultadoIntentoLogin registrarIntentoLogin(int id,boolean ok,String origen)throws SQLException {
            exigir(id==7);intentos++;exitoso=ok;ip=origen;
            if(fallo==3)throw new SQLException("SECRETO_INTERNO","TEST",57005);
            return r;
        }
    }
    static class Sesion {
        Map<String,Object> datos=new LinkedHashMap<>();
        boolean invalidada,expirada,falloLectura,falloEscritura;
        final HttpSession ref=proxy(HttpSession.class,(p,m,a)->{
            if(expirada)throw new IllegalStateException("SECRETO_INTERNO");
            switch(m.getName()){
                case "getAttribute":if(falloLectura)throw new UnsupportedOperationException("SECRETO_INTERNO");return datos.get(a[0]);
                case "setAttribute":
                    if(falloEscritura)throw new UnsupportedOperationException("SECRETO_INTERNO");
                    exigir(!invalidada);datos.put((String)a[0],a[1]);return null;
                case "invalidate":invalidada=true;datos.clear();return null;
                default:throw new AssertionError(m.getName());
            }
        });
    }
    static class Http {
        Map<String,String> params=new HashMap<>(),headers=new HashMap<>();
        String method="POST",ruta="/administrador/login",pathInfo,contexto="/app",tipo,forward,encoding;
        DispatcherType dispatcher=DispatcherType.REQUEST;
        int status=200,creaciones,chain;
        Sesion previa,nueva; boolean falloNueva;
        StringWriter body=new StringWriter();
        final HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)->{
            switch(m.getName()){
                case "getMethod":return method;
                case "getServletPath":return ruta;
                case "getPathInfo":return pathInfo;
                case "getDispatcherType":return dispatcher;
                case "getContextPath":return contexto;
                case "setCharacterEncoding":encoding=(String)a[0];return null;
                case "getParameter":
                    exigir("UTF-8".equals(encoding));
                    exigir(a[0].equals("correo")||a[0].equals("contrasena"));return params.get(a[0]);
                case "getRemoteAddr":return "127.0.0.1";
                case "getSession":
                    exigir(a!=null && a.length==1);
                    if(Boolean.TRUE.equals(a[0])){
                        exigir(previa==null||previa.invalidada||previa.expirada);
                        creaciones++;nueva=new Sesion();nueva.falloEscritura=falloNueva;return nueva.ref;
                    }
                    return previa==null?null:previa.ref;
                case "getRequestDispatcher":
                    return proxy(RequestDispatcher.class,(d,dm,da)->{exigir(dm.getName().equals("forward"));forward=(String)a[0];return null;});
                default:throw new AssertionError(m.getName());
            }
        });
        final HttpServletResponse res=proxy(HttpServletResponse.class,(p,m,a)->{
            switch(m.getName()){
                case "setStatus":status=(Integer)a[0];return null;
                case "setHeader":headers.put((String)a[0],(String)a[1]);return null;
                case "setContentType":tipo=(String)a[0];return null;
                case "getWriter":return new PrintWriter(body);
                default:throw new AssertionError(m.getName());
            }
        });
        void comun(){exigir("no-store".equals(headers.get("Cache-Control")));exigir(!body.toString().contains("SECRETO_INTERNO"));}
    }
    static Http llamar(Dao dao,String correo,String clave,String metodo)throws Exception {
        Http h=new Http();h.method=metodo;
        h.params.put("correo",correo);h.params.put("contrasena",clave);
        // Ninguno de estos parametros puede leerse para autenticar.
        h.params.put("rol","ADMINISTRADOR");h.params.put("idUsuario","99");h.params.put("IpOrigen","falsa");
        h.previa=new Sesion();h.previa.datos.put("idUsuario",99);h.previa.datos.put("rol","USUARIO");
        ejecutar(h,new AutenticacionAdministrativaServicio(dao));return h;
    }
    static void ejecutar(Http h,AutenticacionAdministrativaServicio servicio)throws Exception {
        LoginAdministrativoServlet s=new LoginAdministrativoServlet();
        Field f=LoginAdministrativoServlet.class.getDeclaredField("servicio");f.setAccessible(true);f.set(s,servicio);
        s.service(h.req,h.res);h.comun();
    }
    static void rechazo(Http h,int codigo){
        exigir(h.status==codigo && h.creaciones==0 && !h.previa.invalidada);
        exigir(RECHAZO.equals(h.body.toString()));casos++;
    }
    static void exito(Http h,String rol){
        exigir(h.status==303 && "/app/administrador/inicio.jsp".equals(h.headers.get("Location")));
        exigir(h.creaciones==1 && h.previa.invalidada && h.previa.datos.isEmpty());
        exigir(h.nueva.datos.size()==5 && SesionAdministrativa.valida(h.nueva.ref));
        exigir(h.nueva.datos.get("adminRol").equals(rol));
        exigir(h.nueva.datos.keySet().equals(new HashSet<>(Arrays.asList(
                "adminIdUsuario","adminCorreo","adminIdRol","adminRol","adminEstadoUsuario"))));
        exigir(!h.nueva.datos.containsValue(CLAVE)&&!h.nueva.datos.containsValue(HASH));casos++;
    }
    /** Ejecuta el DAO real con ResultSet simulado, comprueba cierre y lectura estricta. */
    static void jdbc(boolean intento,int filas,String columna,boolean nulo)throws Exception {
        final boolean[] cerrados=new boolean[3];final int[] pos={0};final boolean[] wasNull={false};
        ResultSet rs=proxy(ResultSet.class,(p,m,a)->{
            if(m.getName().equals("close")){cerrados[2]=true;return null;}
            if(m.getName().equals("next"))return ++pos[0]<=filas;
            if(m.getName().equals("wasNull"))return wasNull[0];
            String col=(String)a[0];wasNull[0]=col.equals(columna)&&nulo;
            if(col.equals(columna)&&!nulo)throw new SQLException("SECRETO_INTERNO");
            switch(m.getName()){
                case "getInt":return wasNull[0]?0:col.equals("IntentosFallidos")?0:7;
                case "getBoolean":return !wasNull[0] && !col.equals("BloqueoVigente");
                case "getTimestamp":return null;
                case "getString":
                    if(wasNull[0])return null;
                    if(col.equals("Correo"))return "admin@example.test";
                    if(col.equals("Contrasena"))return HASH;
                    if(col.equals("Rol"))return "ADMINISTRADOR";
                    return "ACTIVO";
                default:throw new AssertionError(m.getName());
            }
        });
        CallableStatement cs=proxy(CallableStatement.class,(p,m,a)->{
            switch(m.getName()){
                case "close":cerrados[1]=true;return null;
                case "execute":return true;
                case "getResultSet":return rs;
                case "getMoreResults":return false;
                case "getUpdateCount":return -1;
                case "setInt":case "setBoolean":case "setString":case "setNull":return null;
                default:throw new AssertionError(m.getName());
            }
        });
        Connection c=proxy(Connection.class,(p,m,a)->{
            if(m.getName().equals("close")){cerrados[0]=true;return null;}
            if(m.getName().equals("prepareCall")){
                exigir(a[0].equals(intento?"{call dbo.sp_RegistrarIntentoLogin(?, ?, ?)}":"{call dbo.sp_ObtenerUsuarioAutenticacion(?)}"));
                return cs;
            }throw new AssertionError(m.getName());
        });
        UsuarioDAO dao=new UsuarioDAO(){@Override protected Connection obtenerConexion(){return c;}};
        boolean error=false;
        try {
            if(intento)dao.registrarIntentoLogin(7,true,"127.0.0.1");
            else exigir((dao.obtenerUsuarioAutenticacion("admin@example.test")==null)==(filas==0));
        }catch(SQLException e){error=true;}
        exigir(error==(filas>1||columna!=null||(intento&&filas==0)));
        exigir(cerrados[0]&&cerrados[1]&&cerrados[2]);casos++;
    }
    public static void main(String[] args)throws Exception {
        for(String correo:new String[]{null,""," ","abc","a@@b.test","a b@test.t","a".repeat(151)+"@t.t"}){
            Dao d=new Dao();rechazo(llamar(d,correo,CLAVE,"POST"),400);exigir(d.consultas==0);
        }
        for(String clave:new String[]{null,""," ","a".repeat(73),"é".repeat(37)}){
            Dao d=new Dao();rechazo(llamar(d,"admin@example.test",clave,"POST"),400);exigir(d.consultas==0);
        }
        Dao d=new Dao();d.u=null;rechazo(llamar(d,"admin@example.test",CLAVE,"POST"),401);exigir(d.intentos==0);
        d=new Dao();d.r=intento(7,1,false,false,"ACTIVO");
        rechazo(llamar(d,"admin@example.test","incorrecta","POST"),401);exigir(d.intentos==1&&!d.exitoso);
        for(String rol:new String[]{"ADMINISTRADOR","OPERADOR_EVENTOS","CAJERO","AUDITOR"}){
            d=new Dao();d.u=usuario(7,3,rol,"ACTIVO",HASH,false);
            exito(llamar(d," ADMIN@EXAMPLE.TEST ",CLAVE,"POST"),rol);
            exigir(d.correo.equals("admin@example.test")&&d.ip.equals("127.0.0.1")&&d.exitoso);
        }
        for(String rol:new String[]{null,"","USUARIO","CASA","ADMIN","administrador","ADMINISTRADOR "}){
            d=new Dao();d.u=usuario(7,3,rol,"ACTIVO",HASH,false);
            rechazo(llamar(d,"admin@example.test",CLAVE,"POST"),401);exigir(d.intentos==0);
        }
        for(String estado:new String[]{null,"","PENDIENTE","INACTIVO","SUSPENDIDO","CERRADO"}){
            d=new Dao();d.u=usuario(7,3,"ADMINISTRADOR",estado,HASH,false);
            rechazo(llamar(d,"admin@example.test",CLAVE,"POST"),401);exigir(d.intentos==0);
        }
        for(String hash:new String[]{null,"","invalido","$2b$12$"+"a".repeat(53),"$2a$03$"+"a".repeat(53)}){
            d=new Dao();d.u=usuario(7,3,"ADMINISTRADOR","ACTIVO",hash,false);
            rechazo(llamar(d,"admin@example.test",CLAVE,"POST"),500);exigir(d.intentos==0);
        }
        for(int id:new int[]{0,-1}){
            d=new Dao();d.u=usuario(id,3,"ADMINISTRADOR","ACTIVO",HASH,false);
            rechazo(llamar(d,"admin@example.test",CLAVE,"POST"),500);
            d=new Dao();d.u=usuario(7,id,"ADMINISTRADOR","ACTIVO",HASH,false);
            rechazo(llamar(d,"admin@example.test",CLAVE,"POST"),500);
        }
        for(int fallo=1;fallo<=4;fallo++){
            d=new Dao();d.fallo=fallo;rechazo(llamar(d,"admin@example.test",CLAVE,"POST"),500);
        }
        for(String clave:new String[]{CLAVE,"incorrecta"}){
            d=new Dao();d.u=usuario(7,3,"ADMINISTRADOR","ACTIVO",HASH,true);d.r=intento(7,5,true,false,"ACTIVO");
            rechazo(llamar(d,"admin@example.test",clave,"POST"),401);exigir(d.intentos==1);
        }
        for(ResultadoIntentoLogin r:new ResultadoIntentoLogin[]{
                null,intento(8,0,false,true,"ACTIVO"),intento(7,-1,false,false,"ACTIVO"),
                intento(7,0,false,true,null),intento(7,2,false,true,"ACTIVO"),intento(7,5,true,true,"ACTIVO")}){
            d=new Dao();d.r=r;rechazo(llamar(d,"admin@example.test",CLAVE,"POST"),500);
        }
        for(ResultadoIntentoLogin r:new ResultadoIntentoLogin[]{
                intento(7,0,false,true,"PENDIENTE"),intento(7,0,false,true,"SUSPENDIDO"),
                intento(7,0,false,false,"ACTIVO"),intento(7,5,true,false,"ACTIVO")}){
            d=new Dao();d.r=r;rechazo(llamar(d,"admin@example.test",CLAVE,"POST"),401);
        }
        d=new Dao();Http h=llamar(d,null,null,"GET");
        exigir(h.status==200&&h.forward.equals("/administrador/login.jsp")&&h.creaciones==0&&d.consultas==0);casos++;
        for(String metodo:new String[]{"PUT","DELETE","HEAD","TRACE","OPTIONS"}){
            d=new Dao();h=llamar(d,null,null,metodo);
            exigir(h.status==405&&d.consultas==0&&h.creaciones==0);casos++;
        }
        h=new Http();h.params.put("correo","admin@example.test");h.params.put("contrasena",CLAVE);h.falloNueva=true;
        ejecutar(h,new AutenticacionAdministrativaServicio(new Dao()));
        exigir(h.status==500&&h.nueva.invalidada&&h.nueva.datos.isEmpty());casos++;
        for(boolean intento:new boolean[]{false,true}){
            for(int filas:new int[]{0,1,2})jdbc(intento,filas,null,false);
            String[] columnas=intento?new String[]{"IdUsuario","IntentosFallidos","BloqueoVigente","AutenticacionPermitida","EstadoUsuario"}:
                    new String[]{"IdUsuario","Correo","Contrasena","CorreoVerificado","IntentosFallidos","IdRol","Rol","IdEstado","EstadoUsuario","NombreEstadoUsuario","BloqueoVigente","PuedeIniciarSesion"};
            for(String columna:columnas){jdbc(intento,1,columna,false);jdbc(intento,1,columna,true);}
        }
        System.out.println("Login administrativo: "+casos+" casos, 0 fallos.");
    }
}