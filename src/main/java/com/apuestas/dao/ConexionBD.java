/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
/**
 *
 * @author GRUPO8
 */
public class ConexionBD {

    private static final String URL =
            "jdbc:sqlserver://localhost:1433;"
            + "databaseName=PlataformaApuestas;"
            + "encrypt=true;"
            + "trustServerCertificate=true;";

    private static final String USUARIO = "sa";
    private static final String PASSWORD = "CONFIGURAR LOCALMENTE";

    public static Connection obtenerConexion() throws SQLException {

        try {
            Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
        } catch (ClassNotFoundException e) {
            throw new SQLException(
                    "No se encontró el driver JDBC de SQL Server.",
                    e
            );
        }

        return DriverManager.getConnection(
                URL,
                USUARIO,
                PASSWORD
        );
    }
}