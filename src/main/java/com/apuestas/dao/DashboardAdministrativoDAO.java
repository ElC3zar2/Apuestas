package com.apuestas.dao;
import com.apuestas.modelo.DashboardAdministrativoModelos.*;
import java.sql.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;

/** Solo dos procedimientos de lectura. No agrega ni redondea sus metricas. */
public class DashboardAdministrativoDAO {
    protected Connection obtenerConexion() throws SQLException { return ConexionBD.obtenerConexion(); }
    private static SQLException contrato() { return new SQLException("Respuesta de dashboard inconsistente."); }
    public Dashboard dashboard(int actor,FiltrosDashboard f) throws SQLException {
        try(Connection c=obtenerConexion();CallableStatement cs=c.prepareCall("{call dbo.sp_ObtenerDashboardAdministrativo(?, ?, ?)}")) {
            cs.setInt(1,actor);cs.setInt(2,f.horasPrevia);cs.setInt(3,f.cantidadAuditoria);
            Dashboard d=new Dashboard();d.filtros=f;
            try(ResultSet rs=resultado(cs,true,COLUMNAS_RESUMEN)) {
                if(!rs.next()) throw contrato();d.resumen=leerResumen(rs);
                if(rs.next()) throw contrato();
            }
            d.deportes=new ArrayList<>();Set<Integer> deportes=new HashSet<>();
            try(ResultSet rs=resultado(cs,false,COLUMNAS_DEPORTE)) {
                while(rs.next()) {
                    Deporte r=leerDeporte(rs);
                    if(!deportes.add(r.idDeporte)) throw contrato();
                    d.deportes.add(r);
                }
            }
            d.auditoriaReciente=new ArrayList<>();Set<Long> auditorias=new HashSet<>();
            try(ResultSet rs=resultado(cs,false,COLUMNAS_AUDITORIA)) {
                while(rs.next()) {
                    Auditoria r=leerAuditoria(rs);
                    if(!auditorias.add(r.idAuditoria)||d.auditoriaReciente.size()>=f.cantidadAuditoria) throw contrato();
                    d.auditoriaReciente.add(r);
                }
            }
            fin(cs);return d;
        }
    }
    public Analitica eventos(int actor,FiltrosEventos f) throws SQLException {
        try(Connection c=obtenerConexion();CallableStatement cs=c.prepareCall("{call dbo.sp_ObtenerAnaliticaEventosAdministracion(?, ?, ?, ?, ?)}")) {
            cs.setInt(1,actor);
            if(f.idDeporte==null) cs.setNull(2,Types.INTEGER);else cs.setInt(2,f.idDeporte);
            cs.setString(3,f.vista);cs.setInt(4,f.horasPrevia);cs.setInt(5,f.cantidad);
            Analitica d=new Analitica();d.filtros=f;d.eventos=new ArrayList<>();
            Set<Integer> ids=new HashSet<>();
            try(ResultSet rs=resultado(cs,true,COLUMNAS_EVENTO)) {
                while(rs.next()) {
                    Evento r=leerEvento(rs);
                    if(!ids.add(r.idEvento)||d.eventos.size()>=f.cantidad
                            ||(f.idDeporte!=null&&!f.idDeporte.equals(r.idDeporte))) throw contrato();
                    d.eventos.add(r);
                }
            }
            fin(cs);return d;
        }
    }
    private static boolean siguiente(CallableStatement cs,boolean primero) throws SQLException {
        boolean hay=primero?cs.execute():cs.getMoreResults();
        while(!hay&&cs.getUpdateCount()!=-1) hay=cs.getMoreResults();
        return hay;
    }
    private static ResultSet resultado(CallableStatement cs,boolean primero,String[] columnas) throws SQLException {
        if(!siguiente(cs,primero)) throw contrato();
        ResultSet rs=cs.getResultSet();if(rs==null) throw contrato();
        // La metadata permite comprobar el orden incluso con listas vacias.
        try {
            ResultSetMetaData md=rs.getMetaData();if(md==null) throw contrato();
            Set<String> nombres=new HashSet<>();
            for(int i=1;i<=md.getColumnCount();i++)
                if(!nombres.add(md.getColumnLabel(i))) throw contrato();
            for(String col:columnas) if(!nombres.contains(col)) throw contrato();
            return rs;
        } catch(SQLException | RuntimeException | Error e) {
            try { rs.close(); } catch(SQLException cierre) { e.addSuppressed(cierre); }
            throw e;
        }
    }
    private static void fin(CallableStatement cs) throws SQLException {
        if(siguiente(cs,false)) { try(ResultSet extra=cs.getResultSet()) { throw contrato(); } }
    }
    private static Integer entero(ResultSet rs,String col,boolean nullable,int minimo) throws SQLException {
        Object v=rs.getObject(col);if(v==null&&nullable) return null;
        if(!(v instanceof Integer)||(Integer)v<minimo) throw contrato();return (Integer)v;
    }
    private static Long largo(ResultSet rs,String col,boolean nullable,boolean positivo) throws SQLException {
        Object v=rs.getObject(col);if(v==null&&nullable) return null;
        if(!(v instanceof Long)||(positivo&&(Long)v<=0)) throw contrato();return (Long)v;
    }
    private static String texto(ResultSet rs,String col,boolean nullable) throws SQLException {
        Object v=rs.getObject(col);if(v==null&&nullable) return null;
        if(!(v instanceof String)||(!nullable&&((String)v).trim().isEmpty())) throw contrato();return (String)v;
    }
    private static LocalDateTime fecha(ResultSet rs,String col,boolean nullable) throws SQLException {
        Object v=rs.getObject(col);if(v==null&&nullable) return null;
        if(!(v instanceof Timestamp)) throw contrato();return ((Timestamp)v).toLocalDateTime();
    }
    private static BigDecimal decimal(ResultSet rs,String col,boolean nullable,int precision,int escala,boolean firmado) throws SQLException {
        Object v=rs.getObject(col);if(v==null&&nullable) return null;
        if(!(v instanceof BigDecimal)) throw contrato();
        BigDecimal d=(BigDecimal)v;
        if((!firmado&&d.signum()<0)||d.scale()>escala||d.precision()-d.scale()>precision-escala) throw contrato();
        return d;
    }
    private static final String[] COLUMNAS_RESUMEN={"ClientesRegistrados","ClientesActivos","EventosTotales","EventosProgramados","EventosPrevia","EventosEnProgreso","EventosPendienteResultado","EventosFinalizados","BoletosTotales","BoletosPendientes","BoletosGanadores","BoletosPerdedores","BoletosAnulados","TotalApostadoHistorico","ComisionesHistoricas","ComisionesRealizadas","ComisionesPendientes","ComisionesDevueltas","MontoApostadoPendiente","PremioPotencialPendiente","ExposicionPotencialCasa","GananciaCasaPorApuestasPerdidas","PremiosPagados","ResultadoCasaRealizado","AccionesAuditoriaUltimas24Horas"};
    private static Resumen leerResumen(ResultSet rs) throws SQLException {
        Resumen r=new Resumen();
        r.clientesRegistrados=entero(rs,"ClientesRegistrados",false,0);
        r.clientesActivos=entero(rs,"ClientesActivos",false,0);
        r.eventosTotales=entero(rs,"EventosTotales",false,0);
        r.eventosProgramados=entero(rs,"EventosProgramados",false,0);
        r.eventosPrevia=entero(rs,"EventosPrevia",false,0);
        r.eventosEnProgreso=entero(rs,"EventosEnProgreso",false,0);
        r.eventosPendienteResultado=entero(rs,"EventosPendienteResultado",false,0);
        r.eventosFinalizados=entero(rs,"EventosFinalizados",false,0);
        r.boletosTotales=entero(rs,"BoletosTotales",false,0);
        r.boletosPendientes=entero(rs,"BoletosPendientes",false,0);
        r.boletosGanadores=entero(rs,"BoletosGanadores",false,0);
        r.boletosPerdedores=entero(rs,"BoletosPerdedores",false,0);
        r.boletosAnulados=entero(rs,"BoletosAnulados",false,0);
        r.totalApostadoHistorico=decimal(rs,"TotalApostadoHistorico",false,38,2,false);
        r.comisionesHistoricas=decimal(rs,"ComisionesHistoricas",false,38,2,false);
        r.comisionesRealizadas=decimal(rs,"ComisionesRealizadas",false,38,2,false);
        r.comisionesPendientes=decimal(rs,"ComisionesPendientes",false,38,2,false);
        r.comisionesDevueltas=decimal(rs,"ComisionesDevueltas",false,38,2,false);
        r.montoApostadoPendiente=decimal(rs,"MontoApostadoPendiente",false,38,2,false);
        r.premioPotencialPendiente=decimal(rs,"PremioPotencialPendiente",false,38,2,false);
        r.exposicionPotencialCasa=decimal(rs,"ExposicionPotencialCasa",false,38,2,false);
        r.gananciaCasaPorApuestasPerdidas=decimal(rs,"GananciaCasaPorApuestasPerdidas",false,38,2,false);
        r.premiosPagados=decimal(rs,"PremiosPagados",false,38,2,false);
        r.resultadoCasaRealizado=decimal(rs,"ResultadoCasaRealizado",false,38,2,true);
        r.accionesAuditoriaUltimas24Horas=entero(rs,"AccionesAuditoriaUltimas24Horas",false,0);
        return r;
    }
    private static final String[] COLUMNAS_DEPORTE={"IdDeporte","Deporte","EventosTotales","Programados","Previa","EnProgreso","PendienteResultado","Finalizados","BoletosRelacionados","ClientesUnicos","BoletosPendientes","BoletosGanadores","BoletosPerdedores","BoletosAnulados","MontoApostadoRelacionado","ComisionRelacionada","PremioPotencialPendienteRelacionado","CantidadSeleccionesApostadas","SeleccionesPendientes","SeleccionesGanadas","SeleccionesPerdidas","CuotaPromedio","ProbabilidadImplicitaPromedio"};
    private static Deporte leerDeporte(ResultSet rs) throws SQLException {
        Deporte r=new Deporte();
        r.idDeporte=entero(rs,"IdDeporte",false,1);
        r.deporte=texto(rs,"Deporte",false);
        r.eventosTotales=entero(rs,"EventosTotales",false,0);
        r.programados=entero(rs,"Programados",false,0);
        r.previa=entero(rs,"Previa",false,0);
        r.enProgreso=entero(rs,"EnProgreso",false,0);
        r.pendienteResultado=entero(rs,"PendienteResultado",false,0);
        r.finalizados=entero(rs,"Finalizados",false,0);
        r.boletosRelacionados=entero(rs,"BoletosRelacionados",false,0);
        r.clientesUnicos=entero(rs,"ClientesUnicos",false,0);
        r.boletosPendientes=entero(rs,"BoletosPendientes",false,0);
        r.boletosGanadores=entero(rs,"BoletosGanadores",false,0);
        r.boletosPerdedores=entero(rs,"BoletosPerdedores",false,0);
        r.boletosAnulados=entero(rs,"BoletosAnulados",false,0);
        r.montoApostadoRelacionado=decimal(rs,"MontoApostadoRelacionado",false,38,2,false);
        r.comisionRelacionada=decimal(rs,"ComisionRelacionada",false,38,2,false);
        r.premioPotencialPendienteRelacionado=decimal(rs,"PremioPotencialPendienteRelacionado",false,38,2,false);
        r.cantidadSeleccionesApostadas=entero(rs,"CantidadSeleccionesApostadas",false,0);
        r.seleccionesPendientes=entero(rs,"SeleccionesPendientes",false,0);
        r.seleccionesGanadas=entero(rs,"SeleccionesGanadas",false,0);
        r.seleccionesPerdidas=entero(rs,"SeleccionesPerdidas",false,0);
        r.cuotaPromedio=decimal(rs,"CuotaPromedio",true,12,4,false);
        r.probabilidadImplicitaPromedio=decimal(rs,"ProbabilidadImplicitaPromedio",true,7,2,false);
        return r;
    }
    private static final String[] COLUMNAS_AUDITORIA={"IdAuditoria","FechaAccion","IdUsuario","Correo","Accion","TablaAfectada","IdRegistro","ReferenciaOperacion","IpOrigen","Descripcion"};
    private static Auditoria leerAuditoria(ResultSet rs) throws SQLException {
        Auditoria r=new Auditoria();
        r.idAuditoria=largo(rs,"IdAuditoria",false,true);
        r.fechaAccion=fecha(rs,"FechaAccion",false);
        r.idUsuario=entero(rs,"IdUsuario",true,1);
        r.correo=texto(rs,"Correo",true);
        r.accion=texto(rs,"Accion",false);
        r.tablaAfectada=texto(rs,"TablaAfectada",true);
        r.idRegistro=largo(rs,"IdRegistro",true,false);
        // Validar pero no publicar detalles libres ni identificadores tecnicos innecesarios.
        String referencia=texto(rs,"ReferenciaOperacion",true);
        if(referencia!=null&&!referencia.matches("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")) throw contrato();
        texto(rs,"IpOrigen",true);texto(rs,"Descripcion",true);
        return r;
    }
    private static final String[] COLUMNAS_EVENTO={"IdEvento","IdDeporte","Deporte","IdLiga","Liga","Evento","FechaInicio","FechaFin","EstadoEvento","EstadoVisual","CantidadMercados","MercadosAbiertos","CantidadSelecciones","SeleccionesConCuotaActiva","BoletosRelacionados","ClientesUnicos","BoletosPendientes","BoletosGanadores","BoletosPerdedores","BoletosAnulados","MontoApostadoRelacionado","ComisionRelacionada","PremioPotencialPendienteRelacionado","ExposicionPotencialRelacionada","ResultadoCasaRealizadoRelacionado","CuotaPromedioBoletos","UltimaApuestaRelacionada"};
    private static Evento leerEvento(ResultSet rs) throws SQLException {
        Evento r=new Evento();
        r.idEvento=entero(rs,"IdEvento",false,1);
        r.idDeporte=entero(rs,"IdDeporte",false,1);
        r.deporte=texto(rs,"Deporte",false);
        r.idLiga=entero(rs,"IdLiga",false,1);
        r.liga=texto(rs,"Liga",false);
        r.evento=texto(rs,"Evento",false);
        r.fechaInicio=fecha(rs,"FechaInicio",false);
        r.fechaFin=fecha(rs,"FechaFin",true);
        r.estadoEvento=texto(rs,"EstadoEvento",false);
        r.estadoVisual=texto(rs,"EstadoVisual",false);
        r.cantidadMercados=entero(rs,"CantidadMercados",false,0);
        r.mercadosAbiertos=entero(rs,"MercadosAbiertos",false,0);
        r.cantidadSelecciones=entero(rs,"CantidadSelecciones",false,0);
        r.seleccionesConCuotaActiva=entero(rs,"SeleccionesConCuotaActiva",false,0);
        r.boletosRelacionados=entero(rs,"BoletosRelacionados",false,0);
        r.clientesUnicos=entero(rs,"ClientesUnicos",false,0);
        r.boletosPendientes=entero(rs,"BoletosPendientes",false,0);
        r.boletosGanadores=entero(rs,"BoletosGanadores",false,0);
        r.boletosPerdedores=entero(rs,"BoletosPerdedores",false,0);
        r.boletosAnulados=entero(rs,"BoletosAnulados",false,0);
        r.montoApostadoRelacionado=decimal(rs,"MontoApostadoRelacionado",false,38,2,false);
        r.comisionRelacionada=decimal(rs,"ComisionRelacionada",false,38,2,false);
        r.premioPotencialPendienteRelacionado=decimal(rs,"PremioPotencialPendienteRelacionado",false,38,2,false);
        r.exposicionPotencialRelacionada=decimal(rs,"ExposicionPotencialRelacionada",false,38,2,false);
        r.resultadoCasaRealizadoRelacionado=decimal(rs,"ResultadoCasaRealizadoRelacionado",false,38,2,true);
        r.cuotaPromedioBoletos=decimal(rs,"CuotaPromedioBoletos",true,12,4,false);
        r.ultimaApuestaRelacionada=fecha(rs,"UltimaApuestaRelacionada",true);
        return r;
    }
}
