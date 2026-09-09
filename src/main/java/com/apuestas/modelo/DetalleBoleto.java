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
public class DetalleBoleto {

    private int idDetalle;

    private int idEvento;
    private String evento;

    private int idMercado;
    private String mercado;

    private int idSeleccion;
    private String seleccion;

    private BigDecimal cuotaAplicada;

    private String resultado;

    public DetalleBoleto() {
    }

    public int getIdDetalle() {
        return idDetalle;
    }

    public void setIdDetalle(int idDetalle) {
        this.idDetalle = idDetalle;
    }

    public int getIdEvento() {
        return idEvento;
    }

    public void setIdEvento(int idEvento) {
        this.idEvento = idEvento;
    }

    public String getEvento() {
        return evento;
    }

    public void setEvento(String evento) {
        this.evento = evento;
    }

    public int getIdMercado() {
        return idMercado;
    }

    public void setIdMercado(int idMercado) {
        this.idMercado = idMercado;
    }

    public String getMercado() {
        return mercado;
    }

    public void setMercado(String mercado) {
        this.mercado = mercado;
    }

    public int getIdSeleccion() {
        return idSeleccion;
    }

    public void setIdSeleccion(int idSeleccion) {
        this.idSeleccion = idSeleccion;
    }

    public String getSeleccion() {
        return seleccion;
    }

    public void setSeleccion(String seleccion) {
        this.seleccion = seleccion;
    }

    public BigDecimal getCuotaAplicada() {
        return cuotaAplicada;
    }

    public void setCuotaAplicada(BigDecimal cuotaAplicada) {
        this.cuotaAplicada = cuotaAplicada;
    }

    public String getResultado() {
        return resultado;
    }

    public void setResultado(String resultado) {
        this.resultado = resultado;
    }
}
