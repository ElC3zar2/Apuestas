package com.apuestas.controlador;

import com.apuestas.dao.*;
import com.apuestas.modelo.*;
import com.apuestas.servicio.UsuarioServicio;
import java.time.*;
import java.nio.file.*;
import java.util.*;
import static com.apuestas.controlador.PruebaAuditoriaUsuario.*;

/** Pruebas sin red: reloj fijo y DAO simulados. */
public class PruebaEdadRegistro {
    private static int casos;
    private static final String INVALIDA = "Fecha de nacimiento inválida.";
    private static final String MENOR = "Debes ser mayor de edad para crear una cuenta.";
    private static final Clock RELOJ = Clock.fixed(
            Instant.parse("2026-10-02T03:00:00Z"), ZoneId.of("America/Guatemala"));
    private static UsuarioServicio servicio(Clock reloj, int[] llamadas) {
        return new UsuarioServicio(new UsuarioDAO() {
            @Override public int registrarCliente(Usuario u) {
                llamadas[0]++;
                exigir(u.getContrasena().startsWith("$2a$12$"));
                return 7;
            }
        }, reloj);
    }
    private static void texto(String entrada, String error) {
        UsuarioServicio s=servicio(RELOJ,new int[1]);
        try {
            exigir(s.interpretarFechaNacimiento(entrada).toString().equals(entrada));
            exigir(error==null);
        } catch(UsuarioServicio.FechaNacimientoException e) {
            exigir(e.getMessage().equals(error));
        }
        casos++;
    }
    private static void directo(LocalDate fecha, boolean valido, Clock reloj) throws Exception {
        int[] llamadas={0};
        Usuario u=usuario("ClaveSegura123","a@example.invalid");
        u.setFechaNacimiento(fecha);
        try {
            exigir(servicio(reloj,llamadas).registrarCliente(u)==7);
            exigir(valido);
        } catch(UsuarioServicio.FechaNacimientoException e) {
            exigir(!valido);
            exigir(u.getContrasena().equals("ClaveSegura123"));
        }
        exigir(llamadas[0]==(valido?1:0));
        casos++;
    }
    private static void http(String fecha, String error, boolean get) throws Exception {
        Http h=new Http();
        h.parametros.put("nombre","Nombre");h.parametros.put("apellido","Apellido");
        h.parametros.put("correo","a@example.invalid");h.parametros.put("contrasena","ClaveSegura123");
        h.parametros.put("genero","M");h.parametros.put("tipoDocumento","PASAPORTE");
        h.parametros.put("numeroDocumento","PRUEBA");h.parametros.put("direccion","Direccion");
        h.parametros.put("fechaNacimiento",fecha);h.parametros.put("idPais","2");
        h.parametros.put("ciudadExterior","Ciudad");h.parametros.put("idPaisTelefono","2");
        h.parametros.put("telefono","12345678");
        // No max ni JavaScript: solicitud manual directa al servlet.
        int[] llamadas={0};
        RegistroUsuarioServlet s=new RegistroUsuarioServlet();
        inyectar(s,"usuarioServicio",servicio(RELOJ,llamadas));
        inyectar(s,"ubicacionDAO",new UbicacionDAO() {
            @Override public boolean esGuatemala(int id){return false;}
            @Override public String obtenerCodigoTelefonicoPorPais(int id){return "+502";}
            @Override public List<Pais> listarPaisesActivos(){return Collections.emptyList();}
            @Override public List<Departamento> listarDepartamentosGuatemala(){return Collections.emptyList();}
        });
        if(get)s.doGet(h.req,h.res);else s.doPost(h.req,h.res);
        exigir("2008-10-01".equals(h.atributos.get("fechaLimiteNacimiento")));
        exigir("no-store".equals(h.headers.get("Cache-Control")));
        exigir(h.estado==(error==null?200:400));
        exigir(Objects.equals(error,h.atributos.get("error")));
        exigir(h.forward.equals(get || error!=null?"/usuario/registro.jsp":"/usuario/login.jsp"));
        exigir(llamadas[0]==(!get && error==null?1:0));
        casos++;
    }
    public static void main(String[] args) throws Exception {
        // Fecha civil 1 octubre aunque UTC ya sea 2 octubre.
        for(String fecha:new String[]{"2008-10-01","2008-09-30","2008-01-01","1990-01-01","2008-02-29"})
            texto(fecha,null);
        for(String fecha:new String[]{"2008-10-02","2009-10-01","2026-10-01","2026-10-02","2027-01-01"})
            texto(fecha,MENOR);
        for(String fecha:new String[]{null,""," ","2008/10/01","01/10/2008","2025-02-30",
                "2007-02-29","2008-2-29","2008-10-01 "," 2008-10-01","0000-01-01","2008-13-01"})
            texto(fecha,INVALIDA);
        for(LocalDate fecha:new LocalDate[]{LocalDate.of(2008,10,1),LocalDate.of(2008,9,30),LocalDate.of(2008,2,29)})
            directo(fecha,true,RELOJ);
        for(LocalDate fecha:new LocalDate[]{null,LocalDate.of(2008,10,2),LocalDate.of(2009,10,1),
                LocalDate.of(2026,10,1),LocalDate.of(2027,1,1)})
            directo(fecha,false,RELOJ);
        Clock febrero=Clock.fixed(Instant.parse("2026-02-28T12:00:00Z"),ZoneOffset.UTC);
        directo(LocalDate.of(2008,2,29),false,febrero);
        directo(LocalDate.of(2008,2,28),true,febrero);
        directo(LocalDate.of(2008,2,29),true,Clock.offset(febrero,Duration.ofDays(1)));
        Clock bisiesto=Clock.fixed(Instant.parse("2024-02-29T12:00:00Z"),ZoneOffset.UTC);
        directo(LocalDate.of(2006,2,28),true,bisiesto);
        directo(LocalDate.of(2006,3,1),false,bisiesto);
        http(null,null,true);
        http("2008-10-01",null,false);
        http("2008-10-02",MENOR,false);
        http("2027-01-01",MENOR,false);
        http(null,INVALIDA,false);
        http("2025-02-30",INVALIDA,false);
        http("",INVALIDA,false);
        String jsp=Files.readString(Paths.get("src/main/webapp/usuario/registro.jsp"));
        exigir(jsp.contains("max=\""+"$"+"{fechaLimiteNacimiento}\""));casos++;
        String js=Files.readString(Paths.get("src/main/webapp/js/registro.js"));
        exigir(!js.contains("toISOString") && !js.contains("fechaNacimiento.max"));casos++;
        System.out.println("Edad registro: "+casos+" casos, 0 fallos.");
    }
}