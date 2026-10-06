package com.apuestas.modelo;

import java.util.*;

/** Contratos cerrados de 04_EventosMercados.sql; nunca nombres SQL del cliente. */
public enum OperacionAdministracionEventos {
    CREAR_LIGA("ligas/crear","CrearLiga","idDeporte","nombre","idPais"),
    ACTUALIZAR_LIGA("ligas/actualizar","ActualizarLiga","idLiga","nombre","idPais","activo"),
    CREAR_PARTICIPANTE("participantes/crear","CrearParticipante","idDeporte","nombre","tipoParticipante","idPais"),
    ACTUALIZAR_PARTICIPANTE("participantes/actualizar","ActualizarParticipante","idParticipante","nombre","idPais","activo"),
    CREAR_EVENTO("eventos/crear","CrearEvento","idLiga","nombre","fechaInicio","fechaFin"),
    ACTUALIZAR_EVENTO("eventos/actualizar","ActualizarEvento","idEvento","nombre","fechaInicio","fechaFin"),
    AGREGAR_PARTICIPANTE("eventos/participantes/agregar","AgregarParticipanteEvento","idEvento","idParticipante","ordenParticipante","esLocal"),
    CREAR_MERCADO("mercados/crear","CrearMercado","idEvento","nombre","descripcion"),
    CREAR_SELECCION("selecciones/crear","CrearSeleccion","idMercado","nombre"),
    REGISTRAR_CUOTA("cuotas/registrar","RegistrarCuota","idSeleccion","valor"),
    ESTADO_EVENTO("eventos/estado/cambiar","CambiarEstadoEvento","idEvento","nuevoEstado","motivo"),
    ESTADO_MERCADO("mercados/estado/cambiar","CambiarEstadoMercado","idMercado","nuevoEstado","motivo");

    public final String ruta, procedimiento;
    public final Set<String> parametros;
    OperacionAdministracionEventos(String ruta,String procedimiento,String... parametros) {
        this.ruta="/administrador/"+ruta;
        this.procedimiento="sp_"+procedimiento;
        this.parametros=Collections.unmodifiableSet(new LinkedHashSet<>(Arrays.asList(parametros)));
    }
    public static OperacionAdministracionEventos deRuta(String ruta) {
        for(OperacionAdministracionEventos op:values()) if(op.ruta.equals(ruta)) return op;
        return null;
    }
}