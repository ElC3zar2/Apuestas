/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import com.apuestas.modelo.Usuario;
import com.apuestas.modelo.UsuarioAutenticacion;
import com.apuestas.modelo.ResultadoIntentoLogin;
import java.sql.Timestamp;
import java.time.LocalDateTime;

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

    public UsuarioAutenticacion obtenerUsuarioAutenticacion(String correo)
            throws SQLException {
        try (Connection conexion = obtenerConexion();
             CallableStatement procedimiento = conexion.prepareCall(
                     "{call dbo.sp_ObtenerUsuarioAutenticacion(?)}")) {
            procedimiento.setString(1, correo);
            UsuarioAutenticacion usuario = null;
            try (ResultSet rs = ejecutarConsulta(procedimiento)) {
                if (rs.next()) {
                    usuario = new UsuarioAutenticacion(
                            enteroObligatorio(rs, "IdUsuario"),
                            textoObligatorio(rs, "Correo"),
                            textoObligatorio(rs, "Contrasena"),
                            booleanObligatorio(rs, "CorreoVerificado"),
                            enteroObligatorio(rs, "IntentosFallidos"),
                            fechaNullable(rs, "BloqueadoHasta"),
                            fechaNullable(rs, "UltimoAcceso"),
                            enteroObligatorio(rs, "IdRol"),
                            textoObligatorio(rs, "Rol"),
                            enteroObligatorio(rs, "IdEstado"),
                            textoObligatorio(rs, "EstadoUsuario"),
                            textoObligatorio(rs, "NombreEstadoUsuario"),
                            booleanObligatorio(rs, "BloqueoVigente"),
                            booleanObligatorio(rs, "PuedeIniciarSesion"));
                    if (rs.next()) {
                        throw new SQLException("Respuesta de autenticacion duplicada.");
                    }
                }
            }
            comprobarFin(procedimiento);
            return usuario;
        }
    }

    public ResultadoIntentoLogin registrarIntentoLogin(
            int idUsuario, boolean exitoso, String ipOrigen) throws SQLException {
        try (Connection conexion = obtenerConexion();
             CallableStatement procedimiento = conexion.prepareCall(
                     "{call dbo.sp_RegistrarIntentoLogin(?, ?, ?)}")) {
            procedimiento.setInt(1, idUsuario);
            procedimiento.setBoolean(2, exitoso);
            if (ipOrigen == null || ipOrigen.trim().isEmpty()) {
                procedimiento.setNull(3, Types.VARCHAR);
            } else {
                procedimiento.setString(3, ipOrigen.trim());
            }
            ResultadoIntentoLogin intento;
            try (ResultSet rs = ejecutarConsulta(procedimiento)) {
                if (!rs.next()) {
                    throw new SQLException("Falta el resultado del intento de login.");
                }
                intento = new ResultadoIntentoLogin(
                        enteroObligatorio(rs, "IdUsuario"),
                        enteroObligatorio(rs, "IntentosFallidos"),
                        fechaNullable(rs, "BloqueadoHasta"),
                        booleanObligatorio(rs, "BloqueoVigente"),
                        booleanObligatorio(rs, "AutenticacionPermitida"),
                        textoObligatorio(rs, "EstadoUsuario"));
                if (rs.next()) {
                    throw new SQLException("Respuesta del intento de login duplicada.");
                }
            }
            comprobarFin(procedimiento);
            return intento;
        }
    }

    protected Connection obtenerConexion() throws SQLException {
        return ConexionBD.obtenerConexion();
    }

    private ResultSet ejecutarConsulta(CallableStatement procedimiento) throws SQLException {
        boolean resultado = procedimiento.execute();
        while (!resultado && procedimiento.getUpdateCount() != -1) {
            resultado = procedimiento.getMoreResults();
        }
        if (!resultado) {
            throw new SQLException("El procedimiento no devolvio un resultado.");
        }
        return procedimiento.getResultSet();
    }

    private void comprobarFin(CallableStatement procedimiento) throws SQLException {
        boolean resultado = procedimiento.getMoreResults();
        while (resultado || procedimiento.getUpdateCount() != -1) {
            if (resultado) {
                throw new SQLException("El procedimiento devolvio resultados adicionales.");
            }
            resultado = procedimiento.getMoreResults();
        }
    }

    private int enteroObligatorio(ResultSet rs, String columna) throws SQLException {
        int valor = rs.getInt(columna);
        if (rs.wasNull()) {
            throw new SQLException("Campo obligatorio nulo: " + columna);
        }
        return valor;
    }

    private boolean booleanObligatorio(ResultSet rs, String columna) throws SQLException {
        boolean valor = rs.getBoolean(columna);
        if (rs.wasNull()) {
            throw new SQLException("Campo obligatorio nulo: " + columna);
        }
        return valor;
    }

    private String textoObligatorio(ResultSet rs, String columna) throws SQLException {
        String valor = rs.getString(columna);
        if (valor == null || valor.trim().isEmpty()) {
            throw new SQLException("Campo obligatorio vacio: " + columna);
        }
        return valor;
    }

    private LocalDateTime fechaNullable(ResultSet rs, String columna) throws SQLException {
        Timestamp valor = rs.getTimestamp(columna);
        return valor == null ? null : valor.toLocalDateTime();
    }
}