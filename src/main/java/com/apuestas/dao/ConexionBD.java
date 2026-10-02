package com.apuestas.dao;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import java.sql.Connection;
import java.sql.SQLException;

public class ConexionBD {
    private static final HikariDataSource DATA_SOURCE;

    static {
        String url = variableRequerida("APUESTAS_DB_URL");
        String usuario = variableRequerida("APUESTAS_DB_USUARIO");
        String password = variableRequerida("APUESTAS_DB_PASSWORD");
        try {
            HikariConfig configuracion = new HikariConfig();
            configuracion.setDriverClassName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
            configuracion.setJdbcUrl(url);
            configuracion.setUsername(usuario);
            configuracion.setPassword(password);
            configuracion.setMaximumPoolSize(10);
            configuracion.setMinimumIdle(2);
            configuracion.setConnectionTimeout(30000);
            configuracion.setIdleTimeout(600000);
            configuracion.setMaxLifetime(1800000);
            configuracion.setPoolName("PlataformaApuestasPool");
            DATA_SOURCE = new HikariDataSource(configuracion);
        } catch (RuntimeException e) {
            // El proveedor puede incluir URL o credenciales en la excepcion original.
            throw new ExceptionInInitializerError("No fue posible inicializar el pool de base de datos.");
        }
    }

    private static String variableRequerida(String nombre) {
        String valor = System.getenv(nombre);
        if (valor == null || valor.trim().isEmpty()) {
            throw new IllegalStateException("Falta configuracion externa de base de datos: " + nombre);
        }
        return valor;
    }

    private ConexionBD() { }

    public static Connection obtenerConexion() throws SQLException {
        return DATA_SOURCE.getConnection();
    }

    public static void cerrarPool() {
        if (!DATA_SOURCE.isClosed()) DATA_SOURCE.close();
    }
}