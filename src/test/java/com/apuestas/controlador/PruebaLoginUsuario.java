package com.apuestas.controlador;

import com.apuestas.dao.UsuarioDAO;
import com.apuestas.modelo.ResultadoIntentoLogin;
import com.apuestas.modelo.ResultadoLogin;
import com.apuestas.modelo.UsuarioAutenticacion;
import com.apuestas.servicio.UsuarioServicio;
import java.lang.reflect.Field;
import java.lang.reflect.Proxy;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.*;
import javax.servlet.RequestDispatcher;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import org.mindrot.jbcrypt.BCrypt;

/**
 * Pruebas controladas sin modificar cuentas reales.
 * Ejecutar main con target/test-classes, target/classes, dependencias y servlet-api de Tomcat.
 * --sql ejecuta solamente la consulta oficial para un correo aleatorio inexistente.
 */
public class PruebaLoginUsuario {
    private static final String CLAVE = " ClaveLocal-á-123 ";
    private static final String HASH = BCrypt.hashpw(CLAVE, BCrypt.gensalt(4));
    private static final String RECHAZO =
            "No fue posible iniciar sesión con los datos proporcionados.";
    private static final LocalDateTime FUTURO = LocalDateTime.of(2099, 1, 1, 0, 0);
    private static int pruebas;

    private static void exigir(boolean condicion, String mensaje) {
        if (!condicion) throw new AssertionError(mensaje);
    }

    private static UsuarioAutenticacion usuario(String rol, String estado, String hash,
            boolean bloqueado, boolean habilitado, boolean verificado) {
        return new UsuarioAutenticacion(7, "cliente@example.test", hash, verificado,
                bloqueado ? 5 : 0, bloqueado ? FUTURO : null, null,
                3, rol, 1, estado, estado, bloqueado, habilitado);
    }

    private static ResultadoIntentoLogin intento(int id, int fallos, LocalDateTime hasta,
            boolean bloqueo, boolean permitido, String estado) {
        return new ResultadoIntentoLogin(id, fallos, hasta, bloqueo, permitido, estado);
    }

    private static class DaoControlado extends UsuarioDAO {
        UsuarioAutenticacion usuario = usuario("USUARIO", "ACTIVO", HASH, false, true, false);
        ResultadoIntentoLogin resultado = intento(7, 0, null, false, true, "ACTIVO");
        boolean errorConsulta, errorRegistro;
        int consultas, registros;
        Boolean exitoso;
        String correo, ip;

        @Override public UsuarioAutenticacion obtenerUsuarioAutenticacion(String correo)
                throws SQLException {
            consultas++;
            this.correo = correo;
            if (errorConsulta) throw new SQLException("NO MOSTRAR secreto SQL", "TEST", 57004);
            return usuario;
        }

        @Override public ResultadoIntentoLogin registrarIntentoLogin(
                int id, boolean exitoso, String ip) throws SQLException {
            exigir(id == 7, "IdUsuario enviado al DAO");
            registros++;
            this.exitoso = exitoso;
            this.ip = ip;
            if (errorRegistro) throw new SQLException("NO MOSTRAR secreto SQL", "TEST", 57005);
            return resultado;
        }
    }

    private static class Sesion {
        final Map<String, Object> atributos = new LinkedHashMap<>();
        boolean invalidada;
        final HttpSession proxy = (HttpSession) Proxy.newProxyInstance(
                getClass().getClassLoader(), new Class<?>[]{HttpSession.class},
                (obj, metodo, args) -> {
                    switch (metodo.getName()) {
                        case "invalidate": invalidada = true; atributos.clear(); return null;
                        case "setAttribute":
                            exigir(!invalidada, "Escritura en sesion invalidada");
                            atributos.put((String) args[0], args[1]); return null;
                        case "getAttribute": return atributos.get(args[0]);
                        default: throw new AssertionError("Sesion: " + metodo.getName());
                    }
                });
    }

    private static class Intercambio {
        final Map<String, Object> atributos = new HashMap<>();
        final Map<String, String> headers = new HashMap<>();
        Sesion anterior, nueva;
        String ruta, encoding, tipo, contexto = "/PlataformaApuestas";
        int estado = 200;
        boolean forward;
    }

