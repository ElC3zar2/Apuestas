/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.servicio;
import com.apuestas.dao.UsuarioDAO;
import com.apuestas.modelo.Usuario;
import com.apuestas.seguridad.EncriptadorContrasena;
import java.sql.SQLException;
/**
 *
 * @author cesar
 */
public class UsuarioServicio {

    private final UsuarioDAO usuarioDAO;

    public UsuarioServicio() {
        this.usuarioDAO = new UsuarioDAO();
    }

    public int registrarCliente(Usuario usuario) throws SQLException {

        if (usuario == null) {
            throw new IllegalArgumentException(
                    "El usuario es obligatorio."
            );
        }

        if (usuario.getNombre() == null
                || usuario.getNombre().trim().isEmpty()) {
            throw new IllegalArgumentException(
                    "El nombre es obligatorio."
            );
        }

        if (usuario.getApellido() == null
                || usuario.getApellido().trim().isEmpty()) {
            throw new IllegalArgumentException(
                    "El apellido es obligatorio."
            );
        }

        if (usuario.getCorreo() == null
                || usuario.getCorreo().trim().isEmpty()) {
            throw new IllegalArgumentException(
                    "El correo es obligatorio."
            );
        }

        if (usuario.getContrasena() == null
                || usuario.getContrasena().length() < 8) {
            throw new IllegalArgumentException(
                    "La contraseña debe tener al menos 8 caracteres."
            );
        }

        String hash =
                EncriptadorContrasena.encriptar(
                        usuario.getContrasena()
                );

        usuario.setContrasena(hash);

        return usuarioDAO.registrarCliente(usuario);
    }
}
