package com.apuestas.controlador;

import com.apuestas.modelo.*;
import com.apuestas.servicio.AnaliticaUsuarioServicio;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.math.BigDecimal;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.logging.Logger;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet("/usuario/boletos/historial")
public class HistorialBoletosUsuarioServlet extends HttpServlet {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final Logger LOG = Logger.getLogger(HistorialBoletosUsuarioServlet.class.getName());
    private AnaliticaUsuarioServicio analiticaServicio;

    @Override
    public void init() { analiticaServicio = new AnaliticaUsuarioServicio(); }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        response.setContentType("application/json;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");
        try {
            HttpSession sesion = request.getSession(false);
            Integer idUsuario;
            Object rol;
            try {
                idUsuario = sesion == null ? null : usuario(sesion.getAttribute("idUsuario"));
                rol = sesion == null ? null : sesion.getAttribute("rol");
            } catch (IllegalStateException e) {
                idUsuario = null;
                rol = null;
            }
            if (idUsuario == null) { error(response, 401); return; }
            if (!"USUARIO".equals(rol)) { error(response, 403); return; }

            String filtro = request.getParameter("idDeporte");
            Integer idDeporte = null;
            if (filtro != null) {
                try {
                    if (!filtro.matches("[0-9]+")) throw new NumberFormatException();
                    idDeporte = Integer.valueOf(filtro);
                    if (idDeporte <= 0) throw new NumberFormatException();
                } catch (NumberFormatException e) {
                    error(response, 400);
                    return;
                }
            }
            List<Map<String, Object>> boletos = new ArrayList<>();
            for (AnaliticaBoletoUsuario boleto :
                    analiticaServicio.obtenerAnaliticaBoletosUsuario(idUsuario, idDeporte)) {
                boletos.add(resumen(boleto));
            }
            Map<String, Object> cuerpo = new LinkedHashMap<>();
            cuerpo.put("ok", true);
            cuerpo.put("idDeporte", idDeporte);
            cuerpo.put("cantidadBoletos", boletos.size());
            cuerpo.put("boletos", boletos);
            escribir(response, 200, cuerpo);
        } catch (SQLException e) {
            LOG.warning("Error SQL al consultar historial. Codigo: " + e.getErrorCode());
            int codigo = e.getErrorCode();
            error(response, codigo == 64002 ? 401 : codigo == 64001 || codigo == 64003 ? 400 : 500);
        } catch (RuntimeException e) {
            LOG.severe("Error interno al consultar historial.");
            error(response, 500);
        }
    }

    private Integer usuario(Object valor) {
        if (!(valor instanceof Number) && !(valor instanceof String)) return null;
        try {
            String texto = valor.toString().trim();
            if (valor instanceof String && !texto.matches("[0-9]+")) return null;
            int id = new BigDecimal(texto).intValueExact();
            return id > 0 ? id : null;
        } catch (ArithmeticException | NumberFormatException e) {
            return null;
        }
    }

    private Map<String, Object> resumen(AnaliticaBoletoUsuario boleto) {
        Map<String, Object> datos = new LinkedHashMap<>();
        datos.put("idBoleto", boleto.getIdBoleto());
        datos.put("codigoBoleto", boleto.getCodigoBoleto());
        datos.put("tipoBoleto", boleto.getTipoBoleto());
        datos.put("resultado", boleto.getResultado());
        datos.put("estadoBoleto", boleto.getEstadoBoleto());
        datos.put("fechaCreacion", fecha(boleto.getFechaCreacion()));
        datos.put("fechaLiquidacion", fecha(boleto.getFechaLiquidacion()));
        datos.put("montoApostado", boleto.getMontoApostado());
        datos.put("comisionServicio", boleto.getComisionServicio());
        datos.put("totalCargo", boleto.getTotalCargo());
        datos.put("cuotaTotal", boleto.getCuotaTotal());
        datos.put("premioPotencial", boleto.getPremioPotencial());
        datos.put("gananciaNetaPotencial", boleto.getGananciaNetaPotencial());
        datos.put("porcentajeGananciaPotencial", boleto.getPorcentajeGananciaPotencial());
        datos.put("probabilidadImplicitaPorcentaje", boleto.getProbabilidadImplicitaPorcentaje());
        datos.put("cantidadSelecciones", boleto.getCantidadSelecciones());
        List<Map<String, Object>> detalles = new ArrayList<>();
        for (DetalleAnaliticaBoletoUsuario detalle : boleto.getDetalles()) detalles.add(detalle(detalle));
        datos.put("detalles", detalles);
        return datos;
    }

    private Map<String, Object> detalle(DetalleAnaliticaBoletoUsuario detalle) {
        Map<String, Object> datos = new LinkedHashMap<>();
        datos.put("idDetalle", detalle.getIdDetalle());
        datos.put("idDeporte", detalle.getIdDeporte());
        datos.put("deporte", detalle.getDeporte());
        datos.put("idLiga", detalle.getIdLiga());
        datos.put("liga", detalle.getLiga());
        datos.put("idEvento", detalle.getIdEvento());
        datos.put("evento", detalle.getEvento());
        datos.put("fechaInicio", fecha(detalle.getFechaInicio()));
        datos.put("idMercado", detalle.getIdMercado());
        datos.put("mercado", detalle.getMercado());
        datos.put("idSeleccion", detalle.getIdSeleccion());
        datos.put("seleccion", detalle.getSeleccion());
        datos.put("cuotaAplicada", detalle.getCuotaAplicada());
        datos.put("probabilidadImplicitaSeleccionPorcentaje", detalle.getProbabilidadImplicitaSeleccionPorcentaje());
        datos.put("resultadoSeleccion", detalle.getResultadoSeleccion());
        return datos;
    }

    private String fecha(LocalDateTime valor) {
        return valor == null ? null : DateTimeFormatter.ISO_LOCAL_DATE_TIME.format(valor);
    }

    private void escribir(HttpServletResponse response, int estado, Map<String, Object> cuerpo)
            throws IOException {
        String json = JSON.writeValueAsString(cuerpo);
        response.setStatus(estado);
        response.getWriter().print(json);
    }

    private void error(HttpServletResponse response, int estado) throws IOException {
        String mensaje = estado == 400 ? "Los parametros de la consulta no son validos."
                : estado == 401 ? "Debe iniciar sesion con un usuario valido."
                : estado == 403 ? "No tiene permiso para consultar el historial."
                : "No fue posible consultar el historial.";
        Map<String, Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("ok", false);
        cuerpo.put("mensaje", mensaje);
        escribir(response, estado, cuerpo);
    }
}
