package com.apuestas.controlador;

import com.apuestas.dao.*;
import com.apuestas.modelo.*;
import com.apuestas.seguridad.*;
import com.apuestas.servicio.ConsultasAdministrativasServicio;
import com.fasterxml.jackson.databind.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import javax.servlet.http.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;

/** Cadena filtro/servlet/servicio/DAO real con JDBC controlado. Sin conexiones ni escrituras reales. */
public final class PruebaDetalleEventoAdministrativo {
    private static int casos;
    private static final ObjectMapper JSON=new ObjectMapper();
    private static final Timestamp FECHA=Timestamp.valueOf("2026-10-16 12:30:00.1234567");
    private static Map<String,Object> fila(Object... values){
        Map<String,Object> row=new LinkedHashMap<>();for(int i=0;i<values.length;i+=2)row.put((String)values[i],values[i+1]);return row;
    }
    static Map<String,Object> participante(int id,int order,String nombre){
        return fila("IdEventoParticipante",100+id,"OrdenParticipante",(short)order,"EsLocal",order==1,"MarcadorActual",null,
                "IdParticipante",id,"Participante",nombre,"TipoParticipante","EQUIPO","IdPais",null,"Pais",null,"CodigoPais",null);
    }
    static Map<String,Object> mercado(int id,String type,Integer selection,Integer participant,String name){
        return fila("IdMercado",id,"Mercado",id==21?"Ganador del partido":type,"DescripcionMercado",null,"TipoMercado",type,
                "EstadoMercado","BORRADOR","TipoEstadoMercado","MERCADO","IdSeleccion",selection,"Seleccion",name,
                "SeleccionActiva",selection==null?null:true,"IdParticipante",participant,"IdCuota",null,"Valor",null,
                "ValorResultado",null,"FechaInicioCuota",null,"FechaFinCuota",null,"CuotaActiva",null,
                "ResultadoSeleccion",null,"FechaResolucion",null);
    }
    static class Jdbc {
        List<Map<String,Object>> evento=new ArrayList<>(),participantes=new ArrayList<>(),mercados=new ArrayList<>();
        int conexiones,cerradas,statements,cerrados,resultados,resultadosCerrados,commits,rollbacks,consultas,isolation=Connection.TRANSACTION_READ_COMMITTED;
        boolean auto=true;int fallo;
        Jdbc(){
            evento.add(fila("IdEvento",10,"Evento","Partido prueba","IdLiga",3,"Liga","LALIGA","IdDeporte",1,"Deporte","Fútbol",
                    "EstadoEvento","BORRADOR","TipoEstadoEvento","EVENTO","FechaInicio",FECHA,"FechaFin",null,"EsSimulado",false,
                    "DuracionSimulacionSegundos",null,"FechaInicioRealUtc",null,"FechaFinRealUtc",null,"VersionFila",new byte[8],"ResultadoTexto",null,"EstadoResultado",null));
            participantes.add(participante(31,1,"FC Barcelona"));participantes.add(participante(32,2,"Real Sociedad"));
            mercados.add(mercado(21,"CONVENCIONAL",null,null,null));
        }
        Connection conexion() throws SQLException {
            conexiones++;if(fallo==1)throw new SQLTransientConnectionException("SECRETO_SQL");
            return proxy(Connection.class,(p,m,a)->{
                switch(m.getName()){
                    case "getAutoCommit":return auto;
                    case "getTransactionIsolation":return isolation;
                    case "setTransactionIsolation":isolation=(Integer)a[0];return null;
                    case "setAutoCommit":auto=(Boolean)a[0];return null;
                    case "commit":commits++;return null;
                    case "rollback":rollbacks++;return null;
                    case "close":cerradas++;return null;
                    case "prepareStatement":
                        exigir(!auto&&isolation==Connection.TRANSACTION_SERIALIZABLE);
                        String sql=(String)a[0];exigir(sql.startsWith("SELECT ")&&!sql.contains("SELECT *")&&!sql.contains(";")&&!sql.contains("sp_ObtenerDetalleEventoExploracion"));
                        List<Map<String,Object>> rows;
                        if(sql.startsWith("SELECT EV.IdEvento"))rows=evento;
                        else if(sql.startsWith("SELECT EP.IdEventoParticipante"))rows=participantes;
                        else {exigir(sql.startsWith("SELECT M.IdMercado")&&sql.contains("LEFT JOIN dbo.Seleccion")&&sql.contains("OUTER APPLY (SELECT TOP (1)")&&sql.contains("Q.Activo=1")&&sql.contains("ORDER BY Q.FechaInicio DESC, Q.IdCuota DESC"));rows=mercados;}
                        statements++;boolean[] bound={false},timeout={false};
                        return proxy(PreparedStatement.class,(sp,sm,sa)->{
                            switch(sm.getName()){
                                case "setInt":exigir(sa[0].equals(1)&&sa[1].equals(10));bound[0]=true;return null;
                                case "setQueryTimeout":exigir(sa[0].equals(15));timeout[0]=true;return null;
                                case "close":cerrados++;return null;
                                case "executeQuery":
                                    exigir(bound[0]&&timeout[0]);consultas++;
                                    if(fallo==2)throw new SQLTimeoutException("SECRETO_SQL");
                                    if(fallo==3)throw new SQLException("SECRETO_SQL","TEST",1205);
                                    if(fallo==4)throw new SQLException("SECRETO_SQL","TEST",99999);
                                    resultados++;int[] index={-1};
                                    return proxy(ResultSet.class,(rp,rm,ra)->{
                                        switch(rm.getName()){
                                            case "next":return ++index[0]<rows.size();
                                            case "getObject":exigir(rows.get(index[0]).containsKey(ra[0]));return rows.get(index[0]).get(ra[0]);
                                            case "close":resultadosCerrados++;return null;
                                            default:throw new AssertionError(rm.getName());
                                        }
                                    });
                                default:throw new AssertionError(sm.getName());
                            }
                        });
                    default:throw new AssertionError(m.getName());
                }
            });
        }
        DetalleEventoAdministrativoDAO dao(){return new DetalleEventoAdministrativoDAO(){@Override protected Connection obtenerConexion()throws SQLException{return conexion();}};}
        void cerrado(){exigir(statements==cerrados&&resultados==resultadosCerrados&&cerradas==conexiones-(fallo==1?1:0)&&auto&&isolation==Connection.TRANSACTION_READ_COMMITTED);}
    }
    static class Caso {
        final Http h=new Http();final Jdbc jdbc=new Jdbc();final Map<String,String[]> params=new LinkedHashMap<>();
        Caso(){h.ruta=OperacionConsultaAdministrativa.DETALLE_EVENTO.ruta;h.method="GET";PruebaCierreAdministrativo.sesion(h,"ADMINISTRADOR");params.put("idEvento",new String[]{"10"});}
        JsonNode ejecutar(int status)throws Exception{
            ConsultasAdministrativasServlet servlet=new ConsultasAdministrativasServlet();
            Field field=servlet.getClass().getDeclaredField("servicio");field.setAccessible(true);
            field.set(servlet,new ConsultasAdministrativasServicio(new EventoDAO(),new AdministracionUsuarioDAO(),new UbicacionDAO(),jdbc.dao()));
            HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)->{
                if(m.getName().equals("getParameterMap")){exigir("UTF-8".equals(h.encoding));return params;}
                try{return m.invoke(h.req,a);}catch(InvocationTargetException e){throw e.getCause();}
            });
            Map<String,Object> identidad=h.previa==null?null:new HashMap<>(h.previa.datos);
            new ControlAccesoAdministrativo().doFilter(req,h.res,(r,s)->servlet.service((HttpServletRequest)r,(HttpServletResponse)s));
            if(h.status!=status)throw new AssertionError("HTTP esperado "+status+", recibido "+h.status+": "+h.body);
            exigir(h.creaciones==0&&"application/json;charset=UTF-8".equals(h.tipo)&&"no-store".equals(h.headers.get("Cache-Control"))&&!h.headers.containsKey("Location"));
            exigir(!h.body.toString().contains("SECRETO_SQL")&&!h.body.toString().contains("SQLException"));
            if(h.previa!=null)exigir(h.previa.datos.equals(identidad));jdbc.cerrado();
            JsonNode json=JSON.readTree(h.body.toString());exigir(json.path("ok").asBoolean()==(status==200));casos++;return json;
        }
    }
    public static void main(String[] args)throws Exception{
        Caso c=new Caso();JsonNode n=c.ejecutar(200);
        exigir(n.at("/evento/idEvento").asInt()==10&&n.at("/evento/mercados/0/idMercado").asInt()==21);
        exigir(n.at("/evento/mercados/0/estadoMercado").asText().equals("BORRADOR")&&n.at("/evento/mercados/0/selecciones").isArray()&&n.at("/evento/mercados/0/selecciones").size()==0);
        exigir(n.at("/evento/cantidadMercados").asInt()==1&&c.jdbc.consultas==3&&c.jdbc.commits==1&&c.jdbc.rollbacks==0);
        System.out.println("JSON_MERCADO_VACIO="+n);
        c=new Caso();c.jdbc.mercados.clear();c.jdbc.mercados.add(mercado(21,"CONVENCIONAL",41,31,"FC Barcelona"));
        c.jdbc.mercados.add(mercado(21,"CONVENCIONAL",42,null,"Empate"));c.jdbc.mercados.add(mercado(21,"CONVENCIONAL",43,32,"Real Sociedad"));
        c.jdbc.mercados.add(mercado(22,"PRIMERA_ANOTACION",44,31,"Primero"));
        Map<String,Object> score=mercado(23,"MARCADOR_FINAL",45,null,"Exacto");
        score.putAll(fila("IdCuota",70,"Valor",new BigDecimal("20.5000"),"ValorResultado",new BigDecimal("3.0000"),"FechaInicioCuota",FECHA,"CuotaActiva",true));c.jdbc.mercados.add(score);
        n=c.ejecutar(200);exigir(n.at("/evento/mercados").size()==3&&n.at("/evento/mercados/0/selecciones").size()==3);
        exigir(n.at("/evento/mercados/0/selecciones/0/idParticipante").asInt()==31&&n.at("/evento/mercados/0/selecciones/1/idParticipante").isNull()&&n.at("/evento/mercados/0/selecciones/2/idParticipante").asInt()==32);
        exigir(n.at("/evento/mercados/1/tipoMercado").asText().equals("PRIMERA_ANOTACION")&&n.at("/evento/mercados/1/selecciones/0/idParticipante").asInt()==31);
        exigir(n.at("/evento/mercados/2/tipoMercado").asText().equals("MARCADOR_FINAL")&&n.at("/evento/mercados/2/selecciones/0/idParticipante").isNull());
        exigir(n.at("/evento/mercados/2/selecciones/0/idCuota").asInt()==70&&n.at("/evento/mercados/2/selecciones/0/valor").decimalValue().compareTo(new BigDecimal("20.5"))==0&&n.at("/evento/mercados/2/selecciones/0/valorResultado").asInt()==3);
        exigir(n.at("/evento/mercados/0/selecciones/0/idCuota").isNull()&&n.at("/evento/participantes/0/participante").asText().equals("FC Barcelona"));
        exigir(n.at("/evento/fechaInicio").asText().equals("2026-10-16T12:30:00.123456700"));
        c=new Caso();c.jdbc.evento.clear();c.ejecutar(404);exigir(c.jdbc.consultas==1);
        c=new Caso();c.h.previa=null;c.ejecutar(401);exigir(c.jdbc.conexiones==0);
        c=new Caso();c.h.previa.expirada=true;c.ejecutar(401);
        for(String role:new String[]{"ADMINISTRADOR","OPERADOR_EVENTOS","AUDITOR","CAJERO","USUARIO","CASA"}){
            c=new Caso();c.h.previa.datos.put("adminRol",role);boolean allowed=Arrays.asList("ADMINISTRADOR","OPERADOR_EVENTOS","AUDITOR").contains(role);c.ejecutar(allowed?200:403);exigir(c.jdbc.conexiones==(allowed?1:0));
        }
        c=new Caso();c.h.previa.datos.put("idUsuario",1);c.ejecutar(403);
        c=new Caso();c.h.previa.datos.put("adminEstadoUsuario","SUSPENDIDO");c.ejecutar(403);
        c=new Caso();c.params.clear();c.ejecutar(400);
        for(String value:new String[]{"","0","-1","abc","10.0","2147483648","10 OR 1=1"," 10","10 "}){c=new Caso();c.params.put("idEvento",new String[]{value});c.ejecutar(400);exigir(c.jdbc.conexiones==0);}
        for(String[] values:new String[][]{null,new String[0],new String[]{null},new String[]{"10","10"}}){c=new Caso();c.params.put("idEvento",values);c.ejecutar(400);}
        for(String extra:new String[]{"idUsuarioProceso","rol","tabla","pagina"}){c=new Caso();c.params.put(extra,new String[]{"1"});c.ejecutar(400);}
        for(String method:new String[]{"POST","PUT","DELETE","PATCH","HEAD","OPTIONS"}){c=new Caso();c.h.method=method;c.ejecutar(405);exigir(c.jdbc.conexiones==0&&"GET".equals(c.h.headers.get("Allow")));}
        for(int failure=1;failure<=4;failure++){c=new Caso();c.jdbc.fallo=failure;c.ejecutar(failure==4?500:503);exigir(c.jdbc.rollbacks==(failure==1?0:1));}
        c=new Caso();c.jdbc.mercados.clear();n=c.ejecutar(200);exigir(n.at("/evento/mercados").size()==0);
        c=new Caso();c.jdbc.mercados.clear();c.jdbc.mercados.add(mercado(21,"CONVENCIONAL",41,31,"Local"));c.jdbc.mercados.add(mercado(21,"CONVENCIONAL",41,31,"Duplicado"));c.ejecutar(500);exigir(c.jdbc.rollbacks==1);
        c=new Caso();c.jdbc.mercados.clear();c.jdbc.mercados.add(mercado(21,"CONVENCIONAL",41,99,"Ajeno"));c.ejecutar(500);
        c=new Caso();c.jdbc.mercados.get(0).put("Valor",BigDecimal.TEN);c.ejecutar(500);
        c=new Caso();c.jdbc.mercados.get(0).put("TipoEstadoMercado","EVENTO");c.ejecutar(500);
        c=new Caso();c.jdbc.evento.get(0).put("EsSimulado",true);c.jdbc.evento.get(0).put("DuracionSimulacionSegundos",300);n=c.ejecutar(200);exigir(n.at("/evento/simulacion/esSimulado").asBoolean()&&n.at("/evento/simulacion/duracionSimulacionSegundos").asInt()==300);
        exigir(FiltroCsrf.ambito(OperacionConsultaAdministrativa.DETALLE_EVENTO.ruta)==null);
        System.out.println("Detalle evento administrativo: "+casos+" PASS, 0 FAIL; JDBC controlado, sin escrituras SQL.");
    }
}
