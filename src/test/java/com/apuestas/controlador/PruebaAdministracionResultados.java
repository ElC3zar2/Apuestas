package com.apuestas.controlador;

import com.apuestas.dao.AdministracionResultadosDAO;
import com.apuestas.modelo.OperacionAdministracionResultados;
import com.apuestas.seguridad.ControlAccesoAdministrativo;
import com.apuestas.servicio.AdministracionResultadosServicio;
import com.fasterxml.jackson.databind.*;
import java.lang.reflect.*;
import java.sql.*;
import java.util.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;
import static com.apuestas.modelo.OperacionAdministracionResultados.*;

/** Flujo HTTP/servicio/DAO real con JDBC estricto sin red. Prohibe otras consultas y transacciones Java. */
public class PruebaAdministracionResultados {
    private static int casos;
    private static final String PRIVADO="SECRETO_SQL_RESULTADOS";
    private static final ObjectMapper JSON=new ObjectMapper();
    private static Map<String,Object> fila(Object... valores) {
        Map<String,Object> r=new LinkedHashMap<>();
        for(int i=0;i<valores.length;i+=2) r.put((String)valores[i],valores[i+1]);
        return r;
    }
    private static Map<String,Object> respuesta(OperacionAdministracionResultados op) {
        switch(op) {
            case REGISTRAR:return fila("IdResultado",31,"IdEvento",13,"EstadoResultado","PENDIENTE","ResultadoTexto","Resultado deportivo","Observacion",null);
            case RESOLVER:return fila("IdResolucion",41,"IdResultadoEvento",31,"IdSeleccion",16,"Resultado","GANADA","Observacion",null);
            case OFICIALIZAR:return fila("IdResultado",31,"IdEvento",13,"EstadoResultado","OFICIAL","EstadoEvento","FINALIZADO","SinCambios",false);
            case CORREGIR:return fila("IdResultado",31,"IdEvento",13,"EstadoResultado","CORREGIDO","EstadoEvento","PENDIENTE_RESULTADO","RequiereNuevaResolucion",true);
            case ANULAR:return fila("IdResultado",31,"IdEvento",13,"EstadoResultado","ANULADO","EstadoEvento","CANCELADO","SinCambios",false);
            default:throw new AssertionError();
        }
    }
    private static String[] contrato(OperacionAdministracionResultados op) {
        // Contratos independientes de los metadatos usados por produccion.
        switch(op) {
            case REGISTRAR:return new String[]{"sp_RegistrarResultadoEvento","idEvento","resultadoTexto","observacion"};
            case RESOLVER:return new String[]{"sp_ResolverSeleccion","idResultadoEvento","idSeleccion","resultado","observacion"};
            case OFICIALIZAR:return new String[]{"sp_OficializarResultadoEvento","idResultadoEvento","observacion"};
            case CORREGIR:return new String[]{"sp_CorregirResultadoEvento","idResultadoEvento","nuevoResultadoTexto","motivo"};
            case ANULAR:return new String[]{"sp_AnularResultadoEvento","idResultadoEvento","motivo"};
            default:throw new AssertionError();
        }
    }
    static class Jdbc {
        final OperacionAdministracionResultados op;
        final List<List<Map<String,Object>>> resultados=new ArrayList<>();
        final Map<Integer,Object> params=new LinkedHashMap<>();
        final Map<Integer,Integer> nulos=new HashMap<>();
        int conexiones,llamadas,ejecuciones,indice,abiertos,cerrados,codigo;
        boolean conexionCerrada,statementCerrado,conteo,rsNull,falloConexion,falloPreparar,falloRuntime,falloPosterior;
        Jdbc(OperacionAdministracionResultados op) { this.op=op;resultados.add(new ArrayList<>(Arrays.asList(respuesta(op)))); }
        Map<String,Object> fila() { return resultados.get(0).get(0); }
        Connection conexion() throws SQLException {
            conexiones++;
            if(falloConexion) throw new SQLException(PRIVADO);
            return proxy(Connection.class,(p,m,a)->{
                if(m.getName().equals("close")) { conexionCerrada=true;return null; }
                if(m.getName().equals("prepareCall")) {
                    llamadas++;
                    if(falloPreparar) throw new SQLException(PRIVADO);
                    String[] contrato=contrato(op);
                    exigir(a[0].equals("{call dbo."+contrato[0]+"("+String.join(", ",Collections.nCopies(contrato.length+1,"?"))+")}"));
                    return sentencia();
                }
                // Ningun prepareStatement, commit, rollback ni operacion financiera permitida.
                throw new AssertionError("Operacion JDBC inesperada: "+m.getName());
            });
        }
        CallableStatement sentencia() {
            return proxy(CallableStatement.class,(p,m,a)->{
                switch(m.getName()) {
                    case "setInt":case "setString":params.put((Integer)a[0],a[1]);return null;
                    case "setNull":params.put((Integer)a[0],null);nulos.put((Integer)a[0],(Integer)a[1]);return null;
                    case "execute":
                        ejecuciones++;
                        if(codigo!=0) throw new SQLException(PRIVADO,"TEST",codigo);
                        if(falloRuntime) throw new IllegalStateException(PRIVADO);
                        indice=conteo?-1:0;return indice>=0&&!resultados.isEmpty();
                    case "getMoreResults":
                        if(falloPosterior) throw new SQLException(PRIVADO);
                        return ++indice<resultados.size();
                    case "getUpdateCount":return indice==-1?2:-1;
                    case "getResultSet":return rsNull?null:rs(resultados.get(indice));
                    case "close":statementCerrado=true;return null;
                    default:throw new AssertionError(m.getName());
                }
            });
        }
        ResultSet rs(List<Map<String,Object>> filas) {
            abiertos++;int[] pos={-1};
            return proxy(ResultSet.class,(p,m,a)->{
                switch(m.getName()) {
                    case "next":return ++pos[0]<filas.size();
                    case "close":cerrados++;return null;
                    case "getObject":
                        Map<String,Object> r=filas.get(pos[0]);
                        if(!r.containsKey(a[0])) throw new SQLException(PRIVADO);
                        return r.get(a[0]);
                    default:throw new AssertionError(m.getName());
                }
            });
        }
    }
    static class Caso {
        final OperacionAdministracionResultados op;
        final Http h=new Http();
        final Jdbc j;
        final Map<String,String[]> params=new LinkedHashMap<>();
        final HttpServletRequest req;
        String ip="127.0.0.1";
        boolean directo;
        Caso(OperacionAdministracionResultados op) {
            this.op=op;j=new Jdbc(op);h.ruta=op.ruta;
            h.previa=new Sesion();h.previa.datos.put("adminIdUsuario",7);h.previa.datos.put("adminIdRol",3);
            h.previa.datos.put("adminCorreo","admin@example.test");h.previa.datos.put("adminRol","ADMINISTRADOR");
            h.previa.datos.put("adminEstadoUsuario","ACTIVO");
            for(String campo:op.parametros) {
                switch(campo) {
                    case "idEvento":p(campo,"13");break;
                    case "idResultadoEvento":p(campo,"31");break;
                    case "idSeleccion":p(campo,"16");break;
                    case "resultadoTexto":p(campo,"Resultado deportivo");break;
                    case "nuevoResultadoTexto":p(campo,"Resultado corregido");break;
                    case "resultado":p(campo,"GANADA");break;
                    case "motivo":p(campo,"Motivo");break;
                    case "observacion":break;
                    default:throw new AssertionError();
                }
            }
            req=proxy(HttpServletRequest.class,(p,m,a)->{
                if(m.getName().equals("getParameterMap")) { exigir("UTF-8".equals(h.encoding));return params; }
                if(m.getName().equals("getRemoteAddr")) return ip;
                try { return m.invoke(h.req,a); } catch(InvocationTargetException e) { throw e.getCause(); }
            });
        }
        void p(String campo,String... valores) { params.put(campo,valores); }
        JsonNode ejecutar(int esperado) throws Exception {
            AdministracionResultadosServlet s=new AdministracionResultadosServlet();
            Field f=AdministracionResultadosServlet.class.getDeclaredField("servicio");f.setAccessible(true);
            f.set(s,new AdministracionResultadosServicio(new AdministracionResultadosDAO() {
                @Override protected Connection obtenerConexion() throws SQLException { return j.conexion(); }
            }));
            if(directo) s.service(req,h.res);
            else new ControlAccesoAdministrativo().doFilter(req,h.res,(r,res)->s.service((HttpServletRequest)r,(HttpServletResponse)res));
            if(h.status!=esperado) throw new AssertionError(op+" HTTP esperado "+esperado+", recibido "+h.status);
            if(!"application/json;charset=UTF-8".equals(h.tipo)) throw new AssertionError(op+" Content-Type no JSON");
            exigir("no-store".equals(h.headers.get("Cache-Control"))&&h.creaciones==0);
            String body=h.body.toString();
            exigir(!body.contains(PRIVADO)&&!body.contains("dbo.")&&!body.contains("SQLException")&&!body.contains("SECRETO_INTERNO"));
            JsonNode json=JSON.readTree(body);
            exigir(json.size()==2&&json.path("ok").asBoolean()==(esperado==200)&&json.has(esperado==200?"resultado":"mensaje"));
            if(j.conexiones>0) {
                exigir(j.conexiones==1&&j.abiertos==j.cerrados);
                if(!j.falloConexion) {
                    exigir(j.conexionCerrada&&j.llamadas==1);
                    if(!j.falloPreparar) { exigir(j.statementCerrado&&j.ejecuciones==1);comprobarParametros(); }
                }
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
                if(v==null) exigir(Objects.equals(j.nulos.get(i+1),Types.VARCHAR));
                else if(k.startsWith("id")) esperado=Integer.valueOf(v);
                else if(k.equals("resultado")) esperado=v.toUpperCase(Locale.ROOT);
                exigir(Objects.equals(esperado,j.params.get(i+1)));
            }
        }
    }
    private static int esperadoSql(int codigo) {
        if(Arrays.asList(59001,61001,61002,61007,61008,61009,61016,61025,61026,61027,61028,61038,61039,61040).contains(codigo)) return 400;
        if(Arrays.asList(59002,59003,59004,61029,61030,61031,61041,61042,61043).contains(codigo)) return 403;
        if(Arrays.asList(61004,61010,61012,61020,61035,61047).contains(codigo)) return 404;
        if(Arrays.asList(61005,61006,61011,61013,61014,61015,61021,61022,61023,61024,61036,61037,61048).contains(codigo)) return 409;
        return 500;
    }
    public static void main(String[] args) throws Exception {
        if(args.length>0) {
            Caso c=new Caso(REGISTRAR);c.h.previa=null;c.ejecutar(401);
            System.out.println("Filtro resultados JSON: OK");return;
        }
        Set<String> rutas=new HashSet<>(Arrays.asList(AdministracionResultadosServlet.class.getAnnotation(WebServlet.class).value()));
        exigir(rutas.size()==5);
        for(OperacionAdministracionResultados op:OperacionAdministracionResultados.values()) {
            exigir(rutas.contains(op.ruta));
            Caso c=new Caso(op);JsonNode resultado=c.ejecutar(200).get("resultado");
            exigir(resultado.size()==respuesta(op).size());
            for(String col:respuesta(op).keySet()) exigir(resultado.has(Character.toLowerCase(col.charAt(0))+col.substring(1)));
            c=new Caso(op);c.j.conteo=true;c.ejecutar(200);
            for(String rol:new String[]{"ADMINISTRADOR","OPERADOR_EVENTOS","AUDITOR","CAJERO","CASA","USUARIO","administrador"}) {
                boolean permitido=rol.equals("ADMINISTRADOR")||(rol.equals("OPERADOR_EVENTOS")&&(op==REGISTRAR||op==RESOLVER||op==OFICIALIZAR));
                c=new Caso(op);c.h.previa.datos.put("adminRol",rol);c.ejecutar(permitido?200:403);
                if(!permitido) exigir(c.j.conexiones==0);
            }
            c=new Caso(op);c.h.previa=null;c.ejecutar(401);exigir(c.j.conexiones==0);
            c=new Caso(op);c.h.previa.expirada=true;c.ejecutar(401);
            c=new Caso(op);c.h.previa.falloLectura=true;c.ejecutar(500);
            c=new Caso(op);c.directo=true;c.h.previa=null;c.ejecutar(401);
            c=new Caso(op);c.directo=true;c.h.previa.expirada=true;c.ejecutar(401);
            c=new Caso(op);c.h.previa.datos.put("idUsuario",99);c.h.previa.datos.put("rol","USUARIO");c.ejecutar(403);
            for(String campo:new String[]{"adminIdUsuario","adminIdRol","adminCorreo","adminRol","adminEstadoUsuario"}) {
                c=new Caso(op);c.h.previa.datos.remove(campo);c.ejecutar(403);
            }
            for(Object id:new Object[]{0,-1,"7",7L}) {
                c=new Caso(op);c.h.previa.datos.put("adminIdUsuario",id);c.ejecutar(403);
            }
            c=new Caso(op);c.h.previa.datos.put("adminEstadoUsuario","SUSPENDIDO");c.ejecutar(403);
            for(String metodo:new String[]{"GET","HEAD","PUT","PATCH","DELETE","OPTIONS"}) {
                c=new Caso(op);c.h.method=metodo;c.ejecutar(405);
                exigir("POST".equals(c.h.headers.get("Allow"))&&c.j.conexiones==0);
            }
            for(String intruso:new String[]{"idUsuarioProceso","idAdministrador","usuarioProceso","correoAdministrador","rolAdministrador","IpOrigen","ipOrigen","otro","saldo","liquidar"}) {
                c=new Caso(op);c.p(intruso,"99");c.ejecutar(400);exigir(c.j.conexiones==0);
            }
            for(String k:op.parametros) {
                c=new Caso(op);c.p(k,"1","2");c.ejecutar(400);exigir(c.j.conexiones==0);
                c=new Caso(op);c.p(k,new String[0]);c.ejecutar(400);
                c=new Caso(op);c.p(k,(String[])null);c.ejecutar(400);
                c=new Caso(op);c.p(k,(String)null);c.ejecutar(400);
                if(!k.equals("observacion")) {
                    c=new Caso(op);c.params.remove(k);c.ejecutar(400);
                    c=new Caso(op);c.p(k," ");c.ejecutar(400);
                    c=new Caso(op);c.p(k,"");c.ejecutar(400);
                }
                if(k.startsWith("id")) {
                    for(String v:new String[]{"0","-1","abc","1.5","2147483648","1 OR 1=1"}) {
                        c=new Caso(op);c.p(k,v);c.ejecutar(400);exigir(c.j.conexiones==0);
                    }
                } else if(!k.equals("resultado")) {
                    int max=k.equals("resultadoTexto")||k.equals("nuevoResultadoTexto")?250:500;
                    c=new Caso(op);c.p(k,"x".repeat(max));
                    String col=Character.toUpperCase(k.charAt(0))+k.substring(1);
                    if(c.j.fila().containsKey(col)) c.j.fila().put(col,"x".repeat(max));
                    c.ejecutar(200);
                    c=new Caso(op);c.p(k,"x".repeat(max+1));c.ejecutar(400);
                }
            }
            c=new Caso(op);c.j.codigo=99999;c.ejecutar(500);
            c=new Caso(op);c.j.falloRuntime=true;c.ejecutar(500);
            c=new Caso(op);c.j.falloConexion=true;c.ejecutar(500);
            c=new Caso(op);c.j.falloPreparar=true;c.ejecutar(500);
            c=new Caso(op);c.j.falloPosterior=true;c.ejecutar(500);
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
                c=new Caso(op);c.j.fila().put(col.getKey(),new Object());c.ejecutar(500);
                if(col.getKey().startsWith("Id")) {
                    for(int id:new int[]{0,-1}) {
                        c=new Caso(op);c.j.fila().put(col.getKey(),id);c.ejecutar(500);
                    }
                }
            }
            c=new Caso(op);c.j.fila().put("Contrasena",PRIVADO);c.j.fila().put("Token",PRIVADO);c.ejecutar(200);
            c=new Caso(op);c.j.fila().put(op==REGISTRAR?"IdEvento":op==RESOLVER?"IdResultadoEvento":"IdResultado",999);c.ejecutar(500);
            c=new Caso(op);c.ip="2001:db8::1";c.ejecutar(200);
            c=new Caso(op);c.ip="x".repeat(46);c.ejecutar(400);
            c=new Caso(op);c.directo=true;c.h.pathInfo="/extra";c.ejecutar(404);
        }
        for(int codigo=61001;codigo<=61048;codigo++) {
            OperacionAdministracionResultados op=codigo<=61006?REGISTRAR:codigo<=61015?RESOLVER:codigo<=61024?OFICIALIZAR:codigo<=61037?CORREGIR:ANULAR;
            Caso c=new Caso(op);c.j.codigo=codigo;c.ejecutar(esperadoSql(codigo));
        }
        for(int codigo=59001;codigo<=59004;codigo++) {
            Caso c=new Caso(REGISTRAR);c.j.codigo=codigo;c.ejecutar(esperadoSql(codigo));
        }
        for(String estado:new String[]{"PENDIENTE","CORREGIDO"}) {
            Caso c=new Caso(REGISTRAR);c.j.fila().put("EstadoResultado",estado);c.ejecutar(200);
        }
        for(String estado:new String[]{"OFICIAL","ANULADO","OTRO"}) {
            Caso c=new Caso(REGISTRAR);c.j.fila().put("EstadoResultado",estado);c.ejecutar(500);
        }
        for(String resultado:new String[]{"GANADA","PERDIDA","ANULADA"," perdida "}) {
            Caso c=new Caso(RESOLVER);c.p("resultado",resultado);c.j.fila().put("Resultado",resultado.trim().toUpperCase(Locale.ROOT));c.ejecutar(200);
        }
        for(String resultado:new String[]{"PENDIENTE","GANADOR","OTRO","x".repeat(21)}) {
            Caso c=new Caso(RESOLVER);c.p("resultado",resultado);c.ejecutar(400);
        }
        Caso c=new Caso(RESOLVER);c.j.fila().put("IdSeleccion",999);c.ejecutar(500);
        c=new Caso(RESOLVER);c.j.fila().put("Resultado","PERDIDA");c.ejecutar(500);
        for(OperacionAdministracionResultados op:new OperacionAdministracionResultados[]{REGISTRAR,RESOLVER,OFICIALIZAR}) {
            c=new Caso(op);c.p("observacion"," ");
            c.ejecutar(200);
            c=new Caso(op);String observacion="Texto \"citado\"\n\tcon control \u0001 fin";
            c.p("observacion",observacion);
            if(op!=OFICIALIZAR) c.j.fila().put("Observacion",observacion);
            JsonNode json=c.ejecutar(200);
            if(op!=OFICIALIZAR) exigir(json.at("/resultado/observacion").asText().equals(observacion));
        }
        for(OperacionAdministracionResultados op:new OperacionAdministracionResultados[]{OFICIALIZAR,ANULAR}) {
            c=new Caso(op);c.j.fila().put("SinCambios",true);
            exigir(c.ejecutar(200).at("/resultado/sinCambios").asBoolean());
        }
        for(OperacionAdministracionResultados op:new OperacionAdministracionResultados[]{OFICIALIZAR,CORREGIR,ANULAR}) {
            c=new Caso(op);c.j.fila().put("EstadoResultado","OTRO");c.ejecutar(500);
            c=new Caso(op);c.j.fila().put("EstadoEvento","OTRO");c.ejecutar(500);
        }
        c=new Caso(CORREGIR);c.j.fila().put("RequiereNuevaResolucion",false);c.ejecutar(500);
        c=new Caso(REGISTRAR);c.p("resultadoTexto","  Texto normalizado  ");c.j.fila().put("ResultadoTexto","Texto normalizado");c.ejecutar(200);
        c=new Caso(CORREGIR);c.p("motivo","  Motivo normalizado  ");c.ejecutar(200);
        System.out.println("Administracion resultados: "+casos+" casos, 0 fallos.");
    }
}