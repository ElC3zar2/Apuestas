/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.apuestas.dao;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
/**
 *
 * @author alumno
 */
public class PruebaRendimientoConexion {

    private static final int ITERACIONES = 20;

    public static void main(String[] args) {

        long tiempoTotal = 0;
        long minimo = Long.MAX_VALUE;
        long maximo = 0;
        int exitosas = 0;
        int errores = 0;

        System.out.println("========================================");
        System.out.println(" PRUEBA BASE DE CONEXIONES");
        System.out.println(" Iteraciones: " + ITERACIONES);
        System.out.println("========================================");

        for (int i = 1; i <= ITERACIONES; i++) {

            long inicio = System.nanoTime();

            try (Connection conexion = ConexionBD.obtenerConexion();
                 PreparedStatement ps = conexion.prepareStatement("SELECT 1");
                 ResultSet rs = ps.executeQuery()) {

                if (!rs.next() || rs.getInt(1) != 1) {
                    throw new IllegalStateException(
                            "La consulta de validacion no devolvio el valor esperado."
                    );
                }

                long fin = System.nanoTime();
                long tiempoMs = (fin - inicio) / 1_000_000;

                tiempoTotal += tiempoMs;
                minimo = Math.min(minimo, tiempoMs);
                maximo = Math.max(maximo, tiempoMs);

                exitosas++;

                System.out.println(
                        "Conexion " + i + ": " + tiempoMs + " ms"
                );

            } catch (Exception e) {

                errores++;

                System.out.println(
                        "Conexion " + i + ": ERROR - "
                        + e.getMessage()
                );
            }
        }

        System.out.println();
        System.out.println("========================================");
        System.out.println(" RESULTADOS");
        System.out.println("========================================");
        System.out.println("Exitosas: " + exitosas);
        System.out.println("Errores: " + errores);

        if (exitosas > 0) {

            double promedio =
                    (double) tiempoTotal / exitosas;

            System.out.printf(
                    "Promedio: %.2f ms%n",
                    promedio
            );

            System.out.println(
                    "Minimo: " + minimo + " ms"
            );

            System.out.println(
                    "Maximo: " + maximo + " ms"
            );

            System.out.println(
                    "Tiempo acumulado: "
                    + tiempoTotal + " ms"
            );
        }

        System.out.println("========================================");
    }
}