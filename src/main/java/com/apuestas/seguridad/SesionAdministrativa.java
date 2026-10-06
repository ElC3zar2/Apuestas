package com.apuestas.seguridad;

import com.apuestas.modelo.ResultadoLogin;
import com.apuestas.servicio.UsuarioServicio;
import javax.servlet.http.HttpSession;

/** Espacio de atributos independiente de la sesion de /usuario. */
public final class SesionAdministrativa {
    private SesionAdministrativa() { }
    public static boolean rolPermitido(Object rol) {
        return "ADMINISTRADOR".equals(rol) || "OPERADOR_EVENTOS".equals(rol)
                || "CAJERO".equals(rol) || "AUDITOR".equals(rol);
    }
    public static boolean estadoPermitido(Object estado) { return "ACTIVO".equals(estado); }
    private static boolean idValido(Object id) { return id instanceof Integer && (Integer) id > 0; }
    private static boolean correoValido(Object correo) {
        return correo instanceof String && UsuarioServicio.correoSesionValido((String) correo)
                && correo.equals(((String) correo).trim().toLowerCase(java.util.Locale.ROOT));
    }
    public static boolean resultadoValido(ResultadoLogin r) {
        return r != null && r.isAutenticado() && idValido(r.getIdUsuario())
                && idValido(r.getIdRol()) && correoValido(r.getCorreo())
                && rolPermitido(r.getRol()) && estadoPermitido(r.getEstadoUsuario());
    }
    public static boolean valida(HttpSession s) {
        return s != null && s.getAttribute("idUsuario") == null && s.getAttribute("rol") == null
                && idValido(s.getAttribute("adminIdUsuario"))
                && idValido(s.getAttribute("adminIdRol"))
                && correoValido(s.getAttribute("adminCorreo"))
                && rolPermitido(s.getAttribute("adminRol"))
                && estadoPermitido(s.getAttribute("adminEstadoUsuario"));
    }
    public static void guardar(HttpSession s, ResultadoLogin r) {
        if (!resultadoValido(r)) throw new IllegalStateException("Identidad administrativa invalida.");
        s.setAttribute("adminIdUsuario", r.getIdUsuario());
        s.setAttribute("adminCorreo", r.getCorreo());
        s.setAttribute("adminIdRol", r.getIdRol());
        s.setAttribute("adminRol", r.getRol());
        s.setAttribute("adminEstadoUsuario", r.getEstadoUsuario());
    }
}