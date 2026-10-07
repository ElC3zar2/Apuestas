package com.apuestas.controlador;

import com.apuestas.dao.AdministracionUsuarioDAO;
import com.apuestas.modelo.*;
import com.apuestas.seguridad.*;
import com.apuestas.servicio.AutenticacionAdministrativaServicio;
import com.fasterxml.jackson.databind.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.nio.file.*;
import java.sql.*;
import java.util.*;
import java.util.function.Supplier;
import javax.servlet.*;
import javax.servlet.annotation.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;

/**
 * Integracion de los seis bloques con una sesion obtenida por login.
 * Reutiliza los dobles JDBC estrictos; no simula que estos sustituyan una BD real.
 * Cada caso contabilizado corresponde a una solicitud o comprobacion integral nueva.
 */
public class PruebaIntegracionBackendAdministrativo {
    private static int casos;
    private static final ObjectMapper JSON=new ObjectMapper();
    private static Object campo(Object o,String nombre) throws Exception {
        Field f=o.getClass().getDeclaredField(nombre);f.setAccessible(true);return f.get(o);
    }
    private static void asignar(Object o,String nombre,Object valor) throws Exception {
        Field f=o.getClass().getDeclaredField(nombre);f.setAccessible(true);f.set(o,valor);
    }
    static class Api {
        final Object caso;final Http h;final Map<String,String[]> params;
        @SuppressWarnings("unchecked") Api(Object caso) throws Exception {
            this.caso=caso;h=(Http)campo(caso,"h");
            params=(Map<String,String[]>)campo(caso,caso instanceof PruebaAdministracionUsuario.Caso?"parametros":"params");
        }
        JsonNode ejecutar(int estado) throws Exception {
            Method m=caso.getClass().getDeclaredMethod("ejecutar",int.class);m.setAccessible(true);
            try {
                JsonNode r=(JsonNode)m.invoke(caso,estado);casos++;return r;
            } catch(InvocationTargetException e) {
                Throwable causa=e.getCause();
                if(causa instanceof Exception) throw (Exception)causa;
                throw (Error)causa;
            }
        }
    }
    private static Sesion login(String rol) throws Exception {
        Dao d=new Dao();d.u=usuario(7,3,rol,"ACTIVO",HASH,false);
        Http h=new Http();h.params.put("correo","admin@example.test");h.params.put("contrasena",CLAVE);
        h.previa=new Sesion();h.previa.datos.put("idUsuario",99);h.previa.datos.put("rol","USUARIO");
        new ControlAccesoAdministrativo().doFilter(h.req,h.res,(r,s)-> {
            try { PruebaLoginAdministrativo.ejecutar(h,new AutenticacionAdministrativaServicio(d)); }
            catch(Exception e) { throw new ServletException(e); }
        });
        exigir(h.status==303&&h.creaciones==1&&h.previa.invalidada&&d.intentos==1);
        exigir(h.nueva.datos.keySet().equals(new HashSet<>(Arrays.asList(
                "adminIdUsuario","adminCorreo","adminIdRol","adminRol","adminEstadoUsuario"))));
        exigir(SesionAdministrativa.valida(h.nueva.ref)&&"127.0.0.1".equals(d.ip));
        exigir(!h.nueva.datos.containsValue(CLAVE)&&!h.nueva.datos.containsValue(HASH));casos++;
        return h.nueva;
    }
    private static void logout(Sesion sesion) throws Exception {
        Http h=new Http();h.ruta="/administrador/logout";h.previa=sesion;
        new ControlAccesoAdministrativo().doFilter(h.req,h.res,(r,s)->new LogoutAdministrativoServlet().service(h.req,h.res));
        exigir(h.status==303&&h.creaciones==0&&sesion.invalidada&&sesion.datos.isEmpty());
        exigir("/app/administrador/login".equals(h.headers.get("Location")));casos++;
    }
    private static List<Supplier<Object>> fabricas() {
        List<Supplier<Object>> f=new ArrayList<>();
        f.add(()->new PruebaDashboardAdministrativo.Caso(false));
        f.add(()->new PruebaDashboardAdministrativo.Caso(true));
        for(OperacionAdministracionUsuario op:OperacionAdministracionUsuario.values()) f.add(()->new PruebaAdministracionUsuario.Caso(op));
        for(OperacionAdministracionEventos op:OperacionAdministracionEventos.values()) f.add(()->new PruebaAdministracionEventos.Caso(op));
        for(OperacionAdministracionResultados op:OperacionAdministracionResultados.values()) f.add(()->new PruebaAdministracionResultados.Caso(op));
        f.add(()->new PruebaLiquidacionAdministrativa.Caso(0));
        f.add(()->new PruebaLiquidacionAdministrativa.Caso(1));
        f.add(()->new PruebaLiquidacionAdministrativa.Caso(3));
        return f;
    }
    private static void mappings() throws Exception {
        Map<String,String> rutas=new HashMap<>();int admin=0;
        try(java.util.stream.Stream<Path> files=Files.list(Paths.get("src/main/java/com/apuestas/controlador"))) {
            for(Path p:(Iterable<Path>)files.filter(x->x.toString().endsWith(".java"))::iterator) {
                String nombre=p.getFileName().toString().replace(".java","");
                Class<?> c=Class.forName("com.apuestas.controlador."+nombre,false,PruebaIntegracionBackendAdministrativo.class.getClassLoader());
                WebServlet a=c.getAnnotation(WebServlet.class);if(a==null) continue;
                Set<String> locales=new HashSet<>();Collections.addAll(locales,a.value());Collections.addAll(locales,a.urlPatterns());
                for(String ruta:locales) {
                    exigir(rutas.put(ruta,nombre)==null);
                    if(ruta.startsWith("/administrador/")) { exigir(!ruta.contains("*"));admin++; }
                }
            }
        }
        exigir(admin==33);
        for(Supplier<Object> f:fabricas()) exigir(rutas.containsKey(new Api(f.get()).h.ruta));
        WebFilter filtro=ControlAccesoAdministrativo.class.getAnnotation(WebFilter.class);
        exigir(Arrays.asList(filtro.urlPatterns()).contains("/administrador/*"));
        exigir(Arrays.asList(filtro.dispatcherTypes()).contains(DispatcherType.FORWARD));
        exigir(!Files.exists(Paths.get("src/main/webapp/WEB-INF/web.xml")));casos++;
    }
    private static void navegacion() throws Exception {
        for(String ruta:new String[]{"/administrador/inicio.jsp","/administrador/","/administrador/login.jsp"}) {
            Http h=new Http();h.ruta=ruta;h.method="GET";
            new ControlAccesoAdministrativo().doFilter(h.req,h.res,(r,s)->h.chain++);
            exigir(h.status==303&&h.chain==0&&h.creaciones==0&&"/app/administrador/login".equals(h.headers.get("Location")));casos++;
        }
        for(String ruta:new String[]{"/administrador/login-extra","/administrador/login.jsp/extra","/administrador/logout-extra"}) {
            Http h=new Http();h.ruta=ruta;h.method="GET";
            new ControlAccesoAdministrativo().doFilter(h.req,h.res,(r,s)->h.chain++);
            exigir(h.status==401&&h.chain==0&&h.creaciones==0);casos++;
        }
        Http h=new Http();h.ruta="/administrador/login";h.method="GET";
        new ControlAccesoAdministrativo().doFilter(h.req,h.res,(r,s)->new LoginAdministrativoServlet().service((javax.servlet.http.HttpServletRequest)r,(javax.servlet.http.HttpServletResponse)s));
        exigir("/administrador/login.jsp".equals(h.forward)&&h.creaciones==0);casos++;
        h=new Http();h.ruta="/administrador/logout";h.method="GET";
        new LogoutAdministrativoServlet().service(h.req,h.res);
        exigir(h.status==405&&"POST".equals(h.headers.get("Allow"))&&h.creaciones==0);casos++;
        h=new Http();h.ruta="/administrador/logout";new LogoutAdministrativoServlet().service(h.req,h.res);
        exigir(h.status==303&&h.creaciones==0);casos++;
    }
    /** Reproduce conversion silenciosa JDBC de DECIMAL a INT en un identificador. */
    private static void tipoJdbcEstricto() throws Exception {
        PruebaAdministracionUsuario.Jdbc j=new PruebaAdministracionUsuario.Jdbc(OperacionAdministracionUsuario.PENDIENTES) {
            @Override ResultSet rs(List<Map<String,Object>> datos) {
                ResultSet base=super.rs(datos);
                return proxy(ResultSet.class,(p,m,a)-> {
                    if(a!=null&&a.length==1&&"IdUsuario".equals(a[0])) {
                        if(m.getName().equals("getInt")) return 19;
                        if(m.getName().equals("getObject")) return new BigDecimal("19.9");
                    }
                    try { return m.invoke(base,a); } catch(InvocationTargetException e) { throw e.getCause(); }
                });
            }
        };
        AdministracionUsuarioDAO d=new AdministracionUsuarioDAO() { @Override protected Connection obtenerConexion(){return j.conexion();} };
        boolean rechazo=false;
        try { d.pendientes(7,100); } catch(SQLException e) { rechazo=true; }
        if(!rechazo) throw new AssertionError("IdUsuario DECIMAL fue aceptado como INT por conversion JDBC");
        exigir(j.conexionCerrada&&j.statementCerrado&&j.abiertos==j.cerrados);casos++;
    }
    public static void main(String[] args) throws Exception {
        if(args.length>0) { tipoJdbcEstricto();return; }
        mappings();navegacion();tipoJdbcEstricto();
        Sesion admin=login("ADMINISTRADOR");
        Map<String,Object> identidad=new LinkedHashMap<>(admin.datos);
        for(Supplier<Object> f:fabricas()) {
            Api a=new Api(f.get());a.h.previa=admin;a.ejecutar(200);
            exigir(admin.datos.equals(identidad));
            a=new Api(f.get());a.h.previa=null;a.ejecutar(401);
            a=new Api(f.get());a.h.previa.expirada=true;a.ejecutar(401);
            a=new Api(f.get());a.h.previa.datos.put("idUsuario",7);a.h.previa.datos.put("rol","USUARIO");a.ejecutar(403);
            a=new Api(f.get());a.h.previa.datos.put("adminIdUsuario","7");a.ejecutar(403);
            a=new Api(f.get());a.h.previa.datos.put("adminEstadoUsuario","SUSPENDIDO");a.ejecutar(403);
            a=new Api(f.get());String correcto=a.h.method;a.h.method=correcto.equals("GET")?"POST":"GET";
            a.ejecutar(405);exigir(correcto.equals(a.h.headers.get("Allow")));
            for(String clave:new String[]{"IdUsuarioProceso","idUsuarioProceso","IdUsuarioSolicitante","idUsuarioSolicitante",
                    "idAdministrador","rolAdministrador","correoAdministrador","ipOrigen","IpOrigen","X-Forwarded-For"}) {
                a=new Api(f.get());a.params.put(clave,new String[]{"99","100"});a.ejecutar(400);
            }
            a=new Api(f.get());a.params.put("parametroDesconocido",new String[]{"valor"});a.ejecutar(400);
            a=new Api(f.get());
            if(!a.params.isEmpty()) {
                String clave=a.params.keySet().iterator().next();a.params.put(clave,new String[]{"1","2"});a.ejecutar(400);
            }
        }
        // Roles de login reales transportados entre todos los modulos.
        for(String rol:new String[]{"AUDITOR","CAJERO","OPERADOR_EVENTOS"}) {
            Sesion sesion=login(rol);
            for(Supplier<Object> f:fabricas()) {
                Api a=new Api(f.get());a.h.previa=sesion;boolean permitido=false;
                if(a.caso instanceof PruebaAdministracionUsuario.Caso)
                    permitido=rol.equals("AUDITOR")&&((PruebaAdministracionUsuario.Caso)a.caso).op.lectura();
                else if(a.caso instanceof PruebaAdministracionEventos.Caso) permitido=rol.equals("OPERADOR_EVENTOS");
                else if(a.caso instanceof PruebaAdministracionResultados.Caso)
                    permitido=rol.equals("OPERADOR_EVENTOS")&&!((PruebaAdministracionResultados.Caso)a.caso).op.soloAdministrador;
                else if(a.caso instanceof PruebaLiquidacionAdministrativa.Caso)
                    permitido=rol.equals("CAJERO")||(rol.equals("AUDITOR")&&a.h.ruta.endsWith("/consultar"));
                else permitido=rol.equals("AUDITOR");
                a.ejecutar(permitido?200:403);
            }
            logout(sesion);
        }
        Dao malo=new Dao();malo.r=intento(7,1,false,false,"ACTIVO");
        Http fallo=PruebaLoginAdministrativo.llamar(malo,"admin@example.test","incorrecta","POST");
        exigir(fallo.status==401&&fallo.creaciones==0);casos++;
        malo=new Dao();malo.u=usuario(7,2,"USUARIO","ACTIVO",HASH,false);
        fallo=PruebaLoginAdministrativo.llamar(malo,"admin@example.test",CLAVE,"POST");
        exigir(fallo.status==401&&fallo.creaciones==0&&malo.intentos==0);casos++;
        // Repeticion con estado persistente en el doble SQL; nunca una operacion financiera Java.
        PruebaLiquidacionAdministrativa.EstadoSP estado=new PruebaLiquidacionAdministrativa.EstadoSP();
        PruebaLiquidacionAdministrativa.Caso uno=new PruebaLiquidacionAdministrativa.Caso(1);
        uno.h.previa=admin;uno.j.estado=estado;JsonNode primera=new Api(uno).ejecutar(200);
        PruebaLiquidacionAdministrativa.Caso dos=new PruebaLiquidacionAdministrativa.Caso(2);
        dos.h.previa=admin;dos.j.estado=estado;JsonNode segunda=new Api(dos).ejecutar(200);
        exigir(estado.invocaciones==2&&estado.efectos==1);
        exigir(primera.at("/resultado/idLiquidacion").equals(segunda.at("/resultado/idLiquidacion")));
        exigir(segunda.at("/resultado/solicitudIdempotente").asBoolean());
        // Fallos JDBC atraviesan los controladores de cada modulo, sin respuesta parcial.
        PruebaAdministracionUsuario.Caso u=new PruebaAdministracionUsuario.Caso(OperacionAdministracionUsuario.DETALLE);
        u.j.resultados.get(0).clear();new Api(u).ejecutar(500);
        u=new PruebaAdministracionUsuario.Caso(OperacionAdministracionUsuario.DETALLE);
        u.j.resultados.get(0).get(0).remove("IdUsuario");new Api(u).ejecutar(500);
        PruebaAdministracionEventos.Caso e=new PruebaAdministracionEventos.Caso(OperacionAdministracionEventos.CREAR_LIGA);
        e.j.resultados.get(0).add(new LinkedHashMap<>(e.j.fila()));new Api(e).ejecutar(500);
        PruebaAdministracionResultados.Caso r=new PruebaAdministracionResultados.Caso(OperacionAdministracionResultados.OFICIALIZAR);
        r.j.fila().put("IdResultado",null);new Api(r).ejecutar(500);
        PruebaLiquidacionAdministrativa.Caso l=new PruebaLiquidacionAdministrativa.Caso(1);
        l.j.codigo=62020;new Api(l).ejecutar(409);
        PruebaDashboardAdministrativo.Caso d=new PruebaDashboardAdministrativo.Caso(false);
        d.j.bloques.add(new PruebaDashboardAdministrativo.Bloque(new LinkedHashMap<>()));new Api(d).ejecutar(500);
        d=new PruebaDashboardAdministrativo.Caso(false);d.j.falloRuntime=true;new Api(d).ejecutar(500);
        d=new PruebaDashboardAdministrativo.Caso(false);d.j.codigo=99999;new Api(d).ejecutar(500);
        d=new PruebaDashboardAdministrativo.Caso(false);
        d.j.fila(1).put("CuotaPromedio",null);d.j.fila(1).put("ProbabilidadImplicitaPromedio",null);
        exigir(new Api(d).ejecutar(200).at("/deportes/0/cuotaPromedio").isNull());
        d=new PruebaDashboardAdministrativo.Caso(true);d.p("idDeporte","2");d.p("vista"," previa ");d.p("horasPrevia","48");
        new Api(d).ejecutar(200);
        // Escaping compartido, nulos, booleanos, precision y fechas ISO.
        Http jsonHttp=new Http();String texto="Comillas \" barra \\ salto\n tab\t Unicode ñ 控制 \u0001";
        Map<String,Object> json=new LinkedHashMap<>();json.put("texto",texto);json.put("nulo",null);json.put("booleano",true);
        json.put("importe",new BigDecimal("12345678901234567890.12"));json.put("fecha",java.time.LocalDateTime.of(2026,10,6,12,34,56));
        AdministracionUsuarioHttp.escribir(jsonHttp.res,200,json);
        JsonNode leido=new ObjectMapper().enable(DeserializationFeature.USE_BIG_DECIMAL_FOR_FLOATS).readTree(jsonHttp.body.toString());
        exigir(leido.get("texto").asText().equals(texto)&&leido.get("nulo").isNull()&&leido.get("booleano").isBoolean());
        exigir(leido.get("importe").decimalValue().equals(json.get("importe"))&&leido.get("fecha").asText().equals("2026-10-06T12:34:56"));casos++;
        logout(admin);admin.expirada=true;
        for(Supplier<Object> f:fabricas()) { Api a=new Api(f.get());a.h.previa=admin;a.ejecutar(401); }
        System.out.println("Integracion backend administrativo: "+casos+" casos, 0 fallos.");
    }
}
