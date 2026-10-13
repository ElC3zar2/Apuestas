package com.apuestas.controlador;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.JsonSerializer;
import com.fasterxml.jackson.databind.SerializerProvider;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.core.JsonGenerator;
import java.io.IOException;
import java.time.LocalDateTime;

/** Serializa datos adicionales de lectura sin alterar los nombres JSON anteriores. */
final class ExploracionEventoJson {
    private static final ObjectMapper JSON=new ObjectMapper();
    static {
        SimpleModule fechas=new SimpleModule();
        fechas.addSerializer(LocalDateTime.class,new JsonSerializer<LocalDateTime>() {
            @Override public void serialize(LocalDateTime v,JsonGenerator g,SerializerProvider p) throws IOException {
                g.writeString(v.toString());
            }
        });
        JSON.registerModule(fechas);
    }
    private ExploracionEventoJson() { }
    static String valor(Object v) throws IOException { return JSON.writeValueAsString(v); }
}
