package com.apuestas.controlador;

import com.apuestas.dao.ApuestaDAO;
import com.apuestas.modelo.CotizacionApuesta;
import com.apuestas.servicio.ApuestaServicio;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.Field;
import java.lang.reflect.Proxy;
import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

/** Ejecutar main con servlet-api de Tomcat. No abre conexiones ni registra apuestas reales. */
public class PruebaRealizarApuesta {
    private static final String REF = "c8ec53e7-1fa9-4b51-b97d-55792fcdd75a";
    private static final ObjectMapper JSON = new ObjectMapper();
    private static int casos;

    private static void exigir(boolean valor, String mensaje) {
        if (!valor) throw new AssertionError(mensaje);
    }

    private static class Jdbc extends ApuestaDAO {
        final Map<String, Object> fila = new LinkedHashMap<>();
        final Map<Integer, Object> parametros = new HashMap<>();
        String sql;
        int codigo, llamadas, cierres, filas = 1, posicion;
        boolean nulo, sinResultado, resultadoExtra, errorTardio, conteoPrevio;
        int avance;

        Jdbc(boolean idempotente) {
            fila.put("IdBoleto", 25);
            fila.put("CodigoBoleto", "BOL-25");
            fila.put("TipoBoleto", "COMPUESTO");
            fila.put("MontoApostado", new BigDecimal("100.25"));
            fila.put("ComisionServicio", new BigDecimal("5.01"));
            fila.put("TotalCargo", new BigDecimal("105.26"));
            fila.put("CuotaTotal", new BigDecimal("3.1234"));
            fila.put("GananciaPotencial", new BigDecimal("313.12"));
            fila.put("ReferenciaOperacion", REF);
            fila.put("SolicitudIdempotente", idempotente);
            if (!idempotente) {
                fila.put("CantidadSelecciones", 2);
                fila.put("ComisionServicioPorcentaje", new BigDecimal("5.0000"));
            }
        }

        @Override protected Connection obtenerConexion() {
            llamadas++;
            posicion = 0;
            avance = 0;
            List<String> columnas = new ArrayList<>(fila.keySet());
            ResultSetMetaData meta = (ResultSetMetaData) Proxy.newProxyInstance(
                    getClass().getClassLoader(), new Class<?>[]{ResultSetMetaData.class},
                    (p, m, a) -> {
                        if ("getColumnCount".equals(m.getName())) return columnas.size();
                        if ("getColumnLabel".equals(m.getName())) return columnas.get((Integer) a[0] - 1);
                        throw new AssertionError(m.getName());
                    });
            ResultSet rs = (ResultSet) Proxy.newProxyInstance(getClass().getClassLoader(),
                    new Class<?>[]{ResultSet.class}, (p, m, a) -> {
                        switch (m.getName()) {
                            case "next": return ++posicion <= filas;
                            case "close": cierres++; return null;
                            case "wasNull": return nulo;
                            case "getMetaData": return meta;
                            case "getString": case "getInt": case "getBoolean": case "getBigDecimal":
                                String nombre = (String) a[0];
                                if (!fila.containsKey(nombre)) throw new SQLException("Columna ausente");
                                Object valor = fila.get(nombre);
                                nulo = valor == null;
                                if (valor != null) return valor;
                                if ("getInt".equals(m.getName())) return 0;
                                if ("getBoolean".equals(m.getName())) return false;
                                return null;
                            default: throw new AssertionError("ResultSet: " + m.getName());
                        }
                    });
            CallableStatement cs = (CallableStatement) Proxy.newProxyInstance(
                    getClass().getClassLoader(), new Class<?>[]{CallableStatement.class},
                    (p, m, a) -> {
                        switch (m.getName()) {
                            case "setInt": case "setString": case "setBigDecimal":
                                parametros.put((Integer) a[0], a[1]); return null;
                            case "setNull": parametros.put((Integer) a[0], null); return null;
                            case "execute":
                                if (codigo != 0) throw new SQLException(
                                        "PRIVADO: SQL password hash SELECT dbo.Usuario", "TEST", codigo);
                                return !sinResultado && !conteoPrevio;
                            case "getResultSet": return rs;
                            case "getUpdateCount": return conteoPrevio && avance == 0 ? 1 : -1;
                            case "getMoreResults":
                                avance++;
                                if (conteoPrevio && avance == 1) return true;
                                if (errorTardio) throw new SQLException("PRIVADO error tardio");
                                return resultadoExtra;
                            case "close": cierres++; return null;
                            default: throw new AssertionError("Statement: " + m.getName());
                        }
                    });
            return (Connection) Proxy.newProxyInstance(getClass().getClassLoader(),
                    new Class<?>[]{Connection.class}, (p, m, a) -> {
                        switch (m.getName()) {
                            case "prepareCall": sql = (String) a[0]; return cs;
                            case "close": cierres++; return null;
                            default: throw new AssertionError("Connection: " + m.getName());
                        }
                    });
        }
    }

