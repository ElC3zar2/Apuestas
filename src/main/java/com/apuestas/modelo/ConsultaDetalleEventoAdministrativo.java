package com.apuestas.modelo;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/** Proyeccion administrativa completa, sin filtros de publicacion ni permisos de apuesta. */
public final class ConsultaDetalleEventoAdministrativo {
    public final boolean ok=true;
    public final Evento evento;
    public ConsultaDetalleEventoAdministrativo(Evento evento){this.evento=evento;}

    public static final class Evento {
        public int idEvento,idDeporte,idLiga,cantidadParticipantes,cantidadMercados;
        public String evento,deporte,liga,estadoEvento,resultadoTexto,estadoResultado;
        public LocalDateTime fechaInicio,fechaFin;
        public SimulacionEventoExploracion simulacion;
        public List<ParticipanteExploracion> participantes=new ArrayList<>();
        public List<MercadoExploracion> mercados=new ArrayList<>();
    }
}
