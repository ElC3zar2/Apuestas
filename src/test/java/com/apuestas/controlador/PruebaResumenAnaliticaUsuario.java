package com.apuestas.controlador;

import com.apuestas.dao.AnaliticaUsuarioDAO;
import com.apuestas.servicio.AnaliticaUsuarioServicio;
import com.fasterxml.jackson.databind.*;
import java.io.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

/** Pruebas main de resumenes con HTTP/JDBC simulados; no conecta a SQL real. */
public class PruebaResumenAnaliticaUsuario {
    private static final ObjectMapper JSON = new ObjectMapper()
            .enable(DeserializationFeature.USE_BIG_DECIMAL_FOR_FLOATS);
    private static int casos;
    private static void exigir(boolean condicion, String mensaje) {
        if (!condicion) throw new AssertionError(mensaje);
    }
    @SuppressWarnings("unchecked")
    private static <T> T proxy(Class<T> tipo, InvocationHandler manejador) {
        return (T) Proxy.newProxyInstance(tipo.getClassLoader(), new Class<?>[]{tipo}, manejador);
    }
    private static Map<String,Object> deporte() {
        Map<String,Object> fila = new LinkedHashMap<>();
        fila.put("IdDeporte", 1);
        fila.put("Deporte", "Futbol");
        fila.put("CantidadBoletos", 3);
        fila.put("BoletosPendientes", 4);
        fila.put("BoletosGanadores", 5);
        fila.put("BoletosPerdedores", 6);
        fila.put("BoletosAnulados", 7);
        fila.put("CantidadSelecciones", 8);
        fila.put("SeleccionesPendientes", 9);
        fila.put("SeleccionesGanadas", 10);
        fila.put("SeleccionesPerdidas", 11);
        fila.put("SeleccionesAnuladas", 12);
        fila.put("CuotaPromedio", new BigDecimal("32.2200"));
        fila.put("ProbabilidadImplicitaPromedio", new BigDecimal("33.2300"));
        fila.put("PorcentajeEfectividad", new BigDecimal("34.2400"));
        return fila;
    }
    private static Map<String,Object> general() {
        Map<String,Object> fila = new LinkedHashMap<>();
        fila.put("CantidadBoletos", 1);
        fila.put("BoletosPendientes", 2);
        fila.put("BoletosGanadores", 3);
        fila.put("BoletosPerdedores", 4);
        fila.put("BoletosAnulados", 5);
        fila.put("TotalApostado", new BigDecimal("25.1500"));
        fila.put("TotalComisionesHistoricas", new BigDecimal("26.1600"));
        fila.put("TotalCargoHistorico", new BigDecimal("27.1700"));
        fila.put("PremioPotencialPendiente", new BigDecimal("28.1800"));
        fila.put("GananciaNetaPotencialPendiente", new BigDecimal("29.1900"));
        fila.put("TotalPremiosGanadores", new BigDecimal("30.2000"));
        fila.put("TotalDevueltoPorAnulacion", new BigDecimal("31.2100"));
        fila.put("ResultadoNetoRealizado", new BigDecimal("32.2200"));
        fila.put("PorcentajeEfectividad", new BigDecimal("33.2300"));
        fila.put("CuotaPromedio", new BigDecimal("34.2400"));
        fila.put("ProbabilidadImplicitaPromedio", new BigDecimal("35.2500"));
        return fila;
    }
    private static final Set<String> PROMEDIOS = new HashSet<>(Arrays.asList(
            "CuotaPromedio","ProbabilidadImplicitaPromedio","PorcentajeEfectividad"));
    private static final Set<String> SUMAS_NULAS = new HashSet<>(Arrays.asList(
            "BoletosPendientes","BoletosGanadores","BoletosPerdedores","BoletosAnulados"));

    private static class Jdbc extends AnaliticaUsuarioDAO {
        final boolean deportes;
        final List<Map<String,Object>> filas = new ArrayList<>();
        final List<Object> resultados = new ArrayList<>();
        final Map<Integer,Integer> parametros = new HashMap<>();
        final Set<String> abiertos = new HashSet<>(), cerrados = new HashSet<>(), columnas = new HashSet<>();
        int conexiones, codigo, indice;
        boolean runtime, errorConexion, errorPreparar, errorParametro, errorLeer, errorFinal;
        boolean sinResultado, extra, conteos;
        String sql;
        Jdbc(boolean deportes) { this.deportes = deportes; filas.add(deportes ? deporte() : general()); }

