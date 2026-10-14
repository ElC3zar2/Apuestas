package com.apuestas.controlador;

import com.apuestas.seguridad.CsrfSeguridad;
import com.apuestas.seguridad.CsrfSeguridad.Ambito;
import java.io.IOException;
import java.util.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

/** Entrega autenticada; no crea sesiones, no habilita CORS ni publica tokens en URL/logs. */
@WebServlet({CsrfSeguridad.RUTA_USUARIO,CsrfSeguridad.RUTA_ADMIN})
public class TokenCsrfServlet extends HttpServlet {
    @Override protected void service(HttpServletRequest req,HttpServletResponse res) throws IOException {
        AdministracionUsuarioHttp.preparar(res);
        res.setHeader("X-Content-Type-Options","nosniff");
        String ruta=req.getServletPath()+(req.getPathInfo()==null?"":req.getPathInfo());
        Ambito a=CsrfSeguridad.RUTA_USUARIO.equals(ruta)?Ambito.USUARIO:
                CsrfSeguridad.RUTA_ADMIN.equals(ruta)?Ambito.ADMINISTRADOR:null;
        if(a==null) {AdministracionUsuarioHttp.error(res,404);return;}
        if(!"GET".equals(req.getMethod())) {res.setHeader("Allow","GET");AdministracionUsuarioHttp.error(res,405);return;}
        try {
            HttpSession s=req.getSession(false);
            if(s==null) {AdministracionUsuarioHttp.error(res,401);return;}
            if(!CsrfSeguridad.autorizada(s,a)) {AdministracionUsuarioHttp.error(res,403);return;}
            if(!CsrfSeguridad.mismoOrigen(req)) {AdministracionUsuarioHttp.error(res,403);return;}
            if(req.getQueryString()!=null&&!req.getQueryString().isEmpty()||!req.getParameterMap().isEmpty()) {
                AdministracionUsuarioHttp.error(res,400);return;
            }
            Map<String,Object> json=new LinkedHashMap<>();json.put("ok",true);
            json.put("csrfToken",CsrfSeguridad.obtener(s,a));
            AdministracionUsuarioHttp.escribir(res,200,json);
        }catch(IllegalStateException e){AdministracionUsuarioHttp.error(res,401);}
        catch(SecurityException e){AdministracionUsuarioHttp.error(res,403);}
        catch(RuntimeException | LinkageError e){AdministracionUsuarioHttp.error(res,500);}
    }
}
