/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import com.apuestas.modelo.Participante;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
/**
 *
 * @author farfa
 */
public class ParticipanteDAO {

    public Participante crearParticipante(int idUsuarioProceso,
                                          Participante participante,
                                          String ipOrigen)
            throws SQLException {

        String sql = "{call dbo.sp_CrearParticipante(?, ?, ?, ?, ?, ?)}";

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

            if (ipOrigen != null && !ipOrigen.trim().isEmpty()) {
                cs.setString(6, ipOrigen);
            } else {
                cs.setNull(6, Types.VARCHAR);
            }

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {

                    Participante participanteCreado = new Participante();

                    participanteCreado.setIdParticipante(
                            rs.getInt("IdParticipante"));

                    participanteCreado.setIdDeporte(
                            rs.getInt("IdDeporte"));

                    int idPais = rs.getInt("IdPais");

                    if (rs.wasNull()) {
                        participanteCreado.setIdPais(null);
                    } else {
                        participanteCreado.setIdPais(idPais);
                    }

                    participanteCreado.setNombre(
                            rs.getString("Nombre"));

                    participanteCreado.setTipoParticipante(
                            rs.getString("TipoParticipante"));

                    participanteCreado.setActivo(
                            rs.getBoolean("Activo"));

                    return participanteCreado;
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_CrearParticipante no devolvió el participante creado.");
    }
}