    private static Intercambio llamar(DaoControlado dao, String correo, String clave,
            boolean get, boolean previa, String contexto) throws Exception {
        LoginUsuarioServlet servlet = new LoginUsuarioServlet();
        servlet.init();
        Field servicio = LoginUsuarioServlet.class.getDeclaredField("usuarioServicio");
        servicio.setAccessible(true);
        servicio.set(servlet, new UsuarioServicio(dao));
        Intercambio i = new Intercambio();
        i.contexto = contexto;
        if (previa) {
            i.anterior = new Sesion();
            i.anterior.atributos.put("idUsuario", 999);
            i.anterior.atributos.put("atributoAjeno", "no copiar");
        }
        HttpServletRequest req = (HttpServletRequest) Proxy.newProxyInstance(
                PruebaLoginUsuario.class.getClassLoader(),
                new Class<?>[]{HttpServletRequest.class}, (obj, metodo, args) -> {
                    switch (metodo.getName()) {
                        case "setCharacterEncoding": i.encoding = (String) args[0]; return null;
                        case "getParameter":
                            exigir("UTF-8".equals(i.encoding), "Codificacion antes de parametros");
                            if ("correo".equals(args[0])) return correo;
                            if ("contrasena".equals(args[0])) return clave;
                            throw new AssertionError("Parametro inesperado: " + args[0]);
                        case "getRemoteAddr": return "127.0.0.1";
                        case "getContextPath": return i.contexto;
                        case "setAttribute": i.atributos.put((String) args[0], args[1]); return null;
                        case "getRequestDispatcher":
                            i.ruta = (String) args[0];
                            return Proxy.newProxyInstance(PruebaLoginUsuario.class.getClassLoader(),
                                    new Class<?>[]{RequestDispatcher.class}, (p, m, a) -> {
                                        exigir("forward".equals(m.getName()), "Usar forward");
                                        i.forward = true;
                                        return null;
                                    });
                        case "getSession":
                            boolean crear = args == null || args.length == 0 || (Boolean) args[0];
                            if (i.anterior != null && !i.anterior.invalidada) {
                                exigir(!crear, "Invalidar anterior antes de crear");
                                return i.anterior.proxy;
                            }
                            if (!crear) return null;
                            exigir(i.nueva == null, "Solo una sesion nueva");
                            i.nueva = new Sesion();
                            return i.nueva.proxy;
                        default: throw new AssertionError("Request: " + metodo.getName());
                    }
                });
        HttpServletResponse resp = (HttpServletResponse) Proxy.newProxyInstance(
                PruebaLoginUsuario.class.getClassLoader(),
                new Class<?>[]{HttpServletResponse.class}, (obj, metodo, args) -> {
                    switch (metodo.getName()) {
                        case "setStatus": i.estado = (Integer) args[0]; return null;
                        case "setHeader": i.headers.put((String) args[0], (String) args[1]); return null;
                        case "setContentType": i.tipo = (String) args[0]; return null;
                        default: throw new AssertionError("Response: " + metodo.getName());
                    }
                });
        if (get) servlet.doGet(req, resp); else servlet.doPost(req, resp);
        exigir("text/html;charset=UTF-8".equals(i.tipo), "Tipo HTML UTF-8");
        exigir("no-store".equals(i.headers.get("Cache-Control")), "No cache");
        pruebas++;
        return i;
    }

    private static Intercambio post(DaoControlado dao, String correo, String clave)
            throws Exception {
        return llamar(dao, correo, clave, false, true, "/PlataformaApuestas");
    }

    private static void error(Intercambio i, int estado, boolean generico) {
        exigir(i.estado == estado, "HTTP esperado " + estado + ", recibido " + i.estado);
        exigir(i.forward && "/usuario/login.jsp".equals(i.ruta), "Forward al formulario");
        exigir(i.nueva == null && !i.headers.containsKey("Location"), "Sin autenticacion parcial");
        String mensaje = (String) i.atributos.get("error");
        exigir(mensaje != null && !mensaje.contains("secreto") && !mensaje.contains(HASH),
                "Mensaje sin secretos");
        if (generico) exigir(RECHAZO.equals(mensaje), "Mensaje de rechazo uniforme");
    }

    private static void exito(Intercambio i, String estado, boolean verificado) {
        exigir(i.estado == 303 && !i.forward, "Exito HTTP 303");
        exigir((i.contexto + "/usuario/inicio.jsp").equals(i.headers.get("Location")), "Location");
        exigir(i.nueva != null, "Sesion nueva");
        if (i.anterior != null) exigir(i.anterior.invalidada, "Sesion previa invalidada");
        Map<String, Object> esperados = new LinkedHashMap<>();
        esperados.put("idUsuario", Integer.valueOf(7));
        esperados.put("correo", "cliente@example.test");
        esperados.put("idRol", Integer.valueOf(3));
        esperados.put("rol", "USUARIO");
        esperados.put("estadoUsuario", estado);
        esperados.put("correoVerificado", Boolean.valueOf(verificado));
        exigir(esperados.equals(i.nueva.atributos), "Solo seis atributos y tipos correctos");
    }

