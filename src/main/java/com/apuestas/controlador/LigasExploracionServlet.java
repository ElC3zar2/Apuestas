/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.controlador;

import com.apuestas.modelo.Liga;
import com.apuestas.servicio.LigaServicio;

import java.io.IOException;
import java.io.PrintWriter;
import java.sql.SQLException;
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
@WebServlet("/ligas/exploracion")
public class LigasExploracionServlet
        extends HttpServlet {

    private LigaServicio ligaServicio;

    @Override
    public void init() {

        ligaServicio =
                new LigaServicio();
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

            List<Liga> ligas =
                    ligaServicio
                            .listarLigasPorDeporte(
                                    idDeporte
                            );

            response.setStatus(
                    HttpServletResponse.SC_OK
            );

            escribirRespuesta(
                    response,
                    idDeporte,
                    ligas
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
                    + "las ligas disponibles."
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
            int idDeporte,
            List<Liga> ligas)
            throws IOException {

        StringBuilder json =
                new StringBuilder();

        json.append("{");

        json.append("\"ok\":true,");

        json.append("\"idDeporte\":")
                .append(
                        idDeporte
                )
                .append(",");

        json.append("\"cantidad\":")
                .append(
                        ligas.size()
                )
                .append(",");

        json.append("\"ligas\":[");

        for (int i = 0;
             i < ligas.size();
             i++) {

            if (i > 0) {
                json.append(",");
            }

            agregarLiga(
                    json,
                    ligas.get(i)
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

    private void agregarLiga(
            StringBuilder json,
            Liga liga) {

        json.append("{");

        json.append("\"idLiga\":")
                .append(
                        liga.getIdLiga()
                )
                .append(",");

        json.append("\"idDeporte\":")
                .append(
                        liga.getIdDeporte()
                )
                .append(",");

        json.append("\"idPais\":")
                .append(
                        enteroJson(
                                liga.getIdPais()
                        )
                )
                .append(",");

        json.append("\"nombre\":")
                .append(
                        textoJson(
                                liga.getNombre()
                        )
                )
                .append(",");

        json.append("\"activo\":")
                .append(
                        liga.isActivo()
                );

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

    private String enteroJson(
            Integer valor) {

        if (valor == null) {
            return "null";
        }

        return valor.toString();
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