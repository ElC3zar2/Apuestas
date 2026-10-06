package com.apuestas.controlador;

/** Codigos reales de 07_Liquidacion.sql, sin mensajes internos del proveedor. */
public final class LiquidacionAdministrativaHttp {
    private LiquidacionAdministrativaHttp() { }
    public static int estadoSql(int codigo) {
        switch(codigo) {
            case 62001:case 62005:case 62006:case 62032:case 62033:return 400;
            case 62002:case 62003:case 62004:case 62035:case 62036:return 403;
            case 62017:case 62034:case 62037:return 404;
            case 62018:case 62019:case 62020:case 62021:case 62022:
            case 62023:case 62024:case 62030:case 62031:case 62039:return 409;
            // Catalogos, invariantes financieras y fallos internos/desconocidos.
            default:return 500;
        }
    }
}