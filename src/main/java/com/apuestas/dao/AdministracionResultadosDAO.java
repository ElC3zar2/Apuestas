package com.apuestas.dao;

import com.apuestas.modelo.AdministracionResultadosModelos.*;
import com.apuestas.modelo.OperacionAdministracionResultados;
import java.sql.*;
import java.util.*;

/** Los POST llaman un SP; la consulta por evento usa SELECT. SQL conserva las transacciones. */
public class AdministracionResultadosDAO {
    protected Connection obtenerConexion() throws SQLException { return ConexionBD.obtenerConexion(); }
    private static SQLException contrato() { return new SQLException("Respuesta de resultados inconsistente."); }

    /** SELECT de solo lectura; null significa evento inexistente, nunca resultado ausente. */
    public com.apuestas.modelo.ConsultaResultadoEvento consultarPorEvento(int idEvento) throws SQLException {
        if(idEvento<=0) throw new IllegalArgumentException();
        String sql="SELECT EV.IdEvento, EE.Codigo AS EstadoEvento, TE.Codigo AS TipoEstadoEvento, "
                +"RE.IdResultado, RE.IdEvento AS IdEventoResultado, ER.Codigo AS EstadoResultado, "
                +"TR.Codigo AS TipoEstadoResultado, RE.ResultadoTexto, RE.Observacion, RE.FechaRegistro, "
                +"RE.MarcadorFinalA, RE.MarcadorFinalB, RE.IdIncidenciaPrimeraAnotacion "
                +"FROM dbo.Evento EV LEFT JOIN dbo.Estado EE ON EE.IdEstado=EV.IdEstado "
                +"LEFT JOIN dbo.TipoEstado TE ON TE.IdTipoEstado=EE.IdTipoEstado "
                +"LEFT JOIN dbo.ResultadoEvento RE ON RE.IdEvento=EV.IdEvento "
                +"LEFT JOIN dbo.Estado ER ON ER.IdEstado=RE.IdEstado "
                +"LEFT JOIN dbo.TipoEstado TR ON TR.IdTipoEstado=ER.IdTipoEstado WHERE EV.IdEvento=?";
        try(Connection c=obtenerConexion();PreparedStatement ps=c.prepareStatement(sql)) {
            ps.setInt(1,idEvento);ps.setQueryTimeout(15);
            try(ResultSet rs=ps.executeQuery()) {
                if(!rs.next()) return null;
                igual(idEvento,id(rs,"IdEvento"));
                igual("EVENTO",texto(rs,"TipoEstadoEvento",false,40));
                String estadoEvento=texto(rs,"EstadoEvento",false,40);
                com.apuestas.modelo.ConsultaResultadoEvento.Resultado resultado=null;
                if(rs.getObject("IdResultado")==null) {
                    for(String col:Arrays.asList("IdEventoResultado","EstadoResultado","TipoEstadoResultado",
                            "ResultadoTexto","Observacion","FechaRegistro","MarcadorFinalA","MarcadorFinalB",
                            "IdIncidenciaPrimeraAnotacion")) if(rs.getObject(col)!=null) throw contrato();
                } else {
                    int identificador=id(rs,"IdResultado");igual(idEvento,id(rs,"IdEventoResultado"));
                    igual("RESULTADO_EVENTO",texto(rs,"TipoEstadoResultado",false,40));
                    String estado=texto(rs,"EstadoResultado",false,40);
                    if(!Arrays.asList("PENDIENTE","OFICIAL","CORREGIDO","ANULADO").contains(estado)) throw contrato();
                    Object fecha=rs.getObject("FechaRegistro");if(!(fecha instanceof Timestamp)) throw contrato();
                    Integer a=marcadorConsulta(rs,"MarcadorFinalA"),b=marcadorConsulta(rs,"MarcadorFinalB");
                    if((a==null)!=(b==null)) throw contrato();
                    Object incidencia=rs.getObject("IdIncidenciaPrimeraAnotacion");
                    if(incidencia!=null&&(!(incidencia instanceof Long)||(Long)incidencia<=0)) throw contrato();
                    resultado=new com.apuestas.modelo.ConsultaResultadoEvento.Resultado(identificador,estado,
                            texto(rs,"ResultadoTexto",false,250),texto(rs,"Observacion",true,500),
                            ((Timestamp)fecha).toLocalDateTime(),a,b,(Long)incidencia);
                }
                if(rs.next()) throw contrato();
                return new com.apuestas.modelo.ConsultaResultadoEvento(idEvento,estadoEvento,resultado);
            }
        }
    }
    private static Integer marcadorConsulta(ResultSet rs,String columna) throws SQLException {
        Object v=rs.getObject(columna);if(v==null)return null;
        if(!(v instanceof Integer)||(Integer)v<0)throw contrato();return (Integer)v;
    }

