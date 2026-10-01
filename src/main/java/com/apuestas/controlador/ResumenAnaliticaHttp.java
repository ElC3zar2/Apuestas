package com.apuestas.controlador;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.math.BigDecimal;
import java.util.*;
import javax.servlet.http.*;

/** Soporte HTTP interno de los dos resumenes de analitica. */
final class ResumenAnaliticaHttp {
    private static final ObjectMapper JSON = new ObjectMapper();
    private ResumenAnaliticaHttp() { }

    static void preparar(HttpServletResponse response) {
        response.setContentType("application/json;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");
    }

    static Integer usuarioAutorizado(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        HttpSession sesion = request.getSession(false);
        Integer id;
        Object rol;
        try {
            id = sesion == null ? null : usuario(sesion.getAttribute("idUsuario"));
            rol = sesion == null ? null : sesion.getAttribute("rol");
        } catch (IllegalStateException e) {
            id = null;
            rol = null;
        }
        if (id == null) { error(response, 401); return null; }
        if (!"USUARIO".equals(rol)) { error(response, 403); return null; }
        return id;
    }

    private static Integer usuario(Object valor) {
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

    static void escribir(HttpServletResponse response, int estado, Map<String,Object> cuerpo)
            throws IOException {
        String json = JSON.writeValueAsString(cuerpo);
        response.setStatus(estado);
        response.getWriter().print(json);
    }

    static void error(HttpServletResponse response, int estado) throws IOException {
        String mensaje = estado == 400 ? "Los parametros de la consulta no son validos."
                : estado == 401 ? "Debe iniciar sesion con un usuario valido."
                : estado == 403 ? "No tiene permiso para consultar la analitica."
                : "No fue posible consultar la analitica.";
        Map<String,Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("ok", false);
        cuerpo.put("mensaje", mensaje);
        escribir(response, estado, cuerpo);
    }
}
