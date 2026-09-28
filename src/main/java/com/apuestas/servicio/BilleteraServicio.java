package com.apuestas.servicio;

import com.apuestas.dao.BilleteraDAO;
import com.apuestas.modelo.BilleteraUsuario;
import com.apuestas.modelo.MovimientoBilletera;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Objects;

public class BilleteraServicio {
    private final BilleteraDAO billeteraDAO;

    public BilleteraServicio() { this(new BilleteraDAO()); }
    public BilleteraServicio(BilleteraDAO billeteraDAO) {
        this.billeteraDAO = Objects.requireNonNull(billeteraDAO);
    }

    public BilleteraUsuario obtenerBilletera(int idUsuario) throws SQLException {
        validarUsuario(idUsuario);
        return billeteraDAO.obtenerBilleteraUsuario(idUsuario);
    }

    public List<MovimientoBilletera> obtenerMovimientosBilletera(int idUsuario,
            LocalDateTime fechaDesde, LocalDateTime fechaHasta, int cantidad) throws SQLException {
        validarUsuario(idUsuario);
        if (cantidad < 1 || cantidad > 500) {
            throw new IllegalArgumentException("Cantidad fuera del rango 1..500.");
        }
        if (fechaDesde != null && fechaHasta != null && fechaHasta.isBefore(fechaDesde)) {
            throw new IllegalArgumentException("Rango de fechas invalido.");
        }
        return billeteraDAO.obtenerMovimientosBilletera(idUsuario, fechaDesde, fechaHasta, cantidad);
    }

    private void validarUsuario(int idUsuario) {
        if (idUsuario <= 0) throw new IllegalArgumentException("Usuario invalido.");
    }
}
