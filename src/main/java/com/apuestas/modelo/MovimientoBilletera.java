package com.apuestas.modelo;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public final class MovimientoBilletera {
    private final long idMovimiento;
    private final LocalDateTime fechaMovimiento;
    private final long idTransaccion;
    private final String referenciaOperacion;
    private final BigDecimal monto;
    private final LocalDateTime fechaSolicitud;
    private final LocalDateTime fechaProcesamiento;
    private final String descripcion;
    private final String tipoTransaccion;
    private final String nombreTipoTransaccion;
    private final String estadoTransaccion;
    private final Integer idBoleto;
    private final BigDecimal saldoDisponibleAnterior;
    private final BigDecimal saldoDisponiblePosterior;
    private final BigDecimal variacionSaldoDisponible;
    private final BigDecimal saldoComprometidoAnterior;
    private final BigDecimal saldoComprometidoPosterior;
    private final BigDecimal variacionSaldoComprometido;
    private final Integer idUsuarioProceso;
    private final String usuarioProceso;

    public MovimientoBilletera(
            long idMovimiento,
            LocalDateTime fechaMovimiento,
            long idTransaccion,
            String referenciaOperacion,
            BigDecimal monto,
            LocalDateTime fechaSolicitud,
            LocalDateTime fechaProcesamiento,
            String descripcion,
            String tipoTransaccion,
            String nombreTipoTransaccion,
            String estadoTransaccion,
            Integer idBoleto,
            BigDecimal saldoDisponibleAnterior,
            BigDecimal saldoDisponiblePosterior,
            BigDecimal variacionSaldoDisponible,
            BigDecimal saldoComprometidoAnterior,
            BigDecimal saldoComprometidoPosterior,
            BigDecimal variacionSaldoComprometido,
            Integer idUsuarioProceso,
            String usuarioProceso) {
        this.idMovimiento = idMovimiento;
        this.fechaMovimiento = fechaMovimiento;
        this.idTransaccion = idTransaccion;
        this.referenciaOperacion = referenciaOperacion;
        this.monto = monto;
        this.fechaSolicitud = fechaSolicitud;
        this.fechaProcesamiento = fechaProcesamiento;
        this.descripcion = descripcion;
        this.tipoTransaccion = tipoTransaccion;
        this.nombreTipoTransaccion = nombreTipoTransaccion;
        this.estadoTransaccion = estadoTransaccion;
        this.idBoleto = idBoleto;
        this.saldoDisponibleAnterior = saldoDisponibleAnterior;
        this.saldoDisponiblePosterior = saldoDisponiblePosterior;
        this.variacionSaldoDisponible = variacionSaldoDisponible;
        this.saldoComprometidoAnterior = saldoComprometidoAnterior;
        this.saldoComprometidoPosterior = saldoComprometidoPosterior;
        this.variacionSaldoComprometido = variacionSaldoComprometido;
        this.idUsuarioProceso = idUsuarioProceso;
        this.usuarioProceso = usuarioProceso;
    }

    public long getIdMovimiento() { return idMovimiento; }
    public LocalDateTime getFechaMovimiento() { return fechaMovimiento; }
    public long getIdTransaccion() { return idTransaccion; }
    public String getReferenciaOperacion() { return referenciaOperacion; }
    public BigDecimal getMonto() { return monto; }
    public LocalDateTime getFechaSolicitud() { return fechaSolicitud; }
    public LocalDateTime getFechaProcesamiento() { return fechaProcesamiento; }
    public String getDescripcion() { return descripcion; }
    public String getTipoTransaccion() { return tipoTransaccion; }
    public String getNombreTipoTransaccion() { return nombreTipoTransaccion; }
    public String getEstadoTransaccion() { return estadoTransaccion; }
    public Integer getIdBoleto() { return idBoleto; }
    public BigDecimal getSaldoDisponibleAnterior() { return saldoDisponibleAnterior; }
    public BigDecimal getSaldoDisponiblePosterior() { return saldoDisponiblePosterior; }
    public BigDecimal getVariacionSaldoDisponible() { return variacionSaldoDisponible; }
    public BigDecimal getSaldoComprometidoAnterior() { return saldoComprometidoAnterior; }
    public BigDecimal getSaldoComprometidoPosterior() { return saldoComprometidoPosterior; }
    public BigDecimal getVariacionSaldoComprometido() { return variacionSaldoComprometido; }
    public Integer getIdUsuarioProceso() { return idUsuarioProceso; }
    public String getUsuarioProceso() { return usuarioProceso; }
}
