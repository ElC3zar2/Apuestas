package com.apuestas.modelo;

import java.time.LocalDateTime;

/** Resultado interno de SQL; no contiene token ni hash y no se serializa por HTTP. */
public final class ResultadoTokenVerificacionCorreo {
    private final boolean tokenCreado;
    private final Integer idToken, idUsuario;
    private final LocalDateTime fechaExpiracion;

    public ResultadoTokenVerificacionCorreo(boolean tokenCreado, Integer idToken,
            Integer idUsuario, LocalDateTime fechaExpiracion) {
        this.tokenCreado = tokenCreado;
        this.idToken = idToken;
        this.idUsuario = idUsuario;
        this.fechaExpiracion = fechaExpiracion;
    }

    public boolean isTokenCreado() { return tokenCreado; }
    public Integer getIdToken() { return idToken; }
    public Integer getIdUsuario() { return idUsuario; }
    public LocalDateTime getFechaExpiracion() { return fechaExpiracion; }
}
