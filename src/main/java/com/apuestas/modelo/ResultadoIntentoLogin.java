package com.apuestas.modelo;

import java.time.LocalDateTime;

/** Datos del contrato SQL; no almacenar este objeto en sesion. */
public final class ResultadoIntentoLogin {
    private final int idUsuario;
    private final int intentosFallidos;
    private final LocalDateTime bloqueadoHasta;
    private final boolean bloqueoVigente;
    private final boolean autenticacionPermitida;
    private final String estadoUsuario;

    public ResultadoIntentoLogin(
            int idUsuario,
            int intentosFallidos,
            LocalDateTime bloqueadoHasta,
            boolean bloqueoVigente,
            boolean autenticacionPermitida,
            String estadoUsuario) {
        this.idUsuario = idUsuario;
        this.intentosFallidos = intentosFallidos;
        this.bloqueadoHasta = bloqueadoHasta;
        this.bloqueoVigente = bloqueoVigente;
        this.autenticacionPermitida = autenticacionPermitida;
        this.estadoUsuario = estadoUsuario;
    }

    public int getIdUsuario() {
        return idUsuario;
    }

    public int getIntentosFallidos() {
        return intentosFallidos;
    }

    public LocalDateTime getBloqueadoHasta() {
        return bloqueadoHasta;
    }

    public boolean isBloqueoVigente() {
        return bloqueoVigente;
    }

    public boolean isAutenticacionPermitida() {
        return autenticacionPermitida;
    }

    public String getEstadoUsuario() {
        return estadoUsuario;
    }
}
