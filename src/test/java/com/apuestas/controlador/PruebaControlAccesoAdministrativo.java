package com.apuestas.controlador;

import com.apuestas.seguridad.*;
import java.util.*;
import javax.servlet.*;
import javax.servlet.annotation.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;

/** Pruebas ejecutables del filtro y logout, sin consultas ni sesiones reales. */
public class PruebaControlAccesoAdministrativo {
    private static int casos;
    private static Http contexto(){
        Http h=new Http();h.method="GET";h.ruta="/administrador/inicio.jsp";
        h.previa=new Sesion();
        h.previa.datos.put("adminIdUsuario",7);h.previa.datos.put("adminIdRol",3);
        h.previa.datos.put("adminCorreo","admin@example.test");
        h.previa.datos.put("adminRol","ADMINISTRADOR");
        h.previa.datos.put("adminEstadoUsuario","ACTIVO");return h;
    }
    private static void filtrar(Http h)throws Exception {
        new ControlAccesoAdministrativo().doFilter(h.req,h.res,(r,s)->{h.chain++;});
        h.comun();exigir(h.creaciones==0);casos++;
    }
    private static void logout(Http h)throws Exception{
        new LogoutAdministrativoServlet().service(h.req,h.res);
        h.comun();exigir(h.creaciones==0);casos++;
    }
    public static void main(String[] args)throws Exception {
        WebFilter f=ControlAccesoAdministrativo.class.getAnnotation(WebFilter.class);
        exigir(Arrays.equals(f.urlPatterns(),new String[]{"/administrador/*"}));
        exigir(Arrays.equals(f.dispatcherTypes(),new DispatcherType[]{DispatcherType.REQUEST,DispatcherType.FORWARD}));
        exigir(Arrays.equals(LoginAdministrativoServlet.class.getAnnotation(WebServlet.class).value(),new String[]{"/administrador/login"}));
        exigir(Arrays.equals(LogoutAdministrativoServlet.class.getAnnotation(WebServlet.class).value(),new String[]{"/administrador/logout"}));casos++;
        for(String ruta:new String[]{"/administrador/login","/administrador/logout"}){
            Http h=contexto();h.ruta=ruta;h.previa=null;filtrar(h);exigir(h.chain==1);
        }
        Http h=contexto();h.ruta="/administrador/login.jsp";h.previa=null;
        filtrar(h);exigir(h.status==303&&h.chain==0&&h.headers.get("Location").equals("/app/administrador/login"));
        h=contexto();h.ruta="/administrador/login.jsp";h.dispatcher=DispatcherType.FORWARD;h.previa=null;
        filtrar(h);exigir(h.chain==1);
        h=contexto();h.ruta="/administrador/login.jsp";h.method="POST";h.previa=null;
        filtrar(h);exigir(h.status==405&&h.chain==0);
        for(String ruta:new String[]{"/administrador/login/otra","/administrador/login.jsp/otra",
                "/administrador/logout/otra","/administrador/login-falso","/administrador/api/futura"}){
            h=contexto();h.ruta=ruta;h.previa=null;filtrar(h);exigir(h.status==401&&h.chain==0);
        }
        h=contexto();h.ruta="/administrador/login";h.pathInfo="/otra";h.previa=null;
        filtrar(h);exigir(h.status==401&&h.chain==0);
        for(String contexto:new String[]{"","/app"}){
            h=contexto();h.contexto=contexto;h.previa=null;filtrar(h);
            exigir(h.status==303&&h.headers.get("Location").equals(contexto+"/administrador/login")&&h.chain==0);
        }
        h=contexto();h.previa.expirada=true;filtrar(h);exigir(h.status==303&&h.chain==0);
        h=contexto();h.previa.falloLectura=true;filtrar(h);exigir(h.status==500&&h.chain==0);
        for(String clave:new String[]{"adminIdUsuario","adminIdRol"}){
            for(Object id:new Object[]{null,0,-1,"7",7L,1.2,true,Double.NaN}){
                h=contexto();h.previa.datos.put(clave,id);filtrar(h);exigir(h.status==403&&h.chain==0);
            }
        }
        for(Object rol:new Object[]{null,"","USUARIO","CASA","ADMIN","ADMINISTRADOR ","administrador",7}){
            h=contexto();h.previa.datos.put("adminRol",rol);filtrar(h);exigir(h.status==403&&h.chain==0);
        }
        for(String rol:new String[]{"ADMINISTRADOR","OPERADOR_EVENTOS","CAJERO","AUDITOR"}){
            h=contexto();h.previa.datos.put("adminRol",rol);filtrar(h);exigir(h.status==200&&h.chain==1);
        }
        for(Object correo:new Object[]{null,"","x"," ADMIN@EXAMPLE.TEST ","a".repeat(151)+"@t.t",7}){
            h=contexto();h.previa.datos.put("adminCorreo",correo);filtrar(h);exigir(h.status==403&&h.chain==0);
        }
        for(Object estado:new Object[]{null,"","PENDIENTE","INACTIVO","SUSPENDIDO","ACTIVO ",7}){
            h=contexto();h.previa.datos.put("adminEstadoUsuario",estado);filtrar(h);exigir(h.status==403&&h.chain==0);
        }
        for(String rol:new String[]{"USUARIO","ADMINISTRADOR"}){
            h=contexto();h.previa.datos.clear();h.previa.datos.put("idUsuario",7);h.previa.datos.put("rol",rol);
            filtrar(h);exigir(h.status==403&&h.chain==0);
        }
        h=contexto();h.previa.datos.put("idUsuario",99);h.previa.datos.put("rol","USUARIO");
        filtrar(h);exigir(h.status==403&&h.chain==0);
        h=contexto();h.previa.datos.clear();h.previa.datos.put("adminRol","ADMINISTRADOR");
        filtrar(h);exigir(h.status==403&&h.chain==0);
        h=contexto();h.dispatcher=DispatcherType.FORWARD;h.previa=null;filtrar(h);exigir(h.status==303&&h.chain==0);
        for(String metodo:new String[]{"GET","HEAD","PUT","DELETE","OPTIONS"}){
            h=contexto();h.method=metodo;logout(h);
            exigir(h.status==405&&!h.previa.invalidada&&"POST".equals(h.headers.get("Allow")));
        }
        for(String contexto:new String[]{"","/app"}){
            h=contexto();h.method="POST";h.contexto=contexto;logout(h);
            exigir(h.status==303&&h.previa.invalidada&&h.headers.get("Location").equals(contexto+"/administrador/login"));
            h=contexto();h.method="POST";h.contexto=contexto;h.previa=null;logout(h);
            exigir(h.status==303&&h.headers.get("Location").equals(contexto+"/administrador/login"));
        }
        h=contexto();h.method="POST";h.previa.expirada=true;logout(h);exigir(h.status==303);
        h=contexto();h.method="POST";h.previa.datos.clear();h.previa.datos.put("rol","USUARIO");
        logout(h);exigir(h.status==403&&!h.previa.invalidada);
        h=contexto();h.method="POST";h.previa.falloLectura=true;logout(h);exigir(h.status==500);
        System.out.println("Control administrativo: "+casos+" casos, 0 fallos.");
    }
}