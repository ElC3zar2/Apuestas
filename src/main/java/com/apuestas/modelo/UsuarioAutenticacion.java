package com.apuestas.modelo;

import java.time.LocalDateTime;

/** Datos del contrato SQL; no almacenar este objeto en sesion. */
public final class UsuarioAutenticacion {
    private final int idUsuario;
    private final String correo;
    private final String hashContrasena;
    private final boolean correoVerificado;
    private final int intentosFallidos;
    private final LocalDateTime bloqueadoHasta;
    private final LocalDateTime ultimoAcceso;
    private final int idRol;
    private final String rol;
    private final int idEstado;
    private final String estadoUsuario;
    private final String nombreEstadoUsuario;
    private final boolean bloqueoVigente;
    private final boolean puedeIniciarSesion;

    public UsuarioAutenticacion(
            int idUsuario,
            String correo,
            String hashContrasena,
            boolean correoVerificado,
            int intentosFallidos,
            LocalDateTime bloqueadoHasta,
            LocalDateTime ultimoAcceso,
            int idRol,
            String rol,
            int idEstado,
            String estadoUsuario,
            String nombreEstadoUsuario,
            boolean bloqueoVigente,
            boolean puedeIniciarSesion) {
        this.idUsuario = idUsuario;
        this.correo = correo;
        this.hashContrasena = hashContrasena;
        this.correoVerificado = correoVerificado;
        this.intentosFallidos = intentosFallidos;
        this.bloqueadoHasta = bloqueadoHasta;
        this.ultimoAcceso = ultimoAcceso;
        this.idRol = idRol;
        this.rol = rol;
        this.idEstado = idEstado;
        this.estadoUsuario = estadoUsuario;
        this.nombreEstadoUsuario = nombreEstadoUsuario;
        this.bloqueoVigente = bloqueoVigente;
        this.puedeIniciarSesion = puedeIniciarSesion;
    }

    public int getIdUsuario() {
        return idUsuario;
    }

    public String getCorreo() {
        return correo;
    }

    public String getHashContrasena() {
        return hashContrasena;
    }

    public boolean isCorreoVerificado() {
        return correoVerificado;
    }

    public int getIntentosFallidos() {
        return intentosFallidos;
    }

    public LocalDateTime getBloqueadoHasta() {
        return bloqueadoHasta;
    }

    public LocalDateTime getUltimoAcceso() {
        return ultimoAcceso;
    }

    public int getIdRol() {
        return idRol;
    }

    public String getRol() {
        return rol;
    }

    public int getIdEstado() {
        return idEstado;
    }

    public String getEstadoUsuario() {
        return estadoUsuario;
    }

    public String getNombreEstadoUsuario() {
        return nombreEstadoUsuario;
    }

    public boolean isBloqueoVigente() {
        return bloqueoVigente;
    }

    public boolean isPuedeIniciarSesion() {
        return puedeIniciarSesion;
    }
}