    private static class Entrada {
        boolean sesion = true, expirada;
        Object usuario = Integer.valueOf(7), rol = "USUARIO";
        String[] selecciones = {"11", "12"};
        String monto = "100.25", referencia = REF;
        // Estos datos maliciosos existen pero leerlos produce un fallo en el proxy.
        String idUsuarioRequest = "999", ipRequest = "8.8.8.8";
    }

    private static class Salida {
        int estado = 200, sesiones;
        String tipo, encoding;
        final Map<String, String> headers = new HashMap<>();
        final StringWriter texto = new StringWriter();
        JsonNode json;
    }

    private static Salida ejecutar(Entrada entrada, Jdbc jdbc) throws Exception {
        RealizarApuestaServlet servlet = new RealizarApuestaServlet();
        servlet.init();
        Field servicio = RealizarApuestaServlet.class.getDeclaredField("apuestaServicio");
        servicio.setAccessible(true);
        servicio.set(servlet, new ApuestaServicio(jdbc));
        Salida s = new Salida();
        HttpSession sesion = (HttpSession) Proxy.newProxyInstance(
                PruebaRealizarApuesta.class.getClassLoader(), new Class<?>[]{HttpSession.class},
                (p, m, a) -> {
                    if (!"getAttribute".equals(m.getName())) {
                        throw new AssertionError("No modificar sesion: " + m.getName());
                    }
                    if (entrada.expirada) throw new IllegalStateException("Sesion expirada");
                    if ("idUsuario".equals(a[0])) return entrada.usuario;
                    if ("rol".equals(a[0])) return entrada.rol;
                    throw new AssertionError("No duplicar reglas SQL con otros atributos");
                });
        HttpServletRequest req = (HttpServletRequest) Proxy.newProxyInstance(
                PruebaRealizarApuesta.class.getClassLoader(),
                new Class<?>[]{HttpServletRequest.class}, (p, m, a) -> {
                    switch (m.getName()) {
                        case "setCharacterEncoding": s.encoding = (String) a[0]; return null;
                        case "getSession":
                            exigir(a != null && a.length == 1 && Boolean.FALSE.equals(a[0]),
                                    "Nunca crear una sesion");
                            s.sesiones++;
                            return entrada.sesion ? sesion : null;
                        case "getParameter":
                            exigir("UTF-8".equals(s.encoding), "Encoding antes de leer");
                            if ("monto".equals(a[0])) return entrada.monto;
                            if ("referenciaOperacion".equals(a[0])) return entrada.referencia;
                            throw new AssertionError("No leer parametro controlado por cliente: " + a[0]);
                        case "getParameterValues":
                            exigir("idSeleccion".equals(a[0]), "Solo selecciones repetidas");
                            return entrada.selecciones;
                        case "getRemoteAddr": return "127.0.0.9";
                        default: throw new AssertionError("Request inesperado: " + m.getName());
                    }
                });
        HttpServletResponse res = (HttpServletResponse) Proxy.newProxyInstance(
                PruebaRealizarApuesta.class.getClassLoader(),
                new Class<?>[]{HttpServletResponse.class}, (p, m, a) -> {
                    switch (m.getName()) {
                        case "setContentType": s.tipo = (String) a[0]; return null;
                        case "setHeader": s.headers.put((String) a[0], (String) a[1]); return null;
                        case "setStatus": s.estado = (Integer) a[0]; return null;
                        case "getWriter": return new PrintWriter(s.texto);
                        default: throw new AssertionError("Response inesperado: " + m.getName());
                    }
                });
        servlet.doPost(req, res);
        exigir("application/json;charset=UTF-8".equals(s.tipo), "Content-Type");
        exigir("no-store".equals(s.headers.get("Cache-Control")), "Cache-Control");
        exigir(s.sesiones == 1, "Consultar sesion una vez sin crearla");
        s.json = JSON.readTree(s.texto.toString());
        exigir(s.json.path("ok").asBoolean() == (s.estado == 200 || s.estado == 201), "ok");
        exigir(!s.texto.toString().contains("PRIVADO")
                && !s.texto.toString().contains("password")
                && !s.texto.toString().contains("dbo.Usuario"), "No filtrar SQL o secretos");
        casos++;
        return s;
    }

