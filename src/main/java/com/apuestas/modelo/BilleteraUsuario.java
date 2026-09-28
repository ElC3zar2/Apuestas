package com.apuestas.modelo;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public final class BilleteraUsuario {
    private final int idUsuario;
    private final String correo;
    private final String rol;
    private final String estadoUsuario;
    private final int idBilletera;
    private final BigDecimal saldoDisponible;
    private final BigDecimal saldoComprometido;
    private final BigDecimal saldoVirtualTotal;
    private final LocalDateTime fechaCreacion;

    public BilleteraUsuario(
            int idUsuario,
            String correo,
            String rol,
            String estadoUsuario,
            int idBilletera,
            BigDecimal saldoDisponible,
            BigDecimal saldoComprometido,
            BigDecimal saldoVirtualTotal,
            LocalDateTime fechaCreacion) {
        this.idUsuario = idUsuario;
        this.correo = correo;
        this.rol = rol;
        this.estadoUsuario = estadoUsuario;
        this.idBilletera = idBilletera;
        this.saldoDisponible = saldoDisponible;
        this.saldoComprometido = saldoComprometido;
        this.saldoVirtualTotal = saldoVirtualTotal;
        this.fechaCreacion = fechaCreacion;
    }

    public int getIdUsuario() { return idUsuario; }
    public String getCorreo() { return correo; }
    public String getRol() { return rol; }
    public String getEstadoUsuario() { return estadoUsuario; }
    public int getIdBilletera() { return idBilletera; }
    public BigDecimal getSaldoDisponible() { return saldoDisponible; }
    public BigDecimal getSaldoComprometido() { return saldoComprometido; }
    public BigDecimal getSaldoVirtualTotal() { return saldoVirtualTotal; }
    public LocalDateTime getFechaCreacion() { return fechaCreacion; }
}
