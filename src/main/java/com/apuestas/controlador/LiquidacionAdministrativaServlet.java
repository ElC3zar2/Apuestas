package com.apuestas.controlador;

import com.apuestas.modelo.LiquidacionAdministrativaModelos.BoletoListo;
import com.apuestas.modelo.OperacionLiquidacionAdministrativa;
import com.apuestas.seguridad.SesionAdministrativa;
import com.apuestas.servicio.LiquidacionAdministrativaServicio;
import java.io.IOException;
import java.sql.SQLException;
import java.util.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import static com.apuestas.modelo.OperacionLiquidacionAdministrativa.*;

@WebServlet({"/administrador/liquidaciones/listos","/administrador/liquidaciones/liquidar","/administrador/liquidaciones/consultar"})
public class LiquidacionAdministrativaServlet extends HttpServlet {
    private LiquidacionAdministrativaServicio servicio;
    @Override public void init() { servicio=new LiquidacionAdministrativaServicio(); }
    @Override protected void service(HttpServletRequest req,HttpServletResponse res) throws IOException {
        AdministracionUsuarioHttp.preparar(res);req.setCharacterEncoding("UTF-8");
        OperacionLiquidacionAdministrativa op=OperacionLiquidacionAdministrativa.deRuta(
                req.getServletPath()+(req.getPathInfo()==null?"":req.getPathInfo()));
        if(op==null) { AdministracionUsuarioHttp.error(res,404);return; }
        if(!op.metodo.equals(req.getMethod())) {
            res.setHeader("Allow",op.metodo);AdministracionUsuarioHttp.error(res,405);return;
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
            LiquidacionAdministrativaServicio.autorizar(op,actor,rol);
            int parametro=LiquidacionAdministrativaServicio.parametro(op,req.getParameterMap());
            Map<String,Object> cuerpo=new LinkedHashMap<>();cuerpo.put("ok",true);
            if(op==LISTAR) {
                List<BoletoListo> boletos=servicio.listar(actor,rol,parametro);
                cuerpo.put("cantidad",boletos.size());cuerpo.put("boletos",boletos);
            } else if(op==LIQUIDAR) {
                cuerpo.put("resultado",servicio.liquidar(actor,rol,parametro,req.getRemoteAddr()));
            } else cuerpo.put("resultado",servicio.consultar(actor,rol,parametro));
            AdministracionUsuarioHttp.escribir(res,200,cuerpo);
        } catch(SecurityException e) { AdministracionUsuarioHttp.error(res,403); }
        catch(IllegalArgumentException e) { AdministracionUsuarioHttp.error(res,400); }
        catch(SQLException e) { AdministracionUsuarioHttp.error(res,LiquidacionAdministrativaHttp.estadoSql(e.getErrorCode())); }
        catch(RuntimeException | LinkageError e) { AdministracionUsuarioHttp.error(res,500); }
    }
}