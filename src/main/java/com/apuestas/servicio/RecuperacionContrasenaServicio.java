package com.apuestas.servicio;

import com.apuestas.correo.*;
import com.apuestas.dao.UsuarioDAO;
import com.apuestas.seguridad.EncriptadorContrasena;
import com.apuestas.seguridad.TokenSeguridad;
import java.nio.charset.StandardCharsets;
import java.sql.SQLException;
import java.util.Locale;
import java.util.Objects;
import java.util.function.Supplier;

public final class RecuperacionContrasenaServicio {
    private final UsuarioDAO dao;
    private final Supplier<CorreoServicio> correo;
    public RecuperacionContrasenaServicio() {
        dao = new UsuarioDAO();
        correo = () -> new CorreoSmtpServicio(ConfiguracionCorreo.desdeEntorno());
    }
    public RecuperacionContrasenaServicio(UsuarioDAO dao, CorreoServicio correo) {
        this.dao = Objects.requireNonNull(dao);
        CorreoServicio transporte = Objects.requireNonNull(correo);
        this.correo = () -> transporte;
    }
    public void solicitar(String direccion) throws SQLException, EnvioCorreoException {
        if (!UsuarioServicio.correoSesionValido(direccion)) throw new IllegalArgumentException("Correo invalido.");
        String normalizado = direccion.trim().toLowerCase(Locale.ROOT);
        String token = TokenSeguridad.generar();
        if (!dao.crearTokenRecuperacionContrasena(normalizado, TokenSeguridad.hash(token))) return;
        correo.get().enviar(new MensajeCorreo(normalizado, "Restablece tu contrasena",
                "Recibimos una solicitud para restablecer tu contrasena. Usa este codigo:\n"
                + token + "\n\nSi no lo solicitaste, ignora este mensaje."));
    }
    public static boolean datosValidos(String token, String nueva, String confirmacion) {
        return TokenSeguridad.esValido(token) && nueva != null && nueva.length() >= 8
                && nueva.length() <= 72 && !nueva.trim().isEmpty()
                && nueva.getBytes(StandardCharsets.UTF_8).length <= 72
                && nueva.equals(confirmacion);
    }
    public void restablecer(String token, String nueva, String confirmacion) throws SQLException {
        if (!datosValidos(token, nueva, confirmacion)) throw new IllegalArgumentException("Datos de restablecimiento invalidos.");
        String tokenHash = TokenSeguridad.hash(token);
        String bcrypt = EncriptadorContrasena.encriptar(nueva);
        dao.restablecerContrasenaConToken(tokenHash, bcrypt);
    }
}