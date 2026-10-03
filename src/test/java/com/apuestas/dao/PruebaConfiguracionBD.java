package com.apuestas.dao;

import java.io.*;
import java.net.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.zip.*;
import javax.tools.ToolProvider;

/** Inicializa la clase real en procesos aislados, sustituyendo solo Hikari por dobles sin red. */
public class PruebaConfiguracionBD {
    private static final String[] CLAVES={"db.url","db.usuario","db.password"};
    private static final String[] VALORES={"jdbc:sqlserver://servidor-ficticio.invalid","usuario-ficticio","clave-ficticia-prueba"};
    private static void exigir(boolean valor){if(!valor)throw new AssertionError("Validacion de configuracion fallida");}

    private static Path dobles() throws Exception {
        Path raiz=Paths.get("target","prueba-config-bd").toAbsolutePath();
        Path paquete=raiz.resolve("com/zaxxer/hikari");Files.createDirectories(paquete);
        StringBuilder config=new StringBuilder("package com.zaxxer.hikari; public class HikariConfig { public java.util.Map<String,Object> valores=new java.util.HashMap<>();");
        String[] nombres={"DriverClassName","JdbcUrl","Username","Password","PoolName"};
        for(String n:nombres)config.append("public void set").append(n).append("(String v){valores.put(\"").append(n).append("\",v);}");
        for(String n:new String[]{"MaximumPoolSize","MinimumIdle"})config.append("public void set").append(n).append("(int v){valores.put(\"").append(n).append("\",v);}");
        for(String n:new String[]{"ConnectionTimeout","IdleTimeout","MaxLifetime"})config.append("public void set").append(n).append("(long v){valores.put(\"").append(n).append("\",v);}");
        config.append("}");
        Files.writeString(paquete.resolve("HikariConfig.java"),config.toString());
        Files.writeString(paquete.resolve("HikariDataSource.java"),
            "package com.zaxxer.hikari; public class HikariDataSource {"+
            " public static HikariConfig configuracion; public static boolean cerrado;"+
            " public HikariDataSource(HikariConfig c){configuracion=c; if(Boolean.getBoolean(\"fallo.simulado\"))throw new IllegalStateException(c.valores.toString());}"+
            " public java.sql.Connection getConnection(){throw new AssertionError(\"Prohibida conexion SQL\");}"+
            " public boolean isClosed(){return cerrado;} public void close(){cerrado=true;} }");
        int resultado=ToolProvider.getSystemJavaCompiler().run(null,null,null,"-d",raiz.toString(),
                paquete.resolve("HikariConfig.java").toString(),paquete.resolve("HikariDataSource.java").toString());
        exigir(resultado==0);return raiz;
    }

