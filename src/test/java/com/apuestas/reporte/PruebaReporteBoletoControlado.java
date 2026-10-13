package com.apuestas.reporte;

import com.apuestas.modelo.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import com.lowagie.text.pdf.PdfReader;
import com.lowagie.text.pdf.parser.PdfTextExtractor;

/** Genera y verifica PDF en memoria; no consulta SQL ni escribe archivos. */
public final class PruebaReporteBoletoControlado {
    public static void main(String[] args)throws Exception {
        int casos=0;
        for(String tipo:Arrays.asList("CONVENCIONAL","MARCADOR_FINAL","PRIMERA_ANOTACION")) {
            Boleto b=new Boleto();b.setCodigoBoleto("B-CONTROLADO");b.setCorreo("prueba@example.invalid");
            b.setTipoBoleto("SIMPLE");b.setEstadoBoleto("PENDIENTE");b.setResultado("PENDIENTE");
            b.setFechaCreacion(LocalDateTime.of(2026,10,1,12,0));b.setMontoApostado(new BigDecimal("100.00"));
            b.setComisionServicio(new BigDecimal("5.00"));b.setTotalCargo(new BigDecimal("105.00"));
            b.setCuotaTotal(new BigDecimal("5.0000"));b.setGananciaPotencial(new BigDecimal("500.00"));
            DetalleBoleto d=new DetalleBoleto();d.setEvento("Evento actual");d.setMercado("Mercado actual");
            d.setSeleccion("Seleccion actual");d.setResultado("PENDIENTE");d.setCuotaAplicada(new BigDecimal("5.0000"));
            d.setTipoMercadoAplicado(tipo);d.setNombreEventoAplicado("Evento congelado");d.setNombreSeleccionAplicada("Participante congelado");
            if(tipo.equals("MARCADOR_FINAL")){d.setPronosticoA(0);d.setPronosticoB(2);d.setNombreSeleccionAplicada("Participante congelado con nombre largo y denominacion completa aceptada en el boleto");}
            b.getDetalles().add(d);
            byte[] pdf=new ReporteBoletoServicio().generarBoleto(b);
            StringBuilder texto=new StringBuilder();
            try(PdfReader reader=new PdfReader(pdf)) {
                PdfTextExtractor extractor=new PdfTextExtractor(reader);
                for(int i=1;i<=reader.getNumberOfPages();i++)texto.append(extractor.getTextFromPage(i));
            }
            String contenido=texto.toString().replaceAll("\\s+"," ");
            if(!contenido.contains(tipo) || !contenido.contains("Evento congelado") || !contenido.contains("Participante congelado")
                    || contenido.contains("Evento actual") || contenido.contains("Seleccion actual"))throw new AssertionError("PDF modalidad/datos congelados " + tipo);
            if(tipo.equals("MARCADOR_FINAL") && !contenido.contains("0 - 2"))throw new AssertionError("Pronostico PDF");
            if(!d.getEvento().equals("Evento actual") || !d.getSeleccion().equals("Seleccion actual") || d.getCuotaAplicada().compareTo(new BigDecimal("5"))!=0)throw new AssertionError("DTO original alterado");
            casos++;
        }
        DetalleBoleto legado=new DetalleBoleto();legado.setEvento("Evento legado");legado.setMercado("Mercado legado");legado.setSeleccion("Seleccion legado");legado.setResultado("GANADA");
        DetalleBoleto copia=ReporteBoletoServicio.detallesReporte(Arrays.asList(legado)).get(0);
        if(!copia.getEvento().equals("Evento legado") || !copia.getMercado().equals("Mercado legado"))throw new AssertionError("Compatibilidad legado");casos++;
        System.out.println("OK: " + casos + " casos de reporte/PDF controlados, 0 fallos.");
    }
}
