package com.apuestas.servicio;

import com.apuestas.correo.*;
import com.apuestas.dao.UsuarioDAO;
import com.apuestas.modelo.ResultadoTokenVerificacionCorreo;
import com.apuestas.seguridad.TokenVerificacionCorreo;
import java.sql.SQLException;
import java.util.*;
import java.util.function.Supplier;

/** Seguridad de correo separada del login y del transporte SMTP. */
public final class VerificacionCorreoServicio {
    private final UsuarioDAO usuarioDAO;
    private final Supplier<CorreoServicio> correo;

    public VerificacionCorreoServicio() {
        usuarioDAO = new UsuarioDAO();
        // Configurar SMTP solo al enviar: confirmar y GET no dependen del entorno SMTP.
        correo = () -> new CorreoSmtpServicio(ConfiguracionCorreo.desdeEntorno());
    }

    public VerificacionCorreoServicio(UsuarioDAO usuarioDAO, CorreoServicio correo) {
        this.usuarioDAO = Objects.requireNonNull(usuarioDAO);
        CorreoServicio transporte = Objects.requireNonNull(correo);
        this.correo = () -> transporte;
    }

    public void solicitar(int idUsuario, String correoSesion) throws SQLException, EnvioCorreoException {
        if (idUsuario <= 0 || !UsuarioServicio.correoSesionValido(correoSesion)) {
            throw new IllegalArgumentException("Identidad de sesion invalida.");
        }
        String destinatario = correoSesion.trim().toLowerCase(Locale.ROOT);
        String token = TokenVerificacionCorreo.generar();
        ResultadoTokenVerificacionCorreo resultado = usuarioDAO.crearTokenVerificacionCorreo(
                destinatario, TokenVerificacionCorreo.hash(token));
        if (resultado == null || (resultado.getIdUsuario() != null
                && resultado.getIdUsuario().intValue() != idUsuario)) {
            throw new IllegalStateException("Identidad de verificacion inconsistente.");
        }
        if (!resultado.isTokenCreado()) return;
        // La vigencia la decide SQL. No se construye un enlace GET ni se activa la cuenta.
        MensajeCorreo mensaje = new MensajeCorreo(destinatario, "Verifica tu correo",
                "Tu codigo de verificacion es:\n" + token
                + "\n\nUsa este codigo para confirmar tu correo. Si no lo solicitaste, ignora este mensaje.");
        correo.get().enviar(mensaje);
    }

    public void confirmar(String token) throws SQLException {
        usuarioDAO.verificarCorreoConToken(TokenVerificacionCorreo.hash(token));
    }
}
