package com.apuestas.dao;
import com.apuestas.modelo.Usuario;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.sql.*;
import java.time.LocalDate;

/** Simula exclusivamente JDBC; nunca inicializa ConexionBD. */
public class PruebaContratosAuditoria {
    static int casos,fallos;
    @SuppressWarnings("unchecked") static <T>T proxy(Class<T> c,InvocationHandler h){
        return (T)Proxy.newProxyInstance(c.getClassLoader(),new Class<?>[]{c},h);
    }
    static class Jdbc {
        int[] filas; int indice,abiertos,cerrados; boolean conexionCerrada,statementCerrado;
        Jdbc(int... filas){this.filas=filas;}
        Connection conexion(){
            return proxy(Connection.class,(p,m,a)->{
                if(m.getName().equals("close")){conexionCerrada=true;return null;}
                if(m.getName().equals("prepareCall"))return proxy(CallableStatement.class,(sp,sm,sa)->{
                    switch(sm.getName()){
                        case "setInt":case "setString":case "setBigDecimal":case "setDate":case "setNull":return null;
                        case "execute":indice=0;return filas.length>0;
                        case "getUpdateCount":return -1;
                        case "getMoreResults":return ++indice<filas.length;
                        case "getResultSet":return resultado(filas[indice]);
                        case "close":statementCerrado=true;return null;
                        default:throw new AssertionError(sm.getName());
                    }
                });
                throw new AssertionError(m.getName());
            });
        }
        ResultSet resultado(int cantidad){
            abiertos++;int[] posicion={0};
            return proxy(ResultSet.class,(p,m,a)->{
                switch(m.getName()){
                    case "next":return ++posicion[0]<=cantidad;
                    case "getInt":return "CantidadSelecciones".equals(a[0])?1:7;
                    case "getString":return "PRUEBA";
                    case "getBigDecimal":return BigDecimal.TEN;
                    case "getTimestamp":return Timestamp.valueOf("2026-01-01 00:00:00");
                    case "getBoolean":return true;
                    case "getObject":return (a[0].toString().equals("EsLocal") || a[0].toString().equals("CuotaActiva")) ? Boolean.TRUE : Integer.valueOf(7);
                    case "wasNull":return false;
                    case "close":cerrados++;return null;
                    default:throw new AssertionError(m.getName());
                }
            });
        }
    }
    static void probar(String operacion,boolean valido,int... filas)throws Exception{
        casos++;Jdbc j=new Jdbc(filas);boolean fallo=false;
        try{
            if(operacion.equals("registro")){
                Usuario u=new Usuario("A","B","a@example.invalid","$2a$12$"+"a".repeat(53),LocalDate.of(1990,1,1),"M","+50212345678","PASAPORTE","X",2,null,"Ciudad","Calle");
                new UsuarioDAO(){protected Connection obtenerConexion(){return j.conexion();}}.registrarCliente(u);
            }else if(operacion.equals("evento")){
                new ExploracionEventoDAO(){protected Connection obtenerConexion(){return j.conexion();}}.obtenerDetalleEvento(7,24);
            }else{
                ApuestaDAO d=new ApuestaDAO(){protected Connection obtenerConexion(){return j.conexion();}};
                if(operacion.equals("cotizar"))d.cotizarApuesta("[7]",BigDecimal.TEN);
                else d.obtenerBoleto(7,7,null);
            }
        }catch(SQLException esperado){fallo=true;}
        if(fallo==valido || !j.conexionCerrada || !j.statementCerrado || j.abiertos!=j.cerrados){
            fallos++;System.out.println("FALLO contrato "+operacion+" "+java.util.Arrays.toString(filas));
        }
    }
    public static void main(String[] args)throws Exception{
        probar("registro",true,1);
        probar("registro",false,0);
        probar("registro",false,2);
        probar("registro",false,1,1);
        for(String op:new String[]{"cotizar","boleto"}){
            probar(op,true,1,1);
            probar(op,false,0,1);
            probar(op,false,2,1);
            probar(op,false,1);
            probar(op,false,1,1,1);
        }
        probar("evento",true,1,1,1);
        probar("evento",false,0,1,1);
        probar("evento",false,2,1,1);
        probar("evento",false,1);
        probar("evento",false,1,1);
        probar("evento",false,1,1,1,1);
        System.out.println("Contratos auditoria: "+casos+" casos, "+fallos+" fallos.");
        if(fallos>0)throw new AssertionError("Contratos incompletos");
    }
}