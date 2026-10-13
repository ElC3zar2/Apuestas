package com.apuestas.controlador;

import com.apuestas.modelo.BilleteraUsuario;
import com.apuestas.servicio.BilleteraServicio;
import java.io.IOException;
import java.sql.SQLException;
import java.util.*;
import java.util.logging.Logger;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet("/usuario/billetera/resumen")
public class BilleteraResumenServlet extends HttpServlet {
    private static final Logger LOG = Logger.getLogger(BilleteraResumenServlet.class.getName());
    private BilleteraServicio billeteraServicio;

    @Override
    public void init() { billeteraServicio = new BilleteraServicio(); }

    @Override
    protected void service(HttpServletRequest request,HttpServletResponse response) throws javax.servlet.ServletException,IOException {
        if(!"GET".equals(request.getMethod())) {
            response.setContentType("application/json;charset=UTF-8");
            response.setHeader("Cache-Control","no-store");response.setHeader("Allow","GET");
            BilleteraHttp.error(response,405); return;
        }
        super.service(request,response);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        BilleteraHttp.preparar(response);
        Integer idUsuario = BilleteraHttp.usuarioAutorizado(request,response);
        if (idUsuario == null) {
            return;
        }
        try {
            BilleteraUsuario billetera = billeteraServicio.obtenerBilletera(idUsuario);
            Map<String, Object> cuerpo = new LinkedHashMap<>();
            cuerpo.put("ok", true);
            cuerpo.put("idUsuario", billetera.getIdUsuario());
            cuerpo.put("correo", billetera.getCorreo());
            cuerpo.put("rol", billetera.getRol());
            cuerpo.put("estadoUsuario", billetera.getEstadoUsuario());
            cuerpo.put("idBilletera", billetera.getIdBilletera());
            cuerpo.put("saldoDisponible", billetera.getSaldoDisponible());
            cuerpo.put("saldoComprometido", billetera.getSaldoComprometido());
            cuerpo.put("saldoVirtualTotal", billetera.getSaldoVirtualTotal());
            cuerpo.put("fechaCreacion", BilleteraHttp.fecha(billetera.getFechaCreacion()));
            BilleteraHttp.escribir(response, 200, cuerpo);
        } catch (IllegalArgumentException e) {
            BilleteraHttp.error(response, 400);
        } catch (SQLException e) {
            LOG.warning("Error SQL en consulta de billetera. Codigo: " + e.getErrorCode());
            BilleteraHttp.error(response, BilleteraHttp.estadoSql(e.getErrorCode(), false));
        } catch (RuntimeException e) {
            LOG.severe("Error interno en consulta de billetera.");
            BilleteraHttp.error(response, 500);
        }
    }
}
