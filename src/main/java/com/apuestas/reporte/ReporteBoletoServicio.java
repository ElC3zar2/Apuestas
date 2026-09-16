/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.apuestas.reporte;
import com.apuestas.modelo.Boleto;
import com.apuestas.modelo.DetalleBoleto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import net.sf.jasperreports.engine.data.JRBeanCollectionDataSource;
/**
 *
 * @author alumno
 */
public class ReporteBoletoServicio {

    private static final DateTimeFormatter FORMATO_FECHA =
            DateTimeFormatter.ofPattern(
                    "dd/MM/yyyy HH:mm"
            );

    /**
     * Genera el PDF de un boleto.
     *
     * @param boleto boleto que será representado
     * @return contenido PDF en bytes
     * @throws Exception si ocurre un error al generar el reporte
     */
    public byte[] generarBoleto(
            Boleto boleto)
            throws Exception {

        if (boleto == null) {
            throw new IllegalArgumentException(
                    "El boleto es obligatorio."
            );
        }

        Map<String, Object> parametros =
                new HashMap<>();

        parametros.put(
                "codigoBoleto",
                texto(boleto.getCodigoBoleto())
        );

        parametros.put(
                "correo",
                texto(boleto.getCorreo())
        );

        parametros.put(
                "tipoBoleto",
                texto(boleto.getTipoBoleto())
        );

        parametros.put(
                "estadoBoleto",
                texto(boleto.getEstadoBoleto())
        );

        parametros.put(
                "resultadoBoleto",
                texto(boleto.getResultado())
        );

        parametros.put(
                "montoApostado",
                monto(boleto.getMontoApostado())
        );

        parametros.put(
                "comisionServicio",
                monto(boleto.getComisionServicio())
        );

        parametros.put(
                "totalCargo",
                monto(boleto.getTotalCargo())
        );

        parametros.put(
                "cuotaTotal",
                numero(boleto.getCuotaTotal())
        );

        parametros.put(
                "premioPotencial",
                monto(boleto.getGananciaPotencial())
        );

        parametros.put(
                "fechaCreacion",
                fecha(boleto.getFechaCreacion())
        );

        parametros.put(
                "fechaLiquidacion",
                boleto.getFechaLiquidacion() == null
                        ? "Pendiente"
                        : fecha(boleto.getFechaLiquidacion())
        );

        parametros.put(
                "referenciaOperacion",
                texto(boleto.getReferenciaOperacion())
        );

        List<DetalleBoleto> detalles =
                boleto.getDetalles() == null
                        ? Collections.emptyList()
                        : boleto.getDetalles();

        JRBeanCollectionDataSource dataSource =
                new JRBeanCollectionDataSource(
                        detalles
                );

        return GeneradorReportePDF.generar(
                "reportes/boleto_cliente.jrxml",
                parametros,
                dataSource
        );
    }

    private String texto(String valor) {

        if (valor == null
                || valor.trim().isEmpty()) {

            return "-";
        }

        return valor.trim();
    }

    private String fecha(
            LocalDateTime valor) {

        if (valor == null) {
            return "-";
        }

        return valor.format(
                FORMATO_FECHA
        );
    }

    private String monto(
            BigDecimal valor) {

        if (valor == null) {
            return "Q 0.00";
        }

        return String.format(
                Locale.US,
                "Q %,.2f",
                valor
        );
    }

    private String numero(
            BigDecimal valor) {

        if (valor == null) {
            return "0.00";
        }

        return String.format(
                Locale.US,
                "%,.2f",
                valor
        );
    }
}