    private static void rechazo(Entrada e, int estado) throws Exception {
        Jdbc jdbc = new Jdbc(false);
        Salida s = ejecutar(e, jdbc);
        exigir(s.estado == estado, "HTTP " + estado + " recibido " + s.estado);
        exigir(s.json.path("mensaje").isTextual() && jdbc.llamadas == 0,
                "Rechazo previo a SQL");
    }

    private static void exito(Salida s, boolean idempotente, String codigo) {
        exigir(s.estado == (idempotente ? 200 : 201), "Estado por idempotencia");
        exigir(s.json.size() == 13, "Solo campos publicos solicitados");
        exigir(s.json.path("idBoleto").asInt() == 25
                && s.json.path("codigoBoleto").asText().equals(codigo)
                && s.json.path("tipoBoleto").asText().equals("COMPUESTO")
                && s.json.path("cantidadSelecciones").asInt() == 2
                && s.json.path("referenciaOperacion").asText().equals(REF)
                && s.json.path("solicitudIdempotente").isBoolean()
                && s.json.path("solicitudIdempotente").asBoolean() == idempotente, "Identidad y contrato");
        String[][] decimales = {{"montoApostado", "100.25"}, {"comisionServicio", "5.01"},
                {"totalCargo", "105.26"}, {"cuotaTotal", "3.1234"}, {"gananciaPotencial", "313.12"}};
        for (String[] par : decimales) {
            exigir(s.json.path(par[0]).isNumber()
                    && s.json.path(par[0]).decimalValue().compareTo(new BigDecimal(par[1])) == 0,
                    "BigDecimal numerico " + par[0]);
        }
        if (idempotente) {
            exigir(s.json.path("comisionServicioPorcentaje").isNull(), "No inventar porcentaje historico");
        } else {
            exigir(s.json.path("comisionServicioPorcentaje").isNumber()
                    && s.json.path("comisionServicioPorcentaje").decimalValue()
                    .compareTo(new BigDecimal("5.0000")) == 0, "Porcentaje nuevo numerico");
        }
    }

