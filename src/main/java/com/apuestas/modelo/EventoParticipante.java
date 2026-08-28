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
public class EventoParticipante {

    private int idEventoParticipante;
    private int idEvento;
    private int idParticipante;
    private boolean esLocal;

    public EventoParticipante() {
    }

    public EventoParticipante(int idEvento, int idParticipante,
                              boolean esLocal) {
        this.idEvento = idEvento;
        this.idParticipante = idParticipante;
        this.esLocal = esLocal;
    }

    public int getIdEventoParticipante() {
        return idEventoParticipante;
    }

    public void setIdEventoParticipante(int idEventoParticipante) {
        this.idEventoParticipante = idEventoParticipante;
    }

    public int getIdEvento() {
        return idEvento;
    }

    public void setIdEvento(int idEvento) {
        this.idEvento = idEvento;
    }

    public int getIdParticipante() {
        return idParticipante;
    }

    public void setIdParticipante(int idParticipante) {
        this.idParticipante = idParticipante;
    }

    public boolean isEsLocal() {
        return esLocal;
    }

    public void setEsLocal(boolean esLocal) {
        this.esLocal = esLocal;
    }
}
