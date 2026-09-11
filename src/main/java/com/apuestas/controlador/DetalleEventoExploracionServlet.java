/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.controlador;

import com.apuestas.modelo.DetalleEventoExploracion;
import com.apuestas.modelo.MercadoExploracion;
import com.apuestas.modelo.ParticipanteExploracion;
import com.apuestas.modelo.SeleccionExploracion;
import com.apuestas.servicio.ExploracionEventoServicio;

import java.io.IOException;
import java.io.PrintWriter;
import java.math.BigDecimal;
import java.sql.SQLException;
import java.time.LocalDateTime;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/**
 *
 * @author farfa
 */
@WebServlet("/eventos/exploracion/detalle")
public class DetalleEventoExploracionServlet
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

            int idEvento =
                    obtenerEnteroObligatorio(
                            request,
                            "idEvento"
                    );

            int horasPrevia =
                    obtenerEnteroOpcional(
                            request,
                            "horasPrevia",
                            24
                    );

            DetalleEventoExploracion detalle =
                    exploracionEventoServicio
                            .obtenerDetalleEvento(
                                    idEvento,
                                    horasPrevia
                            );

            response.setStatus(
                    HttpServletResponse.SC_OK
            );

            escribirDetalle(
                    response,
                    detalle
            );

        } catch (IllegalArgumentException e) {

            escribirError(
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    e.getMessage()
            );

        } catch (SQLException e) {

            int estadoHttp =
                    obtenerEstadoHttp(
                            e
                    );

            String mensaje;

            if (estadoHttp
                    == HttpServletResponse.SC_BAD_REQUEST
                    || estadoHttp
                    == HttpServletResponse.SC_NOT_FOUND) {

                mensaje =
                        e.getMessage();

            } else {

                mensaje =
                        "No fue posible obtener "
                        + "el detalle del evento.";
            }

            escribirError(
                    response,
                    estadoHttp,
                    mensaje
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

        return convertirEntero(
                valor,
                nombre
        );
    }

    private int obtenerEnteroOpcional(
            HttpServletRequest request,
            String nombre,
            int valorPredeterminado) {

        String valor =
                request.getParameter(
                        nombre
                );

        if (valor == null
                || valor.trim().isEmpty()) {

            return valorPredeterminado;
        }

        return convertirEntero(
                valor,
                nombre
        );
    }

    private int convertirEntero(
            String valor,
            String nombre) {

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

    private int obtenerEstadoHttp(
            SQLException e) {

        switch (e.getErrorCode()) {

            case 64012:
            case 64013:

                return HttpServletResponse
                        .SC_BAD_REQUEST;

            case 64014:

                return HttpServletResponse
                        .SC_NOT_FOUND;

            default:

                return HttpServletResponse
                        .SC_INTERNAL_SERVER_ERROR;
        }
    }

    private void escribirDetalle(
            HttpServletResponse response,
            DetalleEventoExploracion detalle)
            throws IOException {

        StringBuilder json =
                new StringBuilder();

        json.append("{");

        json.append("\"ok\":true,");

        json.append("\"evento\":");

        agregarDetalleEvento(
                json,
                detalle
        );

        json.append("}");

        try (PrintWriter out =
                     response.getWriter()) {

            out.print(
                    json.toString()
            );
        }
    }

    private void agregarDetalleEvento(
            StringBuilder json,
            DetalleEventoExploracion detalle) {

        json.append("{");

        json.append("\"idEvento\":")
                .append(
                        detalle.getIdEvento()
                )
                .append(",");

        json.append("\"idDeporte\":")
                .append(
                        detalle.getIdDeporte()
                )
                .append(",");

        json.append("\"deporte\":")
                .append(
                        textoJson(
                                detalle.getDeporte()
                        )
                )
                .append(",");

        json.append("\"idLiga\":")
                .append(
                        detalle.getIdLiga()
                )
                .append(",");

        json.append("\"liga\":")
                .append(
                        textoJson(
                                detalle.getLiga()
                        )
                )
                .append(",");

        json.append("\"nombre\":")
                .append(
                        textoJson(
                                detalle.getEvento()
                        )
                )
                .append(",");

        json.append("\"fechaInicio\":")
                .append(
                        fechaJson(
                                detalle.getFechaInicio()
                        )
                )
                .append(",");

        json.append("\"fechaFin\":")
                .append(
                        fechaJson(
                                detalle.getFechaFin()
                        )
                )
                .append(",");

        json.append("\"fechaCierreApuestas\":")
                .append(
                        fechaJson(
                                detalle.getFechaCierreApuestas()
                        )
                )
                .append(",");

        json.append("\"minutosParaInicio\":")
                .append(
                        detalle.getMinutosParaInicio()
                )
                .append(",");

        json.append("\"minutosParaCierreApuestas\":")
                .append(
                        detalle.getMinutosParaCierreApuestas()
                )
                .append(",");

        json.append("\"estadoEvento\":")
                .append(
                        textoJson(
                                detalle.getEstadoEvento()
                        )
                )
                .append(",");

        json.append("\"estadoVisual\":")
                .append(
                        textoJson(
                                detalle.getEstadoVisual()
                        )
                )
                .append(",");

        json.append("\"puedeApostar\":")
                .append(
                        detalle.isPuedeApostar()
                )
                .append(",");

        json.append("\"cantidadMercados\":")
                .append(
                        detalle.getCantidadMercados()
                )
                .append(",");

        json.append("\"cantidadParticipantes\":")
                .append(
                        detalle.getCantidadParticipantes()
                )
                .append(",");

        json.append("\"resultadoTexto\":")
                .append(
                        textoJson(
                                detalle.getResultadoTexto()
                        )
                )
                .append(",");

        json.append("\"estadoResultado\":")
                .append(
                        textoJson(
                                detalle.getEstadoResultado()
                        )
                )
                .append(",");

        json.append("\"resultadoPendiente\":")
                .append(
                        detalle.isResultadoPendiente()
                )
                .append(",");

        json.append("\"participantes\":[");

        for (int i = 0;
             i < detalle.getParticipantes().size();
             i++) {

            if (i > 0) {
                json.append(",");
            }

            agregarParticipante(
                    json,
                    detalle.getParticipantes()
                            .get(i)
            );
        }

        json.append("],");

        json.append("\"mercados\":[");

        for (int i = 0;
             i < detalle.getMercados().size();
             i++) {

            if (i > 0) {
                json.append(",");
            }

            agregarMercado(
                    json,
                    detalle.getMercados()
                            .get(i)
            );
        }

        json.append("]");

        json.append("}");
    }

    private void agregarParticipante(
            StringBuilder json,
            ParticipanteExploracion participante) {

        json.append("{");

        json.append("\"idEventoParticipante\":")
                .append(
                        participante
                                .getIdEventoParticipante()
                )
                .append(",");

        json.append("\"ordenParticipante\":")
                .append(
                        participante
                                .getOrdenParticipante()
                )
                .append(",");

        json.append("\"esLocal\":")
                .append(
                        booleanJson(
                                participante.getEsLocal()
                        )
                )
                .append(",");

        json.append("\"idParticipante\":")
                .append(
                        participante.getIdParticipante()
                )
                .append(",");

        json.append("\"participante\":")
                .append(
                        textoJson(
                                participante.getParticipante()
                        )
                )
                .append(",");

        json.append("\"tipoParticipante\":")
                .append(
                        textoJson(
                                participante
                                        .getTipoParticipante()
                        )
                )
                .append(",");

        json.append("\"idPais\":")
                .append(
                        enteroJson(
                                participante.getIdPais()
                        )
                )
                .append(",");

        json.append("\"pais\":")
                .append(
                        textoJson(
                                participante.getPais()
                        )
                )
                .append(",");

        json.append("\"codigoPais\":")
                .append(
                        textoJson(
                                participante.getCodigoPais()
                        )
                );

        json.append("}");
    }

    private void agregarMercado(
            StringBuilder json,
            MercadoExploracion mercado) {

        json.append("{");

        json.append("\"idMercado\":")
                .append(
                        mercado.getIdMercado()
                )
                .append(",");

        json.append("\"mercado\":")
                .append(
                        textoJson(
                                mercado.getMercado()
                        )
                )
                .append(",");

        json.append("\"descripcionMercado\":")
                .append(
                        textoJson(
                                mercado
                                        .getDescripcionMercado()
                        )
                )
                .append(",");

        json.append("\"estadoMercado\":")
                .append(
                        textoJson(
                                mercado.getEstadoMercado()
                        )
                )
                .append(",");

        json.append("\"selecciones\":[");

        for (int i = 0;
             i < mercado.getSelecciones().size();
             i++) {

            if (i > 0) {
                json.append(",");
            }

            agregarSeleccion(
                    json,
                    mercado.getSelecciones()
                            .get(i)
            );
        }

        json.append("]");

        json.append("}");
    }

    private void agregarSeleccion(
            StringBuilder json,
            SeleccionExploracion seleccion) {

        json.append("{");

        json.append("\"idSeleccion\":")
                .append(
                        seleccion.getIdSeleccion()
                )
                .append(",");

        json.append("\"seleccion\":")
                .append(
                        textoJson(
                                seleccion.getSeleccion()
                        )
                )
                .append(",");

        json.append("\"seleccionActiva\":")
                .append(
                        seleccion.isSeleccionActiva()
                )
                .append(",");

        json.append("\"idCuota\":")
                .append(
                        enteroJson(
                                seleccion.getIdCuota()
                        )
                )
                .append(",");

        json.append("\"cuota\":")
                .append(
                        decimalJson(
                                seleccion.getCuota()
                        )
                )
                .append(",");

        json.append("\"fechaInicioCuota\":")
                .append(
                        fechaJson(
                                seleccion
                                        .getFechaInicioCuota()
                        )
                )
                .append(",");

        json.append("\"fechaFinCuota\":")
                .append(
                        fechaJson(
                                seleccion
                                        .getFechaFinCuota()
                        )
                )
                .append(",");

        json.append("\"cuotaActiva\":")
                .append(
                        booleanJson(
                                seleccion.getCuotaActiva()
                        )
                )
                .append(",");

        json.append(
                "\"probabilidadImplicitaPorcentaje\":"
        )
                .append(
                        decimalJson(
                                seleccion
                                        .getProbabilidadImplicitaPorcentaje()
                        )
                )
                .append(",");

        json.append("\"resultadoSeleccion\":")
                .append(
                        textoJson(
                                seleccion
                                        .getResultadoSeleccion()
                        )
                )
                .append(",");

        json.append("\"fechaResolucion\":")
                .append(
                        fechaJson(
                                seleccion.getFechaResolucion()
                        )
                )
                .append(",");

        json.append("\"puedeSeleccionar\":")
                .append(
                        seleccion.isPuedeSeleccionar()
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

    private String fechaJson(
            LocalDateTime fecha) {

        if (fecha == null) {
            return "null";
        }

        return textoJson(
                fecha.toString()
        );
    }

    private String decimalJson(
            BigDecimal valor) {

        if (valor == null) {
            return "null";
        }

        return valor.toPlainString();
    }

    private String enteroJson(
            Integer valor) {

        if (valor == null) {
            return "null";
        }

        return valor.toString();
    }

    private String booleanJson(
            Boolean valor) {

        if (valor == null) {
            return "null";
        }

        return valor.toString();
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