    public static void main(String[] args) throws Exception {
        exigir(Arrays.asList(RealizarApuestaServlet.class.getAnnotation(WebServlet.class).value())
                .contains("/apuestas/realizar"), "Mapping");
        Entrada e = new Entrada(); e.sesion = false; rechazo(e, 401);
        for (Object id : new Object[]{null, 0, -1, "", "abc", "1.1", true,
                Long.valueOf(4294967303L), new BigDecimal("7.5"), Double.NaN, Double.POSITIVE_INFINITY}) {
            e = new Entrada(); e.usuario = id; rechazo(e, 401);
        }
        e = new Entrada(); e.expirada = true; rechazo(e, 401);
        for (Object rol : new Object[]{null, "ADMINISTRADOR", "OPERADOR_EVENTOS",
                "CAJERO", "AUDITOR", "CASA", "usuario", "USUARIO ", 1}) {
            e = new Entrada(); e.rol = rol; rechazo(e, 403);
        }
        for (String[] seleccion : new String[][]{null, {}, {""}, {" "}, {null},
                {"abc"}, {"0"}, {"-1"}, {"2147483648"}, {"11", "11"}, {"11", " 11 "}}) {
            e = new Entrada(); e.selecciones = seleccion; rechazo(e, 400);
        }
        for (String monto : new String[]{null, "", " ", "abc", "NaN", "1,23", "0", "-1"}) {
            e = new Entrada(); e.monto = monto; rechazo(e, 400);
        }
        for (String referencia : new String[]{null, "", " ", "abc", "1-1-1-1-1",
                REF + "0", REF.substring(1), REF.replace("c", "g")}) {
            e = new Entrada(); e.referencia = referencia; rechazo(e, 400);
        }
        for (Object id : new Object[]{7, 7L, " 7 ", new BigDecimal("7.0")}) {
            e = new Entrada(); e.usuario = id;
            Jdbc d = new Jdbc(false);
            exito(ejecutar(e, d), false, "BOL-25");
            exigir(d.parametros.get(1).equals(7), "Usuario exclusivamente de sesion");
            exigir(d.parametros.get(2).equals("[11,12]"), "JSON de selecciones");
            exigir(d.parametros.get(3).equals(new BigDecimal("100.25")), "Monto exacto");
            exigir(d.parametros.get(4).equals(REF), "UUID estable y explicito");
            exigir(d.parametros.get(5).equals("127.0.0.9"), "IP real de request.getRemoteAddr");
            exigir(d.sql.equals("{call dbo.sp_RealizarApuesta(?, ?, ?, ?, ?)}")
                    && d.llamadas == 1 && d.cierres == 3, "Contrato SQL y recursos");
        }
        Jdbc d = new Jdbc(true);
        exito(ejecutar(new Entrada(), d), true, "BOL-25");
        exigir(d.parametros.get(4).equals(REF), "Repeticion conserva referencia");
        d = new Jdbc(true);
        d.fila.put("CantidadSelecciones", 2);
        d.fila.put("ComisionServicioPorcentaje", new BigDecimal("5.0000"));
        Salida extendida = ejecutar(new Entrada(), d);
        exigir(extendida.estado == 200 && extendida.json.path("comisionServicioPorcentaje").isNumber(),
                "Conservar campos cuando SQL si los devuelve");

        StringBuilder especial = new StringBuilder("áñ\"\\");
        for (int c = 0; c < 32; c++) especial.append((char) c);
        d = new Jdbc(false); d.fila.put("CodigoBoleto", especial.toString());
        exito(ejecutar(new Entrada(), d), false, especial.toString());
        d = new Jdbc(false); d.conteoPrevio = true;
        exito(ejecutar(new Entrada(), d), false, "BOL-25");

        Map<Integer, Integer> codigos = new LinkedHashMap<>();
        for (int c = 60016; c <= 60046; c++) codigos.put(c, 500);
        for (int c = 60055; c <= 60065; c++) codigos.put(c, 500);
        for (int c : new int[]{60016,60017,60018,60019,60020,60022,60023,60024,60025,
                60042,60043,60044,60061,60062}) codigos.put(c,400);
        codigos.put(60033,401);
        for (int c = 60034; c <= 60039; c++) codigos.put(c,403);
        for (int c : new int[]{60029,60030,60031,60032,60040,60046,60056}) codigos.put(c,409);
        codigos.put(12345,500);
        codigos.put(60054,500); // Cotizacion: no pertenece a sp_RealizarApuesta.
        for (Map.Entry<Integer,Integer> caso : codigos.entrySet()) {
            d = new Jdbc(false); d.codigo = caso.getKey();
            Salida s = ejecutar(new Entrada(),d);
            exigir(s.estado == caso.getValue(), "Mapeo codigo " + caso.getKey());
            exigir(d.llamadas == 1 && d.cierres == 2, "No reintentar transaccion");
            if (s.estado == 500) exigir(s.json.path("mensaje").asText()
                    .equals("No fue posible confirmar la apuesta."), "Error interno generico");
        }

        for (String campo : new String[]{"ReferenciaOperacion", "SolicitudIdempotente",
                "MontoApostado", "CantidadSelecciones", "ComisionServicioPorcentaje"}) {
            d = new Jdbc(false); d.fila.put(campo,null);
            exigir(ejecutar(new Entrada(),d).estado == 500, "Nulo obligatorio: " + campo);
            d = new Jdbc(false); d.fila.remove(campo);
            exigir(ejecutar(new Entrada(),d).estado == 500, "Columna ausente: " + campo);
        }
        d = new Jdbc(false); d.fila.put("ReferenciaOperacion", UUID.randomUUID().toString());
        exigir(ejecutar(new Entrada(),d).estado == 500, "Referencia ajena");
        d = new Jdbc(false); d.filas = 0;
        exigir(ejecutar(new Entrada(),d).estado == 500, "Sin boleto");
        d = new Jdbc(false); d.filas = 2;
        exigir(ejecutar(new Entrada(),d).estado == 500, "Varios boletos");
        d = new Jdbc(false); d.sinResultado = true;
        exigir(ejecutar(new Entrada(),d).estado == 500, "Sin resultado");
        d = new Jdbc(false); d.resultadoExtra = true;
        exigir(ejecutar(new Entrada(),d).estado == 500, "Resultado adicional");
        d = new Jdbc(false); d.errorTardio = true;
        exigir(ejecutar(new Entrada(),d).estado == 500, "Error tardio SQL");

        ApuestaServicio cotizar = new ApuestaServicio(new ApuestaDAO() {
            @Override public CotizacionApuesta cotizarApuesta(String ids, BigDecimal monto) {
                exigir("[11,12]".equals(ids), "Regresion JSON cotizacion");
                return new CotizacionApuesta();
            }
        });
        exigir(cotizar.cotizarApuesta(Arrays.asList(11,12), new BigDecimal("100.25")) != null,
                "Regresion cotizacion");
        casos++;
        System.out.println("OK: " + casos + " casos controlados, sin conexiones SQL reales.");
    }
}
