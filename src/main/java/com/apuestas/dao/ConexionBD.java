/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import java.io.IOException;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.Properties;
/**
 *
 * @author GRUPO8
 */
public class ConexionBD {

    private static final Properties CONFIG = new Properties();
    private static final HikariDataSource DATA_SOURCE;

    static {
        try (InputStream entrada = ConexionBD.class
                .getClassLoader()
                .getResourceAsStream("config.properties")) {

            System.out.println("Buscando config.properties...");
            System.out.println("Archivo encontrado: " + (entrada != null));

            if (entrada == null) {
                throw new RuntimeException(
                        "No se encontró config.properties en src/main/resources"
                );
            }

            CONFIG.load(entrada);

            String url = CONFIG.getProperty("db.url");
            String usuario = CONFIG.getProperty("db.usuario");
            String password = CONFIG.getProperty("db.password");

            if (url == null || usuario == null || password == null) {
                throw new RuntimeException(
                        "La configuración de la base de datos está incompleta."
                );
            }

            HikariConfig hikariConfig = new HikariConfig();

            hikariConfig.setJdbcUrl(url);
            hikariConfig.setUsername(usuario);
            hikariConfig.setPassword(password);

            /*
             * Configuración inicial conservadora.
             * Posteriormente se ajustará según las pruebas de carga.
             */
            hikariConfig.setMaximumPoolSize(10);
            hikariConfig.setMinimumIdle(2);

            hikariConfig.setConnectionTimeout(30000);
            hikariConfig.setIdleTimeout(600000);
            hikariConfig.setMaxLifetime(1800000);

            hikariConfig.setPoolName("PlataformaApuestasPool");

            DATA_SOURCE = new HikariDataSource(hikariConfig);

            System.out.println(
                    "Pool de conexiones HikariCP inicializado correctamente."
            );

        } catch (IOException e) {
            throw new ExceptionInInitializerError(
                    "Error al cargar la configuración de la base de datos: "
                    + e.getMessage()
            );
        }
    }

    private ConexionBD() {
        // Evita crear instancias de esta clase.
    }

    public static Connection obtenerConexion()
            throws SQLException {

        return DATA_SOURCE.getConnection();
    }

    public static void cerrarPool() {

        if (DATA_SOURCE != null && !DATA_SOURCE.isClosed()) {
            DATA_SOURCE.close();
        }
    }
}