package com.apuestas.dao;

import com.apuestas.modelo.*;
import com.apuestas.modelo.ConsultaDetalleEventoAdministrativo.Evento;
import java.math.BigDecimal;
import java.sql.*;
import java.time.LocalDateTime;
import java.util.*;

/** SELECT administrativos parametrizados, independientes de la exploracion publica. */
public class DetalleEventoAdministrativoDAO {
    protected Connection obtenerConexion() throws SQLException {return ConexionBD.obtenerConexion();}
    private static SQLException contrato(){return new SQLException("Detalle administrativo inconsistente.");}

    private static final String EVENTO="SELECT EV.IdEvento, EV.Nombre AS Evento, EV.IdLiga, L.Nombre AS Liga, "
            +"D.IdDeporte, D.Nombre AS Deporte, EE.Codigo AS EstadoEvento, TE.Codigo AS TipoEstadoEvento, "
            +"EV.FechaInicio, EV.FechaFin, EV.EsSimulado, EV.DuracionSimulacionSegundos, "
            +"EV.FechaInicioRealUtc, EV.FechaFinRealUtc, EV.VersionFila, RE.ResultadoTexto, ER.Codigo AS EstadoResultado "
            +"FROM dbo.Evento EV JOIN dbo.Liga L ON L.IdLiga=EV.IdLiga JOIN dbo.Deporte D ON D.IdDeporte=L.IdDeporte "
            +"JOIN dbo.Estado EE ON EE.IdEstado=EV.IdEstado JOIN dbo.TipoEstado TE ON TE.IdTipoEstado=EE.IdTipoEstado "
            +"LEFT JOIN dbo.ResultadoEvento RE ON RE.IdEvento=EV.IdEvento LEFT JOIN dbo.Estado ER ON ER.IdEstado=RE.IdEstado "
            +"WHERE EV.IdEvento=?";
    private static final String PARTICIPANTES="SELECT EP.IdEventoParticipante, EP.OrdenParticipante, EP.EsLocal, EP.MarcadorActual, "
            +"P.IdParticipante, P.Nombre AS Participante, P.TipoParticipante, P.IdPais, PA.Nombre AS Pais, PA.CodigoISO2 AS CodigoPais "
            +"FROM dbo.EventoParticipante EP JOIN dbo.Participante P ON P.IdParticipante=EP.IdParticipante "
            +"LEFT JOIN dbo.Pais PA ON PA.IdPais=P.IdPais WHERE EP.IdEvento=? ORDER BY EP.OrdenParticipante";
    private static final String MERCADOS="SELECT M.IdMercado, M.Nombre AS Mercado, M.Descripcion AS DescripcionMercado, "
            +"M.TipoMercado, EM.Codigo AS EstadoMercado, TM.Codigo AS TipoEstadoMercado, "
            +"S.IdSeleccion, S.Nombre AS Seleccion, S.Activo AS SeleccionActiva, S.IdParticipante, "
            +"C.IdCuota, C.Valor, C.ValorResultado, C.FechaInicio AS FechaInicioCuota, C.FechaFin AS FechaFinCuota, C.Activo AS CuotaActiva, "
            +"RS.Resultado AS ResultadoSeleccion, RS.FechaResolucion "
            +"FROM dbo.Mercado M JOIN dbo.Estado EM ON EM.IdEstado=M.IdEstado "
            +"JOIN dbo.TipoEstado TM ON TM.IdTipoEstado=EM.IdTipoEstado "
            +"LEFT JOIN dbo.Seleccion S ON S.IdMercado=M.IdMercado "
            +"OUTER APPLY (SELECT TOP (1) Q.IdCuota, Q.Valor, Q.ValorResultado, Q.FechaInicio, Q.FechaFin, Q.Activo "
            +"FROM dbo.Cuota Q WHERE Q.IdSeleccion=S.IdSeleccion AND Q.Activo=1 "
            +"ORDER BY Q.FechaInicio DESC, Q.IdCuota DESC) C "
            +"LEFT JOIN dbo.ResolucionSeleccion RS ON RS.IdSeleccion=S.IdSeleccion "
            +"WHERE M.IdEvento=? ORDER BY M.IdMercado, S.IdSeleccion";

