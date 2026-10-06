package com.apuestas.dao;

import com.apuestas.modelo.LiquidacionAdministrativaModelos.*;
import java.sql.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;

/** Sin calculos financieros, reintentos ni transacciones Java. Una llamada oficial por operacion. */
public class LiquidacionAdministrativaDAO {
    protected Connection obtenerConexion() throws SQLException { return ConexionBD.obtenerConexion(); }
    private static SQLException contrato() { return new SQLException("Respuesta de liquidacion inconsistente."); }
    public List<BoletoListo> listar(int actor,int cantidad) throws SQLException {
        try(Connection c=obtenerConexion();CallableStatement cs=c.prepareCall("{call dbo.sp_ObtenerBoletosListosLiquidar(?, ?)}")) {
            cs.setInt(1,actor);cs.setInt(2,cantidad);
            List<BoletoListo> lista=new ArrayList<>();Set<Integer> ids=new HashSet<>();
            try(ResultSet rs=iniciar(cs)) {
                while(rs.next()) {
                    BoletoListo r=leerBoletoListo(rs);
                    if(!ids.add(r.idBoleto)||lista.size()>=cantidad) throw contrato();
                    lista.add(r);
                }
            }
            fin(cs);return lista;
        }
    }
    public Resultado liquidar(int actor,int idBoleto,String ip) throws SQLException {
        try(Connection c=obtenerConexion();CallableStatement cs=c.prepareCall("{call dbo.sp_LiquidarBoleto(?, ?, ?)}")) {
            cs.setInt(1,actor);cs.setInt(2,idBoleto);
            if(ip==null) cs.setNull(3,Types.VARCHAR);else cs.setString(3,ip);
            Resultado resultado;
            try(ResultSet rs=iniciar(cs)) {
                if(!rs.next()) throw contrato();
                boolean repetida=bit(rs,"SolicitudIdempotente");
                if(repetida) {
                    LiquidacionExistente r=leerLiquidacionExistente(rs);
                    if(r.idBoleto!=idBoleto) throw contrato();
                    resultado=r;
                } else {
                    LiquidacionNueva r=leerLiquidacionNueva(rs);
                    if(r.idBoleto!=idBoleto) throw contrato();
                    resultado=r;
                }
                if(rs.next()) throw contrato();
            }
            fin(cs);return resultado;
        }
    }
    public Consulta consultar(int actor,int idBoleto) throws SQLException {
        try(Connection c=obtenerConexion();CallableStatement cs=c.prepareCall("{call dbo.sp_ObtenerLiquidacionBoleto(?, ?)}")) {
            cs.setInt(1,actor);cs.setInt(2,idBoleto);Consulta r;
            try(ResultSet rs=iniciar(cs)) {
                if(!rs.next()) throw contrato();
                r=leerConsulta(rs);
                if(r.idBoleto!=idBoleto||rs.next()) throw contrato();
            }
            fin(cs);return r;
        }
    }
    private static boolean siguiente(CallableStatement cs,boolean primero) throws SQLException {
        boolean hay=primero?cs.execute():cs.getMoreResults();
        while(!hay&&cs.getUpdateCount()!=-1) hay=cs.getMoreResults();
        return hay;
    }
    private static ResultSet iniciar(CallableStatement cs) throws SQLException {
        if(!siguiente(cs,true)) throw contrato();
        ResultSet rs=cs.getResultSet();if(rs==null) throw contrato();return rs;
    }
    private static void fin(CallableStatement cs) throws SQLException {
        if(siguiente(cs,false)) { try(ResultSet extra=cs.getResultSet()) { throw contrato(); } }
    }
    private static Integer entero(ResultSet rs,String col,boolean nullable,int minimo) throws SQLException {
        Object v=rs.getObject(col);if(v==null&&nullable) return null;
        if(!(v instanceof Integer)||(Integer)v<minimo) throw contrato();return (Integer)v;
    }
    private static Long largo(ResultSet rs,String col,boolean nullable) throws SQLException {
        Object v=rs.getObject(col);if(v==null&&nullable) return null;
        if(!(v instanceof Long)||(Long)v<=0) throw contrato();return (Long)v;
    }
    private static String texto(ResultSet rs,String col,boolean nullable) throws SQLException {
        Object v=rs.getObject(col);if(v==null&&nullable) return null;
        if(!(v instanceof String)||(!nullable&&((String)v).trim().isEmpty())) throw contrato();return (String)v;
    }
    private static String referencia(ResultSet rs,String col,boolean nullable) throws SQLException {
        String v=texto(rs,col,nullable);
        if(v!=null&&!v.matches("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")) throw contrato();
        return v;
    }
    private static Boolean bit(ResultSet rs,String col) throws SQLException {
        Object v=rs.getObject(col);if(!(v instanceof Boolean)) throw contrato();return (Boolean)v;
    }
    private static LocalDateTime fecha(ResultSet rs,String col,boolean nullable) throws SQLException {
        Object v=rs.getObject(col);if(v==null&&nullable) return null;
        if(!(v instanceof Timestamp)) throw contrato();return ((Timestamp)v).toLocalDateTime();
    }
    private static BigDecimal decimal(ResultSet rs,String col,int precision,int escala) throws SQLException {
        Object v=rs.getObject(col);
        if(!(v instanceof BigDecimal)) throw contrato();
        BigDecimal d=(BigDecimal)v;
        if(d.signum()<0||d.scale()>escala||d.precision()-d.scale()>precision-escala) throw contrato();
        return d;
    }
    private static BoletoListo leerBoletoListo(ResultSet rs) throws SQLException {
        BoletoListo r=new BoletoListo();
        r.idBoleto=entero(rs,"IdBoleto",false,1);
        r.codigoBoleto=texto(rs,"CodigoBoleto",false);
        r.idUsuario=entero(rs,"IdUsuario",false,1);
        r.correo=texto(rs,"Correo",false);
        r.tipoBoleto=texto(rs,"TipoBoleto",false);
        r.montoApostado=decimal(rs,"MontoApostado",12,2);
        r.cuotaTotal=decimal(rs,"CuotaTotal",12,4);
        r.gananciaPotencial=decimal(rs,"GananciaPotencial",12,2);
        r.fechaCreacion=fecha(rs,"FechaCreacion",false);
        r.cantidadSelecciones=entero(rs,"CantidadSelecciones",false,1);
        r.seleccionesGanadas=entero(rs,"SeleccionesGanadas",false,0);
        r.seleccionesPerdidas=entero(rs,"SeleccionesPerdidas",false,0);
        r.seleccionesAnuladas=entero(rs,"SeleccionesAnuladas",false,0);
        r.resultadoPropuesto=texto(rs,"ResultadoPropuesto",false);
        return r;
    }
    private static LiquidacionNueva leerLiquidacionNueva(ResultSet rs) throws SQLException {
        LiquidacionNueva r=new LiquidacionNueva();
        r.idLiquidacion=largo(rs,"IdLiquidacion",false);
        r.idBoleto=entero(rs,"IdBoleto",false,1);
        r.codigoBoleto=texto(rs,"CodigoBoleto",false);
        r.resultadoBoleto=texto(rs,"ResultadoBoleto",false);
        r.estadoBoleto=texto(rs,"EstadoBoleto",false);
        r.montoApostado=decimal(rs,"MontoApostado",12,2);
        r.comisionServicio=decimal(rs,"ComisionServicio",12,2);
        r.totalCargo=decimal(rs,"TotalCargo",13,2);
        r.montoLiquidado=decimal(rs,"MontoLiquidado",12,2);
        r.gananciaNeta=decimal(rs,"GananciaNeta",12,2);
        r.comisionDevuelta=decimal(rs,"ComisionDevuelta",12,2);
        r.idTransaccionUsuario=largo(rs,"IdTransaccionUsuario",false);
        r.referenciaUsuario=referencia(rs,"ReferenciaUsuario",false);
        r.idTransaccionDevolucionComisionUsuario=largo(rs,"IdTransaccionDevolucionComisionUsuario",true);
        r.referenciaDevolucionComisionUsuario=referencia(rs,"ReferenciaDevolucionComisionUsuario",true);
        r.idTransaccionCasa=largo(rs,"IdTransaccionCasa",true);
        r.referenciaCasa=referencia(rs,"ReferenciaCasa",true);
        r.usuarioDisponibleAnterior=decimal(rs,"UsuarioDisponibleAnterior",12,2);
        r.usuarioDisponiblePosterior=decimal(rs,"UsuarioDisponiblePosterior",12,2);
        r.usuarioComprometidoAnterior=decimal(rs,"UsuarioComprometidoAnterior",12,2);
        r.usuarioComprometidoPosterior=decimal(rs,"UsuarioComprometidoPosterior",12,2);
        r.casaDisponibleAnterior=decimal(rs,"CasaDisponibleAnterior",12,2);
        r.casaDisponiblePosterior=decimal(rs,"CasaDisponiblePosterior",12,2);
        r.solicitudIdempotente=bit(rs,"SolicitudIdempotente");
        return r;
    }
    private static LiquidacionExistente leerLiquidacionExistente(ResultSet rs) throws SQLException {
        LiquidacionExistente r=new LiquidacionExistente();
        r.idLiquidacion=largo(rs,"IdLiquidacion",false);
        r.idBoleto=entero(rs,"IdBoleto",false,1);
        r.codigoBoleto=texto(rs,"CodigoBoleto",false);
        r.resultado=texto(rs,"Resultado",false);
        r.estadoBoleto=texto(rs,"EstadoBoleto",false);
        r.montoApostado=decimal(rs,"MontoApostado",12,2);
        r.comisionServicio=decimal(rs,"ComisionServicio",12,2);
        r.totalCargo=decimal(rs,"TotalCargo",13,2);
        r.montoLiquidado=decimal(rs,"MontoLiquidado",12,2);
        r.idTransaccion=largo(rs,"IdTransaccion",true);
        r.fechaFinalizacion=fecha(rs,"FechaFinalizacion",true);
        r.solicitudIdempotente=bit(rs,"SolicitudIdempotente");
        return r;
    }
    private static Consulta leerConsulta(ResultSet rs) throws SQLException {
        Consulta r=new Consulta();
        r.idLiquidacion=largo(rs,"IdLiquidacion",false);
        r.idBoleto=entero(rs,"IdBoleto",false,1);
        r.codigoBoleto=texto(rs,"CodigoBoleto",false);
        r.idUsuario=entero(rs,"IdUsuario",false,1);
        r.correo=texto(rs,"Correo",false);
        r.resultadoBoleto=texto(rs,"ResultadoBoleto",false);
        r.estadoBoleto=texto(rs,"EstadoBoleto",false);
        r.montoApostado=decimal(rs,"MontoApostado",12,2);
        r.comisionServicio=decimal(rs,"ComisionServicio",12,2);
        r.totalCargo=decimal(rs,"TotalCargo",13,2);
        r.cuotaTotal=decimal(rs,"CuotaTotal",12,4);
        r.gananciaPotencial=decimal(rs,"GananciaPotencial",12,2);
        r.montoLiquidado=decimal(rs,"MontoLiquidado",12,2);
        r.estadoLiquidacion=texto(rs,"EstadoLiquidacion",false);
        r.idTransaccionUsuario=largo(rs,"IdTransaccionUsuario",true);
        r.idTransaccionCasa=largo(rs,"IdTransaccionCasa",true);
        r.fechaCreacion=fecha(rs,"FechaCreacion",false);
        r.fechaInicioProceso=fecha(rs,"FechaInicioProceso",true);
        r.fechaFinalizacion=fecha(rs,"FechaFinalizacion",true);
        r.idUsuarioProceso=entero(rs,"IdUsuarioProceso",true,1);
        r.usuarioProceso=texto(rs,"UsuarioProceso",true);
        r.observacion=texto(rs,"Observacion",true);
        return r;
    }
}