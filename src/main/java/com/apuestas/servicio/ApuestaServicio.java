/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.servicio;

import com.apuestas.dao.ApuestaDAO;
import com.apuestas.modelo.Boleto;
import com.apuestas.modelo.CotizacionApuesta;
import com.apuestas.modelo.ResultadoApuesta;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.util.List;
import java.util.UUID;

/**
 *
 * @author farfa
 */
public class ApuestaServicio {

    private final ApuestaDAO apuestaDAO;

    public ApuestaServicio() {
        this.apuestaDAO =
                new ApuestaDAO();
    }

    public CotizacionApuesta cotizarApuesta(
            List<Integer> idSelecciones,
            BigDecimal monto)
            throws SQLException {

        validarSelecciones(
                idSelecciones
        );

        validarMonto(
                monto
        );

        String seleccionesJson =
                construirSeleccionesJson(
                        idSelecciones
                );

        try {

            return apuestaDAO.cotizarApuesta(
                    seleccionesJson,
                    monto
            );

        } catch (SQLException e) {

            throw traducirErrorApuesta(
                    e
            );
        }
    }

    public ResultadoApuesta realizarApuesta(
            int idUsuario,
            List<Integer> idSelecciones,
            BigDecimal monto,
            UUID referenciaOperacion,
            String ipOrigen)
            throws SQLException {

        validarUsuario(
                idUsuario
        );

        validarSelecciones(
                idSelecciones
        );

        validarMonto(
                monto
        );

        if (referenciaOperacion == null) {

            throw new IllegalArgumentException(
                    "La referencia de operación "
                    + "es obligatoria."
            );
        }

        String seleccionesJson =
                construirSeleccionesJson(
                        idSelecciones
                );

        try {

            return apuestaDAO.realizarApuesta(
                    idUsuario,
                    seleccionesJson,
                    monto,
                    referenciaOperacion,
                    ipOrigen
            );

        } catch (SQLException e) {

            throw traducirErrorApuesta(
                    e
            );
        }
    }

    public Boleto obtenerBoletoPorId(
            int idUsuarioSolicitante,
            int idBoleto)
            throws SQLException {

        validarUsuario(
                idUsuarioSolicitante
        );

        if (idBoleto <= 0) {

            throw new IllegalArgumentException(
                    "El boleto seleccionado no es válido."
            );
        }

        return apuestaDAO.obtenerBoleto(
                idUsuarioSolicitante,
                idBoleto,
                null
        );
    }

    public Boleto obtenerBoletoPorCodigo(
            int idUsuarioSolicitante,
            String codigoBoleto)
            throws SQLException {

        validarUsuario(
                idUsuarioSolicitante
        );

        if (codigoBoleto == null
                || codigoBoleto.trim().isEmpty()) {

            throw new IllegalArgumentException(
                    "El código del boleto es obligatorio."
            );
        }

        String codigo =
                codigoBoleto.trim();

        if (codigo.length() > 40) {

            throw new IllegalArgumentException(
                    "El código del boleto no puede superar "
                    + "los 40 caracteres."
            );
        }

        return apuestaDAO.obtenerBoleto(
                idUsuarioSolicitante,
                null,
                codigo
        );
    }

    private void validarUsuario(
            int idUsuario) {

        if (idUsuario <= 0) {

            throw new IllegalArgumentException(
                    "El usuario no es válido."
            );
        }
    }

    private void validarSelecciones(
            List<Integer> idSelecciones) {

        if (idSelecciones == null
                || idSelecciones.isEmpty()) {

            throw new IllegalArgumentException(
                    "Debe seleccionar al menos "
                    + "una opción para apostar."
            );
        }

        for (Integer idSeleccion
                : idSelecciones) {

            if (idSeleccion == null
                    || idSeleccion <= 0) {

                throw new IllegalArgumentException(
                        "Existe una selección no válida."
                );
            }
        }

        long cantidadUnicas =
                idSelecciones
                        .stream()
                        .distinct()
                        .count();

        if (cantidadUnicas
                != idSelecciones.size()) {

            throw new IllegalArgumentException(
                    "No se puede repetir una selección "
                    + "en el mismo boleto."
            );
        }
    }

    private void validarMonto(
            BigDecimal monto) {

        if (monto == null
                || monto.compareTo(
                        BigDecimal.ZERO
                ) <= 0) {

            throw new IllegalArgumentException(
                    "El monto debe ser mayor que cero."
            );
        }
    }

    private String construirSeleccionesJson(
            List<Integer> idSelecciones) {

        StringBuilder json =
                new StringBuilder("[");

        for (int i = 0;
             i < idSelecciones.size();
             i++) {

            if (i > 0) {
                json.append(",");
            }

            json.append(
                    idSelecciones.get(i)
            );
        }

        json.append("]");

        return json.toString();
    }

    private SQLException traducirErrorApuesta(
            SQLException e) {

        int codigo =
                e.getErrorCode();

        String mensaje;

        switch (codigo) {

            case 60054:

                mensaje =
                        "El periodo para apostar "
                        + "ya cerró.";

                break;

            case 60056:

                mensaje =
                        "El evento cerró mientras "
                        + "se confirmaba la apuesta.";

                break;

            case 60005:
            case 60022:

                mensaje =
                        "El monto es menor al mínimo "
                        + "permitido para apostar.";

                break;

            default:

                return e;
        }

        return new SQLException(
                mensaje,
                e.getSQLState(),
                codigo,
                e
        );
    }
}