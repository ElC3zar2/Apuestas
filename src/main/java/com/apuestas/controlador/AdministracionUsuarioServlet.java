package com.apuestas.controlador;

import com.apuestas.modelo.AdministracionUsuarioModelos.*;
import com.apuestas.modelo.OperacionAdministracionUsuario;
import com.apuestas.seguridad.SesionAdministrativa;
import com.apuestas.servicio.AdministracionUsuarioServicio;
import java.io.IOException;
import java.sql.SQLException;
import java.time.*;
import java.util.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet({
    "/administrador/usuarios/pendientes","/administrador/usuarios/detalle",
    "/administrador/usuarios/verificacion/iniciar","/administrador/usuarios/verificacion/aprobar",
    "/administrador/usuarios/verificacion/rechazar","/administrador/usuarios/verificacion/reabrir",
    "/administrador/usuarios/estado/cambiar","/administrador/usuarios/restricciones/agregar",
    "/administrador/usuarios/restricciones/levantar"
})
public class AdministracionUsuarioServlet extends HttpServlet {
    private AdministracionUsuarioServicio servicio;
    @Override public void init(){servicio=new AdministracionUsuarioServicio();}
    @Override protected void service(HttpServletRequest req,HttpServletResponse res)throws IOException {
        AdministracionUsuarioHttp.preparar(res);req.setCharacterEncoding("UTF-8");
        OperacionAdministracionUsuario op=OperacionAdministracionUsuario.deRuta(
                req.getServletPath()+(req.getPathInfo()==null?"":req.getPathInfo()));
        if(op==null){AdministracionUsuarioHttp.error(res,404);return;}
        if(!op.metodo.equals(req.getMethod())){
            res.setHeader("Allow",op.metodo);AdministracionUsuarioHttp.error(res,405);return;
        }
        final int actor;final String rol;
        try {
            HttpSession sesion=req.getSession(false);
            if(sesion==null){AdministracionUsuarioHttp.error(res,401);return;}
            if(!SesionAdministrativa.valida(sesion)){AdministracionUsuarioHttp.error(res,403);return;}
            // Solo atributos validados por SesionAdministrativa; nunca parametros del navegador.
            actor=(Integer)sesion.getAttribute("adminIdUsuario");
            rol=(String)sesion.getAttribute("adminRol");
        }catch(IllegalStateException e){AdministracionUsuarioHttp.error(res,401);return;}
        catch(RuntimeException e){AdministracionUsuarioHttp.error(res,500);return;}
        try {
            AdministracionUsuarioServicio.autorizar(actor,rol,op.lectura());
            Map<String,String[]> params=req.getParameterMap();
            for(Map.Entry<String,String[]> e:params.entrySet()){
                if(!op.parametros.contains(e.getKey())||e.getValue()==null||e.getValue().length!=1)
                    throw new IllegalArgumentException();
            }
            Map<String,Object> salida=new LinkedHashMap<>();salida.put("ok",true);
            if(op==OperacionAdministracionUsuario.PENDIENTES){
                String cantidad=parametro(params,"cantidad");
                List<Pendiente> usuarios=servicio.pendientes(actor,rol,cantidad==null?100:entero(cantidad));
                salida.put("cantidad",usuarios.size());salida.put("usuarios",usuarios);
            }else if(op==OperacionAdministracionUsuario.DETALLE){
                salida.put("detalle",servicio.detalle(actor,rol,entero(parametro(params,"idUsuario"))));
            }else{
                String id=op==OperacionAdministracionUsuario.LEVANTAR?"idRestriccion":
                        (op==OperacionAdministracionUsuario.INICIAR||op==OperacionAdministracionUsuario.APROBAR
                        ||op==OperacionAdministracionUsuario.RECHAZAR)?"idVerificacion":"idUsuario";
                String campoTexto=op==OperacionAdministracionUsuario.LEVANTAR?"motivoLevantamiento":
                        (op==OperacionAdministracionUsuario.INICIAR||op==OperacionAdministracionUsuario.APROBAR
                        ||op==OperacionAdministracionUsuario.REABRIR)?"observacion":"motivo";
                String clasificacion=parametro(params,op==OperacionAdministracionUsuario.ESTADO?"nuevoEstado":"tipoRestriccion");
                salida.put("resultado",servicio.accion(op,actor,rol,entero(parametro(params,id)),
                        parametro(params,campoTexto),clasificacion,fecha(parametro(params,"fechaFin")),req.getRemoteAddr()));
            }
            AdministracionUsuarioHttp.escribir(res,200,salida);
        }catch(SecurityException e){AdministracionUsuarioHttp.error(res,403);}
        catch(IllegalArgumentException | java.time.format.DateTimeParseException e){AdministracionUsuarioHttp.error(res,400);}
        catch(SQLException e){AdministracionUsuarioHttp.error(res,AdministracionUsuarioHttp.estadoSql(e.getErrorCode()));}
        catch(RuntimeException | LinkageError e){AdministracionUsuarioHttp.error(res,500);}
    }
    private static String parametro(Map<String,String[]> p,String nombre){String[] v=p.get(nombre);return v==null?null:v[0];}
    private static int entero(String s){
        if(s==null||!s.trim().matches("[0-9]{1,10}"))throw new IllegalArgumentException();
        int n=Integer.parseInt(s.trim());if(n<=0)throw new IllegalArgumentException();return n;
    }
    private static LocalDateTime fecha(String s){
        if(s==null||s.trim().isEmpty())return null;
        if(!s.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{1,7})?"))
            throw new IllegalArgumentException();
        LocalDateTime f=LocalDateTime.parse(s);
        if(f.getYear()<1)throw new IllegalArgumentException();return f;
    }
}