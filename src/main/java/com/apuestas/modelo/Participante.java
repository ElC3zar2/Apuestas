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
public class Participante {

    private int idParticipante;
    private int idDeporte;
    private String nombre;
    private String tipoParticipante;
    private boolean estado;

    public Participante() {
    }

    public Participante(int idDeporte, String nombre,
                        String tipoParticipante, boolean estado) {
        this.idDeporte = idDeporte;
        this.nombre = nombre;
        this.tipoParticipante = tipoParticipante;
        this.estado = estado;
    }

    public int getIdParticipante() {
        return idParticipante;
    }

    public void setIdParticipante(int idParticipante) {
        this.idParticipante = idParticipante;
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

    public String getTipoParticipante() {
        return tipoParticipante;
    }

    public void setTipoParticipante(String tipoParticipante) {
        this.tipoParticipante = tipoParticipante;
    }

    public boolean isEstado() {
        return estado;
    }

    public void setEstado(boolean estado) {
        this.estado = estado;
    }
}
