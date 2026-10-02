package com.apuestas.controlador;

import com.apuestas.correo.*;
import com.apuestas.dao.UsuarioDAO;
import com.apuestas.seguridad.*;
import com.apuestas.servicio.RecuperacionContrasenaServicio;
import com.fasterxml.jackson.databind.*;
import java.io.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.*;
import java.util.*;
import java.util.logging.*;
import javax.servlet.http.*;
import javax.servlet.annotation.WebServlet;

/** Prueba manual sin red, SQL real ni correo real. El DAO real usa proxies JDBC. */
public class PruebaRecuperacionContrasena {
    private static final String CORREO = "cliente@example.invalid";
    private static final ObjectMapper JSON = new ObjectMapper();
    private static int casos;

    private static void exigir(boolean condicion, String mensaje) {
        if (!condicion) throw new AssertionError(mensaje);
    }
    @SuppressWarnings("unchecked")
    private static <T> T proxy(Class<T> clase, InvocationHandler manejador) {
        return (T)Proxy.newProxyInstance(clase.getClassLoader(),new Class<?>[]{clase},manejador);
    }
    private static String hashIndependiente(String token) throws Exception {
        byte[] bytes=MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
        StringBuilder hex=new StringBuilder();
        for (byte b:bytes) hex.append(String.format(Locale.ROOT,"%02x",b & 255));
        return hex.toString();
    }
    private static class CorreoFake implements CorreoServicio {
        int envios;
        boolean fallo, runtime;
        MensajeCorreo mensaje;
        @Override public void enviar(MensajeCorreo mensaje) throws EnvioCorreoException {
            envios++; this.mensaje=mensaje;
            if (fallo) throw new EnvioCorreoException();
            if (runtime) throw new IllegalStateException("INTERNO " + mensaje.getTexto());
        }
    }
    private static class Jdbc extends UsuarioDAO {
        final boolean solicitar;
        final Map<String,Object> fila=new LinkedHashMap<>();
        final Map<Integer,String> parametros=new HashMap<>();
        final Set<String> abiertos=new HashSet<>(), cerrados=new HashSet<>(), leidas=new HashSet<>();
        final List<Object> resultados=new ArrayList<>();
        int conexiones, ejecuciones, indice, filas=1, codigo;
        String sql, fallo;
        boolean extra, conteos, sinResultado, runtime;
        Jdbc(boolean solicitar) {
            this.solicitar=solicitar;
            if (solicitar) {
                fila.put("TokenCreado",true);
                fila.put("IdToken",11);
                fila.put("IdUsuario",7);
                fila.put("FechaExpiracion",Timestamp.valueOf("2099-10-01 12:30:00.1234567"));
            } else {
                fila.put("IdUsuario",7);
                fila.put("ContrasenaActualizada",true);
            }
        }
        void noCreado(Integer id) {
            fila.put("TokenCreado",false); fila.put("IdToken",null);
            fila.put("IdUsuario",id); fila.put("FechaExpiracion",null);
        }
        @Override protected Connection obtenerConexion() throws SQLException {
            conexiones++;
            if (runtime) throw new IllegalArgumentException("INTERNO runtime");
            if ("conexion".equals(fallo)) throw new SQLException("INTERNO conexion");
            abiertos.add("conexion");
            return proxy(Connection.class,(p,m,a)->{
                switch(m.getName()) {
                    case "prepareCall":
                        if ("preparar".equals(fallo)) throw new SQLException("INTERNO preparar");
                        sql=(String)a[0]; abiertos.add("statement"); return statement();
                    case "close": cerrar("conexion"); return null;
                    default: throw new AssertionError("Conexion inesperada " + m.getName());
                }
            });
        }
        void cerrar(String nombre) { exigir(cerrados.add(nombre),"Cierre duplicado"); }
        boolean esResultado() {
            return indice<resultados.size() && resultados.get(indice) instanceof String;
        }
        CallableStatement statement() {
            return proxy(CallableStatement.class,(p,m,a)->{
                switch(m.getName()) {
                    case "setString":
                        if ("parametro".equals(fallo)) throw new SQLException("INTERNO parametro");
                        parametros.put((Integer)a[0],(String)a[1]); return null;
                    case "execute":
                        ejecuciones++;
                        if (codigo!=0) throw new SQLException("INTERNO SQL "+parametros,"TEST",codigo);
                        if (conteos) { resultados.add(0); resultados.add(2); }
                        if (!sinResultado) resultados.add("principal");
                        if (conteos) resultados.add(0);
                        if (extra) resultados.add("adicional");
                        return esResultado();
                    case "getUpdateCount":
                        return indice>=resultados.size() || esResultado() ? -1 : (Integer)resultados.get(indice);
                    case "getMoreResults":
                        indice++;
                        if ("final".equals(fallo)) throw new SQLException("INTERNO final "+parametros);
                        return esResultado();
                    case "getResultSet": return resultado(indice);
                    case "close": cerrar("statement"); return null;
                    default: throw new AssertionError("Statement inesperado " + m.getName());
                }
            });
        }
        ResultSet resultado(int numero) {
            String nombre="rs"+numero;
            abiertos.add(nombre);
            int[] posicion={0}; boolean[] nulo={false};
            return proxy(ResultSet.class,(p,m,a)->{
                switch(m.getName()) {
                    case "next":
                        if ("lectura".equals(fallo)) throw new SQLException("INTERNO lectura");
                        return ++posicion[0]<=filas;
                    case "wasNull": return nulo[0];
                    case "getInt": case "getBoolean": case "getTimestamp":
                        String columna=(String)a[0];
                        if (!fila.containsKey(columna)) throw new SQLException("INTERNO columna");
                        leidas.add(columna);
                        Object valor=fila.get(columna); nulo[0]=valor==null;
                        if (valor!=null) return valor;
                        if (m.getName().equals("getInt")) return Integer.valueOf(0);
                        if (m.getName().equals("getBoolean")) return Boolean.FALSE;
                        return null;
                    case "close": cerrar(nombre); return null;
                    default: throw new AssertionError("ResultSet inesperado "+m.getName());
                }
            });
        }
    }
    private static class Entrada {
        boolean get, sesion=true, expirada, errorRequest;
        Object id=7, correo=CORREO, rol="USUARIO";
        String token=TokenSeguridad.generar();
        String nueva="ClavePrueba123!", confirmacion=nueva;
    }
    private static class Salida {
        int estado=200, sesiones;
        String tipo, encoding;
        final Map<String,String> headers=new HashMap<>();
        final StringWriter cuerpo=new StringWriter();
        JsonNode json;
    }
    private static void sinSecretos(String texto, String token, String hash) {
        exigir(!texto.contains("INTERNO") && (!TokenSeguridad.esValido(token) || !texto.contains(token))
                && (hash==null || !texto.contains(hash)), "No exponer token, hash ni excepciones");
    }
    private static Salida ejecutar(Entrada e, Jdbc d, CorreoFake correo, int esperado) throws Exception {
        HttpServlet servlet=d.solicitar ? new SolicitarRecuperacionContrasenaServlet() : new RestablecerContrasenaServlet();
        servlet.init();
        Field campo=servlet.getClass().getDeclaredField("recuperacionServicio");
        campo.setAccessible(true); campo.set(servlet,new RecuperacionContrasenaServicio(d,correo));
        Salida s=new Salida();
        HttpServletRequest req=proxy(HttpServletRequest.class,(p0,m,a)->{
            switch(m.getName()) {
                case "setCharacterEncoding": s.encoding=(String)a[0]; return null;
                case "getParameter":
                    exigir(!e.get && "UTF-8".equals(s.encoding),"Parametros despues de UTF8");
                    if (e.errorRequest) throw new IllegalArgumentException("INTERNO "+e.token);
                    if (d.solicitar) {
                        exigir("correo".equals(a[0]),"Ignorar idUsuario y no consultar identidad");
                        return e.correo;
                    }
                    switch ((String)a[0]) {
                        case "token": return e.token;
                        case "nuevaContrasena": return e.nueva;
                        case "confirmarContrasena": return e.confirmacion;
                        default: throw new AssertionError("Parametro no permitido");
                    }
                default: throw new AssertionError("Nunca consultar/crear sesion: "+m.getName());
            }
        });        HttpServletResponse resp=proxy(HttpServletResponse.class,(p,m,a)->{
            switch(m.getName()) {
                case "setStatus": s.estado=(Integer)a[0]; return null;
                case "setHeader": s.headers.put((String)a[0],(String)a[1]); return null;
                case "setContentType": s.tipo=(String)a[0]; return null;
                case "getWriter": return new PrintWriter(s.cuerpo);
                default: throw new AssertionError("Response inesperado "+m.getName());
            }
        });
        if (d.solicitar) {
            if (e.get) ((SolicitarRecuperacionContrasenaServlet)servlet).doGet(req,resp);
            else ((SolicitarRecuperacionContrasenaServlet)servlet).doPost(req,resp);
        } else {
            if (e.get) ((RestablecerContrasenaServlet)servlet).doGet(req,resp);
            else ((RestablecerContrasenaServlet)servlet).doPost(req,resp);
        }
        exigir(s.estado==esperado,"HTTP esperado "+esperado+", recibido "+s.estado);
        exigir("application/json;charset=UTF-8".equals(s.tipo),"JSON UTF8");
        exigir("no-store".equals(s.headers.get("Cache-Control")),"No store");
        exigir(s.sesiones==0,"Sin sesion");
        s.json=JSON.readTree(s.cuerpo.toString());
        exigir(s.json.get("ok").asBoolean()==(esperado==200),"ok");
        exigir(s.json.size()==(esperado==200 && d.solicitar ? 1:2),"Campos externos exactos");
        if (esperado==200 && !d.solicitar) exigir(s.json.get("contrasenaActualizada").asBoolean(),"Confirmacion");
        if (esperado!=200) exigir(s.json.get("mensaje").isTextual(),"Error generico");
        if (e.get) exigir("POST".equals(s.headers.get("Allow")) && d.conexiones==0 && correo.envios==0,"GET no consume");
        exigir(d.abiertos.equals(d.cerrados),"Todos los recursos cerrados");
        exigir(d.conexiones<=1 && d.ejecuciones<=1 && correo.envios<=1,"Sin consultas adicionales ni reintentos");
        String hash=d.parametros.get(d.solicitar?3:1);
        if (d.sql!=null) {
            exigir((d.solicitar?"{call dbo.sp_CrearTokenSeguridad(?, ?, ?)}"
                    :"{call dbo.sp_RestablecerContrasenaConToken(?, ?)}").equals(d.sql),"Procedimiento oficial exacto");
            if (!"parametro".equals(d.fallo)) {
                exigir(d.parametros.size()==(d.solicitar?3:2),"Parametros exactos");
                exigir(hash.matches("[0-9a-f]{64}"),"SQL solo recibe hash hexadecimal");
                if (d.solicitar) {
                    exigir(((String)e.correo).trim().toLowerCase(Locale.ROOT).equals(d.parametros.get(1)),"Correo sesion");
                    exigir("RECUPERACION_CONTRASENA".equals(d.parametros.get(2)),"Tipo fijo");
                                } else {
                    exigir(hashIndependiente(e.token).equals(hash) && !hash.equals(e.token),"Hash token");
                    String bcrypt=d.parametros.get(2);
                    exigir(!e.nueva.equals(bcrypt) && bcrypt.startsWith("$2a$12$"),"Solo BCrypt en SQL");
                    exigir(EncriptadorContrasena.verificar(e.nueva,bcrypt),"BCrypt real");
                    exigir(!s.cuerpo.toString().contains(bcrypt) && !s.cuerpo.toString().contains(e.nueva),"Sin secretos");
                }
            }
        }
        if (correo.envios>0) {
            exigir(d.solicitar && d.cerrados.equals(d.abiertos),"Correo solo despues de cerrar SQL");
            String token=correo.mensaje.getTexto().split("\n")[1];
            exigir(TokenSeguridad.esValido(token) && !token.contains("="),"Token canonico");
            exigir(Base64.getUrlDecoder().decode(token).length==32,"256 bits");
            exigir(hashIndependiente(token).equals(hash),"Hash de token enviado");
            exigir(correo.mensaje.getDestinatario().equals(d.parametros.get(1)),"Destinatario exclusivo sesion");
            exigir(!correo.mensaje.getTexto().contains(hash) && !correo.mensaje.getTexto().contains("http")
                    && !correo.mensaje.getTexto().contains("IdUsuario") && !correo.mensaje.getTexto().contains("IdToken"),"Correo sin datos SQL ni enlace");
            sinSecretos(s.cuerpo.toString(),token,hash);
            sinSecretos(correo.mensaje.toString(),token,hash);
        } else sinSecretos(s.cuerpo.toString(),e.token,hash);
        if (esperado==200) exigir(d.leidas.equals(d.fila.keySet()),"Todas las columnas oficiales");
        if (!d.solicitar || esperado!=200 && !(correo.fallo || correo.runtime)) exigir(correo.envios==0,"Sin envio indebido");
        casos++;
        return s;
    }
    private static Salida llamar(Entrada e, Jdbc d, int estado) throws Exception {
        return ejecutar(e,d,new CorreoFake(),estado);
    }
    private static void rechazar(Entrada e, Jdbc d, int estado) throws Exception {
        llamar(e,d,estado); exigir(d.conexiones==0,"Validar antes de SQL");
    }
    private static void filtro(String ruta, String pathInfo, boolean publica) throws Exception {
        int[] accesos={0}, estado={200};
        Map<String,String> headers=new HashMap<>();
        HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)->{
            switch(m.getName()) {
                case "getServletPath": return ruta;
                case "getPathInfo": return pathInfo;
                case "getSession":
                    exigir(!publica && a!=null && Boolean.FALSE.equals(a[0]),"Ruta publica sin sesion");
                    return null;
                case "getContextPath": return "/PlataformaApuestasNuevo";
                default: throw new AssertionError("Filtro request "+m.getName());
            }
        });
        HttpServletResponse res=proxy(HttpServletResponse.class,(p,m,a)->{
            if ("setStatus".equals(m.getName())) { estado[0]=(Integer)a[0]; return null; }
            if ("setHeader".equals(m.getName())) { headers.put((String)a[0],(String)a[1]); return null; }
            throw new AssertionError("Filtro response "+m.getName());
        });
        new ControlAcceso().doFilter(req,res,(r,s)->accesos[0]++);
        exigir(accesos[0]==(publica?1:0),"Exclusion exacta");
        if (!publica) exigir(estado[0]==303
                && "/PlataformaApuestasNuevo/usuario/login".equals(headers.get("Location")),"Ruta protegida");
        casos++;
    }
    public static void main(String[] args) throws Exception {
        List<String> logs=new ArrayList<>();
        Handler h=new Handler() {
            @Override public void publish(LogRecord r) {
                logs.add(r.getMessage()); exigir(r.getThrown()==null,"Sin excepciones en logs");
            }
            @Override public void flush() { }
            @Override public void close() { }
        };
        Logger ls=Logger.getLogger(SolicitarRecuperacionContrasenaServlet.class.getName());
        Logger lr=Logger.getLogger(RestablecerContrasenaServlet.class.getName());
        ls.addHandler(h); lr.addHandler(h);
        try {
            exigir(SolicitarRecuperacionContrasenaServlet.class.getAnnotation(WebServlet.class).value()[0]
                    .equals("/usuario/seguridad/recuperacion-contrasena/solicitar"),"Mapping solicitud");
            exigir(RestablecerContrasenaServlet.class.getAnnotation(WebServlet.class).value()[0]
                    .equals("/usuario/seguridad/recuperacion-contrasena/restablecer"),"Mapping restablecer");
            Set<String> tokens=new HashSet<>();
            for (int i=0;i<100;i++) {
                String token=TokenSeguridad.generar();
                exigir(tokens.add(token) && TokenSeguridad.esValido(token),"Aleatoriedad");
                exigir(hashIndependiente(token).equals(TokenSeguridad.hash(token)),"SHA256 independiente");
                exigir(TokenVerificacionCorreo.hash(token).equals(TokenSeguridad.hash(token)),"Compatibilidad");
            }
            casos++;
            Entrada e; Jdbc d; CorreoFake c;
            for (String direccion:Arrays.asList(null,""," ","abc","a@@b.test","a b@c.test",
                    "x".repeat(151)+"@b.test","a@b","a\n@b.test")) {
                e=new Entrada(); e.correo=direccion; rechazar(e,new Jdbc(true),400);
            }
            e=new Entrada(); e.correo=" CLIENTE@EXAMPLE.INVALID "; llamar(e,new Jdbc(true),200);
            Salida creado=llamar(new Entrada(),new Jdbc(true),200);
            d=new Jdbc(true); d.noCreado(null); c=new CorreoFake();
            Salida ausente=ejecutar(new Entrada(),d,c,200);
            exigir(creado.json.equals(ausente.json) && c.envios==0,"Inexistente/cerrado sin enumeracion");
            for (String col:Arrays.asList("TokenCreado","IdToken","IdUsuario","FechaExpiracion")) {
                d=new Jdbc(true); d.fila.put(col,null); llamar(new Entrada(),d,500);
                d=new Jdbc(true); d.fila.remove(col); llamar(new Entrada(),d,500);
            }
            for (String col:Arrays.asList("IdToken","IdUsuario")) {
                for (int id:new int[]{0,-1}) { d=new Jdbc(true); d.fila.put(col,id); llamar(new Entrada(),d,500); }
            }
            d=new Jdbc(true); d.noCreado(7); llamar(new Entrada(),d,500);
            d=new Jdbc(true); d.noCreado(null); d.fila.put("IdToken",11); llamar(new Entrada(),d,500);
            d=new Jdbc(true); d.noCreado(null); d.fila.put("FechaExpiracion",Timestamp.valueOf("2099-01-01 00:00:00")); llamar(new Entrada(),d,500);
            for (boolean runtime:new boolean[]{false,true}) {
                d=new Jdbc(true); c=new CorreoFake(); c.fallo=!runtime; c.runtime=runtime;
                ejecutar(new Entrada(),d,c,500);
                exigir(c.envios==1 && d.ejecuciones==1,"Sin reintentos/rollback");
            }
            Jdbc primero=new Jdbc(true), segundo=new Jdbc(true);
            llamar(new Entrada(),primero,200); llamar(new Entrada(),segundo,200);
            exigir(!primero.parametros.get(3).equals(segundo.parametros.get(3)),"Token nuevo");

            for (String token:Arrays.asList(null,""," ","abc","a".repeat(10000),"A".repeat(42),
                    "A".repeat(44),"A".repeat(42)+"=","A".repeat(42)+"+","A".repeat(42)+"/",
                    "A".repeat(42)+"B"," "+"A".repeat(43),"A".repeat(43)+"\n")) {
                e=new Entrada(); e.token=token; rechazar(e,new Jdbc(false),400);
            }
            for (String clave:Arrays.asList(null,""," ","1234567","a".repeat(73),"é".repeat(37),
                    "😀".repeat(19)," ".repeat(8))) {
                e=new Entrada(); e.nueva=clave; e.confirmacion=clave; rechazar(e,new Jdbc(false),400);
            }
            for (String confirmacion:Arrays.asList(null,"","distinta")) {
                e=new Entrada(); e.confirmacion=confirmacion; rechazar(e,new Jdbc(false),400);
            }
            for (String clave:Arrays.asList("12345678","a".repeat(72),"é".repeat(36),"😀".repeat(18)," clave segura ")) {
                e=new Entrada(); e.nueva=clave; e.confirmacion=clave; llamar(e,new Jdbc(false),200);
            }
            String error=null;
            for (int codigo:new int[]{57017,57018,57019,57020,57021,57022}) {
                d=new Jdbc(false); d.codigo=codigo;
                Salida s=llamar(new Entrada(),d,codigo==57018?500:400);
                if (codigo!=57018) {
                    if(error==null) error=s.json.get("mensaje").asText();
                    else exigir(error.equals(s.json.get("mensaje").asText()),"Errores token uniformes");
                }
            }
            for (String col:Arrays.asList("IdUsuario","ContrasenaActualizada")) {
                d=new Jdbc(false); d.fila.put(col,null); llamar(new Entrada(),d,500);
                d=new Jdbc(false); d.fila.remove(col); llamar(new Entrada(),d,500);
            }
            d=new Jdbc(false); d.fila.put("ContrasenaActualizada",false); llamar(new Entrada(),d,500);
            for (int id:new int[]{0,-1}) { d=new Jdbc(false); d.fila.put("IdUsuario",id); llamar(new Entrada(),d,500); }

            for (boolean solicitud:new boolean[]{true,false}) {
                e=new Entrada(); e.get=true; rechazar(e,new Jdbc(solicitud),405);
                e=new Entrada(); e.errorRequest=true; rechazar(e,new Jdbc(solicitud),500);
                d=new Jdbc(solicitud); d.runtime=true; llamar(new Entrada(),d,500);
                d=new Jdbc(solicitud); d.codigo=99999; llamar(new Entrada(),d,500);
                for (int filas:new int[]{0,2}) { d=new Jdbc(solicitud); d.filas=filas; llamar(new Entrada(),d,500); }
                d=new Jdbc(solicitud); d.sinResultado=true; llamar(new Entrada(),d,500);
                d=new Jdbc(solicitud); d.extra=true; llamar(new Entrada(),d,500);
                d=new Jdbc(solicitud); d.conteos=true; llamar(new Entrada(),d,200);
                for (String fallo:Arrays.asList("conexion","preparar","parametro","lectura","final")) {
                    d=new Jdbc(solicitud); d.fallo=fallo; llamar(new Entrada(),d,500);
                }
            }
            String bcrypt=EncriptadorContrasena.encriptar("PruebaSegura123!");
            for (String hash:Arrays.asList(null,"","A".repeat(43),"z".repeat(64))) {
                for (boolean solicitud:new boolean[]{true,false}) {
                    d=new Jdbc(solicitud);
                    try {
                        if(solicitud) d.crearTokenRecuperacionContrasena(CORREO,hash);
                        else d.restablecerContrasenaConToken(hash,bcrypt);
                        throw new AssertionError("Hash invalido aceptado");
                    } catch (IllegalArgumentException esperado) { exigir(d.conexiones==0,"Validacion previa DAO"); casos++; }
                }
            }
            for (String hashClave:Arrays.asList(null,"","ClavePlana123!","$2a$12$incompleto")) {
                d=new Jdbc(false);
                try {
                    d.restablecerContrasenaConToken("a".repeat(64),hashClave);
                    throw new AssertionError("No aceptar clave plana");
                } catch (IllegalArgumentException esperado) { exigir(d.conexiones==0,"Validacion hash BCrypt"); casos++; }
            }
            d=new Jdbc(true);
            try { new RecuperacionContrasenaServicio(d,new CorreoFake()).solicitar("invalido"); throw new AssertionError(); }
            catch (IllegalArgumentException esperado) { exigir(d.conexiones==0,"Servicio valida correo"); casos++; }
            d=new Jdbc(false);
            try { new RecuperacionContrasenaServicio(d,new CorreoFake()).restablecer("malo","x","x"); throw new AssertionError(); }
            catch (IllegalArgumentException esperado) { exigir(d.conexiones==0,"Servicio valida datos"); casos++; }

            String base="/usuario/seguridad/recuperacion-contrasena";
            for (String ruta:Arrays.asList(base+"/solicitar",base+"/restablecer")) {
                filtro(ruta,null,true);
                for (String sufijo:Arrays.asList("/","/extra","-otra",".jsp")) filtro(ruta+sufijo,null,false);
                filtro(ruta.toUpperCase(Locale.ROOT),null,false);
                filtro(ruta,"/extra",false);
            }
            filtro(base,"/restablecer",true);
            for (String ruta:Arrays.asList("/usuario/seguridad/verificacion-correo/confirmar","/usuario/login","/usuario/logout")) filtro(ruta,null,true);
            for (String ruta:Arrays.asList(base,"/usuario/seguridad/verificacion-correo/solicitar",
                    "/usuario/seguridad/cambiar-contrasena","/usuario/inicio.jsp")) filtro(ruta,null,false);
            for(String log:logs) exigir(log.equals("No se completo la solicitud de recuperacion.")
                    || log.equals("No se completo el restablecimiento."),"Logs fijos sin secretos");
            System.out.println("OK: "+casos+" casos de recuperacion, JDBC/correo simulados y BCrypt real.");
        } finally { ls.removeHandler(h); lr.removeHandler(h); }
    }
}