package com.apuestas.dao;

import java.sql.Connection;

/** Comprueba apertura y cierre; no ejecuta consultas ni muestra datos de conexion. */
public class PruebaConexion {
    public static void main(String[] args) {
        boolean correcto = false;
        boolean poolInicializado = false;
        try {
            Connection conexion = ConexionBD.obtenerConexion();
            poolInicializado = true;
            try (Connection cerrar = conexion) {
                if (cerrar.isClosed()) throw new IllegalStateException();
            }
            correcto = true;
        } catch (Exception | LinkageError e) {
            System.err.println("No fue posible completar la prueba de conexion. Revise la configuracion y conectividad.");
        } finally {
            if (poolInicializado) {
                try { ConexionBD.cerrarPool(); }
                catch (RuntimeException e) { correcto = false; }
            }
        }
        if (!correcto) System.exit(1);
        System.out.println("CONEXION EXITOSA: conexion y pool cerrados.");
    }
}