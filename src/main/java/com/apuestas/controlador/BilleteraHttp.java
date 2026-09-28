package com.apuestas.controlador;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.time.format.ResolverStyle;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.servlet.http.*;

/** Utilidades internas compartidas solamente por las consultas de billetera. */
final class BilleteraHttp {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final DateTimeFormatter ENTRADA =
            DateTimeFormatter.ofPattern("uuuu-MM-dd'T'HH:mm:ss").withResolverStyle(ResolverStyle.STRICT);

    private BilleteraHttp() { }

    static void preparar(HttpServletResponse response) {
        response.setContentType("application/json;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");
    }

    static Integer usuario(HttpServletRequest request) {
        HttpSession sesion = request.getSession(false);
        try {
            Object valor = sesion == null ? null : sesion.getAttribute("idUsuario");
            if (!(valor instanceof Number) && !(valor instanceof String)) return null;
            String texto = valor.toString().trim();
            if (valor instanceof String && !texto.matches("[0-9]+")) return null;
            int id = new BigDecimal(texto).intValueExact();
            return id > 0 ? id : null;
        } catch (IllegalStateException | ArithmeticException | NumberFormatException e) {
            return null;
        }
    }

    static LocalDateTime fechaEntrada(String texto) {
        if (texto == null) return null;
        if (!texto.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}")) {
            throw new IllegalArgumentException("Formato de fecha invalido.");
        }
        try {
            LocalDateTime fecha = LocalDateTime.parse(texto, ENTRADA);
            if (fecha.getYear() < 1) throw new IllegalArgumentException("Fecha fuera de rango.");
            return fecha;
        } catch (DateTimeParseException e) {
            throw new IllegalArgumentException("Fecha invalida.");
        }
    }

    static String fecha(LocalDateTime valor) {
        return valor == null ? null : DateTimeFormatter.ISO_LOCAL_DATE_TIME.format(valor);
    }

    static void escribir(HttpServletResponse response, int estado, Map<String, Object> cuerpo)
            throws IOException {
        String json = JSON.writeValueAsString(cuerpo);
        response.setStatus(estado);
        response.getWriter().print(json);
    }

    static void error(HttpServletResponse response, int estado) throws IOException {
        String mensaje;
        switch (estado) {
            case 400: mensaje = "Los parámetros de la consulta no son válidos."; break;
            case 401: mensaje = "Debe iniciar sesión con un usuario válido."; break;
            case 404: mensaje = "No se encontró la billetera del usuario."; break;
            default: mensaje = "No fue posible consultar la billetera."; break;
        }
        Map<String, Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("ok", false);
        cuerpo.put("mensaje", mensaje);
        escribir(response, estado, cuerpo);
    }

    static int estadoSql(int codigo, boolean movimientos) {
        if (movimientos) {
            switch (codigo) {
                case 58004: case 58005: case 58006: return 400;
                case 58007: return 401;
                case 58008: return 404;
                default: return 500;
            }
        }
        switch (codigo) {
            case 58001: return 400;
            case 58002: return 401;
            case 58003: return 404;
            default: return 500;
        }
    }
}
