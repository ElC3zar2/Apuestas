package com.apuestas.controlador;

import com.apuestas.modelo.*;
import com.apuestas.servicio.AnaliticaUsuarioServicio;
import java.io.IOException;
import java.sql.SQLException;
import java.util.*;
import java.util.logging.Logger;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

@WebServlet("/usuario/analitica/deportes")
public class ResumenUsuarioPorDeporteServlet extends HttpServlet {
    private static final Logger LOG = Logger.getLogger(ResumenUsuarioPorDeporteServlet.class.getName());
    private AnaliticaUsuarioServicio analiticaServicio;

    @Override
    public void init() { analiticaServicio = new AnaliticaUsuarioServicio(); }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        ResumenAnaliticaHttp.preparar(response);
        try {
            Integer idUsuario = ResumenAnaliticaHttp.usuarioAutorizado(request, response);
            if (idUsuario == null) return;
            Map<String,Object> cuerpo = new LinkedHashMap<>();
            cuerpo.put("ok", true);
            List<ResumenUsuarioPorDeporte> deportes =
                    analiticaServicio.obtenerResumenUsuarioPorDeporte(idUsuario);
            cuerpo.put("cantidadDeportes", deportes.size());
            cuerpo.put("deportes", deportes);
            ResumenAnaliticaHttp.escribir(response, 200, cuerpo);
        } catch (SQLException e) {
            LOG.warning("Error SQL al consultar analitica. Codigo: " + e.getErrorCode());
            int codigo = e.getErrorCode();
            ResumenAnaliticaHttp.error(response,
                    codigo == 64004 ? 400 : codigo == 64005 ? 401 : 500);
        } catch (RuntimeException e) {
            LOG.severe("Error interno al consultar analitica.");
            ResumenAnaliticaHttp.error(response, 500);
        }
    }
}
