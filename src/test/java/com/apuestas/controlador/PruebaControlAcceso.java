package com.apuestas.controlador;

import com.apuestas.seguridad.ControlAcceso;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.Proxy;
import java.math.BigDecimal;
import java.util.*;
import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

/** Pruebas main con proxies estrictos: ningun acceso SQL ni cambios de datos reales. */
public class PruebaControlAcceso {
    private static int casos;
    private static void exigir(boolean condicion, String mensaje) {
        if (!condicion) throw new AssertionError(mensaje);
    }

    private static class Caso {
        String ruta = "/usuario/inicio.jsp", pathInfo, contexto = "/PlataformaApuestas", metodo = "POST";
        boolean existe = true, expirada, faltaId;
        Object id = 7, rol = "USUARIO";
        int estado = 200, cadenas, sesiones, invalidaciones;
        String tipo;
        final Map<String,String> headers = new HashMap<>();
        final StringWriter cuerpo = new StringWriter();
        final HttpSession sesion = (HttpSession) Proxy.newProxyInstance(
                getClass().getClassLoader(), new Class<?>[]{HttpSession.class}, (p,m,a) -> {
                    switch (m.getName()) {
                        case "getAttribute":
                            if (expirada) throw new IllegalStateException("Expirada");
                            if ("idUsuario".equals(a[0])) return faltaId ? null : id;
                            if ("rol".equals(a[0])) return rol;
                            throw new AssertionError("No validar estado ni correo en filtro");
                        case "invalidate":
                            invalidaciones++;
                            if (expirada) throw new IllegalStateException("Ya invalidada");
                            return null;
                        default: throw new AssertionError("Sesion inesperada: " + m.getName());
                    }
                });
        final HttpServletRequest request = (HttpServletRequest) Proxy.newProxyInstance(
                getClass().getClassLoader(), new Class<?>[]{HttpServletRequest.class}, (p,m,a) -> {
                    switch (m.getName()) {
                        case "getServletPath": return ruta;
                        case "getPathInfo": return pathInfo;
                        case "getContextPath": return contexto;
                        case "getSession":
                            exigir(a != null && a.length == 1 && Boolean.FALSE.equals(a[0]),
                                    "Nunca crear sesion");
                            sesiones++;
                            return existe ? sesion : null;
                        case "getMethod": return metodo;
                        case "getProtocol": return "HTTP/1.1";
                        default: throw new AssertionError("No leer parametros ni atributos request: " + m.getName());
                    }
                });
        final HttpServletResponse response = (HttpServletResponse) Proxy.newProxyInstance(
                getClass().getClassLoader(), new Class<?>[]{HttpServletResponse.class}, (p,m,a) -> {
                    switch (m.getName()) {
                        case "setStatus": case "sendError": estado = (Integer) a[0]; return null;
                        case "setHeader": headers.put((String)a[0],(String)a[1]); return null;
                        case "setContentType": tipo = (String)a[0]; return null;
                        case "getWriter": return new PrintWriter(cuerpo);
                        default: throw new AssertionError("Response: " + m.getName());
                    }
                });

        void filtrar() throws Exception {
            new ControlAcceso().doFilter(request, response, (req,res) -> {
                exigir(req == request && res == response, "Conservar request y response");
                cadenas++;
            });
            casos++;
        }

        void redireccion() {
            exigir(estado == 303 && (contexto + "/usuario/login").equals(headers.get("Location")),
                    "303 y Location");
            exigir("no-store".equals(headers.get("Cache-Control")), "No-store");
        }
    }

