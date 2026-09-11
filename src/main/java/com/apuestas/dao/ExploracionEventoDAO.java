/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;

import com.apuestas.modelo.EventoExploracion;

import com.apuestas.modelo.DetalleEventoExploracion;
import com.apuestas.modelo.EventoExploracion;
import com.apuestas.modelo.MercadoExploracion;
import com.apuestas.modelo.ParticipanteExploracion;
import com.apuestas.modelo.SeleccionExploracion;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
/**
 *
 * @author farfa
 */
public class ExploracionEventoDAO {

    public List<EventoExploracion> listarEventos(
            int idDeporte,
            String vista,
            int horasPrevia,
            int cantidad)
            throws SQLException {

        String sql =
                "{call dbo.sp_ObtenerEventosExploracion"
                + "(?, ?, ?, ?)}";

        List<EventoExploracion> eventos =
                new ArrayList<>();

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             CallableStatement cs =
                     conexion.prepareCall(sql)) {

            cs.setInt(
                    1,
                    idDeporte
            );

            cs.setString(
                    2,
                    vista
            );

            cs.setInt(
                    3,
                    horasPrevia
            );

            cs.setInt(
                    4,
                    cantidad
            );

            try (ResultSet rs =
                         cs.executeQuery()) {

                while (rs.next()) {

                    eventos.add(
                            mapearEvento(
                                    rs
                            )
                    );
                }
            }
        }

