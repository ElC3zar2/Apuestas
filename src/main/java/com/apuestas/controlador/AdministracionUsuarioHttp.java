package com.apuestas.controlador;

import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.core.JsonGenerator;
import java.io.IOException;
import java.time.*;
import java.util.*;
import javax.servlet.http.HttpServletResponse;

/** JSON y traduccion segura del contrato 08_AdministracionUsuario.sql. */
public final class AdministracionUsuarioHttp {
    private static final ObjectMapper JSON=new ObjectMapper();
    static {
        SimpleModule fechas=new SimpleModule();
        fechas.addSerializer(LocalDateTime.class,new JsonSerializer<LocalDateTime>(){
            @Override public void serialize(LocalDateTime v,JsonGenerator g,SerializerProvider p)throws IOException{g.writeString(v.toString());}
        });
        fechas.addSerializer(LocalDate.class,new JsonSerializer<LocalDate>(){
            @Override public void serialize(LocalDate v,JsonGenerator g,SerializerProvider p)throws IOException{g.writeString(v.toString());}
        });
        JSON.registerModule(fechas);
    }
    private AdministracionUsuarioHttp(){}
    public static void preparar(HttpServletResponse res){
        res.setContentType("application/json;charset=UTF-8");res.setHeader("Cache-Control","no-store");
    }
    public static void escribir(HttpServletResponse res,int estado,Object cuerpo)throws IOException {
        String json=JSON.writeValueAsString(cuerpo);
        preparar(res);res.setStatus(estado);res.getWriter().print(json);
    }
    public static void error(HttpServletResponse res,int estado)throws IOException {
        String mensaje;
        switch(estado){
            case 400:mensaje="Los parámetros no son válidos.";break;
            case 401:mensaje="Autenticación requerida.";break;
            case 403:mensaje="Acceso no permitido.";break;
            case 404:mensaje="No se encontró el recurso solicitado.";break;
            case 405:mensaje="Método no permitido.";break;
            case 409:mensaje="La operación no es compatible con el estado actual.";break;
            default:mensaje="No fue posible procesar la solicitud.";
        }
        Map<String,Object> cuerpo=new LinkedHashMap<>();cuerpo.put("ok",false);cuerpo.put("mensaje",mensaje);
        escribir(res,estado,cuerpo);
    }
    public static int estadoSql(int c){
        switch(c){
            case 63001:case 63005:case 63006:case 63012:case 63016:case 63020:case 63025:
            case 63030:case 63031:case 63036:case 63042:case 63043:case 63044:case 63052:
            case 63053:case 63054:case 63055:case 63060:case 63061:return 400;
            case 63002:case 63003:case 63004:case 63007:case 63008:case 63009:case 63011:
            case 63013:case 63014:case 63015:case 63019:case 63023:case 63039:case 63047:case 63057:return 403;
            case 63010:case 63018:case 63022:case 63028:case 63034:case 63038:
            case 63046:case 63056:case 63062:return 404;
            case 63024:case 63029:case 63035:case 63040:case 63041:case 63048:case 63049:
            case 63050:case 63051:case 63058:case 63059:return 409;
            default:return 500;
        }
    }
}