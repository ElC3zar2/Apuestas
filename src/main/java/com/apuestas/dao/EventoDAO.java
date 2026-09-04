/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import com.apuestas.modelo.Evento;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
/**
 *
 * @author farfa
 */
public class EventoDAO {

    public Evento crearEvento(int idUsuarioProceso,
                              Evento evento,
                              String ipOrigen)
            throws SQLException {

        String sql = "{call dbo.sp_CrearEvento(?, ?, ?, ?, ?, ?)}";

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
                cs.setNull(5, Types.TIMESTAMP);
            }

            if (ipOrigen != null && !ipOrigen.trim().isEmpty()) {
                cs.setString(6, ipOrigen);
            } else {
                cs.setNull(6, Types.VARCHAR);
            }

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {

                    Evento eventoCreado = new Evento();

                    eventoCreado.setIdEvento(
                            rs.getInt("IdEvento"));

                    eventoCreado.setIdLiga(
                            rs.getInt("IdLiga"));

                    eventoCreado.setIdEstado(
                            rs.getInt("IdEstado"));

                    eventoCreado.setEstadoEvento(
                            rs.getString("EstadoEvento"));

                    eventoCreado.setNombre(
                            rs.getString("Nombre"));

                    Timestamp fechaInicio =
                            rs.getTimestamp("FechaInicio");

                    if (fechaInicio != null) {
                        eventoCreado.setFechaInicio(
                                fechaInicio.toLocalDateTime());
                    }

                    Timestamp fechaFin =
                            rs.getTimestamp("FechaFin");

                    if (fechaFin != null) {
                        eventoCreado.setFechaFin(
                                fechaFin.toLocalDateTime());
                    }

                    return eventoCreado;
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_CrearEvento no devolvió el evento creado.");
    }
}