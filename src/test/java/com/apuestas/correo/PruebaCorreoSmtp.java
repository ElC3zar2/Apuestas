package com.apuestas.correo;

import jakarta.mail.*;
import jakarta.mail.internet.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Prueba manual sin sockets: todo envio utiliza Transport simulado. */
public class PruebaCorreoSmtp {
    private static int casos;
    private static void exigir(boolean valor, String mensaje) {
        if (!valor) throw new AssertionError(mensaje);
    }
    private static Map<String,String> base() {
        Map<String,String> v = new HashMap<>();
        v.put("APUESTAS_MAIL_HOST", "smtp.example.invalid");
        v.put("APUESTAS_MAIL_PORT", "587");
        v.put("APUESTAS_MAIL_FROM", "seguridad@example.invalid");
        v.put("APUESTAS_MAIL_FROM_NAME", "Plataforma áñ");
        v.put("APUESTAS_MAIL_SECURITY", "STARTTLS");
        v.put("APUESTAS_PUBLIC_BASE_URL", "https://example.invalid/apuestas/");
        return v;
    }
    private static void invalida(String clave, String valor) {
        Map<String,String> v = base();
        if (valor == null) v.remove(clave); else v.put(clave,valor);
        try { ConfiguracionCorreo.desdeVariables(v); throw new AssertionError("Configuracion aceptada: " + clave); }
        catch (IllegalArgumentException esperado) { exigir(esperado.getCause() == null,"Sin causa externa"); casos++; }
    }
    private static void mensajeInvalido(String destino, String asunto, String texto, String html) {
        try { new MensajeCorreo(destino,asunto,texto,html); throw new AssertionError("Mensaje aceptado"); }
        catch (IllegalArgumentException esperado) { exigir(esperado.getCause() == null,"Sin entrada en causa"); casos++; }
    }
    private static final class TransporteSimulado extends Transport {
        final Session recibida;
        int conexiones, envios, cierres, puerto;
        String host, usuario, password;
        MimeMessage mensaje;
        Address[] destinos;
        String fallo;
        TransporteSimulado(Session session) { super(session,null); recibida=session; }
        @Override public synchronized void connect(String host, int puerto, String usuario, String password)
                throws MessagingException {
            conexiones++; this.host=host; this.puerto=puerto; this.usuario=usuario; this.password=password;
            if ("conexion".equals(fallo)) throw new MessagingException("INTERNO " + password);
        }
        @Override public void sendMessage(Message mensaje, Address[] destinos) throws MessagingException {
            envios++; this.mensaje=(MimeMessage)mensaje; this.destinos=destinos;
            if ("envio".equals(fallo)) throw new MessagingException("INTERNO " + password);
            if ("runtime".equals(fallo)) throw new IllegalStateException("INTERNO " + password);
        }
        @Override public synchronized void close() throws MessagingException {
            cierres++;
            if ("cierre".equals(fallo)) throw new MessagingException("INTERNO " + password);
        }
    }
    private static final class Fabrica implements CorreoSmtpServicio.FabricaTransporte {
        TransporteSimulado transporte;
        String fallo;
        int creaciones;
        @Override public Transport crear(Session session) throws MessagingException {
            creaciones++;
            if ("fabrica".equals(fallo)) throw new MessagingException("INTERNO");
            transporte=new TransporteSimulado(session);
            transporte.fallo=fallo;
            return transporte;
        }
    }
    private static void configuracion() {
        for (String clave : Arrays.asList("APUESTAS_MAIL_HOST","APUESTAS_MAIL_PORT",
                "APUESTAS_MAIL_FROM","APUESTAS_MAIL_SECURITY","APUESTAS_PUBLIC_BASE_URL")) {
            invalida(clave,null); invalida(clave,""); invalida(clave," ");
        }
        for (String host : Arrays.asList("smtp host","host\r\n","https://smtp.example.invalid","host:25")) {
            invalida("APUESTAS_MAIL_HOST",host);
        }
        for (String puerto : Arrays.asList("abc","0","-1","65536","999999999999","1.5","+25")) {
            invalida("APUESTAS_MAIL_PORT",puerto);
        }
        for (String modo : Arrays.asList("NINGUNO","TLS","starttls","SSL\n")) {
            invalida("APUESTAS_MAIL_SECURITY",modo);
        }
        for (String correo : Arrays.asList("abc","a@@b.test","a@","a@b.test,b@c.test","a@b.test\r\nBcc: x@y.test")) {
            invalida("APUESTAS_MAIL_FROM",correo);
        }
        invalida("APUESTAS_MAIL_FROM_NAME","Nombre\r\nBcc: x@y.test");
        invalida("APUESTAS_MAIL_FROM_NAME","Nombre\0");
        for (String url : Arrays.asList("/relativa","http://example.invalid","ftp://example.invalid",
                "https://user:clave@example.invalid","https://example.invalid/?q=1",
                "https://example.invalid/#fragmento","https://example.invalid:0",
                "https://example.invalid:65536","https://example.invalid/a/../b",
                "https://example.invalid/a//b","https://","http://localhost.example.invalid",
                "http://127.0.0.1.example.invalid","https://example.invalid\r\n")) {
            invalida("APUESTAS_PUBLIC_BASE_URL",url);
        }
        for (String clave : Arrays.asList("APUESTAS_MAIL_CONNECT_TIMEOUT_MS",
                "APUESTAS_MAIL_READ_TIMEOUT_MS","APUESTAS_MAIL_WRITE_TIMEOUT_MS")) {
            for (String valor : Arrays.asList("0","-1","abc","","2147483648")) invalida(clave,valor);
        }
        Map<String,String> v=base(); v.put("APUESTAS_MAIL_USERNAME","usuario-prueba");
        try { ConfiguracionCorreo.desdeVariables(v); throw new AssertionError("Falta password"); }
        catch (IllegalArgumentException esperado) { casos++; }
        v=base(); v.put("APUESTAS_MAIL_PASSWORD",UUID.randomUUID().toString());
        try { ConfiguracionCorreo.desdeVariables(v); throw new AssertionError("Falta username"); }
        catch (IllegalArgumentException esperado) { casos++; }
        for (String url : Arrays.asList("https://example.invalid","https://example.invalid/app/",
                "http://localhost:8084/app/","http://127.0.0.1:8084/","http://[::1]:8084/")) {
            v=base(); v.put("APUESTAS_PUBLIC_BASE_URL",url);
            ConfiguracionCorreo c=ConfiguracionCorreo.desdeVariables(v);
            exigir(!c.getUrlPublica().endsWith("/"),"Normalizar slash");
            casos++;
        }
        for (String modo : Arrays.asList("STARTTLS","SSL")) {
            v=base(); v.put("APUESTAS_MAIL_SECURITY",modo);
            v.put("APUESTAS_MAIL_PORT",modo.equals("SSL") ? "465" : "587");
            ConfiguracionCorreo c=ConfiguracionCorreo.desdeVariables(v);
            Properties p=c.propiedadesSmtp();
            exigir(p.getProperty("mail.smtp.starttls.enable").equals(Boolean.toString(modo.equals("STARTTLS"))),"STARTTLS");
            exigir(p.getProperty("mail.smtp.starttls.required").equals(Boolean.toString(modo.equals("STARTTLS"))),"TLS requerido");
            exigir(p.getProperty("mail.smtp.ssl.enable").equals(Boolean.toString(modo.equals("SSL"))),"SSL");
            exigir("true".equals(p.getProperty("mail.smtp.ssl.checkserveridentity")),"Verificar identidad TLS");
            exigir("false".equals(p.getProperty("mail.smtp.auth")),"Sin credenciales no autentica");
            exigir("false".equals(p.getProperty("mail.debug")) && "false".equals(p.getProperty("mail.debug.auth")),"Sin debug");
            for (String clave : Arrays.asList("mail.smtp.connectiontimeout","mail.smtp.timeout","mail.smtp.writetimeout")) {
                exigir("10000".equals(p.getProperty(clave)),"Timeout por defecto");
            }
            p.setProperty("mail.debug","true");
            exigir("false".equals(c.propiedadesSmtp().getProperty("mail.debug")),"Copia defensiva propiedades");
            casos++;
        }
        v=base(); v.replaceAll((k,val)->" "+val+" ");
        v.put("APUESTAS_MAIL_CONNECT_TIMEOUT_MS"," 1200 ");
        v.put("APUESTAS_MAIL_READ_TIMEOUT_MS"," 2300 ");
        v.put("APUESTAS_MAIL_WRITE_TIMEOUT_MS"," 3400 ");
        String clave=" "+UUID.randomUUID()+" ";
        v.put("APUESTAS_MAIL_USERNAME"," usuario-prueba ");
        v.put("APUESTAS_MAIL_PASSWORD",clave);
        ConfiguracionCorreo c=ConfiguracionCorreo.desdeVariables(v);
        v.clear();
        exigir(c.getHost().equals("smtp.example.invalid") && c.getPuerto()==587,"Espacios configuracion");
        exigir(c.getRemitente().equals("seguridad@example.invalid") && c.getNombreRemitente().equals("Plataforma áñ"),"From normalizado");
        exigir("usuario-prueba".equals(c.usuario()) && clave.equals(c.password()),"Password no se recorta");
        exigir(c.tieneAutenticacion() && "true".equals(c.propiedadesSmtp().getProperty("mail.smtp.auth")),"Auth");
        exigir("1200".equals(c.propiedadesSmtp().getProperty("mail.smtp.connectiontimeout")),"Connect timeout");
        exigir("2300".equals(c.propiedadesSmtp().getProperty("mail.smtp.timeout")),"Read timeout");
        exigir("3400".equals(c.propiedadesSmtp().getProperty("mail.smtp.writetimeout")),"Write timeout");
        exigir(!c.toString().contains(clave) && !c.toString().contains("usuario-prueba"),"toString seguro");
        exigir(!c.propiedadesSmtp().toString().contains(clave) && !c.propiedadesSmtp().containsKey("mail.smtp.user"),"Propiedades sin credenciales");
        casos++;
    }
    private static void mensajes() {
        for (String destino : Arrays.asList(null,"","abc","a@@b.test","a@","a@b.test,b@c.test",
                "Nombre <a@b.test>","grupo: a@b.test;","a@b.test\n")) {
            mensajeInvalido(destino,"Asunto","Texto",null);
        }
        for (String asunto : Arrays.asList(null,""," ","Normal\rBcc: x@y.test","Normal\n","Normal\0")) {
            mensajeInvalido("a@example.invalid",asunto,"Texto",null);
        }
        mensajeInvalido("a@example.invalid","Asunto",null,null);
        mensajeInvalido("a@example.invalid","Asunto","",null);
        mensajeInvalido("a@example.invalid","Asunto","Texto","");
        MensajeCorreo m=new MensajeCorreo(" destino@example.invalid ","Asunto áñ","Texto ñ\nsegunda linea");
        exigir("destino@example.invalid".equals(m.getDestinatario()),"Destino normalizado");
        exigir(!m.toString().contains("destino") && !m.toString().contains("Texto"),"toString no revela contenido");
        List<MensajeCorreo> recibidos=new ArrayList<>();
        CorreoServicio fake=recibidos::add;
        try { fake.enviar(m); } catch (EnvioCorreoException e) { throw new AssertionError(e); }
        exigir(recibidos.size()==1 && recibidos.get(0)==m,"Interfaz sustituible por fake");
        casos++;
    }
    private static void envios() throws Exception {
        for (boolean html : new boolean[]{false,true}) {
            for (boolean auth : new boolean[]{false,true}) {
                Map<String,String> v=base();
                String password=UUID.randomUUID().toString();
                if (auth) { v.put("APUESTAS_MAIL_USERNAME","usuario-prueba"); v.put("APUESTAS_MAIL_PASSWORD",password); }
                ConfiguracionCorreo c=ConfiguracionCorreo.desdeVariables(v);
                Fabrica f=new Fabrica();
                CorreoSmtpServicio servicio=new CorreoSmtpServicio(c,f);
                MensajeCorreo entrada=new MensajeCorreo("destino@example.invalid","Asunto áñ",
                        "Texto español áñ",html ? "<p>Texto español áñ</p>" : null);
                servicio.enviar(entrada);
                TransporteSimulado t=f.transporte;
                exigir(f.creaciones==1 && t.conexiones==1 && t.envios==1 && t.cierres==1,"Un envio sin reintentos, cerrado");
                exigir(t.host.equals(c.getHost()) && t.puerto==587,"Host y puerto del transporte");
                exigir(auth ? password.equals(t.password) && "usuario-prueba".equals(t.usuario)
                        : t.password==null && t.usuario==null,"Credenciales solo al connect");
                exigir(!t.recibida.getDebug(),"Session sin debug");
                exigir(t.destinos.length==1 && t.destinos[0].toString().equals("destino@example.invalid"),"Destinos");
                InternetAddress from=(InternetAddress)t.mensaje.getFrom()[0];
                exigir(from.getAddress().equals(c.getRemitente()) && from.getPersonal().equals("Plataforma áñ"),"From UTF8");
                exigir(t.mensaje.getHeader("Reply-To")==null,"Sin Reply-To agregado");
                ByteArrayOutputStream bytes=new ByteArrayOutputStream();
                t.mensaje.writeTo(bytes);
                String serializado=bytes.toString(StandardCharsets.UTF_8.name());
                exigir(!serializado.contains(password) && !serializado.contains("usuario-prueba"),"Sin credenciales en MIME");
                MimeMessage reconstruido=new MimeMessage(t.recibida,new ByteArrayInputStream(bytes.toByteArray()));
                exigir("Asunto áñ".equals(reconstruido.getSubject()),"Subject UTF8");
                if (html) {
                    exigir(reconstruido.isMimeType("multipart/alternative"),"Multipart alternative");
                    Multipart partes=(Multipart)reconstruido.getContent();
                    exigir(partes.getCount()==2 && partes.getBodyPart(0).isMimeType("text/plain")
                            && partes.getBodyPart(1).isMimeType("text/html"),"Orden texto y HTML");
                    exigir(entrada.getTexto().equals(partes.getBodyPart(0).getContent()),"Texto UTF8");
                    exigir(entrada.getHtml().equals(partes.getBodyPart(1).getContent()),"HTML UTF8");
                } else {
                    exigir(reconstruido.isMimeType("text/plain") && entrada.getTexto().equals(reconstruido.getContent()),"Texto plano UTF8");
                }
                casos++;
            }
        }
        for (String fallo : Arrays.asList("fabrica","conexion","envio","runtime","cierre")) {
            Map<String,String> v=base();
            String secreto=UUID.randomUUID().toString();
            v.put("APUESTAS_MAIL_USERNAME","usuario-prueba"); v.put("APUESTAS_MAIL_PASSWORD",secreto);
            Fabrica f=new Fabrica(); f.fallo=fallo;
            try {
                new CorreoSmtpServicio(ConfiguracionCorreo.desdeVariables(v),f)
                        .enviar(new MensajeCorreo("destino@example.invalid","Asunto","Contenido privado"));
                throw new AssertionError("No afirmar exito");
            } catch (EnvioCorreoException esperado) {
                StringWriter traza=new StringWriter(); esperado.printStackTrace(new PrintWriter(traza));
                exigir(!traza.toString().contains(secreto) && !traza.toString().contains("INTERNO")
                        && !traza.toString().contains("Contenido privado"),"Excepcion segura incluso en traza");
                exigir(esperado.getCause()==null,"No encadenar datos SMTP");
                exigir(f.creaciones==1,"No reintento");
                if (f.transporte!=null) {
                    exigir(f.transporte.cierres==1,"Cierre ante fallo");
                    exigir(f.transporte.envios==("conexion".equals(fallo)?0:1),"No enviar tras fallo de conexion");
                }
                casos++;
            }
        }
        // Resolver el proveedor instalado no abre sockets ni llama connect.
        Session session=Session.getInstance(ConfiguracionCorreo.desdeVariables(base()).propiedadesSmtp());
        try (Transport transport=session.getTransport("smtp")) {
            exigir(transport.getClass().getName().startsWith("org.eclipse.angus."),"Proveedor Angus disponible");
        }
        casos++;
    }
    public static void main(String[] args) throws Exception {
        configuracion();
        mensajes();
        envios();
        System.out.println("OK: "+casos+" casos de infraestructura SMTP, sin red ni correos reales.");
    }
}