    public Resultado ejecutar(OperacionAdministracionResultados op,int actor,Solicitud s,String ip) throws SQLException {
        Objects.requireNonNull(op);Objects.requireNonNull(s);
        int cantidad=op.parametros.size()+2;
        String sql="{call dbo."+op.procedimiento+"("+String.join(", ",Collections.nCopies(cantidad,"?"))+")}";
        try(Connection c=obtenerConexion();CallableStatement cs=c.prepareCall(sql)) {
            cs.setInt(1,actor);
            switch(op) {
                case REGISTRAR:
                    cs.setInt(2,s.idEvento);cs.setString(3,s.resultadoTexto);cadena(cs,4,s.observacion);break;
                case RESOLVER:
                    cs.setInt(2,s.idResultadoEvento);cs.setInt(3,s.idSeleccion);
                    cs.setString(4,s.resultado);cadena(cs,5,s.observacion);break;
                case OFICIALIZAR:
                    cs.setInt(2,s.idResultadoEvento);cadena(cs,3,s.observacion);break;
                case CORREGIR:
                    cs.setInt(2,s.idResultadoEvento);cs.setString(3,s.nuevoResultadoTexto);cs.setString(4,s.motivo);break;
                case ANULAR:
                    cs.setInt(2,s.idResultadoEvento);cs.setString(3,s.motivo);break;
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
    private static void cadena(CallableStatement cs,int pos,String valor) throws SQLException {
        if(valor==null) cs.setNull(pos,Types.VARCHAR);else cs.setString(pos,valor);
    }
    private static boolean siguiente(CallableStatement cs,boolean primero) throws SQLException {
        boolean resultado=primero?cs.execute():cs.getMoreResults();
        while(!resultado&&cs.getUpdateCount()!=-1) resultado=cs.getMoreResults();
        return resultado;
    }
    // INT, VARCHAR y BIT: getObject evita aceptar conversiones silenciosas de un contrato distinto.
    private static Integer id(ResultSet rs,String columna) throws SQLException {
        Object v=rs.getObject(columna);
        if(!(v instanceof Integer)||(Integer)v<=0) throw contrato();
        return (Integer)v;
    }
    private static String texto(ResultSet rs,String columna,boolean nullable,int max) throws SQLException {
        Object v=rs.getObject(columna);
        if(v==null&&nullable) return null;
        if(!(v instanceof String)||((String)v).length()>max
                ||(!nullable&&((String)v).trim().isEmpty())) throw contrato();
        return (String)v;
    }
    private static Boolean bit(ResultSet rs,String columna) throws SQLException {
        Object v=rs.getObject(columna);
        if(!(v instanceof Boolean)) throw contrato();
        return (Boolean)v;
    }
    private static void igual(Object esperado,Object recibido) throws SQLException {
        if(!Objects.equals(esperado,recibido)) throw contrato();
    }
    private static Resultado leer(OperacionAdministracionResultados op,Solicitud s,ResultSet rs) throws SQLException {
        switch(op) {
            case REGISTRAR: {
                Registro r=new Registro();
                r.idResultado=id(rs,"IdResultado");r.idEvento=id(rs,"IdEvento");
                r.estadoResultado=texto(rs,"EstadoResultado",false,40);
                r.resultadoTexto=texto(rs,"ResultadoTexto",false,250);r.observacion=texto(rs,"Observacion",true,500);
                igual(s.idEvento,r.idEvento);igual(s.resultadoTexto,r.resultadoTexto);igual(s.observacion,r.observacion);
                if(!Arrays.asList("PENDIENTE","CORREGIDO").contains(r.estadoResultado)) throw contrato();
                return r;
            }
            case RESOLVER: {
                Resolucion r=new Resolucion();
                r.idResolucion=id(rs,"IdResolucion");r.idResultadoEvento=id(rs,"IdResultadoEvento");r.idSeleccion=id(rs,"IdSeleccion");
                r.resultado=texto(rs,"Resultado",false,20);r.observacion=texto(rs,"Observacion",true,500);
                igual(s.idResultadoEvento,r.idResultadoEvento);igual(s.idSeleccion,r.idSeleccion);
                igual(s.resultado,r.resultado);igual(s.observacion,r.observacion);return r;
            }
            case OFICIALIZAR: {
                Oficializacion r=new Oficializacion();
                r.idResultado=id(rs,"IdResultado");r.idEvento=id(rs,"IdEvento");
                r.estadoResultado=texto(rs,"EstadoResultado",false,40);r.estadoEvento=texto(rs,"EstadoEvento",false,40);
                r.sinCambios=bit(rs,"SinCambios");
                igual(s.idResultadoEvento,r.idResultado);igual("OFICIAL",r.estadoResultado);igual("FINALIZADO",r.estadoEvento);
                return r;
            }
            case CORREGIR: {
                Correccion r=new Correccion();
                r.idResultado=id(rs,"IdResultado");r.idEvento=id(rs,"IdEvento");
                r.estadoResultado=texto(rs,"EstadoResultado",false,40);r.estadoEvento=texto(rs,"EstadoEvento",false,40);
                r.requiereNuevaResolucion=bit(rs,"RequiereNuevaResolucion");
                igual(s.idResultadoEvento,r.idResultado);igual("CORREGIDO",r.estadoResultado);
                igual("PENDIENTE_RESULTADO",r.estadoEvento);igual(true,r.requiereNuevaResolucion);return r;
            }
            case ANULAR: {
                Anulacion r=new Anulacion();
                r.idResultado=id(rs,"IdResultado");r.idEvento=id(rs,"IdEvento");
                r.estadoResultado=texto(rs,"EstadoResultado",false,40);r.estadoEvento=texto(rs,"EstadoEvento",false,40);
                r.sinCambios=bit(rs,"SinCambios");
                igual(s.idResultadoEvento,r.idResultado);igual("ANULADO",r.estadoResultado);igual("CANCELADO",r.estadoEvento);
                return r;
            }
            default:throw contrato();
        }
    }
}