    public static void main(String[] args) throws Exception {
        WebFilter filtro = ControlAcceso.class.getAnnotation(WebFilter.class);
        exigir(Arrays.equals(filtro.urlPatterns(),new String[]{"/usuario/*"}), "Patron exclusivo usuario");
        exigir(Arrays.equals(filtro.dispatcherTypes(),new DispatcherType[]{DispatcherType.REQUEST}),
                "Solo REQUEST, no FORWARD/INCLUDE/ERROR");
        exigir("/registro".equals(RegistroUsuarioServlet.class.getAnnotation(WebServlet.class).value()[0]),
                "Registro permanece fuera del filtro");
        exigir(Arrays.equals(CerrarSesionServlet.class.getAnnotation(WebServlet.class).value(),
                new String[]{"/usuario/logout"}), "Mapping logout");

        for (String ruta : new String[]{"/usuario/login","/usuario/login.jsp",
                "/usuario/logout","/usuario/boletos/imprimir"}) {
            Caso c = new Caso(); c.ruta = ruta; c.existe = false; c.filtrar();
            exigir(c.cadenas == 1 && c.sesiones == 0 && c.headers.isEmpty(),
                    "Exclusion exacta sin interceptar: " + ruta);
        }
        for (String contexto : new String[]{"", "/PlataformaApuestas"}) {
            Caso c = new Caso(); c.contexto = contexto; c.existe = false; c.filtrar();
            c.redireccion();
            exigir(c.cadenas == 0 && c.sesiones == 1, "No pasar sin sesion");
        }
        Caso c = new Caso(); c.faltaId = true; c.filtrar(); c.redireccion();
        for (Object id : new Object[]{null,0,-1,"","abc","7.5",new BigDecimal("7.5"),
                4294967303L,Double.NaN,Double.POSITIVE_INFINITY,true}) {
            c = new Caso(); c.id = id; c.filtrar(); c.redireccion();
            exigir(c.cadenas == 0 && c.invalidaciones == 0, "Id invalido no autentica");
        }
        c = new Caso(); c.expirada = true; c.filtrar(); c.redireccion();
        for (Object id : new Object[]{7,7L," 7 ",new BigDecimal("7.0")}) {
            c = new Caso(); c.id = id; c.filtrar();
            exigir(c.cadenas == 1 && c.estado == 200 && !c.headers.containsKey("Location"),
                    "Usuario valido sin redirect; no consulta estado ni correo");
        }
        for (Object rol : new Object[]{"ADMINISTRADOR","CASA",null,"usuario","USUARIO ",
                "OPERADOR_EVENTOS","CAJERO","AUDITOR",1}) {
            c = new Caso(); c.rol = rol; c.filtrar();
            exigir(c.estado == 403 && c.cadenas == 0 && c.invalidaciones == 0, "Rol rechazado");
            exigir("no-store".equals(c.headers.get("Cache-Control"))
                    && "text/plain;charset=UTF-8".equals(c.tipo), "403 UTF-8 no-store");
            exigir(c.cuerpo.toString().equals("No tiene permiso para acceder a esta página."),
                    "Mensaje generico sin atributos");
        }
        for (String ruta : new String[]{"/usuario/registro.jsp","/usuario/futura.jsp",
                "/usuario/login/otra","/usuario/boletos/imprimir/otra"}) {
            c = new Caso(); c.ruta = ruta; c.existe = false; c.filtrar(); c.redireccion();
            exigir(c.cadenas == 0, "No ampliar exclusiones");
        }
        c = new Caso(); c.ruta = "/usuario/login"; c.pathInfo = "/otra";
        c.existe = false; c.filtrar(); c.redireccion();

        for (String contexto : new String[]{"", "/PlataformaApuestas"}) {
            for (int modo = 0; modo < 4; modo++) {
                c = new Caso(); c.contexto = contexto;
                c.existe = modo != 1;
                c.expirada = modo == 2;
                if (modo == 3) { c.id = null; c.rol = "CASA"; }
                new CerrarSesionServlet().doPost(c.request,c.response);
                c.redireccion();
                exigir(c.sesiones == 1 && c.invalidaciones == (c.existe ? 1 : 0),
                        "Invalidar exactamente sesion previa, ninguna nueva");
                exigir(c.headers.size() == 2, "Sin manipulacion manual de cookies");
                casos++;
            }
        }
        c = new Caso(); c.metodo = "GET";
        new CerrarSesionServlet().service(c.request,c.response);
        exigir(c.estado == 405 && c.invalidaciones == 0 && c.sesiones == 0,
                "GET logout no invalida");
        casos++;

        // Regresion segura de ImprimirBoleto: no llega a servicio ni a SQL.
        c = new Caso(); c.existe = false;
        new ImprimirBoletoServlet().doGet(c.request, respuestaImprimir(c));
        exigir(c.estado == 401 && !c.headers.containsKey("Location"), "Imprimir mantiene 401");
        casos++;
        System.out.println("OK: " + casos + " casos de filtro, logout e imprimir; sin SQL.");
    }

    private static HttpServletResponse respuestaImprimir(Caso c) {
        return (HttpServletResponse) Proxy.newProxyInstance(
                PruebaControlAcceso.class.getClassLoader(),
                new Class<?>[]{HttpServletResponse.class}, (p,m,a) -> {
                    if ("setCharacterEncoding".equals(m.getName()) || "reset".equals(m.getName())) return null;
                    if ("isCommitted".equals(m.getName())) return false;
                    return m.invoke(c.response,a);
                });
    }
}
