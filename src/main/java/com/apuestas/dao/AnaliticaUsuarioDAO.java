package com.apuestas.dao;

import com.apuestas.modelo.*;
import java.sql.*;
import java.time.LocalDateTime;
import java.util.*;

public class AnaliticaUsuarioDAO {
    protected Connection obtenerConexion() throws SQLException {
        return ConexionBD.obtenerConexion();
    }

    public ConsultaAnaliticaUsuario<List<AnaliticaBoletoUsuario>> consultarHistorial(
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
                LecturaUsuarioSQL.columnas(rs,"IdBoleto,CodigoBoleto,TipoBoleto,Resultado,EstadoBoleto,FechaCreacion,FechaLiquidacion,MontoApostado,ComisionServicio,TotalCargo,CuotaTotal,PremioPotencial,GananciaNetaPotencial,PorcentajeGananciaPotencial,ProbabilidadImplicitaPorcentaje,CantidadSelecciones");
                while (rs.next()) {
                    AnaliticaBoletoUsuario boleto = new AnaliticaBoletoUsuario(
                            obligatorio(entero(rs, "IdBoleto"), "IdBoleto"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"CodigoBoleto",String.class,true), "CodigoBoleto"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"TipoBoleto",String.class,true), "TipoBoleto"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"Resultado",String.class,true), "Resultado"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"EstadoBoleto",String.class,true), "EstadoBoleto"),
                            obligatorio(fecha(rs, "FechaCreacion"), "FechaCreacion"),
                            fecha(rs, "FechaLiquidacion"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"MontoApostado",java.math.BigDecimal.class,true), "MontoApostado"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"ComisionServicio",java.math.BigDecimal.class,true), "ComisionServicio"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"TotalCargo",java.math.BigDecimal.class,true), "TotalCargo"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"CuotaTotal",java.math.BigDecimal.class,true), "CuotaTotal"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"PremioPotencial",java.math.BigDecimal.class,true), "PremioPotencial"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"GananciaNetaPotencial",java.math.BigDecimal.class,true), "GananciaNetaPotencial"),
                            LecturaUsuarioSQL.dato(rs,"PorcentajeGananciaPotencial",java.math.BigDecimal.class,true),
                            LecturaUsuarioSQL.dato(rs,"ProbabilidadImplicitaPorcentaje",java.math.BigDecimal.class,true),
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
                LecturaUsuarioSQL.columnas(rs,"IdBoleto,CodigoBoleto,IdDetalle,IdDeporte,Deporte,IdLiga,Liga,IdEvento,Evento,FechaInicio,IdMercado,Mercado,IdSeleccion,Seleccion,CuotaAplicada,ProbabilidadImplicitaSeleccionPorcentaje,ResultadoSeleccion");
                while (rs.next()) {
                    DetalleAnaliticaBoletoUsuario detalle = new DetalleAnaliticaBoletoUsuario(
                            obligatorio(entero(rs, "IdBoleto"), "IdBoleto"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"CodigoBoleto",String.class,true), "CodigoBoleto"),
                            obligatorio(entero(rs, "IdDetalle"), "IdDetalle"),
                            obligatorio(entero(rs, "IdDeporte"), "IdDeporte"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"Deporte",String.class,true), "Deporte"),
                            obligatorio(entero(rs, "IdLiga"), "IdLiga"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"Liga",String.class,true), "Liga"),
                            obligatorio(entero(rs, "IdEvento"), "IdEvento"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"Evento",String.class,true), "Evento"),
                            obligatorio(fecha(rs, "FechaInicio"), "FechaInicio"),
                            obligatorio(entero(rs, "IdMercado"), "IdMercado"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"Mercado",String.class,true), "Mercado"),
                            obligatorio(entero(rs, "IdSeleccion"), "IdSeleccion"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"Seleccion",String.class,true), "Seleccion"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"CuotaAplicada",java.math.BigDecimal.class,true), "CuotaAplicada"),
                            LecturaUsuarioSQL.dato(rs,"ProbabilidadImplicitaSeleccionPorcentaje",java.math.BigDecimal.class,true),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"ResultadoSeleccion",String.class,true), "ResultadoSeleccion"));
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
            List<MetricasModalidadUsuario> modalidades=LecturaUsuarioSQL.metricas(cs);
            Map<Integer,DetalleAnaliticaBoletoUsuario> porDetalle=new HashMap<>();
            for(AnaliticaBoletoUsuario b:boletos.values())for(DetalleAnaliticaBoletoUsuario d:b.getDetalles())porDetalle.put(d.getIdDetalle(),d);
            Set<Integer> historicos=new HashSet<>();
            try(ResultSet rs=LecturaUsuarioSQL.resultado(cs,false,
                    "IdDetalle,IdBoleto,CodigoBoleto,IdUsuario,TipoBoleto,ResultadoDetalle,CuotaAplicada,DescripcionAcierto,IdSeleccion,Seleccion,IdMercado,Mercado,IdEvento,Evento,FechaInicio,IdLiga,Liga,IdDeporte,Deporte,"+LecturaUsuarioSQL.MODALIDAD)) {
                while(rs.next()) {
                    int id=LecturaUsuarioSQL.dato(rs,"IdDetalle",Integer.class,false);
                    DetalleAnaliticaBoletoUsuario d=porDetalle.get(id);
                    if(d==null || !historicos.add(id)
                            || LecturaUsuarioSQL.dato(rs,"IdUsuario",Integer.class,false)!=idUsuario
                            || LecturaUsuarioSQL.dato(rs,"IdBoleto",Integer.class,false)!=d.getIdBoleto()
                            || !LecturaUsuarioSQL.dato(rs,"CodigoBoleto",String.class,false).equals(d.getCodigoBoleto())
                            || !LecturaUsuarioSQL.dato(rs,"TipoBoleto",String.class,false).equals(boletos.get(d.getIdBoleto()).getTipoBoleto())
                            || LecturaUsuarioSQL.dato(rs,"IdSeleccion",Integer.class,false)!=d.getIdSeleccion()
                            || LecturaUsuarioSQL.dato(rs,"IdMercado",Integer.class,false)!=d.getIdMercado()
                            || LecturaUsuarioSQL.dato(rs,"IdEvento",Integer.class,false)!=d.getIdEvento()
                            || LecturaUsuarioSQL.dato(rs,"IdLiga",Integer.class,false)!=d.getIdLiga()
                            || LecturaUsuarioSQL.dato(rs,"IdDeporte",Integer.class,false)!=d.getIdDeporte()
                            || LecturaUsuarioSQL.dato(rs,"CuotaAplicada",java.math.BigDecimal.class,false).compareTo(d.getCuotaAplicada())!=0
                            || !LecturaUsuarioSQL.dato(rs,"ResultadoDetalle",String.class,false).equals(d.getResultadoSeleccion()))throw LecturaUsuarioSQL.error();
                    // RS2 ya transporta estos campos; comprobar la asociacion por ID, no por posicion.
                    for(String c:new String[]{"Seleccion","Mercado","Evento","Liga","Deporte"})LecturaUsuarioSQL.dato(rs,c,String.class,false);
                    LecturaUsuarioSQL.dato(rs,"FechaInicio",Timestamp.class,false);
                    LecturaUsuarioSQL.modalidad(rs,d);
                    d.setDescripcionAcierto(LecturaUsuarioSQL.dato(rs,"DescripcionAcierto",String.class,false));
                }
            }
            if(!historicos.equals(porDetalle.keySet()))throw LecturaUsuarioSQL.error();
            comprobarFinResumen(cs);
            return new ConsultaAnaliticaUsuario<>(new ArrayList<>(boletos.values()),modalidades);
        }
    }


    public ConsultaAnaliticaUsuario<List<ResumenUsuarioPorDeporte>> consultarResumenPorDeporte(int idUsuario)
            throws SQLException {
        try (Connection conexion = obtenerConexion();
             CallableStatement cs = conexion.prepareCall(
                     "{call dbo.sp_ObtenerResumenUsuarioPorDeporte(?)}")) {
            cs.setInt(1, idUsuario);
            exigirResultado(cs, cs.execute());
            List<ResumenUsuarioPorDeporte> deportes = new ArrayList<>();
            try (ResultSet rs = cs.getResultSet()) {
                LecturaUsuarioSQL.columnas(rs,"IdDeporte,Deporte,CantidadBoletos,BoletosPendientes,BoletosGanadores,BoletosPerdedores,BoletosAnulados,CantidadSelecciones,SeleccionesPendientes,SeleccionesGanadas,SeleccionesPerdidas,SeleccionesAnuladas,CuotaPromedio,ProbabilidadImplicitaPromedio,PorcentajeEfectividad");
                while (rs.next()) {
                    deportes.add(new ResumenUsuarioPorDeporte(
                            obligatorio(entero(rs, "IdDeporte"), "IdDeporte"),
                            obligatorio(LecturaUsuarioSQL.dato(rs,"Deporte",String.class,true), "Deporte"),
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
                            LecturaUsuarioSQL.dato(rs,"CuotaPromedio",java.math.BigDecimal.class,true),
                            LecturaUsuarioSQL.dato(rs,"ProbabilidadImplicitaPromedio",java.math.BigDecimal.class,true),
                            LecturaUsuarioSQL.dato(rs,"PorcentajeEfectividad",java.math.BigDecimal.class,true)));
                }
            }
            List<MetricasModalidadUsuario> modalidades=LecturaUsuarioSQL.metricas(cs);
            comprobarFinResumen(cs);
            return new ConsultaAnaliticaUsuario<>(deportes,modalidades);
        }
    }

    public ConsultaAnaliticaUsuario<ResumenGeneralUsuario> consultarResumenGeneral(int idUsuario) throws SQLException {
        try (Connection conexion = obtenerConexion();
             CallableStatement cs = conexion.prepareCall(
                     "{call dbo.sp_ObtenerResumenGeneralUsuario(?)}")) {
            cs.setInt(1, idUsuario);
            exigirResultado(cs, cs.execute());
            ResumenGeneralUsuario resumen;
            try (ResultSet rs = cs.getResultSet()) {
                LecturaUsuarioSQL.columnas(rs,"CantidadBoletos,BoletosPendientes,BoletosGanadores,BoletosPerdedores,BoletosAnulados,TotalApostado,TotalComisionesHistoricas,TotalCargoHistorico,PremioPotencialPendiente,GananciaNetaPotencialPendiente,TotalPremiosGanadores,TotalDevueltoPorAnulacion,ResultadoNetoRealizado,PorcentajeEfectividad,CuotaPromedio,ProbabilidadImplicitaPromedio");
                if (!rs.next()) throw new SQLException("Falta el resumen general.");
                // SUM sin filas conserva NULL; no sustituirlo por cero.
                resumen = new ResumenGeneralUsuario(
                        obligatorio(entero(rs, "CantidadBoletos"), "CantidadBoletos"),
                        entero(rs, "BoletosPendientes"),
                        entero(rs, "BoletosGanadores"),
                        entero(rs, "BoletosPerdedores"),
                        entero(rs, "BoletosAnulados"),
                        obligatorio(LecturaUsuarioSQL.dato(rs,"TotalApostado",java.math.BigDecimal.class,true), "TotalApostado"),
                        obligatorio(LecturaUsuarioSQL.dato(rs,"TotalComisionesHistoricas",java.math.BigDecimal.class,true), "TotalComisionesHistoricas"),
                        obligatorio(LecturaUsuarioSQL.dato(rs,"TotalCargoHistorico",java.math.BigDecimal.class,true), "TotalCargoHistorico"),
                        obligatorio(LecturaUsuarioSQL.dato(rs,"PremioPotencialPendiente",java.math.BigDecimal.class,true), "PremioPotencialPendiente"),
                        obligatorio(LecturaUsuarioSQL.dato(rs,"GananciaNetaPotencialPendiente",java.math.BigDecimal.class,true), "GananciaNetaPotencialPendiente"),
                        obligatorio(LecturaUsuarioSQL.dato(rs,"TotalPremiosGanadores",java.math.BigDecimal.class,true), "TotalPremiosGanadores"),
                        obligatorio(LecturaUsuarioSQL.dato(rs,"TotalDevueltoPorAnulacion",java.math.BigDecimal.class,true), "TotalDevueltoPorAnulacion"),
                        obligatorio(LecturaUsuarioSQL.dato(rs,"ResultadoNetoRealizado",java.math.BigDecimal.class,true), "ResultadoNetoRealizado"),
                        LecturaUsuarioSQL.dato(rs,"PorcentajeEfectividad",java.math.BigDecimal.class,true),
                        LecturaUsuarioSQL.dato(rs,"CuotaPromedio",java.math.BigDecimal.class,true),
                        LecturaUsuarioSQL.dato(rs,"ProbabilidadImplicitaPromedio",java.math.BigDecimal.class,true));
                if (rs.next()) throw new SQLException("Resumen general duplicado.");
            }
            List<MetricasModalidadUsuario> modalidades=LecturaUsuarioSQL.metricas(cs);
            comprobarFinResumen(cs);
            return new ConsultaAnaliticaUsuario<>(resumen,modalidades);
        }
    }

    public List<AnaliticaBoletoUsuario> obtenerAnaliticaBoletosUsuario(int idUsuario,Integer idDeporte) throws SQLException {
        return consultarHistorial(idUsuario,idDeporte).getDatos();
    }
    public List<ResumenUsuarioPorDeporte> obtenerResumenUsuarioPorDeporte(int idUsuario) throws SQLException {
        return consultarResumenPorDeporte(idUsuario).getDatos();
    }
    public ResumenGeneralUsuario obtenerResumenGeneralUsuario(int idUsuario) throws SQLException {
        return consultarResumenGeneral(idUsuario).getDatos();
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
        return LecturaUsuarioSQL.dato(rs,columna,Integer.class,true);
    }

    private LocalDateTime fecha(ResultSet rs, String columna) throws SQLException {
        Timestamp valor = LecturaUsuarioSQL.dato(rs,columna,Timestamp.class,true);
        return valor == null ? null : valor.toLocalDateTime();
    }

    private <T> T obligatorio(T valor, String columna) throws SQLException {
        if (valor == null) throw new SQLException("Columna obligatoria nula: " + columna);
        return valor;
    }
}
