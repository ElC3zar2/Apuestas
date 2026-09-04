/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.modelo;

/**
 *
 * @author farfa
 */
public class Pais {

    private int idPais;
    private String codigoISO2;
    private String nombre;

    public Pais() {
    }

    public Pais(int idPais, String codigoISO2, String nombre) {
        this.idPais = idPais;
        this.codigoISO2 = codigoISO2;
        this.nombre = nombre;
    }

    public int getIdPais() {
        return idPais;
    }

    public void setIdPais(int idPais) {
        this.idPais = idPais;
    }

    public String getCodigoISO2() {
        return codigoISO2;
    }

    public void setCodigoISO2(String codigoISO2) {
        this.codigoISO2 = codigoISO2;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }
}
