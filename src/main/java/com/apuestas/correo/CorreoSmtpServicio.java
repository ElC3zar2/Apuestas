package com.apuestas.correo;

import jakarta.mail.*;
import jakarta.mail.internet.*;
import java.io.IOException;
import java.util.Objects;

/** Envio sin reintentos ni logs de mensajes, propiedades o credenciales. */
public final class CorreoSmtpServicio implements CorreoServicio {
    @FunctionalInterface
    public interface FabricaTransporte {
        Transport crear(Session session) throws MessagingException;
    }

    private final ConfiguracionCorreo configuracion;
    private final FabricaTransporte fabrica;

    public CorreoSmtpServicio(ConfiguracionCorreo configuracion) {
        this(configuracion, session -> session.getTransport("smtp"));
    }

    /** Permite verificar configuracion, MIME y cierre de recursos sin abrir red. */
    public CorreoSmtpServicio(ConfiguracionCorreo configuracion, FabricaTransporte fabrica) {
        this.configuracion = Objects.requireNonNull(configuracion);
        this.fabrica = Objects.requireNonNull(fabrica);
    }

    @Override
    public void enviar(MensajeCorreo mensaje) throws EnvioCorreoException {
        try {
            Objects.requireNonNull(mensaje);
            Session session = Session.getInstance(configuracion.propiedadesSmtp());
            session.setDebug(false);
            MimeMessage mime = new MimeMessage(session);
            InternetAddress from = new InternetAddress(configuracion.getRemitente(), true);
            if (!configuracion.getNombreRemitente().isEmpty()) {
                from.setPersonal(configuracion.getNombreRemitente(), "UTF-8");
            }
            mime.setFrom(from);
            mime.setRecipient(Message.RecipientType.TO,
                    new InternetAddress(mensaje.getDestinatario(), true));
            mime.setSubject(mensaje.getAsunto(), "UTF-8");
            if (mensaje.getHtml() == null) {
                mime.setText(mensaje.getTexto(), "UTF-8");
            } else {
                MimeMultipart alternativas = new MimeMultipart("alternative");
                MimeBodyPart texto = new MimeBodyPart();
                texto.setText(mensaje.getTexto(), "UTF-8");
                alternativas.addBodyPart(texto);
                MimeBodyPart html = new MimeBodyPart();
                html.setContent(mensaje.getHtml(), "text/html; charset=UTF-8");
                alternativas.addBodyPart(html);
                mime.setContent(alternativas);
            }
            mime.saveChanges();
            try (Transport transporte = fabrica.crear(session)) {
                transporte.connect(configuracion.getHost(), configuracion.getPuerto(),
                        configuracion.usuario(), configuracion.password());
                transporte.sendMessage(mime, mime.getAllRecipients());
            }
        } catch (MessagingException | IOException | RuntimeException e) {
            // Las excepciones del proveedor pueden incluir credenciales o contenido.
            throw new EnvioCorreoException();
        }
    }
}