    private static void casosServletServicio() throws Exception {
        exigir(Arrays.asList(LoginUsuarioServlet.class.getAnnotation(WebServlet.class).value())
                .contains("/usuario/login"), "Mapping");
        DaoControlado dao = new DaoControlado();
        Intercambio get = llamar(dao, null, null, true, false, "");
        exigir(get.estado == 200 && get.forward && "/usuario/login.jsp".equals(get.ruta)
                && dao.consultas == 0 && get.nueva == null, "GET");
        for (String correo : new String[]{null, "", " ", "abc", "a@@b.test",
                "a b@example.test", "a".repeat(151) + "@example.test"}) {
            dao = new DaoControlado();
            error(post(dao, correo, CLAVE), 400, false);
            exigir(dao.consultas == 0 && dao.registros == 0, "Validacion sin SQL");
        }
        for (String clave : new String[]{null, ""}) {
            dao = new DaoControlado();
            error(post(dao, "cliente@example.test", clave), 400, false);
            exigir(dao.consultas == 0, "Contrasena requerida");
        }
        dao = new DaoControlado();
        dao.usuario = null;
        error(post(dao, "ausente@example.test", CLAVE), 401, true);
        exigir(dao.registros == 0, "No registrar usuario inexistente");

        dao = new DaoControlado();
        dao.resultado = intento(7, 1, null, false, false, "ACTIVO");
        error(post(dao, "cliente@example.test", "incorrecta"), 401, true);
        exigir(dao.registros == 1 && Boolean.FALSE.equals(dao.exitoso), "Registrar fallo una vez");

        for (String estado : new String[]{"PENDIENTE", "ACTIVO"}) {
            for (boolean verificado : new boolean[]{false, true}) {
                dao = new DaoControlado();
                dao.usuario = usuario("USUARIO", estado, HASH, false, true, verificado);
                dao.resultado = intento(7, 0, null, false, true, estado);
                Intercambio i = post(dao, "  CLIENTE@EXAMPLE.TEST  ", CLAVE);
                exito(i, estado, verificado);
                exigir("cliente@example.test".equals(dao.correo), "Normalizar correo");
                exigir(dao.registros == 1 && Boolean.TRUE.equals(dao.exitoso)
                        && "127.0.0.1".equals(dao.ip), "Registrar exito e IP");
            }
        }
        dao = new DaoControlado();
        exito(llamar(dao, "cliente@example.test", CLAVE, false, false, ""), "ACTIVO", false);

        for (String rol : new String[]{"ADMINISTRADOR", "OPERADOR_EVENTOS",
                "CAJERO", "AUDITOR", "CASA", "usuario", "USUARIO "}) {
            dao = new DaoControlado();
            dao.usuario = usuario(rol, "ACTIVO", HASH, false, true, false);
            error(post(dao, "cliente@example.test", CLAVE), 401, true);
            exigir(dao.registros == 0, "Rol rechazado sin registrar exito");
        }
        for (String estado : new String[]{"SUSPENDIDO", "CERRADO"}) {
            dao = new DaoControlado();
            dao.usuario = usuario("USUARIO", estado, HASH, false, false, false);
            error(post(dao, "cliente@example.test", CLAVE), 401, true);
            exigir(dao.registros == 0, "Estado rechazado sin registrar exito");
        }
        for (String clave : new String[]{CLAVE, "incorrecta"}) {
            dao = new DaoControlado();
            dao.usuario = usuario("USUARIO", "ACTIVO", HASH, true, false, false);
            dao.resultado = intento(7, 5, FUTURO, true, false, "ACTIVO");
            error(post(dao, "cliente@example.test", clave), 401, true);
            exigir(dao.registros == 1 && dao.exitoso == CLAVE.equals(clave), "Bloqueo auditado");
        }
        // Bloqueo o estado cambiado despues de la primera consulta.
        for (ResultadoIntentoLogin resultado : Arrays.asList(
                intento(7, 5, FUTURO, true, false, "ACTIVO"),
                intento(7, 0, null, false, false, "SUSPENDIDO"),
                intento(7, 0, null, false, true, "CERRADO"),
                intento(7, 0, null, false, false, "ACTIVO"))) {
            dao = new DaoControlado();
            dao.resultado = resultado;
            error(post(dao, "cliente@example.test", CLAVE), 401, true);
        }
        // Respuestas ausentes, identificadores ajenos, nulos y combinaciones imposibles.
        for (ResultadoIntentoLogin resultado : Arrays.asList(
                null, intento(8, 0, null, false, true, "ACTIVO"),
                intento(7, -1, null, false, false, "ACTIVO"),
                intento(7, 0, null, false, true, null),
                intento(7, 0, null, false, true, ""),
                intento(7, 5, null, true, false, "ACTIVO"),
                intento(7, 5, FUTURO, true, true, "ACTIVO"),
                intento(7, 1, null, false, true, "ACTIVO"),
                intento(7, 0, FUTURO, false, true, "ACTIVO"))) {
            dao = new DaoControlado();
            dao.resultado = resultado;
            error(post(dao, "cliente@example.test", CLAVE), 500, false);
        }
        dao = new DaoControlado();
        error(post(dao, "cliente@example.test", "incorrecta"), 500, false);

        for (boolean consulta : new boolean[]{true, false}) {
            dao = new DaoControlado();
            dao.errorConsulta = consulta;
            dao.errorRegistro = !consulta;
            error(post(dao, "cliente@example.test", CLAVE), 500, false);
            exigir(dao.registros == (consulta ? 0 : 1), "Sin reintentos SQL");
        }
        for (String hash : new String[]{null, "", "texto-plano", "$2a$12$corto",
                HASH.substring(0, 59) + "!", HASH.replace("$04$", "$99$")}) {
            dao = new DaoControlado();
            dao.usuario = usuario("USUARIO", "ACTIVO", hash, false, true, false);
            error(post(dao, "cliente@example.test", CLAVE), 500, false);
            exigir(dao.registros == 0, "Hash corrupto no registra fallo de contrasena");
        }
        Set<String> campos = new HashSet<>();
        for (Field campo : ResultadoLogin.class.getDeclaredFields()) campos.add(campo.getName());
        exigir(campos.equals(new HashSet<>(Arrays.asList("autenticado", "idUsuario", "correo",
                "idRol", "rol", "estadoUsuario", "correoVerificado"))), "Resultado sin secretos");
    }

