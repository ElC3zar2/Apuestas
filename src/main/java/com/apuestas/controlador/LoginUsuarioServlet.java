package com.apuestas.controlador;

import com.apuestas.modelo.ResultadoLogin;
import com.apuestas.servicio.UsuarioServicio;
import java.io.IOException;
import java.sql.SQLException;
import java.util.logging.Logger;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

@WebServlet("/usuario/login")
public class LoginUsuarioServlet extends HttpServlet {
    private static final Logger LOG = Logger.getLogger(LoginUsuarioServlet.class.getName());
    private static final String RECHAZO =
            "No fue posible iniciar sesión con los datos proporcionados.";
    private static final String ERROR_INTERNO =
            "No fue posible procesar el inicio de sesión. Inténtelo nuevamente.";
    private UsuarioServicio usuarioServicio;

    @Override
    public void init() {
        usuarioServicio = new UsuarioServicio();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.setContentType("text/html;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");
        request.getRequestDispatcher("/usuario/login.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        request.setCharacterEncoding("UTF-8");
        response.setContentType("text/html;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");
        final ResultadoLogin resultado;
        try {
            resultado = usuarioServicio.autenticar(request.getParameter("correo"),
                    request.getParameter("contrasena"), request.getRemoteAddr());
        } catch (IllegalArgumentException e) {
            mostrarError(request, response, HttpServletResponse.SC_BAD_REQUEST, e.getMessage());
            return;
        } catch (SQLException e) {
            LOG.severe("Error SQL en login. Codigo: " + e.getErrorCode()
                    + "; SQLState: " + e.getSQLState());
            mostrarError(request, response, HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                    ERROR_INTERNO);
            return;
        } catch (RuntimeException e) {
            LOG.severe("Error interno al autenticar al usuario.");
            mostrarError(request, response, HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                    ERROR_INTERNO);
            return;
        }

        if (!resultado.isAutenticado()) {
            mostrarError(request, response, HttpServletResponse.SC_UNAUTHORIZED, RECHAZO);
            return;
        }
        HttpSession anterior = request.getSession(false);
        if (anterior != null) {
            anterior.invalidate();
        }
        HttpSession sesion = request.getSession(true);
        try {
            sesion.setAttribute("idUsuario", resultado.getIdUsuario());
            sesion.setAttribute("correo", resultado.getCorreo());
            sesion.setAttribute("idRol", resultado.getIdRol());
            sesion.setAttribute("rol", resultado.getRol());
            sesion.setAttribute("estadoUsuario", resultado.getEstadoUsuario());
            sesion.setAttribute("correoVerificado", resultado.getCorreoVerificado());
        } catch (RuntimeException e) {
            sesion.invalidate();
            throw new ServletException("No fue posible establecer la sesion.");
        }
        response.setStatus(HttpServletResponse.SC_SEE_OTHER);
        response.setHeader("Location", request.getContextPath() + "/usuario/inicio.jsp");
    }

    private void mostrarError(HttpServletRequest request, HttpServletResponse response,
            int estado, String mensaje) throws ServletException, IOException {
        response.setStatus(estado);
        request.setAttribute("error", mensaje);
        request.getRequestDispatcher("/usuario/login.jsp").forward(request, response);
    }
}
