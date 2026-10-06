package com.apuestas.controlador;

import com.apuestas.seguridad.SesionAdministrativa;
import java.io.IOException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet("/administrador/logout")
public class LogoutAdministrativoServlet extends HttpServlet {
    @Override protected void service(HttpServletRequest req,HttpServletResponse res)throws IOException {
        res.setHeader("Cache-Control","no-store");
        res.setContentType("text/plain;charset=UTF-8");
        if(!"POST".equals(req.getMethod())) {
            res.setStatus(405);res.setHeader("Allow","POST");return;
        }
        try {
            HttpSession s=req.getSession(false);
            if(s!=null) {
                try {
                    if(!SesionAdministrativa.valida(s)) {
                        res.setStatus(403);res.getWriter().print("Acceso no permitido.");return;
                    }
                    s.invalidate();
                }catch(IllegalStateException expirada){ /* Logout idempotente. */ }
            }
            res.setStatus(303);
            res.setHeader("Location",req.getContextPath()+"/administrador/login");
        }catch(RuntimeException e) {
            res.setStatus(500);res.getWriter().print("No fue posible procesar la solicitud.");
        }
    }
}