/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;

import com.apuestas.modelo.Liga;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;

/**
 *
 * @author farfa
 */

public class LigaDAO {

    public Liga crearLiga(int idUsuarioProceso,
                          Liga liga,
                          String ipOrigen)
            throws SQLException {

        String sql =
                "{call dbo.sp_CrearLiga(?, ?, ?, ?, ?)}";

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

            establecerIp(cs, 5, ipOrigen);

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {
                    return mapearLiga(rs);
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_CrearLiga no devolvió la liga creada.");
    }

    public Liga actualizarLiga(int idUsuarioProceso,
                               Liga liga,
                               String ipOrigen)
            throws SQLException {

        String sql =
                "{call dbo.sp_ActualizarLiga(?, ?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement cs = conexion.prepareCall(sql)) {

            cs.setInt(1, idUsuarioProceso);
            cs.setInt(2, liga.getIdLiga());
            cs.setString(3, liga.getNombre());

            if (liga.getIdPais() != null) {
                cs.setInt(4, liga.getIdPais());
            } else {
                cs.setNull(4, Types.INTEGER);
            }

            cs.setBoolean(5, liga.isActivo());

            establecerIp(cs, 6, ipOrigen);

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {
                    return mapearLiga(rs);
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_ActualizarLiga no devolvió la liga actualizada.");
    }

    public List<Liga> listarLigas() throws SQLException {

        List<Liga> ligas = new ArrayList<>();

        String sql =
                "SELECT "
                + "IdLiga, "
                + "IdDeporte, "
                + "IdPais, "
                + "Nombre, "
                + "Activo "
                + "FROM dbo.Liga "
                + "ORDER BY Nombre";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps = conexion.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                ligas.add(mapearLiga(rs));
            }
        }

        return ligas;
    }

    public List<Liga> listarLigasActivas() throws SQLException {

        List<Liga> ligas = new ArrayList<>();

        String sql =
                "SELECT "
                + "IdLiga, "
                + "IdDeporte, "
                + "IdPais, "
                + "Nombre, "
                + "Activo "
                + "FROM dbo.Liga "
                + "WHERE Activo = 1 "
                + "ORDER BY Nombre";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps = conexion.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                ligas.add(mapearLiga(rs));
            }
        }

        return ligas;
    }

    public List<Liga> listarLigasPorDeporte(int idDeporte)
            throws SQLException {

        List<Liga> ligas = new ArrayList<>();

        String sql =
                "SELECT "
                + "IdLiga, "
                + "IdDeporte, "
                + "IdPais, "
                + "Nombre, "
                + "Activo "
                + "FROM dbo.Liga "
                + "WHERE IdDeporte = ? "
                + "AND Activo = 1 "
                + "ORDER BY Nombre";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps = conexion.prepareStatement(sql)) {

            ps.setInt(1, idDeporte);

            try (ResultSet rs = ps.executeQuery()) {

                while (rs.next()) {
                    ligas.add(mapearLiga(rs));
                }
            }
        }

        return ligas;
    }

    public Liga buscarPorId(int idLiga)
            throws SQLException {

        String sql =
                "SELECT "
                + "IdLiga, "
                + "IdDeporte, "
                + "IdPais, "
                + "Nombre, "
                + "Activo "
                + "FROM dbo.Liga "
                + "WHERE IdLiga = ?";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps = conexion.prepareStatement(sql)) {

            ps.setInt(1, idLiga);

            try (ResultSet rs = ps.executeQuery()) {

                if (rs.next()) {
                    return mapearLiga(rs);
                }
            }
        }

        return null;
    }

    private Liga mapearLiga(ResultSet rs)
            throws SQLException {

        Liga liga = new Liga();

        liga.setIdLiga(
                rs.getInt("IdLiga"));

        liga.setIdDeporte(
                rs.getInt("IdDeporte"));

        int idPais =
                rs.getInt("IdPais");

        if (rs.wasNull()) {
            liga.setIdPais(null);
        } else {
            liga.setIdPais(idPais);
        }

        liga.setNombre(
                rs.getString("Nombre"));

        liga.setActivo(
                rs.getBoolean("Activo"));

        return liga;
    }

    private void establecerIp(CallableStatement cs,
                              int parametro,
                              String ipOrigen)
            throws SQLException {

        if (ipOrigen != null
                && !ipOrigen.trim().isEmpty()) {

            cs.setString(parametro, ipOrigen);

        } else {

            cs.setNull(parametro, Types.VARCHAR);
        }
    }
}