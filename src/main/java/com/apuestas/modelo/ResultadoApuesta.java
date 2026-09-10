/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.modelo;

import java.math.BigDecimal;

/**
 *
 * @author farfa
 */
public class ResultadoApuesta {

    private int idBoleto;
    private String codigoBoleto;

    private String tipoBoleto;
    private int cantidadSelecciones;

    private BigDecimal montoApostado;
    private BigDecimal comisionServicioPorcentaje;
    private BigDecimal comisionServicio;
    private BigDecimal totalCargo;

    private BigDecimal cuotaTotal;
    private BigDecimal gananciaPotencial;

    public ResultadoApuesta() {
    }

    public int getIdBoleto() {
        return idBoleto;
    }

    public void setIdBoleto(int idBoleto) {
        this.idBoleto = idBoleto;
    }

    public String getCodigoBoleto() {
        return codigoBoleto;
    }

    public void setCodigoBoleto(
            String codigoBoleto) {
        this.codigoBoleto = codigoBoleto;
    }

    public String getTipoBoleto() {
        return tipoBoleto;
    }

    public void setTipoBoleto(
            String tipoBoleto) {
        this.tipoBoleto = tipoBoleto;
    }

    public int getCantidadSelecciones() {
        return cantidadSelecciones;
    }

    public void setCantidadSelecciones(
            int cantidadSelecciones) {
        this.cantidadSelecciones =
                cantidadSelecciones;
    }

    public BigDecimal getMontoApostado() {
        return montoApostado;
    }

    public void setMontoApostado(
            BigDecimal montoApostado) {
        this.montoApostado = montoApostado;
    }

    public BigDecimal getComisionServicioPorcentaje() {
        return comisionServicioPorcentaje;
    }

    public void setComisionServicioPorcentaje(
            BigDecimal comisionServicioPorcentaje) {
        this.comisionServicioPorcentaje =
                comisionServicioPorcentaje;
    }

    public BigDecimal getComisionServicio() {
        return comisionServicio;
    }

    public void setComisionServicio(
            BigDecimal comisionServicio) {
        this.comisionServicio = comisionServicio;
    }

    public BigDecimal getTotalCargo() {
        return totalCargo;
    }

    public void setTotalCargo(
            BigDecimal totalCargo) {
        this.totalCargo = totalCargo;
    }

    public BigDecimal getCuotaTotal() {
        return cuotaTotal;
    }

    public void setCuotaTotal(
            BigDecimal cuotaTotal) {
        this.cuotaTotal = cuotaTotal;
    }

    public BigDecimal getGananciaPotencial() {
        return gananciaPotencial;
    }

    public void setGananciaPotencial(
            BigDecimal gananciaPotencial) {
        this.gananciaPotencial =
                gananciaPotencial;
    }
}