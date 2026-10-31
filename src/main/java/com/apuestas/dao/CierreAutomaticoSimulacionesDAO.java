package com.apuestas.dao;

import java.sql.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import java.util.logging.Logger;

/** Acceso exclusivo del servicio autonomo; reutiliza el pool existente. */
public class CierreAutomaticoSimulacionesDAO {
    private static final Logger LOG=Logger.getLogger(CierreAutomaticoSimulacionesDAO.class.getName());
    private final AtomicBoolean detenido=new AtomicBoolean();
    private final AtomicReference<CallableStatement> enCurso=new AtomicReference<>();
    private static SQLException contrato() { return new SQLException("Contrato de autocierre inconsistente."); }
    protected Connection obtenerConexion() throws SQLException { return ConexionBD.obtenerConexion(); }

    @FunctionalInterface private interface Operacion<T> { T leer(CallableStatement cs) throws SQLException; }
    private <T>T ejecutar(String llamada,Operacion<T> operacion) throws SQLException {
        if(detenido.get())throw new SQLException("Autocierre detenido.");
        try(Connection c=obtenerConexion()) {
            if(detenido.get()||!c.getAutoCommit())throw contrato();
            int timeoutAnterior=c.getNetworkTimeout();
            c.setNetworkTimeout(Runnable::run,20000);
            try {
                try(CallableStatement cs=c.prepareCall(llamada)) {
                    cs.setQueryTimeout(15);
                    if(!enCurso.compareAndSet(null,cs))throw contrato();
                    try {
                        if(detenido.get())throw new SQLException("Autocierre detenido.");
                        return operacion.leer(cs);
                    } finally { enCurso.compareAndSet(cs,null); }
                }
            } finally {
                if(!c.isClosed())c.setNetworkTimeout(Runnable::run,timeoutAnterior);
            }
        }
    }

    public List<Integer> listarVencidas(int actor,int despues,int limite) throws SQLException {
        if(actor<=0||despues<0||limite<1||limite>20)throw new IllegalArgumentException();
        return ejecutar("{call dbo.sp_ListarSimulacionesVencidas(?, ?, ?)}",cs->{
            cs.setInt(1,actor);cs.setInt(2,despues);cs.setInt(3,limite);
            if(!siguiente(cs,true))throw contrato();
            List<Integer> ids=new ArrayList<>();int anterior=despues;
            try(ResultSet rs=cs.getResultSet()) {
                columnas(rs,"IdEvento");
                while(rs.next()) {
                    int id=positivo(rs,"IdEvento");
                    if(id<=anterior||ids.size()>=limite)throw contrato();
                    ids.add(id);anterior=id;
                }
            }
            if(siguiente(cs,false)){try(ResultSet extra=cs.getResultSet()){throw contrato();}}
            return Collections.unmodifiableList(ids);
        });
    }

