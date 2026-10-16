package com.apuestas.controlador;

import com.apuestas.dao.*;
import com.apuestas.modelo.*;
import com.apuestas.modelo.ConsultasAdministrativasModelos.*;
import com.apuestas.seguridad.*;
import com.apuestas.servicio.*;
import com.fasterxml.jackson.databind.*;
import java.lang.reflect.*;
import java.sql.*;
import java.util.*;
import javax.servlet.http.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.*;

/** Contratos HTTP y DAO reales con JDBC controlado. Nunca abre SQL. */
public class PruebaCierreAdministrativo {
    static int casos;
    static final ObjectMapper JSON=new ObjectMapper();
    static void caso(boolean ok){exigir(ok);casos++;}
    static void sesion(Http h,String rol){h.previa=new Sesion();h.previa.datos.put("adminIdUsuario",7);h.previa.datos.put("adminIdRol",3);h.previa.datos.put("adminCorreo","admin@example.test");h.previa.datos.put("adminRol",rol);h.previa.datos.put("adminEstadoUsuario","ACTIVO");}
    static class Fuentes {
        int consultas;boolean vacio;String buscar;Integer deporte;String estado;int pagina,tamano;
        ConsultasAdministrativasServicio servicio(){return new ConsultasAdministrativasServicio(new EventoDAO(){
            @Override public PaginaEventos listarSelectores(Integer d,String e,int p,int t){consultas++;deporte=d;estado=e;pagina=p;tamano=t;
                EventoSelector v=new EventoSelector();v.idEvento=19;v.idDeporte=1;v.evento="Evento <seguro>";
                return new PaginaEventos(p,t,vacio?0:1,vacio?Collections.emptyList():Arrays.asList(v));}
        },new AdministracionUsuarioDAO(){
            @Override public PaginaUsuarios buscarUsuarios(String b,int p,int t){consultas++;buscar=b;pagina=p;tamano=t;
                UsuarioBusqueda v=new UsuarioBusqueda();v.idUsuario=9;v.nombre="José";v.apellido="López";v.correo="cliente@example.test";v.estadoUsuario="ACTIVO";v.rol="USUARIO";
                return new PaginaUsuarios(p,t,vacio?0:1,vacio?Collections.emptyList():Arrays.asList(v));}
        },new UbicacionDAO(){@Override public List<Pais> listarPaisesActivos(){consultas++;return vacio?Collections.emptyList():Arrays.asList(new Pais(3,"GT","Guatemala"));}},new DetalleEventoAdministrativoDAO(){
            @Override public ConsultaDetalleEventoAdministrativo.Evento consultar(int id){consultas++;if(vacio)return null;ConsultaDetalleEventoAdministrativo.Evento e=new ConsultaDetalleEventoAdministrativo.Evento();e.idEvento=id;return e;}
        });}
    }
    static class Api {
        Http h=new Http();Map<String,String[]> params=new LinkedHashMap<>();Fuentes datos=new Fuentes();ConsultasAdministrativasServicio servicio;
        Api(OperacionConsultaAdministrativa op,String rol){h.ruta=op.ruta;h.method="GET";sesion(h,rol);servicio=datos.servicio();if(op==OperacionConsultaAdministrativa.DETALLE_EVENTO)p("idEvento","19");}
        void p(String k,String... v){params.put(k,v);}
        JsonNode ejecutar(int estado)throws Exception {
            HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)->{
                if(m.getName().equals("getParameterMap"))return params;
                try{return m.invoke(h.req,a);}catch(InvocationTargetException e){throw e.getCause();}
            });
            ConsultasAdministrativasServlet s=new ConsultasAdministrativasServlet();Field f=s.getClass().getDeclaredField("servicio");f.setAccessible(true);f.set(s,servicio);
            new ControlAccesoAdministrativo().doFilter(req,h.res,(r,res)->s.service((HttpServletRequest)r,(HttpServletResponse)res));
            if(h.status!=estado)throw new AssertionError(h.ruta+" esperado "+estado+" recibido "+h.status+" "+h.body);
            caso(h.creaciones==0&&"application/json;charset=UTF-8".equals(h.tipo)&&"no-store".equals(h.headers.get("Cache-Control")));
            caso(!h.body.toString().contains("SECRETO")&&!h.body.toString().contains("SQLException"));
            JsonNode json=JSON.readTree(h.body.toString());caso(json.path("ok").asBoolean()==(estado==200));return json;
        }
    }
    static class Jdbc {
        List<String> sql=new ArrayList<>();List<Map<Integer,Object>> bindings=new ArrayList<>();
        List<Map<String,Object>> rows=new ArrayList<>();long total=1;int closeC,closeP,closeR;boolean fail;
        Connection conexion(){return proxy(Connection.class,(p,m,a)->{
            if(m.getName().equals("close")){closeC++;return null;}
            if(!m.getName().equals("prepareStatement"))throw new AssertionError(m.getName());
            String query=(String)a[0];caso(query.startsWith("SELECT ")&&!query.contains("Contrasena")&&!query.contains("Token"));sql.add(query);
            Map<Integer,Object> b=new LinkedHashMap<>();bindings.add(b);
            return proxy(PreparedStatement.class,(sp,sm,sa)->{
                if(sm.getName().startsWith("set")){b.put((Integer)sa[0],sa[1]);return null;}
                if(sm.getName().equals("close")){closeP++;return null;}
                if(!sm.getName().equals("executeQuery"))throw new AssertionError(sm.getName());
                if(fail)throw new SQLException("SECRETO");
                List<Map<String,Object>> data=query.contains("COUNT_BIG")?Arrays.asList(Collections.singletonMap("Total",total)):rows;
                int[] pos={-1};return proxy(ResultSet.class,(rp,rm,ra)->{
                    if(rm.getName().equals("next"))return ++pos[0]<data.size();
                    if(rm.getName().equals("close")){closeR++;return null;}
                    Object value=data.get(pos[0]).get(ra[0]);
                    if(rm.getName().equals("getInt"))return value==null?0:value;
                    if(Arrays.asList("getObject","getString","getTimestamp").contains(rm.getName()))return value;
                    throw new AssertionError(rm.getName());
                });
            });
        });}
    }
    static Map<String,Object> fila(Object... v){Map<String,Object> r=new LinkedHashMap<>();for(int i=0;i<v.length;i+=2)r.put((String)v[i],v[i+1]);return r;}
    static void dao()throws Exception {
        Jdbc u=new Jdbc();u.rows.add(fila("IdUsuario",9,"Nombre","José","Apellido","López","Correo","x@test.test","EstadoUsuario","ACTIVO","Rol","USUARIO"));
        AdministracionUsuarioDAO usuarios=new AdministracionUsuarioDAO(){@Override protected Connection obtenerConexion(){return u.conexion();}};
        String busqueda="O'Neil %_[!] OR 1=1";
        PaginaUsuarios result=usuarios.buscarUsuarios(busqueda,3,25);caso(result.usuarios.size()==1&&result.pagina==3);
        caso(u.bindings.get(1).get(3).equals(50L)&&u.bindings.get(1).get(4).equals(25));
        caso(!u.sql.get(0).contains(busqueda)&&u.bindings.get(0).get(1).toString().contains("!%")&&u.bindings.get(0).get(1).toString().contains("!_"));
        caso(u.closeC==1&&u.closeP==2&&u.closeR==2);
        String json=JSON.writeValueAsString(result);for(String secret:new String[]{"contrasena","password","hash","salt","token","fechaNacimiento","telefono","numeroDocumento"})caso(!json.contains("\""+secret+"\""));
        u.rows.clear();u.total=0;caso(usuarios.buscarUsuarios("",1,50).usuarios.isEmpty());
        Jdbc e=new Jdbc();e.rows.add(fila("IdEvento",19,"IdDeporte",1,"IdLiga",11,"Evento","A vs B","Deporte","Futbol","Liga","Liga real","EstadoEvento","CANCELADO","Participante1","A","Participante2","B","FechaInicio",Timestamp.valueOf("2026-10-18 20:00:00")));
        EventoDAO eventos=new EventoDAO(){@Override protected Connection obtenerConexionSelector(){return e.conexion();}};
        PaginaEventos ev=eventos.listarSelectores(1,"CANCELADO",2,50);caso(ev.eventos.get(0).participante1.equals("A"));
        caso(e.bindings.get(0).get(1).equals(1)&&e.bindings.get(0).get(2).equals("CANCELADO"));
        caso(e.bindings.get(1).get(3).equals(50L)&&e.bindings.get(1).get(4).equals(50));caso(e.closeC==1&&e.closeP==2&&e.closeR==2);
        e.rows.clear();e.total=0;caso(eventos.listarSelectores(null,null,1,50).eventos.isEmpty());
        e.fail=true;try{eventos.listarSelectores(null,null,1,50);throw new AssertionError();}catch(SQLException expected){caso(e.closeC==3&&e.closeP==5);}
    }
    static void vistas()throws Exception {
        for(VistasAdministrativas vista:VistasAdministrativas.values())for(String rol:new String[]{"ADMINISTRADOR","OPERADOR_EVENTOS","CAJERO","AUDITOR"}){
            Http h=new Http();h.method="GET";h.ruta=vista.ruta;sesion(h,rol);
            Http actual=h;new ControlAccesoAdministrativo().doFilter(h.req,h.res,(r,res)->new VistasAdministrativasServlet().service(actual.req,actual.res));
            caso(h.status==(vista.permite(rol)?200:403));caso(vista.permite(rol)?vista.jsp.equals(h.forward):h.forward==null);caso(h.creaciones==0);
            if(rol.equals("ADMINISTRADOR")){
                h=new Http();h.method="GET";h.ruta=vista.jsp;sesion(h,rol);Http directa=h;new ControlAccesoAdministrativo().doFilter(h.req,h.res,(r,res)->directa.chain++);
                caso(h.status==303&&("/app"+vista.ruta).equals(h.headers.get("Location"))&&h.chain==0);
            }
        }
        Http h=new Http();h.method="GET";h.ruta="/administrador/inicio";h.previa=null;new VistasAdministrativasServlet().service(h.req,h.res);caso(h.status==303&&"/app/administrador/login".equals(h.headers.get("Location")));
        h=new Http();h.method="GET";h.ruta="/administrador/no-existe";new VistasAdministrativasServlet().service(h.req,h.res);caso(h.status==404);
        h=new Http();h.method="POST";h.ruta="/administrador/eventos";new VistasAdministrativasServlet().service(h.req,h.res);caso(h.status==405&&"GET, HEAD".equals(h.headers.get("Allow")));
        h=new Http();h.method="GET";h.ruta="/administrador/eventos";sesion(h,"ADMINISTRADOR");h.previa.expirada=true;new VistasAdministrativasServlet().service(h.req,h.res);caso(h.status==303);
    }
    public static void main(String[] args)throws Exception {
        vistas();dao();
        for(OperacionConsultaAdministrativa op:OperacionConsultaAdministrativa.values()){
            for(String rol:new String[]{"ADMINISTRADOR","OPERADOR_EVENTOS","CAJERO","AUDITOR","USUARIO","CASA"}){
                Api a=new Api(op,rol);boolean permitido=rol.equals("ADMINISTRADOR")||op==OperacionConsultaAdministrativa.EVENTOS&&SesionAdministrativa.rolPermitido(rol)||op==OperacionConsultaAdministrativa.PAISES&&rol.equals("OPERADOR_EVENTOS")||op==OperacionConsultaAdministrativa.USUARIOS&&rol.equals("AUDITOR")||op==OperacionConsultaAdministrativa.DETALLE_EVENTO&&Arrays.asList("OPERADOR_EVENTOS","AUDITOR").contains(rol);
                a.ejecutar(permitido?200:403);caso(a.datos.consultas==(permitido?1:0));
            }
            Api a=new Api(op,"ADMINISTRADOR");a.datos.vacio=true;JsonNode j=a.ejecutar(op==OperacionConsultaAdministrativa.DETALLE_EVENTO?404:200);if(op!=OperacionConsultaAdministrativa.DETALLE_EVENTO)caso(j.path(op==OperacionConsultaAdministrativa.EVENTOS?"eventos":op==OperacionConsultaAdministrativa.PAISES?"paises":"usuarios").size()==0);
            a=new Api(op,"ADMINISTRADOR");a.h.previa=null;a.ejecutar(401);caso(a.datos.consultas==0);
            a=new Api(op,"ADMINISTRADOR");a.h.previa.expirada=true;a.ejecutar(401);
            for(String method:new String[]{"POST","PUT","DELETE","HEAD","OPTIONS"}){a=new Api(op,"ADMINISTRADOR");a.h.method=method;a.ejecutar(405);caso("GET".equals(a.h.headers.get("Allow")));}
            for(String extra:new String[]{"idUsuarioProceso","rol","ipOrigen","otro"}){a=new Api(op,"ADMINISTRADOR");a.p(extra,"7");a.ejecutar(400);caso(a.datos.consultas==0);}
            for(int code:new int[]{99999,1205,1222,76900}){a=new Api(op,"ADMINISTRADOR");final int error=code;a.servicio=new ConsultasAdministrativasServicio(){@Override public Object consultar(OperacionConsultaAdministrativa o,int actor,String rol,Map<String,String[]> p)throws SQLException{throw new SQLException("SECRETO","TEST",error);}};a.ejecutar(code==99999?500:503);}
            caso(FiltroCsrf.ambito(op.ruta)==null);
            if(op!=OperacionConsultaAdministrativa.PAISES){
                for(String value:new String[]{"0","-1","1.5","texto","2147483648","1 OR 1=1"}){a=new Api(op,"ADMINISTRADOR");a.p("pagina",value);a.ejecutar(400);}
                a=new Api(op,"ADMINISTRADOR");a.p("pagina","1","2");a.ejecutar(400);
                a=new Api(op,"ADMINISTRADOR");a.p("tamanoPagina","101");a.ejecutar(400);
                a=new Api(op,"ADMINISTRADOR");a.p("pagina","2147483647");a.p("tamanoPagina","100");a.ejecutar(400);
            }
        }
        Api a=new Api(OperacionConsultaAdministrativa.USUARIOS,"AUDITOR");a.p("buscar","  José O'Neil %_[]!  ");a.p("pagina","2");a.p("tamanoPagina","25");a.ejecutar(200);caso(a.datos.buscar.equals("José O'Neil %_[]!")&&a.datos.pagina==2&&a.datos.tamano==25);
        a=new Api(OperacionConsultaAdministrativa.USUARIOS,"ADMINISTRADOR");a.p("buscar","x".repeat(151));a.ejecutar(400);
        a=new Api(OperacionConsultaAdministrativa.EVENTOS,"CAJERO");a.p("idDeporte","1");a.p("estado","CANCELADO");a.ejecutar(200);caso(a.datos.deporte==1&&a.datos.estado.equals("CANCELADO"));
        a=new Api(OperacionConsultaAdministrativa.EVENTOS,"ADMINISTRADOR");a.p("estado","LIQUIDADO");a.ejecutar(400);
        System.out.println("Cierre administrativo: "+casos+" comprobaciones, 0 fallos; sin SQL.");
    }
}
