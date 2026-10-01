package com.apuestas.controlador;

import com.apuestas.servicio.UsuarioServicio;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.math.BigDecimal;
import java.sql.SQLException;
import java.util.*;
import java.util.logging.Logger;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet("/usuario/seguridad/cambiar-contrasena")
public class CambiarContrasenaUsuarioServlet extends HttpServlet {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final Logger LOG = Logger.getLogger(CambiarContrasenaUsuarioServlet.class.getName());
    private UsuarioServicio usuarioServicio;

    @Override
    public void init() { usuarioServicio = new UsuarioServicio(); }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        preparar(response);
        response.setHeader("Allow", "POST");
        error(response, 405);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException {
        preparar(response);
        request.setCharacterEncoding("UTF-8");
        try {
            HttpSession sesion = request.getSession(false);
            Integer id;
            Object correo, rol;
            try {
                id = sesion == null ? null : idUsuario(sesion.getAttribute("idUsuario"));
                correo = sesion == null ? null : sesion.getAttribute("correo");
                rol = sesion == null ? null : sesion.getAttribute("rol");
            } catch (IllegalStateException e) {
                id = null; correo = null; rol = null;
            }
            if (id == null || !(correo instanceof String)
                    || !UsuarioServicio.correoSesionValido((String)correo)) {
                error(response, 401); return;
            }
            if (!"USUARIO".equals(rol)) { error(response, 403); return; }

            String actual = request.getParameter("contrasenaActual");
            String nueva = request.getParameter("nuevaContrasena");
            String confirmacion = request.getParameter("confirmarContrasena");
            if (!UsuarioServicio.datosCambioContrasenaValidos(actual, nueva, confirmacion)) {
                error(response, 400); return;
            }
            if (!usuarioServicio.cambiarContrasenaUsuario(
                    id, (String)correo, actual, nueva, confirmacion)) {
                error(response, 401); return;
            }
            Map<String,Object> cuerpo = new LinkedHashMap<>();
            cuerpo.put("ok", true);
            cuerpo.put("contrasenaActualizada", true);
            escribir(response, 200, cuerpo);
        } catch (SQLException e) {
            LOG.warning("Error SQL en cambio de contrasena. Codigo: " + e.getErrorCode());
            int codigo = e.getErrorCode();
            error(response, codigo == 57023 || codigo == 57024 ? 400 : codigo == 57025 ? 401 : 500);
        } catch (RuntimeException e) {
            LOG.severe("Error interno en cambio de contrasena.");
            error(response, 500);
        }
    }

    private Integer idUsuario(Object valor) {
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

    private void preparar(HttpServletResponse response) {
        response.setContentType("application/json;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");
    }

    private void escribir(HttpServletResponse response, int estado, Map<String,Object> cuerpo)
            throws IOException {
        String json = JSON.writeValueAsString(cuerpo);
        response.setStatus(estado);
        response.getWriter().print(json);
    }

    private void error(HttpServletResponse response, int estado) throws IOException {
        String mensaje = estado == 400 ? "Los datos proporcionados no son validos."
                : estado == 401 ? "No fue posible autenticar la solicitud."
                : estado == 403 ? "No tiene permiso para realizar esta operacion."
                : estado == 405 ? "Metodo no permitido."
                : "No fue posible procesar el cambio de contrasena.";
        Map<String,Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("ok", false);
        cuerpo.put("mensaje", mensaje);
        escribir(response, estado, cuerpo);
    }
}
