package com.apuestas.controlador;

import com.apuestas.dao.BilleteraDAO;
import com.apuestas.servicio.BilleteraServicio;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.*;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.sql.*;
import java.time.LocalDateTime;
import java.util.*;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

/** Pruebas main de ambas rutas con JDBC controlado. No abre conexiones reales. */
public class PruebaBilleteraUsuario {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static int casos;
    private static void exigir(boolean valor, String mensaje) {
        if (!valor) throw new AssertionError(mensaje);
    }

    private static class Jdbc extends BilleteraDAO {
        final Map<String,Object> fila = new LinkedHashMap<>();
        final Map<Integer,Object> parametros = new HashMap<>();
        final Map<Integer,Integer> tiposNull = new HashMap<>();
        final Set<String> leidas = new HashSet<>();
        final Set<String> cerrados = new HashSet<>();
        List<Map<String,Object>> orden;
        int filas = 1, posicion, conexiones, cierres, codigo;
        boolean nulo, sinResultado, extra, errorTardio;
        String sql;

        Jdbc(boolean movimientos) {
            if (movimientos) {
            fila.put("IdMovimiento", 3000000000L);
            fila.put("FechaMovimiento", Timestamp.valueOf("2026-09-28 10:20:30"));
            fila.put("IdTransaccion", 3000000000L);
            fila.put("ReferenciaOperacion", "a57b2bc0-3627-4caa-a07d-dce70f7f1f38");
            fila.put("Monto", new BigDecimal("123.45"));
            fila.put("FechaSolicitud", Timestamp.valueOf("2026-09-28 10:20:30"));
            fila.put("FechaProcesamiento", null);
            fila.put("Descripcion", null);
            fila.put("TipoTransaccion", "Texto áñ");
            fila.put("NombreTipoTransaccion", "Texto áñ");
            fila.put("EstadoTransaccion", "Texto áñ");
            fila.put("IdBoleto", null);
            fila.put("SaldoDisponibleAnterior", new BigDecimal("123.45"));
            fila.put("SaldoDisponiblePosterior", new BigDecimal("123.45"));
            fila.put("VariacionSaldoDisponible", new BigDecimal("123.45"));
            fila.put("SaldoComprometidoAnterior", new BigDecimal("123.45"));
            fila.put("SaldoComprometidoPosterior", new BigDecimal("123.45"));
            fila.put("VariacionSaldoComprometido", new BigDecimal("123.45"));
            fila.put("IdUsuarioProceso", null);
            fila.put("UsuarioProceso", null);
            } else {
            fila.put("IdUsuario", 7);
            fila.put("Correo", "Texto áñ");
            fila.put("Rol", "Texto áñ");
            fila.put("EstadoUsuario", "Texto áñ");
            fila.put("IdBilletera", 3);
            fila.put("SaldoDisponible", new BigDecimal("123.45"));
            fila.put("SaldoComprometido", new BigDecimal("123.45"));
            fila.put("SaldoVirtualTotal", new BigDecimal("123.45"));
            fila.put("FechaCreacion", Timestamp.valueOf("2026-09-28 10:20:30"));
            }
        }

