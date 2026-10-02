/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.apuestas.controlador;
import com.apuestas.modelo.Boleto;
import com.apuestas.reporte.ReporteBoletoServicio;
import com.apuestas.servicio.ApuestaServicio;

import java.io.IOException;
import java.io.OutputStream;
import java.sql.SQLException;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
/**
 *
 * @author alumno
 */
@WebServlet("/usuario/boletos/imprimir")
public class ImprimirBoletoServlet extends HttpServlet {

    private ApuestaServicio apuestaServicio;
    private ReporteBoletoServicio reporteBoletoServicio;

    @Override
    public void init() {

        apuestaServicio =
                new ApuestaServicio();

        reporteBoletoServicio =
                new ReporteBoletoServicio();
    }

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        response.setCharacterEncoding(
                "UTF-8"
        );

        /*
         * No se crea una sesión nueva.
         * El usuario debe venir autenticado previamente.
         */
        HttpSession session =
                request.getSession(false);

        if (session == null) {

            enviarError(
                    response,
                    HttpServletResponse.SC_UNAUTHORIZED,
                    "Debe iniciar sesión para imprimir un boleto."
            );

            return;
        }

        Integer idUsuario;
        Object rol;
        try {
            idUsuario = obtenerIdUsuarioSesion(session);
            rol = session.getAttribute("rol");
        } catch (IllegalStateException e) {
            idUsuario = null; rol = null;
        }
        if (idUsuario == null) {
            enviarError(response, 401, "La sesion del usuario no es valida.");
            return;
        }
        if (!"USUARIO".equals(rol)) {
            enviarError(response, 403, "No tiene permiso para imprimir boletos.");
            return;
        }
        String idBoletoTexto =
                request.getParameter(
                        "idBoleto"
                );

        if (idBoletoTexto == null
                || idBoletoTexto.trim().isEmpty()) {

            enviarError(
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    "Debe indicar el boleto que desea imprimir."
            );

            return;
        }

        final int idBoleto;

        try {

            idBoleto =
                    Integer.parseInt(
                            idBoletoTexto.trim()
                    );

        } catch (NumberFormatException e) {

            enviarError(
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    "El identificador del boleto no es válido."
            );

            return;
        }

        if (idBoleto <= 0) {

            enviarError(
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    "El identificador del boleto no es válido."
            );

            return;
        }

        try {

            /*
             * El procedimiento almacenado recibe también
             * el usuario solicitante.
             */
            Boleto boleto =
                    apuestaServicio
                            .obtenerBoletoPorId(
                                    idUsuario,
                                    idBoleto
                            );

            if (boleto == null) {

                enviarError(
                        response,
                        HttpServletResponse.SC_NOT_FOUND,
                        "El boleto no fue encontrado."
                );

                return;
            }

            /*
             * Protección adicional específica de la ruta
             * del cliente.
             *
             * Aunque la BD permite determinadas consultas
             * administrativas, esta ruta solamente permite
             * imprimir boletos propios.
             */
            if (boleto.getIdUsuario()
                    != idUsuario) {

                enviarError(
                        response,
                        HttpServletResponse.SC_FORBIDDEN,
                        "No tiene permiso para imprimir este boleto."
                );

                return;
            }

            /*
             * No se restringe por estado del evento.
             *
             * Un boleto comprado legítimamente puede
             * imprimirse mientras esté pendiente,
             * durante el evento o después de finalizar.
             */
            byte[] pdf =
                    reporteBoletoServicio
                            .generarBoleto(
                                    boleto
                            );

            if (pdf == null
                    || pdf.length == 0) {

                throw new IllegalStateException(
                        "No se generó contenido para el PDF."
                );
            }

            String codigoSeguro =
                    construirNombreSeguro(
                            boleto.getCodigoBoleto()
                    );

            response.reset();
        response.setHeader("Cache-Control", "no-store");

            response.setContentType(
                    "application/pdf"
            );

            response.setContentLength(
                    pdf.length
            );

            /*
             * inline:
             * permite que el navegador abra el PDF
             * directamente y desde ahí pueda imprimirse.
             */
            response.setHeader(
                    "Content-Disposition",
                    "inline; filename=\"boleto-"
                    + codigoSeguro
                    + ".pdf\""
            );

            /*
             * Evita almacenar en caché documentos
             * financieros personales.
             */
            response.setHeader(
                    "Cache-Control",
                    "no-store, no-cache, must-revalidate, max-age=0"
            );

            response.setHeader(
                    "Pragma",
                    "no-cache"
            );

            response.setHeader(
                    "Expires",
                    "0"
            );

            try (OutputStream salida =
                         response.getOutputStream()) {

                salida.write(
                        pdf
                );

                salida.flush();
            }

        } catch (SQLException e) {

            manejarErrorSQL(
                    response,
                    e
            );

        } catch (IllegalArgumentException e) {

            enviarError(
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    "No fue posible procesar el boleto."
            );

        } catch (Exception e) {

            enviarError(
                    response,
                    HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                    "No fue posible generar el boleto en PDF."
            );
        }
    }

    /**
     * Obtiene el identificador del usuario autenticado.
     *
     * Contrato de sesión:
     * session.setAttribute("idUsuario", idUsuario);
     */
    private Integer obtenerIdUsuarioSesion(HttpSession session) {
        Object valor = session.getAttribute("idUsuario");
        if (!(valor instanceof Number) && !(valor instanceof String)) return null;
        try {
            String texto = valor.toString().trim();
            if (valor instanceof String && !texto.matches("[0-9]+")) return null;
            int id = new java.math.BigDecimal(texto).intValueExact();
            return id > 0 ? id : null;
        } catch (ArithmeticException | NumberFormatException e) {
            return null;
        }
    }
    private void manejarErrorSQL(
            HttpServletResponse response,
            SQLException e)
            throws IOException {

        int codigo =
                e.getErrorCode();

        switch (codigo) {

            case 60049:

                enviarError(
                        response,
                        HttpServletResponse.SC_NOT_FOUND,
                        "El boleto indicado no existe."
                );

                break;

            case 60050:

                enviarError(
                        response,
                        HttpServletResponse.SC_UNAUTHORIZED,
                        "El usuario de la sesión no existe."
                );

                break;

            case 60051:

                enviarError(
                        response,
                        HttpServletResponse.SC_FORBIDDEN,
                        "La cuenta se encuentra cerrada."
                );

                break;

            case 60052:

                enviarError(
                        response,
                        HttpServletResponse.SC_FORBIDDEN,
                        "No tiene permiso para consultar este boleto."
                );

                break;

            default:

                enviarError(
                        response,
                        HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                        "No fue posible consultar el boleto."
                );

                break;
        }
    }

    private void enviarError(
            HttpServletResponse response,
            int estado,
            String mensaje)
            throws IOException {

        if (response.isCommitted()) {
            return;
        }

        response.reset();
        response.setHeader("Cache-Control", "no-store");

        response.setStatus(
                estado
        );

        response.setCharacterEncoding(
                "UTF-8"
        );

        response.setContentType(
                "text/plain;charset=UTF-8"
        );

        response.getWriter()
                .write(
                        mensaje == null
                                ? "Ocurrió un error."
                                : mensaje
                );
    }

    private String construirNombreSeguro(
            String codigoBoleto) {

        if (codigoBoleto == null
                || codigoBoleto.trim().isEmpty()) {

            return "sin-codigo";
        }

        return codigoBoleto
                .trim()
                .replaceAll(
                        "[^a-zA-Z0-9._-]",
                        "_"
                );
    }
}
