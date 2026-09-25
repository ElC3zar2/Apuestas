/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.apuestas.dao;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
/**
 *
 * @author alumno
 */
public class PruebaConcurrenciaConexion {

    private static final int[] NIVELES = {5, 10, 20, 50};

    public static void main(String[] args) throws Exception {

        System.out.println("========================================");
        System.out.println(" PRUEBA CONCURRENTE DE CONEXIONES");
        System.out.println(" HikariCP - Azure SQL");
        System.out.println("========================================");

        // Una conexión inicial para arrancar el pool.
        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps = conexion.prepareStatement("SELECT 1");
             ResultSet rs = ps.executeQuery()) {

            if (!rs.next() || rs.getInt(1) != 1) {
                throw new IllegalStateException(
                        "Falló la validación inicial."
                );
            }
        }

        System.out.println("Pool inicializado.");
        System.out.println();

        for (int cantidad : NIVELES) {
            ejecutarPrueba(cantidad);

            // Pequeña pausa entre niveles.
            Thread.sleep(1500);
        }
    }

    private static void ejecutarPrueba(int cantidad)
            throws Exception {

        ExecutorService executor =
                Executors.newFixedThreadPool(cantidad);

        CountDownLatch inicioSimultaneo =
                new CountDownLatch(1);

        List<Future<Resultado>> futuros =
                new ArrayList<>();

        for (int i = 1; i <= cantidad; i++) {

            final int numero = i;

            Callable<Resultado> tarea = () -> {

                inicioSimultaneo.await();

                long inicio = System.nanoTime();

                try (Connection conexion =
                             ConexionBD.obtenerConexion();
                     PreparedStatement ps =
                             conexion.prepareStatement("SELECT 1");
                     ResultSet rs =
                             ps.executeQuery()) {

                    if (!rs.next() || rs.getInt(1) != 1) {
                        throw new IllegalStateException(
                                "Resultado SQL inesperado."
                        );
                    }

                    long fin = System.nanoTime();

                    return new Resultado(
                            numero,
                            true,
                            (fin - inicio) / 1_000_000,
                            null
                    );

                } catch (Exception e) {

                    long fin = System.nanoTime();

                    return new Resultado(
                            numero,
                            false,
                            (fin - inicio) / 1_000_000,
                            e.getMessage()
                    );
                }
            };

            futuros.add(executor.submit(tarea));
        }

        long inicioGrupo = System.nanoTime();

        // Todas las tareas comienzan juntas.
        inicioSimultaneo.countDown();

        int exitosas = 0;
        int errores = 0;

        long suma = 0;
        long minimo = Long.MAX_VALUE;
        long maximo = 0;

        for (Future<Resultado> futuro : futuros) {

            Resultado resultado = futuro.get();

            if (resultado.exitosa) {

                exitosas++;
                suma += resultado.tiempoMs;

                minimo = Math.min(
                        minimo,
                        resultado.tiempoMs
                );

                maximo = Math.max(
                        maximo,
                        resultado.tiempoMs
                );

            } else {

                errores++;

                System.out.println(
                        "Solicitud "
                        + resultado.numero
                        + " ERROR: "
                        + resultado.error
                );
            }
        }

        long finGrupo = System.nanoTime();

        executor.shutdown();

        long tiempoGrupo =
                (finGrupo - inicioGrupo) / 1_000_000;

        double promedio =
                exitosas > 0
                        ? (double) suma / exitosas
                        : 0;

        double solicitudesSegundo =
                tiempoGrupo > 0
                        ? (cantidad * 1000.0) / tiempoGrupo
                        : 0;

        System.out.println("----------------------------------------");
        System.out.println(
                "CONCURRENCIA: " + cantidad
        );
        System.out.println("----------------------------------------");

        System.out.println(
                "Exitosas: " + exitosas
        );

        System.out.println(
                "Errores: " + errores
        );

        System.out.printf(
                "Promedio por solicitud: %.2f ms%n",
                promedio
        );

        if (exitosas > 0) {

            System.out.println(
                    "Mínimo: " + minimo + " ms"
            );

            System.out.println(
                    "Máximo: " + maximo + " ms"
            );
        }

        System.out.println(
                "Tiempo total del grupo: "
                + tiempoGrupo + " ms"
        );

        System.out.printf(
                "Solicitudes/segundo: %.2f%n",
                solicitudesSegundo
        );

        System.out.println();
    }

    private static class Resultado {

        private final int numero;
        private final boolean exitosa;
        private final long tiempoMs;
        private final String error;

        private Resultado(
                int numero,
                boolean exitosa,
                long tiempoMs,
                String error) {

            this.numero = numero;
            this.exitosa = exitosa;
            this.tiempoMs = tiempoMs;
            this.error = error;
        }
    }
}