        @Override protected Connection obtenerConexion() {
            conexiones++;
            ResultSet rs = (ResultSet) Proxy.newProxyInstance(getClass().getClassLoader(),
                    new Class<?>[]{ResultSet.class}, (p,m,a) -> {
                        switch(m.getName()) {
                            case "next": return ++posicion <= (orden == null ? filas : orden.size());
                            case "close": exigir(cerrados.add("ResultSet"),"Cierre duplicado RS"); cierres++; return null;
                            case "wasNull": return nulo;
                            case "getInt": case "getLong": case "getString":
                            case "getBigDecimal": case "getTimestamp":
                                String columna = (String)a[0];
                                Map<String,Object> actual = orden == null ? fila : orden.get(posicion - 1);
                                if (!actual.containsKey(columna)) throw new SQLException("PRIVADO columna ausente");
                                leidas.add(columna);
                                Object valor = actual.get(columna);
                                nulo = valor == null;
                                if (valor != null) return valor;
                                if ("getInt".equals(m.getName())) return Integer.valueOf(0);
                                if ("getLong".equals(m.getName())) return Long.valueOf(0);
                                return null;
                            default: throw new AssertionError("ResultSet: " + m.getName());
                        }
                    });
            CallableStatement cs = (CallableStatement) Proxy.newProxyInstance(
                    getClass().getClassLoader(),new Class<?>[]{CallableStatement.class},(p,m,a) -> {
                        switch(m.getName()) {
                            case "setInt": case "setTimestamp":
                                parametros.put((Integer)a[0],a[1]); return null;
                            case "setNull":
                                parametros.put((Integer)a[0],null);
                                tiposNull.put((Integer)a[0],(Integer)a[1]); return null;
                            case "execute":
                                if(codigo != 0) throw new SQLException("PRIVADO password SELECT", "TEST",codigo);
                                return !sinResultado;
                            case "getResultSet": return rs;
                            case "getMoreResults":
                                if(errorTardio) throw new SQLException("PRIVADO error tardio");
                                return extra;
                            case "getUpdateCount": return -1;
                            case "close": exigir(cerrados.add("CallableStatement"),"Cierre duplicado CS"); cierres++; return null;
                            default: throw new AssertionError("Statement: " + m.getName());
                        }
                    });
            return (Connection) Proxy.newProxyInstance(getClass().getClassLoader(),
                    new Class<?>[]{Connection.class},(p,m,a) -> {
                        if("prepareCall".equals(m.getName())) { sql=(String)a[0]; return cs; }
                        if("close".equals(m.getName())) { exigir(cerrados.add("Connection"),"Cierre duplicado conexion"); cierres++; return null; }
                        throw new AssertionError("Connection: " + m.getName());
                    });
        }
    }

    private static class Entrada {
        boolean sesion = true, expirada;
        Object idUsuario = 7;
        String desde, hasta, cantidad;
    }
    private static class Salida {
        int estado = 200, sesiones;
        String tipo;
        final Map<String,String> headers = new HashMap<>();
        final StringWriter body = new StringWriter();
        JsonNode json;
    }

    private static Salida ejecutar(boolean movimientos, Entrada e, Jdbc d) throws Exception {
        HttpServlet servlet = movimientos ? new MovimientosBilleteraServlet() : new BilleteraResumenServlet();
        servlet.init();
        Field campo=servlet.getClass().getDeclaredField("billeteraServicio");
        campo.setAccessible(true);
        campo.set(servlet,new BilleteraServicio(d));
        Salida s=new Salida();
        HttpSession sesion=(HttpSession)Proxy.newProxyInstance(
                PruebaBilleteraUsuario.class.getClassLoader(),new Class<?>[]{HttpSession.class},(p,m,a)->{
                    exigir("getAttribute".equals(m.getName()),"No escribir ni invalidar sesion");
                    exigir("idUsuario".equals(a[0]),"Solo identidad de sesion");
                    if(e.expirada) throw new IllegalStateException("Expirada");
                    return e.idUsuario;
                });
        HttpServletRequest req=(HttpServletRequest)Proxy.newProxyInstance(
                PruebaBilleteraUsuario.class.getClassLoader(),new Class<?>[]{HttpServletRequest.class},(p,m,a)->{
                    if("getSession".equals(m.getName())) {
                        exigir(a != null && a.length==1 && Boolean.FALSE.equals(a[0]),"No crear sesion");
                        s.sesiones++;
                        return e.sesion ? sesion : null;
                    }
                    if("getParameter".equals(m.getName())) {
                        exigir(movimientos,"Resumen no lee parametros");
                        switch((String)a[0]) {
                            case "fechaDesde": return e.desde;
                            case "fechaHasta": return e.hasta;
                            case "cantidad": return e.cantidad;
                            default: throw new AssertionError("Nunca leer identidad enviada por navegador");
                        }
                    }
                    throw new AssertionError("Request: "+m.getName());
                });
        HttpServletResponse resp=(HttpServletResponse)Proxy.newProxyInstance(
                PruebaBilleteraUsuario.class.getClassLoader(),new Class<?>[]{HttpServletResponse.class},(p,m,a)->{
                    switch(m.getName()) {
                        case "setContentType": s.tipo=(String)a[0]; return null;
                        case "setHeader": s.headers.put((String)a[0],(String)a[1]); return null;
                        case "setStatus": s.estado=(Integer)a[0]; return null;
                        case "getWriter": return new PrintWriter(s.body);
                        default: throw new AssertionError("Response: "+m.getName());
                    }
                });
        if(movimientos) ((MovimientosBilleteraServlet)servlet).doGet(req,resp);
        else ((BilleteraResumenServlet)servlet).doGet(req,resp);
        exigir(s.sesiones==1,"Sesion solo consultada una vez");
        exigir("application/json;charset=UTF-8".equals(s.tipo),"Content-Type");
        exigir("no-store".equals(s.headers.get("Cache-Control")),"Cache-Control");
        if (d.conexiones > 0) {
            Set<String> esperados = new HashSet<>(Arrays.asList("Connection","CallableStatement"));
            if (d.codigo == 0 && !d.sinResultado) esperados.add("ResultSet");
            exigir(d.cerrados.equals(esperados), "Cerrar cada recurso JDBC aun en errores");
        }
        s.json=JSON.readTree(s.body.toString());
        exigir(s.json.path("ok").asBoolean()==(s.estado==200),"ok");
        exigir(!s.body.toString().contains("PRIVADO") && !s.body.toString().contains("password"),
                "No exponer errores internos");
        casos++;
        return s;
    }