        return eventos;
    }

    public DetalleEventoExploracion obtenerDetalleEvento(
            int idEvento,
            int horasPrevia)
            throws SQLException {

        String sql =
                "{call dbo.sp_ObtenerDetalleEventoExploracion"
                + "(?, ?)}";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             CallableStatement cs =
                     conexion.prepareCall(sql)) {

            cs.setInt(
                    1,
                    idEvento
            );

            cs.setInt(
                    2,
                    horasPrevia
            );

            boolean tieneResultado =
                    cs.execute();

            if (!tieneResultado) {

                throw new SQLException(
                        "El procedimiento "
                        + "sp_ObtenerDetalleEventoExploracion "
                        + "no devolvió el encabezado "
                        + "del evento."
                );
            }

            DetalleEventoExploracion detalle;

            try (ResultSet rs =
                         cs.getResultSet()) {

                if (!rs.next()) {

                    throw new SQLException(
                            "El procedimiento "
                            + "sp_ObtenerDetalleEventoExploracion "
                            + "no devolvió el evento solicitado."
                    );
                }

                detalle =
                        mapearDetalleEvento(
                                rs
                        );
            }

            boolean tieneParticipantes =
                    cs.getMoreResults();

            List<ParticipanteExploracion>
                    participantes =
                    new ArrayList<>();

            if (tieneParticipantes) {

                try (ResultSet rs =
                             cs.getResultSet()) {

                    while (rs.next()) {

                        participantes.add(
                                mapearParticipante(
                                        rs
                                )
                        );
                    }
                }
            }

            detalle.setParticipantes(
                    participantes
            );

            boolean tieneMercados =
                    cs.getMoreResults();

            Map<Integer, MercadoExploracion>
                    mercadosPorId =
                    new LinkedHashMap<>();

            if (tieneMercados) {

                try (ResultSet rs =
                             cs.getResultSet()) {

                    while (rs.next()) {

                        int idMercado =
                                rs.getInt(
                                        "IdMercado"
                                );

                        MercadoExploracion mercado =
                                mercadosPorId.get(
                                        idMercado
                                );

                        if (mercado == null) {

                            mercado =
                                    mapearMercado(
                                            rs
                                    );

                            mercadosPorId.put(
                                    idMercado,
                                    mercado
                            );
                        }

                        SeleccionExploracion seleccion =
                                mapearSeleccion(
                                        rs
                                );

                        mercado.getSelecciones()
                                .add(
                                        seleccion
                                );
                    }
                }
            }

            detalle.setMercados(
                    new ArrayList<>(
                            mercadosPorId.values()
                    )
            );

            return detalle;
        }
    }

    private EventoExploracion mapearEvento(
            ResultSet rs)
            throws SQLException {

        EventoExploracion evento =
                new EventoExploracion();

        evento.setIdEvento(
                rs.getInt(
                        "IdEvento"
                )
        );

        evento.setIdDeporte(
                rs.getInt(
                        "IdDeporte"
                )
        );

        evento.setDeporte(
                rs.getString(
                        "Deporte"
                )
        );

        evento.setIdLiga(
                rs.getInt(
                        "IdLiga"
                )
        );

        evento.setLiga(
                rs.getString(
                        "Liga"
                )
        );

        evento.setEvento(
                rs.getString(
                        "Evento"
                )
        );

        evento.setParticipante1(
                rs.getString(
                        "Participante1"
                )
        );

        evento.setParticipante2(
                rs.getString(
                        "Participante2"
                )
        );

        evento.setCantidadParticipantes(
                rs.getInt(
                        "CantidadParticipantes"
                )
        );

        evento.setFechaInicio(
                obtenerFecha(
                        rs,
                        "FechaInicio"
                )
        );

        evento.setFechaFin(
                obtenerFecha(
                        rs,
                        "FechaFin"
                )
        );

        evento.setFechaCierreApuestas(
                obtenerFecha(
                        rs,
                        "FechaCierreApuestas"
                )
        );

        evento.setMinutosParaInicio(
                rs.getInt(
                        "MinutosParaInicio"
                )
        );

        evento.setMinutosParaCierreApuestas(
                rs.getInt(
                        "MinutosParaCierreApuestas"
                )
        );

        evento.setEstadoEvento(
                rs.getString(
                        "EstadoEvento"
                )
        );

        evento.setEstadoVisual(
                rs.getString(
                        "EstadoVisual"
                )
        );

        evento.setResultadoPendiente(
                rs.getBoolean(
                        "ResultadoPendiente"
                )
        );

        evento.setCantidadMercados(
                rs.getInt(
                        "CantidadMercados"
                )
        );

        evento.setMercadosAbiertos(
                rs.getInt(
                        "MercadosAbiertos"
                )
        );

        evento.setSeleccionesDisponibles(
                rs.getInt(
                        "SeleccionesDisponibles"
                )
        );

        evento.setPuedeApostar(
                rs.getBoolean(
                        "PuedeApostar"
                )
        );

        evento.setResultadoTexto(
                rs.getString(
                        "ResultadoTexto"
                )
        );

        evento.setEstadoResultado(
                rs.getString(
                        "EstadoResultado"
                )
        );

        return evento;
    }

    private DetalleEventoExploracion mapearDetalleEvento(
            ResultSet rs)
            throws SQLException {

        DetalleEventoExploracion detalle =
                new DetalleEventoExploracion();

        detalle.setIdEvento(
                rs.getInt(
                        "IdEvento"
                )
        );

        detalle.setIdDeporte(
                rs.getInt(
                        "IdDeporte"
                )
        );

        detalle.setDeporte(
                rs.getString(
                        "Deporte"
                )
        );

        detalle.setIdLiga(
                rs.getInt(
                        "IdLiga"
                )
        );

        detalle.setLiga(
                rs.getString(
                        "Liga"
                )
        );

        detalle.setEvento(
                rs.getString(
                        "Evento"
                )
        );

        detalle.setFechaInicio(
                obtenerFecha(
                        rs,
                        "FechaInicio"
                )
        );

        detalle.setFechaFin(
                obtenerFecha(
                        rs,
                        "FechaFin"
                )
        );

        detalle.setFechaCierreApuestas(
                obtenerFecha(
                        rs,
                        "FechaCierreApuestas"
                )
        );

        detalle.setMinutosParaInicio(
                rs.getInt(
                        "MinutosParaInicio"
                )
        );

        detalle.setMinutosParaCierreApuestas(
                rs.getInt(
                        "MinutosParaCierreApuestas"
                )
        );

        detalle.setEstadoEvento(
                rs.getString(
                        "EstadoEvento"
                )
        );

        detalle.setEstadoVisual(
                rs.getString(
                        "EstadoVisual"
                )
        );

        detalle.setPuedeApostar(
                rs.getBoolean(
                        "PuedeApostar"
                )
        );

        detalle.setCantidadMercados(
                rs.getInt(
                        "CantidadMercados"
                )
        );

        detalle.setCantidadParticipantes(
                rs.getInt(
                        "CantidadParticipantes"
                )
        );

        detalle.setResultadoTexto(
                rs.getString(
                        "ResultadoTexto"
                )
        );

        detalle.setEstadoResultado(
                rs.getString(
                        "EstadoResultado"
                )
        );

        detalle.setResultadoPendiente(
                rs.getBoolean(
                        "ResultadoPendiente"
                )
        );

        return detalle;
    }

    private ParticipanteExploracion mapearParticipante(
            ResultSet rs)
            throws SQLException {

        ParticipanteExploracion participante =
                new ParticipanteExploracion();

        participante.setIdEventoParticipante(
                rs.getInt(
                        "IdEventoParticipante"
                )
        );

        participante.setOrdenParticipante(
                rs.getInt(
                        "OrdenParticipante"
                )
        );

        participante.setEsLocal(
                obtenerBooleanNullable(
                        rs,
                        "EsLocal"
                )
        );

        participante.setIdParticipante(
                rs.getInt(
                        "IdParticipante"
                )
        );

        participante.setParticipante(
                rs.getString(
                        "Participante"
                )
        );

        participante.setTipoParticipante(
                rs.getString(
                        "TipoParticipante"
                )
        );

        participante.setIdPais(
                obtenerEnteroNullable(
                        rs,
                        "IdPais"
                )
        );

        participante.setPais(
                rs.getString(
                        "Pais"
                )
        );

        participante.setCodigoPais(
                rs.getString(
                        "CodigoPais"
                )
        );

        return participante;
    }

    private MercadoExploracion mapearMercado(
            ResultSet rs)
            throws SQLException {

        MercadoExploracion mercado =
                new MercadoExploracion();

        mercado.setIdMercado(
                rs.getInt(
                        "IdMercado"
                )
        );

        mercado.setMercado(
                rs.getString(
                        "Mercado"
                )
        );

        mercado.setDescripcionMercado(
                rs.getString(
                        "DescripcionMercado"
                )
        );

        mercado.setEstadoMercado(
                rs.getString(
                        "EstadoMercado"
                )
        );

        return mercado;
    }

    private SeleccionExploracion mapearSeleccion(
            ResultSet rs)
            throws SQLException {

        SeleccionExploracion seleccion =
                new SeleccionExploracion();

        seleccion.setIdSeleccion(
                rs.getInt(
                        "IdSeleccion"
                )
        );

        seleccion.setSeleccion(
                rs.getString(
                        "Seleccion"
                )
        );

        seleccion.setSeleccionActiva(
                rs.getBoolean(
                        "SeleccionActiva"
                )
        );

        seleccion.setIdCuota(
                obtenerEnteroNullable(
                        rs,
                        "IdCuota"
                )
        );

        seleccion.setCuota(
                rs.getBigDecimal(
                        "Cuota"
                )
        );

        seleccion.setFechaInicioCuota(
                obtenerFecha(
                        rs,
                        "FechaInicioCuota"
                )
        );

        seleccion.setFechaFinCuota(
                obtenerFecha(
                        rs,
                        "FechaFinCuota"
                )
        );

        seleccion.setCuotaActiva(
                obtenerBooleanNullable(
                        rs,
                        "CuotaActiva"
                )
        );

        seleccion.setProbabilidadImplicitaPorcentaje(
                rs.getBigDecimal(
                        "ProbabilidadImplicitaPorcentaje"
                )
        );

        seleccion.setResultadoSeleccion(
                rs.getString(
                        "ResultadoSeleccion"
                )
        );

        seleccion.setFechaResolucion(
                obtenerFecha(
                        rs,
                        "FechaResolucion"
                )
        );

        seleccion.setPuedeSeleccionar(
                rs.getBoolean(
                        "PuedeSeleccionar"
                )
        );

        return seleccion;
    }

    private java.time.LocalDateTime obtenerFecha(
            ResultSet rs,
            String columna)
            throws SQLException {

        Timestamp fecha =
                rs.getTimestamp(
                        columna
                );

        if (fecha == null) {
            return null;
        }

        return fecha.toLocalDateTime();
    }

    private Integer obtenerEnteroNullable(
            ResultSet rs,
            String columna)
            throws SQLException {

        Object valor =
                rs.getObject(
                        columna
                );

        if (valor == null) {
            return null;
        }

        return ((Number) valor)
                .intValue();
    }

    private Boolean obtenerBooleanNullable(
            ResultSet rs,
            String columna)
            throws SQLException {

        Object valor =
                rs.getObject(
                        columna
                );

        if (valor == null) {
            return null;
        }

        if (valor instanceof Boolean) {
            return (Boolean) valor;
        }

        if (valor instanceof Number) {

            return ((Number) valor)
                    .intValue() != 0;
        }

        return Boolean.valueOf(
                valor.toString()
        );
    }
}