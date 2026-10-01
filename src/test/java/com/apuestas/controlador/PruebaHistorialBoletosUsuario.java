package com.apuestas.controlador;

import com.apuestas.dao.AnaliticaUsuarioDAO;
import com.apuestas.modelo.AnaliticaBoletoUsuario;
import com.apuestas.servicio.AnaliticaUsuarioServicio;
import com.fasterxml.jackson.databind.*;
import java.io.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.sql.*;
import java.time.format.DateTimeFormatter;
import java.util.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

/** Prueba manual con JDBC y HTTP controlados: nunca abre SQL real. */
public class PruebaHistorialBoletosUsuario {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static int casos;
    private static void exigir(boolean condicion, String mensaje) {
        if (!condicion) throw new AssertionError(mensaje);
    }
    @SuppressWarnings("unchecked")
    private static <T> T proxy(Class<T> tipo, InvocationHandler manejador) {
        return (T) Proxy.newProxyInstance(tipo.getClassLoader(), new Class<?>[]{tipo}, manejador);
    }
    private static Map<String, Object> resumen(int id) {
        Map<String, Object> fila = new LinkedHashMap<>();
        fila.put("IdBoleto", id);
        fila.put("CodigoBoleto", "B-" + id);
        fila.put("TipoBoleto", "TipoBoleto áñ");
        fila.put("Resultado", "Resultado áñ");
        fila.put("EstadoBoleto", "EstadoBoleto áñ");
        fila.put("FechaCreacion", Timestamp.valueOf("2026-09-28 10:20:30.1234567"));
        fila.put("FechaLiquidacion", null);
        fila.put("MontoApostado", new BigDecimal("27.17"));
        fila.put("ComisionServicio", new BigDecimal("28.18"));
        fila.put("TotalCargo", new BigDecimal("29.19"));
        fila.put("CuotaTotal", new BigDecimal("30.20"));
        fila.put("PremioPotencial", new BigDecimal("31.21"));
        fila.put("GananciaNetaPotencial", new BigDecimal("32.22"));
        fila.put("PorcentajeGananciaPotencial", new BigDecimal("33.23"));
        fila.put("ProbabilidadImplicitaPorcentaje", new BigDecimal("34.24"));
        fila.put("CantidadSelecciones", 3);
        return fila;
    }
    private static Map<String, Object> detalle(int id, int idDetalle) {
        Map<String, Object> fila = new LinkedHashMap<>();
        fila.put("IdBoleto", id);
        fila.put("CodigoBoleto", "B-" + id);
        fila.put("IdDetalle", 3);
        fila.put("IdDeporte", 4);
        fila.put("Deporte", "Deporte áñ");
        fila.put("IdLiga", 6);
        fila.put("Liga", "Liga áñ");
        fila.put("IdEvento", 8);
        fila.put("Evento", "Evento áñ");
        fila.put("FechaInicio", Timestamp.valueOf("2026-09-28 10:20:30.1234567"));
        fila.put("IdMercado", 11);
        fila.put("Mercado", "Mercado áñ");
        fila.put("IdSeleccion", 13);
        fila.put("Seleccion", "Seleccion áñ");
        fila.put("CuotaAplicada", new BigDecimal("34.24"));
        fila.put("ProbabilidadImplicitaSeleccionPorcentaje", new BigDecimal("35.25"));
        fila.put("ResultadoSeleccion", "ResultadoSeleccion áñ");
        fila.put("IdDetalle", idDetalle);
        return fila;
    }

    private static class Jdbc extends AnaliticaUsuarioDAO {
        final List<Map<String, Object>> resumenes = new ArrayList<>();
        final List<Map<String, Object>> detalles = new ArrayList<>();
        final List<Object> resultados = new ArrayList<>();
        final Map<Integer, Object> parametros = new HashMap<>();
        final Map<Integer, Integer> tipos = new HashMap<>();
        final Set<String> abiertos = new HashSet<>(), cerrados = new HashSet<>();
        final Set<String> columnas = new HashSet<>();
        int conexiones, codigo, indice, falloResultado = -1;
        boolean runtime, faltaPrimero, faltaSegundo, extra, conteos, errorFinal, preparado;
        String sql;
        Jdbc() { resumenes.add(resumen(70)); detalles.add(detalle(70, 8)); }

