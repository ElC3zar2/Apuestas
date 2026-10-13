package com.apuestas.controlador;

import javax.servlet.http.HttpServletRequest;

/** Parametros de formulario y codigos realmente emitidos por los dos SP de apuestas. */
final class ApuestaHttp {
    private ApuestaHttp() { }
    static Integer pronostico(HttpServletRequest req,String nombre) {
        String[] valores=req.getParameterValues(nombre);
        if(valores==null) return null;
        if(valores.length!=1 || valores[0]==null || !valores[0].trim().matches("[0-9]{1,10}"))
            throw new IllegalArgumentException("Pronostico invalido.");
        return Integer.valueOf(valores[0].trim());
    }
    static int estadoCotizacion(int c) {
        switch(c) {
            case 60001:case 60002:case 60003:case 60005:case 60006:case 60007:case 60008:
            case 60013:case 60014:case 60015:case 60058:case 60059:case 76101:case 76102:return 400;
            case 60009:case 60011:case 60012:case 60054:return 409;
            // Configuracion, ofertas inconsistentes (60010/76103) y desconocidos son internos.
            default:return 500;
        }
    }
    static int estadoRealizacion(int c) {
        switch(c) {
            case 60016:case 60017:case 60018:case 60019:case 60020:case 60022:case 60023:
            case 60024:case 60025:case 60042:case 60043:case 60044:case 60061:case 60062:
            case 76101:case 76102:return 400;
            case 60033:return 401;
            case 60034:case 60035:case 60036:case 60037:case 60038:case 60039:return 403;
            case 60029:case 60030:case 60031:case 60032:case 60040:case 60046:case 60056:
            case 76104:case 76106:return 409;
            case 76900:return 503;
            // 76105 y catalogos/invariantes financieras son internos, no errores del cliente.
            default:return 500;
        }
    }
}
