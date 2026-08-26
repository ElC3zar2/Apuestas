/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import java.io.IOException;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;
/**
 *
 * @author GRUPO8
 */
public class ConexionBD {

    private static final Properties CONFIG = new Properties();

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

            Class.forName(
                    "com.microsoft.sqlserver.jdbc.SQLServerDriver"
            );

        } catch (IOException | ClassNotFoundException e) {
            throw new RuntimeException(
                    "Error al cargar la configuración de la base de datos.",
                    e
            );
        }
    }

    public static Connection obtenerConexion()
            throws SQLException {

        String url = CONFIG.getProperty("db.url");
        String usuario = CONFIG.getProperty("db.usuario");
        String password = CONFIG.getProperty("db.password");

        if (url == null || usuario == null || password == null) {
            throw new SQLException(
                    "La configuración de la base de datos está incompleta."
            );
        }

        return DriverManager.getConnection(
                url,
                usuario,
                password
        );
    }
}