    private static void rechazo(boolean movimientos, Entrada e, int estado) throws Exception {
        Jdbc d=new Jdbc(movimientos);
        exigir(ejecutar(movimientos,e,d).estado==estado,"Estado de rechazo "+estado);
        exigir(d.conexiones==0,"Validacion antes de SQL");
    }

    public static void main(String[] args) throws Exception {
        exigir(Arrays.equals(BilleteraResumenServlet.class.getAnnotation(WebServlet.class).value(),
                new String[]{"/usuario/billetera/resumen"}),"Mapping resumen");
        exigir(Arrays.equals(MovimientosBilleteraServlet.class.getAnnotation(WebServlet.class).value(),
                new String[]{"/usuario/billetera/movimientos"}),"Mapping movimientos");
        for(boolean mov:new boolean[]{false,true}) {
            Entrada e=new Entrada(); e.sesion=false; rechazo(mov,e,401);
            for(Object id:new Object[]{null,0,-1,"","abc","7.5",4294967303L,
                    new BigDecimal("7.5"),Double.NaN,true}) {
                e=new Entrada(); e.idUsuario=id; rechazo(mov,e,401);
            }
            e=new Entrada(); e.expirada=true; rechazo(mov,e,401);
            for(Object id:new Object[]{7,7L," 7 ",new BigDecimal("7.0")}) {
                e=new Entrada(); e.idUsuario=id;
                Jdbc d=new Jdbc(mov);
                Salida s=ejecutar(mov,e,d);
                exigir(s.estado==200 && d.parametros.get(1).equals(7),"Usuario de sesion");
                exigir(d.leidas.equals(d.fila.keySet()) && d.cierres==3,"Leer todas las columnas y cerrar");
                if(mov) {
                    exigir("{call dbo.sp_ObtenerMovimientosBilletera(?, ?, ?, ?)}".equals(d.sql),"SP movimientos");
                    exigir(d.parametros.get(4).equals(100),"Cantidad default");
                    exigir(d.tiposNull.get(2).equals(Types.TIMESTAMP)
                            && d.tiposNull.get(3).equals(Types.TIMESTAMP),"Fechas nullable JDBC");
                    JsonNode item=s.json.path("movimientos").get(0);
                    exigir(item.size()==20 && s.json.path("cantidad").asInt()==1,"Esquema completo");
                    exigir(item.path("idMovimiento").asLong()==3000000000L
                            && item.path("idTransaccion").asLong()==3000000000L,"BIGINT sin truncamiento");
                    for(String n:new String[]{"fechaProcesamiento","descripcion","idBoleto","idUsuarioProceso","usuarioProceso"})
                        exigir(item.path(n).isNull(),"Nullable JSON "+n);
                    for(String n:new String[]{"monto","saldoDisponibleAnterior","saldoDisponiblePosterior",
                            "variacionSaldoDisponible","saldoComprometidoAnterior","saldoComprometidoPosterior",
                            "variacionSaldoComprometido"})
                        exigir(item.path(n).isNumber() && item.path(n).decimalValue()
                                .compareTo(new BigDecimal("123.45"))==0,"Decimal "+n);
                    exigir(item.path("fechaMovimiento").asText().equals("2026-09-28T10:20:30")
                            && item.path("fechaSolicitud").asText().equals("2026-09-28T10:20:30"),"Fechas ISO");
                } else {
                    exigir("{call dbo.sp_ObtenerBilleteraUsuario(?)}".equals(d.sql),"SP resumen");
                    exigir(s.json.size()==10 && s.json.path("idUsuario").asInt()==7,"Esquema resumen");
                    for(String n:new String[]{"saldoDisponible","saldoComprometido","saldoVirtualTotal"})
                        exigir(s.json.path(n).isNumber() && s.json.path(n).decimalValue()
                                .compareTo(new BigDecimal("123.45"))==0,"Decimal "+n);
                    exigir(s.json.path("fechaCreacion").asText().equals("2026-09-28T10:20:30"),"Fecha ISO");
                }
            }
            for(int codigo: mov ? new int[]{58004,58005,58006,58007,58008,58001,99999}
                    :new int[]{58001,58002,58003,58004,99999}) {
                Jdbc d=new Jdbc(mov); d.codigo=codigo;
                int esperado=500;
                if(mov) {
                    if(codigo>=58004 && codigo<=58006) esperado=400;
                    if(codigo==58007) esperado=401;
                    if(codigo==58008) esperado=404;
                } else {
                    if(codigo==58001) esperado=400;
                    if(codigo==58002) esperado=401;
                    if(codigo==58003) esperado=404;
                }
                Salida s=ejecutar(mov,new Entrada(),d);
                exigir(s.estado==esperado && d.cierres==2,"SQL "+codigo);
                if(esperado==500) exigir(s.json.path("mensaje").asText()
                        .equals("No fue posible consultar la billetera."),"500 generico");
            }
            for(String col:new ArrayList<>(new Jdbc(mov).fila.keySet())) {
                Jdbc d=new Jdbc(mov); d.fila.remove(col);
                exigir(ejecutar(mov,new Entrada(),d).estado==500 && d.cierres==3,"Falta columna "+col);
                d=new Jdbc(mov);
                if(d.fila.get(col)!=null) {
                    d.fila.put(col,null);
                    exigir(ejecutar(mov,new Entrada(),d).estado==500,"Nulo obligatorio "+col);
                }
            }
            Jdbc d=new Jdbc(mov); d.filas=2;
            exigir(ejecutar(mov,new Entrada(),d).estado==500,"Duplicados");
            d=new Jdbc(mov); d.sinResultado=true;
            exigir(ejecutar(mov,new Entrada(),d).estado==500 && d.cierres==2,"Sin resultado");
            d=new Jdbc(mov); d.extra=true;
            exigir(ejecutar(mov,new Entrada(),d).estado==500,"Resultado adicional");
            d=new Jdbc(mov); d.errorTardio=true;
            exigir(ejecutar(mov,new Entrada(),d).estado==500,"Error tardio");
        }

        Jdbc d=new Jdbc(false); d.fila.put("IdUsuario",8);
        exigir(ejecutar(false,new Entrada(),d).estado==500,"Nunca devolver billetera ajena");
        d=new Jdbc(false); d.filas=0;
        exigir(ejecutar(false,new Entrada(),d).estado==500,"Resumen ausente");
        d=new Jdbc(true); d.filas=0;
        Salida vacio=ejecutar(true,new Entrada(),d);
        exigir(vacio.estado==200 && vacio.json.path("cantidad").asInt()==0
                && vacio.json.path("movimientos").isArray() && vacio.json.path("movimientos").size()==0,"Lista vacia");

        for(String cantidad:new String[]{"0","501","abc","", "2147483648"}) {
            Entrada e=new Entrada(); e.cantidad=cantidad; rechazo(true,e,400);
        }
        for(String cantidad:new String[]{"1","500"}) {
            Entrada e=new Entrada(); e.cantidad=cantidad; d=new Jdbc(true);
            exigir(ejecutar(true,e,d).estado==200 && d.parametros.get(4).equals(Integer.valueOf(cantidad)),"Limites");
        }
        for(String fecha:new String[]{"2026-02-30T12:00:00","abc","2026-09-28","2026-09-28T10:20",
                "2026-09-28T10:20:30Z","2026-09-28T10:20:30.1","0000-01-01T00:00:00",""}) {
            Entrada e=new Entrada(); e.desde=fecha; rechazo(true,e,400);
            e=new Entrada(); e.hasta=fecha; rechazo(true,e,400);
        }
        Entrada e=new Entrada(); e.desde="2026-09-28T10:20:31"; e.hasta="2026-09-28T10:20:30";
        rechazo(true,e,400);
        e=new Entrada(); e.desde="2026-09-28T10:20:30"; e.hasta=e.desde; d=new Jdbc(true);
        exigir(ejecutar(true,e,d).estado==200
                && d.parametros.get(2).equals(Timestamp.valueOf("2026-09-28 10:20:30"))
                && d.parametros.get(3).equals(d.parametros.get(2)),"Rango inclusivo y parametros");
        d=new Jdbc(true);
        StringBuilder texto=new StringBuilder("ñ\"\\");
        for(int i=0;i<32;i++) texto.append((char)i);
        d.fila.put("Descripcion",texto.toString());
        d.fila.put("FechaProcesamiento",Timestamp.valueOf("2026-09-28 11:00:00"));
        d.fila.put("IdBoleto",45); d.fila.put("IdUsuarioProceso",8); d.fila.put("UsuarioProceso","operador@example.test");
        JsonNode item=ejecutar(true,new Entrada(),d).json.path("movimientos").get(0);
        exigir(item.path("descripcion").asText().equals(texto.toString())
                && item.path("idBoleto").asInt()==45 && item.path("idUsuarioProceso").asInt()==8
                && item.path("fechaProcesamiento").asText().equals("2026-09-28T11:00:00"),"Campos opcionales presentes");

        for(int id:new int[]{0,-1}) {
            d=new Jdbc(false);
            try { new BilleteraServicio(d).obtenerBilletera(id); throw new AssertionError("Usuario invalido"); }
            catch(IllegalArgumentException esperado) { exigir(d.conexiones==0,"Servicio valida usuario"); }
            casos++;
            try { new BilleteraServicio(d).obtenerMovimientosBilletera(id,null,null,100); throw new AssertionError("Usuario invalido"); }
            catch(IllegalArgumentException esperado) { exigir(d.conexiones==0,"Servicio valida usuario"); }
            casos++;
        }
        casosAdicionales();
        System.out.println("OK: "+casos+" casos de billetera; sin SQL real.");
    }

