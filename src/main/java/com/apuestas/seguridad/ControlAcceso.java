package com.apuestas.seguridad;

import java.io.IOException;
import java.math.BigDecimal;
import java.util.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

@WebFilter(urlPatterns = "/usuario/*", dispatcherTypes = DispatcherType.REQUEST)
public class ControlAcceso implements Filter {
    private static final ObjectMapper JSON = new ObjectMapper();
    // Registro exacto de APIs JSON protegidas bajo este mapping. Nuevas APIs se agregan aqui.
    // Login, logout, recuperacion publica y descarga PDF conservan sus contratos propios.
    private static final Set<String> APIS = Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
            CsrfSeguridad.RUTA_USUARIO,
            "/usuario/boletos/historial",
            "/usuario/billetera/resumen",
            "/usuario/billetera/movimientos",
            "/usuario/analitica/resumen",
            "/usuario/analitica/deportes",
            "/usuario/seguridad/cambiar-contrasena",
            "/usuario/seguridad/verificacion-correo/solicitar")));

    @Override
    public void init(FilterConfig config) { }

    @Override
    public void destroy() { }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse res = (HttpServletResponse) response;
        String ruta = req.getServletPath();
        if (req.getPathInfo() != null) {
            ruta += req.getPathInfo();
        }
        if ("/usuario/login".equals(ruta) || "/usuario/login.jsp".equals(ruta)
                || "/usuario/logout".equals(ruta) || "/usuario/boletos/imprimir".equals(ruta)
                || "/usuario/seguridad/verificacion-correo/confirmar".equals(ruta)
                || "/usuario/seguridad/recuperacion-contrasena/solicitar".equals(ruta)
                || "/usuario/seguridad/recuperacion-contrasena/restablecer".equals(ruta)) {
            chain.doFilter(request, response);
            return;
        }

        res.setHeader("Cache-Control", "no-store");
        HttpSession sesion;
        Integer idUsuario;
        Object rol;
        try {
            sesion = req.getSession(false);
            idUsuario = sesion == null ? null : idValido(sesion.getAttribute("idUsuario"));
            rol = sesion == null ? null : sesion.getAttribute("rol");
        } catch (IllegalStateException e) {
            // La sesion pudo expirar concurrentemente.
            idUsuario = null;
            rol = null;
        }
        catch (RuntimeException e) {
            falloInterno(ruta,res);return;
        }
        if (idUsuario == null) {
            if (APIS.contains(ruta)) { errorApi(res,401); return; }
            res.setStatus(HttpServletResponse.SC_SEE_OTHER);
            res.setHeader("Location", req.getContextPath() + "/usuario/login");
            return;
        }
        if (!"USUARIO".equals(rol)) {
            if (APIS.contains(ruta)) { errorApi(res,403); return; }
            res.setStatus(HttpServletResponse.SC_FORBIDDEN);
            res.setContentType("text/plain;charset=UTF-8");
            res.getWriter().print("No tiene permiso para acceder a esta página.");
            return;
        }
        try {chain.doFilter(request,response);}
        catch(LinkageError e) {
            if(!APIS.contains(ruta)) throw e;
            if(!res.isCommitted()) {
                res.reset();res.setHeader("Cache-Control","no-store");errorApi(res,500);
            }
        }
    }
    private static void falloInterno(String ruta,HttpServletResponse res) throws IOException {
        if(APIS.contains(ruta)) {errorApi(res,500);return;}
        res.setStatus(500);res.setContentType("text/plain;charset=UTF-8");
        res.getWriter().print("No fue posible procesar la solicitud.");
    }

    private static void errorApi(HttpServletResponse res,int estado) throws IOException {
        res.setStatus(estado);
        res.setContentType("application/json;charset=UTF-8");
        Map<String,Object> cuerpo=new LinkedHashMap<>();
        cuerpo.put("ok",false);
        cuerpo.put("mensaje",estado==401?"Debe iniciar sesion con un usuario valido.":estado==403?"No tiene permiso para realizar esta operacion.":"No fue posible procesar la solicitud.");
        res.getWriter().print(JSON.writeValueAsString(cuerpo));
    }

    private Integer idValido(Object valor) {
        if (!(valor instanceof Number) && !(valor instanceof String)) return null;
        try {
            String texto = valor.toString().trim();
            if (valor instanceof String && !texto.matches("[0-9]+")) return null;
            int id = new BigDecimal(texto).intValueExact();
            return id > 0 ? id : null;
        } catch (ArithmeticException | NumberFormatException e) {
            return null;
        }
    }
}
