/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.modelo;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 *
 * @author farfa
 */
public class SeleccionExploracion {

    private int idSeleccion;
    private String seleccion;

    private boolean seleccionActiva;

    private Integer idCuota;
    private BigDecimal cuota;

    private LocalDateTime fechaInicioCuota;
    private LocalDateTime fechaFinCuota;

    private Boolean cuotaActiva;

    private BigDecimal
            probabilidadImplicitaPorcentaje;

    private String resultadoSeleccion;
    private LocalDateTime fechaResolucion;

    private boolean puedeSeleccionar;

    public SeleccionExploracion() {
    }

    public int getIdSeleccion() {
        return idSeleccion;
    }

    public void setIdSeleccion(
            int idSeleccion) {

        this.idSeleccion = idSeleccion;
    }

    public String getSeleccion() {
        return seleccion;
    }

    public void setSeleccion(
            String seleccion) {

        this.seleccion = seleccion;
    }

    public boolean isSeleccionActiva() {
        return seleccionActiva;
    }

    public void setSeleccionActiva(
            boolean seleccionActiva) {

        this.seleccionActiva =
                seleccionActiva;
    }

    public Integer getIdCuota() {
        return idCuota;
    }

    public void setIdCuota(
            Integer idCuota) {

        this.idCuota = idCuota;
    }

    public BigDecimal getCuota() {
        return cuota;
    }

    public void setCuota(
            BigDecimal cuota) {

        this.cuota = cuota;
    }

    public LocalDateTime getFechaInicioCuota() {
        return fechaInicioCuota;
    }

    public void setFechaInicioCuota(
            LocalDateTime fechaInicioCuota) {

        this.fechaInicioCuota =
                fechaInicioCuota;
    }

    public LocalDateTime getFechaFinCuota() {
        return fechaFinCuota;
    }

    public void setFechaFinCuota(
            LocalDateTime fechaFinCuota) {

        this.fechaFinCuota =
                fechaFinCuota;
    }

    public Boolean getCuotaActiva() {
        return cuotaActiva;
    }

    public void setCuotaActiva(
            Boolean cuotaActiva) {

        this.cuotaActiva = cuotaActiva;
    }

    public BigDecimal
            getProbabilidadImplicitaPorcentaje() {

        return probabilidadImplicitaPorcentaje;
    }

    public void
            setProbabilidadImplicitaPorcentaje(
                    BigDecimal
                            probabilidadImplicitaPorcentaje) {

        this.probabilidadImplicitaPorcentaje =
                probabilidadImplicitaPorcentaje;
    }

    public String getResultadoSeleccion() {
        return resultadoSeleccion;
    }

    public void setResultadoSeleccion(
            String resultadoSeleccion) {

        this.resultadoSeleccion =
                resultadoSeleccion;
    }

    public LocalDateTime getFechaResolucion() {
        return fechaResolucion;
    }

    public void setFechaResolucion(
            LocalDateTime fechaResolucion) {

        this.fechaResolucion =
                fechaResolucion;
    }

    public boolean isPuedeSeleccionar() {
        return puedeSeleccionar;
    }

    public void setPuedeSeleccionar(
            boolean puedeSeleccionar) {

        this.puedeSeleccionar =
                puedeSeleccionar;
    }
}