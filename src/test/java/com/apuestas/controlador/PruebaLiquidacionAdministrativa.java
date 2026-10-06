package com.apuestas.controlador;

import com.apuestas.dao.LiquidacionAdministrativaDAO;
import com.apuestas.modelo.OperacionLiquidacionAdministrativa;
import com.apuestas.seguridad.ControlAccesoAdministrativo;
import com.apuestas.servicio.LiquidacionAdministrativaServicio;
import com.fasterxml.jackson.databind.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;
import static com.apuestas.modelo.OperacionLiquidacionAdministrativa.*;

/** HTTP/servicio/DAO reales con SP simulado. No conexiones, movimientos ni pagos reales. */
public class PruebaLiquidacionAdministrativa {
    private static int casos;
    private static final String PRIVADO="SECRETO_LIQUIDACION";
    private static final ObjectMapper JSON=new ObjectMapper().enable(DeserializationFeature.USE_BIG_DECIMAL_FOR_FLOATS);
    private static final String UUID="12345678-1234-1234-1234-123456789012";
    private static BigDecimal dinero(String v) { return new BigDecimal(v); }
    private static Timestamp fecha() { return Timestamp.valueOf("2026-01-02 03:04:05.1234567"); }
    private static Map<String,Object> fila(Object... pares) {
        Map<String,Object> r=new LinkedHashMap<>();
        for(int i=0;i<pares.length;i+=2) r.put((String)pares[i],pares[i+1]);return r;
    }
    private static Map<String,Object> listo() {
        return fila("IdBoleto",19,"CodigoBoleto","B-19","IdUsuario",8,"Correo","cliente@example.test",
                "TipoBoleto","COMPUESTO","MontoApostado",dinero("100.00"),"CuotaTotal",dinero("1.2345"),
                "GananciaPotencial",dinero("123.45"),"FechaCreacion",fecha(),"CantidadSelecciones",2,
                "SeleccionesGanadas",1,"SeleccionesPerdidas",0,"SeleccionesAnuladas",1,"ResultadoPropuesto","GANADOR");
    }
    private static Map<String,Object> nueva() {
        return fila("IdLiquidacion",5000000000L,"IdBoleto",19,"CodigoBoleto","B-19","ResultadoBoleto","GANADOR",
                "EstadoBoleto","LIQUIDADO","MontoApostado",dinero("100.00"),"ComisionServicio",dinero("5.00"),
                "TotalCargo",dinero("105.00"),"MontoLiquidado",dinero("123.45"),"GananciaNeta",dinero("23.45"),
                "ComisionDevuelta",dinero("0.00"),"IdTransaccionUsuario",6000000000L,"ReferenciaUsuario",UUID,
                "IdTransaccionDevolucionComisionUsuario",null,"ReferenciaDevolucionComisionUsuario",null,
                "IdTransaccionCasa",7000000000L,"ReferenciaCasa",UUID,"UsuarioDisponibleAnterior",dinero("10.00"),
                "UsuarioDisponiblePosterior",dinero("133.45"),"UsuarioComprometidoAnterior",dinero("100.00"),
                "UsuarioComprometidoPosterior",dinero("0.00"),"CasaDisponibleAnterior",dinero("1000.00"),
                "CasaDisponiblePosterior",dinero("976.55"),"SolicitudIdempotente",false);
    }
    private static Map<String,Object> repetida() {
        return fila("IdLiquidacion",5000000000L,"IdBoleto",19,"CodigoBoleto","B-19","Resultado","GANADOR",
                "EstadoBoleto","LIQUIDADO","MontoApostado",dinero("100.00"),"ComisionServicio",dinero("5.00"),
                "TotalCargo",dinero("105.00"),"MontoLiquidado",dinero("123.45"),"IdTransaccion",6000000000L,
                "FechaFinalizacion",fecha(),"SolicitudIdempotente",true);
    }
    private static Map<String,Object> consulta() {
        return fila("IdLiquidacion",5000000000L,"IdBoleto",19,"CodigoBoleto","B-19","IdUsuario",8,
                "Correo","cliente@example.test","ResultadoBoleto","GANADOR","EstadoBoleto","LIQUIDADO",
                "MontoApostado",dinero("100.00"),"ComisionServicio",dinero("5.00"),"TotalCargo",dinero("105.00"),
                "CuotaTotal",dinero("1.2345"),"GananciaPotencial",dinero("123.45"),"MontoLiquidado",dinero("123.45"),
                "EstadoLiquidacion","COMPLETADA","IdTransaccionUsuario",6000000000L,"IdTransaccionCasa",null,
                "FechaCreacion",fecha(),"FechaInicioProceso",fecha(),"FechaFinalizacion",fecha(),
                "IdUsuarioProceso",7,"UsuarioProceso","admin@example.test","Observacion",null);
    }
    private static Map<String,Object> respuesta(int variante) {
        return variante==0?listo():variante==1?nueva():variante==2?repetida():consulta();
    }
    private static boolean nullable(int variante,String columna) {
        if(variante==1) return Arrays.asList("IdTransaccionDevolucionComisionUsuario","ReferenciaDevolucionComisionUsuario","IdTransaccionCasa","ReferenciaCasa").contains(columna);
        if(variante==2) return Arrays.asList("IdTransaccion","FechaFinalizacion").contains(columna);
        return variante==3&&Arrays.asList("IdTransaccionUsuario","IdTransaccionCasa","FechaInicioProceso","FechaFinalizacion","IdUsuarioProceso","UsuarioProceso","Observacion").contains(columna);
    }
    /** Estado del procedimiento simulado, no una implementacion financiera Java de produccion. */
    static class EstadoSP {
        int invocaciones,efectos;
        boolean completada;
        Map<String,Object> ejecutar() {
            invocaciones++;
            if(completada) return repetida();
            completada=true;efectos++;return nueva();
        }
    }
    static class Jdbc {
        final OperacionLiquidacionAdministrativa op;
        final List<List<Map<String,Object>>> resultados=new ArrayList<>();
        final Map<Integer,Object> params=new HashMap<>();
        int conexiones,llamadas,ejecuciones,indice,abiertos,cerrados,codigo;
        boolean conexionCerrada,statementCerrado,conteo,rsNull,falloConexion,falloPreparar,falloRuntime,falloPosterior;
        EstadoSP estado;
        Jdbc(int variante) {
            op=variante==0?LISTAR:variante==3?CONSULTAR:LIQUIDAR;
            resultados.add(new ArrayList<>(Arrays.asList(respuesta(variante))));
        }
        Map<String,Object> fila() { return resultados.get(0).get(0); }
        Connection conexion() throws SQLException {
            conexiones++;
            if(falloConexion) throw new SQLException(PRIVADO);
            return proxy(Connection.class,(p,m,a)->{
                if(m.getName().equals("close")) { conexionCerrada=true;return null; }
                if(m.getName().equals("prepareCall")) {
                    llamadas++;
                    if(falloPreparar) throw new SQLException(PRIVADO);
                    String sql=op==LISTAR?"{call dbo.sp_ObtenerBoletosListosLiquidar(?, ?)}":
                            op==LIQUIDAR?"{call dbo.sp_LiquidarBoleto(?, ?, ?)}":"{call dbo.sp_ObtenerLiquidacionBoleto(?, ?)}";
                    exigir(a[0].equals(sql));return sentencia();
                }
                // Falla ante UPDATE/INSERT, otro SP, commit, rollback o transaccion financiera Java.
                throw new AssertionError("Operacion JDBC prohibida: "+m.getName());
            });
        }
        CallableStatement sentencia() {
            return proxy(CallableStatement.class,(p,m,a)->{
                switch(m.getName()) {
                    case "setInt":case "setString":params.put((Integer)a[0],a[1]);return null;
                    case "setNull":exigir((Integer)a[1]==Types.VARCHAR);params.put((Integer)a[0],null);return null;
                    case "execute":
                        ejecuciones++;
                        if(codigo!=0) throw new SQLException(PRIVADO,"TEST",codigo);
                        if(falloRuntime) throw new IllegalStateException(PRIVADO);
                        if(estado!=null) { exigir(op==LIQUIDAR);resultados.set(0,new ArrayList<>(Arrays.asList(estado.ejecutar()))); }
                        indice=conteo?-1:0;return indice>=0&&!resultados.isEmpty();
                    case "getMoreResults":
                        if(falloPosterior) throw new SQLException(PRIVADO);
                        return ++indice<resultados.size();
                    case "getUpdateCount":return indice==-1?3:-1;
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
                        Map<String,Object> fila=filas.get(pos[0]);
                        if(!fila.containsKey(a[0])) throw new SQLException(PRIVADO);
                        return fila.get(a[0]);
                    default:throw new AssertionError(m.getName());
                }
            });
        }
    }
    static class Caso {
        final Http h=new Http();
        final Jdbc j;
        final Map<String,String[]> params=new LinkedHashMap<>();
        final HttpServletRequest req;
        boolean directo;
        String ip="127.0.0.1";
        Caso(int variante) {
            j=new Jdbc(variante);h.ruta=j.op.ruta;h.method=j.op.metodo;
            h.previa=new Sesion();h.previa.datos.put("adminIdUsuario",7);h.previa.datos.put("adminIdRol",3);
            h.previa.datos.put("adminCorreo","admin@example.test");h.previa.datos.put("adminRol","ADMINISTRADOR");
            h.previa.datos.put("adminEstadoUsuario","ACTIVO");
            if(j.op!=LISTAR) p("idBoleto","19");
            req=proxy(HttpServletRequest.class,(p,m,a)->{
                if(m.getName().equals("getParameterMap")) { exigir("UTF-8".equals(h.encoding));return params; }
                if(m.getName().equals("getRemoteAddr")) { exigir(j.op==LIQUIDAR);return ip; }
                try { return m.invoke(h.req,a); } catch(InvocationTargetException e) { throw e.getCause(); }
            });
        }
        void p(String k,String... valores) { params.put(k,valores); }
        JsonNode ejecutar(int esperado) throws Exception {
            LiquidacionAdministrativaServlet s=new LiquidacionAdministrativaServlet();
            Field f=LiquidacionAdministrativaServlet.class.getDeclaredField("servicio");f.setAccessible(true);
            f.set(s,new LiquidacionAdministrativaServicio(new LiquidacionAdministrativaDAO() {
                @Override protected Connection obtenerConexion() throws SQLException { return j.conexion(); }
            }));
            if(directo) s.service(req,h.res);
            else new ControlAccesoAdministrativo().doFilter(req,h.res,(r,res)->s.service((HttpServletRequest)r,(HttpServletResponse)res));
            if(h.status!=esperado) throw new AssertionError(j.op+" HTTP esperado "+esperado+", recibido "+h.status);
            if(!"application/json;charset=UTF-8".equals(h.tipo)) throw new AssertionError(j.op+" Content-Type no JSON");
            exigir("no-store".equals(h.headers.get("Cache-Control"))&&h.creaciones==0);
            String body=h.body.toString();
            exigir(!body.contains(PRIVADO)&&!body.contains("dbo.")&&!body.contains("SQLException")&&!body.contains("SECRETO_INTERNO"));
            JsonNode json=JSON.readTree(body);
            exigir(json.path("ok").asBoolean()==(esperado==200));
            if(esperado!=200) exigir(json.size()==2&&json.has("mensaje"));
            else exigir(json.size()==(j.op==LISTAR?3:2)&&json.has(j.op==LISTAR?"boletos":"resultado"));
            if(j.conexiones>0) {
                exigir(j.conexiones==1&&j.abiertos==j.cerrados);
                if(!j.falloConexion) {
                    exigir(j.conexionCerrada&&j.llamadas==1);
                    if(!j.falloPreparar) {
                        exigir(j.statementCerrado&&j.ejecuciones==1);
                        exigir(j.params.size()==(j.op==LIQUIDAR?3:2)&&j.params.get(1).equals(7));
                        int n=j.op==LISTAR?(params.containsKey("cantidad")?Integer.parseInt(params.get("cantidad")[0].trim()):100):19;
                        exigir(j.params.get(2).equals(n));
                        if(j.op==LIQUIDAR) exigir(Objects.equals(j.params.get(3),ip));
                    }
                }
            }
            casos++;return json;
        }
    }
    private static int esperadoSql(int c) {
        if(Arrays.asList(62001,62005,62006,62032,62033).contains(c)) return 400;
        if(Arrays.asList(62002,62003,62004,62035,62036).contains(c)) return 403;
        if(Arrays.asList(62017,62034,62037).contains(c)) return 404;
        if(Arrays.asList(62018,62019,62020,62021,62022,62023,62024,62030,62031,62039).contains(c)) return 409;
        return 500;
    }
    public static void main(String[] args) throws Exception {
        if(args.length>0) {
            Caso c=new Caso(0);c.h.previa=null;c.ejecutar(401);
            System.out.println("Filtro liquidacion JSON: OK");return;
        }
        Set<String> rutas=new HashSet<>(Arrays.asList(LiquidacionAdministrativaServlet.class.getAnnotation(WebServlet.class).value()));
        exigir(rutas.size()==3);
        for(int variante=0;variante<4;variante++) {
            Caso c=new Caso(variante);exigir(rutas.contains(c.j.op.ruta));
            JsonNode json=c.ejecutar(200);
            JsonNode r=variante==0?json.at("/boletos/0"):json.get("resultado");
            exigir(r.size()==respuesta(variante).size());
            for(Map.Entry<String,Object> col:respuesta(variante).entrySet()) {
                String propiedad=Character.toLowerCase(col.getKey().charAt(0))+col.getKey().substring(1);
                exigir(r.has(propiedad));
                if(col.getValue() instanceof BigDecimal) exigir(r.get(propiedad).decimalValue().compareTo((BigDecimal)col.getValue())==0);
                if(col.getValue() instanceof Long) exigir(r.get(propiedad).longValue()==(Long)col.getValue());
            }
            c=new Caso(variante);c.j.conteo=true;c.ejecutar(200);
            for(String rol:new String[]{"ADMINISTRADOR","CAJERO","AUDITOR","OPERADOR_EVENTOS","USUARIO","CASA"}) {
                c=new Caso(variante);c.h.previa.datos.put("adminRol",rol);
                boolean permitido=rol.equals("ADMINISTRADOR")||rol.equals("CAJERO")||(variante==3&&rol.equals("AUDITOR"));
                c.ejecutar(permitido?200:403);if(!permitido) exigir(c.j.conexiones==0);
            }
            c=new Caso(variante);c.h.previa=null;c.ejecutar(401);
            c=new Caso(variante);c.h.previa.expirada=true;c.ejecutar(401);
            c=new Caso(variante);c.h.previa.falloLectura=true;c.ejecutar(500);
            c=new Caso(variante);c.directo=true;c.h.previa=null;c.ejecutar(401);
            c=new Caso(variante);c.directo=true;c.h.previa.expirada=true;c.ejecutar(401);
            c=new Caso(variante);c.h.previa.datos.put("idUsuario",7);c.h.previa.datos.put("rol","USUARIO");c.ejecutar(403);
            for(String k:new String[]{"adminIdUsuario","adminIdRol","adminCorreo","adminRol","adminEstadoUsuario"}) {
                c=new Caso(variante);c.h.previa.datos.remove(k);c.ejecutar(403);
            }
            for(Object id:new Object[]{0,-1,"7",7L}) {
                c=new Caso(variante);c.h.previa.datos.put("adminIdUsuario",id);c.ejecutar(403);
            }
            c=new Caso(variante);c.h.previa.datos.put("adminEstadoUsuario","SUSPENDIDO");c.ejecutar(403);
            for(String metodo:new String[]{"GET","POST","HEAD","PUT","PATCH","DELETE","OPTIONS"}) {
                c=new Caso(variante);if(metodo.equals(c.j.op.metodo)) continue;
                c.h.method=metodo;c.ejecutar(405);exigir(c.j.op.metodo.equals(c.h.headers.get("Allow"))&&c.j.conexiones==0);
            }
            for(String intruso:new String[]{"idUsuarioProceso","idUsuarioSolicitante","idAdministrador","usuarioProceso","correoAdministrador","rolAdministrador","IpOrigen","ipOrigen","montoLiquidado","saldo","premio","otro"}) {
                c=new Caso(variante);c.p(intruso,"99");c.ejecutar(400);exigir(c.j.conexiones==0);
            }
            for(String valor:new String[]{""," ","0","-1","abc","1.5","2147483648","1 OR 1=1"}) {
                c=new Caso(variante);c.p(c.j.op.parametro,valor);c.ejecutar(400);
            }
            c=new Caso(variante);c.p(c.j.op.parametro,"19","20");c.ejecutar(400);
            c=new Caso(variante);c.p(c.j.op.parametro,new String[0]);c.ejecutar(400);
            c=new Caso(variante);c.p(c.j.op.parametro,(String[])null);c.ejecutar(400);
            c=new Caso(variante);c.p(c.j.op.parametro,(String)null);c.ejecutar(400);
            if(variante>0) { c=new Caso(variante);c.params.clear();c.ejecutar(400); }
            c=new Caso(variante);c.j.codigo=99999;c.ejecutar(500);
            c=new Caso(variante);c.j.falloRuntime=true;c.ejecutar(500);
            c=new Caso(variante);c.j.falloConexion=true;c.ejecutar(500);
            c=new Caso(variante);c.j.falloPreparar=true;c.ejecutar(500);
            c=new Caso(variante);c.j.falloPosterior=true;c.ejecutar(500);
            c=new Caso(variante);c.j.resultados.clear();c.ejecutar(500);
            c=new Caso(variante);c.j.resultados.get(0).clear();c.ejecutar(variante==0?200:500);
            c=new Caso(variante);c.j.resultados.get(0).add(respuesta(variante));c.ejecutar(500);
            c=new Caso(variante);c.j.resultados.add(new ArrayList<>());c.ejecutar(500);
            c=new Caso(variante);c.j.rsNull=true;c.ejecutar(500);
            for(Map.Entry<String,Object> col:respuesta(variante).entrySet()) {
                c=new Caso(variante);c.j.fila().remove(col.getKey());c.ejecutar(500);
                c=new Caso(variante);c.j.fila().put(col.getKey(),new Object());c.ejecutar(500);
                c=new Caso(variante);c.j.fila().put(col.getKey(),null);c.ejecutar(nullable(variante,col.getKey())?200:500);
                if(col.getKey().startsWith("Id")) {
                    c=new Caso(variante);
                    Object cero=col.getValue() instanceof Long||col.getKey().startsWith("IdTransaccion")?Long.valueOf(0):Integer.valueOf(0);
                    c.j.fila().put(col.getKey(),cero);c.ejecutar(500);
                }
                if(col.getValue() instanceof BigDecimal) {
                    c=new Caso(variante);c.j.fila().put(col.getKey(),dinero("-0.01"));c.ejecutar(500);
                    c=new Caso(variante);c.j.fila().put(col.getKey(),dinero("0.00001"));c.ejecutar(500);
                    c=new Caso(variante);c.j.fila().put(col.getKey(),dinero("99999999999999.00"));c.ejecutar(500);
                }
            }
            c=new Caso(variante);c.j.fila().put("Contrasena",PRIVADO);c.j.fila().put("Token",PRIVADO);c.ejecutar(200);
            if(variante>0) { c=new Caso(variante);c.j.fila().put("IdBoleto",999);c.ejecutar(500); }
        }
        for(int codigo=62001;codigo<=62039;codigo++) {
            Caso c=new Caso(codigo>=62032&&codigo<=62037?3:codigo==62005?0:1);
            c.j.codigo=codigo;c.ejecutar(esperadoSql(codigo));
        }
        Caso c=new Caso(0);Map<String,Object> segundo=listo();segundo.put("IdBoleto",20);
        c.j.resultados.get(0).add(segundo);exigir(c.ejecutar(200).get("cantidad").asInt()==2);
        c=new Caso(0);c.p("cantidad","1");c.j.resultados.get(0).add(segundo);c.ejecutar(500);
        for(String cantidad:new String[]{"1","500"}) { c=new Caso(0);c.p("cantidad",cantidad);c.ejecutar(200); }
        c=new Caso(0);c.p("cantidad","501");c.ejecutar(400);
        for(String resultado:new String[]{"GANADOR","PERDEDOR","ANULADO"}) {
            c=new Caso(1);c.j.fila().put("ResultadoBoleto",resultado);
            c.j.fila().put("EstadoBoleto",resultado.equals("ANULADO")?"ANULADO":"LIQUIDADO");c.ejecutar(200);
        }
        c=new Caso(1);c.j.fila().put("IdTransaccionDevolucionComisionUsuario",8000000000L);
        c.j.fila().put("ReferenciaDevolucionComisionUsuario",UUID);c.ejecutar(200);
        c=new Caso(3);c.j.fila().put("EstadoLiquidacion","EN_PROCESO");
        c.j.fila().put("FechaFinalizacion",null);c.j.fila().put("IdTransaccionUsuario",null);c.ejecutar(200);
        c=new Caso(3);String obs="Observacion \"citada\"\n\u0001 fin";c.j.fila().put("Observacion",obs);
        exigir(c.ejecutar(200).at("/resultado/observacion").asText().equals(obs));
        c=new Caso(1);c.j.fila().put("SolicitudIdempotente",true);c.ejecutar(500);
        c=new Caso(2);c.j.fila().put("SolicitudIdempotente",false);c.ejecutar(500);
        c=new Caso(1);c.ip="2001:db8::1";c.ejecutar(200);
        c=new Caso(1);c.ip="x".repeat(46);c.ejecutar(400);
        // No recalcular importes recibidos: el doble devuelve un importe distinto al fixture base.
        c=new Caso(1);c.j.fila().put("MontoLiquidado",dinero("321.09"));
        exigir(c.ejecutar(200).at("/resultado/montoLiquidado").decimalValue().equals(dinero("321.09")));
        EstadoSP estado=new EstadoSP();
        Caso primera=new Caso(1);primera.j.estado=estado;JsonNode a=primera.ejecutar(200).get("resultado");
        Caso segunda=new Caso(2);segunda.j.estado=estado;JsonNode b=segunda.ejecutar(200).get("resultado");
        exigir(!a.get("solicitudIdempotente").asBoolean()&&b.get("solicitudIdempotente").asBoolean());
        exigir(a.get("idLiquidacion").equals(b.get("idLiquidacion")));
        exigir(a.get("idTransaccionUsuario").equals(b.get("idTransaccion")));
        exigir(a.get("montoLiquidado").equals(b.get("montoLiquidado")));
        exigir(estado.invocaciones==2&&estado.efectos==1);
        exigir(!b.has("gananciaNeta")&&!b.has("usuarioDisponiblePosterior"));
        System.out.println("Liquidacion administrativa: "+casos+" casos, 0 fallos.");
    }
}