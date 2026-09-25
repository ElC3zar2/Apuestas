/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.servicio;
import com.apuestas.dao.UsuarioDAO;
import com.apuestas.modelo.Usuario;
import com.apuestas.modelo.UsuarioAutenticacion;
import com.apuestas.modelo.ResultadoIntentoLogin;
import com.apuestas.modelo.ResultadoLogin;
import java.util.Locale;
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
        * El teléfono debe llegar normalizado desde
        * RegistroUsuarioServlet con el formato:
        *
        * +CodigoPaisNumeroLocal
        *
        * Ejemplo:
        * +50255555555
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

       if (!telefono.matches("\\+[0-9]+")) {

           throw new IllegalArgumentException(
                   "El teléfono debe utilizar un formato internacional válido."
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

    public UsuarioServicio(UsuarioDAO usuarioDAO) {
        this.usuarioDAO = java.util.Objects.requireNonNull(usuarioDAO);
    }

    public ResultadoLogin autenticar(String correo, String contrasena, String ipOrigen)
            throws SQLException {
        if (correo == null || correo.trim().isEmpty()) {
            throw new IllegalArgumentException("El correo es obligatorio.");
        }
        String correoNormalizado = correo.trim().toLowerCase(Locale.ROOT);
        if (correoNormalizado.length() > 150
                || !correoNormalizado.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")) {
            throw new IllegalArgumentException("El correo no tiene un formato o longitud válido.");
        }
        if (contrasena == null || contrasena.isEmpty()) {
            throw new IllegalArgumentException("La contraseña es obligatoria.");
        }

        UsuarioAutenticacion usuario =
                usuarioDAO.obtenerUsuarioAutenticacion(correoNormalizado);
        if (usuario == null) {
            // Hash ficticio fijo de coste 12: no generar uno nuevo por solicitud.
            EncriptadorContrasena.verificar(contrasena, HASH_FICTICIO);
            return ResultadoLogin.rechazado();
        }
        if (usuario.getIdUsuario() <= 0 || usuario.getIdRol() <= 0
                || usuario.getIdEstado() <= 0 || usuario.getIntentosFallidos() < 0
                || usuario.getCorreo() == null || usuario.getCorreo().trim().isEmpty()) {
            throw new IllegalStateException("Datos de autenticacion inconsistentes.");
        }
        if (!"USUARIO".equals(usuario.getRol())
                || !estadoAdmitido(usuario.getEstadoUsuario())) {
            return ResultadoLogin.rechazado();
        }

        String hash = usuario.getHashContrasena();
        if (hash == null || !hash.matches(
                "^\\$2(?:a)?\\$(?:0[4-9]|[12][0-9]|30)\\$[./A-Za-z0-9]{53}$")) {
            throw new IllegalStateException("Hash de autenticacion invalido.");
        }
        final boolean coincide;
        try {
            coincide = EncriptadorContrasena.verificar(contrasena, hash);
        } catch (RuntimeException e) {
            throw new IllegalStateException("No fue posible verificar el hash.");
        }

        ResultadoIntentoLogin intento = usuarioDAO.registrarIntentoLogin(
                usuario.getIdUsuario(), coincide, ipOrigen);
        if (intento == null || intento.getIdUsuario() != usuario.getIdUsuario()
                || intento.getIntentosFallidos() < 0
                || intento.getEstadoUsuario() == null
                || intento.getEstadoUsuario().trim().isEmpty()
                || (intento.isBloqueoVigente() && intento.getBloqueadoHasta() == null)
                || (intento.isAutenticacionPermitida()
                    && (!coincide || intento.isBloqueoVigente()
                        || intento.getIntentosFallidos() != 0
                        || intento.getBloqueadoHasta() != null))) {
            throw new IllegalStateException("Resultado del intento de login inconsistente.");
        }
        // Una consulta inicial bloqueada o no habilitada tampoco concede una sesion.
        if (!coincide || usuario.isBloqueoVigente() || !usuario.isPuedeIniciarSesion()
                || !intento.isAutenticacionPermitida() || intento.isBloqueoVigente()
                || !estadoAdmitido(intento.getEstadoUsuario())) {
            return ResultadoLogin.rechazado();
        }
        return ResultadoLogin.autenticado(usuario.getIdUsuario(), usuario.getCorreo(),
                usuario.getIdRol(), usuario.getRol(), intento.getEstadoUsuario(),
                usuario.isCorreoVerificado());
    }

    private static boolean estadoAdmitido(String estado) {
        return "PENDIENTE".equals(estado) || "ACTIVO".equals(estado);
    }

    private static final String HASH_FICTICIO =
            "$2a$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW";
}