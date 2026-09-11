/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.controlador;

import com.apuestas.modelo.EventoExploracion;
import com.apuestas.servicio.ExploracionEventoServicio;

import java.io.IOException;
import java.io.PrintWriter;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.List;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/**
 *
 * @author farfa
 */
@WebServlet("/eventos/exploracion")
public class EventosExploracionServlet
        extends HttpServlet {

    private ExploracionEventoServicio
            exploracionEventoServicio;

    @Override
    public void init() {

        exploracionEventoServicio =
                new ExploracionEventoServicio();
    }

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType(
                "application/json;charset=UTF-8"
        );

        try {

            int idDeporte =
                    obtenerEnteroObligatorio(
                            request,
                            "idDeporte"
                    );

            String vista =
                    request.getParameter(
                            "vista"
                    );

            int horasPrevia =
                    obtenerEnteroOpcional(
                            request,
                            "horasPrevia",
                            24
                    );

            int cantidad =
                    obtenerEnteroOpcional(
                            request,
                            "cantidad",
                            100
                    );

            List<EventoExploracion> eventos =
                    exploracionEventoServicio
                            .listarEventos(
                                    idDeporte,
                                    vista,
                                    horasPrevia,
                                    cantidad
                            );

            response.setStatus(
                    HttpServletResponse.SC_OK
            );

            escribirEventos(
                    response,
                    eventos
            );

        } catch (IllegalArgumentException e) {

            escribirError(
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    e.getMessage()
            );

        } catch (SQLException e) {

            int estado =
                    obtenerEstadoHttp(
                            e
                    );

            String mensaje;

            if (estado
                    == HttpServletResponse.SC_NOT_FOUND) {

                mensaje =
                        e.getMessage();

            } else if (estado
                    == HttpServletResponse.SC_BAD_REQUEST) {

                mensaje =
                        e.getMessage();

            } else {

                mensaje =
                        "No fue posible obtener "
                        + "los eventos.";
            }

            escribirError(
                    response,
                    estado,
                    mensaje
            );
        }
    }

    private int obtenerEnteroObligatorio(
            HttpServletRequest request,
            String nombre) {

        String texto =
                request.getParameter(
                        nombre
                );

        if (texto == null
                || texto.trim().isEmpty()) {

            throw new IllegalArgumentException(
                    "El parámetro "
                    + nombre
                    + " es obligatorio."
            );
        }

        return convertirEntero(
                texto,
                nombre
        );
    }

    private int obtenerEnteroOpcional(
            HttpServletRequest request,
            String nombre,
            int valorPredeterminado) {

        String texto =
                request.getParameter(
                        nombre
                );

        if (texto == null
                || texto.trim().isEmpty()) {

            return valorPredeterminado;
        }

        return convertirEntero(
                texto,
                nombre
        );
    }

    private int convertirEntero(
            String texto,
            String nombre) {

        try {

            return Integer.parseInt(
                    texto.trim()
            );

        } catch (NumberFormatException e) {

            throw new IllegalArgumentException(
                    "El parámetro "
                    + nombre
                    + " no tiene un formato válido.",
                    e
            );
        }
    }

    private int obtenerEstadoHttp(
            SQLException e) {

        switch (e.getErrorCode()) {

            case 64006:
            case 64008:
            case 64009:
            case 64010:

                return HttpServletResponse
                        .SC_BAD_REQUEST;

            case 64007:

                return HttpServletResponse
                        .SC_NOT_FOUND;

            default:

                return HttpServletResponse
                        .SC_INTERNAL_SERVER_ERROR;
        }
    }

    private void escribirEventos(
            HttpServletResponse response,
            List<EventoExploracion> eventos)
            throws IOException {

        StringBuilder json =
                new StringBuilder();

        json.append("{");
        json.append("\"ok\":true,");

        json.append("\"cantidad\":")
                .append(eventos.size())
                .append(",");

        json.append("\"eventos\":[");

        for (int i = 0;
             i < eventos.size();
             i++) {

            if (i > 0) {
                json.append(",");
            }

            agregarEvento(
                    json,
                    eventos.get(i)
            );
        }

        json.append("]");
        json.append("}");

        try (PrintWriter out =
                     response.getWriter()) {

            out.print(
                    json.toString()
            );
        }
    }

    private void agregarEvento(
            StringBuilder json,
            EventoExploracion evento) {

        json.append("{");

        json.append("\"idEvento\":")
                .append(evento.getIdEvento())
                .append(",");

        json.append("\"idDeporte\":")
                .append(evento.getIdDeporte())
                .append(",");

        json.append("\"deporte\":")
                .append(textoJson(
                        evento.getDeporte()))
                .append(",");

        json.append("\"idLiga\":")
                .append(evento.getIdLiga())
                .append(",");

        json.append("\"liga\":")
                .append(textoJson(
                        evento.getLiga()))
                .append(",");

        json.append("\"evento\":")
                .append(textoJson(
                        evento.getEvento()))
                .append(",");

        json.append("\"participante1\":")
                .append(textoJson(
                        evento.getParticipante1()))
                .append(",");

        json.append("\"participante2\":")
                .append(textoJson(
                        evento.getParticipante2()))
                .append(",");

        json.append("\"cantidadParticipantes\":")
                .append(
                        evento.getCantidadParticipantes()
                )
                .append(",");

        json.append("\"fechaInicio\":")
                .append(fechaJson(
                        evento.getFechaInicio()))
                .append(",");

        json.append("\"fechaFin\":")
                .append(fechaJson(
                        evento.getFechaFin()))
                .append(",");

        json.append("\"fechaCierreApuestas\":")
                .append(fechaJson(
                        evento.getFechaCierreApuestas()))
                .append(",");

        json.append("\"minutosParaInicio\":")
                .append(
                        evento.getMinutosParaInicio()
                )
                .append(",");

        json.append("\"minutosParaCierreApuestas\":")
                .append(
                        evento.getMinutosParaCierreApuestas()
                )
                .append(",");

        json.append("\"estadoEvento\":")
                .append(textoJson(
                        evento.getEstadoEvento()))
                .append(",");

        json.append("\"estadoVisual\":")
                .append(textoJson(
                        evento.getEstadoVisual()))
                .append(",");

        json.append("\"resultadoPendiente\":")
                .append(
                        evento.isResultadoPendiente()
                )
                .append(",");

        json.append("\"cantidadMercados\":")
                .append(
                        evento.getCantidadMercados()
                )
                .append(",");

        json.append("\"mercadosAbiertos\":")
                .append(
                        evento.getMercadosAbiertos()
                )
                .append(",");

        json.append("\"seleccionesDisponibles\":")
                .append(
                        evento.getSeleccionesDisponibles()
                )
                .append(",");

        json.append("\"puedeApostar\":")
                .append(
                        evento.isPuedeApostar()
                )
                .append(",");

        json.append("\"resultadoTexto\":")
                .append(textoJson(
                        evento.getResultadoTexto()))
                .append(",");

        json.append("\"estadoResultado\":")
                .append(textoJson(
                        evento.getEstadoResultado()));

        json.append("}");
    }

    private void escribirError(
            HttpServletResponse response,
            int estadoHttp,
            String mensaje)
            throws IOException {

        response.setStatus(
                estadoHttp
        );

        try (PrintWriter out =
                     response.getWriter()) {

            out.print(
                    "{"
                    + "\"ok\":false,"
                    + "\"mensaje\":"
                    + textoJson(mensaje)
                    + "}"
            );
        }
    }

    private String fechaJson(
            LocalDateTime fecha) {

        if (fecha == null) {
            return "null";
        }

        return textoJson(
                fecha.toString()
        );
    }

    private String textoJson(
            String texto) {

        if (texto == null) {
            return "null";
        }

        return "\""
                + escaparJson(texto)
                + "\"";
    }

    private String escaparJson(
            String texto) {

        return texto
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");
    }
}