    public ResultadoCierre intentarCerrar(int actor,int evento) throws SQLException {
        if(actor<=0||evento<=0)throw new IllegalArgumentException();
        return ejecutar("{call dbo.sp_AutoFinalizarSimulacionVencida(?, ?)}",cs->{
            cs.setInt(1,actor);cs.setInt(2,evento);
            boolean hay=siguiente(cs,true);int intermedios=0;Integer resultadoIntermedio=null;
            ResultadoCierre finalizado=null;
            while(hay) {
                if(finalizado!=null) { // La marca debe ser el ultimo ResultSet.
                    try(ResultSet extra=cs.getResultSet()){throw contrato();}
                }
                try(ResultSet rs=cs.getResultSet()) {
                    if(rs==null||!rs.next())throw contrato();
                    if(columna(rs,"MarcaConfirmacion")) {
                        columnas(rs,"MarcaConfirmacion,IdEvento,CierreAutomaticoRealizado,SinCambios,EstadoEvento,FechaFinRealUtc,IdResultado,EstadoResultado");
                        if(!"AUTOCIERRE_SIMULACION_V1".equals(dato(rs,"MarcaConfirmacion",String.class,false)))throw contrato();
                        if(positivo(rs,"IdEvento")!=evento)throw contrato();
                        boolean realizado=dato(rs,"CierreAutomaticoRealizado",Boolean.class,false);
                        boolean sinCambios=dato(rs,"SinCambios",Boolean.class,false);
                        String estado=dato(rs,"EstadoEvento",String.class,true);
                        Timestamp fin=dato(rs,"FechaFinRealUtc",Timestamp.class,true);
                        Integer idResultado=dato(rs,"IdResultado",Integer.class,true);
                        String estadoResultado=dato(rs,"EstadoResultado",String.class,true);
                        if(realizado==sinCambios || (estado!=null&&!Arrays.asList("BORRADOR","PROGRAMADO","EN_VIVO","SUSPENDIDO","PENDIENTE_RESULTADO","FINALIZADO","CANCELADO").contains(estado)))throw contrato();
                        if(realizado) {
                            if(intermedios!=2||!"PENDIENTE_RESULTADO".equals(estado)||fin==null
                                ||idResultado==null||idResultado<=0||!idResultado.equals(resultadoIntermedio)
                                ||!"PENDIENTE".equals(estadoResultado))throw contrato();
                        } else if(intermedios!=0||idResultado!=null||estadoResultado!=null)throw contrato();
                        finalizado=new ResultadoCierre(evento,realizado);
                    } else if(intermedios==0) {
                        columnas(rs,"IdResultado,IdEvento,EstadoResultado,ResultadoTexto,Observacion");
                        resultadoIntermedio=positivo(rs,"IdResultado");
                        if(positivo(rs,"IdEvento")!=evento||!"PENDIENTE".equals(dato(rs,"EstadoResultado",String.class,false)))throw contrato();
                        if(dato(rs,"ResultadoTexto",String.class,false).trim().isEmpty())throw contrato();
                        dato(rs,"Observacion",String.class,true);intermedios++;
                    } else if(intermedios==1) {
                        columnas(rs,"IdEvento,SinCambios");
                        if(positivo(rs,"IdEvento")!=evento||dato(rs,"SinCambios",Boolean.class,false))throw contrato();
                        intermedios++;
                    } else throw contrato();
                    if(rs.next())throw contrato();
                }
                // Un error posterior a un SELECT, incluido un rollback exterior,
                // debe propagarse: nunca se confirma por los resultados intermedios.
                hay=siguiente(cs,false);
            }
            if(finalizado==null)throw contrato();
            return finalizado;
        });
    }

    private static boolean siguiente(CallableStatement cs,boolean primero) throws SQLException {
        boolean hay=primero?cs.execute():cs.getMoreResults(Statement.CLOSE_CURRENT_RESULT);
        int saltos=0;
        while(!hay&&cs.getUpdateCount()!=-1) {
            if(++saltos>64)throw contrato();
            hay=cs.getMoreResults(Statement.CLOSE_CURRENT_RESULT);
        }
        return hay;
    }
    private static boolean columna(ResultSet rs,String nombre) throws SQLException {
        ResultSetMetaData md=rs.getMetaData();
        for(int i=1;i<=md.getColumnCount();i++)if(nombre.equalsIgnoreCase(md.getColumnLabel(i)))return true;
        return false;
    }
    private static void columnas(ResultSet rs,String nombres) throws SQLException {
        if(rs==null)throw contrato();
        for(String nombre:nombres.split(","))if(!columna(rs,nombre))throw contrato();
    }
    private static <T>T dato(ResultSet rs,String nombre,Class<T> tipo,boolean nullable) throws SQLException {
        Object valor=rs.getObject(nombre);
        if(valor==null&&nullable)return null;
        if(!tipo.isInstance(valor))throw contrato();
        return tipo.cast(valor);
    }
    private static int positivo(ResultSet rs,String nombre) throws SQLException {
        int valor=dato(rs,nombre,Integer.class,false);if(valor<=0)throw contrato();return valor;
    }
    public void cancelar() {
        detenido.set(true);
        CallableStatement cs=enCurso.get();
        if(cs!=null)try {cs.cancel();}catch(SQLException|RuntimeException e) {
            LOG.warning("No se pudo cancelar inmediatamente la consulta de autocierre; permanecen sus limites de tiempo JDBC.");
        }
    }
    public static final class ResultadoCierre {
        public final int idEvento;
        public final boolean realizado;
        private ResultadoCierre(int idEvento,boolean realizado) {this.idEvento=idEvento;this.realizado=realizado;}
    }
}
