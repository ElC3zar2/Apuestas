package com.apuestas.controlador;
import com.apuestas.seguridad.*;
import java.io.IOException;
import javax.servlet.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
@WebServlet({"/administrador/inicio","/administrador/eventos","/administrador/en-vivo","/administrador/catalogos","/administrador/mercados","/administrador/resultados","/administrador/liquidaciones","/administrador/usuarios"})
public class VistasAdministrativasServlet extends HttpServlet {
    @Override protected void service(HttpServletRequest req,HttpServletResponse res)throws ServletException,IOException {
        res.setHeader("Cache-Control","no-store");
        VistasAdministrativas vista=VistasAdministrativas.deRuta(req.getServletPath()+(req.getPathInfo()==null?"":req.getPathInfo()));
        if(vista==null){res.setStatus(404);return;}
        if(!"GET".equals(req.getMethod())&&!"HEAD".equals(req.getMethod())){res.setHeader("Allow","GET, HEAD");res.setStatus(405);return;}
        try {
            HttpSession s=req.getSession(false);
            if(s==null){res.setStatus(303);res.setHeader("Location",req.getContextPath()+"/administrador/login");return;}
            if(!SesionAdministrativa.valida(s)||!vista.permite((String)s.getAttribute("adminRol"))){res.setStatus(403);return;}
        }catch(IllegalStateException e){res.setStatus(303);res.setHeader("Location",req.getContextPath()+"/administrador/login");return;}
        catch(RuntimeException e){res.setStatus(500);return;}
        req.getRequestDispatcher(vista.jsp).forward(req,res);
    }
}
