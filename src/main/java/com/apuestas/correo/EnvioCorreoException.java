package com.apuestas.correo;

/** Error publico seguro. No conserva respuestas SMTP que puedan contener secretos. */
public final class EnvioCorreoException extends Exception {
    private static final long serialVersionUID = 1L;

    public EnvioCorreoException() {
        super("No fue posible completar el envio de correo.");
    }
}
