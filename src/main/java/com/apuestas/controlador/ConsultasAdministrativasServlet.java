package com.apuestas.controlador;
import com.apuestas.modelo.OperacionConsultaAdministrativa;
import com.apuestas.seguridad.SesionAdministrativa;
import com.apuestas.servicio.ConsultasAdministrativasServicio;
import java.io.IOException;
import java.sql.*;
import java.util.NoSuchElementException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
@WebServlet({"/administrador/eventos/listar","/administrador/eventos/detalle","/administrador/catalogos/paises","/administrador/usuarios/buscar"})
public class ConsultasAdministrativasServlet extends HttpServlet {
    private ConsultasAdministrativasServicio servicio;
    @Override public void init(){servicio=new ConsultasAdministrativasServicio();}
    @Override protected void service(HttpServletRequest req,HttpServletResponse res)throws IOException {
        AdministracionUsuarioHttp.preparar(res);req.setCharacterEncoding("UTF-8");
        OperacionConsultaAdministrativa op=OperacionConsultaAdministrativa.deRuta(req.getServletPath()+(req.getPathInfo()==null?"":req.getPathInfo()));
        if(op==null){AdministracionUsuarioHttp.error(res,404);return;}
        if(!"GET".equals(req.getMethod())){res.setHeader("Allow","GET");AdministracionUsuarioHttp.error(res,405);return;}
        final int actor;final String rol;
        try {
            HttpSession s=req.getSession(false);
            if(s==null){AdministracionUsuarioHttp.error(res,401);return;}
            if(!SesionAdministrativa.valida(s)){AdministracionUsuarioHttp.error(res,403);return;}
            actor=(Integer)s.getAttribute("adminIdUsuario");rol=(String)s.getAttribute("adminRol");
        }catch(IllegalStateException e){AdministracionUsuarioHttp.error(res,401);return;}
        catch(RuntimeException e){AdministracionUsuarioHttp.error(res,500);return;}
        try {
            Object data=servicio.consultar(op,actor,rol,req.getParameterMap());
            AdministracionUsuarioHttp.escribir(res,200,data);
        }
        catch(SecurityException e){AdministracionUsuarioHttp.error(res,403);}
        catch(IllegalArgumentException e){AdministracionUsuarioHttp.error(res,400);}
        catch(NoSuchElementException e){AdministracionUsuarioHttp.error(res,404);}
        catch(SQLException e){int n=e.getErrorCode();AdministracionUsuarioHttp.error(res,e instanceof SQLTimeoutException||e instanceof SQLTransientConnectionException||n==1205||n==1222||n==76900?503:500);}
        catch(RuntimeException|LinkageError e){AdministracionUsuarioHttp.error(res,500);}
    }
}
