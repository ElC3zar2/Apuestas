package com.apuestas.dao;

import com.apuestas.modelo.AdministracionResultadosModelos.*;
import com.apuestas.modelo.OperacionAdministracionResultados;
import java.sql.*;
import java.util.*;

/** Cada solicitud llama exactamente un SP. SQL es la unica autoridad transaccional. */
public class AdministracionResultadosDAO {
    protected Connection obtenerConexion() throws SQLException { return ConexionBD.obtenerConexion(); }
    private static SQLException contrato() { return new SQLException("Respuesta de resultados inconsistente."); }

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