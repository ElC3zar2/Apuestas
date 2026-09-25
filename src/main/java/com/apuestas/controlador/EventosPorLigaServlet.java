/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.controlador;

import com.apuestas.modelo.Evento;
import com.apuestas.servicio.EventoServicio;

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
@WebServlet("/eventos/por-liga")
public class EventosPorLigaServlet
        extends HttpServlet {

    private EventoServicio eventoServicio;

    @Override
    public void init() {

        eventoServicio =
                new EventoServicio();
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

            int idLiga =
                    obtenerEnteroObligatorio(
                            request,
                            "idLiga"
                    );

            List<Evento> eventos =
                    eventoServicio
                            .listarEventosPorLiga(
                                    idLiga
                            );

            response.setStatus(
                    HttpServletResponse.SC_OK
            );

            escribirRespuesta(
                    response,
                    idLiga,
                    eventos
            );

        } catch (IllegalArgumentException e) {

            escribirError(
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    e.getMessage()
            );

        } catch (SQLException e) {

            escribirError(
                    response,
                    HttpServletResponse
                            .SC_INTERNAL_SERVER_ERROR,
                    "No fue posible obtener "
                    + "los eventos de la liga."
            );
        }
    }

    private int obtenerEnteroObligatorio(
            HttpServletRequest request,
            String nombre) {

        String valor =
                request.getParameter(
                        nombre
                );

        if (valor == null
                || valor.trim().isEmpty()) {

            throw new IllegalArgumentException(
                    "El parámetro "
                    + nombre
                    + " es obligatorio."
            );
        }

        try {

            return Integer.parseInt(
                    valor.trim()
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

    private void escribirRespuesta(
            HttpServletResponse response,
            int idLiga,
            List<Evento> eventos)
            throws IOException {

        StringBuilder json =
                new StringBuilder();

        json.append("{");

        json.append("\"ok\":true,");

        json.append("\"idLiga\":")
                .append(
                        idLiga
                )
                .append(",");

        json.append("\"cantidad\":")
                .append(
                        eventos.size()
                )
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
            Evento evento) {

        json.append("{");

        json.append("\"idEvento\":")
                .append(
                        evento.getIdEvento()
                )
                .append(",");

        json.append("\"idLiga\":")
                .append(
                        evento.getIdLiga()
                )
                .append(",");

        json.append("\"idEstado\":")
                .append(
                        evento.getIdEstado()
                )
                .append(",");

        json.append("\"estadoEvento\":")
                .append(
                        textoJson(
                                evento.getEstadoEvento()
                        )
                )
                .append(",");

        json.append("\"nombre\":")
                .append(
                        textoJson(
                                evento.getNombre()
                        )
                )
                .append(",");

        json.append("\"fechaInicio\":")
                .append(
                        fechaJson(
                                evento.getFechaInicio()
                        )
                )
                .append(",");

        json.append("\"fechaFin\":")
                .append(
                        fechaJson(
                                evento.getFechaFin()
                        )
                );

        json.append("}");
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

        StringBuilder escapado = new StringBuilder();

        for (int i = 0; i < texto.length(); i++) {
            char caracter = texto.charAt(i);

            switch (caracter) {
                case '\\':
                    escapado.append("\\\\");
                    break;
                case '"':
                    escapado.append("\\\"");
                    break;
                case '\n':
                    escapado.append("\\n");
                    break;
                case '\r':
                    escapado.append("\\r");
                    break;
                case '\t':
                    escapado.append("\\t");
                    break;
                default:
                    if (caracter < 0x20) {
                        escapado.append("\\u00");
                        escapado.append(Character.forDigit(caracter >> 4, 16));
                        escapado.append(Character.forDigit(caracter & 0xF, 16));
                    } else {
                        escapado.append(caracter);
                    }
            }
        }

        return escapado.toString();
    }
}