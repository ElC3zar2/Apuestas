package com.apuestas.controlador;

import com.apuestas.seguridad.SesionAdministrativa;
import com.apuestas.servicio.AdministracionResultadosServicio;
import java.io.IOException;
import java.sql.*;
import java.util.NoSuchElementException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet(ConsultaResultadoEventoServlet.RUTA)
public class ConsultaResultadoEventoServlet extends HttpServlet {
    public static final String RUTA="/administrador/resultados/por-evento";
    private AdministracionResultadosServicio servicio;
    @Override public void init(){servicio=new AdministracionResultadosServicio();}
    @Override protected void service(HttpServletRequest req,HttpServletResponse res) throws IOException {
        AdministracionUsuarioHttp.preparar(res);req.setCharacterEncoding("UTF-8");
        if(!RUTA.equals(req.getServletPath()+(req.getPathInfo()==null?"":req.getPathInfo()))) {
            AdministracionUsuarioHttp.error(res,404);return;
        }
        if(!"GET".equals(req.getMethod())) {res.setHeader("Allow","GET");AdministracionUsuarioHttp.error(res,405);return;}
        final int actor;final String rol;
        try {
            HttpSession s=req.getSession(false);
            if(s==null){AdministracionUsuarioHttp.error(res,401);return;}
            if(!SesionAdministrativa.valida(s)){AdministracionUsuarioHttp.error(res,403);return;}
            actor=(Integer)s.getAttribute("adminIdUsuario");rol=(String)s.getAttribute("adminRol");
        }catch(IllegalStateException e){AdministracionUsuarioHttp.error(res,401);return;}
        catch(RuntimeException e){AdministracionUsuarioHttp.error(res,500);return;}
        try {
            AdministracionUsuarioHttp.escribir(res,200,servicio.consultarPorEvento(actor,rol,req.getParameterMap()));
        }catch(SecurityException e){AdministracionUsuarioHttp.error(res,403);}
        catch(IllegalArgumentException e){AdministracionUsuarioHttp.error(res,400);}
        catch(NoSuchElementException e){AdministracionUsuarioHttp.error(res,404);}
        catch(SQLException e){
            int c=e.getErrorCode();
            AdministracionUsuarioHttp.error(res,e instanceof SQLTimeoutException||e instanceof SQLTransientConnectionException
                    ||c==1205||c==1222||c==76900?503:500);
        }catch(RuntimeException | LinkageError e){AdministracionUsuarioHttp.error(res,500);}
    }
}
