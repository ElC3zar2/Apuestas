package com.apuestas.controlador;

import com.apuestas.dao.DashboardAdministrativoDAO;
import com.apuestas.servicio.DashboardAdministrativoServicio;
import com.apuestas.modelo.OperacionDashboardAdministrativo;
import com.apuestas.seguridad.ControlAccesoAdministrativo;
import com.fasterxml.jackson.databind.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.sql.*;
import java.util.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;

/** Servlet, servicio y DAO reales; JDBC estricto simulado, sin SQL ni SMTP real. */
public class PruebaDashboardAdministrativo {
    private static int casos;
    private static final String PRIVADO="SECRETO_DASHBOARD";
    private static final String UUID="12345678-1234-1234-1234-123456789012";
    private static final ObjectMapper JSON=new ObjectMapper().enable(DeserializationFeature.USE_BIG_DECIMAL_FOR_FLOATS);
    private static Timestamp fecha() { return Timestamp.valueOf("2026-01-02 03:04:05.1234567"); }
    private static BigDecimal decimal(String s) { return new BigDecimal(s); }
    private static Map<String,Object> fila(Object... pares) {
        Map<String,Object> r=new LinkedHashMap<>();
        for(int i=0;i<pares.length;i+=2) r.put((String)pares[i],pares[i+1]);return r;
    }
    // Fixtures independientes del codigo productivo y de sus listas de columnas.
    private static Map<String,Object> resumen() {
        return fila("ClientesRegistrados",12,"ClientesActivos",10,"EventosTotales",15,"EventosProgramados",3,
                "EventosPrevia",2,"EventosEnProgreso",1,"EventosPendienteResultado",1,"EventosFinalizados",8,
                "BoletosTotales",10,"BoletosPendientes",2,"BoletosGanadores",3,"BoletosPerdedores",4,"BoletosAnulados",1,
                "TotalApostadoHistorico",decimal("12345678901234567890.12"),"ComisionesHistoricas",decimal("25.00"),
                "ComisionesRealizadas",decimal("20.00"),"ComisionesPendientes",decimal("3.00"),
                "ComisionesDevueltas",decimal("2.00"),"MontoApostadoPendiente",decimal("50.00"),
                "PremioPotencialPendiente",decimal("100.00"),"ExposicionPotencialCasa",decimal("47.00"),
                "GananciaCasaPorApuestasPerdidas",decimal("80.00"),"PremiosPagados",decimal("130.00"),
                "ResultadoCasaRealizado",decimal("-10.23"),"AccionesAuditoriaUltimas24Horas",5);
    }
    private static Map<String,Object> deporte() {
        return fila("IdDeporte",2,"Deporte","Baloncesto","EventosTotales",6,"Programados",2,"Previa",1,"EnProgreso",1,
                "PendienteResultado",1,"Finalizados",1,"BoletosRelacionados",8,"ClientesUnicos",5,
                "BoletosPendientes",2,"BoletosGanadores",2,"BoletosPerdedores",3,"BoletosAnulados",1,
                "MontoApostadoRelacionado",decimal("99.99"),"ComisionRelacionada",decimal("5.00"),
                "PremioPotencialPendienteRelacionado",decimal("100.00"),"CantidadSeleccionesApostadas",10,
                "SeleccionesPendientes",2,"SeleccionesGanadas",3,"SeleccionesPerdidas",4,
                "CuotaPromedio",decimal("1.2345"),"ProbabilidadImplicitaPromedio",decimal("81.00"));
    }
    private static Map<String,Object> auditoria() {
        return fila("IdAuditoria",5000000000L,"FechaAccion",fecha(),"IdUsuario",7,"Correo","admin@example.test",
                "Accion","LIQUIDAR_BOLETO","TablaAfectada","Boleto","IdRegistro",6000000000L,
                "ReferenciaOperacion",UUID,"IpOrigen","127.0.0.1","Descripcion",PRIVADO);
    }
    private static Map<String,Object> evento() {
        return fila("IdEvento",19,"IdDeporte",2,"Deporte","Baloncesto","IdLiga",3,"Liga","Liga de prueba",
                "Evento","Evento de prueba","FechaInicio",fecha(),"FechaFin",fecha(),"EstadoEvento","PROGRAMADO",
                "EstadoVisual","PREVIA","CantidadMercados",2,"MercadosAbiertos",1,"CantidadSelecciones",4,
                "SeleccionesConCuotaActiva",3,"BoletosRelacionados",5,"ClientesUnicos",4,"BoletosPendientes",2,
                "BoletosGanadores",1,"BoletosPerdedores",1,"BoletosAnulados",1,
                "MontoApostadoRelacionado",decimal("123.45"),"ComisionRelacionada",decimal("6.00"),
                "PremioPotencialPendienteRelacionado",decimal("50.00"),"ExposicionPotencialRelacionada",decimal("10.00"),
                "ResultadoCasaRealizadoRelacionado",decimal("-3.12"),"CuotaPromedioBoletos",decimal("1.2345"),
                "UltimaApuestaRelacionada",fecha());
    }
    private static boolean nullable(int grupo,String col) {
        if(grupo==1) return Arrays.asList("CuotaPromedio","ProbabilidadImplicitaPromedio").contains(col);
        if(grupo==2) return !Arrays.asList("IdAuditoria","FechaAccion","Accion").contains(col);
        return grupo==3&&Arrays.asList("FechaFin","CuotaPromedioBoletos","UltimaApuestaRelacionada").contains(col);
    }
    static class Bloque {
        final List<String> columnas;
        final List<Map<String,Object>> filas=new ArrayList<>();
        Bloque(Map<String,Object> fila) { columnas=new ArrayList<>(fila.keySet());filas.add(fila); }
    }
    static class Jdbc {
        final boolean eventos;
        final List<Bloque> bloques=new ArrayList<>();
        final Map<Integer,Object> params=new HashMap<>();
        int conexiones,llamadas,ejecuciones,indice,abiertos,cerrados,codigo,pasos;
        boolean conexionCerrada,statementCerrado,conteos,rsNull,metadataNull,falloConexion,falloPreparar,falloPosterior,falloRuntime;
        Jdbc(boolean eventos) {
            this.eventos=eventos;
            if(eventos) bloques.add(new Bloque(evento()));
            else { bloques.add(new Bloque(resumen()));bloques.add(new Bloque(deporte()));bloques.add(new Bloque(auditoria())); }
        }
        Map<String,Object> fila(int i) { return bloques.get(i).filas.get(0); }
        int bloqueActual() { return conteos?indice/2:indice; }
        boolean hay() { return bloqueActual()<bloques.size()&&(!conteos||indice%2==1); }
        Connection conexion() throws SQLException {
            conexiones++;if(falloConexion) throw new SQLException(PRIVADO);
            return proxy(Connection.class,(p,m,a)-> {
                if(m.getName().equals("close")) { conexionCerrada=true;return null; }
                if(m.getName().equals("prepareCall")) {
                    llamadas++;if(falloPreparar) throw new SQLException(PRIVADO);
                    exigir(a[0].equals(eventos?"{call dbo.sp_ObtenerAnaliticaEventosAdministracion(?, ?, ?, ?, ?)}":
                            "{call dbo.sp_ObtenerDashboardAdministrativo(?, ?, ?)}"));
                    return sentencia();
                }
                throw new AssertionError("JDBC no permitido: "+m.getName());
            });
        }
        CallableStatement sentencia() {
            return proxy(CallableStatement.class,(p,m,a)-> {
                switch(m.getName()) {
                    case "setInt":case "setString":params.put((Integer)a[0],a[1]);return null;
                    case "setNull":exigir((Integer)a[1]==Types.INTEGER);params.put((Integer)a[0],null);return null;
                    case "execute":
                        ejecuciones++;if(codigo!=0) throw new SQLException(PRIVADO,"TEST",codigo);
                        if(falloRuntime) throw new IllegalStateException(PRIVADO);
                        indice=0;return hay();
                    case "getMoreResults":
                        pasos++;if(falloPosterior) throw new SQLException(PRIVADO);
                        indice++;return hay();
                    case "getUpdateCount":return bloqueActual()<bloques.size()&&conteos&&indice%2==0?2:-1;
                    case "getResultSet":return rsNull?null:rs(bloques.get(bloqueActual()));
                    case "close":statementCerrado=true;return null;
                    default:throw new AssertionError(m.getName());
                }
            });
        }
        ResultSet rs(Bloque b) {
            abiertos++;int[] pos={-1};
            return proxy(ResultSet.class,(p,m,a)-> {
                switch(m.getName()) {
                    case "next":return ++pos[0]<b.filas.size();
                    case "close":cerrados++;return null;
                    case "getMetaData":
                        if(metadataNull) return null;
                        return proxy(ResultSetMetaData.class,(mp,mm,ma)-> {
                            if(mm.getName().equals("getColumnCount")) return b.columnas.size();
                            if(mm.getName().equals("getColumnLabel")) return b.columnas.get((Integer)ma[0]-1);
                            throw new AssertionError(mm.getName());
                        });
                    case "getObject":
                        Map<String,Object> r=b.filas.get(pos[0]);
                        if(!r.containsKey(a[0])) throw new SQLException(PRIVADO);
                        return r.get(a[0]);
                    default:throw new AssertionError(m.getName());
                }
            });
        }
    }
    static class Caso {
        final Http h=new Http();final Jdbc j;
        final Map<String,String[]> params=new LinkedHashMap<>();
        final HttpServletRequest req;
        boolean directo;
        Caso(boolean eventos) {
            j=new Jdbc(eventos);h.ruta=eventos?"/administrador/analitica/eventos":"/administrador/dashboard/resumen";h.method="GET";
            h.previa=new Sesion();h.previa.datos.put("adminIdUsuario",7);h.previa.datos.put("adminIdRol",3);
            h.previa.datos.put("adminCorreo","admin@example.test");h.previa.datos.put("adminRol","ADMINISTRADOR");
            h.previa.datos.put("adminEstadoUsuario","ACTIVO");
            req=proxy(HttpServletRequest.class,(p,m,a)-> {
                if(m.getName().equals("getParameterMap")) { exigir("UTF-8".equals(h.encoding));return params; }
                if(m.getName().equals("getRemoteAddr")) throw new AssertionError("Los SP no aceptan IP");
                try { return m.invoke(h.req,a); } catch(InvocationTargetException e) { throw e.getCause(); }
            });
        }
        void p(String k,String... valores) { params.put(k,valores); }
        int numero(String k,int defecto) { return params.containsKey(k)?Integer.parseInt(params.get(k)[0].trim()):defecto; }
        JsonNode ejecutar(int esperado) throws Exception {
            DashboardAdministrativoServlet s=new DashboardAdministrativoServlet();
            Field f=DashboardAdministrativoServlet.class.getDeclaredField("servicio");f.setAccessible(true);
            f.set(s,new DashboardAdministrativoServicio(new DashboardAdministrativoDAO() {
                @Override protected Connection obtenerConexion() throws SQLException { return j.conexion(); }
            }));
            if(directo) s.service(req,h.res);
            else new ControlAccesoAdministrativo().doFilter(req,h.res,(r,res)->s.service((HttpServletRequest)r,(HttpServletResponse)res));
            if(h.status!=esperado) throw new AssertionError(h.ruta+" HTTP esperado "+esperado+", recibido "+h.status);
            if(!"application/json;charset=UTF-8".equals(h.tipo)) throw new AssertionError("Content-Type no JSON");
            exigir("no-store".equals(h.headers.get("Cache-Control"))&&h.creaciones==0);
            String body=h.body.toString();
            exigir(!body.contains(PRIVADO)&&!body.contains("SQLException")&&!body.contains("dbo.")&&!body.contains("SECRETO_INTERNO"));
            JsonNode json=JSON.readTree(body);
            exigir(json.path("ok").asBoolean()==(esperado==200));
            if(esperado!=200) exigir(json.size()==2&&json.has("mensaje"));
            else {
                exigir(json.size()==(j.eventos?3:5)&&json.has("filtros"));
                exigir(json.at("/filtros/horasPrevia").asInt()==numero("horasPrevia",24));
                if(j.eventos) {
                    exigir(json.at("/filtros/cantidad").asInt()==numero("cantidad",100));
                    exigir(params.containsKey("idDeporte")?json.at("/filtros/idDeporte").asInt()==numero("idDeporte",0):
                            json.at("/filtros/idDeporte").isNull());
                    exigir(json.at("/filtros/vista").asText().equals(params.containsKey("vista")?params.get("vista")[0].trim().toUpperCase(Locale.ROOT):"TODOS"));
                } else exigir(json.at("/filtros/cantidadAuditoria").asInt()==numero("cantidadAuditoria",25));
            }
            if(j.conexiones>0) {
                exigir(j.conexiones==1&&j.abiertos==j.cerrados);
                if(!j.falloConexion) {
                    exigir(j.conexionCerrada&&j.llamadas==1);
                    if(!j.falloPreparar) {
                        exigir(j.statementCerrado&&j.ejecuciones==1&&j.params.get(1).equals(7));
                        exigir(j.params.size()==(j.eventos?5:3));
                        if(j.eventos) {
                            exigir(Objects.equals(j.params.get(2),params.containsKey("idDeporte")?Integer.valueOf(numero("idDeporte",0)):null));
                            exigir(j.params.get(3).equals(params.containsKey("vista")?params.get("vista")[0].trim().toUpperCase(Locale.ROOT):"TODOS"));
                            exigir(j.params.get(4).equals(numero("horasPrevia",24))&&j.params.get(5).equals(numero("cantidad",100)));
                        } else exigir(j.params.get(2).equals(numero("horasPrevia",24))&&j.params.get(3).equals(numero("cantidadAuditoria",25)));
                    }
                }
            }
            if(esperado==200) exigir(j.pasos>0);
            casos++;return json;
        }
    }
    private static int estadoSql(int c) {
        if(Arrays.asList(64018,64019,64020,64028,64029,64030).contains(c)) return 403;
        if(c==64021) return 404;
        if(c>=64022&&c<=64027) return 400;
        return 500;
    }
    public static void main(String[] args) throws Exception {
        if(args.length>0) { Caso c=new Caso(false);c.h.previa=null;c.ejecutar(401);return; }
        Set<String> rutas=new HashSet<>(Arrays.asList(DashboardAdministrativoServlet.class.getAnnotation(WebServlet.class).value()));
        exigir(rutas.equals(new HashSet<>(Arrays.asList("/administrador/dashboard/resumen","/administrador/analitica/eventos"))));
        for(boolean eventos:new boolean[]{false,true}) {
            Caso c=new Caso(eventos);JsonNode json=c.ejecutar(200);
            exigir(json.has(eventos?"eventos":"resumen"));
            if(!eventos) {
                exigir(json.get("resumen").size()==25&&json.at("/deportes/0").size()==23&&json.at("/auditoriaReciente/0").size()==7);
                exigir(json.at("/resumen/totalApostadoHistorico").decimalValue().equals(decimal("12345678901234567890.12")));
                exigir(json.at("/auditoriaReciente/0/idAuditoria").longValue()==5000000000L);
                exigir(!json.at("/auditoriaReciente/0").has("descripcion")&&!json.at("/auditoriaReciente/0").has("ipOrigen")
                        &&!json.at("/auditoriaReciente/0").has("referenciaOperacion"));
            } else exigir(json.at("/eventos/0").size()==27);
            c=new Caso(eventos);c.j.conteos=true;c.ejecutar(200);
            for(String rol:new String[]{"ADMINISTRADOR","AUDITOR","OPERADOR_EVENTOS","CAJERO","USUARIO","CASA"}) {
                c=new Caso(eventos);c.h.previa.datos.put("adminRol",rol);
                boolean permitido=rol.equals("ADMINISTRADOR")||rol.equals("AUDITOR");
                c.ejecutar(permitido?200:403);if(!permitido) exigir(c.j.conexiones==0);
            }
            c=new Caso(eventos);c.h.previa=null;c.ejecutar(401);
            c=new Caso(eventos);c.h.previa.expirada=true;c.ejecutar(401);
            c=new Caso(eventos);c.h.previa.falloLectura=true;c.ejecutar(500);
            c=new Caso(eventos);c.directo=true;c.h.previa=null;c.ejecutar(401);
            c=new Caso(eventos);c.directo=true;c.h.previa.expirada=true;c.ejecutar(401);
            c=new Caso(eventos);c.directo=true;c.h.previa.datos.put("adminEstadoUsuario","SUSPENDIDO");c.ejecutar(403);
            c=new Caso(eventos);c.h.previa.datos.put("idUsuario",7);c.h.previa.datos.put("rol","USUARIO");c.ejecutar(403);
            for(String k:new String[]{"adminIdUsuario","adminIdRol","adminCorreo","adminRol","adminEstadoUsuario"}) {
                c=new Caso(eventos);c.h.previa.datos.remove(k);c.ejecutar(403);
            }
            for(Object id:new Object[]{0,-1,7L,"7"}) {
                c=new Caso(eventos);c.h.previa.datos.put("adminIdUsuario",id);c.ejecutar(403);
            }
            for(String metodo:new String[]{"POST","HEAD","OPTIONS","PUT","PATCH","DELETE"}) {
                c=new Caso(eventos);c.h.method=metodo;c.ejecutar(405);
                exigir("GET".equals(c.h.headers.get("Allow"))&&c.j.conexiones==0);
            }
            for(String clave:new String[]{"idUsuarioSolicitante","idUsuarioProceso","idAdministrador","rolAdministrador","correoAdministrador","IpOrigen","ipOrigen","otro",eventos?"cantidadAuditoria":"cantidad"}) {
                c=new Caso(eventos);c.p(clave,"1");c.ejecutar(400);exigir(c.j.conexiones==0);
            }
            String[] claves=eventos?new String[]{"idDeporte","vista","horasPrevia","cantidad"}:new String[]{"horasPrevia","cantidadAuditoria"};
            for(String clave:claves) {
                for(String[] valores:new String[][]{new String[]{"1","2"},new String[0],null,new String[]{null}}) {
                    c=new Caso(eventos);c.p(clave,valores);c.ejecutar(400);exigir(c.j.conexiones==0);
                }
                if(clave.equals("vista")) continue;
                for(String valor:new String[]{""," ","0","-1","abc","1.1","2147483648","1 OR 1=1"}) {
                    c=new Caso(eventos);c.p(clave,valor);c.ejecutar(400);
                }
            }
            for(String hora:new String[]{"1","48","2147483647"}) { c=new Caso(eventos);c.p("horasPrevia",hora);c.ejecutar(200); }
            String cantidad=eventos?"cantidad":"cantidadAuditoria";
            for(String valor:new String[]{"1",eventos?"500":"100"}) { c=new Caso(eventos);c.p(cantidad,valor);c.ejecutar(200); }
            c=new Caso(eventos);c.p(cantidad,eventos?"501":"101");c.ejecutar(400);
            c=new Caso(eventos);c.j.codigo=99999;c.ejecutar(500);
            c=new Caso(eventos);c.j.falloConexion=true;c.ejecutar(500);
            c=new Caso(eventos);c.j.falloPreparar=true;c.ejecutar(500);
            c=new Caso(eventos);c.j.falloPosterior=true;c.ejecutar(500);
            c=new Caso(eventos);c.j.falloRuntime=true;c.ejecutar(500);
            c=new Caso(eventos);c.j.rsNull=true;c.ejecutar(500);
            c=new Caso(eventos);c.j.metadataNull=true;c.ejecutar(500);
            c=new Caso(eventos);c.j.bloques.clear();c.ejecutar(500);
            c=new Caso(eventos);c.j.bloques.add(new Bloque(evento()));c.ejecutar(500);
            int bloques=eventos?1:3;
            for(int b=0;b<bloques;b++) {
                int grupo=eventos?3:b;
                c=new Caso(eventos);c.j.bloques.remove(b);c.ejecutar(500);
                c=new Caso(eventos);c.j.bloques.get(b).filas.clear();c.ejecutar(!eventos&&b==0?500:200);
                c=new Caso(eventos);c.j.bloques.get(b).filas.add(new LinkedHashMap<>(c.j.fila(b)));c.ejecutar(500);
                for(Map.Entry<String,Object> col:new Caso(eventos).j.fila(b).entrySet()) {
                    c=new Caso(eventos);c.j.fila(b).remove(col.getKey());c.ejecutar(500);
                    c=new Caso(eventos);c.j.fila(b).put(col.getKey(),new Object());c.ejecutar(500);
                    c=new Caso(eventos);c.j.fila(b).put(col.getKey(),null);c.ejecutar(nullable(grupo,col.getKey())?200:500);
                    c=new Caso(eventos);c.j.bloques.get(b).columnas.remove(col.getKey());c.ejecutar(500);
                    if(col.getValue() instanceof BigDecimal) {
                        c=new Caso(eventos);c.j.fila(b).put(col.getKey(),decimal("0.00001"));c.ejecutar(500);
                        c=new Caso(eventos);c.j.fila(b).put(col.getKey(),decimal("1E+40"));c.ejecutar(500);
                        c=new Caso(eventos);c.j.fila(b).put(col.getKey(),decimal("-1.23"));
                        c.ejecutar(col.getKey().startsWith("ResultadoCasa")?200:500);
                    }
                    if(col.getValue() instanceof Integer) {
                        c=new Caso(eventos);c.j.fila(b).put(col.getKey(),-1);c.ejecutar(500);
                    }
                }
                c=new Caso(eventos);c.j.bloques.get(b).columnas.add(c.j.bloques.get(b).columnas.get(0));c.ejecutar(500);
            }
        }
        for(int codigo=64018;codigo<=64030;codigo++) {
            Caso c=new Caso(codigo<=64024);c.j.codigo=codigo;c.ejecutar(estadoSql(codigo));
        }
        for(String vista:new String[]{"TODOS","PROGRAMADOS","PREVIA","EN_PROGRESO","PENDIENTE_RESULTADO","FINALIZADOS","BORRADOR","SUSPENDIDOS","CANCELADOS"," previa "}) {
            Caso c=new Caso(true);c.p("vista",vista);c.p("idDeporte","2");c.p("horasPrevia","48");c.p("cantidad","50");c.ejecutar(200);
        }
        for(String vista:new String[]{"","HOY","SEMANA","MES","EN_VIVO","X".repeat(31)}) {
            Caso c=new Caso(true);c.p("vista",vista);c.ejecutar(400);
        }
        Caso c=new Caso(true);c.p("idDeporte","3");c.ejecutar(500);
        c=new Caso(false);Collections.swap(c.j.bloques,0,1);c.ejecutar(500);
        c=new Caso(false);c.j.bloques.get(1).filas.clear();c.j.bloques.get(2).filas.clear();
        Collections.swap(c.j.bloques,1,2);c.ejecutar(500);
        c=new Caso(false);Map<String,Object> otro=deporte();otro.put("IdDeporte",3);otro.put("Deporte","Tenis");
        c.j.bloques.get(1).filas.add(otro);exigir(c.ejecutar(200).get("deportes").size()==2);
        c=new Caso(false);otro=auditoria();otro.put("IdAuditoria",5000000001L);c.j.bloques.get(2).filas.add(otro);
        c.p("cantidadAuditoria","1");c.ejecutar(500);
        c=new Caso(true);otro=evento();otro.put("IdEvento",20);c.j.bloques.get(0).filas.add(otro);
        exigir(c.ejecutar(200).get("eventos").size()==2);
        c=new Caso(true);c.j.bloques.get(0).filas.add(otro);c.p("cantidad","1");c.ejecutar(500);
        c=new Caso(false);c.j.fila(0).put("ResultadoCasaRealizado",decimal("-9876.54"));
        exigir(c.ejecutar(200).at("/resumen/resultadoCasaRealizado").decimalValue().equals(decimal("-9876.54")));
        c=new Caso(true);String nombre="Evento \"citado\"\n\u0001 fin";c.j.fila(0).put("Evento",nombre);
        exigir(c.ejecutar(200).at("/eventos/0/evento").asText().equals(nombre));
        c=new Caso(false);c.j.fila(0).put("Password",PRIVADO);c.j.fila(1).put("Token",PRIVADO);c.ejecutar(200);
        c=new Caso(false);c.directo=true;c.h.ruta="/administrador/dashboard/desconocido";c.ejecutar(404);
        System.out.println("Dashboard administrativo: "+casos+" casos, 0 fallos.");
    }
}
