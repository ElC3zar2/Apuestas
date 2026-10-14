package com.apuestas.seguridad;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.net.URI;
import java.net.URLDecoder;
import java.util.*;
import javax.servlet.http.*;

/** Infraestructura de token sincronizado. No activa rechazos en endpoints existentes. */
public final class CsrfSeguridad {
    public static final String RUTA_USUARIO="/usuario/seguridad/csrf";
    public static final String RUTA_ADMIN="/administrador/seguridad/csrf";
    public enum Ambito { USUARIO, ADMINISTRADOR }
    private CsrfSeguridad() { }
    private static String clave(Ambito a) { return CsrfSeguridad.class.getName()+"."+a.name(); }
    public static boolean autorizada(HttpSession s,Ambito a) {
        if(s==null||a==null) return false;
        if(a==Ambito.ADMINISTRADOR) return SesionAdministrativa.valida(s);
        Object id=s.getAttribute("idUsuario");
        return id instanceof Integer && (Integer)id>0 && "USUARIO".equals(s.getAttribute("rol"))
                && s.getAttribute("adminIdUsuario")==null && s.getAttribute("adminRol")==null;
    }
    private static String identidad(HttpSession s,Ambito a) {
        return String.valueOf(s.getAttribute(a==Ambito.USUARIO?"idUsuario":"adminIdUsuario"))+":"+
                s.getAttribute(a==Ambito.USUARIO?"rol":"adminRol");
    }
    private static final class TokenSesion implements java.io.Serializable {
        private static final long serialVersionUID=1L;
        final String identidad,token;
        TokenSesion(String id) { identidad=id;token=TokenSeguridad.generar(); }
    }
    public static String obtener(HttpSession s,Ambito a) {
        if(s==null) throw new SecurityException();
        synchronized(s) {
            if(!autorizada(s,a)) throw new SecurityException();
            Object guardado=s.getAttribute(clave(a));String id=identidad(s,a);
            TokenSesion t=guardado instanceof TokenSesion?(TokenSesion)guardado:null;
            if(t==null||!t.identidad.equals(id)) {t=new TokenSesion(id);s.setAttribute(clave(a),t);}
            return t.token;
        }
    }
    /** Origin se compara con el origen del contenedor, nunca con cabeceras forwarded del cliente. */
    public static boolean mismoOrigen(HttpServletRequest req) {
        String sitio=req.getHeader("Sec-Fetch-Site");
        if(sitio!=null&&!Arrays.asList("same-origin","none").contains(sitio)) return false;
        String origen=req.getHeader("Origin");if(origen==null) return true;
        try {
            URI u=new URI(origen);
            int puerto=u.getPort()<0?("https".equalsIgnoreCase(u.getScheme())?443:80):u.getPort();
            return u.getUserInfo()==null && u.getQuery()==null && u.getFragment()==null
                    && (u.getPath()==null||u.getPath().isEmpty())
                    && req.getScheme().equalsIgnoreCase(u.getScheme())
                    && req.getServerName().equalsIgnoreCase(u.getHost()) && req.getServerPort()==puerto;
        } catch(Exception e) {return false;}
    }
    private static boolean tokenEnUrl(HttpServletRequest req) {
        String q=req.getQueryString();if(q==null) return false;
        try {
            for(String parte:q.split("&")) {
                String nombre=URLDecoder.decode(parte.split("=",2)[0],StandardCharsets.UTF_8.name());
                if("_csrf".equals(nombre)||"X-CSRF-Token".equalsIgnoreCase(nombre)) return true;
            }
            return false;
        }catch(Exception e){return true;}
    }
    /** Nunca genera un token al validar; aceptar solo el almacenado previamente en esta sesion. */
    public static boolean validar(HttpServletRequest req,Ambito a) {
        try {
            HttpSession s=req.getSession(false);
            if(s==null||!mismoOrigen(req)||tokenEnUrl(req)) return false;
            synchronized(s) {
                if(!autorizada(s,a)) return false;
                Object guardado=s.getAttribute(clave(a));
                if(!(guardado instanceof TokenSesion)) return false;
                TokenSesion t=(TokenSesion)guardado;
                if(!t.identidad.equals(identidad(s,a))) return false;
                Enumeration<String> headers=req.getHeaders("X-CSRF-Token");
                String header=null;
                if(headers!=null&&headers.hasMoreElements()) {header=headers.nextElement();if(headers.hasMoreElements()) return false;}
                String[] valores=req.getParameterValues("_csrf");String campo=null;
                if(valores!=null) {if(valores.length!=1) return false;campo=valores[0];}
                if(header!=null&&campo!=null&&!iguales(header,campo)) return false;
                String recibido=header==null?campo:header;
                return TokenSeguridad.esValido(recibido)&&iguales(t.token,recibido);
            }
        } catch(IllegalStateException e) {return false;}
    }
    private static boolean iguales(String a,String b) {
        return a!=null&&b!=null&&MessageDigest.isEqual(a.getBytes(StandardCharsets.US_ASCII),b.getBytes(StandardCharsets.US_ASCII));
    }
}
