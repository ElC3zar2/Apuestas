package com.apuestas.modelo;

/** Incidencia oficial, incluidas las anuladas; sin recalculo deportivo. */
public class IncidenciaEventoExploracion {
    private Long idIncidencia;
    public Long getIdIncidencia() { return idIncidencia; }
    public void setIdIncidencia(Long valor) { this.idIncidencia = valor; }
    private int secuencia;
    public int getSecuencia() { return secuencia; }
    public void setSecuencia(int valor) { this.secuencia = valor; }
    private String tipoIncidencia;
    public String getTipoIncidencia() { return tipoIncidencia; }
    public void setTipoIncidencia(String valor) { this.tipoIncidencia = valor; }
    private Integer idParticipante;
    public Integer getIdParticipante() { return idParticipante; }
    public void setIdParticipante(Integer valor) { this.idParticipante = valor; }
    private Integer valorAnotacion;
    public Integer getValorAnotacion() { return valorAnotacion; }
    public void setValorAnotacion(Integer valor) { this.valorAnotacion = valor; }
    private int segundoSimulacion;
    public int getSegundoSimulacion() { return segundoSimulacion; }
    public void setSegundoSimulacion(int valor) { this.segundoSimulacion = valor; }
    private java.time.LocalDateTime fechaRegistroUtc;
    public java.time.LocalDateTime getFechaRegistroUtc() { return fechaRegistroUtc; }
    public void setFechaRegistroUtc(java.time.LocalDateTime valor) { this.fechaRegistroUtc = valor; }
    private String descripcion;
    public String getDescripcion() { return descripcion; }
    public void setDescripcion(String valor) { this.descripcion = valor; }
    private boolean esAnulada;
    public boolean getEsAnulada() { return esAnulada; }
    public void setEsAnulada(boolean valor) { this.esAnulada = valor; }
    private String motivoAnulacion;
    public String getMotivoAnulacion() { return motivoAnulacion; }
    public void setMotivoAnulacion(String valor) { this.motivoAnulacion = valor; }
    private java.time.LocalDateTime fechaAnulacionUtc;
    public java.time.LocalDateTime getFechaAnulacionUtc() { return fechaAnulacionUtc; }
    public void setFechaAnulacionUtc(java.time.LocalDateTime valor) { this.fechaAnulacionUtc = valor; }
    private String versionFila;
    public String getVersionFila() { return versionFila; }
    public void setVersionFila(String valor) { this.versionFila = valor; }
}
