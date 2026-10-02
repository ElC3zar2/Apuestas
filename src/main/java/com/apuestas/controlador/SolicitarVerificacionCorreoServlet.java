package com.apuestas.controlador;

import com.apuestas.correo.EnvioCorreoException;
import com.apuestas.servicio.*;
import java.io.IOException;
import java.sql.SQLException;
import java.util.logging.Logger;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet("/usuario/seguridad/verificacion-correo/solicitar")
public class SolicitarVerificacionCorreoServlet extends HttpServlet {
    private static final Logger LOG = Logger.getLogger(SolicitarVerificacionCorreoServlet.class.getName());
    private VerificacionCorreoServicio verificacionServicio;

    @Override public void init() { verificacionServicio = new VerificacionCorreoServicio(); }

    @Override protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        VerificacionCorreoHttp.metodoNoPermitido(res);
    }

    @Override protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        VerificacionCorreoHttp.preparar(res);
        try {
            HttpSession sesion = req.getSession(false);
            Integer id;
            Object correo, rol;
            try {
                id = sesion == null ? null : VerificacionCorreoHttp.idUsuario(sesion.getAttribute("idUsuario"));
                correo = sesion == null ? null : sesion.getAttribute("correo");
                rol = sesion == null ? null : sesion.getAttribute("rol");
            } catch (IllegalStateException e) {
                id = null; correo = null; rol = null;
            }
            if (id == null || !(correo instanceof String)
                    || !UsuarioServicio.correoSesionValido((String)correo)) {
                VerificacionCorreoHttp.error(res, 401); return;
            }
            if (!"USUARIO".equals(rol)) { VerificacionCorreoHttp.error(res, 403); return; }
            verificacionServicio.solicitar(id, (String)correo);
            VerificacionCorreoHttp.exito(res, false);
        } catch (SQLException | EnvioCorreoException | RuntimeException e) {
            LOG.warning("No se completo la solicitud de verificacion de correo.");
            VerificacionCorreoHttp.error(res, 500);
        }
    }
}
