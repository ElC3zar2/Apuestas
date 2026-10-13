package com.apuestas.dao;

import com.apuestas.modelo.*;
import java.sql.*;
import java.util.*;

/** Lee los dos/siete ResultSet oficiales; nunca ejecuta acciones de simulacion. */
public class ExploracionEventoDAO {
    protected Connection obtenerConexion() throws SQLException { return ConexionBD.obtenerConexion(); }
    private static SQLException contrato() { return new SQLException("Respuesta de exploracion inconsistente."); }
    private static final String EVENTO = "IdEvento,IdDeporte,Deporte,IdLiga,Liga,Evento,Participante1,Participante2,CantidadParticipantes,FechaInicio,FechaFin,FechaCierreApuestas,MinutosParaInicio,MinutosParaCierreApuestas,EstadoEvento,EstadoVisual,ResultadoPendiente,CantidadMercados,MercadosAbiertos,SeleccionesDisponibles,PuedeApostar,ResultadoTexto,EstadoResultado";
    private static final String DETALLE = "IdEvento,IdDeporte,Deporte,IdLiga,Liga,Evento,FechaInicio,FechaFin,FechaCierreApuestas,MinutosParaInicio,MinutosParaCierreApuestas,EstadoEvento,EstadoVisual,PuedeApostar,CantidadMercados,CantidadParticipantes,ResultadoTexto,EstadoResultado,ResultadoPendiente";
    private static final String PARTICIPANTE = "IdEventoParticipante,EsLocal,IdParticipante,Participante,TipoParticipante,IdPais,Pais,CodigoPais,OrdenParticipante";
    private static final String MERCADO = "IdMercado,Mercado,DescripcionMercado,EstadoMercado";
    private static final String SELECCION = "IdSeleccion,Seleccion,SeleccionActiva,IdCuota,Cuota,FechaInicioCuota,FechaFinCuota,CuotaActiva,ProbabilidadImplicitaPorcentaje,ResultadoSeleccion,FechaResolucion,PuedeSeleccionar";

    public List<EventoExploracion> listarEventos(int idDeporte, String vista, int horasPrevia, int cantidad)
            throws SQLException {
        try (Connection c=obtenerConexion(); CallableStatement cs=c.prepareCall(
                "{call dbo.sp_ObtenerEventosExploracion(?, ?, ?, ?)}")) {
            cs.setInt(1,idDeporte); cs.setString(2,vista); cs.setInt(3,horasPrevia); cs.setInt(4,cantidad);
            Map<Integer,EventoExploracion> eventos=new LinkedHashMap<>();
            try(ResultSet rs=resultado(cs,true,EVENTO)) {
                while(rs.next()) {
                    EventoExploracion e=mapearEvento(rs);
                    if(e.getIdEvento()<=0 || e.getIdDeporte()!=idDeporte
                            || eventos.putIfAbsent(e.getIdEvento(),e)!=null) throw contrato();
                }
            }
            Set<Integer> vistos=new HashSet<>();
            try(ResultSet rs=resultado(cs,false,SIMULACION+",MarcadorA,MarcadorB")) {
                while(rs.next()) {
                    int id=id(rs,"IdEvento"); EventoExploracion e=eventos.get(id);
                    if(e==null || !vistos.add(id)) throw contrato();
                    SimulacionEventoExploracion s=simulacion(rs);
                    s.setMarcadorA(valor(rs,"MarcadorA",Integer.class,true));
                    s.setMarcadorB(valor(rs,"MarcadorB",Integer.class,true));
                    e.setSimulacion(s);
                }
            }
            if(vistos.size()!=eventos.size()) throw contrato();
            fin(cs); return Collections.unmodifiableList(new ArrayList<>(eventos.values()));
        }
    }

