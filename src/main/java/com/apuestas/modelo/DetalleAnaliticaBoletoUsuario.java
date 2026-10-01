package com.apuestas.modelo;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;

/** Datos del contrato oficial de analitica; no recalcula indicadores. */
public final class DetalleAnaliticaBoletoUsuario {
    private final int idBoleto;
    private final String codigoBoleto;
    private final int idDetalle;
    private final int idDeporte;
    private final String deporte;
    private final int idLiga;
    private final String liga;
    private final int idEvento;
    private final String evento;
    private final LocalDateTime fechaInicio;
    private final int idMercado;
    private final String mercado;
    private final int idSeleccion;
    private final String seleccion;
    private final BigDecimal cuotaAplicada;
    private final BigDecimal probabilidadImplicitaSeleccionPorcentaje;
    private final String resultadoSeleccion;

    public DetalleAnaliticaBoletoUsuario(
            int idBoleto,
            String codigoBoleto,
            int idDetalle,
            int idDeporte,
            String deporte,
            int idLiga,
            String liga,
            int idEvento,
            String evento,
            LocalDateTime fechaInicio,
            int idMercado,
            String mercado,
            int idSeleccion,
            String seleccion,
            BigDecimal cuotaAplicada,
            BigDecimal probabilidadImplicitaSeleccionPorcentaje,
            String resultadoSeleccion) {
        this.idBoleto = idBoleto;
        this.codigoBoleto = codigoBoleto;
        this.idDetalle = idDetalle;
        this.idDeporte = idDeporte;
        this.deporte = deporte;
        this.idLiga = idLiga;
        this.liga = liga;
        this.idEvento = idEvento;
        this.evento = evento;
        this.fechaInicio = fechaInicio;
        this.idMercado = idMercado;
        this.mercado = mercado;
        this.idSeleccion = idSeleccion;
        this.seleccion = seleccion;
        this.cuotaAplicada = cuotaAplicada;
        this.probabilidadImplicitaSeleccionPorcentaje = probabilidadImplicitaSeleccionPorcentaje;
        this.resultadoSeleccion = resultadoSeleccion;
    }

    public int getIdBoleto() { return idBoleto; }
    public String getCodigoBoleto() { return codigoBoleto; }
    public int getIdDetalle() { return idDetalle; }
    public int getIdDeporte() { return idDeporte; }
    public String getDeporte() { return deporte; }
    public int getIdLiga() { return idLiga; }
    public String getLiga() { return liga; }
    public int getIdEvento() { return idEvento; }
    public String getEvento() { return evento; }
    public LocalDateTime getFechaInicio() { return fechaInicio; }
    public int getIdMercado() { return idMercado; }
    public String getMercado() { return mercado; }
    public int getIdSeleccion() { return idSeleccion; }
    public String getSeleccion() { return seleccion; }
    public BigDecimal getCuotaAplicada() { return cuotaAplicada; }
    public BigDecimal getProbabilidadImplicitaSeleccionPorcentaje() { return probabilidadImplicitaSeleccionPorcentaje; }
    public String getResultadoSeleccion() { return resultadoSeleccion; }
}
