package com.apuestas.controlador;

import com.apuestas.correo.*;
import com.apuestas.dao.UsuarioDAO;
import com.apuestas.seguridad.*;
import com.apuestas.servicio.VerificacionCorreoServicio;
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
public class PruebaVerificacionCorreoUsuario {
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
                fila.put("CorreoVerificado",true);
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
                        exigir(fila.containsKey(columna),"Columna desconocida");
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
        String token=TokenVerificacionCorreo.generar();
    }
    private static class Salida {
        int estado=200, sesiones;
        String tipo, encoding;
        final Map<String,String> headers=new HashMap<>();
        final StringWriter cuerpo=new StringWriter();
        JsonNode json;
    }
    private static void sinSecretos(String texto, String token, String hash) {
        exigir(!texto.contains("INTERNO") && (!TokenVerificacionCorreo.esValido(token) || !texto.contains(token))
                && (hash==null || !texto.contains(hash)), "No exponer token, hash ni excepciones");
    }
    private static Salida ejecutar(Entrada e, Jdbc d, CorreoFake correo, int esperado) throws Exception {
        HttpServlet servlet=d.solicitar ? new SolicitarVerificacionCorreoServlet() : new ConfirmarVerificacionCorreoServlet();
        servlet.init();
        Field campo=servlet.getClass().getDeclaredField("verificacionServicio");
        campo.setAccessible(true); campo.set(servlet,new VerificacionCorreoServicio(d,correo));
        Salida s=new Salida();
        HttpSession sesion=proxy(HttpSession.class,(p,m,a)->{
            exigir(m.getName().equals("getAttribute"),"Nunca mutar ni guardar token en sesion");
            if (e.expirada) throw new IllegalStateException("Expirada");
            switch((String)a[0]) {
                case "idUsuario": return e.id;
                case "correo": return e.correo;
                case "rol": return e.rol;
                default: throw new AssertionError("Atributo inesperado");
            }
        });
        HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)->{
            switch(m.getName()) {
                case "setCharacterEncoding": s.encoding=(String)a[0]; return null;
                case "getSession":
                    exigir(d.solicitar && !e.get,"Confirmar/GET nunca consulta sesion");
                    exigir(a!=null && a.length==1 && Boolean.FALSE.equals(a[0]),"Solo getSession(false)");
                    s.sesiones++;
                    if (e.errorRequest) throw new IllegalStateException("INTERNO request");
                    return e.sesion ? sesion : null;
                case "getParameter":
                    exigir(!d.solicitar && !e.get && "token".equals(a[0]),"Ignorar idUsuario/correo del request");
                    exigir("UTF-8".equals(s.encoding),"Encoding antes de parametros");
                    if (e.errorRequest) throw new IllegalArgumentException("INTERNO "+e.token);
                    return e.token;
                default: throw new AssertionError("Request inesperado "+m.getName());
            }
        });
        HttpServletResponse resp=proxy(HttpServletResponse.class,(p,m,a)->{
            switch(m.getName()) {
                case "setStatus": s.estado=(Integer)a[0]; return null;
                case "setHeader": s.headers.put((String)a[0],(String)a[1]); return null;
                case "setContentType": s.tipo=(String)a[0]; return null;
                case "getWriter": return new PrintWriter(s.cuerpo);
                default: throw new AssertionError("Response inesperado "+m.getName());
            }
        });
        if (d.solicitar) {
            if (e.get) ((SolicitarVerificacionCorreoServlet)servlet).doGet(req,resp);
            else ((SolicitarVerificacionCorreoServlet)servlet).doPost(req,resp);
        } else {
            if (e.get) ((ConfirmarVerificacionCorreoServlet)servlet).doGet(req,resp);
            else ((ConfirmarVerificacionCorreoServlet)servlet).doPost(req,resp);
        }
        exigir(s.estado==esperado,"HTTP esperado "+esperado+", recibido "+s.estado);
        exigir("application/json;charset=UTF-8".equals(s.tipo),"JSON UTF8");
        exigir("no-store".equals(s.headers.get("Cache-Control")),"No store");
        exigir(s.sesiones==(d.solicitar && !e.get ? 1:0),"Sesion sin cambios");
        s.json=JSON.readTree(s.cuerpo.toString());
        exigir(s.json.get("ok").asBoolean()==(esperado==200),"ok");
        exigir(s.json.size()==(esperado==200 && d.solicitar ? 1:2),"Campos externos exactos");
        if (esperado==200 && !d.solicitar) exigir(s.json.get("correoVerificado").asBoolean(),"Confirmacion");
        if (esperado!=200) exigir(s.json.get("mensaje").isTextual(),"Error generico");
        if (e.get) exigir("POST".equals(s.headers.get("Allow")) && d.conexiones==0 && correo.envios==0,"GET no consume");
        exigir(d.abiertos.equals(d.cerrados),"Todos los recursos cerrados");
        exigir(d.conexiones<=1 && d.ejecuciones<=1 && correo.envios<=1,"Sin consultas adicionales ni reintentos");
        String hash=d.parametros.get(d.solicitar?3:1);
        if (d.sql!=null) {
            exigir((d.solicitar?"{call dbo.sp_CrearTokenSeguridad(?, ?, ?)}"
                    :"{call dbo.sp_VerificarCorreoConToken(?)}").equals(d.sql),"Procedimiento oficial exacto");
            if (!"parametro".equals(d.fallo)) {
                exigir(d.parametros.size()==(d.solicitar?3:1),"Parametros exactos");
                exigir(hash.matches("[0-9a-f]{64}"),"SQL solo recibe hash hexadecimal");
                if (d.solicitar) {
                    exigir(((String)e.correo).trim().toLowerCase(Locale.ROOT).equals(d.parametros.get(1)),"Correo sesion");
                    exigir("VERIFICACION_CORREO".equals(d.parametros.get(2)),"Tipo fijo");
                } else exigir(hashIndependiente(e.token).equals(hash) && !hash.equals(e.token),"Hash confirmacion");
            }
        }
        if (correo.envios>0) {
            exigir(d.solicitar && d.cerrados.equals(d.abiertos),"Correo solo despues de cerrar SQL");
            String token=correo.mensaje.getTexto().split("\n")[1];
            exigir(TokenVerificacionCorreo.esValido(token) && !token.contains("="),"Token canonico");
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
            @Override public void publish(LogRecord r) { logs.add(r.getMessage()); exigir(r.getThrown()==null,"Sin excepcion en logs"); }
            @Override public void flush() { }
            @Override public void close() { }
        };
        Logger ls=Logger.getLogger(SolicitarVerificacionCorreoServlet.class.getName());
        Logger lc=Logger.getLogger(ConfirmarVerificacionCorreoServlet.class.getName());
        ls.addHandler(h); lc.addHandler(h);
        try {
            exigir(Arrays.asList(SolicitarVerificacionCorreoServlet.class.getAnnotation(WebServlet.class).value())
                    .contains("/usuario/seguridad/verificacion-correo/solicitar"),"Mapping solicitar");
            exigir(Arrays.asList(ConfirmarVerificacionCorreoServlet.class.getAnnotation(WebServlet.class).value())
                    .contains("/usuario/seguridad/verificacion-correo/confirmar"),"Mapping confirmar");
            Set<String> tokens=new HashSet<>();
            for (int i=0;i<100;i++) {
                String token=TokenVerificacionCorreo.generar();
                exigir(tokens.add(token) && TokenVerificacionCorreo.esValido(token),"Aleatoriedad y formato");
                exigir(hashIndependiente(token).equals(TokenVerificacionCorreo.hash(token)),"SHA256 determinista");
                exigir(TokenVerificacionCorreo.hash(token).equals(TokenVerificacionCorreo.hash(token)),"Determinismo");
            }
            casos++;
            Entrada e=new Entrada(); e.sesion=false; rechazar(e,new Jdbc(true),401);
            for (Object id:new Object[]{null,0,-1,"","abc",1.5,Long.MAX_VALUE,Double.NaN,new Object()}) {
                e=new Entrada(); e.id=id; rechazar(e,new Jdbc(true),401);
            }
            for (Object correo:new Object[]{null,""," ","abc","a@@b.test","a b@c.test","a".repeat(151)+"@b.test",7}) {
                e=new Entrada(); e.correo=correo; rechazar(e,new Jdbc(true),401);
            }
            for (Object rol:new Object[]{null,"ADMINISTRADOR","OPERADOR_EVENTOS","CAJERO","AUDITOR","CASA","usuario","USUARIO "}) {
                e=new Entrada(); e.rol=rol; rechazar(e,new Jdbc(true),403);
            }
            e=new Entrada(); e.expirada=true; rechazar(e,new Jdbc(true),401);
            for (Object id:new Object[]{"7",7L,new BigDecimal("7.00")}) {
                e=new Entrada(); e.id=id; e.correo=" CLIENTE@EXAMPLE.INVALID "; llamar(e,new Jdbc(true),200);
            }
            Jdbc d=new Jdbc(true); CorreoFake correo=new CorreoFake();
            Salida creado=ejecutar(new Entrada(),d,correo,200);
            String primerHash=d.parametros.get(3);
            for (Integer id:Arrays.asList(null,7)) {
                d=new Jdbc(true); d.noCreado(id); correo=new CorreoFake();
                Salida noCreado=ejecutar(new Entrada(),d,correo,200);
                exigir(noCreado.json.equals(creado.json) && correo.envios==0,"Sin enumeracion ni correo innecesario");
            }
            d=new Jdbc(true); d.fila.put("IdUsuario",8); llamar(new Entrada(),d,500);
            d=new Jdbc(true); d.noCreado(8); llamar(new Entrada(),d,500);
            for (String columna:Arrays.asList("TokenCreado","IdToken","IdUsuario","FechaExpiracion")) {
                d=new Jdbc(true); d.fila.put(columna,null); llamar(new Entrada(),d,500);
            }
            for (String columna:Arrays.asList("IdToken","IdUsuario")) {
                for (int valor:new int[]{0,-1}) {
                    d=new Jdbc(true); d.fila.put(columna,valor); llamar(new Entrada(),d,500);
                }
            }
            d=new Jdbc(true); d.noCreado(7); d.fila.put("IdToken",11); llamar(new Entrada(),d,500);
            d=new Jdbc(true); d.noCreado(7); d.fila.put("FechaExpiracion",Timestamp.valueOf("2099-01-01 00:00:00")); llamar(new Entrada(),d,500);
            d=new Jdbc(true); d.noCreado(0); llamar(new Entrada(),d,500);
            for (boolean runtime:new boolean[]{false,true}) {
                d=new Jdbc(true); correo=new CorreoFake(); correo.fallo=!runtime; correo.runtime=runtime;
                ejecutar(new Entrada(),d,correo,500);
                exigir(correo.envios==1 && d.ejecuciones==1,"Fallo correo no reintenta ni revierte SQL");
            }
            d=new Jdbc(true); llamar(new Entrada(),d,200);
            exigir(!primerHash.equals(d.parametros.get(3)),"Solicitud posterior genera token nuevo");

            for (String token:Arrays.asList(null,""," ","abc","a".repeat(10000),
                    "A".repeat(42),"A".repeat(44),"A".repeat(42)+"=","A".repeat(42)+"+",
                    "A".repeat(42)+"/","A".repeat(42)+"B"," "+ "A".repeat(43),
                    "A".repeat(43)+"\n")) {
                e=new Entrada(); e.token=token; rechazar(e,new Jdbc(false),400);
            }
            e=new Entrada(); e.sesion=false; llamar(e,new Jdbc(false),200);
            String errorToken=null;
            for (int codigo:new int[]{57013,57014,57015,57016}) {
                d=new Jdbc(false); d.codigo=codigo;
                String mensaje=llamar(new Entrada(),d,400).json.get("mensaje").asText();
                if (errorToken==null) errorToken=mensaje;
                else exigir(errorToken.equals(mensaje),"Error uniforme: invalido/inexistente/usado/expirado");
            }
            for (String columna:Arrays.asList("IdUsuario","CorreoVerificado")) {
                d=new Jdbc(false); d.fila.put(columna,null); llamar(new Entrada(),d,500);
            }
            d=new Jdbc(false); d.fila.put("CorreoVerificado",false); llamar(new Entrada(),d,500);
            for (int id:new int[]{0,-1}) { d=new Jdbc(false); d.fila.put("IdUsuario",id); llamar(new Entrada(),d,500); }

            for (boolean solicitar:new boolean[]{true,false}) {
                e=new Entrada(); e.get=true; rechazar(e,new Jdbc(solicitar),405);
                e=new Entrada(); e.errorRequest=true; rechazar(e,new Jdbc(solicitar),500);
                d=new Jdbc(solicitar); d.runtime=true; llamar(new Entrada(),d,500);
                d=new Jdbc(solicitar); d.codigo=99999; llamar(new Entrada(),d,500);
                for (int filas:new int[]{0,2}) { d=new Jdbc(solicitar); d.filas=filas; llamar(new Entrada(),d,500); }
                d=new Jdbc(solicitar); d.sinResultado=true; llamar(new Entrada(),d,500);
                d=new Jdbc(solicitar); d.extra=true; llamar(new Entrada(),d,500);
                d=new Jdbc(solicitar); d.conteos=true; llamar(new Entrada(),d,200);
                for (String fallo:Arrays.asList("conexion","preparar","parametro","lectura","final")) {
                    d=new Jdbc(solicitar); d.fallo=fallo; llamar(new Entrada(),d,500);
                }
                for (String hash:Arrays.asList(null,"","A".repeat(43),"z".repeat(64))) {
                    d=new Jdbc(solicitar);
                    try {
                        if (solicitar) d.crearTokenVerificacionCorreo(CORREO,hash); else d.verificarCorreoConToken(hash);
                        throw new AssertionError("No aceptar token original en DAO");
                    } catch (IllegalArgumentException esperado) { exigir(d.conexiones==0,"DAO valida hash antes SQL"); casos++; }
                }
            }
            for (int id:new int[]{0,-1}) {
                d=new Jdbc(true);
                try { new VerificacionCorreoServicio(d,new CorreoFake()).solicitar(id,CORREO); throw new AssertionError("Id invalido"); }
                catch (IllegalArgumentException esperado) { exigir(d.conexiones==0,"Servicio valida identidad"); casos++; }
            }
            d=new Jdbc(false);
            try { new VerificacionCorreoServicio(d,new CorreoFake()).confirmar("invalido"); throw new AssertionError("Token invalido"); }
            catch (IllegalArgumentException esperado) { exigir(d.conexiones==0,"Servicio valida token"); casos++; }

            String ruta="/usuario/seguridad/verificacion-correo/confirmar";
            filtro(ruta,null,true);
            for (String vecina:Arrays.asList(ruta+"/",ruta+"/extra",ruta+"-otra",ruta.toUpperCase(Locale.ROOT),
                    "/usuario/seguridad/verificacion-correo/solicitar",
                    "/usuario/seguridad/cambiar-contrasena","/usuario/seguridad/recuperacion",
                    "/usuario/seguridad/verificacion-correo","/usuario/inicio.jsp")) {
                filtro(vecina,null,false);
            }
            filtro(ruta,"/extra",false);
            filtro("/usuario/seguridad/verificacion-correo","/confirmar",true);
            for (String log:logs) {
                exigir(log.equals("No se completo la solicitud de verificacion de correo.")
                        || log.equals("No se completo la confirmacion de correo."),"Logs fijos sin secretos");
            }
            System.out.println("OK: "+casos+" casos controlados de verificacion de correo, sin red ni SQL real.");
        } finally { ls.removeHandler(h); lc.removeHandler(h); }
    }
}
