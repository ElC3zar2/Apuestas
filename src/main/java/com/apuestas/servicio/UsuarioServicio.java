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

    public int registrarCliente(Usuario usuario)
            throws SQLException {

        if (usuario == null) {
            throw new IllegalArgumentException(
                    "El usuario es obligatorio."
            );
        }

        /*
         * NOMBRE
         */
        if (usuario.getNombre() == null
                || usuario.getNombre().trim().isEmpty()) {

            throw new IllegalArgumentException(
                    "El nombre es obligatorio."
            );
        }

        /*
         * APELLIDO
         */
        if (usuario.getApellido() == null
                || usuario.getApellido().trim().isEmpty()) {

            throw new IllegalArgumentException(
                    "El apellido es obligatorio."
            );
        }

        /*
         * CORREO
         */
        if (usuario.getCorreo() == null
                || usuario.getCorreo().trim().isEmpty()) {

            throw new IllegalArgumentException(
                    "El correo es obligatorio."
            );
        }

        /*
         * CONTRASEÑA
         */
        if (usuario.getContrasena() == null
                || usuario.getContrasena().length() < 8) {

            throw new IllegalArgumentException(
                    "La contraseña debe tener al menos 8 caracteres."
            );
        }

        /*
         * FECHA DE NACIMIENTO
         */
        if (usuario.getFechaNacimiento() == null) {

            throw new IllegalArgumentException(
                    "La fecha de nacimiento es obligatoria."
            );
        }

        /*
         * GÉNERO
         */
        if (usuario.getGenero() == null
                || (!usuario.getGenero().equalsIgnoreCase("M")
                && !usuario.getGenero().equalsIgnoreCase("F"))) {

            throw new IllegalArgumentException(
                    "El género seleccionado no es válido."
            );
        }

        /*
         * TELÉFONO
         *
         * La base permite VARCHAR(25).
         * Se permiten números, espacios,
         * +, -, paréntesis.
         */
        if (usuario.getTelefono() == null
                || usuario.getTelefono().trim().isEmpty()) {

            throw new IllegalArgumentException(
                    "El teléfono es obligatorio."
            );
        }

        String telefono =
                usuario.getTelefono().trim();

        if (telefono.length() > 25) {

            throw new IllegalArgumentException(
                    "El teléfono no puede superar los 25 caracteres."
            );
        }

        if (!telefono.matches("[0-9+()\\-\\s]+")) {

            throw new IllegalArgumentException(
                    "El teléfono contiene caracteres no válidos."
            );
        }

        usuario.setTelefono(telefono);

        /*
         * TIPO DE DOCUMENTO
         */
        if (usuario.getTipoDocumento() == null
                || usuario.getTipoDocumento()
                        .trim()
                        .isEmpty()) {

            throw new IllegalArgumentException(
                    "El tipo de documento es obligatorio."
            );
        }

        String tipoDocumento =
                usuario.getTipoDocumento()
                        .trim()
                        .toUpperCase();

        if (!tipoDocumento.equals("DPI")
                && !tipoDocumento.equals("PASAPORTE")
                && !tipoDocumento.equals("OTRO")) {

            throw new IllegalArgumentException(
                    "El tipo de documento no es válido."
            );
        }

        usuario.setTipoDocumento(tipoDocumento);

        /*
         * NÚMERO DE DOCUMENTO
         */
        if (usuario.getNumeroDocumento() == null
                || usuario.getNumeroDocumento()
                        .trim()
                        .isEmpty()) {

            throw new IllegalArgumentException(
                    "El número de documento es obligatorio."
            );
        }

        String numeroDocumento =
                usuario.getNumeroDocumento().trim();

        if (numeroDocumento.length() > 50) {

            throw new IllegalArgumentException(
                    "El número de documento no puede superar los 50 caracteres."
            );
        }

        /*
         * DPI:
         * exactamente 13 números.
         *
         * PASAPORTE y OTRO:
         * formato variable dependiendo del país.
         */
        if (tipoDocumento.equals("DPI")) {

            if (!numeroDocumento.matches("\\d{13}")) {

                throw new IllegalArgumentException(
                        "El DPI debe contener exactamente 13 dígitos."
                );
            }
        }

        usuario.setNumeroDocumento(numeroDocumento);

        /*
         * PAÍS
         */
        if (usuario.getIdPais() <= 0) {

            throw new IllegalArgumentException(
                    "Debe seleccionar un país."
            );
        }

        /*
         * DIRECCIÓN
         */
        if (usuario.getDireccion() == null
                || usuario.getDireccion()
                        .trim()
                        .isEmpty()) {

            throw new IllegalArgumentException(
                    "La dirección es obligatoria."
            );
        }

        if (usuario.getDireccion()
                .trim()
                .length() > 250) {

            throw new IllegalArgumentException(
                    "La dirección no puede superar los 250 caracteres."
            );
        }

        /*
         * CIUDAD EXTERIOR
         */
        if (usuario.getCiudadExterior() != null) {

            String ciudad =
                    usuario.getCiudadExterior()
                            .trim();

            if (ciudad.length() > 120) {

                throw new IllegalArgumentException(
                        "La ciudad exterior no puede superar los 120 caracteres."
                );
            }

            if (ciudad.isEmpty()) {

                usuario.setCiudadExterior(null);

            } else {

                usuario.setCiudadExterior(ciudad);
            }
        }

        /*
         * NORMALIZACIÓN DE DATOS
         */
        usuario.setNombre(
                usuario.getNombre().trim()
        );

        usuario.setApellido(
                usuario.getApellido().trim()
        );

        usuario.setCorreo(
                usuario.getCorreo()
                        .trim()
                        .toLowerCase()
        );

        usuario.setGenero(
                usuario.getGenero()
                        .trim()
                        .toUpperCase()
        );

        usuario.setDireccion(
                usuario.getDireccion().trim()
        );

        /*
         * ENCRIPTACIÓN DE CONTRASEÑA
         */
        String hash =
                EncriptadorContrasena.encriptar(
                        usuario.getContrasena()
                );

        usuario.setContrasena(hash);

        /*
         * REGISTRO EN AZURE SQL
         */
        return usuarioDAO.registrarCliente(
                usuario
        );
    }
}