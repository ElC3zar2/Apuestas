package com.apuestas.controlador;

import com.apuestas.correo.EnvioCorreoException;
import com.apuestas.servicio.*;
import java.io.IOException;
import java.sql.SQLException;
import java.util.logging.Logger;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet("/usuario/seguridad/recuperacion-contrasena/solicitar")
public class SolicitarRecuperacionContrasenaServlet extends HttpServlet {
    private static final Logger LOG = Logger.getLogger(SolicitarRecuperacionContrasenaServlet.class.getName());
    private RecuperacionContrasenaServicio recuperacionServicio;
    @Override public void init() { recuperacionServicio = new RecuperacionContrasenaServicio(); }
    @Override protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        RecuperacionContrasenaHttp.metodoNoPermitido(res);
    }
    @Override protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        RecuperacionContrasenaHttp.preparar(res);
        try {
            req.setCharacterEncoding("UTF-8");
            String correo = req.getParameter("correo");
            if (!UsuarioServicio.correoSesionValido(correo)) {
                RecuperacionContrasenaHttp.error(res, 400); return;
            }
            recuperacionServicio.solicitar(correo);
            RecuperacionContrasenaHttp.exito(res, false);
        } catch (SQLException | EnvioCorreoException | RuntimeException e) {
            LOG.warning("No se completo la solicitud de recuperacion.");
            RecuperacionContrasenaHttp.error(res, 500);
        }
    }
}