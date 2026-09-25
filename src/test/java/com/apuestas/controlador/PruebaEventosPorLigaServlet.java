package com.apuestas.controlador;

import com.apuestas.modelo.Evento;
import com.apuestas.servicio.EventoServicio;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.Field;
import java.lang.reflect.Proxy;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/** Prueba ejecutable sin base de datos ni nuevas dependencias de pruebas. */
public class PruebaEventosPorLigaServlet {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static int casos;

    private static void verificar(boolean condicion, String mensaje) {
        if (!condicion) {
            throw new AssertionError(mensaje);
        }
    }

    private static JsonNode consultar(String idLiga, EventoServicio servicio,
                                     int esperado) throws Exception {
        EventosPorLigaServlet servlet = new EventosPorLigaServlet();
        servlet.init();
        Field campo = EventosPorLigaServlet.class.getDeclaredField("eventoServicio");
        campo.setAccessible(true);
        campo.set(servlet, servicio);
        StringWriter cuerpo = new StringWriter();
        int[] estado = {200};
        String[] tipo = {null};
        HttpServletRequest request = (HttpServletRequest) Proxy.newProxyInstance(
                PruebaEventosPorLigaServlet.class.getClassLoader(),
                new Class<?>[]{HttpServletRequest.class}, (proxy, metodo, args) -> {
                    if ("getParameter".equals(metodo.getName())
                            && "idLiga".equals(args[0])) {
                        return idLiga;
                    }
                    throw new AssertionError("Acceso inesperado a request: " + metodo.getName());
                });
        HttpServletResponse response = (HttpServletResponse) Proxy.newProxyInstance(
                PruebaEventosPorLigaServlet.class.getClassLoader(),
                new Class<?>[]{HttpServletResponse.class}, (proxy, metodo, args) -> {
                    switch (metodo.getName()) {
                        case "setContentType": tipo[0] = (String) args[0]; return null;
                        case "setStatus": estado[0] = (Integer) args[0]; return null;
                        case "getWriter": return new PrintWriter(cuerpo);
                        default: throw new AssertionError("Respuesta inesperada: " + metodo.getName());
                    }
                });
        servlet.doGet(request, response);
        verificar(estado[0] == esperado, "HTTP para " + idLiga + ": " + estado[0]);
        verificar("application/json;charset=UTF-8".equals(tipo[0]), "Content-Type");
        JsonNode resultado = JSON.readTree(cuerpo.toString());
        verificar(resultado.path("ok").asBoolean() == (esperado == 200), "ok");
        casos++;
        return resultado;
    }

    public static void main(String[] args) throws Exception {
        verificar(Arrays.asList(EventosPorLigaServlet.class.getAnnotation(WebServlet.class)
                .value()).contains("/eventos/por-liga"), "Mapeo del endpoint");
        EventoServicio noConsultar = new EventoServicio() {
            @Override public java.util.List<Evento> listarEventosPorLiga(int id) {
                throw new AssertionError("No debe consultar con parametro invalido");
            }
        };
        for (String id : new String[]{null, "", "  "}) {
            verificar(consultar(id, noConsultar, 400).path("mensaje").asText()
                    .contains("idLiga es obligatorio"), "Mensaje obligatorio");
        }
        for (String id : new String[]{"abc", "2.5", "2147483648"}) {
            verificar(consultar(id, noConsultar, 400).path("mensaje").asText()
                    .contains("no tiene un formato válido"), "Mensaje formato");
        }
        for (String id : new String[]{"0", "-1"}) {
            consultar(id, new EventoServicio(), 400);
        }
        EventoServicio vacio = new EventoServicio() {
            @Override public java.util.List<Evento> listarEventosPorLiga(int id) {
                verificar(id == 999, "Liga vacia");
                return Collections.emptyList();
            }
        };
        verificar(consultar("999", vacio, 200).equals(JSON.readTree(
                "{\"ok\":true,\"idLiga\":999,\"cantidad\":0,\"eventos\":[]}")), "Lista vacia");
        Evento evento = new Evento(2, "Final \"A\" \\ B\nGuatemala",
                LocalDateTime.of(2026, 9, 24, 18, 0), null);
        evento.setIdEvento(10);
        evento.setIdEstado(1);
        evento.setEstadoEvento("PROGRAMADO");
        EventoServicio conEventos = new EventoServicio() {
            @Override public java.util.List<Evento> listarEventosPorLiga(int id) {
                verificar(id == 2, "Filtro idLiga");
                return Arrays.asList(evento, new Evento(2, null, null, null));
            }
        };
        JsonNode respuesta = consultar(" 2 ", conEventos, 200);
        verificar(respuesta.path("idLiga").asInt() == 2
                && respuesta.path("cantidad").asInt() == 2, "Cabecera");
        JsonNode item = respuesta.path("eventos").get(0);
        Set<String> campos = new HashSet<>();
        item.fieldNames().forEachRemaining(campos::add);
        verificar(campos.equals(new HashSet<>(Arrays.asList("idEvento", "idLiga",
                "idEstado", "estadoEvento", "nombre", "fechaInicio", "fechaFin"))), "Campos");
        verificar(item.path("nombre").asText().equals(evento.getNombre()), "Texto");
        verificar(item.path("idEvento").asInt() == 10 && item.path("idLiga").asInt() == 2
                && item.path("idEstado").asInt() == 1
                && item.path("estadoEvento").asText().equals("PROGRAMADO"), "Datos");
        verificar(item.path("fechaInicio").asText().equals("2026-09-24T18:00")
                && item.path("fechaFin").isNull(), "Fechas");
        verificar(respuesta.path("eventos").get(1).path("nombre").isNull()
                && respuesta.path("eventos").get(1).path("fechaInicio").isNull(), "Nulos");
        EventoServicio error = new EventoServicio() {
            @Override public java.util.List<Evento> listarEventosPorLiga(int id) throws SQLException {
                throw new SQLException("Detalle privado");
            }
        };
        verificar(consultar("2", error, 500).path("mensaje").asText()
                .equals("No fue posible obtener los eventos de la liga."), "Error SQL");
        System.out.println("OK: " + casos + " casos antes de caracteres de control.");
        StringBuilder controles = new StringBuilder("áéñ");
        for (char c = 0; c < 32; c++) {
            controles.append(c);
        }
        evento.setNombre(controles.toString());
        verificar(consultar("2", conEventos, 200).path("eventos").get(0)
                .path("nombre").asText().equals(controles.toString()), "Controles JSON");
        System.out.println("OK: " + casos + " casos; esquema, UTF-8, fechas, nulos, errores y controles JSON.");
    }
}