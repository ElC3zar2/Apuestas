package com.apuestas.controlador;

import com.apuestas.dao.ParticipanteDAO;
import com.apuestas.servicio.CatalogoParticipantesServicio;
import com.apuestas.seguridad.ControlAccesoAdministrativo;
import com.fasterxml.jackson.databind.*;
import java.sql.*;
import java.lang.reflect.*;
import java.util.*;
import javax.servlet.http.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;

/** Filtro, servlet, servicio y DAO reales; solo dobles JDBC, sin Azure. */
public final class PruebaCatalogoParticipantes {
    private static int pass;
    private static final ObjectMapper JSON=new ObjectMapper();
    private static Map<String,Object> fila(int id,String nombre,Integer pais,boolean activo) {
        Map<String,Object> f=new LinkedHashMap<>();f.put("IdParticipante",id);f.put("IdDeporte",1);
        f.put("IdPais",pais);f.put("Nombre",nombre);f.put("TipoParticipante","EQUIPO");f.put("Activo",activo);return f;
    }
    static class Jdbc {
        long total=2;int conexiones,statements,rsAbiertos,rsCerrados,psCerrados,conCerradas;
        int fallo;final List<Map<String,Object>> filas=new ArrayList<>();
        final List<String> sql=new ArrayList<>();final List<Map<Integer,Object>> parametros=new ArrayList<>();
        Jdbc(){filas.add(fila(1001,"Equipo A",null,true));filas.add(fila(1002,"Equipo B",1,false));}
        Connection conexion() throws SQLException {
            conexiones++;if(fallo==1)throw new SQLTransientConnectionException("SECRETO_INTERNO");
            if(fallo==2)throw new ExceptionInInitializerError("SECRETO_INTERNO");
            return proxy(Connection.class,(p,m,a)-> {
                if(m.getName().equals("close")){conCerradas++;return null;}
                if(!m.getName().equals("prepareStatement"))throw new AssertionError("Solo SELECT parametrizado");
                String consulta=(String)a[0];sql.add(consulta);Map<Integer,Object> params=new LinkedHashMap<>();parametros.add(params);
                statements++;boolean conteo=consulta.startsWith("SELECT COUNT_BIG(*)");
                exigir(consulta.startsWith("SELECT ")&&!consulta.contains(";"));
                if(!conteo)exigir(consulta.endsWith("ORDER BY Nombre, IdParticipante OFFSET ? ROWS FETCH NEXT ? ROWS ONLY"));
                return proxy(PreparedStatement.class,(sp,sm,sa)-> {
                    switch(sm.getName()) {
                        case "setInt":case "setLong":case "setString":case "setBoolean":params.put((Integer)sa[0],sa[1]);return null;
                        case "close":psCerrados++;return null;
                        case "executeQuery":
                            if(fallo==3)throw new SQLTimeoutException("SECRETO_INTERNO");
                            if(fallo==4)throw new SQLException("SECRETO_INTERNO","TEST",1205);
                            if(fallo==5)throw new SQLException("SECRETO_INTERNO","TEST",99999);
                            if(fallo==6)throw new IllegalStateException("SECRETO_INTERNO");
                            rsAbiertos++;int[] pos={-1};boolean[] nulo={false};
                            return proxy(ResultSet.class,(rp,rm,ra)-> {
                                switch(rm.getName()) {
                                    case "close":rsCerrados++;return null;
                                    case "next":return ++pos[0]<(conteo?1:filas.size());
                                    case "getObject":return total;
                                    case "wasNull":return nulo[0];
                                    case "getInt":case "getString":case "getBoolean":
                                        Object v=filas.get(pos[0]).get(ra[0]);nulo[0]=v==null;
                                        return v==null&&rm.getName().equals("getInt")?0:v;
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
        final Http h=new Http();final Jdbc j=new Jdbc();final Map<String,String[]> params=new LinkedHashMap<>();
        boolean directo;
        Caso() {
            h.method="GET";h.ruta=CatalogoParticipantesServlet.RUTA;h.previa=new Sesion();
            h.previa.datos.put("adminIdUsuario",7);h.previa.datos.put("adminIdRol",3);
            h.previa.datos.put("adminCorreo","admin@example.test");h.previa.datos.put("adminRol","ADMINISTRADOR");
            h.previa.datos.put("adminEstadoUsuario","ACTIVO");
        }
        void p(String k,String... v){params.put(k,v);}
        JsonNode ejecutar(int esperado) throws Exception {
            CatalogoParticipantesServlet s=new CatalogoParticipantesServlet();
            Field f=s.getClass().getDeclaredField("servicio");f.setAccessible(true);
            f.set(s,new CatalogoParticipantesServicio(new ParticipanteDAO(){
                @Override protected Connection obtenerConexionCatalogo() throws SQLException {return j.conexion();}
            }));
            HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)-> {
                if(m.getName().equals("getParameterMap")){exigir("UTF-8".equals(h.encoding));return params;}
                try{return m.invoke(h.req,a);}catch(InvocationTargetException e){throw e.getCause();}
            });
            if(directo)s.service(req,h.res);
            else new ControlAccesoAdministrativo().doFilter(req,h.res,(r,res)->s.service((HttpServletRequest)r,(HttpServletResponse)res));
            if(h.status!=esperado)throw new AssertionError("Esperado "+esperado+" recibido "+h.status);
            exigir("application/json;charset=UTF-8".equals(h.tipo)&&"no-store".equals(h.headers.get("Cache-Control")));
            exigir(h.creaciones==0&&!h.headers.containsKey("Location")&&!h.body.toString().contains("SECRETO_INTERNO"));
            JsonNode n=JSON.readTree(h.body.toString());exigir(n.path("ok").asBoolean()==(esperado==200));
            exigir(n.size()==(esperado==200?5:2));
            exigir(j.rsAbiertos==j.rsCerrados&&j.statements==j.psCerrados);
            if(j.fallo!=1&&j.fallo!=2)exigir(j.conexiones==j.conCerradas);
            if(esperado==200) {
                exigir(j.sql.size()==2&&j.parametros.get(1).size()==j.parametros.get(0).size()+2);
                for(Map.Entry<Integer,Object> e:j.parametros.get(0).entrySet())exigir(Objects.equals(e.getValue(),j.parametros.get(1).get(e.getKey())));
                exigir(n.get("total").asLong()==j.total&&n.get("participantes").size()==j.filas.size());
                for(JsonNode participante:n.get("participantes"))exigir(participante.size()==6&&!participante.has("idLiga"));
            }
            pass++;return n;
        }
    }
    public static void main(String[] args) throws Exception {
        Caso c=new Caso();JsonNode base=c.ejecutar(200);
        exigir(base.get("pagina").asInt()==1&&base.get("tamanoPagina").asInt()==20);
        exigir(base.at("/participantes/0/idPais").isNull()&&!base.at("/participantes/1/activo").asBoolean());
        exigir(c.j.parametros.get(1).get(1).equals(0L)&&c.j.parametros.get(1).get(2).equals(20));
        System.out.println("JSON_CONTROLADO="+base.toString());
        c=new Caso();c.p("idDeporte","1");c.ejecutar(200);exigir(c.j.parametros.get(0).get(1).equals(1));
        c=new Caso();c.p("buscar","Equipo");c.ejecutar(200);exigir(c.j.parametros.get(0).get(1).equals("%Equipo%"));
        for(String buscar:new String[]{"%_[]!","x' OR 1=1--","Pe\u00f1a \"Norte\"",""}) {
            c=new Caso();c.p("buscar",buscar);c.ejecutar(200);
            if(!buscar.isEmpty())exigir(!c.j.sql.get(0).contains(buscar));
            if(buscar.equals("%_[]!"))exigir(c.j.parametros.get(0).get(1).equals("%!%!_![!]!!%"));
        }
        for(String activo:new String[]{"true","false"}) {
            c=new Caso();c.p("activo",activo);c.j.filas.remove(activo.equals("true")?1:0);c.j.total=1;
            JsonNode respuesta=c.ejecutar(200);exigir(c.j.parametros.get(0).get(1).equals(Boolean.valueOf(activo)));
            exigir(respuesta.at("/participantes/0/activo").asBoolean()==Boolean.parseBoolean(activo));
        }
        c=new Caso();c.p("idDeporte","1");c.p("buscar","Equipo");c.p("activo","true");c.ejecutar(200);
        exigir(c.j.parametros.get(0).size()==3);
        c=new Caso();c.p("pagina","2");c.p("tamanoPagina","1");c.j.filas.remove(0);c.ejecutar(200);
        exigir(c.j.parametros.get(1).get(1).equals(1L)&&c.j.parametros.get(1).get(2).equals(1));
        c=new Caso();c.p("pagina","50");c.j.filas.clear();c.ejecutar(200); // pagina vacia con total no cero
        c=new Caso();c.j.filas.clear();c.j.total=0;c.ejecutar(200);
        c=new Caso();c.j.filas.get(1).put("Nombre","Equipo A");JsonNode iguales=c.ejecutar(200);
        exigir(iguales.at("/participantes/0/idParticipante").asInt()<iguales.at("/participantes/1/idParticipante").asInt());
        for(String clave:new String[]{"idDeporte","pagina","tamanoPagina"}) {
            for(String valor:new String[]{"","0","-1","abc","1.5","2147483648","1 OR 1=1"}) {
                c=new Caso();c.p(clave,valor);c.ejecutar(400);exigir(c.j.conexiones==0);
            }
        }
        for(String clave:new String[]{"idDeporte","buscar","pagina","tamanoPagina","activo"}) {
            for(String[] valores:new String[][]{new String[]{"1","2"},new String[0],null,new String[]{null}}) {
                c=new Caso();c.p(clave,valores);c.ejecutar(400);exigir(c.j.conexiones==0);
            }
        }
        for(String activo:new String[]{"1","0","TRUE","yes",""}) {c=new Caso();c.p("activo",activo);c.ejecutar(400);}
        for(String intruso:new String[]{"idLiga","idUsuarioProceso","rol","otro"}) {c=new Caso();c.p(intruso,"99");c.ejecutar(400);}
        c=new Caso();c.p("buscar","x".repeat(151));c.ejecutar(400);
        c=new Caso();c.p("tamanoPagina","101");c.ejecutar(400);
        c=new Caso();c.p("pagina","2147483647");c.ejecutar(400);
        c=new Caso();c.p("pagina","2147483647");c.p("tamanoPagina","1");c.j.filas.clear();c.ejecutar(200);
        c=new Caso();c.p("tamanoPagina","100");c.ejecutar(200);
        for(String rol:new String[]{"ADMINISTRADOR","OPERADOR_EVENTOS","CAJERO","AUDITOR","USUARIO","CASA"}) {
            c=new Caso();c.h.previa.datos.put("adminRol",rol);boolean permitido=rol.equals("ADMINISTRADOR")||rol.equals("OPERADOR_EVENTOS");
            c.ejecutar(permitido?200:403);if(!permitido)exigir(c.j.conexiones==0);
        }
        c=new Caso();c.h.previa=null;c.ejecutar(401);
        c=new Caso();c.h.previa.expirada=true;c.ejecutar(401);
        c=new Caso();c.h.previa.datos.put("adminEstadoUsuario","SUSPENDIDO");c.ejecutar(403);
        c=new Caso();c.h.previa.datos.put("idUsuario",7);c.ejecutar(403);
        c=new Caso();c.h.previa.falloLectura=true;c.ejecutar(500);
        for(String metodo:new String[]{"POST","PUT","PATCH","DELETE","HEAD","OPTIONS"}) {c=new Caso();c.h.method=metodo;c.ejecutar(405);exigir("GET".equals(c.h.headers.get("Allow"))&&c.j.conexiones==0);}
        c=new Caso();c.directo=true;c.h.previa=null;c.ejecutar(401);
        for(int fallo=1;fallo<=6;fallo++){c=new Caso();c.j.fallo=fallo;c.ejecutar(fallo==1||fallo==3||fallo==4?503:500);}
        System.out.println("Catalogo participantes: "+pass+" PASS, 0 FAIL; sin SQL real.");
    }
}
