package com.apuestas.modelo;

/** Proyecciones exactas de los resultados SQL; no incluyen identidad ni secretos de sesion. */
public final class AdministracionResultadosModelos {
    private AdministracionResultadosModelos() { }
    public static final class Solicitud {
        public Integer idEvento, idResultadoEvento, idSeleccion;
        public String resultadoTexto, resultado, nuevoResultadoTexto, observacion, motivo;
    }
    public interface Resultado { }
    public static final class Registro implements Resultado {
        public Integer idResultado, idEvento;
        public String estadoResultado, resultadoTexto, observacion;
    }
    public static final class Resolucion implements Resultado {
        public Integer idResolucion, idResultadoEvento, idSeleccion;
        public String resultado, observacion;
    }
    public static final class Oficializacion implements Resultado {
        public Integer idResultado, idEvento;
        public String estadoResultado, estadoEvento;
        public Boolean sinCambios;
    }
    public static final class Correccion implements Resultado {
        public Integer idResultado, idEvento;
        public String estadoResultado, estadoEvento;
        public Boolean requiereNuevaResolucion;
    }
    public static final class Anulacion implements Resultado {
        public Integer idResultado, idEvento;
        public String estadoResultado, estadoEvento;
        public Boolean sinCambios;
    }
}