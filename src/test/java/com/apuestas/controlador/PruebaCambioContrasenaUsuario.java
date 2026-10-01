package com.apuestas.controlador;

import com.apuestas.dao.UsuarioDAO;
import com.apuestas.modelo.*;
import com.apuestas.seguridad.EncriptadorContrasena;
import com.apuestas.servicio.UsuarioServicio;
import com.fasterxml.jackson.databind.*;
import java.io.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import java.util.logging.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import org.mindrot.jbcrypt.BCrypt;

/** Pruebas controladas de cambio de clave: no abre SQL ni altera cuentas reales. */
public class PruebaCambioContrasenaUsuario {
    private static final String CORREO = "cliente@example.test";
    private static final String ACTUAL = " Actual-á-123 ";
    private static final String NUEVA = " Nueva-segura-á-456 ";
    private static final String HASH = BCrypt.hashpw(ACTUAL, BCrypt.gensalt(4));
    private static final String HASH_NUEVO = EncriptadorContrasena.encriptar(NUEVA);
    private static final ObjectMapper JSON = new ObjectMapper();
    private static int casos;

    private static void exigir(boolean valor, String mensaje) {
        if (!valor) throw new AssertionError(mensaje);
    }
    @SuppressWarnings("unchecked")
    private static <T> T proxy(Class<T> tipo, InvocationHandler manejador) {
        return (T) Proxy.newProxyInstance(tipo.getClassLoader(), new Class<?>[]{tipo}, manejador);
    }
    private static UsuarioAutenticacion usuario(int id, String correo, String hash, String rol) {
        return new UsuarioAutenticacion(id, correo, hash, false, 0, null, null,
                3, rol, 1, "ACTIVO", "Activo", false, true);
    }

    private static class Jdbc extends UsuarioDAO {
        UsuarioAutenticacion usuario = usuario(7,CORREO,HASH,"USUARIO");
        final Map<String,Object> fila = new LinkedHashMap<>();
        final Map<Integer,Object> parametros = new HashMap<>();
        final Set<String> abiertos = new HashSet<>(), cerrados = new HashSet<>(), columnas = new HashSet<>();
        final List<Object> resultados = new ArrayList<>();
        int consultas, cambios, conexiones, codigoConsulta, codigoCambio, indice, filas = 1;
        String correoConsultado, hashRecibido, sql, fallo;
        boolean extra, conteos, sinResultado, runtimeConsulta;
        Jdbc() { fila.put("IdUsuario",7); fila.put("ContrasenaActualizada",true); }

