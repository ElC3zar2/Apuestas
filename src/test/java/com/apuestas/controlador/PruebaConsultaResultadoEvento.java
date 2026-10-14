package com.apuestas.controlador;

import com.apuestas.dao.AdministracionResultadosDAO;
import com.apuestas.servicio.AdministracionResultadosServicio;
import com.apuestas.modelo.OperacionAdministracionResultados;
import com.apuestas.seguridad.ControlAccesoAdministrativo;
import com.fasterxml.jackson.databind.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import javax.servlet.http.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;

/** Cadena real de lectura con JDBC/HTTP controlados; nunca abre Azure ni escribe datos. */
public final class PruebaConsultaResultadoEvento {
    private static int pass;
    private static final ObjectMapper JSON=new ObjectMapper();
    static class Jdbc {
        final Map<String,Object> fila=new LinkedHashMap<>();
        int conexiones,psAbiertos,psCerrados,rsAbiertos,rsCerrados,conCerradas,filas=1,fallo;
        Jdbc() {
            fila.put("IdEvento",91);fila.put("EstadoEvento","PENDIENTE_RESULTADO");fila.put("TipoEstadoEvento","EVENTO");
            fila.put("IdResultado",501);fila.put("IdEventoResultado",91);fila.put("EstadoResultado","PENDIENTE");
            fila.put("TipoEstadoResultado","RESULTADO_EVENTO");fila.put("ResultadoTexto","3 - 0");fila.put("Observacion",null);
            fila.put("FechaRegistro",Timestamp.valueOf("2026-10-14 14:00:00.1234567"));fila.put("MarcadorFinalA",3);
            fila.put("MarcadorFinalB",0);fila.put("IdIncidenciaPrimeraAnotacion",null);
        }
        void sinResultado(){for(String k:new ArrayList<>(fila.keySet()))if(!Arrays.asList("IdEvento","EstadoEvento","TipoEstadoEvento").contains(k))fila.put(k,null);}
        Connection conexion() throws SQLException {
            conexiones++;
            if(fallo==1)throw new SQLTransientConnectionException("SECRETO_INTERNO");
            if(fallo==2)throw new ExceptionInInitializerError("SECRETO_INTERNO");
            return proxy(Connection.class,(p,m,a)-> {
                if(m.getName().equals("close")){conCerradas++;return null;}
                if(!m.getName().equals("prepareStatement"))throw new AssertionError("Solo PreparedStatement SELECT, sin escrituras ni transacciones");
                String sql=(String)a[0];exigir(sql.startsWith("SELECT EV.IdEvento")&&sql.endsWith("WHERE EV.IdEvento=?"));
                exigir(!sql.contains("SELECT *")&&sql.contains("RE.IdEvento=EV.IdEvento")&&sql.contains("TipoEstadoEvento")&&sql.contains("TipoEstadoResultado"));
                psAbiertos++;boolean[] enlazado={false},timeout={false};
                return proxy(PreparedStatement.class,(sp,sm,sa)-> {
                    switch(sm.getName()) {
                        case "setInt":exigir(sa[0].equals(1)&&sa[1].equals(91));enlazado[0]=true;return null;
                        case "setQueryTimeout":exigir(sa[0].equals(15));timeout[0]=true;return null;
                        case "close":psCerrados++;return null;
                        case "executeQuery":
                            exigir(enlazado[0]&&timeout[0]);
                            if(fallo==3)throw new SQLTimeoutException("SECRETO_INTERNO");
                            if(fallo==4)throw new SQLException("SECRETO_INTERNO","TEST",1205);
                            if(fallo==5)throw new SQLException("SECRETO_INTERNO","TEST",99999);
                            if(fallo==6)throw new IllegalStateException("SECRETO_INTERNO");
                            rsAbiertos++;int[] pos={0};
                            return proxy(ResultSet.class,(rp,rm,ra)-> {
                                switch(rm.getName()) {
                                    case "close":rsCerrados++;return null;
                                    case "next":return ++pos[0]<=filas;
                                    case "getObject":if(!fila.containsKey(ra[0]))throw new SQLException("SECRETO_INTERNO");return fila.get(ra[0]);
                                    default:throw new AssertionError(rm.getName());
                                }
                            });
                        default:throw new AssertionError(sm.getName());
                    }
                });
            });
        }
    }
    static class Caso {
        final Http h=new Http();final Jdbc j=new Jdbc();final Map<String,String[]> params=new LinkedHashMap<>();boolean directo;
        Caso(){h.ruta=ConsultaResultadoEventoServlet.RUTA;h.method="GET";h.contexto="/BetZone";h.previa=new Sesion();
            h.previa.datos.put("adminIdUsuario",7);h.previa.datos.put("adminIdRol",3);h.previa.datos.put("adminCorreo","admin@example.test");
            h.previa.datos.put("adminRol","ADMINISTRADOR");h.previa.datos.put("adminEstadoUsuario","ACTIVO");params.put("idEvento",new String[]{"91"});}
        JsonNode ejecutar(int esperado)throws Exception {
            ConsultaResultadoEventoServlet servlet=new ConsultaResultadoEventoServlet();Field f=servlet.getClass().getDeclaredField("servicio");f.setAccessible(true);
            f.set(servlet,new AdministracionResultadosServicio(new AdministracionResultadosDAO(){
                @Override protected Connection obtenerConexion() throws SQLException{return j.conexion();}
            }));
            HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)-> {
                if(m.getName().equals("getParameterMap")){exigir("UTF-8".equals(h.encoding));return params;}
                try{return m.invoke(h.req,a);}catch(InvocationTargetException e){throw e.getCause();}
            });
            Map<String,Object> identidad=h.previa==null?null:new HashMap<>(h.previa.datos);
            if(directo)servlet.service(req,h.res);
            else new ControlAccesoAdministrativo().doFilter(req,h.res,(r,s)->servlet.service((HttpServletRequest)r,(HttpServletResponse)s));
            if(h.status!=esperado)throw new AssertionError("HTTP esperado "+esperado+" recibido "+h.status);
            exigir("application/json;charset=UTF-8".equals(h.tipo)&&"no-store".equals(h.headers.get("Cache-Control")));
            exigir(!h.headers.containsKey("Location")&&h.creaciones==0&&!h.body.toString().contains("SECRETO_INTERNO"));
            if(h.previa!=null)exigir(h.previa.datos.equals(identidad));
            exigir(j.psAbiertos==j.psCerrados&&j.rsAbiertos==j.rsCerrados);
            if(j.fallo!=1&&j.fallo!=2)exigir(j.conexiones==j.conCerradas);
            JsonNode n=JSON.readTree(h.body.toString());exigir(n.size()==(esperado==200?5:2)&&n.path("ok").asBoolean()==(esperado==200));
            if(esperado==200) {
                exigir(n.get("idEvento").asInt()==91);
                if(!n.get("resultado").isNull()) {exigir(n.get("resultado").size()==9);
                    exigir(n.at("/resultado/idResultadoEvento").asInt()==501&&n.at("/resultado/idResultado").asInt()==501);}
                exigir(n.get("tieneResultado").asBoolean()==!n.get("resultado").isNull());
            }
            pass++;return n;
        }
    }
    public static void main(String[] args)throws Exception {
        for(String estado:new String[]{"PENDIENTE","OFICIAL","CORREGIDO","ANULADO"}) {
            Caso c=new Caso();c.j.fila.put("EstadoResultado",estado);
            c.j.fila.put("EstadoEvento",estado.equals("OFICIAL")?"FINALIZADO":estado.equals("ANULADO")?"CANCELADO":"PENDIENTE_RESULTADO");
            JsonNode n=c.ejecutar(200);
            exigir(n.at("/resultado/estadoResultado").asText().equals(estado));
            exigir(n.at("/resultado/fechaRegistro").asText().equals("2026-10-14T14:00:00.123456700"));
            if(estado.equals("PENDIENTE"))System.out.println("JSON_CON_RESULTADO="+n);
        }
        Caso c=new Caso();c.j.sinResultado();c.j.fila.put("EstadoEvento","EN_VIVO");System.out.println("JSON_SIN_RESULTADO="+c.ejecutar(200));
        c=new Caso();c.j.filas=0;JsonNode error=c.ejecutar(404);exigir(error.get("mensaje").asText().equals("No se encontró el recurso solicitado."));
        c=new Caso();c.params.clear();c.ejecutar(400);
        for(String valor:new String[]{"","0","-1","abc","1.0","2147483648","91 "," 91","91x","91 OR 1=1"}) {
            c=new Caso();c.params.put("idEvento",new String[]{valor});c.ejecutar(400);exigir(c.j.conexiones==0);
        }
        for(String[] valores:new String[][]{new String[]{"91","91"},new String[0],null,new String[]{null}}) {
            c=new Caso();c.params.put("idEvento",valores);c.ejecutar(400);
        }
        for(String intruso:new String[]{"idUsuarioProceso","idResultadoEvento","tabla","otro"}) {c=new Caso();c.params.put(intruso,new String[]{"99"});c.ejecutar(400);}
        for(String rol:new String[]{"ADMINISTRADOR","OPERADOR_EVENTOS","AUDITOR","CAJERO","USUARIO","CASA"}) {
            c=new Caso();c.h.previa.datos.put("adminRol",rol);boolean permitido=Arrays.asList("ADMINISTRADOR","OPERADOR_EVENTOS","AUDITOR").contains(rol);
            c.ejecutar(permitido?200:403);if(!permitido)exigir(c.j.conexiones==0);
        }
        c=new Caso();c.h.previa=null;c.ejecutar(401);
        c=new Caso();c.h.previa.expirada=true;c.ejecutar(401);
        c=new Caso();c.h.previa.datos.put("adminEstadoUsuario","SUSPENDIDO");c.ejecutar(403);
        c=new Caso();c.h.previa.datos.put("idUsuario",7);c.ejecutar(403);
        c=new Caso();c.h.previa.datos.remove("adminIdRol");c.ejecutar(403);
        c=new Caso();c.h.previa.falloLectura=true;c.ejecutar(500);
        for(String metodo:new String[]{"POST","PUT","PATCH","DELETE","HEAD","OPTIONS"}) {c=new Caso();c.h.method=metodo;c.ejecutar(405);exigir("GET".equals(c.h.headers.get("Allow"))&&c.j.conexiones==0);}
        c=new Caso();c.directo=true;c.h.previa=null;c.ejecutar(401);
        for(int fallo=1;fallo<=6;fallo++){c=new Caso();c.j.fallo=fallo;c.ejecutar(fallo==1||fallo==3||fallo==4?503:500);}
        c=new Caso();c.j.fila.put("IdEventoResultado",99);c.ejecutar(500);
        c=new Caso();c.j.fila.put("IdEvento",99);c.ejecutar(500);
        c=new Caso();c.j.filas=2;c.ejecutar(500);
        c=new Caso();c.j.fila.put("TipoEstadoResultado","EVENTO");c.ejecutar(500);
        c=new Caso();c.j.fila.put("TipoEstadoEvento","RESULTADO_EVENTO");c.ejecutar(500);
        for(String col:new String[]{"IdResultado","MarcadorFinalA","IdIncidenciaPrimeraAnotacion","FechaRegistro"}) {
            c=new Caso();c.j.fila.put(col,new BigDecimal("1.5"));c.ejecutar(500);
        }
        c=new Caso();c.j.fila.put("MarcadorFinalA",null);c.j.fila.put("MarcadorFinalB",null);
        exigir(c.ejecutar(200).at("/resultado/marcadorFinalA").isNull());
        c=new Caso();c.j.fila.put("IdIncidenciaPrimeraAnotacion",5000000000L);exigir(c.ejecutar(200).at("/resultado/idIncidenciaPrimeraAnotacion").asLong()==5000000000L);
        c=new Caso();c.j.fila.put("Observacion","Texto \"citado\"\n\u00f1");exigir(c.ejecutar(200).at("/resultado/observacion").asText().equals(c.j.fila.get("Observacion")));
        c=new Caso();c.j.sinResultado();c.j.fila.put("ResultadoTexto","inconsistente");c.ejecutar(500);
        c=new Caso();c.j.fila.put("EstadoResultado","OTRO");c.ejecutar(500);
        // Regresion minima: cinco POST reales con sus dobles previos, sin alterar pruebas anteriores.
        for(OperacionAdministracionResultados op:OperacionAdministracionResultados.values()) {
            new PruebaAdministracionResultados.Caso(op).ejecutar(200);pass++;
            PruebaAdministracionResultados.Caso auditor=new PruebaAdministracionResultados.Caso(op);
            auditor.h.previa.datos.put("adminRol","AUDITOR");auditor.ejecutar(403);pass++;
            PruebaAdministracionResultados.Caso operador=new PruebaAdministracionResultados.Caso(op);
            operador.h.previa.datos.put("adminRol","OPERADOR_EVENTOS");operador.ejecutar(op.soloAdministrador?403:200);pass++;
        }
        System.out.println("Consulta resultado por evento: "+pass+" PASS, 0 FAIL; sin SQL real.");
    }
}
