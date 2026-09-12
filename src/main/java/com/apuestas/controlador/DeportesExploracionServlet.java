/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.controlador;

import com.apuestas.modelo.Deporte;
import com.apuestas.servicio.DeporteServicio;

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
@WebServlet("/deportes/exploracion")
public class DeportesExploracionServlet
        extends HttpServlet {

    private DeporteServicio deporteServicio;

    @Override
    public void init() {

        deporteServicio =
                new DeporteServicio();
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

            List<Deporte> deportes =
                    deporteServicio
                            .listarDeportesActivos();

            response.setStatus(
                    HttpServletResponse.SC_OK
            );

            escribirRespuesta(
                    response,
                    deportes
            );

        } catch (SQLException e) {

            escribirError(
                    response,
                    HttpServletResponse
                            .SC_INTERNAL_SERVER_ERROR,
                    "No fue posible obtener "
                    + "los deportes disponibles."
            );
        }
    }

    private void escribirRespuesta(
            HttpServletResponse response,
            List<Deporte> deportes)
            throws IOException {

        StringBuilder json =
                new StringBuilder();

        json.append("{");

        json.append("\"ok\":true,");

        json.append("\"cantidad\":")
                .append(
                        deportes.size()
                )
                .append(",");

        json.append("\"deportes\":[");

        for (int i = 0;
             i < deportes.size();
             i++) {

            if (i > 0) {
                json.append(",");
            }

            agregarDeporte(
                    json,
                    deportes.get(i)
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

    private void agregarDeporte(
            StringBuilder json,
            Deporte deporte) {

        json.append("{");

        json.append("\"idDeporte\":")
                .append(
                        deporte.getIdDeporte()
                )
                .append(",");

        json.append("\"nombre\":")
                .append(
                        textoJson(
                                deporte.getNombre()
                        )
                )
                .append(",");

        json.append("\"descripcion\":")
                .append(
                        textoJson(
                                deporte.getDescripcion()
                        )
                )
                .append(",");

        json.append("\"activo\":")
                .append(
                        deporte.isActivo()
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
