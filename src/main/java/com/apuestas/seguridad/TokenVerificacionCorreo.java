package com.apuestas.seguridad;

import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.Base64;

/** Token de 256 bits; SHA-256 hexadecimal compatible con CHAR(64) de SQL. */
public final class TokenVerificacionCorreo {
    private static final SecureRandom AZAR = new SecureRandom();
    private TokenVerificacionCorreo() { }

    public static String generar() {
        byte[] bytes = new byte[32];
        AZAR.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public static boolean esValido(String token) {
        if (token == null || token.length() != 43 || !token.matches("[A-Za-z0-9_-]{43}")) {
            return false;
        }
        try {
            byte[] bytes = Base64.getUrlDecoder().decode(token);
            return bytes.length == 32
                    && Base64.getUrlEncoder().withoutPadding().encodeToString(bytes).equals(token);
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    public static String hash(String token) {
        if (!esValido(token)) throw new IllegalArgumentException("Codigo de verificacion invalido.");
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
            char[] hex = new char[64];
            char[] alfabeto = "0123456789abcdef".toCharArray();
            for (int i = 0; i < digest.length; i++) {
                hex[i*2] = alfabeto[(digest[i] & 255) >>> 4];
                hex[i*2+1] = alfabeto[digest[i] & 15];
            }
            return new String(hex);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("No fue posible procesar el codigo de verificacion.");
        }
    }
}
