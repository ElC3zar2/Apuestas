/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.seguridad;
import org.mindrot.jbcrypt.BCrypt;
/**
 *
 * @author cesar
 */
public class EncriptadorContrasena {

    private EncriptadorContrasena() {
    }

    public static String encriptar(String contrasena) {
        return BCrypt.hashpw(
                contrasena,
                BCrypt.gensalt(12)
        );
    }

    public static boolean verificar(
            String contrasena,
            String hashGuardado) {

        return BCrypt.checkpw(
                contrasena,
                hashGuardado
        );
    }
}
