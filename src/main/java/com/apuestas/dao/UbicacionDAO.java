/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import com.apuestas.modelo.Departamento;
import com.apuestas.modelo.Municipio;
import com.apuestas.modelo.Pais;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

import java.util.ArrayList;
import java.util.List;
/**
 *
 * @author farfa
 */
public class UbicacionDAO {

    public List<Pais> listarPaisesActivos() throws SQLException {

        List<Pais> paises = new ArrayList<>();

        String sql =
                "SELECT IdPais, CodigoISO2, Nombre "
                + "FROM dbo.Pais "
                + "WHERE Activo = 1 "
                + "ORDER BY Nombre";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps = conexion.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {

                Pais pais = new Pais();

                pais.setIdPais(rs.getInt("IdPais"));
                pais.setCodigoISO2(rs.getString("CodigoISO2"));
                pais.setNombre(rs.getString("Nombre"));

                paises.add(pais);
            }
        }

        return paises;
    }

    public List<Departamento> listarDepartamentosGuatemala()
            throws SQLException {

        List<Departamento> departamentos = new ArrayList<>();

        String sql =
                "SELECT "
                + "D.IdDepartamento, "
                + "D.IdPais, "
                + "D.Nombre "
                + "FROM dbo.Departamento D "
                + "INNER JOIN dbo.Pais P "
                + "ON P.IdPais = D.IdPais "
                + "WHERE P.CodigoISO2 = 'GT' "
                + "AND P.Activo = 1 "
                + "AND D.Activo = 1 "
                + "ORDER BY D.Nombre";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps = conexion.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {

                Departamento departamento = new Departamento();

                departamento.setIdDepartamento(
                        rs.getInt("IdDepartamento")
                );

                departamento.setIdPais(
                        rs.getInt("IdPais")
                );

                departamento.setNombre(
                        rs.getString("Nombre")
                );

                departamentos.add(departamento);
            }
        }

        return departamentos;
    }

    public List<Municipio> listarMunicipiosPorDepartamento(
            int idDepartamento)
            throws SQLException {

        List<Municipio> municipios = new ArrayList<>();

        String sql =
                "SELECT "
                + "IdMunicipio, "
                + "IdDepartamento, "
                + "Nombre "
                + "FROM dbo.Municipio "
                + "WHERE IdDepartamento = ? "
                + "AND Activo = 1 "
                + "ORDER BY Nombre";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps = conexion.prepareStatement(sql)) {

            ps.setInt(1, idDepartamento);

            try (ResultSet rs = ps.executeQuery()) {

                while (rs.next()) {

                    Municipio municipio = new Municipio();

                    municipio.setIdMunicipio(
                            rs.getInt("IdMunicipio")
                    );

                    municipio.setIdDepartamento(
                            rs.getInt("IdDepartamento")
                    );

                    municipio.setNombre(
                            rs.getString("Nombre")
                    );

                    municipios.add(municipio);
                }
            }
        }

        return municipios;
    }

    public boolean esGuatemala(int idPais)
            throws SQLException {

        String sql =
                "SELECT COUNT(*) "
                + "FROM dbo.Pais "
                + "WHERE IdPais = ? "
                + "AND CodigoISO2 = 'GT' "
                + "AND Activo = 1";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps = conexion.prepareStatement(sql)) {

            ps.setInt(1, idPais);

            try (ResultSet rs = ps.executeQuery()) {

                if (rs.next()) {
                    return rs.getInt(1) > 0;
                }
            }
        }

        return false;
    }
}
