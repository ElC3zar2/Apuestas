package com.apuestas.dao;

import com.apuestas.modelo.AdministracionEventosModelos.*;
import com.apuestas.modelo.OperacionAdministracionEventos;
import java.sql.*;
import java.time.LocalDateTime;
import java.math.BigDecimal;
import java.util.*;

/** Procedimientos cerrados y resultados oficiales; sin escrituras ni transacciones Java. */
public class AdministracionEventosDAO {
    protected Connection obtenerConexion() throws SQLException { return ConexionBD.obtenerConexion(); }
    private static SQLException contrato() { return new SQLException("Respuesta administrativa inconsistente."); }

    public Resultado ejecutar(OperacionAdministracionEventos op,int actor,Solicitud s,String ip) throws SQLException {
        Objects.requireNonNull(op);Objects.requireNonNull(s);
        int cantidad=op==OperacionAdministracionEventos.ESTADO_SIMULACION?1:op.parametros.size()+2;
        String sql="{call dbo."+op.procedimiento+"("+String.join(", ",Collections.nCopies(cantidad,"?"))+")}";
        try(Connection c=obtenerConexion();CallableStatement cs=c.prepareCall(sql)) {
            if(op==OperacionAdministracionEventos.ESTADO_SIMULACION) {
                cs.setInt(1,s.idEvento);return leerSimulacion(cs,s.idEvento);
            }
            cs.setInt(1,actor);
            int posicionIp=cantidad;
            switch(op) {
                case RECONCILIAR_CIERRE_MERCADOS:
                    cs.setInt(2,s.idEvento);break;
                case CONSULTAR_PLANTILLA_1X2:
                    cs.setInt(2,s.idDeporte);break;
                case GUARDAR_PLANTILLA_1X2:
                    cs.setInt(2,s.idDeporte);decimal(cs,3,s.cuotaLocal);decimal(cs,4,s.cuotaEmpate);decimal(cs,5,s.cuotaVisitante);
                    cs.setBoolean(6,s.habilitada);cs.setBoolean(7,s.aprobada);
                    cadena(cs,8,s.versionEsperada==null?null:s.versionEsperada.toString());cs.setString(9,s.referenciaOperacion.toString());break;
                case CREAR_CONVENCIONAL_1X2:
                    cs.setInt(2,s.idDeporte);cs.setInt(3,s.idLiga);cs.setInt(4,s.idParticipanteLocal);cs.setInt(5,s.idParticipanteVisitante);
                    cs.setTimestamp(6,Timestamp.valueOf(s.fechaInicio));cs.setString(7,s.versionPlantilla.toString());
                    cs.setString(8,s.referenciaOperacion.toString());break;
                case CREAR_LIGA:
                    cs.setInt(2,s.idDeporte);cs.setString(3,s.nombre);entero(cs,4,s.idPais);break;
                case ACTUALIZAR_LIGA:
                    cs.setInt(2,s.idLiga);cs.setString(3,s.nombre);entero(cs,4,s.idPais);cs.setBoolean(5,s.activo);break;
                case CREAR_PARTICIPANTE:
                    cs.setInt(2,s.idDeporte);cs.setString(3,s.nombre);cs.setString(4,s.tipoParticipante);entero(cs,5,s.idPais);break;
                case ACTUALIZAR_PARTICIPANTE:
                    cs.setInt(2,s.idParticipante);cs.setString(3,s.nombre);entero(cs,4,s.idPais);cs.setBoolean(5,s.activo);break;
                case CREAR_EVENTO:case ACTUALIZAR_EVENTO:
                    cs.setInt(2,op==OperacionAdministracionEventos.CREAR_EVENTO?s.idLiga:s.idEvento);
                    cs.setString(3,s.nombre);cs.setTimestamp(4,Timestamp.valueOf(s.fechaInicio));
                    if(s.fechaFin==null) cs.setNull(5,Types.TIMESTAMP);
                    else cs.setTimestamp(5,Timestamp.valueOf(s.fechaFin));
                    if(op==OperacionAdministracionEventos.CREAR_EVENTO) {
                        posicionIp=6;cs.setBoolean(7,s.esSimulado);entero(cs,8,s.duracionSimulacionSegundos);
                    }break;
                case ASOCIAR_PARTICIPANTE_LIGA:case DESASOCIAR_PARTICIPANTE_LIGA:
                    cs.setInt(2,s.idLiga);cs.setInt(3,s.idParticipante);break;
                case AGREGAR_PARTICIPANTE:
                    cs.setInt(2,s.idEvento);cs.setInt(3,s.idParticipante);cs.setInt(4,s.ordenParticipante);
                    if(s.esLocal==null) cs.setNull(5,Types.BIT);else cs.setBoolean(5,s.esLocal);break;
                case CREAR_MERCADO:
                    cs.setInt(2,s.idEvento);cs.setString(3,s.nombre);cadena(cs,4,s.descripcion);
                    posicionIp=5;cs.setString(6,s.tipoMercado);break;
                case CREAR_SELECCION:
                    cs.setInt(2,s.idMercado);cs.setString(3,s.nombre);posicionIp=4;entero(cs,5,s.idParticipante);break;
                case REGISTRAR_CUOTA:
                    cs.setInt(2,s.idSeleccion);decimal(cs,3,s.valor);posicionIp=4;decimal(cs,5,s.valorResultado);break;
                case ESTADO_EVENTO:case ESTADO_MERCADO:
                    cs.setInt(2,op==OperacionAdministracionEventos.ESTADO_EVENTO?s.idEvento:s.idMercado);
                    cs.setString(3,s.nuevoEstado);cadena(cs,4,s.motivo);break;
                case REGISTRAR_INCIDENCIA:
                    cs.setInt(2,s.idEvento);cs.setString(3,s.tipoIncidencia);cs.setString(4,s.referenciaOperacion.toString());
                    entero(cs,5,s.idParticipante);entero(cs,6,s.valorAnotacion);cadena(cs,7,s.descripcion);break;
                case ANULAR_INCIDENCIA:
                    cs.setLong(2,s.idIncidencia);cs.setString(3,s.motivo);break;
                default:throw new IllegalArgumentException();
            }
            cadena(cs,posicionIp,ip);
            if(!siguiente(cs,true)) throw contrato();
            Resultado resultado;
            try(ResultSet rs=cs.getResultSet()) {
                if(rs==null||!rs.next()) throw contrato();
                resultado=leer(op,s,rs);
                if(rs.next()) throw contrato();
            }
            if(resultado instanceof ResultadoSimulacion) {
                ResultadoSimulacion registrado=(ResultadoSimulacion)resultado;
                if(!siguiente(cs,false))throw contrato();
                try(ResultSet rs=cs.getResultSet()) {
                    if(rs==null || !rs.next())throw contrato();
                    EstadoSimulacionCambiado finalizacion=abreviado(s,rs);
                    finalizacion.registrado=registrado;resultado=finalizacion;
                    if(rs.next())throw contrato();
                }
            }
            if(siguiente(cs,false)) {
                try(ResultSet extra=cs.getResultSet()) { throw contrato(); }
            }
            return resultado;
        }
    }
    private static boolean siguiente(CallableStatement cs,boolean primero) throws SQLException {
        boolean resultado=primero?cs.execute():cs.getMoreResults();
        while(!resultado&&cs.getUpdateCount()!=-1) resultado=cs.getMoreResults();
        return resultado;
    }
    private static void entero(CallableStatement cs,int pos,Integer valor) throws SQLException {
        if(valor==null) cs.setNull(pos,Types.INTEGER);else cs.setInt(pos,valor);
    }
    private static void cadena(CallableStatement cs,int pos,String valor) throws SQLException {
        if(valor==null) cs.setNull(pos,Types.VARCHAR);else cs.setString(pos,valor);
    }
    private static void decimal(CallableStatement cs,int pos,BigDecimal valor)throws SQLException {
        if(valor==null)cs.setNull(pos,Types.DECIMAL);else cs.setBigDecimal(pos,valor);
    }
    private static <T>T dato(ResultSet rs,String columna,Class<T> tipo,boolean nullable)throws SQLException {
        Object v=rs.getObject(columna);
        if(v==null && nullable)return null;
        if(!tipo.isInstance(v))throw contrato();return tipo.cast(v);
    }
    private static Integer id(ResultSet rs,String columna,boolean nullable)throws SQLException {
        Integer v;
        if(columna.equals("OrdenParticipante")) {
            Object objeto=rs.getObject(columna);
            if(objeto instanceof Short)v=((Short)objeto).intValue();
            else if(objeto instanceof Integer)v=(Integer)objeto;else throw contrato();
            if(v>255)throw contrato();
        }else v=dato(rs,columna,Integer.class,nullable);
        if(v!=null && v<=0)throw contrato();return v;
    }
    private static String texto(ResultSet rs,String columna,boolean nullable)throws SQLException {
        String v=dato(rs,columna,String.class,nullable);
        if(!nullable && v.trim().isEmpty())throw contrato();return v;
    }
    private static Boolean bit(ResultSet rs,String columna,boolean nullable)throws SQLException { return dato(rs,columna,Boolean.class,nullable); }
    private static LocalDateTime fecha(ResultSet rs,String columna,boolean nullable)throws SQLException {
        Timestamp v=dato(rs,columna,Timestamp.class,nullable);return v==null?null:v.toLocalDateTime();
    }
    private static boolean columna(ResultSet rs,String nombre)throws SQLException {
        ResultSetMetaData md=rs.getMetaData();for(int i=1;i<=md.getColumnCount();i++)if(nombre.equalsIgnoreCase(md.getColumnLabel(i)))return true;return false;
    }
    private static EstadoSimulacionCambiado abreviado(Solicitud s,ResultSet rs)throws SQLException {
        EstadoSimulacionCambiado r=new EstadoSimulacionCambiado();r.idEvento=id(rs,"IdEvento",false);r.sinCambios=bit(rs,"SinCambios",false);
        igual(s.idEvento,r.idEvento);return r;
    }
    private static void igual(Object esperado,Object real) throws SQLException {
        if(!Objects.equals(esperado,real)) throw contrato();
    }

