package com.apuestas.modelo;

import java.util.*;

/** Cinco acciones independientes y procedimientos fijos de 06_Resultados.sql. */
public enum OperacionAdministracionResultados {
    REGISTRAR("registrar","RegistrarResultadoEvento",false,"idEvento","resultadoTexto","observacion"),
    RESOLVER("selecciones/resolver","ResolverSeleccion",false,"idResultadoEvento","idSeleccion","resultado","observacion"),
    OFICIALIZAR("oficializar","OficializarResultadoEvento",false,"idResultadoEvento","observacion"),
    CORREGIR("corregir","CorregirResultadoEvento",true,"idResultadoEvento","nuevoResultadoTexto","motivo"),
    ANULAR("anular","AnularResultadoEvento",true,"idResultadoEvento","motivo");

    public final String ruta, procedimiento;
    public final boolean soloAdministrador;
    public final Set<String> parametros;
    OperacionAdministracionResultados(String ruta,String sp,boolean soloAdministrador,String... parametros) {
        this.ruta="/administrador/resultados/"+ruta;
        this.procedimiento="sp_"+sp;
        this.soloAdministrador=soloAdministrador;
        this.parametros=Collections.unmodifiableSet(new LinkedHashSet<>(Arrays.asList(parametros)));
    }
    public static OperacionAdministracionResultados deRuta(String ruta) {
        for(OperacionAdministracionResultados op:values()) if(op.ruta.equals(ruta)) return op;
        return null;
    }
}