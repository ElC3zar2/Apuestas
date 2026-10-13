package com.apuestas.controlador;

import com.apuestas.dao.ExploracionEventoDAO;
import com.apuestas.modelo.*;
import com.apuestas.servicio.ExploracionEventoServicio;
import com.fasterxml.jackson.databind.*;
import java.lang.reflect.*;
import java.sql.*;
import java.math.BigDecimal;
import java.util.*;
import java.io.*;
import javax.servlet.http.*;

/** Contratos SQL definitivos simulados. No inicializa ConexionBD ni abre red. */
public class PruebaExploracionEventos {
    static int pass,fail;
    interface Accion { void ejecutar() throws Exception; }
    static void caso(String nombre,Accion a) {
        try { a.ejecutar(); pass++; }
        catch(Exception | AssertionError e) { fail++; System.out.println("FAIL: "+nombre+" ("+e.getClass().getSimpleName()+")"); }
    }
    static void exigir(boolean v) { if(!v) throw new AssertionError(); }
    @SuppressWarnings("unchecked") static <T>T proxy(Class<T> c,InvocationHandler h) {
        return (T)Proxy.newProxyInstance(c.getClassLoader(),new Class<?>[]{c},h);
    }
    static Map<String,Object> fila(Object... pares) {
        Map<String,Object> r=new LinkedHashMap<>();
        for(int i=0;i<pares.length;i+=2) r.put((String)pares[i],pares[i+1]); return r;
    }
    static final Timestamp FECHA=Timestamp.valueOf("2026-10-12 12:00:00");
    static Map<String,Object> encabezado(int id,boolean lista,String estado) {
        Map<String,Object> r=fila("IdEvento",id,"IdDeporte",1,"Deporte","Futbol","IdLiga",2,"Liga","Liga",
            "Evento","Evento","FechaInicio",FECHA,"FechaFin",null,"FechaCierreApuestas",FECHA,
            "MinutosParaInicio",-1,"MinutosParaCierreApuestas",-2,"EstadoEvento",estado,"EstadoVisual",estado,
            "PuedeApostar",estado.equals("PROGRAMADO"),"CantidadMercados",1,"CantidadParticipantes",2,
            "ResultadoTexto",null,"EstadoResultado",null,"ResultadoPendiente",estado.equals("PENDIENTE_RESULTADO"));
        if(lista) r.putAll(fila("Participante1","A","Participante2","B","MercadosAbiertos",0,"SeleccionesDisponibles",0));
        return r;
    }
    static Map<String,Object> simulacion(int id,boolean sim) {
        return fila("IdEvento",id,"EsSimulado",sim,"DuracionSimulacionSegundos",sim?300:null,
            "FechaInicioRealUtc",sim?FECHA:null,"FechaFinRealUtc",null,"VersionFila",new byte[8]);
    }
    static class Tabla {
        List<Map<String,Object>> filas=new ArrayList<>(); List<String> columnas;
        @SafeVarargs Tabla(Map<String,Object>... datos) { filas.addAll(Arrays.asList(datos)); columnas=new ArrayList<>(datos[0].keySet()); }
    }
    static class Jdbc {
        List<Tabla> tablas=new ArrayList<>(); int indice,abiertos,cerrados; boolean conexionCerrada,statementCerrado;
        SQLException error;
        Connection conexion() {
            return proxy(Connection.class,(p,m,a)->{
                if(m.getName().equals("close")) {conexionCerrada=true;return null;}
                if(!m.getName().equals("prepareCall")) throw new AssertionError(m.getName());
                String sql=(String)a[0];
                exigir(sql.equals("{call dbo.sp_ObtenerEventosExploracion(?, ?, ?, ?)}")
                    || sql.equals("{call dbo.sp_ObtenerDetalleEventoExploracion(?, ?)}"));
                return proxy(CallableStatement.class,(q,n,b)->{
                    switch(n.getName()) {
                        case "setInt":case "setString":return null;
                        case "execute":if(error!=null)throw error;indice=0;return !tablas.isEmpty();
                        case "getUpdateCount":return -1;
                        case "getMoreResults":return ++indice<tablas.size();
                        case "getResultSet":return resultado(tablas.get(indice));
                        case "close":statementCerrado=true;return null;
                        default:throw new AssertionError(n.getName());
                    }
                });
            });
        }
        ResultSet resultado(Tabla t) {
            abiertos++; int[] pos={-1};
            return proxy(ResultSet.class,(p,m,a)->{
                switch(m.getName()) {
                    case "next":return ++pos[0]<t.filas.size();
                    case "getMetaData":return proxy(ResultSetMetaData.class,(q,n,b)->{
                        if(n.getName().equals("getColumnCount"))return t.columnas.size();
                        if(n.getName().equals("getColumnLabel"))return t.columnas.get((Integer)b[0]-1);
                        throw new AssertionError(n.getName());
                    });
                    case "getObject":if(!t.columnas.contains(a[0]))throw new SQLException("Columna ausente");return t.filas.get(pos[0]).get(a[0]);
                    case "close":cerrados++;return null;
                    default:throw new AssertionError(m.getName());
                }
            });
        }
        ExploracionEventoDAO dao() { return new ExploracionEventoDAO(){@Override protected Connection obtenerConexion(){return conexion();}}; }
        void cerrado() { exigir(conexionCerrada && statementCerrado && abiertos==cerrados); }
    }
    static Jdbc listado(boolean sim) {
        Jdbc j=new Jdbc(); j.tablas.add(new Tabla(encabezado(7,true,"PROGRAMADO"),encabezado(8,true,"EN_VIVO")));
        Map<String,Object> a=simulacion(7,sim),b=simulacion(8,sim);
        a.putAll(fila("MarcadorA",null,"MarcadorB",null)); b.putAll(fila("MarcadorA",3,"MarcadorB",2));
        j.tablas.add(new Tabla(b,a)); return j;
    }
    static Map<String,Object> participante(int id,int orden,String nombre) {
        return fila("IdEventoParticipante",id+100,"OrdenParticipante",(short)orden,"EsLocal",null,
            "IdParticipante",id,"Participante",nombre,"TipoParticipante","EQUIPO","IdPais",null,"Pais",null,"CodigoPais",null);
    }
    static Map<String,Object> oferta(int id,int mercado) {
        return fila("IdMercado",mercado,"Mercado","Mercado","DescripcionMercado",null,"EstadoMercado","CERRADO",
            "IdSeleccion",id,"Seleccion","Seleccion","SeleccionActiva",true,"IdCuota",40+id,
            "Cuota",new BigDecimal("2.50"),"FechaInicioCuota",FECHA,"FechaFinCuota",FECHA,"CuotaActiva",false,
            "ProbabilidadImplicitaPorcentaje",new BigDecimal("40.00"),"ResultadoSeleccion",null,"FechaResolucion",null,"PuedeSeleccionar",false);
    }
    static Map<String,Object> incidencia(long id,int seq,String tipo,boolean anulada) {
        return fila("IdIncidencia",id,"Secuencia",seq,"TipoIncidencia",tipo,"IdParticipante",11,
            "ValorAnotacion",tipo.equals("ANOTACION")?1:null,"SegundoSimulacion",17,"FechaRegistroUtc",FECHA,
            "Descripcion","Texto \"seguro\"\n\t", "EsAnulada",anulada,"MotivoAnulacion",anulada?"Revision":null,
            "FechaAnulacionUtc",anulada?FECHA:null,"VersionFila",new byte[8]);
    }
    static Jdbc detalle(boolean sim,String estado) {
        Jdbc j=new Jdbc(); j.tablas.add(new Tabla(encabezado(7,false,estado)));
        j.tablas.add(new Tabla(participante(11,1,"A"),participante(12,2,"B")));
        j.tablas.add(new Tabla(oferta(21,31),oferta(22,32)));
        j.tablas.add(new Tabla(
            fila("IdMercado",32,"TipoMercado",sim?"PRIMERA_ANOTACION":"CONVENCIONAL","IdSeleccion",22,"IdParticipante",sim?12:null,"Valor",null,"ValorResultado",null),
            fila("IdMercado",31,"TipoMercado",sim?"MARCADOR_FINAL":"CONVENCIONAL","IdSeleccion",21,"IdParticipante",null,"Valor",new BigDecimal("5.00"),"ValorResultado",sim?new BigDecimal("2.00"):null)));
        Map<String,Object> s=simulacion(7,sim);
        s.putAll(fila("Nombre","Evento","EstadoEvento",estado,"SegundosTranscurridos",sim?321:0,
            "TiempoVisualCumplido",sim,"IdPrimeraAnotacion",sim?3000000000L:null,"IdPrimerParticipanteAnotador",sim?11:null));
        j.tablas.add(new Tabla(s));
        j.tablas.add(new Tabla(fila("OrdenParticipante",(short)2,"IdParticipante",12,"Nombre","B","MarcadorActual",sim?2:null),
            fila("OrdenParticipante",(short)1,"IdParticipante",11,"Nombre","A","MarcadorActual",sim?3:null)));
        Tabla t=new Tabla(incidencia(3000000000L,1,"ANOTACION",false),incidencia(3000000001L,2,"ANOTACION",true));
        if(!sim)t.filas.clear(); j.tablas.add(t); return j;
    }
    static DetalleEventoExploracion leer(Jdbc j)throws Exception {
        try{return j.dao().obtenerDetalleEvento(7,24);}finally{j.cerrado();}
    }
    static void rechazar(Jdbc j,boolean lista)throws Exception {
        boolean fallo=false;
        try {if(lista)j.dao().listarEventos(1,"TODOS",24,100);else j.dao().obtenerDetalleEvento(7,24);}
        catch(SQLException e){fallo=true;}finally{j.cerrado();} exigir(fallo);
    }
    static class Http {
        int estado=200; String tipo; String metodo="GET"; StringWriter cuerpo=new StringWriter(); Map<String,String> params=new HashMap<>();
        HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)->{
            if(m.getName().equals("getMethod"))return metodo;
            if(m.getName().equals("getParameter"))return params.get(a[0]);
            throw new AssertionError(m.getName());
        });
        HttpServletResponse res=proxy(HttpServletResponse.class,(p,m,a)->{
            switch(m.getName()) {
                case "setContentType":tipo=(String)a[0];return null;
                case "setHeader":return null;
                case "setStatus":estado=(Integer)a[0];return null;
                case "getWriter":return new PrintWriter(cuerpo);
                default:throw new AssertionError(m.getName());
            }
        });
    }
    static JsonNode http(Jdbc j,boolean lista,String id,int esperado)throws Exception {
        Http h=new Http();h.params.put(lista?"idDeporte":"idEvento",id);
        Object servlet=lista?new EventosExploracionServlet():new DetalleEventoExploracionServlet();
        Field f=servlet.getClass().getDeclaredField("exploracionEventoServicio");f.setAccessible(true);
        f.set(servlet,new ExploracionEventoServicio(j.dao()));
        if(lista)((EventosExploracionServlet)servlet).doGet(h.req,h.res);else((DetalleEventoExploracionServlet)servlet).doGet(h.req,h.res);
        exigir(h.estado==esperado && "application/json;charset=UTF-8".equals(h.tipo));
        exigir(!h.cuerpo.toString().contains("SECRETO_INTERNO"));
        return new ObjectMapper().readTree(h.cuerpo.toString());
    }
    public static void ejecutarContratos() throws Exception {
        caso("listado convencional",()->{Jdbc j=listado(false);List<EventoExploracion> l=j.dao().listarEventos(1,"TODOS",24,100);j.cerrado();exigir(!l.get(0).getSimulacion().getEsSimulado());});
        caso("asociacion por ID y marcador NULL",()->{Jdbc j=listado(true);List<EventoExploracion> l=j.dao().listarEventos(1,"TODOS",24,100);exigir(l.get(0).getSimulacion().getMarcadorA()==null && l.get(1).getSimulacion().getMarcadorA()==3);j.cerrado();});
        caso("listado vacio con metadata",()->{Jdbc j=listado(false);j.tablas.forEach(t->t.filas.clear());exigir(j.dao().listarEventos(1,"TODOS",24,100).isEmpty());j.cerrado();});
        caso("detalle convencional",()->{DetalleEventoExploracion d=leer(detalle(false,"PROGRAMADO"));exigir(d.getIncidencias().isEmpty() && d.getParticipantes().get(0).getMarcadorActual()==null);});
        caso("detalle siete RS y asociaciones",()->{DetalleEventoExploracion d=leer(detalle(true,"EN_VIVO"));exigir(d.getParticipantes().get(0).getMarcadorActual()==3 && d.getMercados().get(1).getSelecciones().get(0).getIdParticipante()==12);exigir(d.getMercados().get(0).getSelecciones().get(0).getCuota().compareTo(new BigDecimal("2.50"))==0 && d.getMercados().get(0).getSelecciones().get(0).getValor().compareTo(new BigDecimal("5.00"))==0);});
        caso("tiempo oficial sin cierre automatico",()->{DetalleEventoExploracion d=leer(detalle(true,"EN_VIVO"));exigir(d.getEstadoEvento().equals("EN_VIVO") && d.getSimulacion().getSegundosTranscurridos()==321 && d.getSimulacion().getDuracionSimulacionSegundos()==300 && d.getSimulacion().getTiempoVisualCumplido());});
        caso("incidencia BIGINT y anulada conservada",()->{DetalleEventoExploracion d=leer(detalle(true,"EN_VIVO"));exigir(d.getIncidencias().get(0).getIdIncidencia()==3000000000L && d.getIncidencias().get(1).getEsAnulada());});
        for(String tipo:Arrays.asList("FALTA","TARJETA_AMARILLA","TARJETA_ROJA","OTRA")) caso("incidencia "+tipo,()->{Jdbc j=detalle(true,"EN_VIVO");j.tablas.get(6).filas.add(incidencia(3000000002L,3,tipo,false));exigir(leer(j).getIncidencias().size()==3);});
        for(String estado:Arrays.asList("PROGRAMADO","PENDIENTE_RESULTADO","FINALIZADO","CANCELADO")) caso("estado "+estado,()->exigir(leer(detalle(true,estado)).getEstadoEvento().equals(estado)));
        for(int n=0;n<7;n++){final int i=n;caso("RS detalle ausente "+i,()->{Jdbc j=detalle(true,"EN_VIVO");j.tablas.remove(i);rechazar(j,false);});}
        caso("RS lista ausente",()->{Jdbc j=listado(true);j.tablas.remove(1);rechazar(j,true);});
        caso("RS adicional",()->{Jdbc j=detalle(true,"EN_VIVO");j.tablas.add(j.tablas.get(6));rechazar(j,false);});
        caso("columna ausente incluso sin filas",()->{Jdbc j=detalle(false,"PROGRAMADO");j.tablas.get(6).columnas.remove("VersionFila");rechazar(j,false);});
        caso("tipo incorrecto sin conversion JDBC",()->{Jdbc j=detalle(true,"EN_VIVO");j.tablas.get(4).filas.get(0).put("SegundosTranscurridos",new BigDecimal("1.5"));rechazar(j,false);});
        caso("tipo obligatorio nulo",()->{Jdbc j=listado(true);j.tablas.get(1).filas.get(0).put("EsSimulado",null);rechazar(j,true);});
        caso("ID desconocido",()->{Jdbc j=listado(true);j.tablas.get(1).filas.get(0).put("IdEvento",99);rechazar(j,true);});
        caso("ID duplicado",()->{Jdbc j=listado(true);j.tablas.get(1).filas.get(0).put("IdEvento",7);rechazar(j,true);});
        caso("oferta asociada a mercado incorrecto",()->{Jdbc j=detalle(true,"EN_VIVO");j.tablas.get(3).filas.get(0).put("IdMercado",31);rechazar(j,false);});
        caso("participante desconocido",()->{Jdbc j=detalle(true,"EN_VIVO");j.tablas.get(5).filas.get(0).put("IdParticipante",99);rechazar(j,false);});
        caso("encabezado vacio",()->{Jdbc j=detalle(true,"EN_VIVO");j.tablas.get(0).filas.clear();rechazar(j,false);});
        caso("detalle sin ofertas",()->{Jdbc j=detalle(false,"PROGRAMADO");j.tablas.get(2).filas.clear();j.tablas.get(3).filas.clear();exigir(leer(j).getMercados().isEmpty());});
    }
    public static void main(String[] args)throws Exception {
        pass=0;fail=0;ejecutarContratos();
        caso("JSON detalle EN_VIVO",()->{JsonNode n=http(detalle(true,"EN_VIVO"),false,"7",200);exigir(n.path("evento").path("simulacion").path("marcadorA").asInt()==3 && n.path("evento").path("incidencias").size()==2);});
        caso("JSON listado y NULL",()->exigir(http(listado(true),true,"1",200).path("eventos").get(0).path("simulacion").path("marcadorA").isNull()));
        for(String id:Arrays.asList(null,"","abc","0","-1","2147483648")) caso("idEvento invalido "+id,()->http(detalle(true,"EN_VIVO"),false,id,400));
        caso("evento inexistente",()->{Jdbc j=detalle(false,"PROGRAMADO");j.error=new SQLException("SECRETO_INTERNO","X",64014);http(j,false,"7",404);j.cerrado();});
        caso("SQL inesperado sanitizado",()->{Jdbc j=listado(true);j.error=new SQLException("SECRETO_INTERNO","X",99999);http(j,true,"1",500);j.cerrado();});
        caso("contrato incompleto HTTP",()->{Jdbc j=detalle(true,"EN_VIVO");j.tablas.remove(6);http(j,false,"7",500);});
        caso("metodo no permitido JSON",()->{Http h=new Http();h.metodo="POST";new DetalleEventoExploracionServlet().service(h.req,h.res);exigir(h.estado==405 && !new ObjectMapper().readTree(h.cuerpo.toString()).path("ok").asBoolean());});
        caso("lista RS extra",()->{Jdbc j=listado(true);j.tablas.add(j.tablas.get(1));rechazar(j,true);});
        caso("lista asociacion incompleta",()->{Jdbc j=listado(true);j.tablas.get(1).filas.remove(0);rechazar(j,true);});
        caso("primera anotacion incoherente",()->{Jdbc j=detalle(true,"EN_VIVO");j.tablas.get(4).filas.get(0).put("IdPrimerParticipanteAnotador",12);rechazar(j,false);});
        caso("JSON convencional conserva nombres",()->{JsonNode e=http(detalle(false,"PROGRAMADO"),false,"7",200).path("evento");exigir(e.path("nombre").asText().equals("Evento") && e.path("participantes").get(0).path("marcadorActual").isNull() && e.path("simulacion").path("duracionSimulacionSegundos").isNull());});
        System.out.println("Exploracion definitiva: "+pass+" PASS, "+fail+" FAIL.");
        if(fail!=0)throw new AssertionError("Fallo de exploracion");
    }
}
