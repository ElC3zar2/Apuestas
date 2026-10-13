package com.apuestas.controlador;

import com.apuestas.modelo.*;
import com.apuestas.servicio.*;
import com.apuestas.dao.*;
import com.fasterxml.jackson.databind.JsonNode;
import java.sql.*;
import java.util.*;
import java.math.BigDecimal;
import java.io.*;
import java.lang.reflect.*;
import javax.servlet.http.*;
import static com.apuestas.controlador.PruebaModalidadesApuesta.*;

/** Consultas posteriores con fixtures SQL/HTTP; no utiliza servicios externos. */
public class PruebaConsultasUsuario {
    static int casos;
    static void caso(String nombre,Accion accion)throws Exception {
        try {accion.run();casos++;}catch(Exception|AssertionError e){throw new AssertionError(nombre,e);}
    }
    static class JdbcBoleto extends PruebaModalidadesApuesta.Jdbc {
        @Override protected Connection obtenerConexion() {
            llamadas++;
            return proxy(Connection.class,(p,m,a)->{
                if(m.getName().equals("close")){conexionCerrada=true;return null;}
                if(!m.getName().equals("prepareCall"))throw new AssertionError("Solo SP de consulta");
                sql=(String)a[0];exigir(sql.equals("{call dbo.sp_ObtenerBoleto(?, ?, ?)}"));
                return proxy(CallableStatement.class,(q,n,b)->{
                    switch(n.getName()) {
                        case "setInt":case "setString":parametros.put((Integer)b[0],b[1]);return null;
                        case "setNull":parametros.put((Integer)b[0],null);tiposNull.put((Integer)b[0],(Integer)b[1]);return null;
                        case "execute":if(error!=0)throw new SQLException("PRIVADO","TEST",error);return !tablas.isEmpty();
                        case "getMoreResults":return ++indice<tablas.size();
                        case "getUpdateCount":return -1;
                        case "getResultSet":return rs(tablas.get(indice));
                        case "close":statementCerrado=true;return null;
                        default:throw new AssertionError("Sin escrituras ni transacciones Java");
                    }
                });
            });
        }
    }
    static JdbcBoleto boleto(String modalidad,boolean compuesto,String clasificacion) {
        JdbcBoleto j=new JdbcBoleto();
        Map<String,Object> h=fila("IdBoleto",70,"CodigoBoleto","B-70","IdUsuario",7,"Correo","usuario@example.invalid",
            "TipoBoleto",compuesto?"COMPUESTO":"SIMPLE","MontoApostado",decimal("100.00"),"ComisionServicio",decimal("5.00"),
            "TotalCargo",decimal("105.00"),"CuotaTotal",decimal("5.0000"),"GananciaPotencial",decimal("500.00"),
            "Resultado","PENDIENTE","EstadoBoleto","PENDIENTE","FechaCreacion",Timestamp.valueOf("2026-10-01 12:00:00"),
            "FechaLiquidacion",null,"ReferenciaOperacion",REF.toString(),"IdBilleteraCasaReserva",8,
            "ReservaCasaInicial",decimal("400.00"),"ReservaCasaPendiente",decimal("400.00"));
        j.tablas.add(new Tabla(h));
        Map<String,Object> d=fila("IdDetalle",1,"IdEvento",8,"Evento","Nombre actual","IdMercado",11,"Mercado","Mercado actual",
            "IdSeleccion",13,"Seleccion","Seleccion actual","CuotaAplicada",decimal("5.0000"),"Resultado","PENDIENTE","MontoLiquidado",null);
        d.putAll(DatosPruebaConsultasUsuario.modalidad(modalidad,clasificacion));
        Tabla detalles=new Tabla(d);if(compuesto){Map<String,Object> segundo=new LinkedHashMap<>(d);segundo.put("IdDetalle",2);segundo.put("IdSeleccion",14);detalles.filas.add(segundo);}
        j.tablas.add(detalles);return j;
    }
    static Boleto leer(JdbcBoleto j)throws Exception {
        try{return new ApuestaServicio(j).obtenerBoletoPorId(7,70);}finally{j.cerrado();}
    }
    static void rechazarBoleto(JdbcBoleto j)throws Exception {
        try{leer(j);throw new AssertionError("Debio rechazar contrato");}catch(SQLException esperado){exigir(!esperado.getMessage().contains("usuario@example"));}
    }
    static void rolBilletera(boolean movimientos)throws Exception {
        HttpSession sesion=proxy(HttpSession.class,(p,m,a)->a[0].equals("idUsuario")?7:"CASA");
        HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)->{
            if(m.getName().equals("getSession"))return sesion;
            if(m.getName().equals("getParameter"))return null;
            throw new AssertionError(m.getName());
        });
        int[] estado={200};StringWriter cuerpo=new StringWriter();
        HttpServletResponse resp=proxy(HttpServletResponse.class,(p,m,a)->{
            if(m.getName().equals("setContentType") || m.getName().equals("setHeader"))return null;
            if(m.getName().equals("setStatus")){estado[0]=(Integer)a[0];return null;}
            if(m.getName().equals("getWriter"))return new PrintWriter(cuerpo);
            throw new AssertionError(m.getName());
        });
        HttpServlet servlet=movimientos?new MovimientosBilleteraServlet():new BilleteraResumenServlet();
        Field campo=servlet.getClass().getDeclaredField("billeteraServicio");campo.setAccessible(true);
        campo.set(servlet,new BilleteraServicio(){
            @Override public BilleteraUsuario obtenerBilletera(int id){throw new AssertionError("Rol incorrecto alcanzo servicio");}
            @Override public List<MovimientoBilletera> obtenerMovimientosBilletera(int id,java.time.LocalDateTime desde,java.time.LocalDateTime hasta,int cantidad){throw new AssertionError("Rol incorrecto alcanzo servicio");}
        });
        if(movimientos)((MovimientosBilleteraServlet)servlet).doGet(req,resp);else((BilleteraResumenServlet)servlet).doGet(req,resp);
        exigir(estado[0]==403 && cuerpo.toString().contains("\"ok\":false"));
    }
    public static void main(String[] args)throws Exception {
        casos=0;
        if(args.length>0 && args[0].equals("rol")){rolBilletera(false);rolBilletera(true);return;}
        for(String modalidad:Arrays.asList("CONVENCIONAL","MARCADOR_FINAL","PRIMERA_ANOTACION")) {
            caso("boleto " + modalidad,()->{
                JdbcBoleto j=boleto(modalidad,false,null);Boleto b=leer(j);DetalleBoleto d=b.getDetalles().get(0);
                exigir(d.getTipoMercadoAplicado().equals(modalidad) && d.getNombreEventoAplicado().equals("Evento congelado") && d.getCuotaAplicada().compareTo(decimal("5"))==0);
                exigir(b.getReservaCasaPendiente().compareTo(decimal("400"))==0 && d.getMontoLiquidado()==null);
                exigir(d.getPronosticoA()==null || d.getPronosticoA()==0);
            });
            caso("historial " + modalidad,()->{
                PruebaHistorialBoletosUsuario.Jdbc j=new PruebaHistorialBoletosUsuario.Jdbc();j.modalidad=modalidad;
                JsonNode n=PruebaHistorialBoletosUsuario.ejecutar(new PruebaHistorialBoletosUsuario.Entrada(),j,200).json;
                exigir(n.path("boletos").get(0).path("detalles").get(0).path("tipoMercadoAplicado").asText().equals(modalidad));
                exigir(n.path("modalidades").get(0).path("cantidadDetalles").asLong()==8);
            });
        }
        caso("compuesto convencional consultable",()->exigir(leer(boleto("CONVENCIONAL",true,null)).getDetalles().size()==2));
        for(String clasificacion:Arrays.asList("EXACTO","RESULTADO","NO_ACIERTO","ANULADO","PRIMERA_ANOTACION")) {
            caso("clasificacion boleto " + clasificacion,()->{
                JdbcBoleto j=boleto("MARCADOR_FINAL",false,clasificacion);j.tablas.get(1).filas.get(0).put("MontoLiquidado",decimal("250.00"));
                DetalleBoleto d=leer(j).getDetalles().get(0);exigir(d.getClasificacionAcierto().equals(clasificacion) && d.getMontoLiquidado().compareTo(decimal("250"))==0);
            });
            caso("clasificacion historial " + clasificacion,()->{
                PruebaHistorialBoletosUsuario.Jdbc j=new PruebaHistorialBoletosUsuario.Jdbc();j.modalidad="MARCADOR_FINAL";j.clasificacion=clasificacion;
                JsonNode n=PruebaHistorialBoletosUsuario.ejecutar(new PruebaHistorialBoletosUsuario.Entrada(),j,200).json;
                exigir(n.path("boletos").get(0).path("detalles").get(0).path("clasificacionAcierto").asText().equals(clasificacion));
            });
        }
        caso("NULL nombres congelados",()->{JdbcBoleto j=boleto("CONVENCIONAL",false,null);Map<String,Object> f=j.tablas.get(1).filas.get(0);for(String c:new ArrayList<>(f.keySet()))if(c.startsWith("Nombre"))f.put(c,null);exigir(leer(j).getDetalles().get(0).getNombreSeleccionAplicada()==null);});
        caso("tipo JDBC incompatible boleto",()->{JdbcBoleto j=boleto("MARCADOR_FINAL",false,null);j.tablas.get(1).filas.get(0).put("PronosticoA",decimal("1.5"));rechazarBoleto(j);});
        caso("reserva tipo JDBC incompatible",()->{JdbcBoleto j=boleto("CONVENCIONAL",false,null);j.tablas.get(0).filas.get(0).put("ReservaCasaPendiente","400");rechazarBoleto(j);});
        caso("RS boleto faltante",()->{JdbcBoleto j=boleto("CONVENCIONAL",false,null);j.tablas.remove(1);rechazarBoleto(j);});
        caso("RS boleto adicional",()->{JdbcBoleto j=boleto("CONVENCIONAL",false,null);j.tablas.add(j.tablas.get(1));rechazarBoleto(j);});
        caso("boleto inexistente SQL oficial",()->{JdbcBoleto j=boleto("CONVENCIONAL",false,null);j.error=60049;rechazarBoleto(j);});
        for(int rs:new int[]{2,3})caso("RS historial obligatorio " + rs,()->{PruebaHistorialBoletosUsuario.Jdbc j=new PruebaHistorialBoletosUsuario.Jdbc();j.omitirRS=rs;PruebaHistorialBoletosUsuario.ejecutar(new PruebaHistorialBoletosUsuario.Entrada(),j,500);});
        caso("RS4 asociacion ajena",()->{PruebaHistorialBoletosUsuario.Jdbc j=new PruebaHistorialBoletosUsuario.Jdbc();j.detalleHistoricoAjeno=true;PruebaHistorialBoletosUsuario.ejecutar(new PruebaHistorialBoletosUsuario.Entrada(),j,500);});
        caso("COUNT_BIG tipo incompatible historial",()->{PruebaHistorialBoletosUsuario.Jdbc j=new PruebaHistorialBoletosUsuario.Jdbc();j.tipoMetricaInvalido=true;PruebaHistorialBoletosUsuario.ejecutar(new PruebaHistorialBoletosUsuario.Entrada(),j,500);});
        for(boolean deportes:new boolean[]{false,true}) {
            caso("metricas globales resumen " + deportes,()->{PruebaResumenAnaliticaUsuario.Jdbc j=new PruebaResumenAnaliticaUsuario.Jdbc(deportes);JsonNode n=PruebaResumenAnaliticaUsuario.ejecutar(new PruebaResumenAnaliticaUsuario.Entrada(),j,200).json;exigir(n.path("modalidades").get(0).path("cantidadDetalles").asLong()==8);});
            caso("RS2 resumen obligatorio " + deportes,()->{PruebaResumenAnaliticaUsuario.Jdbc j=new PruebaResumenAnaliticaUsuario.Jdbc(deportes);j.faltaModalidades=true;PruebaResumenAnaliticaUsuario.ejecutar(new PruebaResumenAnaliticaUsuario.Entrada(),j,500);});
            caso("COUNT_BIG resumen incompatible " + deportes,()->{PruebaResumenAnaliticaUsuario.Jdbc j=new PruebaResumenAnaliticaUsuario.Jdbc(deportes);j.tipoModalidadInvalido=true;PruebaResumenAnaliticaUsuario.ejecutar(new PruebaResumenAnaliticaUsuario.Entrada(),j,500);});
            caso("rol billetera " + deportes,()->rolBilletera(deportes));
        }
        for(Class<?> tipo:Arrays.asList(HistorialBoletosUsuarioServlet.class,ResumenGeneralUsuarioServlet.class,ResumenUsuarioPorDeporteServlet.class,BilleteraResumenServlet.class,MovimientosBilleteraServlet.class)) {
            caso("metodo HTTP JSON " + tipo.getSimpleName(),()->{
                HttpServletRequest req=proxy(HttpServletRequest.class,(p,m,a)->{if(m.getName().equals("getMethod"))return "POST";throw new AssertionError("Sin sesion ni SQL para metodo invalido");});
                int[] estado={200};String[] content={null},allow={null};StringWriter cuerpo=new StringWriter();
                HttpServletResponse resp=proxy(HttpServletResponse.class,(p,m,a)->{
                    if(m.getName().equals("setContentType")){content[0]=(String)a[0];return null;}
                    if(m.getName().equals("setHeader")){if(a[0].equals("Allow"))allow[0]=(String)a[1];return null;}
                    if(m.getName().equals("setStatus")){estado[0]=(Integer)a[0];return null;}
                    if(m.getName().equals("getWriter"))return new PrintWriter(cuerpo);
                    throw new AssertionError(m.getName());
                });
                HttpServlet servlet=(HttpServlet)tipo.getDeclaredConstructor().newInstance();
                Method metodo=tipo.getDeclaredMethod("service",HttpServletRequest.class,HttpServletResponse.class);metodo.setAccessible(true);metodo.invoke(servlet,req,resp);
                exigir(estado[0]==405 && "GET".equals(allow[0]) && "application/json;charset=UTF-8".equals(content[0]));
                exigir(!new com.fasterxml.jackson.databind.ObjectMapper().readTree(cuerpo.toString()).path("ok").asBoolean());
            });
        }
        System.out.println("OK: " + casos + " casos controlados de consultas/modos, 0 fallos.");
    }
}
