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
public class Liga {

    private int idLiga;
    private int idDeporte;
    private String nombre;
    private String pais;
    private boolean estado;

    public Liga() {
    }

    public Liga(int idDeporte, String nombre, String pais, boolean estado) {
        this.idDeporte = idDeporte;
        this.nombre = nombre;
        this.pais = pais;
        this.estado = estado;
    }

    public int getIdLiga() {
        return idLiga;
    }

    public void setIdLiga(int idLiga) {
        this.idLiga = idLiga;
    }

    public int getIdDeporte() {
        return idDeporte;
    }

    public void setIdDeporte(int idDeporte) {
        this.idDeporte = idDeporte;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getPais() {
        return pais;
    }

    public void setPais(String pais) {
        this.pais = pais;
    }

    public boolean isEstado() {
        return estado;
    }

    public void setEstado(boolean estado) {
        this.estado = estado;
    }
}