package com.apuestas.seguridad;

import java.io.IOException;
import java.math.BigDecimal;
import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

@WebFilter(urlPatterns = "/usuario/*", dispatcherTypes = DispatcherType.REQUEST)
public class ControlAcceso implements Filter {
    @Override
    public void init(FilterConfig config) { }

    @Override
    public void destroy() { }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse res = (HttpServletResponse) response;
        String ruta = req.getServletPath();
        if (req.getPathInfo() != null) {
            ruta += req.getPathInfo();
        }
        if ("/usuario/login".equals(ruta) || "/usuario/login.jsp".equals(ruta)
                || "/usuario/logout".equals(ruta) || "/usuario/boletos/imprimir".equals(ruta)) {
            chain.doFilter(request, response);
            return;
        }

        res.setHeader("Cache-Control", "no-store");
        HttpSession sesion = req.getSession(false);
        Integer idUsuario;
        Object rol;
        try {
            idUsuario = sesion == null ? null : idValido(sesion.getAttribute("idUsuario"));
            rol = sesion == null ? null : sesion.getAttribute("rol");
        } catch (IllegalStateException e) {
            // La sesion pudo expirar concurrentemente.
            idUsuario = null;
            rol = null;
        }
        if (idUsuario == null) {
            res.setStatus(HttpServletResponse.SC_SEE_OTHER);
            res.setHeader("Location", req.getContextPath() + "/usuario/login");
            return;
        }
        if (!"USUARIO".equals(rol)) {
            res.setStatus(HttpServletResponse.SC_FORBIDDEN);
            res.setContentType("text/plain;charset=UTF-8");
            res.getWriter().print("No tiene permiso para acceder a esta página.");
            return;
        }
        chain.doFilter(request, response);
    }

    private Integer idValido(Object valor) {
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
}
