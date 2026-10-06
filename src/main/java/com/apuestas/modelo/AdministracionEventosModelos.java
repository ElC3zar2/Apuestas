package com.apuestas.modelo;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** DTO administrativos: solo campos de los contratos oficiales, sin datos de autenticacion. */
public final class AdministracionEventosModelos {
    private AdministracionEventosModelos() { }
    /** Entrada tipada interna. Solo se rellenan los campos permitidos por la operacion. */
    public static final class Solicitud {
        public Integer idDeporte, idLiga, idPais, idParticipante, idEvento, idMercado, idSeleccion, ordenParticipante;
        public String nombre, tipoParticipante, descripcion, nuevoEstado, motivo;
        public Boolean activo, esLocal;
        public LocalDateTime fechaInicio, fechaFin;
        public BigDecimal valor;
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
}