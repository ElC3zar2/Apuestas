/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.controlador;

import com.apuestas.modelo.CotizacionApuesta;
import com.apuestas.modelo.DetalleCotizacionApuesta;
import com.apuestas.servicio.ApuestaServicio;

import java.io.IOException;
import java.io.PrintWriter;
import java.math.BigDecimal;
import java.sql.SQLException;
import java.util.ArrayList;
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
@WebServlet("/apuestas/cotizar")
public class CotizarApuestaServlet extends HttpServlet {

    private ApuestaServicio apuestaServicio;

    @Override
    public void init() {

        apuestaServicio =
                new ApuestaServicio();
    }

    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        request.setCharacterEncoding(
                "UTF-8"
        );

        response.setContentType(
                "application/json;charset=UTF-8"
        );

        try {

            List<Integer> idSelecciones =
                    obtenerSelecciones(
                            request
                    );

            BigDecimal monto =
                    obtenerMonto(
                            request
                    );

            CotizacionApuesta cotizacion =
                    apuestaServicio.cotizarApuesta(
                            idSelecciones,
                            monto
                    );

            response.setStatus(
                    HttpServletResponse.SC_OK
            );

            escribirCotizacion(
                    response,
                    cotizacion
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

            String mensaje =
                    estadoHttp
                    == HttpServletResponse
                            .SC_INTERNAL_SERVER_ERROR
                    ? "No fue posible procesar "
                      + "la cotización."
                    : e.getMessage();

            escribirError(
                    response,
                    estadoHttp,
                    mensaje
            );
        }
    }

    private List<Integer> obtenerSelecciones(
            HttpServletRequest request) {

        String[] valores =
                request.getParameterValues(
                        "idSeleccion"
                );

        if (valores == null
                || valores.length == 0) {

            throw new IllegalArgumentException(
                    "Debe seleccionar al menos "
                    + "una opción para apostar."
            );
        }

        List<Integer> selecciones =
                new ArrayList<>();

        try {

            for (String valor : valores) {

                if (valor == null
                        || valor.trim().isEmpty()) {

                    throw new IllegalArgumentException(
                            "Existe una selección no válida."
                    );
                }

                selecciones.add(
                        Integer.valueOf(
                                valor.trim()
                        )
                );
            }

        } catch (NumberFormatException e) {

            throw new IllegalArgumentException(
                    "Existe una selección no válida.",
                    e
            );
        }

        return selecciones;
    }

    private BigDecimal obtenerMonto(
            HttpServletRequest request) {

        String montoTexto =
                request.getParameter(
                        "monto"
                );

        if (montoTexto == null
                || montoTexto.trim().isEmpty()) {

            throw new IllegalArgumentException(
                    "El monto es obligatorio."
            );
        }

        try {

            return new BigDecimal(
                    montoTexto.trim()
            );

        } catch (NumberFormatException e) {

            throw new IllegalArgumentException(
                    "El monto no tiene "
                    + "un formato válido.",
                    e
            );
        }
    }

    private int obtenerEstadoHttp(
            SQLException e) {

        switch (e.getErrorCode()) {

            case 60005:
            case 60022:

                return HttpServletResponse
                        .SC_BAD_REQUEST;

            case 60054:
            case 60056:

                return HttpServletResponse
                        .SC_CONFLICT;

            default:

                return HttpServletResponse
                        .SC_INTERNAL_SERVER_ERROR;
        }
    }

    private void escribirCotizacion(
            HttpServletResponse response,
            CotizacionApuesta cotizacion)
            throws IOException {

        StringBuilder json =
                new StringBuilder();

        json.append("{");

        json.append("\"ok\":true,");

        json.append("\"tipoBoleto\":")
                .append(
                        textoJson(
                                cotizacion
                                        .getTipoBoleto()
                        )
                )
                .append(",");

        json.append("\"cantidadSelecciones\":")
                .append(
                        cotizacion
                                .getCantidadSelecciones()
                )
                .append(",");

        json.append("\"montoApostado\":")
                .append(
                        decimalJson(
                                cotizacion
                                        .getMontoApostado()
                        )
                )
                .append(",");

        json.append(
                "\"comisionServicioPorcentaje\":"
        )
                .append(
                        decimalJson(
                                cotizacion
                                        .getComisionServicioPorcentaje()
                        )
                )
                .append(",");

        json.append("\"comisionServicio\":")
                .append(
                        decimalJson(
                                cotizacion
                                        .getComisionServicio()
                        )
                )
                .append(",");

        json.append("\"totalCargo\":")
                .append(
                        decimalJson(
                                cotizacion
                                        .getTotalCargo()
                        )
                )
                .append(",");

        json.append("\"cuotaTotal\":")
                .append(
                        decimalJson(
                                cotizacion
                                        .getCuotaTotal()
                        )
                )
                .append(",");

        json.append("\"gananciaPotencial\":")
                .append(
                        decimalJson(
                                cotizacion
                                        .getGananciaPotencial()
                        )
                )
                .append(",");

        json.append("\"detalles\":[");

        List<DetalleCotizacionApuesta> detalles =
                cotizacion.getDetalles();

        for (int i = 0;
             i < detalles.size();
             i++) {

            DetalleCotizacionApuesta detalle =
                    detalles.get(i);

            if (i > 0) {
                json.append(",");
            }

            json.append("{");

            json.append("\"orden\":")
                    .append(
                            detalle.getOrden()
                    )
                    .append(",");

            json.append("\"idEvento\":")
                    .append(
                            detalle.getIdEvento()
                    )
                    .append(",");

            json.append("\"nombreEvento\":")
                    .append(
                            textoJson(
                                    detalle
                                            .getNombreEvento()
                            )
                    )
                    .append(",");

            json.append("\"idMercado\":")
                    .append(
                            detalle.getIdMercado()
                    )
                    .append(",");

            json.append("\"nombreMercado\":")
                    .append(
                            textoJson(
                                    detalle
                                            .getNombreMercado()
                            )
                    )
                    .append(",");

            json.append("\"idSeleccion\":")
                    .append(
                            detalle.getIdSeleccion()
                    )
                    .append(",");

            json.append("\"nombreSeleccion\":")
                    .append(
                            textoJson(
                                    detalle
                                            .getNombreSeleccion()
                            )
                    )
                    .append(",");

            json.append("\"idCuota\":")
                    .append(
                            detalle.getIdCuota()
                    )
                    .append(",");

            json.append("\"cuota\":")
                    .append(
                            decimalJson(
                                    detalle.getCuota()
                            )
                    );

            json.append("}");
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

    private String decimalJson(
            BigDecimal valor) {

        if (valor == null) {
            return "null";
        }

        return valor.toPlainString();
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