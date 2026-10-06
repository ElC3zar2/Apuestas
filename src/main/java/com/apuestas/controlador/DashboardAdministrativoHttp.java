package com.apuestas.controlador;
/** Codigos de los dos SP de 11_AnaliticaAdministrativa.sql. Nunca publica mensajes SQL. */
public final class DashboardAdministrativoHttp {
    private DashboardAdministrativoHttp() { }
    public static int estadoSql(int codigo) {
        switch(codigo) {
            case 64018:case 64019:case 64020:case 64028:case 64029:case 64030:return 403;
            case 64021:return 404;
            case 64022:case 64023:case 64024:case 64025:case 64026:case 64027:return 400;
            default:return 500;
        }
    }
}
