/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
/**
 *
 * @author cesar
 */
import java.sql.Connection;
import java.sql.DatabaseMetaData;

public class PruebaConexion {

    public static void main(String[] args) {

        try (Connection conexion = ConexionBD.obtenerConexion()) {

            DatabaseMetaData meta = conexion.getMetaData();

            System.out.println("=================================");
            System.out.println("CONEXION EXITOSA");
            System.out.println("=================================");
            System.out.println("Servidor: " + meta.getURL());
            System.out.println("Base de datos: " + conexion.getCatalog());
            System.out.println("Usuario: " + meta.getUserName());
            System.out.println("=================================");

        } catch (Exception e) {

            System.out.println("=================================");
            System.out.println("ERROR DE CONEXION");
            System.out.println("=================================");

            e.printStackTrace();
        }
    }
}