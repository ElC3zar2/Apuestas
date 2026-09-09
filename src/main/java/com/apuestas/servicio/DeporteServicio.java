/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.servicio;

import com.apuestas.dao.DeporteDAO;
import com.apuestas.modelo.Deporte;

import java.sql.SQLException;
import java.util.List;
/**
 *
 * @author farfa
 */
public class DeporteServicio {

    private final DeporteDAO deporteDAO;

    public DeporteServicio() {
        this.deporteDAO = new DeporteDAO();
    }

    public List<Deporte> listarDeportesActivos()
            throws SQLException {

        return deporteDAO.listarDeportesActivos();
    }

    public Deporte buscarPorId(int idDeporte)
            throws SQLException {

        if (idDeporte <= 0) {
            throw new IllegalArgumentException(
                    "El deporte seleccionado no es válido."
            );
        }

        Deporte deporte =
                deporteDAO.buscarPorId(idDeporte);

        if (deporte == null) {
            throw new IllegalArgumentException(
                    "El deporte no existe."
            );
        }

        return deporte;
    }
}