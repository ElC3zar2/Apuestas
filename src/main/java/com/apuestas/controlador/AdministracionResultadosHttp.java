package com.apuestas.controlador;

/** Traduccion del contrato 06_Resultados.sql y su auxiliar sp_ValidarPermisoEventos. */
public final class AdministracionResultadosHttp {
    private AdministracionResultadosHttp() { }
    public static int estadoSql(int codigo) {
        switch(codigo) {
            case 59001:case 61001:case 61002:case 61007:case 61008:case 61009:
            case 61016:case 61025:case 61026:case 61027:case 61028:
            case 61038:case 61039:case 61040:return 400;
            case 59002:case 59003:case 59004:case 61029:case 61030:case 61031:
            case 61041:case 61042:case 61043:return 403;
            case 61004:case 61010:case 61012:case 61020:case 61035:case 61047:return 404;
            case 61005:case 61006:case 61011:case 61013:case 61014:case 61015:
            case 61021:case 61022:case 61023:case 61024:case 61036:case 61037:case 61048:return 409;
            // Catalogos internos incompletos y errores desconocidos no se revelan.
            default:return 500;
        }
    }
}