package com.apuestas.controlador;

import com.apuestas.modelo.MovimientoBilletera;
import com.apuestas.servicio.BilleteraServicio;
import java.io.IOException;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.*;
import java.util.logging.Logger;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet("/usuario/billetera/movimientos")
public class MovimientosBilleteraServlet extends HttpServlet {
    private static final Logger LOG = Logger.getLogger(MovimientosBilleteraServlet.class.getName());
    private BilleteraServicio billeteraServicio;

    @Override
    public void init() { billeteraServicio = new BilleteraServicio(); }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        BilleteraHttp.preparar(response);
        Integer idUsuario = BilleteraHttp.usuario(request);
        if (idUsuario == null) {
            BilleteraHttp.error(response, 401);
            return;
        }
        try {
            LocalDateTime desde = BilleteraHttp.fechaEntrada(request.getParameter("fechaDesde"));
            LocalDateTime hasta = BilleteraHttp.fechaEntrada(request.getParameter("fechaHasta"));
            String cantidadTexto = request.getParameter("cantidad");
            int cantidad = cantidadTexto == null ? 100 : Integer.parseInt(cantidadTexto.trim());
            List<MovimientoBilletera> movimientos = billeteraServicio.obtenerMovimientosBilletera(
                    idUsuario, desde, hasta, cantidad);
            List<Map<String, Object>> items = new ArrayList<>();
            for (MovimientoBilletera movimiento : movimientos) {
                Map<String, Object> item = new LinkedHashMap<>();
            item.put("idMovimiento", movimiento.getIdMovimiento());
            item.put("fechaMovimiento", BilleteraHttp.fecha(movimiento.getFechaMovimiento()));
            item.put("idTransaccion", movimiento.getIdTransaccion());
            item.put("referenciaOperacion", movimiento.getReferenciaOperacion());
            item.put("monto", movimiento.getMonto());
            item.put("fechaSolicitud", BilleteraHttp.fecha(movimiento.getFechaSolicitud()));
            item.put("fechaProcesamiento", BilleteraHttp.fecha(movimiento.getFechaProcesamiento()));
            item.put("descripcion", movimiento.getDescripcion());
            item.put("tipoTransaccion", movimiento.getTipoTransaccion());
            item.put("nombreTipoTransaccion", movimiento.getNombreTipoTransaccion());
            item.put("estadoTransaccion", movimiento.getEstadoTransaccion());
            item.put("idBoleto", movimiento.getIdBoleto());
            item.put("saldoDisponibleAnterior", movimiento.getSaldoDisponibleAnterior());
            item.put("saldoDisponiblePosterior", movimiento.getSaldoDisponiblePosterior());
            item.put("variacionSaldoDisponible", movimiento.getVariacionSaldoDisponible());
            item.put("saldoComprometidoAnterior", movimiento.getSaldoComprometidoAnterior());
            item.put("saldoComprometidoPosterior", movimiento.getSaldoComprometidoPosterior());
            item.put("variacionSaldoComprometido", movimiento.getVariacionSaldoComprometido());
            item.put("idUsuarioProceso", movimiento.getIdUsuarioProceso());
            item.put("usuarioProceso", movimiento.getUsuarioProceso());
                items.add(item);
            }
            Map<String, Object> cuerpo = new LinkedHashMap<>();
            cuerpo.put("ok", true);
            cuerpo.put("cantidad", items.size());
            cuerpo.put("movimientos", items);
            BilleteraHttp.escribir(response, 200, cuerpo);
        } catch (IllegalArgumentException e) {
            BilleteraHttp.error(response, 400);
        } catch (SQLException e) {
            LOG.warning("Error SQL en consulta de billetera. Codigo: " + e.getErrorCode());
            BilleteraHttp.error(response, BilleteraHttp.estadoSql(e.getErrorCode(), true));
        } catch (RuntimeException e) {
            LOG.severe("Error interno en consulta de billetera.");
            BilleteraHttp.error(response, 500);
        }
    }
}
