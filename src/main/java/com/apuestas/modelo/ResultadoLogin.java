package com.apuestas.modelo;

/** Resultado del servicio sin credenciales ni datos internos de bloqueo. */
public final class ResultadoLogin {
    private final boolean autenticado;
    private final Integer idUsuario;
    private final String correo;
    private final Integer idRol;
    private final String rol;
    private final String estadoUsuario;
    private final Boolean correoVerificado;

    private ResultadoLogin(boolean autenticado, Integer idUsuario, String correo,
            Integer idRol, String rol, String estadoUsuario, Boolean correoVerificado) {
        this.autenticado = autenticado;
        this.idUsuario = idUsuario;
        this.correo = correo;
        this.idRol = idRol;
        this.rol = rol;
        this.estadoUsuario = estadoUsuario;
        this.correoVerificado = correoVerificado;
    }

    public static ResultadoLogin rechazado() {
        return new ResultadoLogin(false, null, null, null, null, null, null);
    }

    public static ResultadoLogin autenticado(int idUsuario, String correo, int idRol,
            String rol, String estadoUsuario, boolean correoVerificado) {
        return new ResultadoLogin(true, idUsuario, correo, idRol, rol,
                estadoUsuario, correoVerificado);
    }

    public boolean isAutenticado() { return autenticado; }
    public Integer getIdUsuario() { return idUsuario; }
    public String getCorreo() { return correo; }
    public Integer getIdRol() { return idRol; }
    public String getRol() { return rol; }
    public String getEstadoUsuario() { return estadoUsuario; }
    public Boolean getCorreoVerificado() { return correoVerificado; }
}
