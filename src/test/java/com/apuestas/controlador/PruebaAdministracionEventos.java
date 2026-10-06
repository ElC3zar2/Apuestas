package com.apuestas.controlador;

import com.apuestas.dao.AdministracionEventosDAO;
import com.apuestas.modelo.OperacionAdministracionEventos;
import com.apuestas.seguridad.ControlAccesoAdministrativo;
import com.apuestas.servicio.AdministracionEventosServicio;
import com.fasterxml.jackson.databind.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;
import static com.apuestas.modelo.OperacionAdministracionEventos.*;

/** Filtro -> servlet -> servicio -> DAO reales, JDBC estricto simulado. Sin SQL ni SMTP reales. */
public class PruebaAdministracionEventos {
    private static int casos;
    private static final String PRIVADO="DETALLE_SQL_PRIVADO";
    private static final ObjectMapper JSON=new ObjectMapper().enable(DeserializationFeature.USE_BIG_DECIMAL_FOR_FLOATS);
    private static Map<String,Object> fila(Object... pares) {
        Map<String,Object> r=new LinkedHashMap<>();
        for(int i=0;i<pares.length;i+=2) r.put((String)pares[i],pares[i+1]);
        return r;
    }
    private static Timestamp fecha() { return Timestamp.valueOf("2099-01-02 03:04:05.1234567"); }
    private static Map<String,Object> respuesta(OperacionAdministracionEventos op) {
        switch(op) {
            case CREAR_LIGA:case ACTUALIZAR_LIGA:
                return fila("IdLiga",11,"IdDeporte",2,"IdPais",null,"Nombre","Nombre","Activo",true);
            case CREAR_PARTICIPANTE:case ACTUALIZAR_PARTICIPANTE:
                return fila("IdParticipante",12,"IdDeporte",2,"IdPais",null,"Nombre","Nombre","TipoParticipante","ATLETA","Activo",true);
            case CREAR_EVENTO:case ACTUALIZAR_EVENTO:
                return fila("IdEvento",13,"IdLiga",11,"IdEstado",5,"EstadoEvento","BORRADOR","Nombre","Nombre","FechaInicio",fecha(),"FechaFin",null);
            case AGREGAR_PARTICIPANTE:
                return fila("IdEventoParticipante",14,"IdEvento",13,"IdParticipante",12,"OrdenParticipante",3,"EsLocal",null);
            case CREAR_MERCADO:
                return fila("IdMercado",15,"IdEvento",13,"IdEstado",6,"EstadoMercado","BORRADOR","Nombre","Nombre","Descripcion",null);
            case CREAR_SELECCION:
                return fila("IdSeleccion",16,"IdMercado",15,"Nombre","Nombre","Activo",true);
            case REGISTRAR_CUOTA:
                return fila("IdCuota",17,"IdSeleccion",16,"Valor",new BigDecimal("1.2345"),"FechaInicio",fecha(),"Activo",true,"IdCuotaAnterior",null);
            case ESTADO_EVENTO:
                return fila("IdEvento",13,"EstadoAnterior","BORRADOR","EstadoActual","PROGRAMADO","SinCambios",false);
            case ESTADO_MERCADO:
                return fila("IdMercado",15,"EstadoAnterior","BORRADOR","EstadoActual","ABIERTO","SinCambios",false);
            default:throw new AssertionError();
        }
    }
    private static String[] contrato(OperacionAdministracionEventos op) {
        // Orden y nombres independientes de los metadatos de produccion.
        switch(op) {
            case CREAR_LIGA:return new String[]{"sp_CrearLiga","idDeporte","nombre","idPais"};
            case ACTUALIZAR_LIGA:return new String[]{"sp_ActualizarLiga","idLiga","nombre","idPais","activo"};
            case CREAR_PARTICIPANTE:return new String[]{"sp_CrearParticipante","idDeporte","nombre","tipoParticipante","idPais"};
            case ACTUALIZAR_PARTICIPANTE:return new String[]{"sp_ActualizarParticipante","idParticipante","nombre","idPais","activo"};
            case CREAR_EVENTO:return new String[]{"sp_CrearEvento","idLiga","nombre","fechaInicio","fechaFin"};
            case ACTUALIZAR_EVENTO:return new String[]{"sp_ActualizarEvento","idEvento","nombre","fechaInicio","fechaFin"};
            case AGREGAR_PARTICIPANTE:return new String[]{"sp_AgregarParticipanteEvento","idEvento","idParticipante","ordenParticipante","esLocal"};
            case CREAR_MERCADO:return new String[]{"sp_CrearMercado","idEvento","nombre","descripcion"};
            case CREAR_SELECCION:return new String[]{"sp_CrearSeleccion","idMercado","nombre"};
            case REGISTRAR_CUOTA:return new String[]{"sp_RegistrarCuota","idSeleccion","valor"};
            case ESTADO_EVENTO:return new String[]{"sp_CambiarEstadoEvento","idEvento","nuevoEstado","motivo"};
            case ESTADO_MERCADO:return new String[]{"sp_CambiarEstadoMercado","idMercado","nuevoEstado","motivo"};
            default:throw new AssertionError();
        }
    }
    private static final Set<String> OPCIONALES=new HashSet<>(Arrays.asList("idPais","fechaFin","esLocal","descripcion","motivo"));
    static class Jdbc {
        final OperacionAdministracionEventos op;
        final List<List<Map<String,Object>>> resultados=new ArrayList<>();
        final Map<Integer,Object> params=new LinkedHashMap<>();
        final Map<Integer,Integer> nulos=new HashMap<>();
        int llamadas,indice,codigo,abiertos,cerrados;
        boolean conexionCerrada,statementCerrado,conteo,rsNull,falloConexion,falloPreparar,falloRuntime;
        Jdbc(OperacionAdministracionEventos op) { this.op=op;resultados.add(new ArrayList<>(Arrays.asList(respuesta(op)))); }
        Map<String,Object> fila() { return resultados.get(0).get(0); }
        Connection conexion() throws SQLException {
            llamadas++;
            if(falloConexion) throw new SQLException(PRIVADO);
            return proxy(Connection.class,(p,m,a)->{
                if(m.getName().equals("close")) { conexionCerrada=true;return null; }
                if(m.getName().equals("prepareCall")) {
                    if(falloPreparar) throw new SQLException(PRIVADO);
                    String[] contrato=contrato(op);
                    exigir(a[0].equals("{call dbo."+contrato[0]+"("+String.join(", ",Collections.nCopies(contrato.length+1,"?"))+")}"));
                    return statement();
                }
                throw new AssertionError(m.getName());
            });
        }
        CallableStatement statement() {
            return proxy(CallableStatement.class,(p,m,a)->{
                switch(m.getName()) {
                    case "setInt":case "setBoolean":case "setString":case "setTimestamp":case "setBigDecimal":
                        params.put((Integer)a[0],a[1]);return null;
                    case "setNull":params.put((Integer)a[0],null);nulos.put((Integer)a[0],(Integer)a[1]);return null;
                    case "execute":
                        if(codigo!=0) throw new SQLException(PRIVADO,"TEST",codigo);
                        if(falloRuntime) throw new IllegalStateException(PRIVADO);
                        indice=conteo?-1:0;return indice>=0&&!resultados.isEmpty();
                    case "getMoreResults":return ++indice<resultados.size();
                    case "getUpdateCount":return indice==-1?2:-1;
                    case "getResultSet":return rsNull?null:rs(resultados.get(indice));
                    case "close":statementCerrado=true;return null;
                    default:throw new AssertionError(m.getName());
                }
            });
        }
        ResultSet rs(List<Map<String,Object>> filas) {
            abiertos++;int[] pos={-1};boolean[] nulo={false};
            return proxy(ResultSet.class,(p,m,a)->{
                switch(m.getName()) {
                    case "next":return ++pos[0]<filas.size();
                    case "close":cerrados++;return null;
                    case "wasNull":return nulo[0];
                }
                String col=(String)a[0];Map<String,Object> f=filas.get(pos[0]);
                if(!f.containsKey(col)) throw new SQLException(PRIVADO);
                Object v=f.get(col);nulo[0]=v==null;
                switch(m.getName()) {
                    case "getInt":return v==null?0:(Integer)v;
                    case "getString":return (String)v;
                    case "getBoolean":return v==null?false:(Boolean)v;
                    case "getTimestamp":return (Timestamp)v;
                    case "getBigDecimal":return (BigDecimal)v;
                    default:throw new AssertionError(m.getName());
                }
            });
        }
    }
    static class Caso {
        final OperacionAdministracionEventos op;
        final Http h=new Http();
        final Jdbc j;
        final Map<String,String[]> params=new LinkedHashMap<>();
        final HttpServletRequest req;
        boolean directo;
        String ip="127.0.0.1";
        Caso(OperacionAdministracionEventos op) {
            this.op=op;j=new Jdbc(op);h.ruta=op.ruta;
            h.previa=new Sesion();h.previa.datos.put("adminIdUsuario",7);h.previa.datos.put("adminIdRol",3);
            h.previa.datos.put("adminCorreo","admin@example.test");h.previa.datos.put("adminRol","ADMINISTRADOR");
            h.previa.datos.put("adminEstadoUsuario","ACTIVO");
            for(String k:op.parametros) {
                switch(k) {
                    case "idDeporte":p(k,"2");break;
                    case "idLiga":p(k,"11");break;
                    case "idParticipante":p(k,"12");break;
                    case "idEvento":p(k,"13");break;
                    case "idMercado":p(k,"15");break;
                    case "idSeleccion":p(k,"16");break;
                    case "ordenParticipante":p(k,"3");break;
                    case "nombre":p(k,"Nombre");break;
                    case "tipoParticipante":p(k,"ATLETA");break;
                    case "activo":p(k,"true");break;
                    case "fechaInicio":p(k,"2099-01-02T03:04:05.1234567");break;
                    case "valor":p(k,"1.2345");break;
                    case "nuevoEstado":p(k,op==ESTADO_EVENTO?"PROGRAMADO":"ABIERTO");break;
                    default:exigir(OPCIONALES.contains(k));
                }
            }
            req=proxy(HttpServletRequest.class,(p,m,a)->{
                if(m.getName().equals("getParameterMap")) { exigir("UTF-8".equals(h.encoding));return params; }
                if(m.getName().equals("getRemoteAddr")) return ip;
                try { return m.invoke(h.req,a); } catch(InvocationTargetException e) { throw e.getCause(); }
            });
        }
        void p(String nombre,String... valores) { params.put(nombre,valores); }
        JsonNode ejecutar(int estado) throws Exception {
            AdministracionEventosServlet s=new AdministracionEventosServlet();
            Field f=AdministracionEventosServlet.class.getDeclaredField("servicio");f.setAccessible(true);
            f.set(s,new AdministracionEventosServicio(new AdministracionEventosDAO() {
                @Override protected Connection obtenerConexion() throws SQLException { return j.conexion(); }
            }));
            if(directo) s.service(req,h.res);
            else new ControlAccesoAdministrativo().doFilter(req,h.res,(r,res)->s.service((HttpServletRequest)r,(HttpServletResponse)res));
            if(h.status!=estado) throw new AssertionError(op+" HTTP esperado "+estado+", recibido "+h.status);
            if(!"application/json;charset=UTF-8".equals(h.tipo)) throw new AssertionError(op+" Content-Type no JSON");
            exigir("no-store".equals(h.headers.get("Cache-Control"))&&h.creaciones==0);
            String body=h.body.toString();
            exigir(!body.contains(PRIVADO)&&!body.contains("dbo.")&&!body.contains("SQLException")&&!body.contains("SECRETO_INTERNO"));
            JsonNode json=JSON.readTree(body);
            exigir(json.get("ok").asBoolean()==(estado==200)&&json.size()==2);
            exigir(json.has(estado==200?"resultado":"mensaje"));
            if(j.llamadas>0) {
                exigir(j.llamadas==1&&j.abiertos==j.cerrados);
                if(!j.falloConexion) exigir(j.conexionCerrada);
                if(!j.falloConexion&&!j.falloPreparar) exigir(j.statementCerrado);
                if(!j.params.isEmpty()) comprobarParametros();
            }
            casos++;return json;
        }
        void comprobarParametros() {
            String[] orden=contrato(op);
            exigir(j.params.size()==orden.length+1&&j.params.get(1).equals(7));
            exigir(Objects.equals(j.params.get(orden.length+1),ip==null?null:ip.trim()));
            for(int i=1;i<orden.length;i++) {
                String k=orden[i];String[] raw=params.get(k);String v=raw==null?null:raw[0].trim();
                if(v!=null&&v.isEmpty()) v=null;
                Object esperado=v;
                if(v!=null) {
                    if(k.startsWith("id")||k.equals("ordenParticipante")) esperado=Integer.valueOf(v);
                    else if(k.equals("activo")||k.equals("esLocal")) esperado=v.equals("true")||v.equals("1");
                    else if(k.startsWith("fecha")) esperado=Timestamp.valueOf(v.replace('T',' '));
                    else if(k.equals("valor")) esperado=new BigDecimal(v);
                    else if(k.equals("tipoParticipante")||k.equals("nuevoEstado")) esperado=v.toUpperCase(Locale.ROOT);
                } else {
                    int tipo=k.equals("idPais")?Types.INTEGER:k.equals("esLocal")?Types.BIT:k.equals("fechaFin")?Types.TIMESTAMP:Types.VARCHAR;
                    exigir(Objects.equals(j.nulos.get(i+1),tipo));
                }
                exigir(Objects.equals(esperado,j.params.get(i+1)));
            }
        }
    }
    private static int sqlEsperado(int c) {
        if(Arrays.asList(59002,59003,59004).contains(c)) return 403;
        if(Arrays.asList(59013,59025,59037,59040,59048,59052,59056,59062,59069).contains(c)) return 404;
        if(Arrays.asList(59008,59014,59015,59020,59026,59027,59038,59041,59043,59044,59045,59049,59050,59053,59054,59057,59058,59063,59064,59070,59071,59072,59073).contains(c)) return 409;
        if(Arrays.asList(59032,59047,59065).contains(c)||c<59001||c>59073) return 500;
        return 400;
    }
    public static void main(String[] args) throws Exception {
        if(args.length>0) {
            Caso c=new Caso(CREAR_LIGA);c.h.previa=null;c.ejecutar(401);
            System.out.println("Filtro eventos JSON: OK");return;
        }
        Set<String> rutas=new HashSet<>(Arrays.asList(AdministracionEventosServlet.class.getAnnotation(WebServlet.class).value()));
        exigir(rutas.size()==12);
        for(OperacionAdministracionEventos op:OperacionAdministracionEventos.values()) {
            exigir(rutas.contains(op.ruta));
            Caso c=new Caso(op);c.ejecutar(200);
            c=new Caso(op);c.j.conteo=true;c.ejecutar(200);
            c=new Caso(op);c.h.previa=null;c.ejecutar(401);exigir(c.j.llamadas==0);
            c=new Caso(op);c.h.previa.expirada=true;c.ejecutar(401);
            c=new Caso(op);c.h.previa.falloLectura=true;c.ejecutar(500);
            c=new Caso(op);c.directo=true;c.h.previa=null;c.ejecutar(401);
            c=new Caso(op);c.directo=true;c.h.previa.expirada=true;c.ejecutar(401);
            c=new Caso(op);c.h.previa.datos.put("idUsuario",99);c.h.previa.datos.put("rol","USUARIO");c.ejecutar(403);
            for(String rol:new String[]{"ADMINISTRADOR","OPERADOR_EVENTOS","AUDITOR","CAJERO","CASA","USUARIO","administrador"}) {
                c=new Caso(op);c.h.previa.datos.put("adminRol",rol);
                int estado=rol.equals("ADMINISTRADOR")||rol.equals("OPERADOR_EVENTOS")?200:403;
                c.ejecutar(estado);if(estado==403) exigir(c.j.llamadas==0);
            }
            for(String metodo:new String[]{"GET","HEAD","PUT","PATCH","DELETE","OPTIONS"}) {
                c=new Caso(op);c.h.method=metodo;c.ejecutar(405);
                exigir("POST".equals(c.h.headers.get("Allow"))&&c.j.llamadas==0);
            }
            for(String intruso:new String[]{"idUsuarioProceso","idAdministrador","usuarioProceso","correoAdministrador","rolAdministrador","IpOrigen","ipOrigen","otro"}) {
                c=new Caso(op);c.p(intruso,"99");c.ejecutar(400);exigir(c.j.llamadas==0);
            }
            for(String k:op.parametros) {
                c=new Caso(op);c.p(k,"1","2");c.ejecutar(400);exigir(c.j.llamadas==0);
                c=new Caso(op);c.p(k,new String[0]);c.ejecutar(400);
                c=new Caso(op);c.p(k,(String[])null);c.ejecutar(400);
                c=new Caso(op);c.p(k,(String)null);c.ejecutar(400);
                if(!OPCIONALES.contains(k)) {
                    c=new Caso(op);c.params.remove(k);c.ejecutar(400);
                    c=new Caso(op);c.p(k," ");c.ejecutar(400);
                }
                if(k.startsWith("id")||k.equals("ordenParticipante")) {
                    for(String v:new String[]{"0","-1","abc","1.5","2147483648","1 OR 1=1"}) {
                        c=new Caso(op);c.p(k,v);c.ejecutar(400);exigir(c.j.llamadas==0);
                    }
                }
            }
            c=new Caso(op);c.j.codigo=99999;c.ejecutar(500);
            c=new Caso(op);c.j.falloRuntime=true;c.ejecutar(500);
            c=new Caso(op);c.j.falloConexion=true;c.ejecutar(500);
            c=new Caso(op);c.j.falloPreparar=true;c.ejecutar(500);
            c=new Caso(op);c.j.resultados.clear();c.ejecutar(500);
            c=new Caso(op);c.j.resultados.get(0).clear();c.ejecutar(500);
            c=new Caso(op);c.j.resultados.get(0).add(respuesta(op));c.ejecutar(500);
            c=new Caso(op);c.j.resultados.add(new ArrayList<>());c.ejecutar(500);
            c=new Caso(op);c.j.rsNull=true;c.ejecutar(500);
            for(Map.Entry<String,Object> col:respuesta(op).entrySet()) {
                c=new Caso(op);c.j.fila().remove(col.getKey());c.ejecutar(500);
                if(col.getValue()!=null) {
                    c=new Caso(op);c.j.fila().put(col.getKey(),null);c.ejecutar(500);
                }
                if(col.getKey().startsWith("Id")) {
                    c=new Caso(op);c.j.fila().put(col.getKey(),0);c.ejecutar(500);
                }
            }
            if(op.parametros.contains("nombre")) {
                int max=op==CREAR_EVENTO||op==ACTUALIZAR_EVENTO?200:150;
                c=new Caso(op);c.p("nombre","x".repeat(max));c.j.fila().put("Nombre","x".repeat(max));c.ejecutar(200);
                c=new Caso(op);c.p("nombre","x".repeat(max+1));c.ejecutar(400);
                c=new Caso(op);String nombre="Texto \"citado\"\n\tfin";
                c.p("nombre",nombre);c.j.fila().put("Nombre",nombre);
                exigir(c.ejecutar(200).at("/resultado/nombre").asText().equals(nombre));
            }
        }
        for(int codigo=59001;codigo<=59073;codigo++) {
            Caso c=new Caso(CREAR_LIGA);c.j.codigo=codigo;c.ejecutar(sqlEsperado(codigo));
        }
        for(OperacionAdministracionEventos op:new OperacionAdministracionEventos[]{CREAR_LIGA,ACTUALIZAR_LIGA,CREAR_PARTICIPANTE,ACTUALIZAR_PARTICIPANTE}) {
            Caso c=new Caso(op);c.p("idPais","1");c.j.fila().put("IdPais",1);c.ejecutar(200);
        }
        for(OperacionAdministracionEventos op:new OperacionAdministracionEventos[]{ACTUALIZAR_LIGA,ACTUALIZAR_PARTICIPANTE}) {
            for(String activo:new String[]{"true","false","1","0"}) {
                Caso c=new Caso(op);c.p("activo",activo);c.j.fila().put("Activo",activo.equals("true")||activo.equals("1"));c.ejecutar(200);
            }
            Caso c=new Caso(op);c.p("activo","yes");c.ejecutar(400);
        }
        for(String tipo:new String[]{"EQUIPO","ATLETA"," atleta "}) {
            Caso c=new Caso(CREAR_PARTICIPANTE);c.p("tipoParticipante",tipo);c.j.fila().put("TipoParticipante",tipo.trim().toUpperCase(Locale.ROOT));c.ejecutar(200);
        }
        Caso c=new Caso(CREAR_PARTICIPANTE);c.p("tipoParticipante","OTRO");c.ejecutar(400);
        for(OperacionAdministracionEventos op:new OperacionAdministracionEventos[]{CREAR_EVENTO,ACTUALIZAR_EVENTO}) {
            for(String campo:new String[]{"fechaInicio","fechaFin"}) {
                for(String f:new String[]{"2026-02-30T12:00:00","0000-01-01T00:00:00","2026-01-01","2026-01-01T00:00:00Z","2026-01-01T00:00:00.12345678"}) {
                    c=new Caso(op);c.p(campo,f);c.ejecutar(400);
                }
            }
            c=new Caso(op);c.p("fechaFin","2099-01-03T00:00:00");c.j.fila().put("FechaFin",Timestamp.valueOf("2099-01-03 00:00:00"));c.ejecutar(200);
            c=new Caso(op);c.p("fechaFin","2000-01-01T00:00:00");c.j.codigo=op==CREAR_EVENTO?59030:59036;c.ejecutar(400);
        }
        for(String orden:new String[]{"1","255"}) {
            c=new Caso(AGREGAR_PARTICIPANTE);c.p("ordenParticipante",orden);c.j.fila().put("OrdenParticipante",Integer.valueOf(orden));c.ejecutar(200);
        }
        c=new Caso(AGREGAR_PARTICIPANTE);c.p("ordenParticipante","256");c.ejecutar(400);
        for(String local:new String[]{"true","false","1","0"}) {
            c=new Caso(AGREGAR_PARTICIPANTE);c.p("esLocal",local);c.j.fila().put("EsLocal",local.equals("true")||local.equals("1"));c.ejecutar(200);
        }
        c=new Caso(AGREGAR_PARTICIPANTE);c.p("esLocal","2");c.ejecutar(400);
        for(String v:new String[]{"1.0001","999999.9999","2","2.1000"}) {
            c=new Caso(REGISTRAR_CUOTA);c.p("valor",v);c.j.fila().put("Valor",new BigDecimal(v).setScale(4));
            exigir(c.ejecutar(200).at("/resultado/valor").decimalValue().compareTo(new BigDecimal(v))==0);
            exigir(c.j.params.get(3).equals(new BigDecimal(v)));
        }
        for(String v:new String[]{"0","1","-2","NaN","Infinity","1000000","1.00001","2.00000","1e2","2,5"}) {
            c=new Caso(REGISTRAR_CUOTA);c.p("valor",v);c.ejecutar(400);exigir(c.j.llamadas==0);
        }
        c=new Caso(REGISTRAR_CUOTA);c.j.fila().put("IdCuotaAnterior",10);c.ejecutar(200);
        c=new Caso(REGISTRAR_CUOTA);c.j.fila().put("IdCuotaAnterior",17);c.ejecutar(500);
        c=new Caso(REGISTRAR_CUOTA);c.j.fila().put("Valor",new BigDecimal("1.2346"));c.ejecutar(500);
        for(OperacionAdministracionEventos op:new OperacionAdministracionEventos[]{ESTADO_EVENTO,ESTADO_MERCADO}) {
            String[] estados=op==ESTADO_EVENTO?new String[]{"BORRADOR","PROGRAMADO","EN_VIVO","SUSPENDIDO","PENDIENTE_RESULTADO","FINALIZADO","CANCELADO"}:
                    new String[]{"BORRADOR","ABIERTO","SUSPENDIDO","CERRADO","LIQUIDADO","ANULADO"};
            for(String estado:estados) {
                c=new Caso(op);c.p("nuevoEstado",estado);
                c.j.fila().put("EstadoActual",estado);c.j.fila().put("EstadoAnterior",estado);c.j.fila().put("SinCambios",true);
                exigir(c.ejecutar(200).at("/resultado/sinCambios").asBoolean());
            }
            c=new Caso(op);c.p("nuevoEstado","DESCONOCIDO");c.ejecutar(400);
            c=new Caso(op);c.j.codigo=op==ESTADO_EVENTO?59063:59070;c.ejecutar(409);
            c=new Caso(op);c.j.fila().put("SinCambios",true);c.ejecutar(500);
            c=new Caso(op);c.p("motivo","x".repeat(250));c.ejecutar(200);
            c=new Caso(op);c.p("motivo","x".repeat(251));c.ejecutar(400);
        }
        c=new Caso(CREAR_MERCADO);c.p("descripcion","x".repeat(250));c.j.fila().put("Descripcion","x".repeat(250));c.ejecutar(200);
        c=new Caso(CREAR_MERCADO);c.p("descripcion","x".repeat(251));c.ejecutar(400);
        for(Object id:new Object[]{null,0,-1,"7",7L}) {
            c=new Caso(CREAR_LIGA);c.h.previa.datos.put("adminIdUsuario",id);c.ejecutar(403);
        }
        for(String k:new String[]{"adminIdRol","adminCorreo","adminRol","adminEstadoUsuario"}) {
            c=new Caso(CREAR_LIGA);c.h.previa.datos.remove(k);c.ejecutar(403);
        }
        c=new Caso(CREAR_LIGA);c.h.previa.datos.put("adminEstadoUsuario","SUSPENDIDO");c.ejecutar(403);
        c=new Caso(CREAR_LIGA);c.directo=true;c.h.ruta="/administrador/desconocido";c.ejecutar(404);
        c=new Caso(CREAR_LIGA);c.ip="2001:db8::1";c.ejecutar(200);
        c=new Caso(CREAR_LIGA);c.ip="x".repeat(46);c.ejecutar(400);
        // Identidades de respuesta, proyeccion publica y nulos opcionales.
        for(OperacionAdministracionEventos op:OperacionAdministracionEventos.values()) {
            c=new Caso(op);
            c.j.fila().put("Contrasena",PRIVADO);c.j.fila().put("Token",PRIVADO);
            JsonNode salida=c.ejecutar(200).get("resultado");
            exigir(salida.size()==respuesta(op).size());
            for(String columna:respuesta(op).keySet()) {
                String propiedad=Character.toLowerCase(columna.charAt(0))+columna.substring(1);
                exigir(salida.has(propiedad));
            }
            String campoId;
            switch(op) {
                case CREAR_LIGA:case CREAR_PARTICIPANTE:campoId="IdDeporte";break;
                case ACTUALIZAR_LIGA:case CREAR_EVENTO:campoId="IdLiga";break;
                case ACTUALIZAR_PARTICIPANTE:campoId="IdParticipante";break;
                case ACTUALIZAR_EVENTO:case AGREGAR_PARTICIPANTE:case CREAR_MERCADO:case ESTADO_EVENTO:campoId="IdEvento";break;
                case CREAR_SELECCION:case ESTADO_MERCADO:campoId="IdMercado";break;
                case REGISTRAR_CUOTA:campoId="IdSeleccion";break;
                default:throw new AssertionError();
            }
            c=new Caso(op);c.j.fila().put(campoId,999);c.ejecutar(500);
            c=new Caso(op);c.j.fila().put(campoId,"tipo-incorrecto");c.ejecutar(500);
            for(String opcional:op.parametros) {
                if(OPCIONALES.contains(opcional)) {
                    c=new Caso(op);c.p(opcional," ");c.ejecutar(200);
                }
            }
        }
        for(OperacionAdministracionEventos op:new OperacionAdministracionEventos[]{ESTADO_EVENTO,ESTADO_MERCADO}) {
            c=new Caso(op);c.p("nuevoEstado",op==ESTADO_EVENTO?" programado ":" abierto ");c.ejecutar(200);
        }
        c=new Caso(CREAR_EVENTO);c.p("fechaInicio","0001-01-01T00:00:00");
        c.j.fila().put("FechaInicio",Timestamp.valueOf("0001-01-01 00:00:00"));c.ejecutar(200);
        c=new Caso(CREAR_EVENTO);c.p("fechaInicio","9999-12-31T23:59:59.9999999");
        c.j.fila().put("FechaInicio",Timestamp.valueOf("9999-12-31 23:59:59.9999999"));c.ejecutar(200);
        System.out.println("Administracion eventos: "+casos+" casos, 0 fallos.");
    }
}