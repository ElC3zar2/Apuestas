/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.modelo;

import java.util.ArrayList;
import java.util.List;

/**
 *
 * @author farfa
 */
public class MercadoExploracion {

    private int idMercado;
    private String mercado;
    private String descripcionMercado;
    private String estadoMercado;

    private List<SeleccionExploracion> selecciones;

    public MercadoExploracion() {

        selecciones =
                new ArrayList<>();
    }

    public int getIdMercado() {
        return idMercado;
    }

    public void setIdMercado(
            int idMercado) {

        this.idMercado = idMercado;
    }

    public String getMercado() {
        return mercado;
    }

    public void setMercado(
            String mercado) {

        this.mercado = mercado;
    }

    public String getDescripcionMercado() {
        return descripcionMercado;
    }

    public void setDescripcionMercado(
            String descripcionMercado) {

        this.descripcionMercado =
                descripcionMercado;
    }

    public String getEstadoMercado() {
        return estadoMercado;
    }

    public void setEstadoMercado(
            String estadoMercado) {

        this.estadoMercado =
                estadoMercado;
    }

    public List<SeleccionExploracion>
            getSelecciones() {

        return selecciones;
    }

    public void setSelecciones(
            List<SeleccionExploracion>
                    selecciones) {

        this.selecciones =
                selecciones;
    }
}