    /** Doble JDBC que ejecuta los metodos reales del DAO y exige consumir toda la fila. */
    private static class JdbcControlado extends UsuarioDAO {
        final Map<String, Object> fila = new LinkedHashMap<>();
        final Map<Integer, Object> parametros = new HashMap<>();
        final Set<String> leidas = new HashSet<>();
        String sql;
        int filas = 1, posicion;
        boolean nulo, sinResultado, extra, falloFinal;
        int cierres;

        @Override protected Connection obtenerConexion() {
            posicion = 0;
            ResultSet rs = (ResultSet) Proxy.newProxyInstance(getClass().getClassLoader(),
                    new Class<?>[]{ResultSet.class}, (p, m, a) -> {
                        switch (m.getName()) {
                            case "next": return ++posicion <= filas;
                            case "close": cierres++; return null;
                            case "wasNull": return nulo;
                            case "getInt": case "getBoolean": case "getString": case "getTimestamp":
                                String columna = (String) a[0];
                                if (!fila.containsKey(columna)) throw new SQLException("Columna faltante");
                                leidas.add(columna);
                                Object valor = fila.get(columna);
                                nulo = valor == null;
                                if (valor != null) return valor;
                                if ("getInt".equals(m.getName())) return 0;
                                if ("getBoolean".equals(m.getName())) return false;
                                return null;
                            default: throw new AssertionError(m.getName());
                        }
                    });
            CallableStatement cs = (CallableStatement) Proxy.newProxyInstance(
                    getClass().getClassLoader(), new Class<?>[]{CallableStatement.class},
                    (p, m, a) -> {
                        switch (m.getName()) {
                            case "setString": case "setInt": case "setBoolean":
                                parametros.put((Integer) a[0], a[1]); return null;
                            case "setNull": parametros.put((Integer) a[0], null); return null;
                            case "execute": return !sinResultado;
                            case "getResultSet": return rs;
                            case "getMoreResults":
                                if (falloFinal) throw new SQLException("Fallo despues de la fila");
                                return extra;
                            case "getUpdateCount": return -1;
                            case "close": cierres++; return null;
                            default: throw new AssertionError(m.getName());
                        }
                    });
            return (Connection) Proxy.newProxyInstance(getClass().getClassLoader(),
                    new Class<?>[]{Connection.class}, (p, m, a) -> {
                        switch (m.getName()) {
                            case "prepareCall": sql = (String) a[0]; return cs;
                            case "close": cierres++; return null;
                            default: throw new AssertionError(m.getName());
                        }
                    });
        }
    }

