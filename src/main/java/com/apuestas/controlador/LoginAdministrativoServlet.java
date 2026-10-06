package com.apuestas.controlador;

import com.apuestas.modelo.ResultadoLogin;
import com.apuestas.seguridad.SesionAdministrativa;
import com.apuestas.servicio.AutenticacionAdministrativaServicio;
import java.io.IOException;
import java.sql.SQLException;
import javax.servlet.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet("/administrador/login")
public class LoginAdministrativoServlet extends HttpServlet {
    private AutenticacionAdministrativaServicio servicio;
    private static final String RECHAZO = "No fue posible iniciar sesión con los datos proporcionados.";
    @Override public void init() { servicio = new AutenticacionAdministrativaServicio(); }

    @Override protected void service(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {
        res.setHeader("Cache-Control", "no-store");
        res.setContentType("text/html;charset=UTF-8");
        if ("GET".equals(req.getMethod())) doGet(req,res);
        else if ("POST".equals(req.getMethod())) doPost(req,res);
        else { res.setStatus(405); res.setHeader("Allow","GET, POST"); }
    }
    @Override protected void doGet(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {
        req.getRequestDispatcher("/administrador/login.jsp").forward(req,res);
    }
    @Override protected void doPost(HttpServletRequest req, HttpServletResponse res)
            throws IOException {
        req.setCharacterEncoding("UTF-8");
        HttpSession nueva = null;
        try {
            ResultadoLogin r = servicio.autenticar(req.getParameter("correo"),
                    req.getParameter("contrasena"), req.getRemoteAddr());
            if (r == null) throw new IllegalStateException();
            if (!r.isAutenticado()) { error(res,401); return; }
            if (!SesionAdministrativa.resultadoValido(r)) throw new IllegalStateException();
            HttpSession anterior = req.getSession(false);
            if (anterior != null) {
                try { anterior.invalidate(); }
                catch (IllegalStateException expirada) { /* Ya expirada. */ }
            }
            nueva = req.getSession(true);
            SesionAdministrativa.guardar(nueva,r);
            res.setStatus(303);
            res.setHeader("Location", req.getContextPath()+"/administrador/inicio.jsp");
        } catch (IllegalArgumentException e) {
            descartar(nueva); error(res,400);
        } catch (SQLException | RuntimeException | LinkageError e) {
            descartar(nueva); error(res,500);
        }
    }
    private static void descartar(HttpSession s) {
        if(s!=null) try{s.invalidate();}catch(RuntimeException ignorada){ }
    }
    private static void error(HttpServletResponse res,int status)throws IOException {
        res.setStatus(status);
        res.setContentType("text/plain;charset=UTF-8");
        res.getWriter().print(RECHAZO);
    }
}