    /** Lectura consistente de las tres proyecciones; no modifica registros. */
    public Evento consultar(int idEvento) throws SQLException {
        if(idEvento<=0)throw new IllegalArgumentException();
        try(Connection c=obtenerConexion()){
            if(!c.getAutoCommit())throw contrato();
            int isolation=c.getTransactionIsolation();
            c.setTransactionIsolation(Connection.TRANSACTION_SERIALIZABLE);
            c.setAutoCommit(false);
            try{
                Evento e=leerEvento(c,idEvento);
                if(e!=null){leerParticipantes(c,e);leerMercados(c,e);}
                c.commit();return e;
            }catch(SQLException|RuntimeException|LinkageError error){
                try{c.rollback();}catch(SQLException rollback){error.addSuppressed(rollback);}throw error;
            }finally{
                c.setAutoCommit(true);c.setTransactionIsolation(isolation);
            }
        }
    }
    private static PreparedStatement consulta(Connection c,String sql,int id)throws SQLException{
        PreparedStatement ps=c.prepareStatement(sql);
        try{ps.setInt(1,id);ps.setQueryTimeout(15);return ps;}
        catch(SQLException|RuntimeException e){ps.close();throw e;}
    }
    private static Evento leerEvento(Connection c,int id)throws SQLException{
        try(PreparedStatement ps=consulta(c,EVENTO,id);ResultSet rs=ps.executeQuery()){
            if(!rs.next())return null;
            Evento e=new Evento();e.idEvento=id(rs,"IdEvento");if(e.idEvento!=id)throw contrato();
            if(!"EVENTO".equals(texto(rs,"TipoEstadoEvento",false)))throw contrato();
            e.evento=texto(rs,"Evento",false);e.idDeporte=id(rs,"IdDeporte");e.deporte=texto(rs,"Deporte",false);
            e.idLiga=id(rs,"IdLiga");e.liga=texto(rs,"Liga",false);e.estadoEvento=texto(rs,"EstadoEvento",false);
            e.fechaInicio=fecha(rs,"FechaInicio",false);e.fechaFin=fecha(rs,"FechaFin",true);
            e.resultadoTexto=texto(rs,"ResultadoTexto",true);e.estadoResultado=texto(rs,"EstadoResultado",true);
            SimulacionEventoExploracion sim=new SimulacionEventoExploracion();
            sim.setEsSimulado(valor(rs,"EsSimulado",Boolean.class,false));
            sim.setDuracionSimulacionSegundos(valor(rs,"DuracionSimulacionSegundos",Integer.class,true));
            sim.setFechaInicioRealUtc(fecha(rs,"FechaInicioRealUtc",true));sim.setFechaFinRealUtc(fecha(rs,"FechaFinRealUtc",true));
            byte[] bytes=valor(rs,"VersionFila",byte[].class,false);if(bytes.length!=8)throw contrato();
            StringBuilder version=new StringBuilder(16);for(byte b:bytes)version.append(String.format(Locale.ROOT,"%02x",b&255));
            sim.setVersionFila(version.toString());e.simulacion=sim;
            if(rs.next())throw contrato();return e;
        }
    }
    private static void leerParticipantes(Connection c,Evento e)throws SQLException{
        Set<Integer> ids=new HashSet<>(),orders=new HashSet<>();
        try(PreparedStatement ps=consulta(c,PARTICIPANTES,e.idEvento);ResultSet rs=ps.executeQuery()){
            while(rs.next()){
                ParticipanteExploracion p=new ParticipanteExploracion();
                p.setIdEventoParticipante(id(rs,"IdEventoParticipante"));p.setIdParticipante(id(rs,"IdParticipante"));
                Object order=rs.getObject("OrdenParticipante");if(!(order instanceof Short)&&!(order instanceof Integer))throw contrato();
                int n=((Number)order).intValue();if(n<1||n>255||!orders.add(n)||!ids.add(p.getIdParticipante()))throw contrato();
                p.setOrdenParticipante(n);p.setEsLocal(valor(rs,"EsLocal",Boolean.class,true));p.setMarcadorActual(valor(rs,"MarcadorActual",Integer.class,true));
                p.setParticipante(texto(rs,"Participante",false));p.setTipoParticipante(texto(rs,"TipoParticipante",false));
                p.setIdPais(valor(rs,"IdPais",Integer.class,true));p.setPais(texto(rs,"Pais",true));p.setCodigoPais(texto(rs,"CodigoPais",true));
                e.participantes.add(p);
            }
        }
        e.cantidadParticipantes=e.participantes.size();
    }
    private static void leerMercados(Connection c,Evento e)throws SQLException{
        Map<Integer,MercadoExploracion> markets=new LinkedHashMap<>();Set<Integer> selections=new HashSet<>();
        try(PreparedStatement ps=consulta(c,MERCADOS,e.idEvento);ResultSet rs=ps.executeQuery()){
            while(rs.next()){
                int id=id(rs,"IdMercado");String name=texto(rs,"Mercado",false),description=texto(rs,"DescripcionMercado",true);
                String state=texto(rs,"EstadoMercado",false),type=texto(rs,"TipoMercado",false);
                if(!"MERCADO".equals(texto(rs,"TipoEstadoMercado",false))||!Arrays.asList("CONVENCIONAL","PRIMERA_ANOTACION","MARCADOR_FINAL").contains(type))throw contrato();
                MercadoExploracion m=markets.get(id);
                if(m==null){m=new MercadoExploracion();m.setIdMercado(id);m.setMercado(name);m.setDescripcionMercado(description);m.setEstadoMercado(state);m.setTipoMercado(type);markets.put(id,m);}
                else if(!Objects.equals(m.getMercado(),name)||!Objects.equals(m.getDescripcionMercado(),description)||!Objects.equals(m.getEstadoMercado(),state)||!Objects.equals(m.getTipoMercado(),type))throw contrato();
                if(rs.getObject("IdSeleccion")==null){
                    for(String col:Arrays.asList("Seleccion","SeleccionActiva","IdParticipante","IdCuota","Valor","ValorResultado","FechaInicioCuota","FechaFinCuota","CuotaActiva","ResultadoSeleccion","FechaResolucion"))if(rs.getObject(col)!=null)throw contrato();
                    continue;
                }
                SeleccionExploracion s=new SeleccionExploracion();s.setIdSeleccion(id(rs,"IdSeleccion"));if(!selections.add(s.getIdSeleccion()))throw contrato();
                s.setSeleccion(texto(rs,"Seleccion",false));s.setSeleccionActiva(valor(rs,"SeleccionActiva",Boolean.class,false));
                s.setIdParticipante(valor(rs,"IdParticipante",Integer.class,true));
                if(s.getIdParticipante()!=null&&e.participantes.stream().noneMatch(p->p.getIdParticipante()==s.getIdParticipante()))throw contrato();
                s.setIdCuota(valor(rs,"IdCuota",Integer.class,true));s.setCuota(valor(rs,"Valor",BigDecimal.class,true));s.setValor(s.getCuota());
                s.setValorResultado(valor(rs,"ValorResultado",BigDecimal.class,true));s.setCuotaActiva(valor(rs,"CuotaActiva",Boolean.class,true));
                s.setFechaInicioCuota(fecha(rs,"FechaInicioCuota",true));s.setFechaFinCuota(fecha(rs,"FechaFinCuota",true));
                if(s.getIdCuota()==null){if(s.getValor()!=null||s.getValorResultado()!=null||s.getCuotaActiva()!=null||s.getFechaInicioCuota()!=null||s.getFechaFinCuota()!=null)throw contrato();}
                else if(s.getIdCuota()<=0||s.getValor()==null||!Boolean.TRUE.equals(s.getCuotaActiva())||s.getFechaInicioCuota()==null)throw contrato();
                s.setResultadoSeleccion(texto(rs,"ResultadoSeleccion",true));s.setFechaResolucion(fecha(rs,"FechaResolucion",true));
                m.getSelecciones().add(s);
            }
        }
        e.mercados.addAll(markets.values());e.cantidadMercados=e.mercados.size();
    }
    private static <T>T valor(ResultSet rs,String col,Class<T> type,boolean nullable)throws SQLException{
        Object v=rs.getObject(col);if(v==null&&nullable)return null;if(!type.isInstance(v))throw contrato();return type.cast(v);
    }
    private static int id(ResultSet rs,String col)throws SQLException{int v=valor(rs,col,Integer.class,false);if(v<=0)throw contrato();return v;}
    private static String texto(ResultSet rs,String col,boolean nullable)throws SQLException{return valor(rs,col,String.class,nullable);}
    private static LocalDateTime fecha(ResultSet rs,String col,boolean nullable)throws SQLException{Timestamp t=valor(rs,col,Timestamp.class,nullable);return t==null?null:t.toLocalDateTime();}
}
