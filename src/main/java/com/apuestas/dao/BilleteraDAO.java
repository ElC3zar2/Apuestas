package com.apuestas.dao;

import com.apuestas.modelo.BilleteraUsuario;
import com.apuestas.modelo.MovimientoBilletera;
import java.sql.*;
import java.time.LocalDateTime;
import java.util.*;

public class BilleteraDAO {
    protected Connection obtenerConexion() throws SQLException {
        return ConexionBD.obtenerConexion();
    }

    public BilleteraUsuario obtenerBilleteraUsuario(int idUsuario) throws SQLException {
        try (Connection conexion = obtenerConexion();
             CallableStatement cs = conexion.prepareCall("{call dbo.sp_ObtenerBilleteraUsuario(?)}")) {
            cs.setInt(1, idUsuario);
            BilleteraUsuario billetera;
            try (ResultSet rs = ejecutar(cs)) {
                if (!rs.next()) throw new SQLException("Falta el resumen de billetera.");
                billetera = new BilleteraUsuario(
                        obligatorio(entero(rs, "IdUsuario"), "IdUsuario"),
                        obligatorio(rs.getString("Correo"), "Correo"),
                        obligatorio(rs.getString("Rol"), "Rol"),
                        obligatorio(rs.getString("EstadoUsuario"), "EstadoUsuario"),
                        obligatorio(entero(rs, "IdBilletera"), "IdBilletera"),
                        obligatorio(rs.getBigDecimal("SaldoDisponible"), "SaldoDisponible"),
                        obligatorio(rs.getBigDecimal("SaldoComprometido"), "SaldoComprometido"),
                        obligatorio(rs.getBigDecimal("SaldoVirtualTotal"), "SaldoVirtualTotal"),
                        obligatorio(fecha(rs, "FechaCreacion"), "FechaCreacion"));
                if (billetera.getIdUsuario() != idUsuario || billetera.getIdBilletera() <= 0) {
                    throw new SQLException("Identidad de billetera inconsistente.");
                }
                if (rs.next()) throw new SQLException("Resumen de billetera duplicado.");
            }
            comprobarFin(cs);
            return billetera;
        }
    }

    public List<MovimientoBilletera> obtenerMovimientosBilletera(int idUsuario,
            LocalDateTime fechaDesde, LocalDateTime fechaHasta, int cantidad) throws SQLException {
        try (Connection conexion = obtenerConexion();
             CallableStatement cs = conexion.prepareCall(
                     "{call dbo.sp_ObtenerMovimientosBilletera(?, ?, ?, ?)}")) {
            cs.setInt(1, idUsuario);
            establecerFecha(cs, 2, fechaDesde);
            establecerFecha(cs, 3, fechaHasta);
            cs.setInt(4, cantidad);
            List<MovimientoBilletera> movimientos = new ArrayList<>();
            Set<Long> ids = new HashSet<>();
            try (ResultSet rs = ejecutar(cs)) {
                while (rs.next()) {
                    MovimientoBilletera movimiento = new MovimientoBilletera(
                        obligatorio(largo(rs, "IdMovimiento"), "IdMovimiento"),
                        obligatorio(fecha(rs, "FechaMovimiento"), "FechaMovimiento"),
                        obligatorio(largo(rs, "IdTransaccion"), "IdTransaccion"),
                        obligatorio(rs.getString("ReferenciaOperacion"), "ReferenciaOperacion"),
                        obligatorio(rs.getBigDecimal("Monto"), "Monto"),
                        obligatorio(fecha(rs, "FechaSolicitud"), "FechaSolicitud"),
                        fecha(rs, "FechaProcesamiento"),
                        rs.getString("Descripcion"),
                        obligatorio(rs.getString("TipoTransaccion"), "TipoTransaccion"),
                        obligatorio(rs.getString("NombreTipoTransaccion"), "NombreTipoTransaccion"),
                        obligatorio(rs.getString("EstadoTransaccion"), "EstadoTransaccion"),
                        entero(rs, "IdBoleto"),
                        obligatorio(rs.getBigDecimal("SaldoDisponibleAnterior"), "SaldoDisponibleAnterior"),
                        obligatorio(rs.getBigDecimal("SaldoDisponiblePosterior"), "SaldoDisponiblePosterior"),
                        obligatorio(rs.getBigDecimal("VariacionSaldoDisponible"), "VariacionSaldoDisponible"),
                        obligatorio(rs.getBigDecimal("SaldoComprometidoAnterior"), "SaldoComprometidoAnterior"),
                        obligatorio(rs.getBigDecimal("SaldoComprometidoPosterior"), "SaldoComprometidoPosterior"),
                        obligatorio(rs.getBigDecimal("VariacionSaldoComprometido"), "VariacionSaldoComprometido"),
                        entero(rs, "IdUsuarioProceso"),
                        rs.getString("UsuarioProceso"));
                    if (movimiento.getIdMovimiento() <= 0 || movimiento.getIdTransaccion() <= 0
                            || !ids.add(movimiento.getIdMovimiento())
                            || movimientos.size() >= cantidad) {
                        throw new SQLException("Historial de movimientos inconsistente.");
                    }
                    movimientos.add(movimiento);
                }
            }
            comprobarFin(cs);
            return movimientos;
        }
    }

    private void establecerFecha(CallableStatement cs, int indice, LocalDateTime valor)
            throws SQLException {
        if (valor == null) cs.setNull(indice, Types.TIMESTAMP);
        else cs.setTimestamp(indice, Timestamp.valueOf(valor));
    }

    private ResultSet ejecutar(CallableStatement cs) throws SQLException {
        boolean resultado = cs.execute();
        while (!resultado && cs.getUpdateCount() != -1) resultado = cs.getMoreResults();
        if (!resultado) throw new SQLException("El procedimiento no devolvio un resultado.");
        return cs.getResultSet();
    }

    private void comprobarFin(CallableStatement cs) throws SQLException {
        boolean resultado = cs.getMoreResults();
        while (resultado || cs.getUpdateCount() != -1) {
            if (resultado) throw new SQLException("Resultado adicional inesperado.");
            resultado = cs.getMoreResults();
        }
    }

    private Integer entero(ResultSet rs, String columna) throws SQLException {
        int valor = rs.getInt(columna);
        return rs.wasNull() ? null : valor;
    }

    private Long largo(ResultSet rs, String columna) throws SQLException {
        long valor = rs.getLong(columna);
        return rs.wasNull() ? null : valor;
    }

    private LocalDateTime fecha(ResultSet rs, String columna) throws SQLException {
        Timestamp valor = rs.getTimestamp(columna);
        return valor == null ? null : valor.toLocalDateTime();
    }

    private <T> T obligatorio(T valor, String columna) throws SQLException {
        if (valor == null) throw new SQLException("Columna obligatoria nula: " + columna);
        return valor;
    }
}
