package com.apuestas.controlador;

import com.apuestas.seguridad.*;
import com.apuestas.seguridad.CsrfSeguridad.Ambito;
import com.apuestas.modelo.*;
import com.apuestas.servicio.*;
import com.apuestas.reporte.ReporteBoletoServicio;
import com.fasterxml.jackson.databind.*;
import java.io.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import javax.servlet.http.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;

/** Seguridad con filtros y servlets reales, servicios/JDBC controlados. Sin SQL/SMTP ni archivos PDF. */
public final class PruebaSeguridadBackend {
    private static int casos;
    private static final ObjectMapper JSON=new ObjectMapper();
    private static void caso(boolean ok) {exigir(ok);casos++;}
    static class C {
        final Http h=new Http();final Map<String,String[]> p=new LinkedHashMap<>();
        final Map<String,List<String>> entrada=new HashMap<>();final ByteArrayOutputStream pdf=new ByteArrayOutputStream();
        String query;int consultas,generaciones;boolean ajeno,inexistente;Throwable fallo;
        final HttpServletRequest req=proxy(HttpServletRequest.class,(o,m,a)-> {
            switch(m.getName()) {
                case "getParameterMap":return p;
                case "getParameterValues":return p.get(a[0]);
                case "getParameter":String[] v=p.get(a[0]);return v==null||v.length==0?null:v[0];
                case "getHeader":List<String> valores=entrada.get(a[0]);return valores==null||valores.isEmpty()?null:valores.get(0);
                case "getHeaders":return Collections.enumeration(entrada.getOrDefault(a[0],Collections.emptyList()));
                case "getQueryString":return query;
                case "getScheme":return "https";
                case "getServerName":return "apuestas.example.test";
                case "getServerPort":return 443;
                case "getProtocol":return "HTTP/1.1";
                default:try{return m.invoke(h.req,a);}catch(InvocationTargetException e){throw e.getCause();}
            }
        });
        final HttpServletResponse res=proxy(HttpServletResponse.class,(o,m,a)-> {
            switch(m.getName()) {
                case "setCharacterEncoding":case "setContentLength":return null;
                case "isCommitted":return false;
                case "sendError":h.status=(Integer)a[0];h.tipo="text/html";return null;
                case "reset":h.status=200;h.headers.clear();h.body.getBuffer().setLength(0);return null;
                case "getOutputStream":return new ServletOutputStream() {
                    @Override public void write(int b){pdf.write(b);}
                    @Override public boolean isReady(){return true;}
                    @Override public void setWriteListener(WriteListener l){throw new AssertionError();}
                };
                default:try{return m.invoke(h.res,a);}catch(InvocationTargetException e){throw e.getCause();}
            }
        });
        C(Ambito ambito) {
            h.method="GET";h.ruta=ambito==Ambito.USUARIO?CsrfSeguridad.RUTA_USUARIO:CsrfSeguridad.RUTA_ADMIN;
            h.previa=new Sesion();
            if(ambito==Ambito.USUARIO) {h.previa.datos.put("idUsuario",7);h.previa.datos.put("rol","USUARIO");}
            else {h.previa.datos.put("adminIdUsuario",7);h.previa.datos.put("adminIdRol",3);
                h.previa.datos.put("adminCorreo","admin@example.test");h.previa.datos.put("adminRol","ADMINISTRADOR");
                h.previa.datos.put("adminEstadoUsuario","ACTIVO");}
        }
        void header(String k,String... v){entrada.put(k,Arrays.asList(v));}
        String token(Ambito a){return CsrfSeguridad.obtener(h.previa.ref,a);}
        JsonNode entregar(int estado)throws Exception {
            TokenCsrfServlet servlet=new TokenCsrfServlet();
            Filter f=h.ruta.startsWith("/administrador")?new ControlAccesoAdministrativo():new ControlAcceso();
            f.doFilter(req,res,(r,s)->servlet.service((HttpServletRequest)r,(HttpServletResponse)s));
            exigir(h.status==estado&&h.creaciones==0&&"application/json;charset=UTF-8".equals(h.tipo));
            exigir("no-store".equals(h.headers.get("Cache-Control"))&&!h.headers.containsKey("Location"));
            JsonNode json=JSON.readTree(h.body.toString());exigir(json.path("ok").asBoolean()==(estado==200));
            if(estado!=200)exigir(json.size()==2&&!json.has("csrfToken"));casos++;return json;
        }
        void filtrar(int estado,boolean permitido)throws Exception {
            new FiltroCsrf().doFilter(req,res,(r,s)-> {
                h.chain++;exigir("UTF-8".equals(h.encoding));HttpServletRequest limpia=(HttpServletRequest)r;
                exigir(!limpia.getParameterMap().containsKey("_csrf")&&limpia.getParameter("_csrf")==null);
                exigir(limpia.getParameterValues("_csrf")==null);
                exigir("referencia-original".equals(limpia.getParameter("referenciaOperacion")));
            });
            exigir(h.status==estado&&h.chain==(permitido?1:0));
            if(!permitido) {exigir(JSON.readTree(h.body.toString()).size()==2);exigir("no-store".equals(h.headers.get("Cache-Control")));}
            casos++;
        }
        void imprimir(int estado)throws Exception {
            h.ruta="/usuario/boletos/imprimir";
            ImprimirBoletoServlet servlet=new ImprimirBoletoServlet();
            PruebaCadenaControlAcceso.inyectar(servlet,"apuestaServicio",new ApuestaServicio() {
                @Override public Boleto obtenerBoletoPorId(int usuario,int boleto)throws SQLException {
                    consultas++;exigir(usuario==7&&boleto==70);
                    if(fallo instanceof SQLException)throw (SQLException)fallo;
                    if(fallo instanceof Error)throw (Error)fallo;
                    if(inexistente)return null;Boleto b=new Boleto();b.setIdUsuario(ajeno?8:7);b.setIdBoleto(70);
                    b.setCodigoBoleto("B-70\r\n../mal\".pdf");return b;
                }
            });
            PruebaCadenaControlAcceso.inyectar(servlet,"reporteBoletoServicio",new ReporteBoletoServicio() {
                @Override public byte[] generarBoleto(Boleto b){generaciones++;return "%PDF-controlado".getBytes(java.nio.charset.StandardCharsets.US_ASCII);}
            });
            servlet.service(req,res);exigir(h.status==estado);
            exigir(h.headers.get("Cache-Control").contains("no-store")&&!h.body.toString().contains("PRIVADO"));
            exigir(generaciones==(estado==200?1:0));
            if(estado==200) {
                exigir("application/pdf".equals(h.tipo)&&pdf.size()>0);
                String nombre=h.headers.get("Content-Disposition");
                exigir(!nombre.contains("\r")&&!nombre.contains("\n")&&!nombre.contains("../"));
            }else exigir("text/plain;charset=UTF-8".equals(h.tipo)&&pdf.size()==0);
            casos++;
        }
    }
    private static C post(Ambito a) {
        C c=new C(a);c.h.method="POST";c.h.ruta=a==Ambito.USUARIO?"/apuestas/realizar":"/administrador/liquidaciones/liquidar";
        c.p.put("referenciaOperacion",new String[]{"referencia-original"});return c;
    }
    private static void inicializacionFiltro()throws Exception {
        C c=new C(Ambito.USUARIO);c.h.ruta="/usuario/boletos/historial";
        HistorialBoletosUsuarioServlet servlet=new HistorialBoletosUsuarioServlet();
        PruebaCadenaControlAcceso.inyectar(servlet,"analiticaServicio",new AnaliticaUsuarioServicio(new com.apuestas.dao.AnaliticaUsuarioDAO() {
            @Override protected Connection obtenerConexion(){throw new ExceptionInInitializerError("PRIVADO");}
        }));
        new ControlAcceso().doFilter(c.req,c.res,(r,s)->servlet.service((HttpServletRequest)r,(HttpServletResponse)s));
        caso(c.h.status==500&&JSON.readTree(c.h.body.toString()).size()==2&&!c.h.body.toString().contains("PRIVADO"));
    }
    private static void realizacion(Throwable error,int esperado)throws Exception {
        C c=post(Ambito.USUARIO);c.p.put("idSeleccion",new String[]{"13"});c.p.put("monto",new String[]{"100.00"});
        c.p.put("referenciaOperacion",new String[]{"12345678-1234-1234-1234-123456789012"});
        RealizarApuestaServlet servlet=new RealizarApuestaServlet();
        PruebaCadenaControlAcceso.inyectar(servlet,"apuestaServicio",new ApuestaServicio() {
            @Override public ResultadoApuesta realizarApuesta(int id,List<Integer> ids,BigDecimal monto,UUID referencia,String ip,Integer a,Integer b)throws SQLException {
                c.consultas++;exigir(id==7&&referencia.toString().equals("12345678-1234-1234-1234-123456789012"));
                if(error instanceof Error)throw (Error)error;
                throw (SQLException)error;
            }
        });
        servlet.service(c.req,c.res);
        caso(c.h.status==esperado&&c.consultas==1&&JSON.readTree(c.h.body.toString()).size()==2
                &&!c.h.body.toString().contains("PRIVADO")&&"no-store".equals(c.h.headers.get("Cache-Control")));
    }
    public static void main(String[] args)throws Exception {
        inicializacionFiltro();
        caso(FiltroCsrf.class.getAnnotation(WebFilter.class)==null);
        for(Ambito a:Ambito.values()) {
            C c=new C(a);String token=c.entregar(200).path("csrfToken").asText();
            caso(TokenSeguridad.esValido(token)&&token.length()==43);
            caso(c.token(a).equals(token)); // varias pestanas no rotan
            C otra=new C(a);caso(!otra.token(a).equals(token));
            C post=post(a);post.header("X-CSRF-Token",token);caso(!CsrfSeguridad.validar(post.req,a));
            post=post(a);String propio=post.token(a);post.header("X-CSRF-Token",propio);caso(CsrfSeguridad.validar(post.req,a));post.filtrar(200,true);
            post=post(a);propio=post.token(a);post.p.put("_csrf",new String[]{propio});post.filtrar(200,true);
            post=post(a);post.token(a);post.filtrar(403,false);
            post=post(a);post.token(a);post.header("X-CSRF-Token","invalido");post.filtrar(403,false);
            post=post(a);post.header("X-CSRF-Token",post.token(a));post.h.previa.expirada=true;post.filtrar(401,false);
            post=post(a);post.h.previa=null;post.filtrar(401,false);
            post=post(a);post.header("X-CSRF-Token",post.token(a));post.h.previa.datos.put(a==Ambito.USUARIO?"rol":"adminRol","CASA");post.filtrar(403,false);
            post=post(a);post.header("X-CSRF-Token",post.token(a));post.h.previa.datos.put(a==Ambito.USUARIO?"idUsuario":"adminIdUsuario",8);post.filtrar(403,false);
            post=post(a);propio=post.token(a);post.header("X-CSRF-Token",propio,propio);post.filtrar(403,false);
            post=post(a);propio=post.token(a);post.p.put("_csrf",new String[]{propio,propio});post.filtrar(403,false);
            post=post(a);propio=post.token(a);post.header("X-CSRF-Token",propio);post.p.put("_csrf",new String[]{TokenSeguridad.generar()});post.filtrar(403,false);
            post=post(a);propio=post.token(a);post.p.put("_csrf",new String[]{propio});post.query="%5Fcsrf="+propio;post.filtrar(403,false);
            for(String origen:new String[]{"https://intruso.example.test","null","https://apuestas.example.test:444","https://apuestas.example.test/ruta","http://apuestas.example.test"}) {
                post=post(a);post.header("X-CSRF-Token",post.token(a));post.header("Origin",origen);post.filtrar(403,false);
            }
            post=post(a);post.header("X-CSRF-Token",post.token(a));post.header("Origin","https://apuestas.example.test");post.filtrar(200,true);
            for(String sitio:new String[]{"cross-site","same-site"}) {c=new C(a);c.header("Sec-Fetch-Site",sitio);c.entregar(403);}
            c=new C(a);c.header("Origin","https://intruso.example.test");c.entregar(403);
            c=new C(a);c.h.previa=null;c.entregar(401);
            c=new C(a);c.h.previa.expirada=true;c.entregar(401);
            c=new C(a);c.h.method="POST";c.entregar(405);
            c=new C(a);c.p.put("idUsuario",new String[]{"99"});c.entregar(400);
            c=new C(a);c.query="token=prohibido";c.entregar(400);
            c=new C(a);c.h.previa.datos.put(a==Ambito.USUARIO?"rol":"adminRol","CASA");c.entregar(403);
            c=new C(a);c.h.previa.falloLectura=true;
            c.entregar(500);
            c=new C(a);String previo=c.token(a);c.h.previa.ref.invalidate();c.h.previa=new C(a).h.previa;
            caso(!previo.equals(c.token(a)));
        }
        C u=new C(Ambito.USUARIO),admin=new C(Ambito.ADMINISTRADOR);
        u.header("X-CSRF-Token",admin.token(Ambito.ADMINISTRADOR));caso(!CsrfSeguridad.validar(u.req,Ambito.USUARIO));
        u=new C(Ambito.USUARIO);u.h.previa.datos.put("adminIdUsuario",7);u.entregar(403);
        for(String id:new String[]{"","0","-1","abc","2147483648"}) {C c=new C(Ambito.USUARIO);c.p.put("idBoleto",new String[]{id});c.imprimir(400);caso(c.consultas==0);}
        C c=new C(Ambito.USUARIO);c.p.put("idBoleto",new String[]{"70"});c.imprimir(200);
        c=new C(Ambito.USUARIO);c.p.put("idBoleto",new String[]{"70"});c.ajeno=true;c.imprimir(403);
        c=new C(Ambito.USUARIO);c.p.put("idBoleto",new String[]{"70"});c.inexistente=true;c.imprimir(404);
        for(int estado:new int[]{401,403}) {c=new C(Ambito.USUARIO);c.p.put("idBoleto",new String[]{"70"});if(estado==401)c.h.previa=null;else c.h.previa.datos.put("rol","CASA");c.imprimir(estado);caso(c.consultas==0);}
        c=new C(Ambito.USUARIO);c.h.previa.expirada=true;c.imprimir(401);
        for(String metodo:new String[]{"POST","PUT","DELETE","HEAD","OPTIONS"}) {c=new C(Ambito.USUARIO);c.h.method=metodo;c.imprimir(405);}
        c=new C(Ambito.USUARIO);c.p.put("idBoleto",new String[]{"70","71"});c.imprimir(400);
        c=new C(Ambito.USUARIO);c.p.put("idBoleto",new String[]{"70"});c.p.put("idUsuario",new String[]{"99"});c.imprimir(400);
        c=new C(Ambito.USUARIO);c.p.put("idBoleto",new String[]{"70"});c.fallo=new ExceptionInInitializerError("PRIVADO");c.imprimir(500);
        c=new C(Ambito.USUARIO);c.p.put("idBoleto",new String[]{"70"});c.fallo=new SQLTransientConnectionException("PRIVADO");c.imprimir(500);
        for(int codigo:new int[]{60049,60050,60051,60052}) {c=new C(Ambito.USUARIO);c.p.put("idBoleto",new String[]{"70"});c.fallo=new SQLException("PRIVADO","TEST",codigo);c.imprimir(codigo==60049?404:codigo==60050?401:403);}
        // Cotizacion publica no modifica saldos; fallo de inicializacion sanitizado.
        C cotizar=post(Ambito.USUARIO);cotizar.p.put("idSeleccion",new String[]{"13"});cotizar.p.put("monto",new String[]{"100"});
        CotizarApuestaServlet cs=new CotizarApuestaServlet();
        PruebaCadenaControlAcceso.inyectar(cs,"apuestaServicio",new ApuestaServicio() {
            @Override public CotizacionApuesta cotizarApuesta(List<Integer> ids,BigDecimal monto,Integer a,Integer b) {throw new ExceptionInInitializerError("PRIVADO");}
        });
        cs.service(cotizar.req,cotizar.res);caso(cotizar.h.status==500&&!cotizar.h.body.toString().contains("PRIVADO"));
        realizacion(new ExceptionInInitializerError("PRIVADO"),500);
        realizacion(new NoClassDefFoundError("PRIVADO"),500);
        realizacion(new SQLTransientConnectionException("PRIVADO"),500);
        realizacion(new SQLException("PRIVADO","TEST",76900),503);
        realizacion(new SQLException("PRIVADO","TEST",60031),409);
        // Consulta con doble JDBC: no publicar billetera de otro usuario y cerrar recursos.
        Class<?> jcl=Class.forName("com.apuestas.controlador.PruebaBilleteraUsuario$Jdbc");
        Constructor<?> ctor=jcl.getDeclaredConstructor(boolean.class);ctor.setAccessible(true);Object j=ctor.newInstance(false);
        Field fila=jcl.getDeclaredField("fila");fila.setAccessible(true);
        ((Map<String,Object>)fila.get(j)).put("IdUsuario",8);
        try {new BilleteraServicio((com.apuestas.dao.BilleteraDAO)j).obtenerBilletera(7);throw new AssertionError("Billetera ajena");}
        catch(SQLException esperado) {Field cerrado=jcl.getDeclaredField("cerrados");cerrado.setAccessible(true);caso(((Set<?>)cerrado.get(j)).size()==3);}
        PruebaHistorialBoletosUsuario.Jdbc historia=new PruebaHistorialBoletosUsuario.Jdbc();historia.detalleHistoricoAjeno=true;
        PruebaHistorialBoletosUsuario.ejecutar(new PruebaHistorialBoletosUsuario.Entrada(),historia,500);casos++;
        System.out.println("Seguridad backend/CSRF/PDF: "+casos+" casos, 0 fallos; sin SQL/SMTP.");
    }
}