        @Override public UsuarioAutenticacion obtenerUsuarioAutenticacion(String correo) throws SQLException {
            consultas++;
            correoConsultado = correo;
            if (runtimeConsulta) throw new IllegalArgumentException("PRIVADO runtime");
            if (codigoConsulta != 0) throw new SQLException("PRIVADO consulta", "TEST", codigoConsulta);
            return usuario;
        }
        @Override public ResultadoIntentoLogin registrarIntentoLogin(int id, boolean exito, String ip) {
            throw new AssertionError("Cambio voluntario nunca registra intento login");
        }
        @Override public void cambiarContrasenaUsuario(int id, String hash) throws SQLException {
            cambios++;
            exigir(id == 7,"Id de sesion enviado al DAO");
            hashRecibido = hash;
            super.cambiarContrasenaUsuario(id,hash);
        }
        @Override protected Connection obtenerConexion() throws SQLException {
            conexiones++;
            if ("conexion".equals(fallo)) throw new SQLException("PRIVADO conexion");
            abiertos.add("conexion");
            return proxy(Connection.class,(p,m,a)->{
                if ("prepareCall".equals(m.getName())) {
                    if ("preparar".equals(fallo)) throw new SQLException("PRIVADO preparar");
                    sql = (String)a[0]; abiertos.add("statement"); return statement();
                }
                if ("close".equals(m.getName())) { cerrar("conexion"); return null; }
                throw new AssertionError("Conexion " + m.getName());
            });
        }
        private void cerrar(String nombre) {
            exigir(cerrados.add(nombre),"Cierre duplicado " + nombre);
        }
        private boolean esResultado() {
            return indice < resultados.size() && resultados.get(indice) instanceof String;
        }
        private CallableStatement statement() {
            return proxy(CallableStatement.class,(p,m,a)->{
                switch (m.getName()) {
                    case "setInt": case "setString":
                        if ("parametro".equals(fallo)) throw new SQLException("PRIVADO parametro");
                        parametros.put((Integer)a[0],a[1]); return null;
                    case "execute":
                        if (codigoCambio != 0) throw new SQLException("PRIVADO servidor password SQL", "TEST",codigoCambio);
                        if (conteos) resultados.add(0);
                        if (!sinResultado) resultados.add("principal");
                        if (conteos) resultados.add(2);
                        if (extra) resultados.add("adicional");
                        return esResultado();
                    case "getMoreResults":
                        indice++;
                        if ("final".equals(fallo)) throw new SQLException("PRIVADO final");
                        return esResultado();
                    case "getUpdateCount":
                        return indice >= resultados.size() || esResultado() ? -1 : (Integer)resultados.get(indice);
                    case "getResultSet": return resultado(indice);
                    case "close": cerrar("statement"); return null;
                    default: throw new AssertionError("Statement " + m.getName());
                }
            });
        }
        private ResultSet resultado(int numero) {
            String nombre = "rs" + numero;
            abiertos.add(nombre);
            int[] pos = {0}; boolean[] nulo = {false};
            return proxy(ResultSet.class,(p,m,a)->{
                switch (m.getName()) {
                    case "next":
                        if ("lectura".equals(fallo)) throw new SQLException("PRIVADO lectura");
                        return ++pos[0] <= filas;
                    case "getInt": case "getBoolean":
                        String columna = (String)a[0];
                        if (!fila.containsKey(columna)) throw new SQLException("PRIVADO columna");
                        columnas.add(columna);
                        Object valor = fila.get(columna); nulo[0] = valor == null;
                        if (valor != null) return valor;
                        if ("getInt".equals(m.getName())) return Integer.valueOf(0);
                        return Boolean.FALSE;
                    case "wasNull": return nulo[0];
                    case "close": cerrar(nombre); return null;
                    default: throw new AssertionError("ResultSet " + m.getName());
                }
            });
        }
        void comprobarRecursos() {
            exigir(abiertos.equals(cerrados),"Cerrar todos los recursos JDBC");
            if (sql != null) {
                exigir("{call dbo.sp_CambiarContrasenaUsuario(?, ?)}".equals(sql),"Procedimiento exacto");
                if (!"parametro".equals(fallo)) {
                    exigir(parametros.size() == 2 && Integer.valueOf(7).equals(parametros.get(1)),"Parametros exactos");
                    exigir(hashRecibido.equals(parametros.get(2)),"Solo hash al parametro 2");
                }
            }
        }
    }
    private static class Entrada {
        Object id = 7, correo = CORREO, rol = "USUARIO";
        boolean sesion = true, expirada, get, errorRequest;
        String actual = ACTUAL, nueva = NUEVA, confirmar = NUEVA;
    }
    private static class Salida {
        int estado = 200, sesiones;
        String tipo, encoding;
        final Map<String,String> headers = new HashMap<>();
        final StringWriter cuerpo = new StringWriter();
        JsonNode json;
    }
    private static Salida ejecutar(Entrada e, Jdbc jdbc, int esperado) throws Exception {
        CambiarContrasenaUsuarioServlet servlet = new CambiarContrasenaUsuarioServlet();
        servlet.init();
        Field campo = CambiarContrasenaUsuarioServlet.class.getDeclaredField("usuarioServicio");
        campo.setAccessible(true); campo.set(servlet,new UsuarioServicio(jdbc));
        Salida s = new Salida();
        HttpSession sesion = proxy(HttpSession.class,(p,m,a)->{
            exigir("getAttribute".equals(m.getName()),"No mutar, invalidar ni guardar secretos en sesion");
            if (e.expirada) throw new IllegalStateException("Expirada");
            switch ((String)a[0]) {
                case "idUsuario": return e.id;
                case "correo": return e.correo;
                case "rol": return e.rol;
                default: throw new AssertionError("Atributo inesperado");
            }
        });
        HttpServletRequest req = proxy(HttpServletRequest.class,(p,m,a)->{
            switch (m.getName()) {
                case "setCharacterEncoding": s.encoding=(String)a[0]; return null;
                case "getSession":
                    exigir(a != null && a.length == 1 && Boolean.FALSE.equals(a[0]),"No crear sesion");
                    s.sesiones++;
                    if (e.errorRequest) throw new IllegalStateException("PRIVADO request");
                    return e.sesion ? sesion : null;
                case "getParameter":
                    exigir("UTF-8".equals(s.encoding),"Encoding antes de leer claves");
                    switch ((String)a[0]) {
                        case "contrasenaActual": return e.actual;
                        case "nuevaContrasena": return e.nueva;
                        case "confirmarContrasena": return e.confirmar;
                        default: throw new AssertionError("Nunca leer idUsuario/correo del navegador");
                    }
                default: throw new AssertionError("No leer datos ajenos " + m.getName());
            }
        });
        HttpServletResponse resp = proxy(HttpServletResponse.class,(p,m,a)->{
            switch (m.getName()) {
                case "setStatus": s.estado=(Integer)a[0]; return null;
                case "setHeader": s.headers.put((String)a[0],(String)a[1]); return null;
                case "setContentType": s.tipo=(String)a[0]; return null;
                case "getWriter": return new PrintWriter(s.cuerpo);
                default: throw new AssertionError("Response " + m.getName());
            }
        });
        if (e.get) servlet.doGet(req,resp); else servlet.doPost(req,resp);
        exigir(s.estado == esperado,"HTTP esperado " + esperado + ", recibido " + s.estado);
        exigir(s.sesiones == (e.get ? 0 : 1),"Solo sesion existente");
        exigir("application/json;charset=UTF-8".equals(s.tipo),"Content-Type");
        exigir("no-store".equals(s.headers.get("Cache-Control")),"No store");
        s.json = JSON.readTree(s.cuerpo.toString());
        exigir(s.json.size() == 2 && s.json.get("ok").asBoolean() == (esperado == 200),"JSON exacto");
        if (esperado == 200) {
            exigir(s.json.get("contrasenaActualizada").asBoolean(),"Cambio confirmado");
            exigir(jdbc.consultas == 1 && jdbc.cambios == 1 && jdbc.conexiones == 1,"Una consulta y un cambio");
            exigir(jdbc.columnas.equals(jdbc.fila.keySet()),"Todas las columnas");
        } else exigir(s.json.get("mensaje").isTextual(),"Error generico");
        if (jdbc.consultas > 0) {
            exigir(((String)e.correo).trim().toLowerCase(Locale.ROOT).equals(jdbc.correoConsultado),
                    "Correo exclusivo de sesion");
        }
        if (jdbc.hashRecibido != null) {
            exigir(!jdbc.hashRecibido.equals(e.nueva) && jdbc.hashRecibido.startsWith("$2a$12$"),"Hash coste12");
            exigir(EncriptadorContrasena.verificar(e.nueva,jdbc.hashRecibido),"Nueva clave valida con BCrypt");
            exigir(!EncriptadorContrasena.verificar(ACTUAL,jdbc.hashRecibido),"No conservar clave anterior");
        }
        sinSecretos(s.cuerpo.toString(),jdbc.hashRecibido);
        jdbc.comprobarRecursos();
        casos++;
        return s;
    }
    private static void sinSecretos(String texto, String hashNuevo) {
        exigir(!texto.contains(ACTUAL) && !texto.contains(NUEVA) && !texto.contains(HASH)
                && !texto.contains(HASH_NUEVO) && !texto.contains("PRIVADO")
                && (hashNuevo == null || !texto.contains(hashNuevo)), "Sin secretos");
    }
    private static void rechazo(Entrada e, Jdbc jdbc, int estado, boolean consulta) throws Exception {
        ejecutar(e,jdbc,estado);
        exigir(jdbc.cambios == 0 && jdbc.conexiones == 0,"Rechazo nunca llama SP de cambio");
        exigir(jdbc.consultas == (consulta ? 1 : 0),"Consultas esperadas");
    }
    private static void falloDao(Jdbc jdbc) throws Exception {
        try { jdbc.cambiarContrasenaUsuario(7,HASH_NUEVO); throw new AssertionError("Falta SQLException"); }
        catch (SQLException esperado) { jdbc.comprobarRecursos(); casos++; }
    }
    public static void main(String[] args) throws Exception {
        List<String> logs = new ArrayList<>();
        Logger logger = Logger.getLogger(CambiarContrasenaUsuarioServlet.class.getName());
        Handler handler = new Handler() {
            @Override public void publish(LogRecord r) { logs.add(r.getMessage()); }
            @Override public void flush() { }
            @Override public void close() { }
        };
        logger.addHandler(handler);
        try {
            exigir(Arrays.asList(CambiarContrasenaUsuarioServlet.class.getAnnotation(WebServlet.class).value())
                    .contains("/usuario/seguridad/cambiar-contrasena"),"Mapping");
            Entrada e = new Entrada(); e.get = true;
            Salida s = ejecutar(e,new Jdbc(),405);
            exigir("POST".equals(s.headers.get("Allow")),"Allow POST");
            e = new Entrada(); e.sesion = false; rechazo(e,new Jdbc(),401,false);
            for (Object id : new Object[]{null,0,-1,"", "abc",1.5,Long.MAX_VALUE,Double.NaN,new Object()}) {
                e = new Entrada(); e.id=id; rechazo(e,new Jdbc(),401,false);
            }
            for (Object correo : new Object[]{null,""," ","abc","a@@b.test","a b@c.test","a".repeat(151)+"@b.test",7}) {
                e = new Entrada(); e.correo=correo; rechazo(e,new Jdbc(),401,false);
            }
            for (Object rol : new Object[]{null,"ADMINISTRADOR","OPERADOR_EVENTOS","CAJERO","AUDITOR","CASA","usuario"}) {
                e = new Entrada(); e.rol=rol; rechazo(e,new Jdbc(),403,false);
            }
            e = new Entrada(); e.expirada=true; rechazo(e,new Jdbc(),401,false);
            e = new Entrada(); e.errorRequest=true; rechazo(e,new Jdbc(),500,false);
            for (String vacia : new String[]{null,""," "}) {
                e = new Entrada(); e.actual=vacia; rechazo(e,new Jdbc(),400,false);
                e = new Entrada(); e.nueva=vacia; rechazo(e,new Jdbc(),400,false);
                e = new Entrada(); e.confirmar=vacia; rechazo(e,new Jdbc(),400,false);
            }
            for (String nueva : new String[]{"1234567","        ","a".repeat(73),"á".repeat(37)}) {
                e = new Entrada(); e.nueva=nueva; e.confirmar=nueva; rechazo(e,new Jdbc(),400,false);
            }
            e = new Entrada(); e.confirmar="Distinta-789"; rechazo(e,new Jdbc(),400,false);
            Jdbc j = new Jdbc(); j.usuario=null; rechazo(new Entrada(),j,401,true);
            j = new Jdbc(); j.usuario=usuario(8,CORREO,HASH,"USUARIO"); rechazo(new Entrada(),j,401,true);
            for (String correo : new String[]{null,"otro@example.test","cliente@otro.test"}) {
                j = new Jdbc(); j.usuario=usuario(7,correo,HASH,"USUARIO"); rechazo(new Entrada(),j,401,true);
            }
            j = new Jdbc(); j.usuario=usuario(7,CORREO,HASH,"ADMINISTRADOR"); rechazo(new Entrada(),j,401,true);
            for (String hash : new String[]{null,"","texto-plano","$2a$12$corto",
                    HASH.substring(0,59)+"!",HASH.replace("$04$","$99$")}) {
                j = new Jdbc(); j.usuario=usuario(7,CORREO,hash,"USUARIO"); rechazo(new Entrada(),j,500,true);
            }
            e = new Entrada(); e.actual="Incorrecta-123"; rechazo(e,new Jdbc(),401,true);
            j = new Jdbc(); j.codigoConsulta=99999; rechazo(new Entrada(),j,500,true);
            j = new Jdbc(); j.runtimeConsulta=true; rechazo(new Entrada(),j,500,true);

            ejecutar(new Entrada(),new Jdbc(),200);
            e = new Entrada(); e.correo=" CLIENTE@EXAMPLE.TEST "; e.id="7"; ejecutar(e,new Jdbc(),200);
            for (String nueva : new String[]{"12345678","a".repeat(72),"á".repeat(36)}) {
                e = new Entrada(); e.nueva=nueva; e.confirmar=nueva; ejecutar(e,new Jdbc(),200);
            }
            for (int codigo : new int[]{57023,57024,57025,99999}) {
                j = new Jdbc(); j.codigoCambio=codigo;
                ejecutar(new Entrada(),j,codigo == 57025 ? 401 : codigo == 99999 ? 500 : 400);
            }
            j = new Jdbc(); j.fila.put("IdUsuario",9); ejecutar(new Entrada(),j,500);
            j = new Jdbc(); j.fila.put("ContrasenaActualizada",null); ejecutar(new Entrada(),j,500);
            j = new Jdbc(); j.fila.put("ContrasenaActualizada",false); ejecutar(new Entrada(),j,500);
            j = new Jdbc(); j.extra=true; ejecutar(new Entrada(),j,500);
            j = new Jdbc(); j.conteos=true; ejecutar(new Entrada(),j,200);

            for (String columna : new String[]{"IdUsuario","ContrasenaActualizada"}) {
                j = new Jdbc(); j.fila.put(columna,null); falloDao(j);
                j = new Jdbc(); j.fila.remove(columna); falloDao(j);
            }
            j = new Jdbc(); j.filas=0; falloDao(j);
            j = new Jdbc(); j.filas=2; falloDao(j);
            j = new Jdbc(); j.sinResultado=true; falloDao(j);
            j = new Jdbc(); j.extra=true; j.conteos=true; falloDao(j);
            for (String fallo : new String[]{"conexion","preparar","parametro","lectura","final"}) {
                j = new Jdbc(); j.fallo=fallo; falloDao(j);
            }
            for (String hash : new String[]{null,"",NUEVA,HASH}) {
                j = new Jdbc();
                try { j.cambiarContrasenaUsuario(7,hash); throw new AssertionError("No aceptar texto o hash no generado"); }
                catch (IllegalArgumentException esperado) { exigir(j.conexiones == 0,"DAO sin SQL"); casos++; }
            }
            for (int id : new int[]{0,-1}) {
                j = new Jdbc();
                try { new UsuarioServicio(j).cambiarContrasenaUsuario(id,CORREO,ACTUAL,NUEVA,NUEVA);
                    throw new AssertionError("Id invalido"); }
                catch (IllegalArgumentException esperado) { exigir(j.consultas == 0 && j.cambios == 0,"Servicio valida"); casos++; }
            }
            j = new Jdbc();
            try { new UsuarioServicio(j).cambiarContrasenaUsuario(7,CORREO,ACTUAL,"corta","corta");
                throw new AssertionError("Clave invalida"); }
            catch (IllegalArgumentException esperado) { exigir(j.consultas == 0,"Servicio valida clave"); casos++; }
            for (String log : logs) sinSecretos(log,null);
            System.out.println("OK: " + casos + " casos controlados de cambio de contrasena, sin SQL real.");
        } finally { logger.removeHandler(handler); }
    }
}
