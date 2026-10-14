package com.apuestas.modelo;

import java.time.LocalDateTime;

/** Consulta de un evento; los dos nombres de ID representan el mismo IdResultado persistido. */
public final class ConsultaResultadoEvento {
    public final boolean ok=true;
    public final int idEvento;
    public final String estadoEvento;
    public final boolean tieneResultado;
    public final Resultado resultado;
    public ConsultaResultadoEvento(int evento,String estado,Resultado resultado) {
        idEvento=evento;estadoEvento=estado;this.resultado=resultado;tieneResultado=resultado!=null;
    }
    public static final class Resultado {
        public final int idResultado,idResultadoEvento;
        public final String estadoResultado,resultadoTexto,observacion;
        public final LocalDateTime fechaRegistro;
        public final Integer marcadorFinalA,marcadorFinalB;
        public final Long idIncidenciaPrimeraAnotacion;
        public Resultado(int id,String estado,String texto,String observacion,LocalDateTime fecha,
                Integer marcadorA,Integer marcadorB,Long incidencia) {
            idResultado=id;idResultadoEvento=id;estadoResultado=estado;resultadoTexto=texto;
            this.observacion=observacion;fechaRegistro=fecha;marcadorFinalA=marcadorA;
            marcadorFinalB=marcadorB;idIncidenciaPrimeraAnotacion=incidencia;
        }
    }
}
