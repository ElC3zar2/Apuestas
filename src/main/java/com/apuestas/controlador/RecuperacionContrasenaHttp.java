package com.apuestas.controlador;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;

import java.util.*;
import javax.servlet.http.HttpServletResponse;

final class RecuperacionContrasenaHttp {
    private static final ObjectMapper JSON = new ObjectMapper();
    private RecuperacionContrasenaHttp() { }

    static void preparar(HttpServletResponse response) {
        response.setContentType("application/json;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");
    }

    static void exito(HttpServletResponse response, boolean confirmacion) throws IOException {
        Map<String,Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("ok", true);
        if (confirmacion) cuerpo.put("contrasenaActualizada", true);
        escribir(response, 200, cuerpo);
    }

    static void error(HttpServletResponse response, int estado) throws IOException {
        String mensaje = estado == 400 ? "No fue posible restablecer la contrasena con los datos proporcionados."
                : estado == 401 ? "Debe iniciar sesion con un usuario valido."
                : estado == 403 ? "No tiene permiso para realizar esta operacion."
                : estado == 405 ? "Metodo no permitido."
                : "No fue posible procesar la recuperacion de contrasena.";
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
