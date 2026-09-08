/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import com.apuestas.modelo.Participante;
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
public class ParticipanteDAO {

    public Participante crearParticipante(int idUsuarioProceso,
                                          Participante participante,
                                          String ipOrigen)
            throws SQLException {

        String sql =
                "{call dbo.sp_CrearParticipante(?, ?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement cs = conexion.prepareCall(sql)) {

            cs.setInt(1, idUsuarioProceso);
            cs.setInt(2, participante.getIdDeporte());
            cs.setString(3, participante.getNombre());
            cs.setString(4, participante.getTipoParticipante());

            if (participante.getIdPais() != null) {
                cs.setInt(5, participante.getIdPais());
            } else {
                cs.setNull(5, Types.INTEGER);
            }

            establecerIp(cs, 6, ipOrigen);

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {
                    return mapearParticipante(rs);
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_CrearParticipante no devolvió el participante creado.");
    }

    public Participante actualizarParticipante(
            int idUsuarioProceso,
            Participante participante,
            String ipOrigen)
            throws SQLException {

        String sql =
                "{call dbo.sp_ActualizarParticipante(?, ?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement cs = conexion.prepareCall(sql)) {

            cs.setInt(1, idUsuarioProceso);
            cs.setInt(2, participante.getIdParticipante());
            cs.setString(3, participante.getNombre());

            if (participante.getIdPais() != null) {
                cs.setInt(4, participante.getIdPais());
            } else {
                cs.setNull(4, Types.INTEGER);
            }

            cs.setBoolean(5, participante.isActivo());

            establecerIp(cs, 6, ipOrigen);

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {
                    return mapearParticipante(rs);
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_ActualizarParticipante no devolvió el participante actualizado.");
    }

    public List<Participante> listarParticipantes()
            throws SQLException {

        List<Participante> participantes =
                new ArrayList<>();

        String sql =
                "SELECT "
                + "IdParticipante, "
                + "IdDeporte, "
                + "IdPais, "
                + "Nombre, "
                + "TipoParticipante, "
                + "Activo "
                + "FROM dbo.Participante "
                + "ORDER BY Nombre";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                participantes.add(
                        mapearParticipante(rs));
            }
        }

        return participantes;
    }

    public List<Participante> listarParticipantesActivos()
            throws SQLException {

        List<Participante> participantes =
                new ArrayList<>();

        String sql =
                "SELECT "
                + "IdParticipante, "
                + "IdDeporte, "
                + "IdPais, "
                + "Nombre, "
                + "TipoParticipante, "
                + "Activo "
                + "FROM dbo.Participante "
                + "WHERE Activo = 1 "
                + "ORDER BY Nombre";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                participantes.add(
                        mapearParticipante(rs));
            }
        }

        return participantes;
    }

    public List<Participante> listarParticipantesPorDeporte(
            int idDeporte)
            throws SQLException {

        List<Participante> participantes =
                new ArrayList<>();

        String sql =
                "SELECT "
                + "IdParticipante, "
                + "IdDeporte, "
                + "IdPais, "
                + "Nombre, "
                + "TipoParticipante, "
                + "Activo "
                + "FROM dbo.Participante "
                + "WHERE IdDeporte = ? "
                + "AND Activo = 1 "
                + "ORDER BY Nombre";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql)) {

            ps.setInt(1, idDeporte);

            try (ResultSet rs =
                         ps.executeQuery()) {

                while (rs.next()) {
                    participantes.add(
                            mapearParticipante(rs));
                }
            }
        }

        return participantes;
    }

    public Participante buscarPorId(
            int idParticipante)
            throws SQLException {

        String sql =
                "SELECT "
                + "IdParticipante, "
                + "IdDeporte, "
                + "IdPais, "
                + "Nombre, "
                + "TipoParticipante, "
                + "Activo "
                + "FROM dbo.Participante "
                + "WHERE IdParticipante = ?";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql)) {

            ps.setInt(1, idParticipante);

            try (ResultSet rs =
                         ps.executeQuery()) {

                if (rs.next()) {
                    return mapearParticipante(rs);
                }
            }
        }

        return null;
    }

    private Participante mapearParticipante(
            ResultSet rs)
            throws SQLException {

        Participante participante =
                new Participante();

        participante.setIdParticipante(
                rs.getInt("IdParticipante"));

        participante.setIdDeporte(
                rs.getInt("IdDeporte"));

        int idPais =
                rs.getInt("IdPais");

        if (rs.wasNull()) {
            participante.setIdPais(null);
        } else {
            participante.setIdPais(idPais);
        }

        participante.setNombre(
                rs.getString("Nombre"));

        participante.setTipoParticipante(
                rs.getString("TipoParticipante"));

        participante.setActivo(
                rs.getBoolean("Activo"));

        return participante;
    }

    private void establecerIp(
            CallableStatement cs,
            int parametro,
            String ipOrigen)
            throws SQLException {

        if (ipOrigen != null
                && !ipOrigen.trim().isEmpty()) {

            cs.setString(parametro, ipOrigen);

        } else {

            cs.setNull(
                    parametro,
                    Types.VARCHAR);
        }
    }
}