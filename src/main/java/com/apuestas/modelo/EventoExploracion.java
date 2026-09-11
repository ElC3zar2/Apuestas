/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.modelo;

import java.time.LocalDateTime;

/**
 *
 * @author farfa
 */
public class EventoExploracion {

    private int idEvento;
    private int idDeporte;
    private String deporte;

    private int idLiga;
    private String liga;

    private String evento;

    private String participante1;
    private String participante2;
    private int cantidadParticipantes;

    private LocalDateTime fechaInicio;
    private LocalDateTime fechaFin;
    private LocalDateTime fechaCierreApuestas;

    private int minutosParaInicio;
    private int minutosParaCierreApuestas;

    private String estadoEvento;
    private String estadoVisual;

    private boolean resultadoPendiente;

    private int cantidadMercados;
    private int mercadosAbiertos;
    private int seleccionesDisponibles;

    private boolean puedeApostar;

    private String resultadoTexto;
    private String estadoResultado;

    public EventoExploracion() {
    }

    public int getIdEvento() {
        return idEvento;
    }

    public void setIdEvento(int idEvento) {
        this.idEvento = idEvento;
    }

    public int getIdDeporte() {
        return idDeporte;
    }

    public void setIdDeporte(int idDeporte) {
        this.idDeporte = idDeporte;
    }

    public String getDeporte() {
        return deporte;
    }

    public void setDeporte(String deporte) {
        this.deporte = deporte;
    }

    public int getIdLiga() {
        return idLiga;
    }

    public void setIdLiga(int idLiga) {
        this.idLiga = idLiga;
    }

    public String getLiga() {
        return liga;
    }

    public void setLiga(String liga) {
        this.liga = liga;
    }

    public String getEvento() {
        return evento;
    }

    public void setEvento(String evento) {
        this.evento = evento;
    }

    public String getParticipante1() {
        return participante1;
    }

    public void setParticipante1(String participante1) {
        this.participante1 = participante1;
    }

    public String getParticipante2() {
        return participante2;
    }

    public void setParticipante2(String participante2) {
        this.participante2 = participante2;
    }

    public int getCantidadParticipantes() {
        return cantidadParticipantes;
    }

    public void setCantidadParticipantes(
            int cantidadParticipantes) {

        this.cantidadParticipantes =
                cantidadParticipantes;
    }

    public LocalDateTime getFechaInicio() {
        return fechaInicio;
    }

    public void setFechaInicio(
            LocalDateTime fechaInicio) {

        this.fechaInicio = fechaInicio;
    }

    public LocalDateTime getFechaFin() {
        return fechaFin;
    }

    public void setFechaFin(
            LocalDateTime fechaFin) {

        this.fechaFin = fechaFin;
    }

    public LocalDateTime getFechaCierreApuestas() {
        return fechaCierreApuestas;
    }

    public void setFechaCierreApuestas(
            LocalDateTime fechaCierreApuestas) {

        this.fechaCierreApuestas =
                fechaCierreApuestas;
    }

    public int getMinutosParaInicio() {
        return minutosParaInicio;
    }

    public void setMinutosParaInicio(
            int minutosParaInicio) {

        this.minutosParaInicio =
                minutosParaInicio;
    }

    public int getMinutosParaCierreApuestas() {
        return minutosParaCierreApuestas;
    }

    public void setMinutosParaCierreApuestas(
            int minutosParaCierreApuestas) {

        this.minutosParaCierreApuestas =
                minutosParaCierreApuestas;
    }

    public String getEstadoEvento() {
        return estadoEvento;
    }

    public void setEstadoEvento(
            String estadoEvento) {

        this.estadoEvento = estadoEvento;
    }

    public String getEstadoVisual() {
        return estadoVisual;
    }

    public void setEstadoVisual(
            String estadoVisual) {

        this.estadoVisual = estadoVisual;
    }

    public boolean isResultadoPendiente() {
        return resultadoPendiente;
    }

    public void setResultadoPendiente(
            boolean resultadoPendiente) {

        this.resultadoPendiente =
                resultadoPendiente;
    }

    public int getCantidadMercados() {
        return cantidadMercados;
    }

    public void setCantidadMercados(
            int cantidadMercados) {

        this.cantidadMercados =
                cantidadMercados;
    }

    public int getMercadosAbiertos() {
        return mercadosAbiertos;
    }

    public void setMercadosAbiertos(
            int mercadosAbiertos) {

        this.mercadosAbiertos =
                mercadosAbiertos;
    }

    public int getSeleccionesDisponibles() {
        return seleccionesDisponibles;
    }

    public void setSeleccionesDisponibles(
            int seleccionesDisponibles) {

        this.seleccionesDisponibles =
                seleccionesDisponibles;
    }

    public boolean isPuedeApostar() {
        return puedeApostar;
    }

    public void setPuedeApostar(
            boolean puedeApostar) {

        this.puedeApostar = puedeApostar;
    }

    public String getResultadoTexto() {
        return resultadoTexto;
    }

    public void setResultadoTexto(
            String resultadoTexto) {

        this.resultadoTexto = resultadoTexto;
    }

    public String getEstadoResultado() {
        return estadoResultado;
    }

    public void setEstadoResultado(
            String estadoResultado) {

        this.estadoResultado = estadoResultado;
    }
}