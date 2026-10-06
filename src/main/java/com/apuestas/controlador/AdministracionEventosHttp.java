package com.apuestas.controlador;

/** Codigos oficiales de 04_EventosMercados.sql; los mensajes publicos son genericos. */
public final class AdministracionEventosHttp {
    private AdministracionEventosHttp() { }
    public static int estadoSql(int codigo) {
        switch(codigo) {
            case 59002:case 59003:case 59004:return 403;
            case 59013:case 59025:case 59037:case 59040:case 59048:
            case 59052:case 59056:case 59062:case 59069:return 404;
            case 59008:case 59014:case 59015:case 59020:case 59026:case 59027:
            case 59038:case 59041:case 59043:case 59044:case 59045:case 59049:
            case 59050:case 59053:case 59054:case 59057:case 59058:case 59063:
            case 59064:case 59070:case 59071:case 59072:case 59073:return 409;
            case 59001:case 59005:case 59006:case 59007:case 59009:case 59010:case 59011:
            case 59012:case 59016:case 59017:case 59018:case 59019:case 59021:case 59022:
            case 59023:case 59024:case 59028:case 59029:case 59030:case 59031:case 59033:
            case 59034:case 59035:case 59036:case 59039:case 59042:case 59046:case 59051:
            case 59055:case 59059:case 59060:case 59061:case 59066:case 59067:case 59068:return 400;
            // 59032, 59047, 59065: catalogos internos incompletos. Desconocidos: 500.
            default:return 500;
        }
    }
}