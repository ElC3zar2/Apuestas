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
public class DetalleCotizacionApuesta {

    private int orden;

    private int idEvento;
    private String nombreEvento;

    private int idMercado;
    private String nombreMercado;

    private int idSeleccion;
    private String nombreSeleccion;

    private int idCuota;
    private BigDecimal cuota;

    public DetalleCotizacionApuesta() {
    }

    public int getOrden() {
        return orden;
    }

    public void setOrden(int orden) {
        this.orden = orden;
    }

    public int getIdEvento() {
        return idEvento;
    }

    public void setIdEvento(int idEvento) {
        this.idEvento = idEvento;
    }

    public String getNombreEvento() {
        return nombreEvento;
    }

    public void setNombreEvento(String nombreEvento) {
        this.nombreEvento = nombreEvento;
    }

    public int getIdMercado() {
        return idMercado;
    }

    public void setIdMercado(int idMercado) {
        this.idMercado = idMercado;
    }

    public String getNombreMercado() {
        return nombreMercado;
    }

    public void setNombreMercado(String nombreMercado) {
        this.nombreMercado = nombreMercado;
    }

    public int getIdSeleccion() {
        return idSeleccion;
    }

    public void setIdSeleccion(int idSeleccion) {
        this.idSeleccion = idSeleccion;
    }

    public String getNombreSeleccion() {
        return nombreSeleccion;
    }

    public void setNombreSeleccion(String nombreSeleccion) {
        this.nombreSeleccion = nombreSeleccion;
    }

    public int getIdCuota() {
        return idCuota;
    }

    public void setIdCuota(int idCuota) {
        this.idCuota = idCuota;
    }

    public BigDecimal getCuota() {
        return cuota;
    }

    public void setCuota(BigDecimal cuota) {
        this.cuota = cuota;
    }
}