package com.apuestas.seguridad;

import com.apuestas.modelo.*;
import com.apuestas.controlador.AdministracionUsuarioHttp;
import com.apuestas.seguridad.CsrfSeguridad.Ambito;
import java.io.IOException;
import java.util.*;
import javax.servlet.*;
import javax.servlet.http.*;

/** Invocado por ControlAccesoAdministrativo; sin registro global para el ambito USUARIO.
 * Registro exacto de operaciones; las comprobaciones locales reutilizan la misma validacion.
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
    /** Solo una envoltura privada creada tras validar acredita CSRF; no atributos del cliente. */
    public static boolean validada(HttpServletRequest req,Ambito ambito) {
        if(!(req instanceof SolicitudValidada))return false;
        SolicitudValidada s=(SolicitudValidada)req;
        return s.ambito==ambito && s.metodo.equals(req.getMethod())
                && s.ruta.equals(req.getServletPath()+(req.getPathInfo()==null?"":req.getPathInfo()));
    }
    @Override public void doFilter(ServletRequest request,ServletResponse response,FilterChain chain)
            throws IOException,ServletException {
        HttpServletRequest req=(HttpServletRequest)request;HttpServletResponse res=(HttpServletResponse)response;
        String ruta=req.getServletPath()+(req.getPathInfo()==null?"":req.getPathInfo());
        Ambito a=ambito(ruta);
        if(a==null||!"POST".equals(req.getMethod())) {chain.doFilter(req,res);return;}
        if(validada(req,a)) {chain.doFilter(req,res);return;}
        req.setCharacterEncoding("UTF-8");
        boolean logout="/administrador/logout".equals(ruta);
        boolean sinSesion=false;
        try {
            HttpSession s=req.getSession(false);
            if(s==null) {
                if(!logout) {AdministracionUsuarioHttp.error(res,401);return;}
                sinSesion=true;
            } else if(!CsrfSeguridad.autorizada(s,a)||!CsrfSeguridad.validar(req,a)) {
                AdministracionUsuarioHttp.error(res,403);return;
            }
        }catch(IllegalStateException e){
            if(!logout) {AdministracionUsuarioHttp.error(res,401);return;}
            sinSesion=true;
        }
        catch(RuntimeException e){AdministracionUsuarioHttp.error(res,500);return;}
        if(sinSesion) {chain.doFilter(req,res);return;}
        // El campo de transporte no pertenece a los parametros de negocio de los servicios.
        chain.doFilter(new SolicitudValidada(req,a,ruta),res);
    }
    private static final class SolicitudValidada extends HttpServletRequestWrapper {
        private final Ambito ambito;
        private final String ruta,metodo;
        private SolicitudValidada(HttpServletRequest req,Ambito ambito,String ruta) {
            super(req);this.ambito=ambito;this.ruta=ruta;this.metodo=req.getMethod();
        }
            @Override public Map<String,String[]> getParameterMap() {
                Map<String,String[]> p=new LinkedHashMap<>(super.getParameterMap());p.remove("_csrf");
                return Collections.unmodifiableMap(p);
            }
            @Override public String getParameter(String n) {return "_csrf".equals(n)?null:super.getParameter(n);}
            @Override public String[] getParameterValues(String n) {return "_csrf".equals(n)?null:super.getParameterValues(n);}
            @Override public Enumeration<String> getParameterNames() {return Collections.enumeration(getParameterMap().keySet());}
    }
}