    private static void verificarColumnas(Map<String,Object> fila, JsonNode json) {
        for (Map.Entry<String,Object> columna : fila.entrySet()) {
            String nombre = Character.toLowerCase(columna.getKey().charAt(0))
                    + columna.getKey().substring(1);
            exigir(json.has(nombre), "Campo JSON faltante: " + nombre);
            JsonNode valor = json.get(nombre);
            Object esperado = columna.getValue();
            if (esperado == null) {
                exigir(valor.isNull(), "NULL: " + nombre);
            } else if (esperado instanceof BigDecimal) {
                exigir(valor.isNumber() && valor.decimalValue().compareTo((BigDecimal) esperado) == 0,
                        "Valor decimal: " + nombre);
            } else if (esperado instanceof Number) {
                exigir(valor.isIntegralNumber() && valor.asLong() == ((Number) esperado).longValue(),
                        "Valor entero: " + nombre);
            } else if (esperado instanceof Timestamp) {
                exigir(valor.isTextual() && LocalDateTime.parse(valor.asText())
                        .equals(((Timestamp) esperado).toLocalDateTime()), "Fecha: " + nombre);
            } else {
                exigir(valor.isTextual() && valor.asText().equals(esperado), "Texto: " + nombre);
            }
        }
    }

    private static void casosAdicionales() throws Exception {
        Jdbc d = new Jdbc(false);
        d.fila.put("Correo", "cliente@example.test");
        d.fila.put("Rol", "USUARIO");
        d.fila.put("EstadoUsuario", "PENDIENTE");
        d.fila.put("SaldoDisponible", new BigDecimal("100.01"));
        d.fila.put("SaldoComprometido", new BigDecimal("20.02"));
        d.fila.put("SaldoVirtualTotal", new BigDecimal("120.03"));
        d.fila.put("FechaCreacion", Timestamp.valueOf("2026-09-28 10:20:30.1234567"));
        verificarColumnas(d.fila, ejecutar(false, new Entrada(), d).json);

        d = new Jdbc(true);
        d.fila.put("IdTransaccion", 4000000001L);
        d.fila.put("TipoTransaccion", "APUESTA");
        d.fila.put("NombreTipoTransaccion", "Confirmacion de apuesta");
        d.fila.put("EstadoTransaccion", "COMPLETADA");
        d.fila.put("Descripcion", "Descripcion diferente");
        d.fila.put("IdBoleto", 55);
        d.fila.put("IdUsuarioProceso", 12);
        d.fila.put("UsuarioProceso", "proceso@example.test");
        d.fila.put("Monto", new BigDecimal("20.01"));
        d.fila.put("SaldoDisponibleAnterior", new BigDecimal("100.00"));
        d.fila.put("SaldoDisponiblePosterior", new BigDecimal("79.99"));
        d.fila.put("VariacionSaldoDisponible", new BigDecimal("-20.01"));
        d.fila.put("SaldoComprometidoAnterior", new BigDecimal("5.00"));
        d.fila.put("SaldoComprometidoPosterior", new BigDecimal("25.01"));
        d.fila.put("VariacionSaldoComprometido", new BigDecimal("20.01"));
        d.fila.put("FechaSolicitud", Timestamp.valueOf("2026-09-28 09:00:01"));
        d.fila.put("FechaProcesamiento", Timestamp.valueOf("2026-09-28 10:00:02.1234567"));
        verificarColumnas(d.fila, ejecutar(true, new Entrada(), d).json.path("movimientos").get(0));

        // Preservar el orden del ResultSet, sin reordenar por transaccion u otro campo.
        d = new Jdbc(true);
        d.orden = new ArrayList<>();
        for (int i = 0; i < 3; i++) {
            Map<String,Object> fila = new LinkedHashMap<>(d.fila);
            fila.put("IdMovimiento", 3000000003L - i);
            fila.put("IdTransaccion", 4000000001L + i);
            fila.put("FechaMovimiento", Timestamp.valueOf(
                    i < 2 ? "2026-09-28 12:00:00" : "2026-09-27 12:00:00"));
            d.orden.add(fila);
        }
        Salida orden = ejecutar(true, new Entrada(), d);
        exigir(orden.estado == 200 && orden.json.path("cantidad").asInt() == 3, "Historial multiple");
        for (int i = 0; i < 3; i++) {
            verificarColumnas(d.orden.get(i), orden.json.path("movimientos").get(i));
        }

        for (boolean soloDesde : new boolean[]{true,false}) {
            Entrada e = new Entrada();
            if (soloDesde) e.desde = "2026-09-01T00:00:00";
            else e.hasta = "2026-09-30T23:59:59";
            d = new Jdbc(true);
            exigir(ejecutar(true,e,d).estado == 200, "Limite unilateral");
            exigir(d.tiposNull.get(soloDesde ? 3 : 2).equals(Types.TIMESTAMP), "Un parametro NULL");
            exigir(d.parametros.get(soloDesde ? 2 : 3).equals(Timestamp.valueOf(
                    soloDesde ? "2026-09-01 00:00:00" : "2026-09-30 23:59:59")), "Otro parametro fecha");
        }

        for (int cantidad : new int[]{0,501}) {
            d = new Jdbc(true);
            try {
                new BilleteraServicio(d).obtenerMovimientosBilletera(7,null,null,cantidad);
                throw new AssertionError("Cantidad invalida");
            } catch (IllegalArgumentException esperado) {
                exigir(d.conexiones == 0, "Servicio valida antes del DAO");
            }
            casos++;
        }
        d = new Jdbc(true);
        try {
            new BilleteraServicio(d).obtenerMovimientosBilletera(7,
                    LocalDateTime.of(2026,9,2,0,0), LocalDateTime.of(2026,9,1,0,0),100);
            throw new AssertionError("Rango invalido");
        } catch (IllegalArgumentException esperado) {
            exigir(d.conexiones == 0, "Servicio valida rango sin SQL");
        }
        casos++;
    }
}
