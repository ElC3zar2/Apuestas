package com.apuestas.controlador;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.math.BigDecimal;
import java.util.*;
import javax.servlet.http.HttpServletResponse;

final class VerificacionCorreoHttp {
    private static final ObjectMapper JSON = new ObjectMapper();
    private VerificacionCorreoHttp() { }

    static void preparar(HttpServletResponse response) {
        response.setContentType("application/json;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");
    }

    static Integer idUsuario(Object valor) {
        if (!(valor instanceof Number) && !(valor instanceof String)) return null;
        try {
            String texto = valor.toString().trim();
            if (valor instanceof String && !texto.matches("[0-9]+")) return null;
            int id = new BigDecimal(texto).intValueExact();
            return id > 0 ? id : null;
        } catch (ArithmeticException | NumberFormatException e) {
            return null;
        }
    }

    static void exito(HttpServletResponse response, boolean confirmacion) throws IOException {
        Map<String,Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("ok", true);
        if (confirmacion) cuerpo.put("correoVerificado", true);
        escribir(response, 200, cuerpo);
    }

    static void error(HttpServletResponse response, int estado) throws IOException {
        String mensaje = estado == 400 ? "No fue posible verificar el codigo proporcionado."
                : estado == 401 ? "Debe iniciar sesion con un usuario valido."
                : estado == 403 ? "No tiene permiso para realizar esta operacion."
                : estado == 405 ? "Metodo no permitido."
                : "No fue posible procesar la verificacion de correo.";
        Map<String,Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("ok", false);
        cuerpo.put("mensaje", mensaje);
        escribir(response, estado, cuerpo);
    }

    static void metodoNoPermitido(HttpServletResponse response) throws IOException {
        preparar(response);
        response.setHeader("Allow", "POST");
        error(response, 405);
    }

    private static void escribir(HttpServletResponse response, int estado, Map<String,Object> cuerpo)
            throws IOException {
        String json = JSON.writeValueAsString(cuerpo);
        response.setStatus(estado);
        response.getWriter().print(json);
    }
}
