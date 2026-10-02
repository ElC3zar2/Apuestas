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

        String departamentoTexto = request.getParameter("idDepartamento");
        if (departamentoTexto == null || departamentoTexto.trim().isEmpty()) {
            response.getWriter().print("[]");
            return;
        }
        final int idDepartamento;
        try {
            idDepartamento = Integer.parseInt(departamentoTexto.trim());
            if (idDepartamento <= 0) throw new NumberFormatException();
        } catch (NumberFormatException e) {
            response.setStatus(400);
            response.getWriter().print("[]");
            return;
        }
        try {
            List<Municipio> municipios = ubicacionDAO.listarMunicipiosPorDepartamento(idDepartamento);
            StringBuilder json = new StringBuilder("[");
            for (int i = 0; i < municipios.size(); i++) {
                if (i > 0) json.append(",");
                Municipio municipio = municipios.get(i);
                json.append("{\"idMunicipio\":").append(municipio.getIdMunicipio())
                    .append(",\"nombre\":\"").append(escaparJson(municipio.getNombre())).append("\"}");
            }
            response.getWriter().print(json.append("]").toString());
        } catch (java.sql.SQLException | RuntimeException e) {
            response.setStatus(500);
            response.getWriter().print("[]");
        }
    }
    private String escaparJson(
            String texto) {

        if (texto == null) return "";
        StringBuilder escapado = new StringBuilder();

        for (int i = 0; i < texto.length(); i++) {
            char caracter = texto.charAt(i);

            switch (caracter) {
                case '\\':
                    escapado.append("\\\\");
                    break;
                case '"':
                    escapado.append("\\\"");
                    break;
                case '\n':
                    escapado.append("\\n");
                    break;
                case '\r':
                    escapado.append("\\r");
                    break;
                case '\t':
                    escapado.append("\\t");
                    break;
                default:
                    if (caracter < 0x20) {
                        escapado.append("\\u00");
                        escapado.append(Character.forDigit(caracter >> 4, 16));
                        escapado.append(Character.forDigit(caracter & 0xF, 16));
                    } else {
                        escapado.append(caracter);
                    }
            }
        }

        return escapado.toString();
    }
}
