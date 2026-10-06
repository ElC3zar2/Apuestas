package com.apuestas.dao;

import com.apuestas.modelo.AdministracionEventosModelos.*;
import com.apuestas.modelo.OperacionAdministracionEventos;
import java.sql.*;
import java.time.LocalDateTime;
import java.math.BigDecimal;
import java.util.*;

/** Un procedimiento y una fila por accion. No ejecuta SQL de escritura directo. */
public class AdministracionEventosDAO {
    protected Connection obtenerConexion() throws SQLException { return ConexionBD.obtenerConexion(); }
    private static SQLException contrato() { return new SQLException("Respuesta administrativa inconsistente."); }

    public Resultado ejecutar(OperacionAdministracionEventos op,int actor,Solicitud s,String ip) throws SQLException {
        Objects.requireNonNull(op);Objects.requireNonNull(s);
        int cantidad=op.parametros.size()+2;
        String sql="{call dbo."+op.procedimiento+"("+String.join(", ",Collections.nCopies(cantidad,"?"))+")}";
        try(Connection c=obtenerConexion();CallableStatement cs=c.prepareCall(sql)) {
            cs.setInt(1,actor);
            switch(op) {
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
                    else cs.setTimestamp(5,Timestamp.valueOf(s.fechaFin));break;
                case AGREGAR_PARTICIPANTE:
                    cs.setInt(2,s.idEvento);cs.setInt(3,s.idParticipante);cs.setInt(4,s.ordenParticipante);
                    if(s.esLocal==null) cs.setNull(5,Types.BIT);else cs.setBoolean(5,s.esLocal);break;
                case CREAR_MERCADO:
                    cs.setInt(2,s.idEvento);cs.setString(3,s.nombre);cadena(cs,4,s.descripcion);break;
                case CREAR_SELECCION:
                    cs.setInt(2,s.idMercado);cs.setString(3,s.nombre);break;
                case REGISTRAR_CUOTA:
                    cs.setInt(2,s.idSeleccion);cs.setBigDecimal(3,s.valor);break;
                case ESTADO_EVENTO:case ESTADO_MERCADO:
                    cs.setInt(2,op==OperacionAdministracionEventos.ESTADO_EVENTO?s.idEvento:s.idMercado);
                    cs.setString(3,s.nuevoEstado);cadena(cs,4,s.motivo);break;
                default:throw new IllegalArgumentException();
            }
            cadena(cs,cantidad,ip);
            if(!siguiente(cs,true)) throw contrato();
            Resultado resultado;
            try(ResultSet rs=cs.getResultSet()) {
                if(rs==null||!rs.next()) throw contrato();
                resultado=leer(op,s,rs);
                if(rs.next()) throw contrato();
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
    private static Integer id(ResultSet rs,String columna,boolean nullable) throws SQLException {
        int v=rs.getInt(columna);
        if(rs.wasNull()) { if(nullable) return null;throw contrato(); }
        if(v<=0) throw contrato();
        return v;
    }
    private static String texto(ResultSet rs,String columna,boolean nullable) throws SQLException {
        String v=rs.getString(columna);
        if(!nullable&&(v==null||v.trim().isEmpty())) throw contrato();
        return v;
    }
    private static Boolean bit(ResultSet rs,String columna,boolean nullable) throws SQLException {
        boolean v=rs.getBoolean(columna);
        if(rs.wasNull()) { if(nullable) return null;throw contrato(); }
        return v;
    }
    private static LocalDateTime fecha(ResultSet rs,String columna,boolean nullable) throws SQLException {
        Timestamp v=rs.getTimestamp(columna);
        if(v==null&&!nullable) throw contrato();
        return v==null?null:v.toLocalDateTime();
    }
    private static void igual(Object esperado,Object real) throws SQLException {
        if(!Objects.equals(esperado,real)) throw contrato();
    }

    private static Resultado leer(OperacionAdministracionEventos op,Solicitud s,ResultSet rs) throws SQLException {
        switch(op) {
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
                r.idCuotaAnterior=id(rs,"IdCuotaAnterior",true);r.valor=rs.getBigDecimal("Valor");
                r.fechaInicio=fecha(rs,"FechaInicio",false);r.activo=bit(rs,"Activo",false);
                igual(s.idSeleccion,r.idSeleccion);igual(true,r.activo);
                if(r.valor==null||r.valor.compareTo(s.valor)!=0||r.valor.scale()>4
                        ||r.valor.compareTo(BigDecimal.ONE)<=0||r.valor.compareTo(new BigDecimal("999999.9999"))>0
                        ||r.idCuota.equals(r.idCuotaAnterior)) throw contrato();
                return r;
            }
            case ESTADO_EVENTO: {
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
            default:throw contrato();
        }
    }
}