        @Override protected Connection obtenerConexion() throws SQLException {
            conexiones++;
            if (runtime) throw new IllegalStateException("PRIVADO interno");
            if (errorConexion) throw new SQLException("PRIVADO conexion");
            abiertos.add("conexion");
            return proxy(Connection.class, (p,m,a) -> {
                switch (m.getName()) {
                    case "prepareCall":
                        if (errorPreparar) throw new SQLException("PRIVADO preparar");
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
                    case "setInt":
                        if (errorParametro) throw new SQLException("PRIVADO parametro");
                        parametros.put((Integer)a[0],(Integer)a[1]); return null;
                    case "execute":
                        if (codigo != 0) throw new SQLException("PRIVADO SELECT password servidor", "TEST", codigo);
                        if (conteos) { resultados.add(0); resultados.add(2); }
                        if (!sinResultado) resultados.add(filas);
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
            List<Map<String,Object>> datos = (List<Map<String,Object>>)resultados.get(numero);
            int[] pos = {-1};
            boolean[] nulo = {false};
            return proxy(ResultSet.class, (p,m,a) -> {
                switch (m.getName()) {
                    case "next":
                        if (errorLeer) throw new SQLException("PRIVADO lectura");
                        return ++pos[0] < datos.size();
                    case "close": cerrar(nombre); return null;
                    case "wasNull": return nulo[0];
                    case "getInt": case "getString": case "getBigDecimal":
                        String columna = (String)a[0];
                        Map<String,Object> fila = datos.get(pos[0]);
                        if (!fila.containsKey(columna)) throw new SQLException("PRIVADO columna");
                        columnas.add(columna);
                        Object valor = fila.get(columna);
                        nulo[0] = valor == null;
                        return valor == null && m.getName().equals("getInt") ? Integer.valueOf(0) : valor;
                    default: throw new AssertionError("ResultSet " + m.getName());
                }
            });
        }
    }
    private static class Entrada {
        boolean sesion = true, expirada, errorRequest;
        Object id = 7, rol = "USUARIO";
    }
    private static class Salida {
        int estado = 200, sesiones;
        String tipo;
        final Map<String,String> headers = new HashMap<>();
        final StringWriter cuerpo = new StringWriter();
        JsonNode json;
    }
    private static Salida ejecutar(Entrada e, Jdbc jdbc, int esperado) throws Exception {
        HttpServlet servlet = jdbc.deportes ? new ResumenUsuarioPorDeporteServlet() : new ResumenGeneralUsuarioServlet();
        servlet.init();
        Field campo = servlet.getClass().getDeclaredField("analiticaServicio");
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
                s.sesiones++;
                if (e.errorRequest) throw new IllegalArgumentException("PRIVADO request");
                return e.sesion ? sesion : null;
            }
            throw new AssertionError("Nunca leer parametros, body, headers ni cookies: " + m.getName());
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
        if (jdbc.deportes) ((ResumenUsuarioPorDeporteServlet)servlet).doGet(req,resp);
        else ((ResumenGeneralUsuarioServlet)servlet).doGet(req,resp);
        exigir(s.estado == esperado, "HTTP esperado " + esperado + ", recibido " + s.estado);
        exigir(s.sesiones == 1, "Consultar sesion existente una vez");
        exigir("application/json;charset=UTF-8".equals(s.tipo), "Content-Type");
        exigir("no-store".equals(s.headers.get("Cache-Control")), "Cache-Control");
        exigir(!s.cuerpo.toString().contains("PRIVADO"), "No revelar excepciones");
        s.json = JSON.readTree(s.cuerpo.toString());
        exigir(s.json.get("ok").asBoolean() == (esperado == 200), "ok");
        exigir(jdbc.abiertos.equals(jdbc.cerrados), "Cierre de todos los recursos " + jdbc.abiertos + "/" + jdbc.cerrados);
        if (jdbc.sql != null) {
            exigir((jdbc.deportes ? "{call dbo.sp_ObtenerResumenUsuarioPorDeporte(?)}"
                    : "{call dbo.sp_ObtenerResumenGeneralUsuario(?)}").equals(jdbc.sql), "Procedimiento exacto");
            if (!jdbc.errorParametro) {
                exigir(jdbc.parametros.size() == 1, "Solo un parametro");
                exigir(Integer.valueOf(e.id.toString().split("\\.")[0].trim()).equals(jdbc.parametros.get(1)),
                        "Identidad exclusiva de sesion sin cambios");
            }
        }
        if (esperado == 200) {
            exigir(s.json.size() == (jdbc.deportes ? 3 : 2), "Estructura exacta");
            if (jdbc.deportes) {
                exigir(s.json.get("cantidadDeportes").asInt() == jdbc.filas.size(), "Cantidad real");
                exigir(s.json.get("deportes").isArray() && s.json.get("deportes").size() == jdbc.filas.size(), "Lista");
                for (int i=0;i<jdbc.filas.size();i++) columnas(jdbc.filas.get(i),s.json.get("deportes").get(i));
            } else columnas(jdbc.filas.get(0),s.json.get("resumen"));
            if (!jdbc.filas.isEmpty()) exigir(jdbc.columnas.equals(jdbc.filas.get(0).keySet()), "Todas las columnas SQL");
        } else {
            exigir(s.json.size() == 2 && s.json.get("mensaje").isTextual(), "Error generico consistente");
        }
        casos++;
        return s;
    }
    private static void columnas(Map<String,Object> fila, JsonNode json) {
        exigir(json.size() == fila.size(), "Campos JSON exactos");
        for (Map.Entry<String,Object> columna : fila.entrySet()) {
            String nombre = columna.getKey();
            String clave = Character.toLowerCase(nombre.charAt(0)) + nombre.substring(1);
            JsonNode valor = json.get(clave);
            exigir(valor != null, "Campo " + clave);
            Object original = columna.getValue();
            if (original == null) exigir(valor.isNull(), "NULL preservado " + clave);
            else if (original instanceof BigDecimal) {
                exigir(valor.isNumber() && valor.decimalValue().compareTo((BigDecimal)original) == 0,
                        "Decimal exacto sin recalculo " + clave);
            } else if (original instanceof Integer) {
                exigir(valor.isIntegralNumber() && valor.intValue() == (Integer)original, "Entero " + clave);
            } else exigir(valor.asText().equals(original), "Texto " + clave);
        }
    }
    public static void main(String[] args) throws Exception {
        exigir(Arrays.asList(ResumenUsuarioPorDeporteServlet.class.getAnnotation(WebServlet.class).value())
                .contains("/usuario/analitica/deportes"),"Mapping deportes");
        exigir(Arrays.asList(ResumenGeneralUsuarioServlet.class.getAnnotation(WebServlet.class).value())
                .contains("/usuario/analitica/resumen"),"Mapping resumen");
        for (boolean deportes : new boolean[]{true,false}) {
            Entrada e = new Entrada(); e.sesion = false;
            Jdbc j = new Jdbc(deportes); ejecutar(e,j,401); exigir(j.conexiones == 0,"No SQL");
            for (Object id : new Object[]{null,0,-1,"abc","",new Object(),1.5,Long.MAX_VALUE,"2147483648",Double.NaN}) {
                e = new Entrada(); e.id = id; j = new Jdbc(deportes);
                ejecutar(e,j,401); exigir(j.conexiones == 0,"No SQL");
            }
            e = new Entrada(); e.expirada = true; ejecutar(e,new Jdbc(deportes),401);
            for (Object rol : new Object[]{null,"ADMINISTRADOR","OPERADOR_EVENTOS","CAJERO","AUDITOR","CASA","usuario"}) {
                e = new Entrada(); e.rol = rol; j = new Jdbc(deportes);
                ejecutar(e,j,403); exigir(j.conexiones == 0,"Rol sin SQL");
            }
            for (int codigo : new int[]{deportes ? 64004 : 64016,deportes ? 64005 : 64017,99999,
                    deportes ? 64017 : 64005}) {
                j = new Jdbc(deportes); j.codigo = codigo;
                ejecutar(new Entrada(),j,codigo == (deportes ? 64004 : 64016) ? 400
                        : codigo == (deportes ? 64005 : 64017) ? 401 : 500);
            }
            j = new Jdbc(deportes); j.runtime = true; ejecutar(new Entrada(),j,500);
            e = new Entrada(); e.errorRequest = true; ejecutar(e,new Jdbc(deportes),500);
            j = new Jdbc(deportes); j.errorConexion = true; ejecutar(new Entrada(),j,500);
            j = new Jdbc(deportes); j.errorPreparar = true; ejecutar(new Entrada(),j,500);
            j = new Jdbc(deportes); j.errorParametro = true; ejecutar(new Entrada(),j,500);
            j = new Jdbc(deportes); j.errorLeer = true; ejecutar(new Entrada(),j,500);
            j = new Jdbc(deportes); j.errorFinal = true; ejecutar(new Entrada(),j,500);
            j = new Jdbc(deportes); j.sinResultado = true; ejecutar(new Entrada(),j,500);
            j = new Jdbc(deportes); j.extra = true; ejecutar(new Entrada(),j,500);
            j = new Jdbc(deportes); j.conteos = true; ejecutar(new Entrada(),j,200);
            j = new Jdbc(deportes); j.conteos = true; j.extra = true; ejecutar(new Entrada(),j,500);
            ejecutar(new Entrada(),new Jdbc(deportes),200);
            for (Object id : new Object[]{"7",7L,new BigDecimal("7.00")," 7 ",123456,Integer.MAX_VALUE}) {
                e = new Entrada(); e.id = id; ejecutar(e,new Jdbc(deportes),200);
            }

            Map<String,Object> plantilla = deportes ? deporte() : general();
            for (String columna : plantilla.keySet()) {
                j = new Jdbc(deportes); j.filas.get(0).put(columna,null);
                boolean nullable = PROMEDIOS.contains(columna) || (!deportes && SUMAS_NULAS.contains(columna));
                ejecutar(new Entrada(),j,nullable ? 200 : 500);
            }
            j = new Jdbc(deportes); j.filas.get(0).remove("CantidadBoletos"); ejecutar(new Entrada(),j,500);
            j = new Jdbc(deportes); j.filas.clear(); ejecutar(new Entrada(),j,deportes ? 200 : 500);
            for (int id : new int[]{0,-1}) {
                j = new Jdbc(deportes);
                AnaliticaUsuarioServicio servicio = new AnaliticaUsuarioServicio(j);
                try {
                    if (deportes) servicio.obtenerResumenUsuarioPorDeporte(id);
                    else servicio.obtenerResumenGeneralUsuario(id);
                    throw new AssertionError("Servicio debe rechazar id");
                } catch (IllegalArgumentException esperado) {
                    exigir(j.conexiones == 0,"Validar antes de DAO"); casos++;
                }
            }
        }

        Jdbc j = new Jdbc(true); j.filas.clear();
        String[] nombres = {"Futbol","Baloncesto","Beisbol","Tenis"};
        int[] ids = {9,2,15,1};
        for (int i=0;i<nombres.length;i++) {
            Map<String,Object> fila = deporte();
            fila.put("IdDeporte",ids[i]); fila.put("Deporte",nombres[i]);
            fila.put("CantidadBoletos",100+i);
            j.filas.add(fila);
        }
        ejecutar(new Entrada(),j,200); // Compara cada fila en su posicion, sin ordenar por id.
        j = new Jdbc(true); j.filas.get(0).put("Deporte","Tenis");
        ejecutar(new Entrada(),j,200); // Un solo deporte: no inventar los tres restantes.
        j = new Jdbc(true);
        for (String columna : new ArrayList<>(j.filas.get(0).keySet())) {
            if (PROMEDIOS.contains(columna)) j.filas.get(0).put(columna,null);
            else if (!columna.equals("IdDeporte") && !columna.equals("Deporte")) j.filas.get(0).put(columna,0);
        }
        ejecutar(new Entrada(),j,200); // LEFT JOIN sin apuestas: conteos cero, promedios NULL.

        j = new Jdbc(false);
        for (String columna : new ArrayList<>(j.filas.get(0).keySet())) {
            if (PROMEDIOS.contains(columna) || SUMAS_NULAS.contains(columna)) j.filas.get(0).put(columna,null);
            else if (columna.equals("CantidadBoletos")) j.filas.get(0).put(columna,0);
            else j.filas.get(0).put(columna,new BigDecimal("0.00"));
        }
        ejecutar(new Entrada(),j,200); // COUNT=0, SUM=NULL y COALESCE=0 sin boletos.
        j = new Jdbc(false); j.filas.add(general()); ejecutar(new Entrada(),j,500);
        j = new Jdbc(false);
        j.filas.get(0).put("TotalApostado",new BigDecimal("123456789012345678901234567890123456.78"));
        j.filas.get(0).put("ResultadoNetoRealizado",new BigDecimal("-12345.67"));
        j.filas.get(0).put("CantidadBoletos",Integer.MAX_VALUE);
        ejecutar(new Entrada(),j,200);
        System.out.println("OK: " + casos + " casos controlados de resumenes de analitica, sin SQL real.");
    }
}
