package com.apuestas.correo;

import jakarta.mail.internet.AddressException;
import jakarta.mail.internet.InternetAddress;

/** Validaciones compartidas; los errores nunca contienen la entrada recibida. */
final class ValidacionCorreo {
    private ValidacionCorreo() { }

    static void encabezado(String valor) {
        if (valor != null && (valor.indexOf('\r') >= 0 || valor.indexOf('\n') >= 0
                || valor.indexOf('\0') >= 0)) {
            throw new IllegalArgumentException("Encabezado de correo invalido.");
        }
    }

    static String direccion(String valor) {
        encabezado(valor);
        if (valor == null || valor.trim().isEmpty()) {
            throw new IllegalArgumentException("Direccion de correo requerida.");
        }
        String direccion = valor.trim();
        try {
            InternetAddress address = new InternetAddress(direccion, true);
            address.validate();
            int arroba = direccion.lastIndexOf('@');
            if (address.isGroup() || address.getPersonal() != null
                    || !direccion.equals(address.getAddress())
                    || arroba <= 0 || arroba == direccion.length() - 1) {
                throw new AddressException();
            }
            return direccion;
        } catch (AddressException e) {
            throw new IllegalArgumentException("Direccion de correo invalida.");
        }
    }
}
