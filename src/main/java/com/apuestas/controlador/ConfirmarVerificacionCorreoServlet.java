package com.apuestas.controlador;

import com.apuestas.seguridad.TokenVerificacionCorreo;
import com.apuestas.servicio.VerificacionCorreoServicio;
import java.io.IOException;
import java.sql.SQLException;
import java.util.logging.Logger;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet("/usuario/seguridad/verificacion-correo/confirmar")
public class ConfirmarVerificacionCorreoServlet extends HttpServlet {
    private static final Logger LOG = Logger.getLogger(ConfirmarVerificacionCorreoServlet.class.getName());
    private VerificacionCorreoServicio verificacionServicio;

    @Override public void init() { verificacionServicio = new VerificacionCorreoServicio(); }

    @Override protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        VerificacionCorreoHttp.metodoNoPermitido(res);
    }

    @Override protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        VerificacionCorreoHttp.preparar(res);
        req.setCharacterEncoding("UTF-8");
        try {
            String token = req.getParameter("token");
            if (!TokenVerificacionCorreo.esValido(token)) {
                VerificacionCorreoHttp.error(res, 400); return;
            }
            verificacionServicio.confirmar(token);
            VerificacionCorreoHttp.exito(res, true);
        } catch (SQLException e) {
            int codigo = e.getErrorCode();
            // SQL: hash invalido, inexistente, usado/invalidado o expirado.
            if (codigo >= 57013 && codigo <= 57016) {
                VerificacionCorreoHttp.error(res, 400);
            } else {
                LOG.warning("No se completo la confirmacion de correo.");
                VerificacionCorreoHttp.error(res, 500);
            }
        } catch (RuntimeException e) {
            LOG.warning("No se completo la confirmacion de correo.");
            VerificacionCorreoHttp.error(res, 500);
        }
    }
}
