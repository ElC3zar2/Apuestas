package com.apuestas.modelo;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/** DTO de los cuatro contratos reales: lista, primera ejecucion, repeticion y consulta. */
public final class LiquidacionAdministrativaModelos {
    private LiquidacionAdministrativaModelos() { }
    public interface Resultado { }
    public static final class BoletoListo implements Resultado {
        public Integer idBoleto;
        public String codigoBoleto;
        public Integer idUsuario;
        public String correo;
        public String tipoBoleto;
        public BigDecimal montoApostado;
        public BigDecimal cuotaTotal;
        public BigDecimal gananciaPotencial;
        public LocalDateTime fechaCreacion;
        public Integer cantidadSelecciones;
        public Integer seleccionesGanadas;
        public Integer seleccionesPerdidas;
        public Integer seleccionesAnuladas;
        public String resultadoPropuesto;
    }
    public static final class LiquidacionNueva implements Resultado {
        public Long idLiquidacion;
        public Integer idBoleto;
        public String codigoBoleto;
        public String resultadoBoleto;
        public String estadoBoleto;
        public BigDecimal montoApostado;
        public BigDecimal comisionServicio;
        public BigDecimal totalCargo;
        public BigDecimal montoLiquidado;
        public BigDecimal gananciaNeta;
        public BigDecimal comisionDevuelta;
        public Long idTransaccionUsuario;
        public String referenciaUsuario;
        public Long idTransaccionDevolucionComisionUsuario;
        public String referenciaDevolucionComisionUsuario;
        public Long idTransaccionCasa;
        public String referenciaCasa;
        public BigDecimal usuarioDisponibleAnterior;
        public BigDecimal usuarioDisponiblePosterior;
        public BigDecimal usuarioComprometidoAnterior;
        public BigDecimal usuarioComprometidoPosterior;
        public BigDecimal casaDisponibleAnterior;
        public BigDecimal casaDisponiblePosterior;
        public Boolean solicitudIdempotente;
    }
    public static final class LiquidacionExistente implements Resultado {
        public Long idLiquidacion;
        public Integer idBoleto;
        public String codigoBoleto;
        public String resultado;
        public String estadoBoleto;
        public BigDecimal montoApostado;
        public BigDecimal comisionServicio;
        public BigDecimal totalCargo;
        public BigDecimal montoLiquidado;
        public Long idTransaccion;
        public LocalDateTime fechaFinalizacion;
        public Boolean solicitudIdempotente;
    }
    public static final class Consulta implements Resultado {
        public Long idLiquidacion;
        public Integer idBoleto;
        public String codigoBoleto;
        public Integer idUsuario;
        public String correo;
        public String resultadoBoleto;
        public String estadoBoleto;
        public BigDecimal montoApostado;
        public BigDecimal comisionServicio;
        public BigDecimal totalCargo;
        public BigDecimal cuotaTotal;
        public BigDecimal gananciaPotencial;
        public BigDecimal montoLiquidado;
        public String estadoLiquidacion;
        public Long idTransaccionUsuario;
        public Long idTransaccionCasa;
        public LocalDateTime fechaCreacion;
        public LocalDateTime fechaInicioProceso;
        public LocalDateTime fechaFinalizacion;
        public Integer idUsuarioProceso;
        public String usuarioProceso;
        public String observacion;
    }
}