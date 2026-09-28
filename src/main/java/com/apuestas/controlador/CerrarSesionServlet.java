package com.apuestas.controlador;

import java.io.IOException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

@WebServlet("/usuario/logout")
public class CerrarSesionServlet extends HttpServlet {
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        HttpSession sesion = request.getSession(false);
        if (sesion != null) {
            try {
                sesion.invalidate();
            } catch (IllegalStateException e) {
                // Ya expirada o invalidada por otra solicitud: logout sigue siendo exitoso.
            }
        }
        response.setHeader("Cache-Control", "no-store");
        response.setStatus(HttpServletResponse.SC_SEE_OTHER);
        response.setHeader("Location", request.getContextPath() + "/usuario/login");
    }
}
