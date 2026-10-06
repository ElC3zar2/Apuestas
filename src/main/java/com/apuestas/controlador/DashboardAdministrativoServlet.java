package com.apuestas.controlador;
import com.apuestas.modelo.OperacionDashboardAdministrativo;
import com.apuestas.seguridad.SesionAdministrativa;
import com.apuestas.servicio.DashboardAdministrativoServicio;
import java.io.IOException;
import java.sql.SQLException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet({"/administrador/dashboard/resumen","/administrador/analitica/eventos"})
public class DashboardAdministrativoServlet extends HttpServlet {
    private DashboardAdministrativoServicio servicio;
    @Override public void init() { servicio=new DashboardAdministrativoServicio(); }
    @Override protected void service(HttpServletRequest req,HttpServletResponse res) throws IOException {
        AdministracionUsuarioHttp.preparar(res);req.setCharacterEncoding("UTF-8");
        OperacionDashboardAdministrativo op=OperacionDashboardAdministrativo.deRuta(
                req.getServletPath()+(req.getPathInfo()==null?"":req.getPathInfo()));
        if(op==null) { AdministracionUsuarioHttp.error(res,404);return; }
        if(!"GET".equals(req.getMethod())) {
            res.setHeader("Allow","GET");AdministracionUsuarioHttp.error(res,405);return;
        }
        final int actor;final String rol;
        try {
            HttpSession s=req.getSession(false);
            if(s==null) { AdministracionUsuarioHttp.error(res,401);return; }
            if(!SesionAdministrativa.valida(s)) { AdministracionUsuarioHttp.error(res,403);return; }
            actor=(Integer)s.getAttribute("adminIdUsuario");rol=(String)s.getAttribute("adminRol");
        } catch(IllegalStateException e) { AdministracionUsuarioHttp.error(res,401);return; }
        catch(RuntimeException e) { AdministracionUsuarioHttp.error(res,500);return; }
        try {
            Object cuerpo=servicio.ejecutar(op,actor,rol,req.getParameterMap());
            AdministracionUsuarioHttp.escribir(res,200,cuerpo);
        } catch(SecurityException e) { AdministracionUsuarioHttp.error(res,403); }
        catch(IllegalArgumentException e) { AdministracionUsuarioHttp.error(res,400); }
        catch(SQLException e) { AdministracionUsuarioHttp.error(res,DashboardAdministrativoHttp.estadoSql(e.getErrorCode())); }
        catch(RuntimeException | LinkageError e) { AdministracionUsuarioHttp.error(res,500); }
    }
}
