/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.controlador;
import com.apuestas.dao.UbicacionDAO;
import com.apuestas.modelo.Municipio;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.List;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
/**
 *
 * @author farfa
 */
@WebServlet("/municipios")
public class MunicipioServlet extends HttpServlet {

    private UbicacionDAO ubicacionDAO;

    @Override
    public void init() {

        ubicacionDAO = new UbicacionDAO();
    }

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType(
                "application/json;charset=UTF-8"
        );

        String departamentoTexto =
                request.getParameter("idDepartamento");

        try (PrintWriter out = response.getWriter()) {

            if (departamentoTexto == null
                    || departamentoTexto.trim().isEmpty()) {

                out.print("[]");
                return;
            }

            int idDepartamento =
                    Integer.parseInt(departamentoTexto);

            List<Municipio> municipios =
                    ubicacionDAO
                            .listarMunicipiosPorDepartamento(
                                    idDepartamento
                            );

            StringBuilder json =
                    new StringBuilder("[");

            for (int i = 0;
                 i < municipios.size();
                 i++) {

                Municipio municipio =
                        municipios.get(i);

                if (i > 0) {
                    json.append(",");
                }

                json.append("{")
                    .append("\"idMunicipio\":")
                    .append(municipio.getIdMunicipio())
                    .append(",")
                    .append("\"nombre\":\"")
                    .append(escaparJson(
                            municipio.getNombre()
                    ))
                    .append("\"")
                    .append("}");
            }

            json.append("]");

            out.print(json.toString());

        } catch (Exception e) {

            response.setStatus(
                    HttpServletResponse
                            .SC_INTERNAL_SERVER_ERROR
            );
        }
    }

    private String escaparJson(String texto) {

        if (texto == null) {
            return "";
        }

        return texto
                .replace("\\", "\\\\")
                .replace("\"", "\\\"");
    }
}