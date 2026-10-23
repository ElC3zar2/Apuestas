package com.apuestas.seguridad;

import java.io.IOException;
import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import javax.servlet.http.*;

@WebFilter(urlPatterns="/administrador/*",
        dispatcherTypes={DispatcherType.REQUEST,DispatcherType.FORWARD})
public class ControlAccesoAdministrativo implements Filter {
    @Override public void init(FilterConfig c) { }
    @Override public void destroy() { }
    @Override public void doFilter(ServletRequest request,ServletResponse response,FilterChain chain)
            throws IOException,ServletException {
        HttpServletRequest req=(HttpServletRequest)request;
        HttpServletResponse res=(HttpServletResponse)response;
        res.setHeader("Cache-Control","no-store");
        String ruta=req.getServletPath()+(req.getPathInfo()==null?"":req.getPathInfo());
        // El JSP sin action debe mostrarse en la URL canonica del servlet.
        if("/administrador/login.jsp".equals(ruta)) {
            if(req.getDispatcherType()==DispatcherType.FORWARD) {
                chain.doFilter(req,res);return;
            }
            if("GET".equals(req.getMethod()) || "HEAD".equals(req.getMethod())) {
                redirigir(req,res);return;
            }
            res.setHeader("Allow","GET, HEAD");res.setStatus(405);return;
        }
        if("/administrador/login".equals(ruta) || "/administrador/logout".equals(ruta)) {
            if("/administrador/logout".equals(ruta)) new FiltroCsrf().doFilter(req,res,chain);
            else chain.doFilter(req,res);
            return;
        }
        HttpSession s;
        boolean valida;
        try {
            s=req.getSession(false);
            valida=SesionAdministrativa.valida(s);
        }catch(IllegalStateException expirada){s=null;valida=false;}
        catch(RuntimeException e){
            error(ruta,res,500,"No fue posible procesar la solicitud.");return;
        }
        if(s==null) {
            if(("GET".equals(req.getMethod()) || "HEAD".equals(req.getMethod()))
                    && (ruta.endsWith(".jsp") || VistasAdministrativas.deRuta(ruta)!=null || "/administrador/".equals(ruta))) redirigir(req,res);
            else error(ruta,res,401,"Autenticación requerida.");
            return;
        }
        if(!valida){error(ruta,res,403,"Acceso no permitido.");return;}
        VistasAdministrativas vista=VistasAdministrativas.deJsp(ruta);
        if(vista!=null) {
            if(!vista.permite((String)s.getAttribute("adminRol"))){res.setStatus(403);return;}
            if(req.getDispatcherType()!=DispatcherType.FORWARD){
                if(!"GET".equals(req.getMethod())&&!"HEAD".equals(req.getMethod())){res.setStatus(405);res.setHeader("Allow","GET, HEAD");return;}
                res.setStatus(303);res.setHeader("Location",req.getContextPath()+vista.ruta);return;
            }
        }
        // Orden explicito: identidad administrativa, CSRF de operaciones POST, servlet/permisos.
        new FiltroCsrf().doFilter(req,res,chain);
    }
    private static void redirigir(HttpServletRequest req,HttpServletResponse res) {
        res.setStatus(303);res.setHeader("Location",req.getContextPath()+"/administrador/login");
    }
    private static void error(String ruta,HttpServletResponse res,int estado,String mensaje)throws IOException {
        // Las APIs de gestion requieren JSON incluso cuando el filtro corta la solicitud.
        if(com.apuestas.modelo.OperacionConsultaAdministrativa.deRuta(ruta)!=null
                || com.apuestas.controlador.ConsultaResultadoEventoServlet.RUTA.equals(ruta)
                || com.apuestas.controlador.CatalogoParticipantesServlet.RUTA.equals(ruta)
                || CsrfSeguridad.RUTA_ADMIN.equals(ruta)
                || com.apuestas.modelo.OperacionAdministracionUsuario.deRuta(ruta)!=null
                || com.apuestas.modelo.OperacionAdministracionEventos.deRuta(ruta)!=null
                || com.apuestas.modelo.OperacionAdministracionResultados.deRuta(ruta)!=null
                || com.apuestas.modelo.OperacionLiquidacionAdministrativa.deRuta(ruta)!=null
                || com.apuestas.modelo.OperacionDashboardAdministrativo.deRuta(ruta)!=null){
            com.apuestas.controlador.AdministracionUsuarioHttp.error(res,estado);
            return;
        }
        res.setStatus(estado);res.setContentType("text/plain;charset=UTF-8");res.getWriter().print(mensaje);
    }
}
