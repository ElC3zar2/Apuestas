package com.apuestas.dao;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import java.io.InputStream;
import java.io.IOException;
import java.util.Properties;
import java.sql.Connection;
import java.sql.SQLException;

public class ConexionBD {
    private static final HikariDataSource DATA_SOURCE;

    static {
        Properties propiedades = new Properties();
        try (InputStream entrada = ConexionBD.class.getClassLoader()
                .getResourceAsStream("config.properties")) {
            if (entrada == null) {
                throw new ExceptionInInitializerError("Falta config.properties en el classpath.");
            }
            propiedades.load(entrada);
        } catch (IOException | IllegalArgumentException e) {
            throw new ExceptionInInitializerError("No fue posible leer config.properties.");
        }
        String url = propiedadRequerida(propiedades, "db.url");
        String usuario = propiedadRequerida(propiedades, "db.usuario");
        String password = propiedadRequerida(propiedades, "db.password");
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

    private static String propiedadRequerida(Properties propiedades, String nombre) {
        String valor = propiedades.getProperty(nombre);
        if (valor == null || valor.trim().isEmpty()) {
            throw new IllegalStateException("Falta propiedad requerida de base de datos: " + nombre);
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