package com.apuestas.modelo;

import java.math.BigDecimal;

/** Datos oficiales congelados; no contiene calculos ni ofertas actuales. */
public class DatosModalidadBoleto {
    private String tipoMercadoAplicado;
    public String getTipoMercadoAplicado() { return tipoMercadoAplicado; }
    public void setTipoMercadoAplicado(String valor) { tipoMercadoAplicado=valor; }
    private Integer pronosticoA;
    public Integer getPronosticoA() { return pronosticoA; }
    public void setPronosticoA(Integer valor) { pronosticoA=valor; }
    private Integer pronosticoB;
    public Integer getPronosticoB() { return pronosticoB; }
    public void setPronosticoB(Integer valor) { pronosticoB=valor; }
    private BigDecimal cuotaResultadoAplicada;
    public BigDecimal getCuotaResultadoAplicada() { return cuotaResultadoAplicada; }
    public void setCuotaResultadoAplicada(BigDecimal valor) { cuotaResultadoAplicada=valor; }
    private BigDecimal cuotaLiquidacion;
    public BigDecimal getCuotaLiquidacion() { return cuotaLiquidacion; }
    public void setCuotaLiquidacion(BigDecimal valor) { cuotaLiquidacion=valor; }
    private String clasificacionAcierto;
    public String getClasificacionAcierto() { return clasificacionAcierto; }
    public void setClasificacionAcierto(String valor) { clasificacionAcierto=valor; }
    private String nombreEventoAplicado;
    public String getNombreEventoAplicado() { return nombreEventoAplicado; }
    public void setNombreEventoAplicado(String valor) { nombreEventoAplicado=valor; }
    private String nombreParticipanteAAplicado;
    public String getNombreParticipanteAAplicado() { return nombreParticipanteAAplicado; }
    public void setNombreParticipanteAAplicado(String valor) { nombreParticipanteAAplicado=valor; }
    private String nombreParticipanteBAplicado;
    public String getNombreParticipanteBAplicado() { return nombreParticipanteBAplicado; }
    public void setNombreParticipanteBAplicado(String valor) { nombreParticipanteBAplicado=valor; }
    private String nombreSeleccionAplicada;
    public String getNombreSeleccionAplicada() { return nombreSeleccionAplicada; }
    public void setNombreSeleccionAplicada(String valor) { nombreSeleccionAplicada=valor; }
}
