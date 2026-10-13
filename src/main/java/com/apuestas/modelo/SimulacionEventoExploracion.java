package com.apuestas.modelo;

/** Datos oficiales de lectura. VersionFila se transporta en hexadecimal. */
public class SimulacionEventoExploracion {
    private boolean esSimulado;
    public boolean getEsSimulado() { return esSimulado; }
    public void setEsSimulado(boolean valor) { this.esSimulado = valor; }
    private Integer duracionSimulacionSegundos;
    public Integer getDuracionSimulacionSegundos() { return duracionSimulacionSegundos; }
    public void setDuracionSimulacionSegundos(Integer valor) { this.duracionSimulacionSegundos = valor; }
    private java.time.LocalDateTime fechaInicioRealUtc;
    public java.time.LocalDateTime getFechaInicioRealUtc() { return fechaInicioRealUtc; }
    public void setFechaInicioRealUtc(java.time.LocalDateTime valor) { this.fechaInicioRealUtc = valor; }
    private java.time.LocalDateTime fechaFinRealUtc;
    public java.time.LocalDateTime getFechaFinRealUtc() { return fechaFinRealUtc; }
    public void setFechaFinRealUtc(java.time.LocalDateTime valor) { this.fechaFinRealUtc = valor; }
    private String versionFila;
    public String getVersionFila() { return versionFila; }
    public void setVersionFila(String valor) { this.versionFila = valor; }
    private Integer marcadorA;
    public Integer getMarcadorA() { return marcadorA; }
    public void setMarcadorA(Integer valor) { this.marcadorA = valor; }
    private Integer marcadorB;
    public Integer getMarcadorB() { return marcadorB; }
    public void setMarcadorB(Integer valor) { this.marcadorB = valor; }
    private Integer segundosTranscurridos;
    public Integer getSegundosTranscurridos() { return segundosTranscurridos; }
    public void setSegundosTranscurridos(Integer valor) { this.segundosTranscurridos = valor; }
    private Boolean tiempoVisualCumplido;
    public Boolean getTiempoVisualCumplido() { return tiempoVisualCumplido; }
    public void setTiempoVisualCumplido(Boolean valor) { this.tiempoVisualCumplido = valor; }
    private Long idPrimeraAnotacion;
    public Long getIdPrimeraAnotacion() { return idPrimeraAnotacion; }
    public void setIdPrimeraAnotacion(Long valor) { this.idPrimeraAnotacion = valor; }
    private Integer idPrimerParticipanteAnotador;
    public Integer getIdPrimerParticipanteAnotador() { return idPrimerParticipanteAnotador; }
    public void setIdPrimerParticipanteAnotador(Integer valor) { this.idPrimerParticipanteAnotador = valor; }
}
