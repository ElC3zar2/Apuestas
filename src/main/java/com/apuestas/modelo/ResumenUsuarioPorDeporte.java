package com.apuestas.modelo;

import java.math.BigDecimal;

/** Valores oficiales del procedimiento SQL, sin recalculos ni sustitucion de nulos. */
public final class ResumenUsuarioPorDeporte {
    private final int idDeporte;
    private final String deporte;
    private final int cantidadBoletos;
    private final int boletosPendientes;
    private final int boletosGanadores;
    private final int boletosPerdedores;
    private final int boletosAnulados;
    private final int cantidadSelecciones;
    private final int seleccionesPendientes;
    private final int seleccionesGanadas;
    private final int seleccionesPerdidas;
    private final int seleccionesAnuladas;
    private final BigDecimal cuotaPromedio;
    private final BigDecimal probabilidadImplicitaPromedio;
    private final BigDecimal porcentajeEfectividad;

    public ResumenUsuarioPorDeporte(
            int idDeporte,
            String deporte,
            int cantidadBoletos,
            int boletosPendientes,
            int boletosGanadores,
            int boletosPerdedores,
            int boletosAnulados,
            int cantidadSelecciones,
            int seleccionesPendientes,
            int seleccionesGanadas,
            int seleccionesPerdidas,
            int seleccionesAnuladas,
            BigDecimal cuotaPromedio,
            BigDecimal probabilidadImplicitaPromedio,
            BigDecimal porcentajeEfectividad) {
        this.idDeporte = idDeporte;
        this.deporte = deporte;
        this.cantidadBoletos = cantidadBoletos;
        this.boletosPendientes = boletosPendientes;
        this.boletosGanadores = boletosGanadores;
        this.boletosPerdedores = boletosPerdedores;
        this.boletosAnulados = boletosAnulados;
        this.cantidadSelecciones = cantidadSelecciones;
        this.seleccionesPendientes = seleccionesPendientes;
        this.seleccionesGanadas = seleccionesGanadas;
        this.seleccionesPerdidas = seleccionesPerdidas;
        this.seleccionesAnuladas = seleccionesAnuladas;
        this.cuotaPromedio = cuotaPromedio;
        this.probabilidadImplicitaPromedio = probabilidadImplicitaPromedio;
        this.porcentajeEfectividad = porcentajeEfectividad;
    }

    public int getIdDeporte() { return idDeporte; }
    public String getDeporte() { return deporte; }
    public int getCantidadBoletos() { return cantidadBoletos; }
    public int getBoletosPendientes() { return boletosPendientes; }
    public int getBoletosGanadores() { return boletosGanadores; }
    public int getBoletosPerdedores() { return boletosPerdedores; }
    public int getBoletosAnulados() { return boletosAnulados; }
    public int getCantidadSelecciones() { return cantidadSelecciones; }
    public int getSeleccionesPendientes() { return seleccionesPendientes; }
    public int getSeleccionesGanadas() { return seleccionesGanadas; }
    public int getSeleccionesPerdidas() { return seleccionesPerdidas; }
    public int getSeleccionesAnuladas() { return seleccionesAnuladas; }
    public BigDecimal getCuotaPromedio() { return cuotaPromedio; }
    public BigDecimal getProbabilidadImplicitaPromedio() { return probabilidadImplicitaPromedio; }
    public BigDecimal getPorcentajeEfectividad() { return porcentajeEfectividad; }
}