    public DetalleEventoExploracion obtenerDetalleEvento(int idEvento,int horasPrevia) throws SQLException {
        try(Connection c=obtenerConexion(); CallableStatement cs=c.prepareCall(
                "{call dbo.sp_ObtenerDetalleEventoExploracion(?, ?)}")) {
            cs.setInt(1,idEvento); cs.setInt(2,horasPrevia);
            DetalleEventoExploracion d;
            try(ResultSet rs=resultado(cs,true,DETALLE)) {
                if(!rs.next()) throw contrato(); d=mapearDetalleEvento(rs);
                if(d.getIdEvento()!=idEvento || rs.next()) throw contrato();
            }
            Map<Integer,ParticipanteExploracion> participantes=new LinkedHashMap<>();
            Set<Integer> ordenes=new HashSet<>();
            try(ResultSet rs=resultado(cs,false,PARTICIPANTE)) {
                while(rs.next()) {
                    ParticipanteExploracion p=mapearParticipante(rs);
                    if(p.getIdParticipante()<=0 || !ordenes.add(p.getOrdenParticipante())
                            || participantes.putIfAbsent(p.getIdParticipante(),p)!=null) throw contrato();
                }
            }
            d.setParticipantes(Collections.unmodifiableList(new ArrayList<>(participantes.values())));
            Map<Integer,MercadoExploracion> mercados=new LinkedHashMap<>();
            Map<Integer,SeleccionExploracion> selecciones=new HashMap<>();
            Map<Integer,Integer> mercadoSeleccion=new HashMap<>();
            try(ResultSet rs=resultado(cs,false,MERCADO+","+SELECCION)) {
                while(rs.next()) {
                    int idMercado=id(rs,"IdMercado");
                    MercadoExploracion m=mercados.get(idMercado);
                    MercadoExploracion fila=mapearMercado(rs);
                    if(m==null) { m=fila; mercados.put(idMercado,m); }
                    else if(!Objects.equals(m.getMercado(),fila.getMercado())
                            || !Objects.equals(m.getDescripcionMercado(),fila.getDescripcionMercado())
                            || !Objects.equals(m.getEstadoMercado(),fila.getEstadoMercado())) throw contrato();
                    SeleccionExploracion s=mapearSeleccion(rs);
                    if(s.getIdSeleccion()<=0 || selecciones.putIfAbsent(s.getIdSeleccion(),s)!=null) throw contrato();
                    mercadoSeleccion.put(s.getIdSeleccion(),idMercado); m.getSelecciones().add(s);
                }
            }
            Set<Integer> ofertas=new HashSet<>();
            try(ResultSet rs=resultado(cs,false,"IdMercado,TipoMercado,IdSeleccion,IdParticipante,Valor,ValorResultado")) {
                while(rs.next()) {
                    int idSeleccion=id(rs,"IdSeleccion"), idMercado=id(rs,"IdMercado");
                    SeleccionExploracion s=selecciones.get(idSeleccion);
                    if(s==null || !Objects.equals(mercadoSeleccion.get(idSeleccion),idMercado)
                            || !ofertas.add(idSeleccion)) throw contrato();
                    MercadoExploracion m=mercados.get(idMercado);
                    String tipo=texto(rs,"TipoMercado",false);
                    if(!Arrays.asList("CONVENCIONAL","MARCADOR_FINAL","PRIMERA_ANOTACION").contains(tipo)
                            || (m.getTipoMercado()!=null && !tipo.equals(m.getTipoMercado()))) throw contrato();
                    m.setTipoMercado(tipo);
                    Integer participante=valor(rs,"IdParticipante",Integer.class,true);
                    if(participante!=null && !participantes.containsKey(participante)) throw contrato();
                    s.setIdParticipante(participante);
                    // Valor es la oferta ACTIVA; Cuota del RS3 puede ser historica. No se sobreescriben.
                    s.setValor(valor(rs,"Valor",java.math.BigDecimal.class,true));
                    s.setValorResultado(valor(rs,"ValorResultado",java.math.BigDecimal.class,true));
                }
            }
            if(ofertas.size()!=selecciones.size()) throw contrato();
            for(MercadoExploracion m:mercados.values())
                m.setSelecciones(Collections.unmodifiableList(new ArrayList<>(m.getSelecciones())));
            d.setMercados(Collections.unmodifiableList(new ArrayList<>(mercados.values())));
            SimulacionEventoExploracion sim;
            try(ResultSet rs=resultado(cs,false,SIMULACION+",Nombre,EstadoEvento,SegundosTranscurridos,TiempoVisualCumplido,IdPrimeraAnotacion,IdPrimerParticipanteAnotador")) {
                if(!rs.next() || id(rs,"IdEvento")!=idEvento) throw contrato();
                if(!Objects.equals(texto(rs,"Nombre",false),d.getEvento())
                        || !Objects.equals(texto(rs,"EstadoEvento",false),d.getEstadoEvento())) throw contrato();
                sim=simulacion(rs);
                sim.setSegundosTranscurridos(valor(rs,"SegundosTranscurridos",Integer.class,false));
                sim.setTiempoVisualCumplido(valor(rs,"TiempoVisualCumplido",Boolean.class,false));
                sim.setIdPrimeraAnotacion(valor(rs,"IdPrimeraAnotacion",Long.class,true));
                sim.setIdPrimerParticipanteAnotador(valor(rs,"IdPrimerParticipanteAnotador",Integer.class,true));
                if(rs.next()) throw contrato();
            }
            Set<Integer> marcadores=new HashSet<>();
            try(ResultSet rs=resultado(cs,false,"OrdenParticipante,IdParticipante,Nombre,MarcadorActual")) {
                while(rs.next()) {
                    int id=id(rs,"IdParticipante"); ParticipanteExploracion p=participantes.get(id);
                    if(p==null || !marcadores.add(id) || orden(rs)!=p.getOrdenParticipante()
                            || !Objects.equals(texto(rs,"Nombre",false),p.getParticipante())) throw contrato();
                    p.setMarcadorActual(valor(rs,"MarcadorActual",Integer.class,true));
                    if(p.getOrdenParticipante()==1) sim.setMarcadorA(p.getMarcadorActual());
                    if(p.getOrdenParticipante()==2) sim.setMarcadorB(p.getMarcadorActual());
                }
            }
            if(marcadores.size()!=participantes.size()) throw contrato();
            List<IncidenciaEventoExploracion> incidencias=new ArrayList<>();
            Set<Long> ids=new HashSet<>(); Set<Integer> secuencias=new HashSet<>();
            try(ResultSet rs=resultado(cs,false,INCIDENCIA)) {
                while(rs.next()) {
                    IncidenciaEventoExploracion i=incidencia(rs);
                    if(!ids.add(i.getIdIncidencia()) || !secuencias.add(i.getSecuencia())
                            || (i.getIdParticipante()!=null && !participantes.containsKey(i.getIdParticipante()))) throw contrato();
                    incidencias.add(i);
                }
            }
            if(sim.getIdPrimeraAnotacion()!=null && !ids.contains(sim.getIdPrimeraAnotacion())) throw contrato();
            if((sim.getIdPrimeraAnotacion()==null)!=(sim.getIdPrimerParticipanteAnotador()==null)) throw contrato();
            for(IncidenciaEventoExploracion i:incidencias) {
                if(Objects.equals(i.getIdIncidencia(),sim.getIdPrimeraAnotacion())
                        && (i.getEsAnulada() || !"ANOTACION".equals(i.getTipoIncidencia())
                            || !Objects.equals(i.getIdParticipante(),sim.getIdPrimerParticipanteAnotador()))) throw contrato();
            }
            d.setSimulacion(sim); d.setIncidencias(incidencias); fin(cs); return d;
        }
    }
    private static final String SIMULACION="IdEvento,EsSimulado,DuracionSimulacionSegundos,FechaInicioRealUtc,FechaFinRealUtc,VersionFila";
    private static final String INCIDENCIA="IdIncidencia,Secuencia,TipoIncidencia,IdParticipante,ValorAnotacion,SegundoSimulacion,FechaRegistroUtc,Descripcion,EsAnulada,MotivoAnulacion,FechaAnulacionUtc,VersionFila";
    private static SimulacionEventoExploracion simulacion(ResultSet rs) throws SQLException {
        SimulacionEventoExploracion s=new SimulacionEventoExploracion();
        s.setEsSimulado(valor(rs,"EsSimulado",Boolean.class,false));
        s.setDuracionSimulacionSegundos(valor(rs,"DuracionSimulacionSegundos",Integer.class,true));
        s.setFechaInicioRealUtc(obtenerFecha(rs,"FechaInicioRealUtc"));
        s.setFechaFinRealUtc(obtenerFecha(rs,"FechaFinRealUtc")); s.setVersionFila(version(rs)); return s;
    }
    private static IncidenciaEventoExploracion incidencia(ResultSet rs) throws SQLException {
        IncidenciaEventoExploracion i=new IncidenciaEventoExploracion();
        i.setIdIncidencia(valor(rs,"IdIncidencia",Long.class,false));
        i.setSecuencia(id(rs,"Secuencia")); i.setTipoIncidencia(texto(rs,"TipoIncidencia",false));
        if(i.getIdIncidencia()<=0 || !Arrays.asList("ANOTACION","FALTA","TARJETA_AMARILLA","TARJETA_ROJA","OTRA").contains(i.getTipoIncidencia())) throw contrato();
        i.setIdParticipante(valor(rs,"IdParticipante",Integer.class,true));
        i.setValorAnotacion(valor(rs,"ValorAnotacion",Integer.class,true));
        i.setSegundoSimulacion(valor(rs,"SegundoSimulacion",Integer.class,false));
        i.setFechaRegistroUtc(valor(rs,"FechaRegistroUtc",Timestamp.class,false).toLocalDateTime());
        i.setDescripcion(texto(rs,"Descripcion",true)); i.setEsAnulada(valor(rs,"EsAnulada",Boolean.class,false));
        i.setMotivoAnulacion(texto(rs,"MotivoAnulacion",true));
        i.setFechaAnulacionUtc(obtenerFecha(rs,"FechaAnulacionUtc")); i.setVersionFila(version(rs)); return i;
    }
    private static boolean siguiente(CallableStatement cs,boolean primero) throws SQLException {
        boolean hay=primero?cs.execute():cs.getMoreResults();
        while(!hay && cs.getUpdateCount()!=-1) hay=cs.getMoreResults(); return hay;
    }
    private static ResultSet resultado(CallableStatement cs,boolean primero,String columnas) throws SQLException {
        if(!siguiente(cs,primero)) throw contrato();
        ResultSet rs=cs.getResultSet(); if(rs==null) throw contrato();
        try {
            ResultSetMetaData md=rs.getMetaData(); if(md==null) throw contrato();
            Set<String> disponibles=new HashSet<>();
            for(int n=1;n<=md.getColumnCount();n++) disponibles.add(md.getColumnLabel(n));
            for(String c:columnas.split(",")) if(!disponibles.contains(c)) throw contrato();
            return rs;
        } catch(SQLException | RuntimeException e) { rs.close(); throw contrato(); }
    }
    private static void fin(CallableStatement cs) throws SQLException {
        if(siguiente(cs,false)) { try(ResultSet extra=cs.getResultSet()) { throw contrato(); } }
    }
    private static <T> T valor(ResultSet rs,String columna,Class<T> tipo,boolean nullable) throws SQLException {
        Object v=rs.getObject(columna);
        if(v==null && nullable) return null;
        if(!tipo.isInstance(v)) throw contrato(); return tipo.cast(v);
    }
    private static String texto(ResultSet rs,String c,boolean nullable) throws SQLException { return valor(rs,c,String.class,nullable); }
    private static int id(ResultSet rs,String c) throws SQLException { int v=valor(rs,c,Integer.class,false); if(v<=0) throw contrato(); return v; }
    private static int orden(ResultSet rs) throws SQLException {
        Object v=rs.getObject("OrdenParticipante");
        if(!(v instanceof Short) && !(v instanceof Integer)) throw contrato();
        int n=((Number)v).intValue(); if(n<1 || n>255) throw contrato(); return n;
    }
    private static java.time.LocalDateTime obtenerFecha(ResultSet rs,String c) throws SQLException {
        Timestamp t=valor(rs,c,Timestamp.class,!"FechaInicio".equals(c)); return t==null?null:t.toLocalDateTime();
    }
    private static Integer obtenerEnteroNullable(ResultSet rs,String c) throws SQLException { return valor(rs,c,Integer.class,true); }
    private static Boolean obtenerBooleanNullable(ResultSet rs,String c) throws SQLException { return valor(rs,c,Boolean.class,true); }
    private static String version(ResultSet rs) throws SQLException {
        byte[] bytes=valor(rs,"VersionFila",byte[].class,false); if(bytes.length!=8) throw contrato();
        StringBuilder b=new StringBuilder(16);
        for(byte v:bytes) { b.append(Character.forDigit((v & 255) >>> 4,16)); b.append(Character.forDigit(v & 15,16)); }
        return b.toString();
    }

