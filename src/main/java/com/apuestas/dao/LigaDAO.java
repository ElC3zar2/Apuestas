/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;

import com.apuestas.modelo.Liga;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;

/**
 *
 * @author farfa
 */

public class LigaDAO {

    public Liga crearLiga(int idUsuarioProceso, Liga liga, String ipOrigen)
            throws SQLException {

        String sql = "{call dbo.sp_CrearLiga(?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement cs = conexion.prepareCall(sql)) {

            cs.setInt(1, idUsuarioProceso);
            cs.setInt(2, liga.getIdDeporte());
            cs.setString(3, liga.getNombre());

            if (liga.getIdPais() != null) {
                cs.setInt(4, liga.getIdPais());
            } else {
                cs.setNull(4, Types.INTEGER);
            }

            if (ipOrigen != null && !ipOrigen.trim().isEmpty()) {
                cs.setString(5, ipOrigen);
            } else {
                cs.setNull(5, Types.VARCHAR);
            }

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {

                    Liga ligaCreada = new Liga();

                    ligaCreada.setIdLiga(rs.getInt("IdLiga"));
                    ligaCreada.setIdDeporte(rs.getInt("IdDeporte"));

                    int idPais = rs.getInt("IdPais");

                    if (rs.wasNull()) {
                        ligaCreada.setIdPais(null);
                    } else {
                        ligaCreada.setIdPais(idPais);
                    }

                    ligaCreada.setNombre(rs.getString("Nombre"));
                    ligaCreada.setActivo(rs.getBoolean("Activo"));

                    return ligaCreada;
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_CrearLiga no devolvió la liga creada.");
    }
}
