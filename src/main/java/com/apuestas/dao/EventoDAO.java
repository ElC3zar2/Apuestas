/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import com.apuestas.modelo.Evento;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
/**
 *
 * @author farfa
 */
public class EventoDAO {

    public Evento crearEvento(int idUsuarioProceso,
                              Evento evento,
                              String ipOrigen)
            throws SQLException {

        String sql =
                "{call dbo.sp_CrearEvento(?, ?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement cs = conexion.prepareCall(sql)) {

            cs.setInt(1, idUsuarioProceso);
            cs.setInt(2, evento.getIdLiga());
            cs.setString(3, evento.getNombre());

            cs.setTimestamp(
                    4,
                    Timestamp.valueOf(evento.getFechaInicio())
            );

            if (evento.getFechaFin() != null) {

                cs.setTimestamp(
                        5,
                        Timestamp.valueOf(evento.getFechaFin())
                );

            } else {

                cs.setNull(
                        5,
                        Types.TIMESTAMP
                );
            }

            establecerIp(cs, 6, ipOrigen);

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {
                    return mapearEvento(rs);
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_CrearEvento no devolvió el evento creado.");
    }

    public Evento actualizarEvento(int idUsuarioProceso,
                                   Evento evento,
                                   String ipOrigen)
            throws SQLException {

        String sql =
                "{call dbo.sp_ActualizarEvento(?, ?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement cs = conexion.prepareCall(sql)) {

            cs.setInt(1, idUsuarioProceso);
            cs.setInt(2, evento.getIdEvento());
            cs.setString(3, evento.getNombre());

            cs.setTimestamp(
                    4,
                    Timestamp.valueOf(evento.getFechaInicio())
            );

            if (evento.getFechaFin() != null) {

                cs.setTimestamp(
                        5,
                        Timestamp.valueOf(evento.getFechaFin())
                );

            } else {

                cs.setNull(
                        5,
                        Types.TIMESTAMP
                );
            }

            establecerIp(cs, 6, ipOrigen);

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {
                    return mapearEvento(rs);
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_ActualizarEvento no devolvió el evento actualizado.");
    }

    public List<Evento> listarEventos()
            throws SQLException {

        List<Evento> eventos =
                new ArrayList<>();

        String sql =
                "SELECT "
                + "EV.IdEvento, "
                + "EV.IdLiga, "
                + "EV.IdEstado, "
                + "E.Codigo AS EstadoEvento, "
                + "EV.Nombre, "
                + "EV.FechaInicio, "
                + "EV.FechaFin "
                + "FROM dbo.Evento EV "
                + "INNER JOIN dbo.Estado E "
                + "ON E.IdEstado = EV.IdEstado "
                + "ORDER BY EV.FechaInicio";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql);
             ResultSet rs =
                     ps.executeQuery()) {

            while (rs.next()) {
                eventos.add(
                        mapearEvento(rs));
            }
        }

        return eventos;
    }

    public List<Evento> listarEventosPorLiga(
            int idLiga)
            throws SQLException {

        List<Evento> eventos =
                new ArrayList<>();

        String sql =
                "SELECT "
                + "EV.IdEvento, "
                + "EV.IdLiga, "
                + "EV.IdEstado, "
                + "E.Codigo AS EstadoEvento, "
                + "EV.Nombre, "
                + "EV.FechaInicio, "
                + "EV.FechaFin "
                + "FROM dbo.Evento EV "
                + "INNER JOIN dbo.Estado E "
                + "ON E.IdEstado = EV.IdEstado "
                + "WHERE EV.IdLiga = ? "
                + "ORDER BY EV.FechaInicio";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql)) {

            ps.setInt(1, idLiga);

            try (ResultSet rs =
                         ps.executeQuery()) {

                while (rs.next()) {
                    eventos.add(
                            mapearEvento(rs));
                }
            }
        }

        return eventos;
    }

    public Evento buscarPorId(
            int idEvento)
            throws SQLException {

        String sql =
                "SELECT "
                + "EV.IdEvento, "
                + "EV.IdLiga, "
                + "EV.IdEstado, "
                + "E.Codigo AS EstadoEvento, "
                + "EV.Nombre, "
                + "EV.FechaInicio, "
                + "EV.FechaFin "
                + "FROM dbo.Evento EV "
                + "INNER JOIN dbo.Estado E "
                + "ON E.IdEstado = EV.IdEstado "
                + "WHERE EV.IdEvento = ?";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql)) {

            ps.setInt(1, idEvento);

            try (ResultSet rs =
                         ps.executeQuery()) {

                if (rs.next()) {
                    return mapearEvento(rs);
                }
            }
        }

        return null;
    }

    private Evento mapearEvento(
            ResultSet rs)
            throws SQLException {

        Evento evento =
                new Evento();

        evento.setIdEvento(
                rs.getInt("IdEvento"));

        evento.setIdLiga(
                rs.getInt("IdLiga"));

        evento.setIdEstado(
                rs.getInt("IdEstado"));

        evento.setEstadoEvento(
                rs.getString("EstadoEvento"));

        evento.setNombre(
                rs.getString("Nombre"));

        Timestamp fechaInicio =
                rs.getTimestamp("FechaInicio");

        if (fechaInicio != null) {
            evento.setFechaInicio(
                    fechaInicio.toLocalDateTime());
        }

        Timestamp fechaFin =
                rs.getTimestamp("FechaFin");

        if (fechaFin != null) {
            evento.setFechaFin(
                    fechaFin.toLocalDateTime());
        }

        return evento;
    }

    private void establecerIp(
            CallableStatement cs,
            int parametro,
            String ipOrigen)
            throws SQLException {

        if (ipOrigen != null
                && !ipOrigen.trim().isEmpty()) {

            cs.setString(
                    parametro,
                    ipOrigen
            );

        } else {

            cs.setNull(
                    parametro,
                    Types.VARCHAR
            );
        }
    }
}