    private EventoExploracion mapearEvento( ResultSet rs) throws SQLException {
        EventoExploracion evento = new EventoExploracion();
        evento.setIdEvento( valor(rs, "IdEvento", Integer.class, false) );
        evento.setIdDeporte( valor(rs, "IdDeporte", Integer.class, false) );
        evento.setDeporte( texto(rs, "Deporte", false) );
        evento.setIdLiga( valor(rs, "IdLiga", Integer.class, false) );
        evento.setLiga( texto(rs, "Liga", false) );
        evento.setEvento( texto(rs, "Evento", false) );
        evento.setParticipante1( texto(rs, "Participante1", true) );
        evento.setParticipante2( texto(rs, "Participante2", true) );
        evento.setCantidadParticipantes( valor(rs, "CantidadParticipantes", Integer.class, false) );
        evento.setFechaInicio( obtenerFecha( rs, "FechaInicio" ) );
        evento.setFechaFin( obtenerFecha( rs, "FechaFin" ) );
        evento.setFechaCierreApuestas( obtenerFecha( rs, "FechaCierreApuestas" ) );
        evento.setMinutosParaInicio( valor(rs, "MinutosParaInicio", Integer.class, false) );
        evento.setMinutosParaCierreApuestas( valor(rs, "MinutosParaCierreApuestas", Integer.class, false) );
        evento.setEstadoEvento( texto(rs, "EstadoEvento", false) );
        evento.setEstadoVisual( texto(rs, "EstadoVisual", false) );
        evento.setResultadoPendiente( valor(rs, "ResultadoPendiente", Boolean.class, false) );
        evento.setCantidadMercados( valor(rs, "CantidadMercados", Integer.class, false) );
        evento.setMercadosAbiertos( valor(rs, "MercadosAbiertos", Integer.class, false) );
        evento.setSeleccionesDisponibles( valor(rs, "SeleccionesDisponibles", Integer.class, false) );
        evento.setPuedeApostar( valor(rs, "PuedeApostar", Boolean.class, false) );
        evento.setResultadoTexto( texto(rs, "ResultadoTexto", true) );
        evento.setEstadoResultado( texto(rs, "EstadoResultado", true) );
        return evento;
    }

