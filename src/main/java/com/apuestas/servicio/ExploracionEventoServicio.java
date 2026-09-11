/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.servicio;

import com.apuestas.dao.ExploracionEventoDAO;
import com.apuestas.modelo.DetalleEventoExploracion;
import com.apuestas.modelo.EventoExploracion;

import java.sql.SQLException;
import java.util.List;

/**
 *
 * @author farfa
 */
public class ExploracionEventoServicio {

    private final ExploracionEventoDAO
            exploracionEventoDAO;

    public ExploracionEventoServicio() {

        exploracionEventoDAO =
                new ExploracionEventoDAO();
    }

    public List<EventoExploracion> listarEventos(
            int idDeporte,
            String vista,
            int horasPrevia,
            int cantidad)
            throws SQLException {

        validarIdDeporte(
                idDeporte
        );

        String vistaNormalizada =
                normalizarVista(
                        vista
                );

        validarHorasPrevia(
                horasPrevia
        );

        validarCantidad(
                cantidad
        );

        return exploracionEventoDAO
                .listarEventos(
                        idDeporte,
                        vistaNormalizada,
                        horasPrevia,
                        cantidad
                );
    }

    public DetalleEventoExploracion
            obtenerDetalleEvento(
                    int idEvento,
                    int horasPrevia)
            throws SQLException {

        validarIdEvento(
                idEvento
        );

        validarHorasPrevia(
                horasPrevia
        );

        return exploracionEventoDAO
                .obtenerDetalleEvento(
                        idEvento,
                        horasPrevia
                );
    }

    private void validarIdDeporte(
            int idDeporte) {

        if (idDeporte <= 0) {

            throw new IllegalArgumentException(
                    "El deporte seleccionado "
                    + "no es válido."
            );
        }
    }

    private void validarIdEvento(
            int idEvento) {

        if (idEvento <= 0) {

            throw new IllegalArgumentException(
                    "El evento seleccionado "
                    + "no es válido."
            );
        }
    }

    private String normalizarVista(
            String vista) {

        if (vista == null
                || vista.trim().isEmpty()) {

            return "TODOS";
        }

        String valor =
                vista.trim()
                        .toUpperCase();

        switch (valor) {

            case "TODOS":
            case "PROGRAMADOS":
            case "PREVIA":
            case "EN_PROGRESO":
            case "FINALIZADOS":

                return valor;

            default:

                throw new IllegalArgumentException(
                        "La vista solicitada "
                        + "no es válida."
                );
        }
    }

    private void validarHorasPrevia(
            int horasPrevia) {

        if (horasPrevia <= 0) {

            throw new IllegalArgumentException(
                    "Las horas de previa deben "
                    + "ser mayores que cero."
            );
        }
    }

    private void validarCantidad(
            int cantidad) {

        if (cantidad < 1
                || cantidad > 500) {

            throw new IllegalArgumentException(
                    "La cantidad debe estar "
                    + "entre 1 y 500."
            );
        }
    }
}