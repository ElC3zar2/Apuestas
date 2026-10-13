package com.apuestas.modelo;

import java.util.*;

/** Separa el resultado anterior de las metricas globales por modalidad. */
public final class ConsultaAnaliticaUsuario<T> {
    private final T datos;
    private final List<MetricasModalidadUsuario> modalidades;
    public ConsultaAnaliticaUsuario(T datos,List<MetricasModalidadUsuario> modalidades) {
        this.datos=Objects.requireNonNull(datos);
        this.modalidades=Collections.unmodifiableList(new ArrayList<>(modalidades));
    }
    public T getDatos() { return datos; }
    public List<MetricasModalidadUsuario> getModalidades() { return modalidades; }
}
