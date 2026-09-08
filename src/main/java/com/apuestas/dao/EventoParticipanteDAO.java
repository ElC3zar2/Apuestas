/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import com.apuestas.modelo.EventoParticipante;
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
public class EventoParticipanteDAO {

    public EventoParticipante agregarParticipanteEvento(
            int idUsuarioProceso,
            EventoParticipante eventoParticipante,
            String ipOrigen)
            throws SQLException {

        String sql =
                "{call dbo.sp_AgregarParticipanteEvento(?, ?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement cs = conexion.prepareCall(sql)) {

            cs.setInt(1, idUsuarioProceso);
            cs.setInt(2, eventoParticipante.getIdEvento());
            cs.setInt(3, eventoParticipante.getIdParticipante());
            cs.setInt(4, eventoParticipante.getOrdenParticipante());

            if (eventoParticipante.getEsLocal() != null) {
                cs.setBoolean(
                        5,
                        eventoParticipante.getEsLocal()
                );
            } else {
                cs.setNull(
                        5,
                        Types.BIT
                );
            }

            establecerIp(cs, 6, ipOrigen);

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {
                    return mapearEventoParticipante(rs);
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_AgregarParticipanteEvento "
                + "no devolvió la asociación creada.");
    }

    public List<EventoParticipante> listarPorEvento(
            int idEvento)
            throws SQLException {

        List<EventoParticipante> participantes =
                new ArrayList<>();

        String sql =
                "SELECT "
                + "IdEventoParticipante, "
                + "IdEvento, "
                + "IdParticipante, "
                + "OrdenParticipante, "
                + "EsLocal "
                + "FROM dbo.EventoParticipante "
                + "WHERE IdEvento = ? "
                + "ORDER BY OrdenParticipante";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql)) {

            ps.setInt(1, idEvento);

            try (ResultSet rs =
                         ps.executeQuery()) {

                while (rs.next()) {
                    participantes.add(
                            mapearEventoParticipante(rs));
                }
            }
        }

        return participantes;
    }

    public EventoParticipante buscarPorId(
            int idEventoParticipante)
            throws SQLException {

        String sql =
                "SELECT "
                + "IdEventoParticipante, "
                + "IdEvento, "
                + "IdParticipante, "
                + "OrdenParticipante, "
                + "EsLocal "
                + "FROM dbo.EventoParticipante "
                + "WHERE IdEventoParticipante = ?";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql)) {

            ps.setInt(
                    1,
                    idEventoParticipante
            );

            try (ResultSet rs =
                         ps.executeQuery()) {

                if (rs.next()) {
                    return mapearEventoParticipante(rs);
                }
            }
        }

        return null;
    }

    public boolean existeParticipanteEnEvento(
            int idEvento,
            int idParticipante)
            throws SQLException {

        String sql =
                "SELECT COUNT(*) "
                + "FROM dbo.EventoParticipante "
                + "WHERE IdEvento = ? "
                + "AND IdParticipante = ?";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql)) {

            ps.setInt(1, idEvento);
            ps.setInt(2, idParticipante);

            try (ResultSet rs =
                         ps.executeQuery()) {

                if (rs.next()) {
                    return rs.getInt(1) > 0;
                }
            }
        }

        return false;
    }

    private EventoParticipante mapearEventoParticipante(
            ResultSet rs)
            throws SQLException {

        EventoParticipante relacion =
                new EventoParticipante();

        relacion.setIdEventoParticipante(
                rs.getInt("IdEventoParticipante"));

        relacion.setIdEvento(
                rs.getInt("IdEvento"));

        relacion.setIdParticipante(
                rs.getInt("IdParticipante"));

        relacion.setOrdenParticipante(
                rs.getInt("OrdenParticipante"));

        boolean esLocal =
                rs.getBoolean("EsLocal");

        if (rs.wasNull()) {
            relacion.setEsLocal(null);
        } else {
            relacion.setEsLocal(esLocal);
        }

        return relacion;
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