    private static void hijo(String modo,Path dobles, String clave, String valor) throws Exception {
        Path clase=Paths.get("target/classes/com/apuestas/dao/ConexionBD.class");
        try(URLClassLoader loader=new URLClassLoader(new URL[]{dobles.toUri().toURL()},ClassLoader.getPlatformClassLoader()){
            @Override public InputStream getResourceAsStream(String nombre) {
                if (!nombre.equals("config.properties")) return super.getResourceAsStream(nombre);
                if (modo.equals("ausente")) return null;
                if (modo.equals("lectura")) return new InputStream() {
                    public int read() throws IOException { throw new IOException(VALORES[2]); }
                };
                Properties propiedades = new Properties();
                for(int i=0;i<CLAVES.length;i++) propiedades.setProperty(CLAVES[i],VALORES[i]);
                if (!clave.equals("-")) {
                    if (valor.equals("NULL")) propiedades.remove(clave);
                    else propiedades.setProperty(clave,valor);
                }
                try {
                    ByteArrayOutputStream bytes=new ByteArrayOutputStream();
                    propiedades.store(bytes,null);
                    return new ByteArrayInputStream(bytes.toByteArray());
                } catch(IOException e) { throw new AssertionError(); }
            }
            @Override protected Class<?> findClass(String nombre)throws ClassNotFoundException {
                if(nombre.equals("com.apuestas.dao.ConexionBD")){
                    try{byte[] bytes=Files.readAllBytes(clase);return defineClass(nombre,bytes,0,bytes.length);}
                    catch(IOException e){throw new ClassNotFoundException(nombre);}
                }
                return super.findClass(nombre);
            }
        }){
            exigir(loader.getResource("config.properties")==null);
            if(modo.equals("proveedor"))System.setProperty("fallo.simulado","true");
            Throwable error=null;Class<?> conexion=null;
            try {conexion=Class.forName("com.apuestas.dao.ConexionBD",true,loader);}
            catch(ExceptionInInitializerError e){error=e;}
            if(modo.equals("correcto")){
                exigir(error==null && conexion!=null);
                Class<?> datasource=loader.loadClass("com.zaxxer.hikari.HikariDataSource");
                Object config=datasource.getField("configuracion").get(null);
                Map<?,?> valores=(Map<?,?>)config.getClass().getField("valores").get(config);
                exigir(valores.get("JdbcUrl").equals(VALORES[0]));
                exigir(valores.get("Username").equals(VALORES[1]));
                exigir(valores.get("Password").equals(VALORES[2]));
                exigir(valores.get("MaximumPoolSize").equals(10) && valores.get("MinimumIdle").equals(2));
                exigir(valores.get("ConnectionTimeout").equals(30000L));
                exigir(valores.get("IdleTimeout").equals(600000L));
                exigir(valores.get("MaxLifetime").equals(1800000L));
                exigir(valores.get("PoolName").equals("PlataformaApuestasPool"));
                exigir(valores.get("DriverClassName").equals("com.microsoft.sqlserver.jdbc.SQLServerDriver"));
                conexion.getMethod("cerrarPool").invoke(null);
                conexion.getMethod("cerrarPool").invoke(null);
                exigir(Boolean.TRUE.equals(datasource.getField("cerrado").get(null)));
            }else{
                exigir(error!=null);
                StringWriter texto=new StringWriter();error.printStackTrace(new PrintWriter(texto));
                for(String secreto:VALORES)exigir(!texto.toString().contains(secreto));
                if(modo.startsWith("db."))exigir(texto.toString().contains(modo));
                else exigir(error.getCause()==null);
            }
        }
        System.out.println("OK hijo");
    }

    private static void proceso(Path dobles,String modo,String variable,String valor)throws Exception{
        String ejecutableJava=Paths.get(System.getProperty("java.home"),"bin","java.exe").toString();
        ProcessBuilder pb=new ProcessBuilder(ejecutableJava,"-cp",System.getProperty("java.class.path"),
                PruebaConfiguracionBD.class.getName(),"hijo",modo,dobles.toString(),
                variable==null?"-":variable,valor==null?"NULL":valor);
        pb.redirectErrorStream(true);
        Process proceso=pb.start();
        if(!proceso.waitFor(30,TimeUnit.SECONDS)){proceso.destroyForcibly();throw new AssertionError("Tiempo de prueba excedido");}
        String salida=new String(proceso.getInputStream().readAllBytes(),java.nio.charset.StandardCharsets.UTF_8);
        exigir(proceso.exitValue()==0 && salida.trim().equals("OK hijo"));
    }

    public static void main(String[] args)throws Exception{
        if(args.length>0 && args[0].equals("hijo")){hijo(args[1],Paths.get(args[2]),args[3],args[4]);return;}
        if(args.length>0 && args[0].equals("war")){
            try(ZipFile war=new ZipFile("target/PlataformaApuestas-1.0-SNAPSHOT.war")){
                exigir(war.getEntry("WEB-INF/classes/config.properties")!=null);
                exigir(war.getEntry("WEB-INF/classes/reportes/boleto_cliente.jrxml")!=null);
            }
            System.out.println("OK: 1 caso de WAR con config.properties y con recursos de reportes.");return;
        }
        if(args.length>0 && args[0].equals("local")){
            Properties p=new Properties();
            try(InputStream in=Files.newInputStream(Paths.get("src/main/resources/config.properties"))){p.load(in);}
            for(String clave:CLAVES){
                String valor=p.getProperty(clave);
                System.out.println(clave+": "+(valor==null?"ausente":valor.trim().isEmpty()?"vacia":"presente"));
            }
            return;
        }
        Path dobles=dobles();int casos=0;
        proceso(dobles,"ausente",null,null);casos++;
        proceso(dobles,"lectura",null,null);casos++;
        for(String variable:CLAVES){
            for(String valor:new String[]{null,"","   "}){proceso(dobles,variable,variable,valor);casos++;}
        }
        proceso(dobles,"correcto",null,null);casos++;
        proceso(dobles,"proveedor",null,null);casos++;
        System.out.println("OK: "+casos+" casos de inicializacion real de ConexionBD con Hikari simulado, sin SQL.");
    }
}