    private static JdbcControlado jdbc(boolean autenticacion) {
        JdbcControlado d = new JdbcControlado();
        d.fila.put("IdUsuario", 7);
        d.fila.put("IntentosFallidos", 0);
        d.fila.put("BloqueadoHasta", null);
        d.fila.put("BloqueoVigente", false);
        d.fila.put("EstadoUsuario", "ACTIVO");
        if (autenticacion) {
            d.fila.put("Correo", "cliente@example.test");
            d.fila.put("Contrasena", HASH);
            d.fila.put("CorreoVerificado", false);
            d.fila.put("UltimoAcceso", Timestamp.valueOf("2026-09-25 01:02:03"));
            d.fila.put("IdRol", 3);
            d.fila.put("Rol", "USUARIO");
            d.fila.put("IdEstado", 1);
            d.fila.put("NombreEstadoUsuario", "Activo");
            d.fila.put("PuedeIniciarSesion", true);
        } else {
            d.fila.put("AutenticacionPermitida", true);
        }
        return d;
    }

    private static void falloJdbc(JdbcControlado d, boolean autenticacion) throws Exception {
        try {
            if (autenticacion) d.obtenerUsuarioAutenticacion("cliente@example.test");
            else d.registrarIntentoLogin(7, true, null);
            throw new AssertionError("Se esperaba SQLException");
        } catch (SQLException esperado) {
            exigir(d.cierres >= 2, "Cerrar recursos en error");
        }
        pruebas++;
    }

    private static void casosDao() throws Exception {
        JdbcControlado d = jdbc(true);
        UsuarioAutenticacion u = d.obtenerUsuarioAutenticacion("cliente@example.test");
        exigir("{call dbo.sp_ObtenerUsuarioAutenticacion(?)}".equals(d.sql), "SP consulta oficial");
        exigir(d.parametros.get(1).equals("cliente@example.test"), "Correo parametrizado");
        exigir(d.leidas.equals(d.fila.keySet()) && d.cierres == 3, "Mapear 14 columnas y cerrar");
        exigir(u.getUltimoAcceso().equals(LocalDateTime.of(2026, 9, 25, 1, 2, 3))
                && u.getBloqueadoHasta() == null && HASH.equals(u.getHashContrasena()), "Fechas/hash");
        pruebas++;
        d = jdbc(false);
        ResultadoIntentoLogin r = d.registrarIntentoLogin(7, true, " 127.0.0.1 ");
        exigir("{call dbo.sp_RegistrarIntentoLogin(?, ?, ?)}".equals(d.sql), "SP intento oficial");
        exigir(d.parametros.get(1).equals(7) && d.parametros.get(2).equals(true)
                && d.parametros.get(3).equals("127.0.0.1"), "Parametros intento");
        exigir(d.leidas.equals(d.fila.keySet()) && d.cierres == 3
                && r.isAutenticacionPermitida(), "Mapear seis columnas y cerrar");
        pruebas++;
        d = jdbc(false);
        d.registrarIntentoLogin(7, false, " ");
        exigir(d.parametros.containsKey(3) && d.parametros.get(3) == null, "IP nullable");
        pruebas++;
        d = jdbc(true); d.filas = 0;
        exigir(d.obtenerUsuarioAutenticacion("ausente@example.test") == null, "Correo ausente");
        pruebas++;
        d = jdbc(false); d.filas = 0; falloJdbc(d, false);
        for (boolean auth : new boolean[]{true, false}) {
            d = jdbc(auth); d.filas = 2; falloJdbc(d, auth);
            d = jdbc(auth); d.sinResultado = true; falloJdbc(d, auth);
            d = jdbc(auth); d.extra = true; falloJdbc(d, auth);
            d = jdbc(auth); d.falloFinal = true; falloJdbc(d, auth);
            for (String campo : new ArrayList<>(jdbc(auth).fila.keySet())) {
                if ("BloqueadoHasta".equals(campo) || "UltimoAcceso".equals(campo)) continue;
                d = jdbc(auth); d.fila.put(campo, null); falloJdbc(d, auth);
                d = jdbc(auth); d.fila.remove(campo); falloJdbc(d, auth);
            }
        }
    }

    public static void main(String[] args) throws Exception {
        if (args.length == 1 && "--sql".equals(args[0])) {
            String correo = "prueba-" + UUID.randomUUID() + "@example.invalid";
            exigir(new UsuarioDAO().obtenerUsuarioAutenticacion(correo) == null,
                    "Consulta SQL para correo inexistente");
            System.out.println("OK SQL: consulta oficial sin usuario; no se registro ningun intento.");
            return;
        }
        casosServletServicio();
        casosDao();
        System.out.println("OK: " + pruebas + " casos controlados de servlet, servicio y contrato JDBC.");
    }
}