    private DetalleEventoExploracion mapearDetalleEvento( ResultSet rs) throws SQLException {
        DetalleEventoExploracion detalle = new DetalleEventoExploracion();
        detalle.setIdEvento( valor(rs, "IdEvento", Integer.class, false) );
        detalle.setIdDeporte( valor(rs, "IdDeporte", Integer.class, false) );
        detalle.setDeporte( texto(rs, "Deporte", false) );
        detalle.setIdLiga( valor(rs, "IdLiga", Integer.class, false) );
        detalle.setLiga( texto(rs, "Liga", false) );
        detalle.setEvento( texto(rs, "Evento", false) );
        detalle.setFechaInicio( obtenerFecha( rs, "FechaInicio" ) );
        detalle.setFechaFin( obtenerFecha( rs, "FechaFin" ) );
        detalle.setFechaCierreApuestas( obtenerFecha( rs, "FechaCierreApuestas" ) );
        detalle.setMinutosParaInicio( valor(rs, "MinutosParaInicio", Integer.class, false) );
        detalle.setMinutosParaCierreApuestas( valor(rs, "MinutosParaCierreApuestas", Integer.class, false) );
        detalle.setEstadoEvento( texto(rs, "EstadoEvento", false) );
        detalle.setEstadoVisual( texto(rs, "EstadoVisual", false) );
        detalle.setPuedeApostar( valor(rs, "PuedeApostar", Boolean.class, false) );
        detalle.setCantidadMercados( valor(rs, "CantidadMercados", Integer.class, false) );
        detalle.setCantidadParticipantes( valor(rs, "CantidadParticipantes", Integer.class, false) );
        detalle.setResultadoTexto( texto(rs, "ResultadoTexto", true) );
        detalle.setEstadoResultado( texto(rs, "EstadoResultado", true) );
        detalle.setResultadoPendiente( valor(rs, "ResultadoPendiente", Boolean.class, false) );
        return detalle;
    }

