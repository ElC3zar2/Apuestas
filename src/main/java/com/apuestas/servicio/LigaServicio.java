/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.servicio;

import com.apuestas.dao.LigaDAO;
import com.apuestas.modelo.Liga;

import java.sql.SQLException;
import java.util.List;

/**
 *
 * @author farfa
 */
public class LigaServicio {

    private final LigaDAO ligaDAO;

    public LigaServicio() {

        ligaDAO =
                new LigaDAO();
    }

    public List<Liga> listarLigasPorDeporte(
            int idDeporte)
            throws SQLException {

        validarIdDeporte(
                idDeporte
        );

        return ligaDAO
                .listarLigasPorDeporte(
                        idDeporte
                );
    }

    private void validarIdDeporte(
            int idDeporte) {

        if (idDeporte <= 0) {

            throw new IllegalArgumentException(
                    "El deporte seleccionado "
                    + "no es válido."
            );
        }
    }
}
