package com.apuestas.modelo;

/** Agregados oficiales por modalidad. COUNT_BIG se conserva como Long. */
public final class MetricasModalidadUsuario {
    private final String tipoMercadoAplicado;
    private final long cantidadDetalles;
    private final int marcadoresExactos, aciertosResultado, aciertosPrimeraAnotacion;
    public MetricasModalidadUsuario(String tipo,long cantidad,int exactos,int resultado,int primera) {
        tipoMercadoAplicado=tipo;cantidadDetalles=cantidad;marcadoresExactos=exactos;
        aciertosResultado=resultado;aciertosPrimeraAnotacion=primera;
    }
    public String getTipoMercadoAplicado() { return tipoMercadoAplicado; }
    public long getCantidadDetalles() { return cantidadDetalles; }
    public int getMarcadoresExactos() { return marcadoresExactos; }
    public int getAciertosResultado() { return aciertosResultado; }
    public int getAciertosPrimeraAnotacion() { return aciertosPrimeraAnotacion; }
}