    private ParticipanteExploracion mapearParticipante( ResultSet rs) throws SQLException {
        ParticipanteExploracion participante = new ParticipanteExploracion();
        participante.setIdEventoParticipante( valor(rs, "IdEventoParticipante", Integer.class, false) );
        participante.setOrdenParticipante( orden(rs) );
        participante.setEsLocal( obtenerBooleanNullable( rs, "EsLocal" ) );
        participante.setIdParticipante( valor(rs, "IdParticipante", Integer.class, false) );
        participante.setParticipante( texto(rs, "Participante", false) );
        participante.setTipoParticipante( texto(rs, "TipoParticipante", false) );
        participante.setIdPais( obtenerEnteroNullable( rs, "IdPais" ) );
        participante.setPais( texto(rs, "Pais", true) );
        participante.setCodigoPais( texto(rs, "CodigoPais", true) );
        return participante;
    }

    private MercadoExploracion mapearMercado( ResultSet rs) throws SQLException {
        MercadoExploracion mercado = new MercadoExploracion();
        mercado.setIdMercado( valor(rs, "IdMercado", Integer.class, false) );
        mercado.setMercado( texto(rs, "Mercado", false) );
        mercado.setDescripcionMercado( texto(rs, "DescripcionMercado", true) );
        mercado.setEstadoMercado( texto(rs, "EstadoMercado", false) );
        return mercado;
    }

