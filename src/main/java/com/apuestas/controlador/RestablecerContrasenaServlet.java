package com.apuestas.controlador;

import com.apuestas.servicio.RecuperacionContrasenaServicio;
import java.io.IOException;
import java.sql.SQLException;
import java.util.logging.Logger;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet("/usuario/seguridad/recuperacion-contrasena/restablecer")
public class RestablecerContrasenaServlet extends HttpServlet {
    private static final Logger LOG = Logger.getLogger(RestablecerContrasenaServlet.class.getName());
    private RecuperacionContrasenaServicio recuperacionServicio;
    @Override public void init() { recuperacionServicio = new RecuperacionContrasenaServicio(); }
    @Override protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        RecuperacionContrasenaHttp.metodoNoPermitido(res);
    }
    @Override protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        RecuperacionContrasenaHttp.preparar(res);
        try {
            req.setCharacterEncoding("UTF-8");
            String token = req.getParameter("token");
            String nueva = req.getParameter("nuevaContrasena");
            String confirmar = req.getParameter("confirmarContrasena");
            if (!RecuperacionContrasenaServicio.datosValidos(token, nueva, confirmar)) {
                RecuperacionContrasenaHttp.error(res, 400); return;
            }
            recuperacionServicio.restablecer(token, nueva, confirmar);
            RecuperacionContrasenaHttp.exito(res, true);
        } catch (SQLException e) {
            int codigo = e.getErrorCode();
            // 57017: hash invalido; 57019: inexistente; 57020: usado/invalidado;
            // 57021: expirado; 57022: usuario asociado inexistente.
            // 57018: hash de contrasena ausente, inconsistencia interna de nuestro flujo.
            if (codigo == 57017 || (codigo >= 57019 && codigo <= 57022)) {
                RecuperacionContrasenaHttp.error(res, 400);
            } else {
                LOG.warning("No se completo el restablecimiento.");
                RecuperacionContrasenaHttp.error(res, 500);
            }
        } catch (RuntimeException e) {
            LOG.warning("No se completo el restablecimiento.");
            RecuperacionContrasenaHttp.error(res, 500);
        }
    }
}