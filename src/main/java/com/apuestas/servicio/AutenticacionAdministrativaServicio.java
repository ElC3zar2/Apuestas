package com.apuestas.servicio;

import com.apuestas.dao.UsuarioDAO;
import com.apuestas.modelo.*;
import com.apuestas.seguridad.EncriptadorContrasena;
import com.apuestas.seguridad.SesionAdministrativa;
import java.sql.SQLException;
import java.util.Locale;

/** Autenticacion administrativa; los permisos por operacion siguen en SQL. */
public class AutenticacionAdministrativaServicio {
    private final UsuarioDAO usuarioDAO;
    private static final String HASH_FICTICIO =
            "$2a$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW";
    public AutenticacionAdministrativaServicio() { this(new UsuarioDAO()); }
    public AutenticacionAdministrativaServicio(UsuarioDAO dao) {
        usuarioDAO = java.util.Objects.requireNonNull(dao);
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
        if (contrasena == null || contrasena.trim().isEmpty()
                || contrasena.getBytes(java.nio.charset.StandardCharsets.UTF_8).length > 72) {
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
                || !UsuarioServicio.correoSesionValido(usuario.getCorreo())
                || !correoNormalizado.equals(usuario.getCorreo().trim().toLowerCase(Locale.ROOT))
                || (usuario.isBloqueoVigente() && usuario.getBloqueadoHasta() == null)) {
            throw new IllegalStateException("Datos de autenticacion inconsistentes.");
        }
        if (!SesionAdministrativa.rolPermitido(usuario.getRol())
                || !SesionAdministrativa.estadoPermitido(usuario.getEstadoUsuario())) {
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
                || !SesionAdministrativa.estadoPermitido(intento.getEstadoUsuario())) {
            return ResultadoLogin.rechazado();
        }
        return ResultadoLogin.autenticado(usuario.getIdUsuario(), correoNormalizado,
                usuario.getIdRol(), usuario.getRol(), intento.getEstadoUsuario(),
                usuario.isCorreoVerificado());
    }


}