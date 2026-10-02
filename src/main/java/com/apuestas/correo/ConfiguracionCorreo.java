package com.apuestas.correo;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.Map;
import java.util.Objects;
import java.util.Properties;

/** Configuracion externa independiente de ConexionBD. No abre conexiones. */
public final class ConfiguracionCorreo {
    public enum Seguridad { STARTTLS, SSL }

    private final String host, usuario, password, remitente, nombreRemitente, urlPublica;
    private final int puerto, timeoutConexion, timeoutLectura, timeoutEscritura;
    private final Seguridad seguridad;

    public static ConfiguracionCorreo desdeEntorno() {
        return desdeVariables(System.getenv());
    }

    /** Punto de inyeccion para configuracion externa y pruebas sin secretos reales. */
    public static ConfiguracionCorreo desdeVariables(Map<String,String> variables) {
        return new ConfiguracionCorreo(Objects.requireNonNull(variables));
    }

    private ConfiguracionCorreo(Map<String,String> variables) {
        host = requerido(variables, "APUESTAS_MAIL_HOST");
        if (!host.matches("[A-Za-z0-9][A-Za-z0-9.-]*|\\[[0-9a-fA-F:]+\\]")) {
            throw new IllegalArgumentException("Host SMTP invalido.");
        }
        puerto = numero(variables, "APUESTAS_MAIL_PORT", null, 65535);
        String modo = requerido(variables, "APUESTAS_MAIL_SECURITY");
        try { seguridad = Seguridad.valueOf(modo); }
        catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Modo de seguridad SMTP invalido.");
        }
        usuario = opcional(variables.get("APUESTAS_MAIL_USERNAME"));
        String clave = variables.get("APUESTAS_MAIL_PASSWORD");
        password = clave == null || clave.isEmpty() ? null : clave;
        if ((usuario == null) != (password == null)) {
            throw new IllegalArgumentException("Autenticacion SMTP incompleta.");
        }
        remitente = ValidacionCorreo.direccion(variables.get("APUESTAS_MAIL_FROM"));
        String nombre = opcional(variables.get("APUESTAS_MAIL_FROM_NAME"));
        nombreRemitente = nombre == null ? "" : nombre;
        timeoutConexion = numero(variables, "APUESTAS_MAIL_CONNECT_TIMEOUT_MS", 10000, Integer.MAX_VALUE);
        timeoutLectura = numero(variables, "APUESTAS_MAIL_READ_TIMEOUT_MS", 10000, Integer.MAX_VALUE);
        timeoutEscritura = numero(variables, "APUESTAS_MAIL_WRITE_TIMEOUT_MS", 10000, Integer.MAX_VALUE);
        urlPublica = url(requerido(variables, "APUESTAS_PUBLIC_BASE_URL"));
    }

    private static String opcional(String valor) {
        ValidacionCorreo.encabezado(valor);
        return valor == null || valor.trim().isEmpty() ? null : valor.trim();
    }

    private static String requerido(Map<String,String> variables, String clave) {
        String valor = opcional(variables.get(clave));
        if (valor == null) throw new IllegalArgumentException("Falta configuracion: " + clave);
        return valor;
    }

    private static int numero(Map<String,String> variables, String clave, Integer defecto, int maximo) {
        String texto = variables.get(clave);
        if (texto == null && defecto != null) return defecto;
        texto = requerido(variables, clave);
        try {
            if (!texto.matches("[0-9]+")) throw new NumberFormatException();
            int valor = Integer.parseInt(texto);
            if (valor <= 0 || valor > maximo) throw new NumberFormatException();
            return valor;
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Valor numerico invalido: " + clave);
        }
    }

    private static String url(String valor) {
        try {
            URI uri = new URI(valor);
            String esquema = uri.getScheme();
            String host = uri.getHost();
            boolean local = "localhost".equalsIgnoreCase(host) || "127.0.0.1".equals(host)
                    || "[::1]".equals(host) || "::1".equals(host);
            if (!uri.isAbsolute() || host == null || uri.getRawUserInfo() != null
                    || uri.getRawQuery() != null || uri.getRawFragment() != null
                    || uri.getPort() == 0 || uri.getPort() > 65535
                    || !("https".equalsIgnoreCase(esquema)
                         || ("http".equalsIgnoreCase(esquema) && local))
                    || uri.getRawPath().contains("//") || !uri.normalize().equals(uri)) {
                throw new URISyntaxException("", "");
            }
            String normalizada = uri.toASCIIString();
            while (normalizada.endsWith("/")) normalizada = normalizada.substring(0, normalizada.length()-1);
            return normalizada;
        } catch (URISyntaxException e) {
            throw new IllegalArgumentException("URL publica invalida.");
        }
    }

    /** Copia nueva; no incluye usuario ni password y no permite sobrescribir opciones seguras. */
    public Properties propiedadesSmtp() {
        Properties p = new Properties();
        p.setProperty("mail.transport.protocol", "smtp");
        p.setProperty("mail.smtp.host", host);
        p.setProperty("mail.smtp.port", Integer.toString(puerto));
        p.setProperty("mail.smtp.auth", Boolean.toString(tieneAutenticacion()));
        p.setProperty("mail.smtp.connectiontimeout", Integer.toString(timeoutConexion));
        p.setProperty("mail.smtp.timeout", Integer.toString(timeoutLectura));
        p.setProperty("mail.smtp.writetimeout", Integer.toString(timeoutEscritura));
        p.setProperty("mail.smtp.starttls.enable", Boolean.toString(seguridad == Seguridad.STARTTLS));
        p.setProperty("mail.smtp.starttls.required", Boolean.toString(seguridad == Seguridad.STARTTLS));
        p.setProperty("mail.smtp.ssl.enable", Boolean.toString(seguridad == Seguridad.SSL));
        p.setProperty("mail.smtp.ssl.checkserveridentity", "true");
        p.setProperty("mail.debug", "false");
        p.setProperty("mail.debug.auth", "false");
        return p;
    }

    public String getHost() { return host; }
    public int getPuerto() { return puerto; }
    public String getRemitente() { return remitente; }
    public String getNombreRemitente() { return nombreRemitente; }
    public String getUrlPublica() { return urlPublica; }
    public Seguridad getSeguridad() { return seguridad; }
    public boolean tieneAutenticacion() { return usuario != null; }
    String usuario() { return usuario; }
    String password() { return password; }

    @Override public String toString() { return "ConfiguracionCorreo[datos omitidos]"; }
}
