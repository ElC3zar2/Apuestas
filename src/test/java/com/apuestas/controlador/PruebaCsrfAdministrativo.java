package com.apuestas.controlador;

import com.apuestas.modelo.*;
import com.apuestas.seguridad.*;
import com.apuestas.seguridad.CsrfSeguridad.Ambito;
import java.util.*;
import javax.servlet.*;
import javax.servlet.http.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;

/** Cadena real del filtro administrativo; sesiones/HTTP simulados, sin JDBC ni red. */
public final class PruebaCsrfAdministrativo {
    private static int casos,fallos;
    interface Accion {void ejecutar()throws Exception;}
    /** Peticiones legitimas de regresion: token ligado a la sesion actual, sin cambiar aserciones. */
    static HttpServletRequest conToken(HttpServletRequest req,Http h) {
        String token=h.previa!=null&&!h.previa.expirada&&!h.previa.falloLectura
                &&SesionAdministrativa.valida(h.previa.ref)?CsrfSeguridad.obtener(h.previa.ref,Ambito.ADMINISTRADOR):null;
        return proxy(HttpServletRequest.class,(o,m,a)->{
            if(m.getName().equals("getHeaders")&&"X-CSRF-Token".equalsIgnoreCase((String)a[0]))
                return Collections.enumeration(token==null?Collections.emptyList():Collections.singletonList(token));
            if(m.getName().equals("getHeader"))return null;
            if(m.getName().equals("getQueryString"))return null;
            if(m.getName().equals("getParameterValues")&&"_csrf".equals(a[0]))return null;
            try{return m.invoke(req,a);}catch(java.lang.reflect.InvocationTargetException e){throw e.getCause();}
        });
    }
    private static void caso(String nombre,Accion accion) {
        casos++;
        try {accion.ejecutar();}
        catch(Exception|AssertionError e) {fallos++;System.out.println("FALLO "+nombre+": "+e.getClass().getSimpleName());}
    }
    private static List<String> rutas() {
        List<String> r=new ArrayList<>();
        for(OperacionAdministracionEventos o:OperacionAdministracionEventos.values())if("POST".equals(o.metodo))r.add(o.ruta);
        for(OperacionAdministracionUsuario o:OperacionAdministracionUsuario.values())if(!o.lectura())r.add(o.ruta);
        for(OperacionAdministracionResultados o:OperacionAdministracionResultados.values())r.add(o.ruta);
        for(OperacionLiquidacionAdministrativa o:OperacionLiquidacionAdministrativa.values())if("POST".equals(o.metodo))r.add(o.ruta);
        r.add("/administrador/logout");return r;
    }
    private static PruebaSeguridadBackend.C post(String ruta) {
        PruebaSeguridadBackend.C c=new PruebaSeguridadBackend.C(Ambito.ADMINISTRADOR);
        c.h.method="POST";c.h.ruta=ruta;return c;
    }
    private static void filtrar(PruebaSeguridadBackend.C c,int estado,int llamadas)throws Exception {
        HttpServletRequest entrada=proxy(HttpServletRequest.class,(o,m,a)->{
            if(m.getName().equals("getParameterNames"))return Collections.enumeration(c.p.keySet());
            try{return m.invoke(c.req,a);}catch(java.lang.reflect.InvocationTargetException e){throw e.getCause();}
        });
        new ControlAccesoAdministrativo().doFilter(entrada,c.res,(r,s)->{
            c.h.chain++;
            HttpServletRequest limpia=(HttpServletRequest)r;
            exigir(limpia.getParameter("_csrf")==null && limpia.getParameterValues("_csrf")==null);
            exigir(!limpia.getParameterMap().containsKey("_csrf"));
            exigir(!Collections.list(limpia.getParameterNames()).contains("_csrf"));
            if(c.p.containsKey("referenciaOperacion"))exigir("original".equals(limpia.getParameter("referenciaOperacion")));
            // La asociacion ya invoca el mismo filtro en el servlet: segunda pasada compatible.
            if(c.h.ruta.contains("/ligas/participantes/"))new FiltroCsrf().doFilter(r,s,(rr,ss)->exigir(rr==r));
            if("/administrador/logout".equals(c.h.ruta))new LogoutAdministrativoServlet().service(limpia,(HttpServletResponse)s);
        });
        exigir(c.h.status==estado&&c.h.chain==llamadas&&c.h.creaciones==0);
        String body=c.h.body.toString();
        exigir(!body.contains("SECRETO_INTERNO")&&!body.contains("SQLException")&&!body.contains("csrfToken"));
        if(estado==403||estado==401)exigir(c.h.previa==null||!c.h.previa.invalidada);
    }
    public static void main(String[] args)throws Exception {
        for(String ruta:rutas()) {
            for(String tipo:Arrays.asList("sin-token","incorrecto","otra-sesion","origin","cross-site","same-site","url","url-codificada","header-duplicado","campo-duplicado","contradictorio","sin-guardado","identidad-cambiada","mixta"))caso(ruta+" "+tipo,()->{
                PruebaSeguridadBackend.C c=post(ruta);String token=c.token(Ambito.ADMINISTRADOR);c.header("X-CSRF-Token",token);
                switch(tipo) {
                    case "sin-token":c.entrada.clear();break;
                    case "incorrecto":c.header("X-CSRF-Token","invalido");break;
                    case "otra-sesion":c.header("X-CSRF-Token",post(ruta).token(Ambito.ADMINISTRADOR));break;
                    case "origin":c.header("Origin","https://externo.example.invalid");break;
                    case "cross-site":case "same-site":c.header("Sec-Fetch-Site",tipo);break;
                    case "url":c.query="X-CSRF-Token="+token;break;
                    case "url-codificada":c.query="%5Fcsrf="+token;break;
                    case "header-duplicado":c.header("X-CSRF-Token",token,token);break;
                    case "campo-duplicado":c.p.put("_csrf",new String[]{token,token});break;
                    case "contradictorio":c.p.put("_csrf",new String[]{post(ruta).token(Ambito.ADMINISTRADOR)});break;
                    case "sin-guardado":c.h.previa.datos.keySet().removeIf(k->k.startsWith(CsrfSeguridad.class.getName()+"."));break;
                    case "identidad-cambiada":c.h.previa.datos.put("adminIdUsuario",8);break;
                    case "mixta":c.h.previa.datos.put("idUsuario",9);c.h.previa.datos.put("rol","USUARIO");break;
                    default:throw new AssertionError();
                }
                filtrar(c,403,0);
            });
            for(String transporte:Arrays.asList("header","campo","ambos"))caso(ruta+" valido "+transporte,()->{
                PruebaSeguridadBackend.C c=post(ruta);String token=c.token(Ambito.ADMINISTRADOR);
                if(!"campo".equals(transporte))c.header("X-CSRF-Token",token);
                if(!"header".equals(transporte))c.p.put("_csrf",new String[]{token});
                c.p.put("referenciaOperacion",new String[]{"original"});
                filtrar(c,ruta.endsWith("/logout")?303:200,1);
            });
            for(boolean expirada:new boolean[]{false,true})caso(ruta+" sesion "+expirada,()->{
                PruebaSeguridadBackend.C c=post(ruta);
                if(expirada)c.h.previa.expirada=true;else c.h.previa=null;
                filtrar(c,ruta.endsWith("/logout")?303:401,ruta.endsWith("/logout")?1:0);
            });
        }
        for(String metodo:new String[]{"GET","HEAD"})caso("lectura "+metodo,()->{
            PruebaSeguridadBackend.C c=post("/administrador/liquidaciones/consultar");c.h.method=metodo;
            new ControlAccesoAdministrativo().doFilter(c.req,c.res,(r,s)->c.h.chain++);exigir(c.h.chain==1);
        });
        caso("login inicial sin token",()->{
            PruebaSeguridadBackend.C c=post("/administrador/login");c.h.previa=null;
            new ControlAccesoAdministrativo().doFilter(c.req,c.res,(r,s)->c.h.chain++);exigir(c.h.chain==1);
        });
        caso("sin filtro CSRF global USUARIO",()->exigir(FiltroCsrf.class.getAnnotation(javax.servlet.annotation.WebFilter.class)==null));
        for(OperacionAdministracionUsuario op:OperacionAdministracionUsuario.values())if(!op.lectura())caso("servlet usuarios token campo "+op,()->{
            PruebaAdministracionUsuario.Caso c=new PruebaAdministracionUsuario.Caso(op);
            c.p("_csrf",c.csrf);c.csrf=null;c.ejecutar(200);exigir(c.j.llamadas==1);
        });
        System.out.println("CSRF administrativo: "+casos+" casos, "+fallos+" fallos; ninguna conexion JDBC.");
        if(fallos!=0)throw new AssertionError("CSRF administrativo: "+fallos+" fallos");
    }
}
