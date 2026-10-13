package com.apuestas.controlador;

import com.apuestas.dao.ApuestaDAO;
import com.apuestas.modelo.*;
import com.apuestas.servicio.ApuestaServicio;
import com.fasterxml.jackson.databind.*;
import java.io.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import javax.servlet.http.*;

/** Dobles JDBC cerrados: solo llamadas a los dos SP; ninguna conexion real. */
public class PruebaModalidadesApuesta {
    static final UUID REF=UUID.fromString("c8ec53e7-1fa9-4b51-b97d-55792fcdd75a");
    static final BigDecimal MONTO=new BigDecimal("100.25");
    static int pass,fail;
    interface Accion {void run()throws Exception;}
    static void caso(String nombre,Accion a) {
        try {a.run();pass++;} catch(Exception | AssertionError e){fail++;System.out.println("FAIL "+nombre+" "+e.getClass().getSimpleName());}
    }
    static void exigir(boolean v){if(!v)throw new AssertionError();}
    @SuppressWarnings("unchecked") static <T>T proxy(Class<T> c,InvocationHandler h){return (T)Proxy.newProxyInstance(c.getClassLoader(),new Class<?>[]{c},h);}
    static Map<String,Object> fila(Object... a){Map<String,Object> r=new LinkedHashMap<>();for(int i=0;i<a.length;i+=2)r.put((String)a[i],a[i+1]);return r;}
    static BigDecimal decimal(String s){return new BigDecimal(s);}
    static class Tabla {
        List<Map<String,Object>> filas=new ArrayList<>();List<String> columnas;
        @SafeVarargs Tabla(Map<String,Object>... rows){filas.addAll(Arrays.asList(rows));columnas=new ArrayList<>(rows[0].keySet());}
    }
    static class Jdbc extends ApuestaDAO {
        List<Tabla> tablas=new ArrayList<>();Map<Integer,Object> parametros=new HashMap<>();Map<Integer,Integer> tiposNull=new HashMap<>();
        int indice,llamadas,abiertos,cerrados;boolean conexionCerrada,statementCerrado;String sql;int error;
        @Override protected Connection obtenerConexion(){
            llamadas++;
            return proxy(Connection.class,(p,m,a)->{
                if(m.getName().equals("close")){conexionCerrada=true;return null;}
                if(!m.getName().equals("prepareCall"))throw new AssertionError("Operacion JDBC no autorizada");
                sql=(String)a[0];
                exigir(sql.equals("{call dbo.sp_CotizarApuesta(?, ?, ?, ?)}") || sql.equals("{call dbo.sp_RealizarApuesta(?, ?, ?, ?, ?, ?, ?)}"));
                return proxy(CallableStatement.class,(q,n,b)->{
                    switch(n.getName()) {
                        case "setInt":case "setString":case "setBigDecimal":parametros.put((Integer)b[0],b[1]);return null;
                        case "setNull":parametros.put((Integer)b[0],null);tiposNull.put((Integer)b[0],(Integer)b[1]);return null;
                        case "execute":if(error!=0)throw new SQLException("SECRETO_INTERNO_SQL","X",error);indice=0;return !tablas.isEmpty();
                        case "getMoreResults":return ++indice<tablas.size();
                        case "getUpdateCount":return -1;
                        case "getResultSet":return rs(tablas.get(indice));
                        case "close":statementCerrado=true;return null;
                        default:throw new AssertionError("No transacciones ni escrituras JDBC adicionales");
                    }
                });
            });
        }
        ResultSet rs(Tabla t){
            abiertos++;int[] pos={-1};
            return proxy(ResultSet.class,(p,m,a)->{
                switch(m.getName()) {
                    case "next":return ++pos[0]<t.filas.size();
                    case "getMetaData":return proxy(ResultSetMetaData.class,(q,n,b)->{
                        if(n.getName().equals("getColumnCount"))return t.columnas.size();
                        if(n.getName().equals("getColumnLabel"))return t.columnas.get((Integer)b[0]-1);
                        throw new AssertionError();
                    });
                    case "getString":case "getObject":if(!t.columnas.contains(a[0]))throw new SQLException("Columna ausente");return t.filas.get(pos[0]).get(a[0]);
                    case "close":cerrados++;return null;
                    default:throw new AssertionError("Conversion JDBC inesperada: "+m.getName());
                }
            });
        }
        void cerrado(){exigir(llamadas==1 && conexionCerrada && statementCerrado && abiertos==cerrados);}
    }
    static Jdbc cotizacion(String tipo,boolean compuesto){
        Jdbc j=new Jdbc();boolean marcador=tipo.equals("MARCADOR_FINAL");
        j.tablas.add(new Tabla(fila("TipoBoleto",compuesto?"COMPUESTO":"SIMPLE","CantidadSelecciones",compuesto?2:1,
            "MontoApostado",MONTO,"ComisionServicioPorcentaje",decimal("5.0000"),"ComisionServicio",decimal("5.01"),
            "TotalCargo",decimal("105.26"),"CuotaTotal",decimal("5.0000"),"GananciaPotencial",decimal("501.25"))));
        Tabla t=new Tabla(detalle(11,1));if(compuesto)t.filas.add(detalle(12,2));j.tablas.add(t);
        j.tablas.add(new Tabla(fila("TipoMercado",tipo,"PronosticoA",marcador?0:null,"PronosticoB",marcador?2:null,
            "CuotaResultado",marcador?decimal("2.0000"):null,"PremioResultadoPotencial",marcador?decimal("200.50"):null,
            "PremioExactoOMaximo",decimal("501.25"))));return j;
    }
    static Map<String,Object> detalle(int id,int orden){return fila("Orden",orden,"IdEvento",100+id,"NombreEvento","Evento",
        "IdMercado",200+id,"NombreMercado","Mercado","IdSeleccion",id,"NombreSeleccion","Seleccion",
        "IdCuota",300+id,"Cuota",decimal("5.0000"));}
    static Jdbc realizacion(boolean compuesto,boolean repetida){
        Jdbc j=new Jdbc();Map<String,Object> r=fila("IdBoleto",25,"CodigoBoleto","BOL-25","TipoBoleto",compuesto?"COMPUESTO":"SIMPLE",
            "MontoApostado",MONTO,"ComisionServicio",decimal("5.01"),"TotalCargo",decimal("105.26"),
            "CuotaTotal",decimal("5.0000"),"GananciaPotencial",decimal("501.25"),"ReferenciaOperacion",REF.toString(),"SolicitudIdempotente",repetida);
        if(!repetida)r.putAll(fila("CantidadSelecciones",compuesto?2:1,"ComisionServicioPorcentaje",decimal("5.0000")));
        j.tablas.add(new Tabla(r));return j;
    }
    static CotizacionApuesta leer(Jdbc j,boolean compuesto,Integer a,Integer b)throws Exception {
        try{return new ApuestaServicio(j).cotizarApuesta(compuesto?Arrays.asList(11,12):Arrays.asList(11),MONTO,a,b);}finally{j.cerrado();}
    }
    static void rechazar(Jdbc j)throws Exception {
        boolean fallo=false;try{leer(j,false,null,null);}catch(SQLException e){fallo=true;}exigir(fallo);
    }
    static class Http {
        Map<String,String[]> parametros=new HashMap<>();StringWriter cuerpo=new StringWriter();String tipo,metodo="POST",rawBody;
        boolean sesion=true,expirada;String rol="USUARIO";int estado=200;
        Http(){parametros.put("idSeleccion",new String[]{"11"});parametros.put("monto",new String[]{"100.25"});parametros.put("referenciaOperacion",new String[]{REF.toString()});}
        HttpSession s=proxy(HttpSession.class,(p,m,a)->{
            exigir(m.getName().equals("getAttribute"));if(expirada)throw new IllegalStateException();
            return a[0].equals("idUsuario")?7:rol;
        });
        HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)->{
            switch(m.getName()){
                case "setCharacterEncoding":return null;
                case "getMethod":return metodo;
                case "getContentType":return rawBody==null?"application/x-www-form-urlencoded":"application/json";
                case "getReader":return new BufferedReader(new StringReader(rawBody==null?"":rawBody));
                case "getSession":exigir(Boolean.FALSE.equals(a[0]));return sesion?s:null;
                case "getRemoteAddr":return "127.0.0.8";
                case "getParameter":String[] v=parametros.get(a[0]);return v==null?null:v[0];
                case "getParameterValues":return parametros.get(a[0]);
                default:throw new AssertionError(m.getName());
            }
        });
        HttpServletResponse res=proxy(HttpServletResponse.class,(p,m,a)->{
            switch(m.getName()){
                case "setContentType":tipo=(String)a[0];return null;
                case "setStatus":estado=(Integer)a[0];return null;
                case "setHeader":return null;
                case "getWriter":return new PrintWriter(cuerpo);
                default:throw new AssertionError(m.getName());
            }
        });
    }
    static JsonNode http(Jdbc j,boolean cotizar,Http h,int esperado)throws Exception {
        Object servlet=cotizar?new CotizarApuestaServlet():new RealizarApuestaServlet();
        Field f=servlet.getClass().getDeclaredField("apuestaServicio");f.setAccessible(true);f.set(servlet,new ApuestaServicio(j));
        // service needs container context for default POST dispatch; doPost directly tests the handler.
        if(cotizar)((CotizarApuestaServlet)servlet).doPost(h.req,h.res);else((RealizarApuestaServlet)servlet).doPost(h.req,h.res);
        exigir(h.estado==esperado && "application/json;charset=UTF-8".equals(h.tipo));
        exigir(!h.cuerpo.toString().contains("SECRETO_INTERNO_SQL"));
        JsonNode n=new ObjectMapper().enable(DeserializationFeature.USE_BIG_DECIMAL_FOR_FLOATS).readTree(h.cuerpo.toString());
        exigir(n.path("ok").asBoolean()==(esperado==200 || esperado==201));return n;
    }
    public static void main(String[] args)throws Exception {
        pass=0;fail=0;
        for(boolean compuesto:new boolean[]{false,true})caso("convencional cotizacion "+compuesto,()->{
            Jdbc j=cotizacion("CONVENCIONAL",compuesto);CotizacionApuesta r=leer(j,compuesto,null,null);
            exigir(r.getDetalles().size()==(compuesto?2:1) && r.getCuotaResultado()==null && r.getPronosticoA()==null);
            exigir(j.tiposNull.get(3)==Types.INTEGER && j.tiposNull.get(4)==Types.INTEGER);
        });
        caso("marcador cotizacion 0 conserva valor",()->{Jdbc j=cotizacion("MARCADOR_FINAL",false);CotizacionApuesta r=leer(j,false,0,2);exigir(r.getPronosticoA()==0 && j.parametros.get(4).equals(2) && r.getPremioResultadoPotencial().equals(decimal("200.50")));});
        caso("primera anotacion cotizacion",()->exigir(leer(cotizacion("PRIMERA_ANOTACION",false),false,null,null).getTipoMercado().equals("PRIMERA_ANOTACION")));
        for(int n=0;n<3;n++){final int i=n;caso("RS ausente "+i,()->{Jdbc j=cotizacion("CONVENCIONAL",false);j.tablas.remove(i);rechazar(j);});}
        caso("RS adicional",()->{Jdbc j=cotizacion("CONVENCIONAL",false);j.tablas.add(j.tablas.get(2));rechazar(j);});
        caso("tipo incorrecto",()->{Jdbc j=cotizacion("CONVENCIONAL",false);j.tablas.get(0).filas.get(0).put("CantidadSelecciones",decimal("1.5"));rechazar(j);});
        caso("RS3 vacio",()->{Jdbc j=cotizacion("CONVENCIONAL",false);j.tablas.get(2).filas.clear();rechazar(j);});
        caso("columna ausente RS3",()->{Jdbc j=cotizacion("CONVENCIONAL",false);j.tablas.get(2).columnas.remove("PronosticoA");rechazar(j);});
        caso("RS3 duplicado",()->{Jdbc j=cotizacion("CONVENCIONAL",false);j.tablas.get(2).filas.add(j.tablas.get(2).filas.get(0));rechazar(j);});
        caso("cuota resultado indebida",()->{Jdbc j=cotizacion("CONVENCIONAL",false);j.tablas.get(2).filas.get(0).put("CuotaResultado",BigDecimal.TEN);rechazar(j);});
        caso("seleccion ajena",()->{Jdbc j=cotizacion("CONVENCIONAL",false);j.tablas.get(1).filas.get(0).put("IdSeleccion",999);rechazar(j);});
        caso("modalidad desconocida respuesta",()->rechazar(cotizacion("OTRA",false)));
        caso("premio maximo inconsistente",()->{Jdbc j=cotizacion("CONVENCIONAL",false);j.tablas.get(2).filas.get(0).put("PremioExactoOMaximo",BigDecimal.ONE);rechazar(j);});
        for(String modalidad:Arrays.asList("CONVENCIONAL","MARCADOR_FINAL","PRIMERA_ANOTACION"))caso("realizar "+modalidad,()->{
            Jdbc j=realizacion(false,false);Integer a=modalidad.equals("MARCADOR_FINAL")?0:null,b=a==null?null:2;
            ResultadoApuesta r=new ApuestaServicio(j).realizarApuesta(7,Arrays.asList(11),MONTO,REF,"127.0.0.8",a,b);
            exigir(r.getCuotaTotal().equals(decimal("5.0000")) && j.parametros.get(1).equals(7)
                && Objects.equals(j.parametros.get(6),a) && Objects.equals(j.parametros.get(7),b));j.cerrado();
        });
        caso("realizar compuesto",()->{Jdbc j=realizacion(true,false);exigir(new ApuestaServicio(j).realizarApuesta(7,Arrays.asList(11,12),MONTO,REF,null).getTipoBoleto().equals("COMPUESTO"));j.cerrado();});
        caso("idempotencia marcador misma referencia",()->{Jdbc j=realizacion(false,true);ResultadoApuesta r=new ApuestaServicio(j).realizarApuesta(7,Arrays.asList(11),MONTO,REF,null,0,2);exigir(r.isSolicitudIdempotente() && r.getComisionServicioPorcentaje()==null && j.parametros.get(4).equals(REF.toString()));j.cerrado();});
        for(boolean cotizar:new boolean[]{true,false}) {
            for(int[] codigo:new int[][]{{76101,400},{76102,400},{99999,500}})caso("error modalidad "+cotizar+" "+codigo[0],()->{Jdbc j=realizacion(false,false);j.error=codigo[0];http(j,cotizar,new Http(),codigo[1]);j.cerrado();});
            caso("body vacio "+cotizar,()->{Jdbc j=realizacion(false,false);Http h=new Http();h.parametros.clear();http(j,cotizar,h,400);exigir(j.llamadas==0);});
            caso("JSON crudo invalido no es formulario "+cotizar,()->{Jdbc j=realizacion(false,false);Http h=new Http();h.parametros.clear();h.rawBody="{json roto";http(j,cotizar,h,400);exigir(j.llamadas==0);});
            caso("selecciones JSON invalido "+cotizar,()->{Jdbc j=realizacion(false,false);Http h=new Http();h.parametros.put("idSeleccion",new String[]{"[11,"});http(j,cotizar,h,400);exigir(j.llamadas==0);});
            for(String monto:Arrays.asList("0","-1","abc","1.001","10000000000"))caso("monto "+cotizar+" "+monto,()->{Jdbc j=realizacion(false,false);Http h=new Http();h.parametros.put("monto",new String[]{monto});http(j,cotizar,h,400);exigir(j.llamadas==0);});
        }
        for(int[] codigo:new int[][]{{76104,409},{76105,500},{76106,409},{76900,503},{60040,409},{60056,409},{60046,409}})
            caso("realizar error oficial "+codigo[0],()->{Jdbc j=realizacion(false,false);j.error=codigo[0];http(j,false,new Http(),codigo[1]);j.cerrado();});
        for(int[] codigo:new int[][]{{60012,409},{60054,409},{76103,500},{60010,500},{60013,400}})
            caso("cotizar error oficial "+codigo[0],()->{Jdbc j=cotizacion("CONVENCIONAL",false);j.error=codigo[0];http(j,true,new Http(),codigo[1]);j.cerrado();});
        caso("sin sesion",()->{Jdbc j=realizacion(false,false);Http h=new Http();h.sesion=false;http(j,false,h,401);exigir(j.llamadas==0);});
        caso("sesion expirada",()->{Jdbc j=realizacion(false,false);Http h=new Http();h.expirada=true;http(j,false,h,401);exigir(j.llamadas==0);});
        caso("rol CASA rechazado",()->{Jdbc j=realizacion(false,false);Http h=new Http();h.rol="CASA";http(j,false,h,403);exigir(j.llamadas==0);});
        caso("identidad IP y cuotas oficiales",()->{Jdbc j=realizacion(false,false);Http h=new Http();h.parametros.put("idUsuario",new String[]{"999"});h.parametros.put("ipOrigen",new String[]{"8.8.8.8"});h.parametros.put("cuota",new String[]{"999"});JsonNode n=http(j,false,h,201);exigir(j.parametros.get(1).equals(7) && j.parametros.get(5).equals("127.0.0.8") && n.path("cuotaTotal").decimalValue().compareTo(decimal("5.0000"))==0);j.cerrado();});
        caso("JSON cotizacion marcador",()->{Jdbc j=cotizacion("MARCADOR_FINAL",false);Http h=new Http();h.parametros.put("pronosticoA",new String[]{"0"});h.parametros.put("pronosticoB",new String[]{"2"});JsonNode n=http(j,true,h,200);exigir(n.path("pronosticoA").asInt()==0 && n.path("tipoMercado").asText().equals("MARCADOR_FINAL"));});
        caso("JSON realizar marcador",()->{Jdbc j=realizacion(false,false);Http h=new Http();h.parametros.put("pronosticoA",new String[]{"0"});h.parametros.put("pronosticoB",new String[]{"2"});http(j,false,h,201);exigir(j.parametros.get(6).equals(0));});
        for(String valor:Arrays.asList("","-1","1.5","2147483648"))caso("pronostico invalido "+valor,()->{Http h=new Http();h.parametros.put("pronosticoA",new String[]{valor});Jdbc j=realizacion(false,false);http(j,false,h,400);exigir(j.llamadas==0);});
        caso("pronostico incompleto",()->{Http h=new Http();h.parametros.put("pronosticoA",new String[]{"1"});Jdbc j=realizacion(false,false);http(j,false,h,400);exigir(j.llamadas==0);});
        caso("pronostico compuesto rechazo temprano",()->{Http h=new Http();h.parametros.put("pronosticoA",new String[]{"1"});h.parametros.put("pronosticoB",new String[]{"1"});h.parametros.put("idSeleccion",new String[]{"11","12"});Jdbc j=realizacion(true,false);http(j,false,h,400);exigir(j.llamadas==0);});
        caso("metodo no permitido JSON",()->{Http h=new Http();h.metodo="GET";new CotizarApuestaServlet().service(h.req,h.res);exigir(h.estado==405 && new ObjectMapper().readTree(h.cuerpo.toString()).has("mensaje"));});
        // Los IDs son opacos para Java: el doble reproduce el rechazo SQL oficial.
        for(boolean cotizar:new boolean[]{true,false}) {
            for(String mezcla:Arrays.asList("nueva + convencional","marcador + primera","multiples nuevas"))
                caso("rechazo SQL combinacion " + mezcla + " " + cotizar,()->{
                    Jdbc j=realizacion(true,false);j.error=76101;Http h=new Http();
                    h.parametros.put("idSeleccion",new String[]{"11","12"});
                    http(j,cotizar,h,400);exigir(j.llamadas==1);j.cerrado();
                });
        }
        for(int codigo:new int[]{60005,60054,99999})
            caso("regresion auditoria cotizar " + codigo,()->PruebaAuditoriaUsuario.errorSql(CotizarApuestaServlet.class,codigo,codigo==60005?400:codigo==60054?409:500));
        caso("regresion auditoria cotizar correcto",()->PruebaAuditoriaUsuario.exploracionCorrecta(4));
        System.out.println("Modalidades apuestas: "+pass+" PASS, "+fail+" FAIL.");if(fail!=0)throw new AssertionError("Pruebas de modalidades fallidas");
    }
}
