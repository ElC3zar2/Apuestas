package com.apuestas.modelo;
import java.util.*;
public enum OperacionDashboardAdministrativo {
    DASHBOARD("/administrador/dashboard/resumen","horasPrevia","cantidadAuditoria"),
    EVENTOS("/administrador/analitica/eventos","idDeporte","vista","horasPrevia","cantidad");
    public final String ruta;
    public final Set<String> parametros;
    OperacionDashboardAdministrativo(String ruta,String... parametros) {
        this.ruta=ruta;this.parametros=Collections.unmodifiableSet(new HashSet<>(Arrays.asList(parametros)));
    }
    public static OperacionDashboardAdministrativo deRuta(String ruta) {
        for(OperacionDashboardAdministrativo op:values()) if(op.ruta.equals(ruta)) return op;
        return null;
    }
}