    private SeleccionExploracion mapearSeleccion( ResultSet rs) throws SQLException {
        SeleccionExploracion seleccion = new SeleccionExploracion();
        seleccion.setIdSeleccion( valor(rs, "IdSeleccion", Integer.class, false) );
        seleccion.setSeleccion( texto(rs, "Seleccion", false) );
        seleccion.setSeleccionActiva( valor(rs, "SeleccionActiva", Boolean.class, false) );
        seleccion.setIdCuota( obtenerEnteroNullable( rs, "IdCuota" ) );
        seleccion.setCuota( valor(rs, "Cuota", java.math.BigDecimal.class, true) );
        seleccion.setFechaInicioCuota( obtenerFecha( rs, "FechaInicioCuota" ) );
        seleccion.setFechaFinCuota( obtenerFecha( rs, "FechaFinCuota" ) );
        seleccion.setCuotaActiva( obtenerBooleanNullable( rs, "CuotaActiva" ) );
        seleccion.setProbabilidadImplicitaPorcentaje( valor(rs, "ProbabilidadImplicitaPorcentaje", java.math.BigDecimal.class, true) );
        seleccion.setResultadoSeleccion( texto(rs, "ResultadoSeleccion", true) );
        seleccion.setFechaResolucion( obtenerFecha( rs, "FechaResolucion" ) );
        seleccion.setPuedeSeleccionar( valor(rs, "PuedeSeleccionar", Boolean.class, false) );
        return seleccion;
    }
}
