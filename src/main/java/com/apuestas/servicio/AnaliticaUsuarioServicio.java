package com.apuestas.servicio;

import com.apuestas.dao.AnaliticaUsuarioDAO;
import com.apuestas.modelo.AnaliticaBoletoUsuario;
import java.sql.SQLException;
import java.util.*;

public class AnaliticaUsuarioServicio {
    private final AnaliticaUsuarioDAO analiticaDAO;

    public AnaliticaUsuarioServicio() { this(new AnaliticaUsuarioDAO()); }

    public AnaliticaUsuarioServicio(AnaliticaUsuarioDAO analiticaDAO) {
        this.analiticaDAO = Objects.requireNonNull(analiticaDAO);
    }

    public List<AnaliticaBoletoUsuario> obtenerAnaliticaBoletosUsuario(
            int idUsuario, Integer idDeporte) throws SQLException {
        if (idUsuario <= 0) throw new IllegalArgumentException("Usuario invalido.");
        if (idDeporte != null && idDeporte <= 0) {
            throw new IllegalArgumentException("Deporte invalido.");
        }
        return analiticaDAO.obtenerAnaliticaBoletosUsuario(idUsuario, idDeporte);
    }
}
