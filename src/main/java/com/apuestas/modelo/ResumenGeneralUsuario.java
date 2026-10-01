package com.apuestas.modelo;

import java.math.BigDecimal;

/** Valores oficiales del procedimiento SQL, sin recalculos ni sustitucion de nulos. */
public final class ResumenGeneralUsuario {
    private final int cantidadBoletos;
    private final Integer boletosPendientes;
    private final Integer boletosGanadores;
    private final Integer boletosPerdedores;
    private final Integer boletosAnulados;
    private final BigDecimal totalApostado;
    private final BigDecimal totalComisionesHistoricas;
    private final BigDecimal totalCargoHistorico;
    private final BigDecimal premioPotencialPendiente;
    private final BigDecimal gananciaNetaPotencialPendiente;
    private final BigDecimal totalPremiosGanadores;
    private final BigDecimal totalDevueltoPorAnulacion;
    private final BigDecimal resultadoNetoRealizado;
    private final BigDecimal porcentajeEfectividad;
    private final BigDecimal cuotaPromedio;
    private final BigDecimal probabilidadImplicitaPromedio;

    public ResumenGeneralUsuario(
            int cantidadBoletos,
            Integer boletosPendientes,
            Integer boletosGanadores,
            Integer boletosPerdedores,
            Integer boletosAnulados,
            BigDecimal totalApostado,
            BigDecimal totalComisionesHistoricas,
            BigDecimal totalCargoHistorico,
            BigDecimal premioPotencialPendiente,
            BigDecimal gananciaNetaPotencialPendiente,
            BigDecimal totalPremiosGanadores,
            BigDecimal totalDevueltoPorAnulacion,
            BigDecimal resultadoNetoRealizado,
            BigDecimal porcentajeEfectividad,
            BigDecimal cuotaPromedio,
            BigDecimal probabilidadImplicitaPromedio) {
        this.cantidadBoletos = cantidadBoletos;
        this.boletosPendientes = boletosPendientes;
        this.boletosGanadores = boletosGanadores;
        this.boletosPerdedores = boletosPerdedores;
        this.boletosAnulados = boletosAnulados;
        this.totalApostado = totalApostado;
        this.totalComisionesHistoricas = totalComisionesHistoricas;
        this.totalCargoHistorico = totalCargoHistorico;
        this.premioPotencialPendiente = premioPotencialPendiente;
        this.gananciaNetaPotencialPendiente = gananciaNetaPotencialPendiente;
        this.totalPremiosGanadores = totalPremiosGanadores;
        this.totalDevueltoPorAnulacion = totalDevueltoPorAnulacion;
        this.resultadoNetoRealizado = resultadoNetoRealizado;
        this.porcentajeEfectividad = porcentajeEfectividad;
        this.cuotaPromedio = cuotaPromedio;
        this.probabilidadImplicitaPromedio = probabilidadImplicitaPromedio;
    }

    public int getCantidadBoletos() { return cantidadBoletos; }
    public Integer getBoletosPendientes() { return boletosPendientes; }
    public Integer getBoletosGanadores() { return boletosGanadores; }
    public Integer getBoletosPerdedores() { return boletosPerdedores; }
    public Integer getBoletosAnulados() { return boletosAnulados; }
    public BigDecimal getTotalApostado() { return totalApostado; }
    public BigDecimal getTotalComisionesHistoricas() { return totalComisionesHistoricas; }
    public BigDecimal getTotalCargoHistorico() { return totalCargoHistorico; }
    public BigDecimal getPremioPotencialPendiente() { return premioPotencialPendiente; }
    public BigDecimal getGananciaNetaPotencialPendiente() { return gananciaNetaPotencialPendiente; }
    public BigDecimal getTotalPremiosGanadores() { return totalPremiosGanadores; }
    public BigDecimal getTotalDevueltoPorAnulacion() { return totalDevueltoPorAnulacion; }
    public BigDecimal getResultadoNetoRealizado() { return resultadoNetoRealizado; }
    public BigDecimal getPorcentajeEfectividad() { return porcentajeEfectividad; }
    public BigDecimal getCuotaPromedio() { return cuotaPromedio; }
    public BigDecimal getProbabilidadImplicitaPromedio() { return probabilidadImplicitaPromedio; }
}