        @Override protected Connection obtenerConexion() throws SQLException {
            conexiones++;
            if (runtime) throw new IllegalStateException("PRIVADO runtime");
            if (preparado) throw new SQLException("PRIVADO conexion");
            abiertos.add("conexion");
            return proxy(Connection.class, (p,m,a) -> {
                switch (m.getName()) {
                    case "prepareCall":
                        sql = (String)a[0];
                        abiertos.add("statement");
                        return statement();
                    case "close": cerrar("conexion"); return null;
                    default: throw new AssertionError("Conexion " + m.getName());
                }
            });
        }
        private void cerrar(String nombre) {
            exigir(cerrados.add(nombre), "Cierre duplicado " + nombre);
        }
        private boolean esResultado() {
            return indice < resultados.size() && resultados.get(indice) instanceof List;
        }
        private CallableStatement statement() {
            return proxy(CallableStatement.class, (p,m,a) -> {
                switch (m.getName()) {
                    case "setInt": parametros.put((Integer)a[0],a[1]); return null;
                    case "setNull":
                        parametros.put((Integer)a[0],null); tipos.put((Integer)a[0],(Integer)a[1]); return null;
                    case "execute":
                        if (codigo != 0) throw new SQLException("PRIVADO SQL servidor password", "TEST", codigo);
                        if (conteos) resultados.add(0);
                        if (!faltaPrimero) resultados.add(resumenes);
                        if (conteos) resultados.add(3);
                        if (!faltaPrimero && !faltaSegundo) resultados.add(detalles);
                        if (conteos) resultados.add(0);
                        if (extra) resultados.add(Collections.emptyList());
                        return esResultado();
                    case "getUpdateCount":
                        return indice >= resultados.size() || esResultado() ? -1 : (Integer)resultados.get(indice);
                    case "getMoreResults":
                        indice++;
                        if (errorFinal && indice >= resultados.size()) throw new SQLException("PRIVADO tardio");
                        return esResultado();
                    case "getResultSet": return resultado(indice);
                    case "close": cerrar("statement"); return null;
                    default: throw new AssertionError("Statement " + m.getName());
                }
            });
        }
        @SuppressWarnings("unchecked")
        private ResultSet resultado(int numero) {
            String nombre = "rs" + numero;
            abiertos.add(nombre);
            List<Map<String,Object>> filas = (List<Map<String,Object>>)resultados.get(numero);
            int[] pos = {-1};
            boolean[] nulo = {false};
            return proxy(ResultSet.class, (p,m,a) -> {
                switch (m.getName()) {
                    case "next":
                        if (falloResultado == numero) throw new SQLException("PRIVADO lectura");
                        return ++pos[0] < filas.size();
                    case "close": cerrar(nombre); return null;
                    case "wasNull": return nulo[0];
                    case "getInt": case "getString": case "getBigDecimal": case "getTimestamp":
                        String columna = (String)a[0];
                        Map<String,Object> fila = filas.get(pos[0]);
                        if (!fila.containsKey(columna)) throw new SQLException("PRIVADO columna");
                        columnas.add((filas == resumenes ? "r:" : "d:") + columna);
                        Object valor = fila.get(columna);
                        nulo[0] = valor == null;
                        return valor == null && m.getName().equals("getInt") ? Integer.valueOf(0) : valor;
                    default: throw new AssertionError("ResultSet " + m.getName());
                }
            });
        }
    }
    private static class Entrada {
        boolean sesion = true, expirada;
        Object id = 7, rol = "USUARIO";
        String deporte;
    }
    private static class Salida {
        int estado = 200;
        String tipo;
        final Map<String,String> headers = new HashMap<>();
        final StringWriter cuerpo = new StringWriter();
        JsonNode json;
    }
    private static Salida ejecutar(Entrada e, Jdbc jdbc, int esperado) throws Exception {
        HistorialBoletosUsuarioServlet servlet = new HistorialBoletosUsuarioServlet();
        servlet.init();
        Field campo = HistorialBoletosUsuarioServlet.class.getDeclaredField("analiticaServicio");
        campo.setAccessible(true);
        campo.set(servlet, new AnaliticaUsuarioServicio(jdbc));
        Salida s = new Salida();
        HttpSession sesion = proxy(HttpSession.class, (p,m,a) -> {
            exigir(m.getName().equals("getAttribute"), "No cambiar sesion");
            if (e.expirada) throw new IllegalStateException("Expirada");
            if ("idUsuario".equals(a[0])) return e.id;
            if ("rol".equals(a[0])) return e.rol;
            throw new AssertionError("Atributo innecesario");
        });
        HttpServletRequest req = proxy(HttpServletRequest.class, (p,m,a) -> {
            if (m.getName().equals("getSession")) {
                exigir(a != null && a.length == 1 && Boolean.FALSE.equals(a[0]), "Nunca crear sesion");
                return e.sesion ? sesion : null;
            }
            if (m.getName().equals("getParameter")) {
                exigir("idDeporte".equals(a[0]), "Nunca leer identidad ni otro filtro del navegador");
                return e.deporte;
            }
            throw new AssertionError("No leer body, headers, cookies: " + m.getName());
        });
        HttpServletResponse resp = proxy(HttpServletResponse.class, (p,m,a) -> {
            switch (m.getName()) {
                case "setContentType": s.tipo = (String)a[0]; return null;
                case "setHeader": s.headers.put((String)a[0],(String)a[1]); return null;
                case "setStatus": s.estado = (Integer)a[0]; return null;
                case "getWriter": return new PrintWriter(s.cuerpo);
                default: throw new AssertionError("Response " + m.getName());
            }
        });
        servlet.doGet(req, resp);
        exigir(s.estado == esperado, "HTTP esperado " + esperado + ", recibido " + s.estado);
        exigir("application/json;charset=UTF-8".equals(s.tipo), "Content-Type");
        exigir("no-store".equals(s.headers.get("Cache-Control")), "Cache-Control");
        exigir(!s.cuerpo.toString().contains("PRIVADO"), "No filtrar excepciones");
        s.json = JSON.readTree(s.cuerpo.toString());
        exigir(s.json.get("ok").asBoolean() == (esperado == 200), "ok");
        exigir(jdbc.abiertos.equals(jdbc.cerrados), "Recursos cerrados: " + jdbc.abiertos + "/" + jdbc.cerrados);
        if (jdbc.sql != null) {
            exigir("{call dbo.sp_ObtenerAnaliticaBoletosUsuario(?, ?)}".equals(jdbc.sql), "Procedimiento");
            exigir(Integer.valueOf(7).equals(jdbc.parametros.get(1)), "Identidad exclusiva sesion");
            exigir(jdbc.parametros.containsKey(2), "Parametro deporte");
            if (e.deporte == null) {
                exigir(jdbc.parametros.get(2) == null && jdbc.tipos.get(2) == Types.INTEGER, "NULL INTEGER");
            } else exigir(Integer.valueOf(e.deporte).equals(jdbc.parametros.get(2)), "Deporte exacto");
        }
        casos++;
        return s;
    }
    private static void columnas(Map<String,Object> fila, JsonNode json, boolean detalle) {
        int omitidas = 0;
        for (Map.Entry<String,Object> columna : fila.entrySet()) {
            String nombre = columna.getKey();
            if (detalle && (nombre.equals("IdBoleto") || nombre.equals("CodigoBoleto"))) {
                omitidas++; continue;
            }
            String clave = Character.toLowerCase(nombre.charAt(0)) + nombre.substring(1);
            JsonNode valor = json.get(clave);
            exigir(valor != null, "Campo " + clave);
            Object original = columna.getValue();
            if (original == null) exigir(valor.isNull(), "NULL " + clave);
            else if (original instanceof BigDecimal) {
                exigir(valor.isNumber() && valor.decimalValue().compareTo((BigDecimal)original) == 0, "Decimal " + clave);
            } else if (original instanceof Integer) {
                exigir(valor.isIntegralNumber() && valor.intValue() == (Integer)original, "Entero " + clave);
            } else if (original instanceof Timestamp) {
                exigir(valor.asText().equals(DateTimeFormatter.ISO_LOCAL_DATE_TIME.format(
                        ((Timestamp)original).toLocalDateTime())), "Fecha ISO " + clave);
            } else exigir(valor.asText().equals(original), "Texto " + clave);
        }
        exigir(json.size() == fila.size() - omitidas + (detalle ? 0 : 1), "Campos exactos");
    }

