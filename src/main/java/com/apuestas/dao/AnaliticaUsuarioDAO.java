package com.apuestas.dao;

import com.apuestas.modelo.*;
import java.sql.*;
import java.time.LocalDateTime;
import java.util.*;

public class AnaliticaUsuarioDAO {
    protected Connection obtenerConexion() throws SQLException {
        return ConexionBD.obtenerConexion();
    }

    public List<AnaliticaBoletoUsuario> obtenerAnaliticaBoletosUsuario(
            int idUsuario, Integer idDeporte) throws SQLException {
        try (Connection conexion = obtenerConexion();
             CallableStatement cs = conexion.prepareCall(
                     "{call dbo.sp_ObtenerAnaliticaBoletosUsuario(?, ?)}")) {
            cs.setInt(1, idUsuario);
            if (idDeporte == null) cs.setNull(2, Types.INTEGER);
            else cs.setInt(2, idDeporte);

            Map<Integer, AnaliticaBoletoUsuario> boletos = new LinkedHashMap<>();
            exigirResultado(cs, cs.execute());
            try (ResultSet rs = cs.getResultSet()) {
                while (rs.next()) {
                    AnaliticaBoletoUsuario boleto = new AnaliticaBoletoUsuario(
                            obligatorio(entero(rs, "IdBoleto"), "IdBoleto"),
                            obligatorio(rs.getString("CodigoBoleto"), "CodigoBoleto"),
                            obligatorio(rs.getString("TipoBoleto"), "TipoBoleto"),
                            obligatorio(rs.getString("Resultado"), "Resultado"),
                            obligatorio(rs.getString("EstadoBoleto"), "EstadoBoleto"),
                            obligatorio(fecha(rs, "FechaCreacion"), "FechaCreacion"),
                            fecha(rs, "FechaLiquidacion"),
                            obligatorio(rs.getBigDecimal("MontoApostado"), "MontoApostado"),
                            obligatorio(rs.getBigDecimal("ComisionServicio"), "ComisionServicio"),
                            obligatorio(rs.getBigDecimal("TotalCargo"), "TotalCargo"),
                            obligatorio(rs.getBigDecimal("CuotaTotal"), "CuotaTotal"),
                            obligatorio(rs.getBigDecimal("PremioPotencial"), "PremioPotencial"),
                            obligatorio(rs.getBigDecimal("GananciaNetaPotencial"), "GananciaNetaPotencial"),
                            rs.getBigDecimal("PorcentajeGananciaPotencial"),
                            rs.getBigDecimal("ProbabilidadImplicitaPorcentaje"),
                            obligatorio(entero(rs, "CantidadSelecciones"), "CantidadSelecciones"));
                    if (boleto.getIdBoleto() <= 0 || boleto.getCantidadSelecciones() < 0
                            || boletos.putIfAbsent(boleto.getIdBoleto(), boleto) != null) {
                        throw new SQLException("Resumen de boletos inconsistente.");
                    }
                }
            }

            exigirResultado(cs, cs.getMoreResults());
            Set<Integer> idsDetalle = new HashSet<>();
            try (ResultSet rs = cs.getResultSet()) {
                while (rs.next()) {
                    DetalleAnaliticaBoletoUsuario detalle = new DetalleAnaliticaBoletoUsuario(
                            obligatorio(entero(rs, "IdBoleto"), "IdBoleto"),
                            obligatorio(rs.getString("CodigoBoleto"), "CodigoBoleto"),
                            obligatorio(entero(rs, "IdDetalle"), "IdDetalle"),
                            obligatorio(entero(rs, "IdDeporte"), "IdDeporte"),
                            obligatorio(rs.getString("Deporte"), "Deporte"),
                            obligatorio(entero(rs, "IdLiga"), "IdLiga"),
                            obligatorio(rs.getString("Liga"), "Liga"),
                            obligatorio(entero(rs, "IdEvento"), "IdEvento"),
                            obligatorio(rs.getString("Evento"), "Evento"),
                            obligatorio(fecha(rs, "FechaInicio"), "FechaInicio"),
                            obligatorio(entero(rs, "IdMercado"), "IdMercado"),
                            obligatorio(rs.getString("Mercado"), "Mercado"),
                            obligatorio(entero(rs, "IdSeleccion"), "IdSeleccion"),
                            obligatorio(rs.getString("Seleccion"), "Seleccion"),
                            obligatorio(rs.getBigDecimal("CuotaAplicada"), "CuotaAplicada"),
                            rs.getBigDecimal("ProbabilidadImplicitaSeleccionPorcentaje"),
                            obligatorio(rs.getString("ResultadoSeleccion"), "ResultadoSeleccion"));
                    AnaliticaBoletoUsuario boleto = boletos.get(detalle.getIdBoleto());
                    if (boleto == null || !boleto.getCodigoBoleto().equals(detalle.getCodigoBoleto())
                            || detalle.getIdDetalle() <= 0 || !idsDetalle.add(detalle.getIdDetalle())
                            || (idDeporte != null && detalle.getIdDeporte() != idDeporte)) {
                        throw new SQLException("Detalle de boleto inconsistente.");
                    }
                    // CantidadSelecciones es el total SQL, incluso al filtrar detalles.
                    boleto.agregarDetalle(detalle);
                }
            }
            boolean resultado = cs.getMoreResults();
            while (resultado || cs.getUpdateCount() != -1) {
                if (resultado) {
                    try (ResultSet adicional = cs.getResultSet()) {
                        throw new SQLException("Resultado adicional inesperado.");
                    }
                }
                resultado = cs.getMoreResults();
            }
            return new ArrayList<>(boletos.values());
        }
    }


