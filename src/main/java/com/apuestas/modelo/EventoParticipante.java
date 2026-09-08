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
    private int ordenParticipante;
    private Boolean esLocal;

    public EventoParticipante() {
    }

    public EventoParticipante(int idEvento,
                              int idParticipante,
                              int ordenParticipante,
                              Boolean esLocal) {
        this.idEvento = idEvento;
        this.idParticipante = idParticipante;
        this.ordenParticipante = ordenParticipante;
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

    public int getOrdenParticipante() {
        return ordenParticipante;
    }

    public void setOrdenParticipante(int ordenParticipante) {
        this.ordenParticipante = ordenParticipante;
    }

    public Boolean getEsLocal() {
        return esLocal;
    }

    public void setEsLocal(Boolean esLocal) {
        this.esLocal = esLocal;
    }
}