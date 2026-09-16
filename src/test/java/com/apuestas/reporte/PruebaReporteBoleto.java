/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.apuestas.reporte;
import com.apuestas.modelo.Boleto;
import com.apuestas.servicio.ApuestaServicio;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.SQLException;
import java.util.Scanner;
/**
 *
 * @author alumno
 */
public class PruebaReporteBoleto {

    public static void main(String[] args) {

        try (Scanner scanner = new Scanner(System.in)) {

            System.out.println(
                    "=============================================="
            );
            System.out.println(
                    "PRUEBA DE REPORTE DE BOLETO - BASE DE DATOS"
            );
            System.out.println(
                    "=============================================="
            );

            System.out.print(
                    "Ingrese el IdUsuario propietario del boleto: "
            );

            int idUsuario =
                    leerEnteroPositivo(
                            scanner,
                            "IdUsuario"
                    );

            System.out.print(
                    "Ingrese el IdBoleto que desea generar: "
            );

            int idBoleto =
                    leerEnteroPositivo(
                            scanner,
                            "IdBoleto"
                    );

            System.out.println();
            System.out.println(
                    "Consultando boleto en la base de datos..."
            );

            ApuestaServicio apuestaServicio =
                    new ApuestaServicio();

            Boleto boleto =
                    apuestaServicio.obtenerBoletoPorId(
                            idUsuario,
                            idBoleto
                    );

            if (boleto == null) {
                throw new IllegalStateException(
                        "No fue posible recuperar el boleto."
                );
            }

            System.out.println(
                    "Boleto recuperado correctamente."
            );

            System.out.println(
                    "Código: "
                    + boleto.getCodigoBoleto()
            );

            System.out.println(
                    "Cliente: "
                    + boleto.getCorreo()
            );

            System.out.println(
                    "Estado: "
                    + boleto.getEstadoBoleto()
            );

            System.out.println(
                    "Resultado: "
                    + boleto.getResultado()
            );

            System.out.println(
                    "Selecciones: "
                    + (
                        boleto.getDetalles() == null
                                ? 0
                                : boleto.getDetalles().size()
                    )
            );

            ReporteBoletoServicio reporteServicio =
                    new ReporteBoletoServicio();

            byte[] pdf =
                    reporteServicio.generarBoleto(
                            boleto
                    );

            if (pdf == null
                    || pdf.length == 0) {

                throw new IllegalStateException(
                        "JasperReports no generó contenido PDF."
                );
            }

            Path carpetaTarget =
                    Paths.get(
                            "target"
                    );

            Files.createDirectories(
                    carpetaTarget
            );

            String codigoSeguro =
                    construirNombreSeguro(
                            boleto.getCodigoBoleto()
                    );

            Path destino =
                    carpetaTarget.resolve(
                            "boleto-"
                            + codigoSeguro
                            + ".pdf"
                    );

            Files.write(
                    destino,
                    pdf
            );

            System.out.println();
            System.out.println(
                    "=============================================="
            );
            System.out.println(
                    "PDF GENERADO CORRECTAMENTE"
            );
            System.out.println(
                    "=============================================="
            );

            System.out.println(
                    "Boleto: "
                    + boleto.getCodigoBoleto()
            );

            System.out.println(
                    "Bytes generados: "
                    + pdf.length
            );

            System.out.println(
                    "Archivo:"
            );

            System.out.println(
                    destino
                            .toAbsolutePath()
                            .normalize()
            );

            System.out.println(
                    "=============================================="
            );

        } catch (SQLException e) {

            System.err.println();
            System.err.println(
                    "ERROR DE BASE DE DATOS"
            );

            System.err.println(
                    "Código SQL: "
                    + e.getErrorCode()
            );

            System.err.println(
                    "Mensaje: "
                    + e.getMessage()
            );

        } catch (NumberFormatException e) {

            System.err.println();
            System.err.println(
                    "Debe ingresar valores numéricos válidos."
            );

        } catch (IllegalArgumentException e) {

            System.err.println();
            System.err.println(
                    "DATOS NO VÁLIDOS"
            );

            System.err.println(
                    e.getMessage()
            );

        } catch (Exception e) {

            System.err.println();
            System.err.println(
                    "ERROR AL GENERAR EL REPORTE"
            );

            System.err.println(
                    e.getClass().getSimpleName()
                    + ": "
                    + e.getMessage()
            );

            e.printStackTrace();
        }
    }

    private static int leerEnteroPositivo(
            Scanner scanner,
            String nombre) {

        String entrada =
                scanner.nextLine().trim();

        int valor =
                Integer.parseInt(
                        entrada
                );

        if (valor <= 0) {
            throw new IllegalArgumentException(
                    nombre
                    + " debe ser mayor que cero."
            );
        }

        return valor;
    }

    private static String construirNombreSeguro(
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