    public List<ResumenUsuarioPorDeporte> obtenerResumenUsuarioPorDeporte(int idUsuario)
            throws SQLException {
        try (Connection conexion = obtenerConexion();
             CallableStatement cs = conexion.prepareCall(
                     "{call dbo.sp_ObtenerResumenUsuarioPorDeporte(?)}")) {
            cs.setInt(1, idUsuario);
            exigirResultado(cs, cs.execute());
            List<ResumenUsuarioPorDeporte> deportes = new ArrayList<>();
            try (ResultSet rs = cs.getResultSet()) {
                while (rs.next()) {
                    deportes.add(new ResumenUsuarioPorDeporte(
                            obligatorio(entero(rs, "IdDeporte"), "IdDeporte"),
                            obligatorio(rs.getString("Deporte"), "Deporte"),
                            obligatorio(entero(rs, "CantidadBoletos"), "CantidadBoletos"),
                            obligatorio(entero(rs, "BoletosPendientes"), "BoletosPendientes"),
                            obligatorio(entero(rs, "BoletosGanadores"), "BoletosGanadores"),
                            obligatorio(entero(rs, "BoletosPerdedores"), "BoletosPerdedores"),
                            obligatorio(entero(rs, "BoletosAnulados"), "BoletosAnulados"),
                            obligatorio(entero(rs, "CantidadSelecciones"), "CantidadSelecciones"),
                            obligatorio(entero(rs, "SeleccionesPendientes"), "SeleccionesPendientes"),
                            obligatorio(entero(rs, "SeleccionesGanadas"), "SeleccionesGanadas"),
                            obligatorio(entero(rs, "SeleccionesPerdidas"), "SeleccionesPerdidas"),
                            obligatorio(entero(rs, "SeleccionesAnuladas"), "SeleccionesAnuladas"),
                            rs.getBigDecimal("CuotaPromedio"),
                            rs.getBigDecimal("ProbabilidadImplicitaPromedio"),
                            rs.getBigDecimal("PorcentajeEfectividad")));
                }
            }
            comprobarFinResumen(cs);
            return deportes;
        }
    }

    public ResumenGeneralUsuario obtenerResumenGeneralUsuario(int idUsuario) throws SQLException {
        try (Connection conexion = obtenerConexion();
             CallableStatement cs = conexion.prepareCall(
                     "{call dbo.sp_ObtenerResumenGeneralUsuario(?)}")) {
            cs.setInt(1, idUsuario);
            exigirResultado(cs, cs.execute());
            ResumenGeneralUsuario resumen;
            try (ResultSet rs = cs.getResultSet()) {
                if (!rs.next()) throw new SQLException("Falta el resumen general.");
                // SUM sin filas conserva NULL; no sustituirlo por cero.
                resumen = new ResumenGeneralUsuario(
                        obligatorio(entero(rs, "CantidadBoletos"), "CantidadBoletos"),
                        entero(rs, "BoletosPendientes"),
                        entero(rs, "BoletosGanadores"),
                        entero(rs, "BoletosPerdedores"),
                        entero(rs, "BoletosAnulados"),
                        obligatorio(rs.getBigDecimal("TotalApostado"), "TotalApostado"),
                        obligatorio(rs.getBigDecimal("TotalComisionesHistoricas"), "TotalComisionesHistoricas"),
                        obligatorio(rs.getBigDecimal("TotalCargoHistorico"), "TotalCargoHistorico"),
                        obligatorio(rs.getBigDecimal("PremioPotencialPendiente"), "PremioPotencialPendiente"),
                        obligatorio(rs.getBigDecimal("GananciaNetaPotencialPendiente"), "GananciaNetaPotencialPendiente"),
                        obligatorio(rs.getBigDecimal("TotalPremiosGanadores"), "TotalPremiosGanadores"),
                        obligatorio(rs.getBigDecimal("TotalDevueltoPorAnulacion"), "TotalDevueltoPorAnulacion"),
                        obligatorio(rs.getBigDecimal("ResultadoNetoRealizado"), "ResultadoNetoRealizado"),
                        rs.getBigDecimal("PorcentajeEfectividad"),
                        rs.getBigDecimal("CuotaPromedio"),
                        rs.getBigDecimal("ProbabilidadImplicitaPromedio"));
                if (rs.next()) throw new SQLException("Resumen general duplicado.");
            }
            comprobarFinResumen(cs);
            return resumen;
        }
    }

    private void comprobarFinResumen(CallableStatement cs) throws SQLException {
        boolean resultado = cs.getMoreResults();
        while (resultado || cs.getUpdateCount() != -1) {
            if (resultado) {
                try (ResultSet adicional = cs.getResultSet()) {
                    throw new SQLException("Resultado adicional inesperado.");
                }
            }
            resultado = cs.getMoreResults();
        }
    }

    private void exigirResultado(CallableStatement cs, boolean resultado) throws SQLException {
        while (!resultado && cs.getUpdateCount() != -1) resultado = cs.getMoreResults();
        if (!resultado) throw new SQLException("Falta un resultado de analitica.");
    }

    private Integer entero(ResultSet rs, String columna) throws SQLException {
        int valor = rs.getInt(columna);
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
