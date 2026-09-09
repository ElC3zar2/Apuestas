/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;

import com.apuestas.modelo.Deporte;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

/**
 *
 * @author farfa
 */
public class DeporteDAO {

    public List<Deporte> listarDeportesActivos() throws SQLException {

        List<Deporte> deportes = new ArrayList<>();

        String sql =
                "SELECT "
                + "IdDeporte, "
                + "Nombre, "
                + "Descripcion, "
                + "Activo "
                + "FROM dbo.Deporte "
                + "WHERE Activo = 1 "
                + "ORDER BY Nombre";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps = conexion.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {

                Deporte deporte = new Deporte();

                deporte.setIdDeporte(
                        rs.getInt("IdDeporte")
                );

                deporte.setNombre(
                        rs.getString("Nombre")
                );

                deporte.setDescripcion(
                        rs.getString("Descripcion")
                );

                deporte.setActivo(
                        rs.getBoolean("Activo")
                );

                deportes.add(deporte);
            }
        }

        return deportes;
    }

    public Deporte buscarPorId(int idDeporte) throws SQLException {

        String sql =
                "SELECT "
                + "IdDeporte, "
                + "Nombre, "
                + "Descripcion, "
                + "Activo "
                + "FROM dbo.Deporte "
                + "WHERE IdDeporte = ?";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps = conexion.prepareStatement(sql)) {

            ps.setInt(1, idDeporte);

            try (ResultSet rs = ps.executeQuery()) {

                if (rs.next()) {

                    Deporte deporte = new Deporte();

                    deporte.setIdDeporte(
                            rs.getInt("IdDeporte")
                    );

                    deporte.setNombre(
                            rs.getString("Nombre")
                    );

                    deporte.setDescripcion(
                            rs.getString("Descripcion")
                    );

                    deporte.setActivo(
                            rs.getBoolean("Activo")
                    );

                    return deporte;
                }
            }
        }

        return null;
    }
}