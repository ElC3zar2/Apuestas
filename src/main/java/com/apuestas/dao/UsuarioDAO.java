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

        String sql = "{call sp_RegistrarUsuarioCliente(?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement procedimiento = conexion.prepareCall(sql)) {

            procedimiento.setString(1, usuario.getNombre());
            procedimiento.setString(2, usuario.getApellido());
            procedimiento.setString(3, usuario.getCorreo());
            procedimiento.setString(4, usuario.getContrasena());

            if (usuario.getFechaNacimiento() != null) {
                procedimiento.setDate(
                        5,
                        Date.valueOf(usuario.getFechaNacimiento())
                );
            } else {
                procedimiento.setNull(5, Types.DATE);
            }

            boolean tieneResultado = procedimiento.execute();

            if (tieneResultado) {

                try (ResultSet resultado = procedimiento.getResultSet()) {

                    if (resultado.next()) {
                        int idUsuario = resultado.getInt("IdUsuario");
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
