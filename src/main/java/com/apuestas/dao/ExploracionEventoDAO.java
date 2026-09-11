/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;

import com.apuestas.modelo.EventoExploracion;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;

import java.util.ArrayList;
import java.util.List;

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
}