    private static Resultado leer(OperacionAdministracionEventos op,Solicitud s,ResultSet rs) throws SQLException {
        switch(op) {
            case RECONCILIAR_CIERRE_MERCADOS: {
                CierreMercadosReconciliado r=new CierreMercadosReconciliado();
                r.idEvento=id(rs,"IdEvento",false);igual(s.idEvento,r.idEvento);
                r.estadoEvento=texto(rs,"EstadoEvento",false);
                if(!Arrays.asList("EN_VIVO","PENDIENTE_RESULTADO").contains(r.estadoEvento))throw contrato();
                r.cantidadMercados=dato(rs,"CantidadMercados",Integer.class,false);
                r.mercadosCerrados=dato(rs,"MercadosCerrados",Integer.class,false);
                r.cuotasDesactivadas=dato(rs,"CuotasDesactivadas",Integer.class,false);
                r.mercadosIncompatiblesRestantes=dato(rs,"MercadosIncompatiblesRestantes",Integer.class,false);
                r.sinCambios=bit(rs,"SinCambios",false);
                if(r.cantidadMercados<0||r.mercadosCerrados<0||r.cuotasDesactivadas<0
                    ||r.mercadosCerrados>r.cantidadMercados||r.mercadosIncompatiblesRestantes!=0
                    ||(r.cantidadMercados==0&&r.cuotasDesactivadas!=0))throw contrato();
                igual(r.mercadosCerrados==0&&r.cuotasDesactivadas==0,r.sinCambios);
                return r;
            }
            case CONSULTAR_PLANTILLA_1X2:case GUARDAR_PLANTILLA_1X2: {
                Plantilla1X2 r=new Plantilla1X2();r.idDeporte=id(rs,"IdDeporte",false);igual(s.idDeporte,r.idDeporte);
                r.identidadPlantilla=texto(rs,"IdentidadPlantilla",false);igual("BETZONE_1X2:"+s.idDeporte,r.identidadPlantilla);
                r.existe=bit(rs,"Existe",false);r.valida=bit(rs,"Valida",false);r.habilitada=bit(rs,"Habilitada",false);r.aprobada=bit(rs,"Aprobada",false);
                r.versionPlantilla=texto(rs,"VersionPlantilla",true);
                UUID versionPlantilla=r.versionPlantilla==null?null:validarUuid(r.versionPlantilla);
                if(versionPlantilla!=null)r.versionPlantilla=versionPlantilla.toString();
                r.cuotaLocal=dato(rs,"CuotaLocal",BigDecimal.class,true);r.cuotaEmpate=dato(rs,"CuotaEmpate",BigDecimal.class,true);r.cuotaVisitante=dato(rs,"CuotaVisitante",BigDecimal.class,true);
                if(r.valida) {
                    if(!r.existe||versionPlantilla==null)throw contrato();cuota1X2(r.cuotaLocal);cuota1X2(r.cuotaEmpate);cuota1X2(r.cuotaVisitante);
                }
                if(op==OperacionAdministracionEventos.GUARDAR_PLANTILLA_1X2) {
                    igual(true,r.valida);igual(s.referenciaOperacion,versionPlantilla);
                    igual(s.habilitada,r.habilitada);igual(s.aprobada,r.aprobada);
                    if(r.cuotaLocal.compareTo(s.cuotaLocal)!=0||r.cuotaEmpate.compareTo(s.cuotaEmpate)!=0||r.cuotaVisitante.compareTo(s.cuotaVisitante)!=0)throw contrato();
                }
                return r;
            }
            case CREAR_CONVENCIONAL_1X2: {
                EventoConvencional1X2 r=new EventoConvencional1X2();
                r.idEvento=id(rs,"IdEvento",false);r.idDeporte=id(rs,"IdDeporte",false);r.idLiga=id(rs,"IdLiga",false);
                r.idParticipanteLocal=id(rs,"IdParticipanteLocal",false);r.idParticipanteVisitante=id(rs,"IdParticipanteVisitante",false);
                r.idMercado=id(rs,"IdMercado",false);r.idSeleccionLocal=id(rs,"IdSeleccionLocal",false);
                r.idSeleccionEmpate=id(rs,"IdSeleccionEmpate",false);r.idSeleccionVisitante=id(rs,"IdSeleccionVisitante",false);
                igual(s.idDeporte,r.idDeporte);igual(s.idLiga,r.idLiga);igual(s.idParticipanteLocal,r.idParticipanteLocal);igual(s.idParticipanteVisitante,r.idParticipanteVisitante);
                if(new HashSet<>(Arrays.asList(r.idSeleccionLocal,r.idSeleccionEmpate,r.idSeleccionVisitante)).size()!=3)throw contrato();
                r.fechaInicio=fecha(rs,"FechaInicio",false);igual(s.fechaInicio,r.fechaInicio);
                r.nombre=texto(rs,"Nombre",false);r.deporte=texto(rs,"Deporte",false);r.liga=texto(rs,"Liga",false);
                r.local=texto(rs,"Local",false);r.visitante=texto(rs,"Visitante",false);
                r.estadoEvento=texto(rs,"EstadoEvento",false);r.tipoMercado=texto(rs,"TipoMercado",false);r.estadoMercado=texto(rs,"EstadoMercado",false);
                igual("PROGRAMADO",r.estadoEvento);igual("CONVENCIONAL",r.tipoMercado);igual("ABIERTO",r.estadoMercado);
                r.cuotaLocal=dato(rs,"CuotaLocal",BigDecimal.class,false);r.cuotaEmpate=dato(rs,"CuotaEmpate",BigDecimal.class,false);r.cuotaVisitante=dato(rs,"CuotaVisitante",BigDecimal.class,false);
                cuota1X2(r.cuotaLocal);cuota1X2(r.cuotaEmpate);cuota1X2(r.cuotaVisitante);
                UUID referenciaOperacion=validarUuid(texto(rs,"ReferenciaOperacion",false));igual(s.referenciaOperacion,referenciaOperacion);
                r.referenciaOperacion=referenciaOperacion.toString();
                r.identidadPlantilla=texto(rs,"IdentidadPlantilla",false);igual("BETZONE_1X2:"+s.idDeporte,r.identidadPlantilla);
                UUID versionPlantilla=validarUuid(texto(rs,"VersionPlantilla",false));igual(s.versionPlantilla,versionPlantilla);
                r.versionPlantilla=versionPlantilla.toString();
                r.solicitudIdempotente=bit(rs,"SolicitudIdempotente",false);r.disponibleParaApuestas=bit(rs,"DisponibleParaApuestas",false);
                r.estadoEventoActual=texto(rs,"EstadoEventoActual",false);r.estadoMercadoActual=texto(rs,"EstadoMercadoActual",false);
                if(!com.apuestas.servicio.AdministracionEventosServicio.estadosEvento().contains(r.estadoEventoActual)
                    ||!com.apuestas.servicio.AdministracionEventosServicio.estadosMercado().contains(r.estadoMercadoActual)
                    ||(r.disponibleParaApuestas&&(!"PROGRAMADO".equals(r.estadoEventoActual)||!"ABIERTO".equals(r.estadoMercadoActual))))throw contrato();
                return r;
            }
            case CREAR_LIGA:case ACTUALIZAR_LIGA: {
                Liga r=new Liga();
                r.idLiga=id(rs,"IdLiga",false);r.idDeporte=id(rs,"IdDeporte",false);
                r.idPais=id(rs,"IdPais",true);r.nombre=texto(rs,"Nombre",false);r.activo=bit(rs,"Activo",false);
                igual(s.nombre,r.nombre);igual(s.idPais,r.idPais);
                if(op==OperacionAdministracionEventos.CREAR_LIGA) { igual(s.idDeporte,r.idDeporte);igual(true,r.activo); }
                else { igual(s.idLiga,r.idLiga);igual(s.activo,r.activo); }
                return r;
            }
            case CREAR_PARTICIPANTE:case ACTUALIZAR_PARTICIPANTE: {
                Participante r=new Participante();
                r.idParticipante=id(rs,"IdParticipante",false);r.idDeporte=id(rs,"IdDeporte",false);
                r.idPais=id(rs,"IdPais",true);r.nombre=texto(rs,"Nombre",false);
                r.tipoParticipante=texto(rs,"TipoParticipante",false);r.activo=bit(rs,"Activo",false);
                if(!Arrays.asList("EQUIPO","ATLETA").contains(r.tipoParticipante)) throw contrato();
                igual(s.nombre,r.nombre);igual(s.idPais,r.idPais);
                if(op==OperacionAdministracionEventos.CREAR_PARTICIPANTE) {
                    igual(s.idDeporte,r.idDeporte);igual(s.tipoParticipante,r.tipoParticipante);igual(true,r.activo);
                } else { igual(s.idParticipante,r.idParticipante);igual(s.activo,r.activo); }
                return r;
            }
            case CREAR_EVENTO:case ACTUALIZAR_EVENTO: {
                Evento r=new Evento();
                r.idEvento=id(rs,"IdEvento",false);r.idLiga=id(rs,"IdLiga",false);r.idEstado=id(rs,"IdEstado",false);
                r.nombre=texto(rs,"Nombre",false);r.estadoEvento=texto(rs,"EstadoEvento",false);
                r.fechaInicio=fecha(rs,"FechaInicio",false);r.fechaFin=fecha(rs,"FechaFin",true);
                igual(s.nombre,r.nombre);igual(s.fechaInicio,r.fechaInicio);igual(s.fechaFin,r.fechaFin);
                if(op==OperacionAdministracionEventos.CREAR_EVENTO) { igual(s.idLiga,r.idLiga);igual("BORRADOR",r.estadoEvento); }
                else igual(s.idEvento,r.idEvento);
                return r;
            }
            case ASOCIAR_PARTICIPANTE_LIGA:case DESASOCIAR_PARTICIPANTE_LIGA: {
                LigaParticipante r=new LigaParticipante();
                r.idLiga=id(rs,"IdLiga",false);r.idParticipante=id(rs,"IdParticipante",false);r.activo=bit(rs,"Activo",false);
                igual(s.idLiga,r.idLiga);igual(s.idParticipante,r.idParticipante);
                igual(op==OperacionAdministracionEventos.ASOCIAR_PARTICIPANTE_LIGA,r.activo);return r;
            }
            case AGREGAR_PARTICIPANTE: {
                AsociacionParticipante r=new AsociacionParticipante();
                r.idEventoParticipante=id(rs,"IdEventoParticipante",false);r.idEvento=id(rs,"IdEvento",false);
                r.idParticipante=id(rs,"IdParticipante",false);r.ordenParticipante=id(rs,"OrdenParticipante",false);
                r.esLocal=bit(rs,"EsLocal",true);
                igual(s.idEvento,r.idEvento);igual(s.idParticipante,r.idParticipante);
                igual(s.ordenParticipante,r.ordenParticipante);igual(s.esLocal,r.esLocal);
                return r;
            }
            case CREAR_MERCADO: {
                Mercado r=new Mercado();
                r.idMercado=id(rs,"IdMercado",false);r.idEvento=id(rs,"IdEvento",false);r.idEstado=id(rs,"IdEstado",false);
                r.estadoMercado=texto(rs,"EstadoMercado",false);r.nombre=texto(rs,"Nombre",false);
                r.descripcion=texto(rs,"Descripcion",true);
                igual(s.idEvento,r.idEvento);igual(s.nombre,r.nombre);igual(s.descripcion,r.descripcion);
                igual("BORRADOR",r.estadoMercado);return r;
            }
            case CREAR_SELECCION: {
                Seleccion r=new Seleccion();
                r.idSeleccion=id(rs,"IdSeleccion",false);r.idMercado=id(rs,"IdMercado",false);
                r.nombre=texto(rs,"Nombre",false);r.activo=bit(rs,"Activo",false);
                igual(s.idMercado,r.idMercado);igual(s.nombre,r.nombre);igual(true,r.activo);return r;
            }
            case REGISTRAR_CUOTA: {
                Cuota r=new Cuota();
                r.idCuota=id(rs,"IdCuota",false);r.idSeleccion=id(rs,"IdSeleccion",false);
                r.idCuotaAnterior=id(rs,"IdCuotaAnterior",true);r.valor=dato(rs,"Valor",BigDecimal.class,false);
                r.fechaInicio=fecha(rs,"FechaInicio",false);r.activo=bit(rs,"Activo",false);
                igual(s.idSeleccion,r.idSeleccion);igual(true,r.activo);
                if(r.valor==null||(s.valor!=null && r.valor.compareTo(s.valor)!=0)||r.valor.scale()>4
                        ||r.valor.compareTo(BigDecimal.ONE)<=0||r.valor.compareTo(new BigDecimal("999999.9999"))>0
                        ||r.idCuota.equals(r.idCuotaAnterior)) throw contrato();
                return r;
            }
            case ESTADO_EVENTO: {
                if(columna(rs,"ResultadoTexto")) {
                    if(!"PENDIENTE_RESULTADO".equals(s.nuevoEstado))throw contrato();
                    ResultadoSimulacion r=new ResultadoSimulacion();r.idResultado=id(rs,"IdResultado",false);r.idEvento=id(rs,"IdEvento",false);
                    r.estadoResultado=texto(rs,"EstadoResultado",false);r.resultadoTexto=texto(rs,"ResultadoTexto",false);r.observacion=texto(rs,"Observacion",true);
                    igual(s.idEvento,r.idEvento);
                    if(!Arrays.asList("PENDIENTE","CORREGIDO").contains(r.estadoResultado))throw contrato();return r;
                }
                if(columna(rs,"EstadoEvento")) {
                    if(!"CANCELADO".equals(s.nuevoEstado))throw contrato();
                    EventoCancelado r=new EventoCancelado();r.idResultado=id(rs,"IdResultado",false);r.idEvento=id(rs,"IdEvento",false);
                    r.estadoResultado=texto(rs,"EstadoResultado",false);r.estadoEvento=texto(rs,"EstadoEvento",false);r.sinCambios=bit(rs,"SinCambios",false);
                    igual(s.idEvento,r.idEvento);igual("CANCELADO",r.estadoEvento);igual("ANULADO",r.estadoResultado);return r;
                }
                if(!columna(rs,"EstadoAnterior")) {
                    if(!Arrays.asList("EN_VIVO","PENDIENTE_RESULTADO").contains(s.nuevoEstado))throw contrato();
                    return abreviado(s,rs);
                }
                EstadoEvento r=new EstadoEvento();
                r.idEvento=id(rs,"IdEvento",false);r.estadoAnterior=texto(rs,"EstadoAnterior",false);
                r.estadoActual=texto(rs,"EstadoActual",false);r.sinCambios=bit(rs,"SinCambios",false);
                igual(s.idEvento,r.idEvento);igual(s.nuevoEstado,r.estadoActual);
                igual(r.estadoAnterior.equals(r.estadoActual),r.sinCambios);return r;
            }
            case ESTADO_MERCADO: {
                EstadoMercado r=new EstadoMercado();
                r.idMercado=id(rs,"IdMercado",false);r.estadoAnterior=texto(rs,"EstadoAnterior",false);
                r.estadoActual=texto(rs,"EstadoActual",false);r.sinCambios=bit(rs,"SinCambios",false);
                igual(s.idMercado,r.idMercado);igual(s.nuevoEstado,r.estadoActual);
                igual(r.estadoAnterior.equals(r.estadoActual),r.sinCambios);return r;
            }
            case REGISTRAR_INCIDENCIA: {
                IncidenciaRegistrada r=new IncidenciaRegistrada();r.idIncidencia=dato(rs,"IdIncidencia",Long.class,false);
                r.solicitudIdempotente=bit(rs,"SolicitudIdempotente",false);if(r.idIncidencia<=0)throw contrato();return r;
            }
            case ANULAR_INCIDENCIA: {
                IncidenciaAnulada r=new IncidenciaAnulada();r.idIncidencia=dato(rs,"IdIncidencia",Long.class,false);
                r.sinCambios=bit(rs,"SinCambios",false);igual(s.idIncidencia,r.idIncidencia);return r;
            }
            default:throw contrato();
        }
    }
    private static ResultSet resultadoConsulta(CallableStatement cs,boolean primero,String columnas)throws SQLException {
        if(!siguiente(cs,primero))throw contrato();ResultSet rs=cs.getResultSet();if(rs==null)throw contrato();
        try{for(String nombre:columnas.split(","))if(!columna(rs,nombre))throw contrato();return rs;}
        catch(SQLException | RuntimeException e){rs.close();throw e;}
    }
    private static void cuota1X2(BigDecimal valor)throws SQLException {
        if(valor==null||valor.scale()>4||valor.compareTo(BigDecimal.ONE)<=0||valor.compareTo(new BigDecimal("999999.9999"))>0)throw contrato();
    }
    private static UUID validarUuid(String valor)throws SQLException {
        if(valor==null||!valor.matches("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"))throw contrato();
        return UUID.fromString(valor);
    }
    private static String version(ResultSet rs)throws SQLException {
        byte[] bytes=dato(rs,"VersionFila",byte[].class,false);if(bytes.length!=8)throw contrato();
        StringBuilder hex=new StringBuilder();for(byte b:bytes)hex.append(String.format(Locale.ROOT,"%02x",b & 255));return hex.toString();
    }
    private static EstadoSimulacion leerSimulacion(CallableStatement cs,int evento)throws SQLException {
        EstadoSimulacion r=null;
        try(ResultSet rs=resultadoConsulta(cs,true,"IdEvento,Nombre,EstadoEvento,EsSimulado,DuracionSimulacionSegundos,FechaInicioRealUtc,FechaFinRealUtc,VersionFila,SegundosTranscurridos,TiempoVisualCumplido,IdPrimeraAnotacion,IdPrimerParticipanteAnotador")) {
            if(rs.next()) {
                r=new EstadoSimulacion();r.idEvento=id(rs,"IdEvento",false);igual(evento,r.idEvento);
                r.nombre=texto(rs,"Nombre",false);r.estadoEvento=texto(rs,"EstadoEvento",false);
                r.esSimulado=bit(rs,"EsSimulado",false);r.duracionSimulacionSegundos=dato(rs,"DuracionSimulacionSegundos",Integer.class,true);
                r.fechaInicioRealUtc=fecha(rs,"FechaInicioRealUtc",true);r.fechaFinRealUtc=fecha(rs,"FechaFinRealUtc",true);r.versionFila=version(rs);
                r.segundosTranscurridos=dato(rs,"SegundosTranscurridos",Integer.class,false);r.tiempoVisualCumplido=bit(rs,"TiempoVisualCumplido",false);
                r.idPrimeraAnotacion=dato(rs,"IdPrimeraAnotacion",Long.class,true);r.idPrimerParticipanteAnotador=id(rs,"IdPrimerParticipanteAnotador",true);
                if(rs.next())throw contrato();
            }
        }
        Set<Integer> participantes=new HashSet<>(),ordenes=new HashSet<>();
        try(ResultSet rs=resultadoConsulta(cs,false,"OrdenParticipante,IdParticipante,Nombre,MarcadorActual")) {
            while(rs.next()) {
                if(r==null)throw contrato();ParticipanteSimulacion p=new ParticipanteSimulacion();
                p.ordenParticipante=id(rs,"OrdenParticipante",false);p.idParticipante=id(rs,"IdParticipante",false);
                p.nombre=texto(rs,"Nombre",false);p.marcadorActual=dato(rs,"MarcadorActual",Integer.class,true);
                if(!participantes.add(p.idParticipante) || !ordenes.add(p.ordenParticipante) || (p.marcadorActual!=null && p.marcadorActual<0))throw contrato();
                r.participantes.add(p);
            }
        }
        Set<Long> ids=new HashSet<>();Set<Integer> secuencias=new HashSet<>();
        try(ResultSet rs=resultadoConsulta(cs,false,"IdIncidencia,Secuencia,TipoIncidencia,IdParticipante,ValorAnotacion,SegundoSimulacion,FechaRegistroUtc,Descripcion,EsAnulada,MotivoAnulacion,FechaAnulacionUtc,VersionFila")) {
            while(rs.next()) {
                if(r==null)throw contrato();com.apuestas.modelo.IncidenciaEventoExploracion i=new com.apuestas.modelo.IncidenciaEventoExploracion();
                Long identificador=dato(rs,"IdIncidencia",Long.class,false);if(identificador<=0 || !ids.add(identificador))throw contrato();i.setIdIncidencia(identificador);
                i.setSecuencia(id(rs,"Secuencia",false));if(!secuencias.add(i.getSecuencia()))throw contrato();
                i.setTipoIncidencia(texto(rs,"TipoIncidencia",false));
                if(!Arrays.asList("ANOTACION","FALTA","TARJETA_AMARILLA","TARJETA_ROJA","OTRA").contains(i.getTipoIncidencia()))throw contrato();
                i.setIdParticipante(id(rs,"IdParticipante",true));if(i.getIdParticipante()!=null && !participantes.contains(i.getIdParticipante()))throw contrato();
                i.setValorAnotacion(dato(rs,"ValorAnotacion",Integer.class,true));i.setSegundoSimulacion(dato(rs,"SegundoSimulacion",Integer.class,false));
                if(i.getSegundoSimulacion()<0)throw contrato();i.setFechaRegistroUtc(fecha(rs,"FechaRegistroUtc",false));
                i.setDescripcion(texto(rs,"Descripcion",true));i.setEsAnulada(bit(rs,"EsAnulada",false));
                i.setMotivoAnulacion(texto(rs,"MotivoAnulacion",true));i.setFechaAnulacionUtc(fecha(rs,"FechaAnulacionUtc",true));i.setVersionFila(version(rs));r.incidencias.add(i);
            }
        }
        if(r!=null) {
            if((r.idPrimeraAnotacion==null)!=(r.idPrimerParticipanteAnotador==null))throw contrato();
            if(r.idPrimeraAnotacion!=null) {
                com.apuestas.modelo.IncidenciaEventoExploracion primera=null;
                for(com.apuestas.modelo.IncidenciaEventoExploracion i:r.incidencias)if(r.idPrimeraAnotacion.equals(i.getIdIncidencia()))primera=i;
                if(primera==null || primera.getEsAnulada() || !"ANOTACION".equals(primera.getTipoIncidencia()) || !r.idPrimerParticipanteAnotador.equals(primera.getIdParticipante()))throw contrato();
            }
        }
        if(siguiente(cs,false)){try(ResultSet extra=cs.getResultSet()){throw contrato();}}return r;
    }
}
