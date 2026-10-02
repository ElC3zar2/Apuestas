package com.apuestas.seguridad;

/** Fachada compatible: la criptografia comun vive en TokenSeguridad. */
public final class TokenVerificacionCorreo {
    private TokenVerificacionCorreo() { }
    public static String generar() { return TokenSeguridad.generar(); }
    public static boolean esValido(String token) { return TokenSeguridad.esValido(token); }
    public static String hash(String token) { return TokenSeguridad.hash(token); }
}