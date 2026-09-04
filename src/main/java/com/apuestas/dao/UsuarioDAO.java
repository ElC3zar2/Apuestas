/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import com.apuestas.modelo.Usuario;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.Date;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
/**
 *
 * @author cesar
 */
public class UsuarioDAO {

    public int registrarCliente(Usuario usuario) throws SQLException {

        String sql =
                "{call dbo.sp_RegistrarUsuarioCliente("
                + "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement procedimiento = conexion.prepareCall(sql)) {

            procedimiento.setString(1, usuario.getNombre());
            procedimiento.setString(2, usuario.getApellido());
            procedimiento.setString(3, usuario.getCorreo());
            procedimiento.setString(4, usuario.getContrasena());

            procedimiento.setDate(
                    5,
                    Date.valueOf(usuario.getFechaNacimiento())
            );

            procedimiento.setString(6, usuario.getGenero());
            procedimiento.setString(7, usuario.getTelefono());
            procedimiento.setString(8, usuario.getTipoDocumento());
            procedimiento.setString(9, usuario.getNumeroDocumento());
            procedimiento.setInt(10, usuario.getIdPais());

            if (usuario.getIdMunicipio() != null) {
                procedimiento.setInt(11, usuario.getIdMunicipio());
            } else {
                procedimiento.setNull(11, Types.INTEGER);
            }

            if (usuario.getCiudadExterior() != null
                    && !usuario.getCiudadExterior().trim().isEmpty()) {

                procedimiento.setString(
                        12,
                        usuario.getCiudadExterior()
                );

            } else {
                procedimiento.setNull(12, Types.VARCHAR);
            }

            procedimiento.setString(
                    13,
                    usuario.getDireccion()
            );

            boolean tieneResultado = procedimiento.execute();

            if (tieneResultado) {

                try (ResultSet resultado =
                             procedimiento.getResultSet()) {

                    if (resultado.next()) {

                        int idUsuario =
                                resultado.getInt("IdUsuario");

                        usuario.setIdUsuario(idUsuario);

                        return idUsuario;
                    }
                }
            }

            throw new SQLException(
                    "El procedimiento no devolvió el usuario registrado."
            );
        }
    }
}