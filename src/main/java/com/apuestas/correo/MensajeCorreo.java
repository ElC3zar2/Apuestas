package com.apuestas.correo;

/** Mensaje inmutable; su representacion textual no revela destinatario ni contenido. */
public final class MensajeCorreo {
    private final String destinatario, asunto, texto, html;

    public MensajeCorreo(String destinatario, String asunto, String texto) {
        this(destinatario, asunto, texto, null);
    }

    public MensajeCorreo(String destinatario, String asunto, String texto, String html) {
        this.destinatario = ValidacionCorreo.direccion(destinatario);
        ValidacionCorreo.encabezado(asunto);
        if (asunto == null || asunto.trim().isEmpty()) {
            throw new IllegalArgumentException("Asunto requerido.");
        }
        if (texto == null || texto.trim().isEmpty() || (html != null && html.trim().isEmpty())) {
            throw new IllegalArgumentException("Contenido de correo invalido.");
        }
        this.asunto = asunto;
        this.texto = texto;
        this.html = html;
    }

    public String getDestinatario() { return destinatario; }
    public String getAsunto() { return asunto; }
    public String getTexto() { return texto; }
    public String getHtml() { return html; }
    @Override public String toString() { return "MensajeCorreo[contenido omitido]"; }
}
