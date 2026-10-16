package com.apuestas.modelo;
import java.util.*;
public enum OperacionConsultaAdministrativa {
    EVENTOS("/administrador/eventos/listar","idDeporte","estado","pagina","tamanoPagina"),
    DETALLE_EVENTO("/administrador/eventos/detalle","idEvento"),
    PAISES("/administrador/catalogos/paises"),
    USUARIOS("/administrador/usuarios/buscar","buscar","pagina","tamanoPagina");
    public final String ruta;public final Set<String> parametros;
    OperacionConsultaAdministrativa(String ruta,String... campos){this.ruta=ruta;parametros=Collections.unmodifiableSet(new HashSet<>(Arrays.asList(campos)));}
    public static OperacionConsultaAdministrativa deRuta(String ruta){for(OperacionConsultaAdministrativa op:values())if(op.ruta.equals(ruta))return op;return null;}
}