    public static void main(String[] args) throws Exception {
        exigir(Arrays.asList(HistorialBoletosUsuarioServlet.class.getAnnotation(WebServlet.class).value())
                .contains("/usuario/boletos/historial"), "Mapping");
        Entrada e = new Entrada();
        e.sesion = false; Jdbc j = new Jdbc(); ejecutar(e,j,401); exigir(j.conexiones == 0,"No SQL");
        for (Object id : new Object[]{null,0,-1,"abc","",new Object(),1.5,Long.MAX_VALUE,"2147483648",Double.NaN}) {
            e = new Entrada(); e.id = id; j = new Jdbc(); ejecutar(e,j,401); exigir(j.conexiones == 0,"No SQL");
        }
        e = new Entrada(); e.expirada = true; ejecutar(e,new Jdbc(),401);
        for (Object rol : new Object[]{null,"ADMINISTRADOR","OPERADOR_EVENTOS","CAJERO","AUDITOR","CASA","usuario"}) {
            e = new Entrada(); e.rol = rol; j = new Jdbc(); ejecutar(e,j,403); exigir(j.conexiones == 0,"Rol sin SQL");
        }
        for (String filtro : new String[]{"0","-1","abc",""," ","1.5","+1","2147483648"}) {
            e = new Entrada(); e.deporte = filtro; j = new Jdbc(); ejecutar(e,j,400); exigir(j.conexiones == 0,"Filtro sin SQL");
        }
        for (int codigo : new int[]{64001,64002,64003,99999}) {
            j = new Jdbc(); j.codigo = codigo;
            ejecutar(new Entrada(),j,codigo == 64002 ? 401 : codigo == 99999 ? 500 : 400);
        }
        j = new Jdbc(); j.runtime = true; ejecutar(new Entrada(),j,500);
        j = new Jdbc(); j.preparado = true; ejecutar(new Entrada(),j,500);
        j = new Jdbc(); j.resumenes.clear(); j.detalles.clear();
        Salida s = ejecutar(new Entrada(),j,200);
        exigir(s.json.get("idDeporte").isNull() && s.json.get("cantidadBoletos").asInt() == 0
                && s.json.get("boletos").isArray() && s.json.get("boletos").isEmpty(),"Vacio");

        j = new Jdbc(); s = ejecutar(new Entrada(),j,200);
        JsonNode boleto = s.json.get("boletos").get(0);
        columnas(j.resumenes.get(0),boleto,false);
        columnas(j.detalles.get(0),boleto.get("detalles").get(0),true);
        for (String c : j.resumenes.get(0).keySet()) exigir(j.columnas.contains("r:"+c),"Columna SQL resumen " + c);
        for (String c : j.detalles.get(0).keySet()) exigir(j.columnas.contains("d:"+c),"Columna SQL detalle " + c);
        exigir(s.json.get("cantidadBoletos").asInt() == 1,"Cantidad real");

        e = new Entrada(); e.deporte = "4"; j = new Jdbc();
        j.resumenes.get(0).put("TipoBoleto","COMPUESTO");
        s = ejecutar(e,j,200); boleto = s.json.get("boletos").get(0);
        exigir(s.json.get("idDeporte").asInt() == 4,"Filtro devuelto");
        exigir(boleto.get("cantidadSelecciones").asInt() == 3 && boleto.get("detalles").size() == 1,"Multideporte");

        j = new Jdbc(); j.resumenes.clear(); j.detalles.clear();
        j.resumenes.add(resumen(90)); j.resumenes.add(resumen(80)); j.resumenes.add(resumen(70));
        j.detalles.add(detalle(90,1)); j.detalles.add(detalle(90,2)); j.detalles.add(detalle(70,3));
        s = ejecutar(new Entrada(),j,200);
        exigir(s.json.get("cantidadBoletos").asInt() == 3,"Tres boletos");
        for (int i = 0; i < 3; i++) exigir(s.json.get("boletos").get(i).get("idBoleto").asInt() == 90-i*10,"Orden SQL");
        exigir(s.json.get("boletos").get(1).get("detalles").isEmpty(),"Boleto sin detalles conservado");
        exigir(s.json.get("boletos").get(0).get("detalles").get(1).get("idDetalle").asInt() == 2,"Orden detalles");
        exigir(s.json.get("boletos").get(2).get("detalles").get(0).get("idDetalle").asInt() == 3,"Asociacion");

        j = new Jdbc();
        j.resumenes.get(0).put("FechaLiquidacion",Timestamp.valueOf("2026-09-30 12:00:00"));
        j.resumenes.get(0).put("PorcentajeGananciaPotencial",null);
        j.resumenes.get(0).put("ProbabilidadImplicitaPorcentaje",null);
        j.detalles.get(0).put("ProbabilidadImplicitaSeleccionPorcentaje",null);
        s = ejecutar(new Entrada(),j,200);
        columnas(j.resumenes.get(0),s.json.get("boletos").get(0),false);
        columnas(j.detalles.get(0),s.json.get("boletos").get(0).get("detalles").get(0),true);

        j = new Jdbc(); j.conteos = true; ejecutar(new Entrada(),j,200);
        j = new Jdbc(); j.faltaPrimero = true; ejecutar(new Entrada(),j,500);
        j = new Jdbc(); j.faltaSegundo = true; ejecutar(new Entrada(),j,500);
        j = new Jdbc(); j.extra = true; ejecutar(new Entrada(),j,500);
        j = new Jdbc(); j.errorFinal = true; ejecutar(new Entrada(),j,500);
        for (int rs = 0; rs < 2; rs++) {
            j = new Jdbc(); j.falloResultado = rs; ejecutar(new Entrada(),j,500);
        }
        j = new Jdbc(); j.detalles.get(0).put("IdBoleto",999); ejecutar(new Entrada(),j,500);
        j = new Jdbc(); j.detalles.get(0).put("CodigoBoleto","OTRO"); ejecutar(new Entrada(),j,500);
        j = new Jdbc(); j.resumenes.add(resumen(70)); ejecutar(new Entrada(),j,500);
        j = new Jdbc(); j.detalles.add(detalle(70,8)); ejecutar(new Entrada(),j,500);
        j = new Jdbc(); e = new Entrada(); e.deporte = "8"; ejecutar(e,j,500);
        for (boolean esDetalle : new boolean[]{false,true}) {
            Map<String,Object> plantilla = esDetalle ? detalle(70,8) : resumen(70);
            for (String columna : plantilla.keySet()) {
                if (Arrays.asList("FechaLiquidacion","PorcentajeGananciaPotencial",
                        "ProbabilidadImplicitaPorcentaje","ProbabilidadImplicitaSeleccionPorcentaje").contains(columna)) continue;
                j = new Jdbc();
                (esDetalle ? j.detalles : j.resumenes).get(0).put(columna,null);
                ejecutar(new Entrada(),j,500);
            }
        }
        j = new Jdbc(); j.resumenes.get(0).remove("MontoApostado"); ejecutar(new Entrada(),j,500);
        for (int id : new int[]{0,-1}) {
            j = new Jdbc(); AnaliticaUsuarioServicio servicio = new AnaliticaUsuarioServicio(j);
            try { servicio.obtenerAnaliticaBoletosUsuario(id,null); throw new AssertionError("Usuario"); }
            catch (IllegalArgumentException esperado) { exigir(j.conexiones == 0,"Servicio antes DAO"); casos++; }
            try { servicio.obtenerAnaliticaBoletosUsuario(7,id); throw new AssertionError("Deporte"); }
            catch (IllegalArgumentException esperado) { exigir(j.conexiones == 0,"Servicio antes DAO"); casos++; }
        }
        for (Object id : new Object[]{"7",7L,new BigDecimal("7.00")}) {
            e = new Entrada(); e.id = id; ejecutar(e,new Jdbc(),200);
        }
        System.out.println("OK: " + casos + " casos controlados de historial, sin SQL real.");
    }
}
