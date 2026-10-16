package com.apuestas.modelo;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** DTO administrativos: solo campos de los contratos oficiales, sin datos de autenticacion. */
public final class AdministracionEventosModelos {
    private AdministracionEventosModelos() { }
    /** Entrada tipada interna. Solo se rellenan los campos permitidos por la operacion. */
    public static final class Solicitud {
        public Integer idDeporte, idLiga, idPais, idParticipante, idEvento, idMercado, idSeleccion, ordenParticipante;
        public String nombre, tipoParticipante, descripcion, nuevoEstado, motivo, tipoMercado, tipoIncidencia;
        public java.util.UUID referenciaOperacion;
        public Long idIncidencia;
        public Integer valorAnotacion,duracionSimulacionSegundos;
        public Boolean esSimulado;
        public Boolean activo, esLocal;
        public LocalDateTime fechaInicio, fechaFin;
        public BigDecimal valor,valorResultado;
    }
    public interface Resultado { }
    public static final class Liga implements Resultado {
        public Integer idLiga, idDeporte, idPais;
        public String nombre;
        public Boolean activo;
    }
    public static final class Participante implements Resultado {
        public Integer idParticipante, idDeporte, idPais;
        public String nombre, tipoParticipante;
        public Boolean activo;
    }
    public static final class Evento implements Resultado {
        public Integer idEvento, idLiga, idEstado;
        public String nombre, estadoEvento;
        public LocalDateTime fechaInicio, fechaFin;
    }
    public static final class LigaParticipante implements Resultado {
        public Integer idLiga,idParticipante;
        public Boolean activo;
    }
    public static final class AsociacionParticipante implements Resultado {
        public Integer idEventoParticipante, idEvento, idParticipante, ordenParticipante;
        public Boolean esLocal;
    }
    public static final class Mercado implements Resultado {
        public Integer idMercado, idEvento, idEstado;
        public String nombre, descripcion, estadoMercado;
    }
    public static final class Seleccion implements Resultado {
        public Integer idSeleccion, idMercado;
        public String nombre;
        public Boolean activo;
    }
    public static final class Cuota implements Resultado {
        public Integer idCuota, idSeleccion, idCuotaAnterior;
        public BigDecimal valor;
        public LocalDateTime fechaInicio;
        public Boolean activo;
    }
    public static final class EstadoEvento implements Resultado {
        public Integer idEvento;
        public String estadoAnterior, estadoActual;
        public Boolean sinCambios;
    }
    public static final class EstadoMercado implements Resultado {
        public Integer idMercado;
        public String estadoAnterior, estadoActual;
        public Boolean sinCambios;
    }
    public static final class IncidenciaRegistrada implements Resultado {
        public Long idIncidencia;
        public Boolean solicitudIdempotente;
    }
    public static final class IncidenciaAnulada implements Resultado {
        public Long idIncidencia;
        public Boolean sinCambios;
    }
    /** Respuesta abreviada oficial de inicio/fin, sin inventar estado anterior. */
    public static final class EstadoSimulacionCambiado implements Resultado {
        public Integer idEvento;
        public Boolean sinCambios;
        public ResultadoSimulacion registrado;
    }
    public static final class ResultadoSimulacion implements Resultado {
        public Integer idResultado,idEvento;
        public String estadoResultado,resultadoTexto,observacion;
    }
    public static final class EventoCancelado implements Resultado {
        public Integer idResultado,idEvento;
        public String estadoResultado,estadoEvento;
        public Boolean sinCambios;
    }
    public static final class ParticipanteSimulacion {
        public Integer ordenParticipante,idParticipante,marcadorActual;
        public String nombre;
    }
    public static final class EstadoSimulacion implements Resultado {
        public Integer idEvento,duracionSimulacionSegundos,segundosTranscurridos;
        public String nombre,estadoEvento,versionFila;
        public Boolean esSimulado,tiempoVisualCumplido;
        public LocalDateTime fechaInicioRealUtc,fechaFinRealUtc;
        public Long idPrimeraAnotacion;
        public Integer idPrimerParticipanteAnotador;
        public final java.util.List<ParticipanteSimulacion> participantes=new java.util.ArrayList<>();
        public final java.util.List<IncidenciaEventoExploracion> incidencias=new java.util.ArrayList<>();
    }
}