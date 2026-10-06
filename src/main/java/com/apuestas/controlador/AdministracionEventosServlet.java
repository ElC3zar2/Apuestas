package com.apuestas.controlador;

import com.apuestas.modelo.OperacionAdministracionEventos;
import com.apuestas.seguridad.SesionAdministrativa;
import com.apuestas.servicio.AdministracionEventosServicio;
import java.io.IOException;
import java.sql.SQLException;
import java.time.DateTimeException;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet({
    "/administrador/ligas/crear", "/administrador/ligas/actualizar",
    "/administrador/participantes/crear", "/administrador/participantes/actualizar",
    "/administrador/eventos/crear", "/administrador/eventos/actualizar",
    "/administrador/eventos/participantes/agregar",
    "/administrador/mercados/crear", "/administrador/selecciones/crear",
    "/administrador/cuotas/registrar",
    "/administrador/eventos/estado/cambiar", "/administrador/mercados/estado/cambiar"
})
public class AdministracionEventosServlet extends HttpServlet {
    private AdministracionEventosServicio servicio;
    @Override public void init() { servicio=new AdministracionEventosServicio(); }
    @Override protected void service(HttpServletRequest req,HttpServletResponse res) throws IOException {
        AdministracionUsuarioHttp.preparar(res);
        req.setCharacterEncoding("UTF-8");
        OperacionAdministracionEventos op=OperacionAdministracionEventos.deRuta(
                req.getServletPath()+(req.getPathInfo()==null?"":req.getPathInfo()));
        if(op==null) { AdministracionUsuarioHttp.error(res,404);return; }
        if(!"POST".equals(req.getMethod())) {
            res.setHeader("Allow","POST");AdministracionUsuarioHttp.error(res,405);return;
        }
        final int actor;
        final String rol;
        try {
            HttpSession sesion=req.getSession(false);
            if(sesion==null) { AdministracionUsuarioHttp.error(res,401);return; }
            if(!SesionAdministrativa.valida(sesion)) { AdministracionUsuarioHttp.error(res,403);return; }
            actor=(Integer)sesion.getAttribute("adminIdUsuario");
            rol=(String)sesion.getAttribute("adminRol");
        } catch(IllegalStateException e) { AdministracionUsuarioHttp.error(res,401);return; }
        catch(RuntimeException e) { AdministracionUsuarioHttp.error(res,500);return; }
        try {
            AdministracionEventosServicio.autorizar(actor,rol);
            Map<String,Object> cuerpo=new LinkedHashMap<>();
            cuerpo.put("ok",true);
            cuerpo.put("resultado",servicio.ejecutar(op,actor,rol,req.getParameterMap(),req.getRemoteAddr()));
            AdministracionUsuarioHttp.escribir(res,200,cuerpo);
        } catch(SecurityException e) { AdministracionUsuarioHttp.error(res,403); }
        catch(IllegalArgumentException | DateTimeException e) { AdministracionUsuarioHttp.error(res,400); }
        catch(SQLException e) { AdministracionUsuarioHttp.error(res,AdministracionEventosHttp.estadoSql(e.getErrorCode())); }
        catch(RuntimeException | LinkageError e) { AdministracionUsuarioHttp.error(res,500); }
    }
}