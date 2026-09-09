/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.servicio;

import com.apuestas.dao.EventoDAO;
import com.apuestas.modelo.Evento;

import java.sql.SQLException;
import java.util.List;

/**
 *
 * @author farfa
 */
public class EventoServicio {

    private final EventoDAO eventoDAO;

    public EventoServicio() {
        this.eventoDAO = new EventoDAO();
    }

    public Evento crearEvento(
            int idUsuarioProceso,
            Evento evento,
            String ipOrigen)
            throws SQLException {

        validarUsuarioProceso(idUsuarioProceso);
        validarEvento(evento);

        return eventoDAO.crearEvento(
                idUsuarioProceso,
                evento,
                ipOrigen
        );
    }

    public Evento actualizarEvento(
            int idUsuarioProceso,
            Evento evento,
            String ipOrigen)
            throws SQLException {

        validarUsuarioProceso(idUsuarioProceso);

        if (evento == null) {
            throw new IllegalArgumentException(
                    "El evento es obligatorio."
            );
        }

        if (evento.getIdEvento() <= 0) {
            throw new IllegalArgumentException(
                    "El evento seleccionado no es válido."
            );
        }

        validarEvento(evento);

        return eventoDAO.actualizarEvento(
                idUsuarioProceso,
                evento,
                ipOrigen
        );
    }

    public List<Evento> listarEventos()
            throws SQLException {

        return eventoDAO.listarEventos();
    }

    public List<Evento> listarEventosPorLiga(
            int idLiga)
            throws SQLException {

        if (idLiga <= 0) {
            throw new IllegalArgumentException(
                    "La liga seleccionada no es válida."
            );
        }

        return eventoDAO.listarEventosPorLiga(
                idLiga
        );
    }

    public Evento buscarPorId(
            int idEvento)
            throws SQLException {

        if (idEvento <= 0) {
            throw new IllegalArgumentException(
                    "El evento seleccionado no es válido."
            );
        }

        Evento evento =
                eventoDAO.buscarPorId(idEvento);

        if (evento == null) {
            throw new IllegalArgumentException(
                    "El evento no existe."
            );
        }

        return evento;
    }

    private void validarEvento(
            Evento evento) {

        if (evento == null) {
            throw new IllegalArgumentException(
                    "El evento es obligatorio."
            );
        }

        if (evento.getIdLiga() <= 0) {
            throw new IllegalArgumentException(
                    "Debe seleccionar una liga."
            );
        }

        if (evento.getNombre() == null
                || evento.getNombre()
                        .trim()
                        .isEmpty()) {

            throw new IllegalArgumentException(
                    "El nombre del evento es obligatorio."
            );
        }

        String nombre =
                evento.getNombre().trim();

        if (nombre.length() > 200) {
            throw new IllegalArgumentException(
                    "El nombre del evento no puede superar "
                    + "los 200 caracteres."
            );
        }

        evento.setNombre(nombre);

        if (evento.getFechaInicio() == null) {
            throw new IllegalArgumentException(
                    "La fecha de inicio es obligatoria."
            );
        }

        if (evento.getFechaFin() != null
                && !evento.getFechaFin()
                        .isAfter(
                                evento.getFechaInicio()
                        )) {

            throw new IllegalArgumentException(
                    "La fecha de fin debe ser posterior "
                    + "a la fecha de inicio."
            );
        }
    }

    private void validarUsuarioProceso(
            int idUsuarioProceso) {

        if (idUsuarioProceso <= 0) {
            throw new IllegalArgumentException(
                    "El usuario de proceso no es válido."
            );
        }
    }
}
