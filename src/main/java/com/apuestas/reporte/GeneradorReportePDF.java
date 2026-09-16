/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.apuestas.reporte;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import net.sf.jasperreports.engine.JRDataSource;
import net.sf.jasperreports.engine.JasperCompileManager;
import net.sf.jasperreports.engine.JasperExportManager;
import net.sf.jasperreports.engine.JasperFillManager;
import net.sf.jasperreports.engine.JasperPrint;
import net.sf.jasperreports.engine.JasperReport;
/**
 *
 * @author alumno
 */
public final class GeneradorReportePDF {

    private static final Map<String, JasperReport> CACHE =
            new ConcurrentHashMap<>();

    private GeneradorReportePDF() {
    }

    /**
     * Genera un PDF a partir de una plantilla JRXML.
     *
     * @param recursoJrxml ruta de la plantilla dentro de resources
     * @param parametros parámetros enviados al reporte
     * @param dataSource datos del reporte
     * @return contenido del PDF en bytes
     * @throws Exception si ocurre un error al generar el reporte
     */
    public static byte[] generar(
            String recursoJrxml,
            Map<String, Object> parametros,
            JRDataSource dataSource)
            throws Exception {

        JasperReport reporte = obtenerReporte(recursoJrxml);

        JasperPrint impresion =
                JasperFillManager.fillReport(
                        reporte,
                        parametros,
                        dataSource
                );

        try (ByteArrayOutputStream salida =
                     new ByteArrayOutputStream()) {

            JasperExportManager.exportReportToPdfStream(
                    impresion,
                    salida
            );

            return salida.toByteArray();
        }
    }

    private static JasperReport obtenerReporte(
            String recursoJrxml)
            throws Exception {

        JasperReport existente =
                CACHE.get(recursoJrxml);

        if (existente != null) {
            return existente;
        }

        try (InputStream entrada =
                     GeneradorReportePDF.class
                             .getClassLoader()
                             .getResourceAsStream(recursoJrxml)) {

            if (entrada == null) {
                throw new IllegalArgumentException(
                        "No se encontró la plantilla: "
                        + recursoJrxml
                );
            }

            JasperReport compilado =
                    JasperCompileManager.compileReport(
                            entrada
                    );

            CACHE.put(
                    recursoJrxml,
                    compilado
            );

            return compilado;
        }
    }
}
