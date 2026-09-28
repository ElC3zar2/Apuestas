package com.apuestas.controlador;

import com.apuestas.modelo.ResultadoApuesta;
import com.apuestas.servicio.ApuestaServicio;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.math.BigDecimal;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.logging.Logger;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

@WebServlet("/apuestas/realizar")
public class RealizarApuestaServlet extends HttpServlet {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final Logger LOG = Logger.getLogger(RealizarApuestaServlet.class.getName());
    private static final String ERROR_INTERNO = "No fue posible confirmar la apuesta.";
    private ApuestaServicio apuestaServicio;

    @Override
    public void init() {
        apuestaServicio = new ApuestaServicio();
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        request.setCharacterEncoding("UTF-8");
        response.setContentType("application/json;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");

        HttpSession sesion = request.getSession(false);
        Integer idUsuario;
        Object rol;
        try {
            idUsuario = sesion == null ? null : idUsuarioSesion(sesion.getAttribute("idUsuario"));
            rol = sesion == null ? null : sesion.getAttribute("rol");
        } catch (IllegalStateException e) {
            // La sesion pudo expirar entre getSession(false) y getAttribute.
            idUsuario = null;
            rol = null;
        }
        if (idUsuario == null) {
            error(response, 401, "Debe iniciar sesión para realizar una apuesta.");
            return;
        }
        if (!"USUARIO".equals(rol)) {
            error(response, 403, "La sesión no tiene permisos para realizar apuestas.");
            return;
        }

        try {
            List<Integer> selecciones = selecciones(request);
            BigDecimal monto;
            try {
                monto = new BigDecimal(obligatorio(request, "monto"));
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException("El monto no tiene un formato válido.");
            }
            String referenciaTexto = obligatorio(request, "referenciaOperacion");
            if (!referenciaTexto.matches(
                    "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")) {
                throw new IllegalArgumentException("La referencia de operación no es un UUID válido.");
            }
            UUID referencia = UUID.fromString(referenciaTexto);
            ResultadoApuesta resultado = apuestaServicio.realizarApuesta(
                    idUsuario, selecciones, monto, referencia, request.getRemoteAddr());

            Map<String, Object> cuerpo = new LinkedHashMap<>();
            cuerpo.put("ok", true);
            cuerpo.put("idBoleto", resultado.getIdBoleto());
            cuerpo.put("codigoBoleto", resultado.getCodigoBoleto());
            cuerpo.put("tipoBoleto", resultado.getTipoBoleto());
            cuerpo.put("cantidadSelecciones", resultado.getCantidadSelecciones());
            cuerpo.put("montoApostado", resultado.getMontoApostado());
            cuerpo.put("comisionServicioPorcentaje", resultado.getComisionServicioPorcentaje());
            cuerpo.put("comisionServicio", resultado.getComisionServicio());
            cuerpo.put("totalCargo", resultado.getTotalCargo());
            cuerpo.put("cuotaTotal", resultado.getCuotaTotal());
            cuerpo.put("gananciaPotencial", resultado.getGananciaPotencial());
            cuerpo.put("referenciaOperacion", resultado.getReferenciaOperacion());
            cuerpo.put("solicitudIdempotente", resultado.isSolicitudIdempotente());
            String json = JSON.writeValueAsString(cuerpo);
            response.setStatus(resultado.isSolicitudIdempotente() ? 200 : 201);
            response.getWriter().print(json);
        } catch (IllegalArgumentException e) {
            error(response, 400, "Los datos de la apuesta no son válidos. Revise selecciones, monto y referencia.");
        } catch (SQLException e) {
            int estado = estadoSql(e.getErrorCode());
            if (estado == 500) {
                LOG.severe("Error SQL al confirmar apuesta. Codigo: " + e.getErrorCode());
            }
            error(response, estado, mensajeSql(e.getErrorCode()));
        } catch (RuntimeException e) {
            LOG.severe("Error interno al confirmar apuesta.");
            error(response, 500, ERROR_INTERNO);
        }
    }

    private Integer idUsuarioSesion(Object valor) {
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

    private String obligatorio(HttpServletRequest request, String nombre) {
        String valor = request.getParameter(nombre);
        if (valor == null || valor.trim().isEmpty()) {
            throw new IllegalArgumentException("Falta un parámetro obligatorio.");
        }
        return valor.trim();
    }

    private List<Integer> selecciones(HttpServletRequest request) {
        String[] valores = request.getParameterValues("idSeleccion");
        if (valores == null || valores.length == 0) {
            throw new IllegalArgumentException("Debe indicar selecciones.");
        }
        List<Integer> ids = new ArrayList<>();
        for (String valor : valores) {
            if (valor == null || valor.trim().isEmpty()) {
                throw new IllegalArgumentException("Selección no válida.");
            }
            ids.add(Integer.valueOf(valor.trim()));
        }
        // Positividad y duplicados se validan en el servicio existente.
        return ids;
    }

    /** Solo codigos emitidos por sp_RealizarApuesta; no usar mensajes SQL como contenido HTTP. */
    private int estadoSql(int codigo) {
        switch (codigo) {
            case 60016: case 60017: case 60018: case 60019: case 60020:
            case 60022: case 60023: case 60024: case 60025:
            case 60042: case 60043: case 60044: case 60061: case 60062:
                return 400;
            case 60033:
                return 401;
            case 60034: case 60035: case 60036: case 60037: case 60038: case 60039:
                return 403;
            case 60029: case 60030: case 60031: case 60032:
            case 60040: case 60046: case 60056:
                return 409;
            // Configuracion, billetera ausente, cuotas inconsistentes y codigos desconocidos.
            default:
                return 500;
        }
    }

    private String mensajeSql(int codigo) {
        switch (codigo) {
            case 60029: case 60030: case 60031: case 60032:
                return "La referencia de operación ya fue utilizada para otra solicitud.";
            case 60040: case 60056:
                return "Una o más selecciones ya no están disponibles o el periodo de apuestas cerró.";
            case 60046:
                return "El saldo disponible es insuficiente para cubrir la apuesta y su comisión.";
            case 60022:
                return "El monto es menor al mínimo permitido para apostar.";
            default:
                switch (estadoSql(codigo)) {
                    case 400: return "La solicitud de apuesta no cumple los límites o requisitos permitidos.";
                    case 401: return "La sesión del usuario ya no es válida.";
                    case 403: return "La cuenta no está habilitada para realizar apuestas.";
                    default: return ERROR_INTERNO;
                }
        }
    }

    private void error(HttpServletResponse response, int estado, String mensaje) throws IOException {
        Map<String, Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("ok", false);
        cuerpo.put("mensaje", mensaje);
        String json = JSON.writeValueAsString(cuerpo);
        response.setStatus(estado);
        response.getWriter().print(json);
    }
}
