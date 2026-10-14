package com.apuestas.controlador;

import com.apuestas.modelo.OperacionAdministracionEventos;
import com.apuestas.dao.AdministracionEventosDAO;
import com.apuestas.servicio.AdministracionEventosServicio;
import com.apuestas.seguridad.ControlAccesoAdministrativo;
import com.fasterxml.jackson.databind.*;
import java.math.BigDecimal;
import java.sql.*;
import java.lang.reflect.*;
import java.util.*;
import javax.servlet.http.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;
import static com.apuestas.modelo.OperacionAdministracionEventos.*;

/** SQL/HTTP sinteticos: no hay conexion, reloj deportivo, escrituras ni calculos Java. */
public class PruebaContratosAdministracionEventos {
    static int casos;
    interface Accion {void ejecutar()throws Exception;}
    static void caso(String nombre,Accion accion)throws Exception {try{accion.ejecutar();casos++;}catch(Exception|AssertionError e){throw new AssertionError(nombre,e);}}
    static Map<String,Object> fila(Object... valores){Map<String,Object> r=new LinkedHashMap<>();for(int i=0;i<valores.length;i+=2)r.put((String)valores[i],valores[i+1]);return r;}
    static class Tabla {
        List<Map<String,Object>> filas=new ArrayList<>();List<String> columnas;
        Tabla(Map<String,Object> f){filas.add(f);columnas=new ArrayList<>(f.keySet());}
    }
    static class Caso {
        Http h=new Http();OperacionAdministracionEventos op;Map<String,String[]> parametros=new LinkedHashMap<>();
        final Map<String,String[]> params=parametros;
        List<Tabla> tablas=new ArrayList<>();Map<Integer,Object> vinculados=new HashMap<>();Map<Integer,Integer> nulos=new HashMap<>();
        int llamadas,indice,abiertos,cerrados,codigo;boolean conexionCerrada,statementCerrado;String procedimiento;
        Caso(OperacionAdministracionEventos op) {
            this.op=op;h.ruta=op.ruta;h.method=op.metodo;h.previa=new Sesion();
            h.previa.datos.put("adminIdUsuario",7);h.previa.datos.put("adminIdRol",3);h.previa.datos.put("adminCorreo","prueba@example.invalid");
            h.previa.datos.put("adminRol","ADMINISTRADOR");h.previa.datos.put("adminEstadoUsuario","ACTIVO");
            if(op==REGISTRAR_INCIDENCIA){p("idEvento","13");p("tipoIncidencia","ANOTACION");p("referenciaOperacion","c8ec53e7-1fa9-4b51-b97d-55792fcdd75a");p("idParticipante","12");p("valorAnotacion","1");tablas.add(new Tabla(fila("IdIncidencia",29L,"SolicitudIdempotente",false)));}
            if(op==ANULAR_INCIDENCIA){p("idIncidencia","29");p("motivo","Correccion");tablas.add(new Tabla(fila("IdIncidencia",29L,"SinCambios",false)));}
            if(op==ESTADO_SIMULACION){p("idEvento","13");
                tablas.add(new Tabla(fila("IdEvento",13,"Nombre","Evento","EstadoEvento","EN_VIVO","EsSimulado",true,"DuracionSimulacionSegundos",300,
                    "FechaInicioRealUtc",Timestamp.valueOf("2026-10-01 12:00:00"),"FechaFinRealUtc",null,"VersionFila",new byte[8],"SegundosTranscurridos",17,"TiempoVisualCumplido",false,
                    "IdPrimeraAnotacion",29L,"IdPrimerParticipanteAnotador",12)));
                Tabla participantes=new Tabla(fila("OrdenParticipante",(short)1,"IdParticipante",12,"Nombre","Participante A","MarcadorActual",77));
                participantes.filas.add(fila("OrdenParticipante",(short)2,"IdParticipante",14,"Nombre","Participante B","MarcadorActual",21));tablas.add(participantes);
                tablas.add(new Tabla(fila("IdIncidencia",29L,"Secuencia",5,"TipoIncidencia","ANOTACION","IdParticipante",12,"ValorAnotacion",1,"SegundoSimulacion",8,
                    "FechaRegistroUtc",Timestamp.valueOf("2026-10-01 12:00:08"),"Descripcion",null,"EsAnulada",false,"MotivoAnulacion",null,"FechaAnulacionUtc",null,"VersionFila",new byte[8])));
            }
        }
        void p(String k,String... v){parametros.put(k,v);}
        Connection conexion(){llamadas++;return proxy(Connection.class,(p,m,a)->{
            if(m.getName().equals("close")){conexionCerrada=true;return null;}
            exigir(m.getName().equals("prepareCall"));procedimiento=(String)a[0];
            String esperado=op==REGISTRAR_INCIDENCIA?"{call dbo.sp_RegistrarIncidenciaEvento(?, ?, ?, ?, ?, ?, ?, ?)}":op==ANULAR_INCIDENCIA?"{call dbo.sp_AnularIncidenciaEvento(?, ?, ?, ?)}":"{call dbo.sp_ObtenerEstadoSimulacionEvento(?)}";
            exigir(esperado.equals(procedimiento));
            return proxy(CallableStatement.class,(q,n,b)->{
                switch(n.getName()) {
                    case "setInt":case "setLong":case "setString":vinculados.put((Integer)b[0],b[1]);return null;
                    case "setNull":vinculados.put((Integer)b[0],null);nulos.put((Integer)b[0],(Integer)b[1]);return null;
                    case "execute":if(codigo!=0)throw new SQLException("SECRETO_INTERNO_SQL","TEST",codigo);return !tablas.isEmpty();
                    case "getMoreResults":return ++indice<tablas.size();case "getUpdateCount":return -1;
                    case "getResultSet":return rs(tablas.get(indice));case "close":statementCerrado=true;return null;
                    default:throw new AssertionError("No escrituras ni transacciones JDBC directas");
                }
            });
        });}
        ResultSet rs(Tabla t){abiertos++;int[] pos={-1};return proxy(ResultSet.class,(p,m,a)->{
            switch(m.getName()) {
                case "next":return ++pos[0]<t.filas.size();case "close":cerrados++;return null;
                case "getMetaData":return proxy(ResultSetMetaData.class,(q,n,b)->{
                    if(n.getName().equals("getColumnCount"))return t.columnas.size();if(n.getName().equals("getColumnLabel"))return t.columnas.get((Integer)b[0]-1);throw new AssertionError();
                });
                case "getObject":if(!t.columnas.contains(a[0]))throw new SQLException("SECRETO_INTERNO_SQL");return t.filas.get(pos[0]).get(a[0]);
                default:throw new AssertionError("Sin conversion JDBC silenciosa");
            }
        });}
        JsonNode ejecutar(int esperado)throws Exception {
            AdministracionEventosServlet servlet=new AdministracionEventosServlet();Field campo=servlet.getClass().getDeclaredField("servicio");campo.setAccessible(true);
            campo.set(servlet,new AdministracionEventosServicio(new AdministracionEventosDAO(){@Override protected Connection obtenerConexion(){return conexion();}}));
            HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)->{
                if(m.getName().equals("getParameterMap"))return parametros;if(m.getName().equals("getRemoteAddr"))return "127.0.0.1";
                try{return m.invoke(h.req,a);}catch(InvocationTargetException e){throw e.getCause();}
            });
            new ControlAccesoAdministrativo().doFilter(req,h.res,(r,s)->servlet.service((HttpServletRequest)r,(HttpServletResponse)s));
            exigir(h.status==esperado && "application/json;charset=UTF-8".equals(h.tipo));
            exigir("no-store".equals(h.headers.get("Cache-Control")) && !h.body.toString().contains("SECRETO_INTERNO_SQL"));
            exigir(abiertos==cerrados && (llamadas==0 || (conexionCerrada && statementCerrado && llamadas==1)));
            return new ObjectMapper().readTree(h.body.toString());
        }
    }
    static void base(OperacionAdministracionEventos op,java.util.function.Consumer<PruebaAdministracionEventos.Caso> cambio,int estado)throws Exception {
        PruebaAdministracionEventos.Caso c=new PruebaAdministracionEventos.Caso(op);cambio.accept(c);c.ejecutar(estado);
    }
    public static void main(String[] args)throws Exception {
        caso("conversion JDBC decimal a INT rechazada",()->base(CREAR_LIGA,c->c.j.fila().put("IdLiga",new BigDecimal("11.5")),500));
        caso("evento simulado envia opciones despues de IP",()->base(CREAR_EVENTO,c->{c.p("esSimulado","true");c.p("duracionSimulacionSegundos","300");},200));
        for(String tipo:Arrays.asList("CONVENCIONAL","MARCADOR_FINAL","PRIMERA_ANOTACION"))caso("mercado " + tipo,()->base(CREAR_MERCADO,c->c.p("tipoMercado",tipo),200));
        caso("seleccion participante oficial",()->base(CREAR_SELECCION,c->c.p("idParticipante","12"),200));
        caso("cuota resultado decimal",()->base(REGISTRAR_CUOTA,c->c.p("valorResultado","1.1000"),200));
        caso("cuota NULL usa valor SQL oficial",()->base(REGISTRAR_CUOTA,c->c.params.remove("valor"),200));
        caso("inicio simulado respuesta abreviada",()->base(ESTADO_EVENTO,c->{c.p("nuevoEstado","EN_VIVO");c.j.resultados.set(0,new ArrayList<>(Arrays.asList(fila("IdEvento",13,"SinCambios",false))));},200));
        caso("cancelacion respuesta oficial delegada",()->base(ESTADO_EVENTO,c->{c.p("nuevoEstado","CANCELADO");c.p("motivo","Cancelacion");c.j.resultados.set(0,new ArrayList<>(Arrays.asList(fila("IdResultado",2,"IdEvento",13,"EstadoResultado","ANULADO","EstadoEvento","CANCELADO","SinCambios",false))));},200));
        caso("fin simulado dos RS oficiales",()->base(ESTADO_EVENTO,c->{c.p("nuevoEstado","PENDIENTE_RESULTADO");c.j.resultados.set(0,new ArrayList<>(Arrays.asList(fila("IdResultado",2,"IdEvento",13,"EstadoResultado","PENDIENTE","ResultadoTexto","77-21","Observacion",null))));c.j.resultados.add(new ArrayList<>(Arrays.asList(fila("IdEvento",13,"SinCambios",false))));},200));
        caso("fin simulado RS final faltante",()->base(ESTADO_EVENTO,c->{c.p("nuevoEstado","PENDIENTE_RESULTADO");c.j.resultados.set(0,new ArrayList<>(Arrays.asList(fila("IdResultado",2,"IdEvento",13,"EstadoResultado","PENDIENTE","ResultadoTexto","77-21","Observacion",null))));},500));
        for(OperacionAdministracionEventos op:Arrays.asList(REGISTRAR_INCIDENCIA,ANULAR_INCIDENCIA,ESTADO_SIMULACION)) {
            caso("operacion " + op,()->{Caso c=new Caso(op);JsonNode n=c.ejecutar(200);exigir(n.path("ok").asBoolean());
                if(op==REGISTRAR_INCIDENCIA)exigir(c.vinculados.get(1).equals(7) && c.vinculados.get(2).equals(13) && c.vinculados.get(4).equals("c8ec53e7-1fa9-4b51-b97d-55792fcdd75a") && c.vinculados.get(8).equals("127.0.0.1"));
                if(op==ESTADO_SIMULACION)exigir(c.vinculados.size()==1 && c.vinculados.get(1).equals(13));
            });
            caso("sin sesion " + op,()->{Caso c=new Caso(op);c.h.previa=null;c.ejecutar(401);exigir(c.llamadas==0);});
            caso("sesion expirada " + op,()->{Caso c=new Caso(op);c.h.previa.expirada=true;c.ejecutar(401);});
            caso("AUDITOR rechazado " + op,()->{Caso c=new Caso(op);c.h.previa.datos.put("adminRol","AUDITOR");c.ejecutar(403);exigir(c.llamadas==0);});
            caso("OPERADOR autorizado " + op,()->{Caso c=new Caso(op);c.h.previa.datos.put("adminRol","OPERADOR_EVENTOS");c.ejecutar(200);});
            caso("metodo incorrecto " + op,()->{Caso c=new Caso(op);c.h.method=op==ESTADO_SIMULACION?"POST":"GET";c.ejecutar(405);exigir(c.llamadas==0);});
            caso("parametro intruso " + op,()->{Caso c=new Caso(op);c.p("idUsuarioProceso","999");c.ejecutar(400);exigir(c.llamadas==0);});
            caso("RS faltante " + op,()->{Caso c=new Caso(op);c.tablas.clear();c.ejecutar(500);});
            caso("RS adicional " + op,()->{Caso c=new Caso(op);c.tablas.add(c.tablas.get(0));c.ejecutar(500);});
            caso("error SQL privado " + op,()->{Caso c=new Caso(op);c.codigo=99999;c.ejecutar(500);});
            caso("concurrencia SQL simulada " + op,()->{Caso c=new Caso(op);c.codigo=76900;c.ejecutar(503);});
        }
        for(String tipo:Arrays.asList("FALTA","TARJETA_AMARILLA","TARJETA_ROJA","OTRA"))caso("incidencia no anotadora " + tipo,()->{Caso c=new Caso(REGISTRAR_INCIDENCIA);c.p("tipoIncidencia",tipo);c.parametros.remove("idParticipante");c.parametros.remove("valorAnotacion");c.ejecutar(200);exigir(c.vinculados.get(5)==null && c.nulos.get(6)==Types.INTEGER);});
        caso("anotacion sin participante",()->{Caso c=new Caso(REGISTRAR_INCIDENCIA);c.parametros.remove("idParticipante");c.ejecutar(400);exigir(c.llamadas==0);});
        caso("tipo incidencia inexistente",()->{Caso c=new Caso(REGISTRAR_INCIDENCIA);c.p("tipoIncidencia","OTRO");c.ejecutar(400);});
        caso("tiempo no es entrada HTTP",()->{Caso c=new Caso(REGISTRAR_INCIDENCIA);c.p("segundoSimulacion","10");c.ejecutar(400);});
        caso("registro idempotente",()->{Caso c=new Caso(REGISTRAR_INCIDENCIA);c.tablas.get(0).filas.get(0).put("SolicitudIdempotente",true);exigir(c.ejecutar(200).at("/resultado/solicitudIdempotente").asBoolean());});
        caso("anulacion previamente anulada",()->{Caso c=new Caso(ANULAR_INCIDENCIA);c.tablas.get(0).filas.get(0).put("SinCambios",true);exigir(c.ejecutar(200).at("/resultado/sinCambios").asBoolean());});
        caso("BIGINT incidencia conserva rango",()->{Caso c=new Caso(ANULAR_INCIDENCIA);c.p("idIncidencia","9223372036854775807");c.tablas.get(0).filas.get(0).put("IdIncidencia",Long.MAX_VALUE);c.ejecutar(200);exigir(c.vinculados.get(2).equals(Long.MAX_VALUE));});
        caso("incidencia tipo incompatible",()->{Caso c=new Caso(REGISTRAR_INCIDENCIA);c.tablas.get(0).filas.get(0).put("IdIncidencia",29);c.ejecutar(500);});
        caso("marcador y primera anotacion oficiales sin sumar",()->{Caso c=new Caso(ESTADO_SIMULACION);JsonNode n=c.ejecutar(200).path("resultado");exigir(n.path("participantes").get(0).path("marcadorActual").asInt()==77 && n.path("idPrimeraAnotacion").asLong()==29);});
        caso("consulta despues de anular conserva datos SQL",()->{Caso c=new Caso(ESTADO_SIMULACION);Map<String,Object> h=c.tablas.get(0).filas.get(0);h.put("IdPrimeraAnotacion",null);h.put("IdPrimerParticipanteAnotador",null);Map<String,Object> i=c.tablas.get(2).filas.get(0);i.put("EsAnulada",true);i.put("MotivoAnulacion","Correccion");i.put("FechaAnulacionUtc",Timestamp.valueOf("2026-10-01 12:01:00"));c.tablas.get(1).filas.get(0).put("MarcadorActual",0);JsonNode n=c.ejecutar(200).path("resultado");exigir(n.path("idPrimeraAnotacion").isNull() && n.path("participantes").get(0).path("marcadorActual").asInt()==0);});
        caso("incidencia no anotadora no cambia marcador oficial",()->{Caso c=new Caso(ESTADO_SIMULACION);c.tablas.get(0).filas.get(0).put("IdPrimeraAnotacion",null);c.tablas.get(0).filas.get(0).put("IdPrimerParticipanteAnotador",null);Map<String,Object> i=c.tablas.get(2).filas.get(0);i.put("TipoIncidencia","FALTA");i.put("ValorAnotacion",null);exigir(c.ejecutar(200).at("/resultado/participantes/0/marcadorActual").asInt()==77);});
        caso("simulacion inexistente",()->{Caso c=new Caso(ESTADO_SIMULACION);for(Tabla t:c.tablas)t.filas.clear();c.ejecutar(404);});
        caso("consulta RS3 obligatorio",()->{Caso c=new Caso(ESTADO_SIMULACION);c.tablas.remove(2);c.ejecutar(500);});
        caso("consulta tipo marcador incorrecto",()->{Caso c=new Caso(ESTADO_SIMULACION);c.tablas.get(1).filas.get(0).put("MarcadorActual",new BigDecimal("1.5"));c.ejecutar(500);});
        caso("participante de incidencia ajeno",()->{Caso c=new Caso(ESTADO_SIMULACION);c.tablas.get(2).filas.get(0).put("IdParticipante",999);c.ejecutar(500);});
        for(int[] error:new int[][]{{76201,409},{76202,409},{76203,409},{76204,400},{76205,409},{76206,409},{76207,409},{76208,400},{76209,400},{76210,400},{76211,400},{76212,404},{76213,409},{76214,409},{76215,409},{76221,400}})caso("codigo SQL " + error[0],()->{Caso c=new Caso(REGISTRAR_INCIDENCIA);c.codigo=error[0];c.ejecutar(error[1]);});
        for(int[] error:new int[][]{{76001,400},{76002,409},{76003,409},{76004,409},{76005,400},{76006,409},{76007,409},{76008,409},{76009,409},{76010,400},{76011,409},{76012,409},{76013,409},{76014,409},{76015,409},{76016,409},{61042,403},{61048,409},{76302,404},{76900,503}})caso("rechazo administrativo SQL " + error[0],()->base(CREAR_EVENTO,c->c.j.codigo=error[0],error[1]));
        caso("consulta cabecera de otro evento",()->{Caso c=new Caso(ESTADO_SIMULACION);c.tablas.get(0).filas.get(0).put("IdEvento",999);c.ejecutar(500);});
        caso("columna obligatoria incluso RS vacio",()->{Caso c=new Caso(ESTADO_SIMULACION);c.tablas.get(2).filas.clear();c.tablas.get(2).columnas.remove("FechaAnulacionUtc");c.ejecutar(500);});
        caso("consulta BORRADOR sin incidencias",()->{Caso c=new Caso(ESTADO_SIMULACION);Map<String,Object> h=c.tablas.get(0).filas.get(0);h.put("EstadoEvento","BORRADOR");h.put("FechaInicioRealUtc",null);h.put("IdPrimeraAnotacion",null);h.put("IdPrimerParticipanteAnotador",null);c.tablas.get(1).filas.get(0).put("MarcadorActual",null);c.tablas.get(2).filas.clear();c.ejecutar(200);});
        caso("BIGINT desbordado",()->{Caso c=new Caso(ANULAR_INCIDENCIA);c.p("idIncidencia","9223372036854775808");c.ejecutar(400);exigir(c.llamadas==0);});
        caso("referencia duplicada HTTP",()->{Caso c=new Caso(REGISTRAR_INCIDENCIA);c.p("referenciaOperacion","a","b");c.ejecutar(400);exigir(c.llamadas==0);});
        caso("OPERADOR cancelacion rechazada por SQL",()->base(ESTADO_EVENTO,c->{c.p("nuevoEstado","CANCELADO");c.p("motivo","Cancelacion");c.h.previa.datos.put("adminRol","OPERADOR_EVENTOS");c.j.codigo=61042;},403));
        System.out.println("Contratos administrativos/incidencias: " + casos + " casos, 0 fallos; sin SQL real.");
    }
}
