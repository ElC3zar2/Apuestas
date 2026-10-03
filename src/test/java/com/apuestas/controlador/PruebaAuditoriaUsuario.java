package com.apuestas.controlador;
import com.apuestas.dao.*;
import com.apuestas.modelo.*;
import com.apuestas.servicio.*;
import com.apuestas.seguridad.EncriptadorContrasena;
import com.apuestas.reporte.ReporteBoletoServicio;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.nio.file.*;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.*;
import javax.servlet.*;
import javax.servlet.http.*;

/** Auditoria sin red: dependencias externas sustituidas por dobles estrictos. */
public class PruebaAuditoriaUsuario {
    static int casos, fallos;
    interface Prueba { void ejecutar() throws Exception; }
    static void caso(String nombre, Prueba p) {
        casos++;
        try { p.ejecutar(); }
        catch(Throwable e) { fallos++; System.out.println("FALLO: "+nombre+" ["+e.getClass().getSimpleName()+"]"); }
    }
    static void exigir(boolean b) { if(!b) throw new AssertionError(); }
    @SuppressWarnings("unchecked") static <T> T proxy(Class<T> c, InvocationHandler h) {
        return (T)Proxy.newProxyInstance(c.getClassLoader(),new Class<?>[]{c},h);
    }
    static void inyectar(Object destino,String campo,Object valor) throws Exception {
        Field f=destino.getClass().getDeclaredField(campo); f.setAccessible(true); f.set(destino,valor);
    }
    static class Http {
        int estado=200, consultas, pdfs;
        Object id=7, rol="USUARIO";
        boolean sesion=true, expirada;
        String tipo, forward;
        Map<String,String> parametros=new HashMap<>(), headers=new HashMap<>();
        Map<String,Object> atributos=new HashMap<>();
        StringWriter texto=new StringWriter(); ByteArrayOutputStream bytes=new ByteArrayOutputStream();
        HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)->{
            switch(m.getName()) {
                case "getParameter": return parametros.get(a[0]);
                case "getParameterValues": return new String[]{"1"};
                case "setCharacterEncoding": return null;
                case "getSession":
                    exigir(a!=null && Boolean.FALSE.equals(a[0]));
                    return !sesion?null:proxy(HttpSession.class,(sp,sm,sa)->{
                        exigir(sm.getName().equals("getAttribute"));
                        if(expirada) throw new IllegalStateException();
                        return "idUsuario".equals(sa[0])?id:"rol".equals(sa[0])?rol:null;
                    });
                case "setAttribute": atributos.put((String)a[0],a[1]); return null;
                case "getRequestDispatcher":
                    return proxy(RequestDispatcher.class,(dp,dm,da)->{exigir(dm.getName().equals("forward")); forward=(String)a[0];return null;});
                default: throw new AssertionError("Request no permitido");
            }
        });
        HttpServletResponse res=proxy(HttpServletResponse.class,(p,m,a)->{
            switch(m.getName()) {
                case "setStatus": estado=(Integer)a[0];return null;
                case "setContentType": tipo=(String)a[0];return null;
                case "setCharacterEncoding": case "setContentLength": return null;
                case "setHeader": headers.put((String)a[0],(String)a[1]);return null;
                case "getWriter": return new PrintWriter(texto);
                case "isCommitted": return false;
                case "reset": headers.clear(); texto.getBuffer().setLength(0); return null;
                case "getOutputStream": return new ServletOutputStream(){
                    public void write(int b){bytes.write(b);}
                    public boolean isReady(){return true;}
                    public void setWriteListener(WriteListener l){}
                };
                default: throw new AssertionError("Response no permitida");
            }
        });
    }
    static Usuario usuario(String clave,String correo) {
        return new Usuario("Nombre","Apellido",correo,clave,LocalDate.now().minusYears(25),
                "M","+50212345678","PASAPORTE","PRUEBA",2,null,"Ciudad","Direccion");
    }
    static UsuarioServicio registroFake(int[] llamadas) {
        return new UsuarioServicio(new UsuarioDAO(){
            @Override public int registrarCliente(Usuario u) {
                llamadas[0]++; exigir(u.getContrasena().startsWith("$2a$12$"));return 7;
            }
        });
    }
    static void pruebaRegistro(String clave,String correo,boolean valido) throws Exception {
        int[] llamadas={0}; Usuario u=usuario(clave,correo);
        try { exigir(registroFake(llamadas).registrarCliente(u)==7); exigir(valido); }
        catch(IllegalArgumentException e){exigir(!valido);}
        exigir(llamadas[0]==(valido?1:0));
        if(valido) exigir(EncriptadorContrasena.verificar(clave,u.getContrasena()));
    }
    static void imprimir(Object id,Object rol,boolean expirada,int propietario,int esperado) throws Exception {
        Http h=new Http();h.id=id;h.rol=rol;h.expirada=expirada;
        h.parametros.put("idBoleto","12");h.parametros.put("idUsuario","999");
        ImprimirBoletoServlet servlet=new ImprimirBoletoServlet();servlet.init();
        inyectar(servlet,"apuestaServicio",new ApuestaServicio(){
            @Override public Boleto obtenerBoletoPorId(int uid,int bid) {
                h.consultas++;exigir(uid==7 && bid==12);
                Boleto b=new Boleto();b.setIdUsuario(propietario);b.setIdBoleto(12);b.setCodigoBoleto("test");return b;
            }
        });
        inyectar(servlet,"reporteBoletoServicio",new ReporteBoletoServicio(){
            @Override public byte[] generarBoleto(Boleto b){h.pdfs++;return "%PDF-fake".getBytes();}
        });
        servlet.doGet(h.req,h.res);
        exigir(h.estado==esperado);
        exigir(h.headers.getOrDefault("Cache-Control","").contains("no-store"));
        exigir(h.pdfs==(esperado==200?1:0));
        if(esperado==401 || !"USUARIO".equals(rol)) exigir(h.consultas==0);
    }
    static void errorSql(Class<?> clase,int codigo,int estado) throws Exception {
        Http h=new Http(); h.parametros.put("idDeporte","1");h.parametros.put("idEvento","1");h.parametros.put("monto","10");
        HttpServlet s=(HttpServlet)clase.getDeclaredConstructor().newInstance();s.init();
        if(s instanceof CotizarApuestaServlet) {
            inyectar(s,"apuestaServicio",new ApuestaServicio(){
                @Override public CotizacionApuesta cotizarApuesta(List<Integer> ids,BigDecimal m)throws SQLException{throw new SQLException("INTERNO_PRIVADO","X",codigo);}
            });
            ((CotizarApuestaServlet)s).doPost(h.req,h.res);
        } else {
            inyectar(s,"exploracionEventoServicio",new ExploracionEventoServicio(){
                @Override public List<EventoExploracion> listarEventos(int d,String v,int hp,int c)throws SQLException{throw new SQLException("INTERNO_PRIVADO","X",codigo);}
                @Override public DetalleEventoExploracion obtenerDetalleEvento(int d,int hp)throws SQLException{throw new SQLException("INTERNO_PRIVADO","X",codigo);}
            });
            if(s instanceof EventosExploracionServlet)((EventosExploracionServlet)s).doGet(h.req,h.res);
            else ((DetalleEventoExploracionServlet)s).doGet(h.req,h.res);
        }
        exigir(h.estado==estado && !h.texto.toString().contains("INTERNO_PRIVADO"));
        exigir(new ObjectMapper().readTree(h.texto.toString()) != null);
    }
    static void registroHttp(Exception error,int esperado) throws Exception {
        Http h=new Http();
        h.parametros.put("fechaNacimiento","1990-01-01");h.parametros.put("idPais","2");
        h.parametros.put("ciudadExterior","Ciudad");h.parametros.put("idPaisTelefono","2");h.parametros.put("telefono","12345678");
        RegistroUsuarioServlet s=new RegistroUsuarioServlet();s.init();
        inyectar(s,"ubicacionDAO",new UbicacionDAO(){
            @Override public boolean esGuatemala(int id){return false;}
            @Override public String obtenerCodigoTelefonicoPorPais(int id){return "+502";}
            @Override public List<Pais> listarPaisesActivos(){return Collections.emptyList();}
            @Override public List<Departamento> listarDepartamentosGuatemala(){return Collections.emptyList();}
        });
        inyectar(s,"usuarioServicio",new UsuarioServicio(){
            @Override public int registrarCliente(Usuario u)throws SQLException{
                if(error instanceof SQLException)throw (SQLException)error;
                if(error instanceof RuntimeException)throw (RuntimeException)error;
                return 7;
            }
        });
        s.doPost(h.req,h.res);
        exigir(h.estado==esperado && "no-store".equals(h.headers.get("Cache-Control")));
        exigir(!String.valueOf(h.atributos.get("error")).contains("INTERNO_PRIVADO"));
    }
    static void municipio(String entrada,int esperado,boolean error) throws Exception {
        Http h=new Http();h.parametros.put("idDepartamento",entrada);
        MunicipioServlet s=new MunicipioServlet();s.init();
        inyectar(s,"ubicacionDAO",new UbicacionDAO(){
            @Override public List<Municipio> listarMunicipiosPorDepartamento(int id)throws SQLException {
                h.consultas++;exigir(id==7);
                if(error)throw new SQLException("INTERNO_PRIVADO");
                Municipio m=new Municipio();m.setIdMunicipio(1);m.setNombre("Nombre\n\u0001");
                return Arrays.asList(m);
            }
        });
        s.doGet(h.req,h.res);
        exigir(h.estado==esperado && !h.texto.toString().contains("INTERNO_PRIVADO"));
        exigir(new ObjectMapper().readTree(h.texto.toString()) != null);
        if(esperado==400)exigir(h.consultas==0);
    }
    static void exploracionCorrecta(int tipo) throws Exception {
        Http h=new Http();h.parametros.put("idDeporte","7");h.parametros.put("idEvento","7");h.parametros.put("monto","10");
        if(tipo==0) {
            DeportesExploracionServlet s=new DeportesExploracionServlet();s.init();
            inyectar(s,"deporteServicio",new DeporteServicio(){
                @Override public List<Deporte> listarDeportesActivos(){return Collections.emptyList();}
            });s.doGet(h.req,h.res);
        }else if(tipo==1){
            LigasExploracionServlet s=new LigasExploracionServlet();s.init();
            inyectar(s,"ligaServicio",new LigaServicio(){
                @Override public List<Liga> listarLigasPorDeporte(int id){exigir(id==7);return Collections.emptyList();}
            });s.doGet(h.req,h.res);
        }else if(tipo==2 || tipo==3){
            ExploracionEventoServicio fake=new ExploracionEventoServicio(){
                @Override public List<EventoExploracion> listarEventos(int d,String v,int hp,int c){exigir(d==7);return Collections.emptyList();}
                @Override public DetalleEventoExploracion obtenerDetalleEvento(int id,int hp){exigir(id==7);return new DetalleEventoExploracion();}
            };
            if(tipo==2){EventosExploracionServlet s=new EventosExploracionServlet();s.init();inyectar(s,"exploracionEventoServicio",fake);s.doGet(h.req,h.res);}
            else{DetalleEventoExploracionServlet s=new DetalleEventoExploracionServlet();s.init();inyectar(s,"exploracionEventoServicio",fake);s.doGet(h.req,h.res);}
        }else{
            CotizarApuestaServlet s=new CotizarApuestaServlet();s.init();
            inyectar(s,"apuestaServicio",new ApuestaServicio(){
                @Override public CotizacionApuesta cotizarApuesta(List<Integer> ids,BigDecimal monto){exigir(ids.equals(Arrays.asList(1)));return new CotizacionApuesta();}
            });s.doPost(h.req,h.res);
        }
        exigir(h.estado==200 && "application/json;charset=UTF-8".equals(h.tipo));
        exigir(new ObjectMapper().readTree(h.texto.toString()).get("ok").asBoolean());
    }
    public static void main(String[] args)throws Exception {
        StringBuilder texto=new StringBuilder("ñ\"\\");for(char c=0;c<32;c++)texto.append(c);
        for(Class<?> c:Arrays.asList(DeportesExploracionServlet.class,LigasExploracionServlet.class,
                EventosExploracionServlet.class,DetalleEventoExploracionServlet.class,CotizarApuestaServlet.class,MunicipioServlet.class)) {
            caso("JSON controles "+c.getSimpleName(),()->{
                Method m=c.getDeclaredMethod("escaparJson",String.class);m.setAccessible(true);
                String escapado=(String)m.invoke(c.getDeclaredConstructor().newInstance(),texto.toString());
                exigir(new ObjectMapper().readTree("\""+escapado+"\"").asText().equals(texto.toString()));
            });
        }
        for(String clave:Arrays.asList("a".repeat(73),"é".repeat(37)," ".repeat(8),"1234567")){
            caso("registro clave invalida",()->pruebaRegistro(clave,"a@example.invalid",false));
        }
        for(String correo:Arrays.asList("abc","a@@b.test","a".repeat(151)+"@b.test")) {
            caso("registro correo invalido",()->pruebaRegistro("ClaveSegura123",correo,false));
        }
        for(String clave:Arrays.asList("12345678","a".repeat(72),"é".repeat(36))){
            caso("registro valido BCrypt",()->pruebaRegistro(clave,"a@example.invalid",true));
        }
        for(Object rol:new Object[]{null,"ADMINISTRADOR","CAJERO","usuario","USUARIO "})
            caso("imprimir rol",()->imprimir(7,rol,false,7,403));
        for(Object id:new Object[]{null,0,-1,1.5,4294967303L,Double.NaN,"abc"})
            caso("imprimir identidad",()->imprimir(id,"USUARIO",false,7,401));
        caso("imprimir sesion expirada",()->imprimir(7,"USUARIO",true,7,401));
        caso("imprimir IDOR",()->imprimir(7,"USUARIO",false,8,403));
        caso("imprimir propio",()->imprimir(7,"USUARIO",false,7,200));
        for(int codigo:new int[]{64006,64007,64008,64009,64010,99999})
            caso("error eventos "+codigo,()->errorSql(EventosExploracionServlet.class,codigo,codigo==64007?404:codigo==99999?500:400));
        for(int codigo:new int[]{64012,64013,64014,99999})
            caso("error detalle "+codigo,()->errorSql(DetalleEventoExploracionServlet.class,codigo,codigo==64014?404:codigo==99999?500:400));
        for(int codigo:new int[]{60005,60054,99999})
            caso("error cotizar "+codigo,()->errorSql(CotizarApuestaServlet.class,codigo,codigo==60005?400:codigo==60054?409:500));
        caso("registro SQL privado",()->registroHttp(new SQLException("INTERNO_PRIVADO"),500));
        caso("registro runtime privado",()->registroHttp(new IllegalStateException("INTERNO_PRIVADO"),500));
        caso("registro validacion privada",()->registroHttp(new IllegalArgumentException("INTERNO_PRIVADO"),400));
        caso("registro correcto",()->registroHttp(null,200));
        caso("config local disponible y excluida del control de versiones",()->{
            String pom=Files.readString(Paths.get("pom.xml"));
            exigir(!pom.contains("<exclude>config.properties</exclude>")
                    && !pom.contains("<packagingExcludes>**/config.properties</packagingExcludes>"));
            exigir(Files.readAllLines(Paths.get(".gitignore")).contains("src/main/resources/config.properties"));
        });        for(String entrada:Arrays.asList("abc","0","-1","2147483648")) {
            caso("municipios parametro invalido",()->municipio(entrada,400,false));
        }
        caso("municipios correcto",()->municipio("7",200,false));
        caso("municipios SQL generico",()->municipio("7",500,true));
        caso("municipios sin filtro",()->municipio(null,200,false));
        for(int tipo=0;tipo<5;tipo++){final int indice=tipo;caso("exploracion/cotizacion correcta "+tipo,()->exploracionCorrecta(indice));}
        System.out.println("Auditoria: "+casos+" casos, "+fallos+" fallos.");
        if(fallos>0)throw new AssertionError("Defectos reproducidos");
    }
}