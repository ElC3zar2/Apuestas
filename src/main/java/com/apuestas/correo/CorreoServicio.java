package com.apuestas.correo;

/** Puerto reutilizable por servicios de negocio; sustituible por un fake sin red. */
@FunctionalInterface
public interface CorreoServicio {
    void enviar(MensajeCorreo mensaje) throws EnvioCorreoException;
}
