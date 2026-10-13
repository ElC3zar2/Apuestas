package com.apuestas.controlador;

import com.apuestas.seguridad.ControlAcceso;
import com.apuestas.modelo.*;
import com.apuestas.servicio.*;
import com.fasterxml.jackson.databind.*;
import java.lang.reflect.*;
import java.io.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import javax.servlet.*;
import javax.servlet.annotation.*;
import javax.servlet.http.*;

/** Filtro y dispatch reales de los servlets; HTTP/JDBC son dobles, nunca SQL/SMTP. */
public final class PruebaCadenaControlAcceso {
    static int casos;
    static void exigir(boolean valor,String mensaje){if(!valor)throw new AssertionError(mensaje);}
    @SuppressWarnings("unchecked") static <T>T proxy(Class<T> tipo,InvocationHandler h){return (T)Proxy.newProxyInstance(tipo.getClassLoader(),new Class<?>[]{tipo},h);}
    static void inyectar(Object objeto,String campo,Object valor)throws Exception{Field f=objeto.getClass().getDeclaredField(campo);f.setAccessible(true);f.set(objeto,valor);}
    static class Http {
        String ruta,contexto="",metodo="GET",pathInfo,tipo;
        boolean existe=true,expirada,expirarEnCadena;Object id=7,rol="USUARIO";
        int estado=200,cadena;Map<String,String> headers=new HashMap<>();StringWriter cuerpo=new StringWriter();
        HttpSession sesion=proxy(HttpSession.class,(p,m,a)->{
            exigir(m.getName().equals("getAttribute"),"No modificar sesion");if(expirada)throw new IllegalStateException("PRIVADO");
            if(a[0].equals("idUsuario"))return id;if(a[0].equals("rol"))return rol;if(a[0].equals("correo"))return "prueba@example.invalid";
            throw new AssertionError("Atributo no esperado");
        });
        HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)->{
            switch(m.getName()) {
                case "getServletPath":return ruta;case "getPathInfo":return pathInfo;case "getContextPath":return contexto;
                case "getMethod":return metodo;case "getProtocol":return "HTTP/1.1";
                case "getSession":exigir(a!=null && a.length==1 && Boolean.FALSE.equals(a[0]),"No crear sesion");return existe?sesion:null;
                case "getParameter":return null;
                case "setCharacterEncoding":return null;
                default:throw new AssertionError("Request " + m.getName());
            }
        });
        HttpServletResponse res=proxy(HttpServletResponse.class,(p,m,a)->{
            switch(m.getName()) {
                case "setStatus":estado=(Integer)a[0];return null;
                case "setHeader":headers.put((String)a[0],(String)a[1]);return null;
                case "setContentType":tipo=(String)a[0];return null;
                case "getWriter":return new PrintWriter(cuerpo);
                default:throw new AssertionError("Response " + m.getName());
            }
        });
        void ejecutar(HttpServlet servlet)throws Exception {
            new ControlAcceso().doFilter(req,res,(r,s)->{cadena++;if(expirarEnCadena)expirada=true;if(servlet!=null)servlet.service(r,s);});casos++;
        }
        JsonNode json(int codigo)throws Exception {
            exigir(estado==codigo,"Estado " + ruta + ": " + estado + " esperado " + codigo);
            exigir("application/json;charset=UTF-8".equals(tipo),"JSON UTF-8");
            exigir("no-store".equals(headers.get("Cache-Control")) && !headers.containsKey("Location"),"Sin redirect/cache");
            exigir(!cuerpo.toString().contains("PRIVADO") && !cuerpo.toString().contains("<html"),"Sin detalles internos/HTML");
            JsonNode n=new ObjectMapper().readTree(cuerpo.toString());
            if(codigo!=200)exigir(n.size()==2 && !n.path("ok").asBoolean() && n.path("mensaje").isTextual(),"Contrato error");
            return n;
        }
    }
    static HttpServlet servlet(Class<? extends HttpServlet> clase)throws Exception {
        HttpServlet s=clase.getDeclaredConstructor().newInstance();
        if(s instanceof HistorialBoletosUsuarioServlet)inyectar(s,"analiticaServicio",new AnaliticaUsuarioServicio(new PruebaHistorialBoletosUsuario.Jdbc()));
        if(s instanceof ResumenGeneralUsuarioServlet || s instanceof ResumenUsuarioPorDeporteServlet)
            inyectar(s,"analiticaServicio",new AnaliticaUsuarioServicio(new PruebaResumenAnaliticaUsuario.Jdbc(s instanceof ResumenUsuarioPorDeporteServlet)));
        if(s instanceof BilleteraResumenServlet || s instanceof MovimientosBilleteraServlet)inyectar(s,"billeteraServicio",new BilleteraServicio(){
            @Override public BilleteraUsuario obtenerBilletera(int id){exigir(id==7,"Identidad sesion");return new BilleteraUsuario(7,"prueba@example.invalid","USUARIO","ACTIVO",9,BigDecimal.TEN,BigDecimal.ZERO,BigDecimal.TEN,LocalDateTime.of(2026,10,1,0,0));}
            @Override public List<MovimientoBilletera> obtenerMovimientosBilletera(int id,LocalDateTime desde,LocalDateTime hasta,int cantidad){exigir(id==7,"Identidad sesion");return Collections.emptyList();}
        });
        return s;
    }
    public static void main(String[] args)throws Exception {
        List<Class<? extends HttpServlet>> apis=Arrays.asList(HistorialBoletosUsuarioServlet.class,BilleteraResumenServlet.class,MovimientosBilleteraServlet.class,ResumenGeneralUsuarioServlet.class,ResumenUsuarioPorDeporteServlet.class,CambiarContrasenaUsuarioServlet.class,SolicitarVerificacionCorreoServlet.class);
        for(Class<? extends HttpServlet> clase:apis) {
            String ruta=clase.getAnnotation(WebServlet.class).value()[0];boolean seguridad=ruta.contains("/seguridad/");
            for(String contexto:Arrays.asList("","/otra-aplicacion")) {
                for(int modo=0;modo<4;modo++) {
                    Http h=new Http();h.ruta=ruta;h.contexto=contexto;
                    h.existe=modo!=0;h.expirada=modo==1;if(modo==2)h.rol="ADMINISTRADOR";
                    h.metodo=seguridad && modo!=3?"POST":"GET";
                    h.ejecutar(servlet(clase));
                    int esperado=modo<2?401:modo==2?403:seguridad?405:200;
                    h.json(esperado);exigir(h.cadena==(modo==3?1:0),"Corte o dispatch real");
                }
            }
            if(!seguridad) {
                Http h=new Http();h.ruta=ruta;h.metodo="POST";h.ejecutar(servlet(clase));h.json(405);
                exigir(h.cadena==1 && "GET".equals(h.headers.get("Allow")),"Servlet conserva metodo");
                h=new Http();h.ruta=ruta;h.contexto="/otra-aplicacion";h.expirarEnCadena=true;
                h.ejecutar(servlet(clase));h.json(401);exigir(h.cadena==1,"Expiracion despues del filtro");
            }
            Http h=new Http();h.ruta=ruta;h.id=new BigDecimal("7.5");h.ejecutar(servlet(clase));h.json(401);exigir(h.cadena==0,"Identidad fraccionaria");
        }
        // Rutas no registradas siguen protegidas como navegacion, sin inferir API por prefijos.
        for(String ruta:Arrays.asList("/usuario/inicio.jsp","/usuario/futura.jsp","/usuario/futura-api","/usuario/login/otra","/usuario/boletos/historial/otra")) {
            Http h=new Http();h.ruta=ruta;h.existe=false;h.contexto="/otra-aplicacion";h.ejecutar(null);
            exigir(h.estado==303 && h.cadena==0 && "/otra-aplicacion/usuario/login".equals(h.headers.get("Location")),"Navegacion contextPath");
        }
        Http h=new Http();h.ruta="/usuario/boletos/historial";h.pathInfo="/otra";h.existe=false;h.ejecutar(null);exigir(h.estado==303,"Registro exacto con pathInfo");
        for(String ruta:Arrays.asList("/usuario/login","/usuario/login.jsp","/usuario/logout","/usuario/boletos/imprimir","/usuario/seguridad/verificacion-correo/confirmar","/usuario/seguridad/recuperacion-contrasena/solicitar","/usuario/seguridad/recuperacion-contrasena/restablecer")) {
            h=new Http();h.ruta=ruta;h.existe=false;h.ejecutar(null);exigir(h.cadena==1 && h.estado==200 && h.headers.isEmpty(),"Contrato excluido " + ruta);
        }
        WebFilter usuario=ControlAcceso.class.getAnnotation(WebFilter.class);
        exigir(Arrays.equals(usuario.urlPatterns(),new String[]{"/usuario/*"}) && Arrays.equals(usuario.dispatcherTypes(),new DispatcherType[]{DispatcherType.REQUEST}),"Mapping usuario limitado");
        WebFilter admin=com.apuestas.seguridad.ControlAccesoAdministrativo.class.getAnnotation(WebFilter.class);
        exigir(Arrays.equals(admin.urlPatterns(),new String[]{"/administrador/*"}),"Mapping admin independiente");
        casos++;
        System.out.println("OK: " + casos + " casos de cadena filtro -> servlet, 0 fallos; sin SQL/SMTP.");
    }
}
