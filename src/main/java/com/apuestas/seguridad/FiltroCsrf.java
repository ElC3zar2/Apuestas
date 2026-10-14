package com.apuestas.seguridad;

import com.apuestas.modelo.*;
import com.apuestas.controlador.AdministracionUsuarioHttp;
import com.apuestas.seguridad.CsrfSeguridad.Ambito;
import java.io.IOException;
import java.util.*;
import javax.servlet.*;
import javax.servlet.http.*;

/** NO registrado: activar solo despues de integrar los consumidores frontend.
 * Registro exacto de operaciones; no cambia POST productivos durante la preparacion.
 */
public final class FiltroCsrf implements Filter {
    public static Ambito ambito(String ruta) {
        if(Arrays.asList("/apuestas/realizar","/usuario/seguridad/cambiar-contrasena",
                "/usuario/seguridad/verificacion-correo/solicitar","/usuario/logout").contains(ruta)) return Ambito.USUARIO;
        if("/administrador/logout".equals(ruta)) return Ambito.ADMINISTRADOR;
        OperacionAdministracionUsuario u=OperacionAdministracionUsuario.deRuta(ruta);
        OperacionAdministracionEventos e=OperacionAdministracionEventos.deRuta(ruta);
        OperacionAdministracionResultados r=OperacionAdministracionResultados.deRuta(ruta);
        OperacionLiquidacionAdministrativa l=OperacionLiquidacionAdministrativa.deRuta(ruta);
        return (u!=null&&!u.lectura())||(e!=null&&"POST".equals(e.metodo))||r!=null
                ||(l!=null&&"POST".equals(l.metodo))?Ambito.ADMINISTRADOR:null;
    }
    @Override public void init(FilterConfig config) { }
    @Override public void destroy() { }
    @Override public void doFilter(ServletRequest request,ServletResponse response,FilterChain chain)
            throws IOException,ServletException {
        HttpServletRequest req=(HttpServletRequest)request;HttpServletResponse res=(HttpServletResponse)response;
        String ruta=req.getServletPath()+(req.getPathInfo()==null?"":req.getPathInfo());
        Ambito a=ambito(ruta);
        if(a==null||!"POST".equals(req.getMethod())) {chain.doFilter(req,res);return;}
        req.setCharacterEncoding("UTF-8");
        try {
            HttpSession s=req.getSession(false);
            if(s==null) {AdministracionUsuarioHttp.error(res,401);return;}
            if(!CsrfSeguridad.autorizada(s,a)||!CsrfSeguridad.validar(req,a)) {
                AdministracionUsuarioHttp.error(res,403);return;
            }
        }catch(IllegalStateException e){AdministracionUsuarioHttp.error(res,401);return;}
        catch(RuntimeException e){AdministracionUsuarioHttp.error(res,500);return;}
        // El campo de transporte no pertenece a los parametros de negocio de los servicios.
        chain.doFilter(new HttpServletRequestWrapper(req) {
            @Override public Map<String,String[]> getParameterMap() {
                Map<String,String[]> p=new LinkedHashMap<>(super.getParameterMap());p.remove("_csrf");
                return Collections.unmodifiableMap(p);
            }
            @Override public String getParameter(String n) {return "_csrf".equals(n)?null:super.getParameter(n);}
            @Override public String[] getParameterValues(String n) {return "_csrf".equals(n)?null:super.getParameterValues(n);}
            @Override public Enumeration<String> getParameterNames() {return Collections.enumeration(getParameterMap().keySet());}
        },res);
    }
}
