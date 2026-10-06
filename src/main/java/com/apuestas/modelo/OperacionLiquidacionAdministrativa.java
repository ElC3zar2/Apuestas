package com.apuestas.modelo;

public enum OperacionLiquidacionAdministrativa {
    LISTAR("listos","GET","cantidad"),
    LIQUIDAR("liquidar","POST","idBoleto"),
    CONSULTAR("consultar","GET","idBoleto");
    public final String ruta,metodo,parametro;
    OperacionLiquidacionAdministrativa(String ruta,String metodo,String parametro) {
        this.ruta="/administrador/liquidaciones/"+ruta;this.metodo=metodo;this.parametro=parametro;
    }
    public static OperacionLiquidacionAdministrativa deRuta(String ruta) {
        for(OperacionLiquidacionAdministrativa op:values()) if(op.ruta.equals(ruta)) return op;
        return null;
    }
}