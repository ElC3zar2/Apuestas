package com.apuestas.modelo;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;

/** Datos del contrato oficial de analitica; no recalcula indicadores. */
public final class AnaliticaBoletoUsuario {
    private final int idBoleto;
    private final String codigoBoleto;
    private final String tipoBoleto;
    private final String resultado;
    private final String estadoBoleto;
    private final LocalDateTime fechaCreacion;
    private final LocalDateTime fechaLiquidacion;
    private final BigDecimal montoApostado;
    private final BigDecimal comisionServicio;
    private final BigDecimal totalCargo;
    private final BigDecimal cuotaTotal;
    private final BigDecimal premioPotencial;
    private final BigDecimal gananciaNetaPotencial;
    private final BigDecimal porcentajeGananciaPotencial;
    private final BigDecimal probabilidadImplicitaPorcentaje;
    private final int cantidadSelecciones;
    private final List<DetalleAnaliticaBoletoUsuario> detalles = new ArrayList<>();

    public AnaliticaBoletoUsuario(
            int idBoleto,
            String codigoBoleto,
            String tipoBoleto,
            String resultado,
            String estadoBoleto,
            LocalDateTime fechaCreacion,
            LocalDateTime fechaLiquidacion,
            BigDecimal montoApostado,
            BigDecimal comisionServicio,
            BigDecimal totalCargo,
            BigDecimal cuotaTotal,
            BigDecimal premioPotencial,
            BigDecimal gananciaNetaPotencial,
            BigDecimal porcentajeGananciaPotencial,
            BigDecimal probabilidadImplicitaPorcentaje,
            int cantidadSelecciones) {
        this.idBoleto = idBoleto;
        this.codigoBoleto = codigoBoleto;
        this.tipoBoleto = tipoBoleto;
        this.resultado = resultado;
        this.estadoBoleto = estadoBoleto;
        this.fechaCreacion = fechaCreacion;
        this.fechaLiquidacion = fechaLiquidacion;
        this.montoApostado = montoApostado;
        this.comisionServicio = comisionServicio;
        this.totalCargo = totalCargo;
        this.cuotaTotal = cuotaTotal;
        this.premioPotencial = premioPotencial;
        this.gananciaNetaPotencial = gananciaNetaPotencial;
        this.porcentajeGananciaPotencial = porcentajeGananciaPotencial;
        this.probabilidadImplicitaPorcentaje = probabilidadImplicitaPorcentaje;
        this.cantidadSelecciones = cantidadSelecciones;
    }

    public int getIdBoleto() { return idBoleto; }
    public String getCodigoBoleto() { return codigoBoleto; }
    public String getTipoBoleto() { return tipoBoleto; }
    public String getResultado() { return resultado; }
    public String getEstadoBoleto() { return estadoBoleto; }
    public LocalDateTime getFechaCreacion() { return fechaCreacion; }
    public LocalDateTime getFechaLiquidacion() { return fechaLiquidacion; }
    public BigDecimal getMontoApostado() { return montoApostado; }
    public BigDecimal getComisionServicio() { return comisionServicio; }
    public BigDecimal getTotalCargo() { return totalCargo; }
    public BigDecimal getCuotaTotal() { return cuotaTotal; }
    public BigDecimal getPremioPotencial() { return premioPotencial; }
    public BigDecimal getGananciaNetaPotencial() { return gananciaNetaPotencial; }
    public BigDecimal getPorcentajeGananciaPotencial() { return porcentajeGananciaPotencial; }
    public BigDecimal getProbabilidadImplicitaPorcentaje() { return probabilidadImplicitaPorcentaje; }
    public int getCantidadSelecciones() { return cantidadSelecciones; }
    public List<DetalleAnaliticaBoletoUsuario> getDetalles() {
        return Collections.unmodifiableList(detalles);
    }
    public void agregarDetalle(DetalleAnaliticaBoletoUsuario detalle) {
        detalles.add(Objects.requireNonNull(detalle));
    }
}
