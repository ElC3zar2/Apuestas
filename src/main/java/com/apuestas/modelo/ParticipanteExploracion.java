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
public class ParticipanteExploracion {

    private int idEventoParticipante;
    private int ordenParticipante;

    private Boolean esLocal;

    private int idParticipante;
    private String participante;
    private String tipoParticipante;

    private Integer idPais;
    private String pais;
    private String codigoPais;

    public ParticipanteExploracion() {
    }

    public int getIdEventoParticipante() {
        return idEventoParticipante;
    }

    public void setIdEventoParticipante(
            int idEventoParticipante) {

        this.idEventoParticipante =
                idEventoParticipante;
    }

    public int getOrdenParticipante() {
        return ordenParticipante;
    }

    public void setOrdenParticipante(
            int ordenParticipante) {

        this.ordenParticipante =
                ordenParticipante;
    }

    public Boolean getEsLocal() {
        return esLocal;
    }

    public void setEsLocal(Boolean esLocal) {
        this.esLocal = esLocal;
    }

    public int getIdParticipante() {
        return idParticipante;
    }

    public void setIdParticipante(
            int idParticipante) {

        this.idParticipante =
                idParticipante;
    }

    public String getParticipante() {
        return participante;
    }

    public void setParticipante(
            String participante) {

        this.participante = participante;
    }

    public String getTipoParticipante() {
        return tipoParticipante;
    }

    public void setTipoParticipante(
            String tipoParticipante) {

        this.tipoParticipante =
                tipoParticipante;
    }

    public Integer getIdPais() {
        return idPais;
    }

    public void setIdPais(Integer idPais) {
        this.idPais = idPais;
    }

    public String getPais() {
        return pais;
    }

    public void setPais(String pais) {
        this.pais = pais;
    }

    public String getCodigoPais() {
        return codigoPais;
    }

    public void setCodigoPais(
            String codigoPais) {

        this.codigoPais = codigoPais;
    }
}