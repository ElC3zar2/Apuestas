package com.apuestas.modelo;
import java.util.*;
/** Rutas y contratos cerrados; ningun procedimiento proviene del cliente. */
public enum OperacionAdministracionUsuario {
    PENDIENTES("pendientes","GET","sp_ObtenerUsuariosPendientesVerificacion","cantidad"),
    DETALLE("detalle","GET","sp_ObtenerDetalleAdministrativoUsuario","idUsuario"),
    INICIAR("verificacion/iniciar","POST","sp_IniciarRevisionUsuario","idVerificacion","observacion"),
    APROBAR("verificacion/aprobar","POST","sp_AprobarVerificacionUsuario","idVerificacion","observacion"),
    RECHAZAR("verificacion/rechazar","POST","sp_RechazarVerificacionUsuario","idVerificacion","motivo"),
    REABRIR("verificacion/reabrir","POST","sp_ReabrirVerificacionUsuario","idUsuario","observacion"),
    ESTADO("estado/cambiar","POST","sp_CambiarEstadoUsuarioAdministrativo","idUsuario","nuevoEstado","motivo"),
    AGREGAR("restricciones/agregar","POST","sp_AgregarRestriccionUsuario","idUsuario","tipoRestriccion","motivo","fechaFin"),
    LEVANTAR("restricciones/levantar","POST","sp_LevantarRestriccionUsuario","idRestriccion","motivoLevantamiento");
    public final String ruta, metodo, procedimiento;
    public final Set<String> parametros;
    OperacionAdministracionUsuario(String ruta,String metodo,String sp,String... parametros) {
        this.ruta="/administrador/usuarios/"+ruta;this.metodo=metodo;this.procedimiento=sp;
        this.parametros=Collections.unmodifiableSet(new LinkedHashSet<>(Arrays.asList(parametros)));
    }
    public boolean lectura(){return metodo.equals("GET");}
    public static OperacionAdministracionUsuario deRuta(String ruta) {
        for(OperacionAdministracionUsuario op:values())if(op.ruta.equals(ruta))return op;
        return null;
    }
}