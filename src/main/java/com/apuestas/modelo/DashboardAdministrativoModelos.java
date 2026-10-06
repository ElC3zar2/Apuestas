package com.apuestas.modelo;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/** Datos oficiales de 11_AnaliticaAdministrativa.sql. Sin calculos derivados. */
public final class DashboardAdministrativoModelos {
    private DashboardAdministrativoModelos() { }
    public static final class FiltrosDashboard {
        public final int horasPrevia,cantidadAuditoria;
        public FiltrosDashboard(int horas,int cantidad) { horasPrevia=horas;cantidadAuditoria=cantidad; }
    }
    public static final class FiltrosEventos {
        public final Integer idDeporte;
        public final String vista;
        public final int horasPrevia,cantidad;
        public FiltrosEventos(Integer deporte,String vista,int horas,int cantidad) {
            idDeporte=deporte;this.vista=vista;horasPrevia=horas;this.cantidad=cantidad;
        }
    }
    public static final class Dashboard {
        public final boolean ok=true;
        public FiltrosDashboard filtros;
        public Resumen resumen;
        public List<Deporte> deportes;
        public List<Auditoria> auditoriaReciente;
    }
    public static final class Analitica {
        public final boolean ok=true;
        public FiltrosEventos filtros;
        public List<Evento> eventos;
    }
    public static final class Resumen {
        public Integer clientesRegistrados;
        public Integer clientesActivos;
        public Integer eventosTotales;
        public Integer eventosProgramados;
        public Integer eventosPrevia;
        public Integer eventosEnProgreso;
        public Integer eventosPendienteResultado;
        public Integer eventosFinalizados;
        public Integer boletosTotales;
        public Integer boletosPendientes;
        public Integer boletosGanadores;
        public Integer boletosPerdedores;
        public Integer boletosAnulados;
        public BigDecimal totalApostadoHistorico;
        public BigDecimal comisionesHistoricas;
        public BigDecimal comisionesRealizadas;
        public BigDecimal comisionesPendientes;
        public BigDecimal comisionesDevueltas;
        public BigDecimal montoApostadoPendiente;
        public BigDecimal premioPotencialPendiente;
        public BigDecimal exposicionPotencialCasa;
        public BigDecimal gananciaCasaPorApuestasPerdidas;
        public BigDecimal premiosPagados;
        public BigDecimal resultadoCasaRealizado;
        public Integer accionesAuditoriaUltimas24Horas;
    }
    public static final class Deporte {
        public Integer idDeporte;
        public String deporte;
        public Integer eventosTotales;
        public Integer programados;
        public Integer previa;
        public Integer enProgreso;
        public Integer pendienteResultado;
        public Integer finalizados;
        public Integer boletosRelacionados;
        public Integer clientesUnicos;
        public Integer boletosPendientes;
        public Integer boletosGanadores;
        public Integer boletosPerdedores;
        public Integer boletosAnulados;
        public BigDecimal montoApostadoRelacionado;
        public BigDecimal comisionRelacionada;
        public BigDecimal premioPotencialPendienteRelacionado;
        public Integer cantidadSeleccionesApostadas;
        public Integer seleccionesPendientes;
        public Integer seleccionesGanadas;
        public Integer seleccionesPerdidas;
        public BigDecimal cuotaPromedio;
        public BigDecimal probabilidadImplicitaPromedio;
    }
    public static final class Auditoria {
        public Long idAuditoria;
        public LocalDateTime fechaAccion;
        public Integer idUsuario;
        public String correo;
        public String accion;
        public String tablaAfectada;
        public Long idRegistro;
    }
    public static final class Evento {
        public Integer idEvento;
        public Integer idDeporte;
        public String deporte;
        public Integer idLiga;
        public String liga;
        public String evento;
        public LocalDateTime fechaInicio;
        public LocalDateTime fechaFin;
        public String estadoEvento;
        public String estadoVisual;
        public Integer cantidadMercados;
        public Integer mercadosAbiertos;
        public Integer cantidadSelecciones;
        public Integer seleccionesConCuotaActiva;
        public Integer boletosRelacionados;
        public Integer clientesUnicos;
        public Integer boletosPendientes;
        public Integer boletosGanadores;
        public Integer boletosPerdedores;
        public Integer boletosAnulados;
        public BigDecimal montoApostadoRelacionado;
        public BigDecimal comisionRelacionada;
        public BigDecimal premioPotencialPendienteRelacionado;
        public BigDecimal exposicionPotencialRelacionada;
        public BigDecimal resultadoCasaRealizadoRelacionado;
        public BigDecimal cuotaPromedioBoletos;
        public LocalDateTime ultimaApuestaRelacionada;
    }
}
