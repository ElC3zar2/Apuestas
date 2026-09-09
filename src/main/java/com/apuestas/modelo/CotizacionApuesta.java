/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.modelo;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 *
 * @author farfa
 */
public class CotizacionApuesta {

    private String tipoBoleto;
    private int cantidadSelecciones;
    private BigDecimal montoApostado;
    private BigDecimal cuotaTotal;
    private BigDecimal gananciaPotencial;
    private List<DetalleCotizacionApuesta> detalles;

    public CotizacionApuesta() {
        this.detalles = new ArrayList<>();
    }

    public String getTipoBoleto() {
        return tipoBoleto;
    }

    public void setTipoBoleto(String tipoBoleto) {
        this.tipoBoleto = tipoBoleto;
    }

    public int getCantidadSelecciones() {
        return cantidadSelecciones;
    }

    public void setCantidadSelecciones(int cantidadSelecciones) {
        this.cantidadSelecciones = cantidadSelecciones;
    }

    public BigDecimal getMontoApostado() {
        return montoApostado;
    }

    public void setMontoApostado(BigDecimal montoApostado) {
        this.montoApostado = montoApostado;
    }

    public BigDecimal getCuotaTotal() {
        return cuotaTotal;
    }

    public void setCuotaTotal(BigDecimal cuotaTotal) {
        this.cuotaTotal = cuotaTotal;
    }

    public BigDecimal getGananciaPotencial() {
        return gananciaPotencial;
    }

    public void setGananciaPotencial(BigDecimal gananciaPotencial) {
        this.gananciaPotencial = gananciaPotencial;
    }

    public List<DetalleCotizacionApuesta> getDetalles() {
        return detalles;
    }

    public void setDetalles(List<DetalleCotizacionApuesta> detalles) {
        this.detalles = detalles;
    }
}
