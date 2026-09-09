/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.modelo;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 *
 * @author farfa
 */
public class Boleto {

    private int idBoleto;
    private String codigoBoleto;

    private int idUsuario;
    private String correo;

    private String tipoBoleto;

    private BigDecimal montoApostado;
    private BigDecimal cuotaTotal;
    private BigDecimal gananciaPotencial;

    private String resultado;
    private String estadoBoleto;

    private LocalDateTime fechaCreacion;
    private LocalDateTime fechaLiquidacion;

    private String referenciaOperacion;

    private List<DetalleBoleto> detalles;

    public Boleto() {
        this.detalles = new ArrayList<>();
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

    public void setCodigoBoleto(String codigoBoleto) {
        this.codigoBoleto = codigoBoleto;
    }

    public int getIdUsuario() {
        return idUsuario;
    }

    public void setIdUsuario(int idUsuario) {
        this.idUsuario = idUsuario;
    }

    public String getCorreo() {
        return correo;
    }

    public void setCorreo(String correo) {
        this.correo = correo;
    }

    public String getTipoBoleto() {
        return tipoBoleto;
    }

    public void setTipoBoleto(String tipoBoleto) {
        this.tipoBoleto = tipoBoleto;
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

    public String getResultado() {
        return resultado;
    }

    public void setResultado(String resultado) {
        this.resultado = resultado;
    }

    public String getEstadoBoleto() {
        return estadoBoleto;
    }

    public void setEstadoBoleto(String estadoBoleto) {
        this.estadoBoleto = estadoBoleto;
    }

    public LocalDateTime getFechaCreacion() {
        return fechaCreacion;
    }

    public void setFechaCreacion(LocalDateTime fechaCreacion) {
        this.fechaCreacion = fechaCreacion;
    }

    public LocalDateTime getFechaLiquidacion() {
        return fechaLiquidacion;
    }

    public void setFechaLiquidacion(LocalDateTime fechaLiquidacion) {
        this.fechaLiquidacion = fechaLiquidacion;
    }

    public String getReferenciaOperacion() {
        return referenciaOperacion;
    }

    public void setReferenciaOperacion(String referenciaOperacion) {
        this.referenciaOperacion = referenciaOperacion;
    }

    public List<DetalleBoleto> getDetalles() {
        return detalles;
    }

    public void setDetalles(List<DetalleBoleto> detalles) {
        this.detalles = detalles;
    }
}