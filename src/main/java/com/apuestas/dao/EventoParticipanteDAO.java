/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import com.apuestas.modelo.EventoParticipante;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
/**
 *
 * @author farfa
 */
public class EventoParticipanteDAO {

    public EventoParticipante agregarParticipanteEvento(
            int idUsuarioProceso,
            EventoParticipante eventoParticipante,
            String ipOrigen) throws SQLException {

        String sql =
                "{call dbo.sp_AgregarParticipanteEvento(?, ?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement cs = conexion.prepareCall(sql)) {

            cs.setInt(1, idUsuarioProceso);
            cs.setInt(2, eventoParticipante.getIdEvento());
            cs.setInt(3, eventoParticipante.getIdParticipante());
            cs.setInt(4, eventoParticipante.getOrdenParticipante());

            if (eventoParticipante.getEsLocal() != null) {
                cs.setBoolean(5, eventoParticipante.getEsLocal());
            } else {
                cs.setNull(5, Types.BIT);
            }

            if (ipOrigen != null && !ipOrigen.trim().isEmpty()) {
                cs.setString(6, ipOrigen);
            } else {
                cs.setNull(6, Types.VARCHAR);
            }

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {

                    EventoParticipante creado =
                            new EventoParticipante();

                    creado.setIdEventoParticipante(
                            rs.getInt("IdEventoParticipante"));

                    creado.setIdEvento(
                            rs.getInt("IdEvento"));

                    creado.setIdParticipante(
                            rs.getInt("IdParticipante"));

                    creado.setOrdenParticipante(
                            rs.getInt("OrdenParticipante"));

                    boolean esLocal =
                            rs.getBoolean("EsLocal");

                    if (rs.wasNull()) {
                        creado.setEsLocal(null);
                    } else {
                        creado.setEsLocal(esLocal);
                    }

                    return creado;
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_AgregarParticipanteEvento no devolvió la asociación creada.");
    }
}