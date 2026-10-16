package com.apuestas.controlador;

import com.apuestas.dao.DeporteDAO;
import com.apuestas.modelo.Deporte;
import com.apuestas.modelo.OperacionAdministracionEventos;
import com.apuestas.seguridad.*;
import com.apuestas.servicio.DeporteServicio;
import com.fasterxml.jackson.databind.*;
import java.lang.reflect.*;
import java.sql.*;
import java.util.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;
import static com.apuestas.modelo.OperacionAdministracionEventos.*;

/** Contratos reales con dobles JDBC; no inicializa ConexionBD ni modifica SQL Server. */
public final class PruebaCorreccionEstructural {
    private static int casos;
    private static void ejecutar(PruebaAdministracionEventos.Caso c,int estado) throws Exception {
        c.ejecutar(estado);casos++;
    }
    public static void main(String[] args) throws Exception {
        for(OperacionAdministracionEventos op:Arrays.asList(ASOCIAR_PARTICIPANTE_LIGA,DESASOCIAR_PARTICIPANTE_LIGA)) {
            PruebaAdministracionEventos.Caso c=new PruebaAdministracionEventos.Caso(op);
            JsonNode n=c.ejecutar(200);casos++;
            exigir(n.at("/resultado/idLiga").asInt()==11 && n.at("/resultado/idParticipante").asInt()==12);
            exigir(n.at("/resultado/activo").asBoolean()==(op==ASOCIAR_PARTICIPANTE_LIGA));
            exigir(FiltroCsrf.ambito(op.ruta)==CsrfSeguridad.Ambito.ADMINISTRADOR);
            for(String rol:Arrays.asList("ADMINISTRADOR","OPERADOR_EVENTOS","AUDITOR","CAJERO","USUARIO","CASA")) {
                c=new PruebaAdministracionEventos.Caso(op);c.h.previa.datos.put("adminRol",rol);
                ejecutar(c,rol.equals("ADMINISTRADOR")||rol.equals("OPERADOR_EVENTOS")?200:403);
            }
            c=new PruebaAdministracionEventos.Caso(op);c.h.previa=null;ejecutar(c,401);
            c=new PruebaAdministracionEventos.Caso(op);c.omitirCsrf=true;ejecutar(c,403);exigir(c.j.llamadas==0);
            c=new PruebaAdministracionEventos.Caso(op);c.omitirCsrf=true;c.tokenCsrf="a".repeat(64);ejecutar(c,403);
            c=new PruebaAdministracionEventos.Caso(op);c.h.method="GET";ejecutar(c,405);
            for(String clave:Arrays.asList("idLiga","idParticipante")) {
                for(String valor:Arrays.asList("0","-1","abc","2147483648","")) {
                    c=new PruebaAdministracionEventos.Caso(op);c.p(clave,valor);ejecutar(c,400);exigir(c.j.llamadas==0);
                }
                c=new PruebaAdministracionEventos.Caso(op);c.p(clave,"1","2");ejecutar(c,400);
                c=new PruebaAdministracionEventos.Caso(op);c.params.remove(clave);ejecutar(c,400);
            }
            c=new PruebaAdministracionEventos.Caso(op);c.p("idUsuarioProceso","999");ejecutar(c,400);
            for(int codigo:new int[]{76600,76601,76602,76603,76604,76605,76606,76900,1205,1222}) {
                c=new PruebaAdministracionEventos.Caso(op);c.j.codigo=codigo;
                ejecutar(c,codigo==76600?400:codigo==76601||codigo==76602||codigo==76605?404:codigo>=76900||codigo==1205||codigo==1222?503:409);
            }
            c=new PruebaAdministracionEventos.Caso(op);c.j.fila().put("IdParticipante",99);ejecutar(c,500);
            c=new PruebaAdministracionEventos.Caso(op);c.j.fila().put("Activo",op!=ASOCIAR_PARTICIPANTE_LIGA);ejecutar(c,500);
        }
        // SQL derives the property; Java only maps and serializes the returned BIT.
        for(boolean permite:Arrays.asList(false,true)) {
            DeporteDAO dao=new DeporteDAO() {
                @Override protected Connection obtenerConexion() {
                    return proxy(Connection.class,(c,m,a)-> {
                        if(m.getName().equals("close"))return null;
                        exigir(m.getName().equals("prepareStatement"));
                        exigir(((String)a[0]).contains("CASE WHEN UnidadMarcador IS NOT NULL THEN 1 ELSE 0 END"));
                        return proxy(PreparedStatement.class,(p,pm,pa)-> {
                            if(pm.getName().equals("close"))return null;
                            exigir(pm.getName().equals("executeQuery"));boolean[] primera={true};
                            return proxy(ResultSet.class,(r,rm,ra)-> {
                                switch(rm.getName()) {
                                    case "next":boolean valor=primera[0];primera[0]=false;return valor;
                                    case "getInt":return 1;
                                    case "getString":return "Prueba ñ á ü \"";
                                    case "getBoolean":return ra[0].equals("PermiteSimulacion")?permite:true;
                                    case "close":return null;
                                    default:throw new AssertionError(rm.getName());
                                }
                            });
                        });
                    });
                }
            };
            List<Deporte> deportes=dao.listarDeportesActivos();exigir(deportes.get(0).isPermiteSimulacion()==permite);
            DeportesExploracionServlet servlet=new DeportesExploracionServlet();
            Field campo=servlet.getClass().getDeclaredField("deporteServicio");campo.setAccessible(true);
            campo.set(servlet,new DeporteServicio(){@Override public List<Deporte> listarDeportesActivos(){return deportes;}});
            Http h=new Http();servlet.doGet(h.req,h.res);
            JsonNode json=new ObjectMapper().readTree(h.body.toString());
            exigir(h.status==200 && "no-store".equals(h.headers.get("Cache-Control")));
            exigir(json.at("/deportes/0/permiteSimulacion").isBoolean() && json.at("/deportes/0/permiteSimulacion").asBoolean()==permite);
            exigir(json.at("/deportes/0/nombre").asText().equals("Prueba ñ á ü \""));casos++;
        }
        System.out.println("Correccion estructural: "+casos+" casos, 0 fallos; sin SQL real.");
    }
}
