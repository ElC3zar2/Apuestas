/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.controlador;
import com.apuestas.dao.UbicacionDAO;
import com.apuestas.modelo.Usuario;
import com.apuestas.servicio.UsuarioServicio;

import java.io.IOException;
import java.time.LocalDate;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
/**
 *
 * @author cesar
 */
@WebServlet("/registro")
public class RegistroUsuarioServlet extends HttpServlet {

    private UsuarioServicio usuarioServicio;
    private UbicacionDAO ubicacionDAO;

    @Override
    public void init() {

        usuarioServicio = new UsuarioServicio();
        ubicacionDAO = new UbicacionDAO();
    }

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        try {

            request.setAttribute(
                    "paises",
                    ubicacionDAO.listarPaisesActivos()
            );

            request.setAttribute(
                    "departamentos",
                    ubicacionDAO.listarDepartamentosGuatemala()
            );

            request.getRequestDispatcher(
                    "/usuario/registro.jsp"
            ).forward(request, response);

        } catch (Exception e) {

            throw new ServletException(
                    "No fue posible cargar los catálogos de ubicación.",
                    e
            );
        }
    }

    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        request.setCharacterEncoding("UTF-8");

        try {

            String nombre =
                    request.getParameter("nombre");

            String apellido =
                    request.getParameter("apellido");

            String correo =
                    request.getParameter("correo");

            String contrasena =
                    request.getParameter("contrasena");

            String fechaTexto =
                    request.getParameter("fechaNacimiento");

            String genero =
                    request.getParameter("genero");

            String telefono =
                    request.getParameter("telefono");

            String tipoDocumento =
                    request.getParameter("tipoDocumento");

            String numeroDocumento =
                    request.getParameter("numeroDocumento");

            String paisTexto =
                    request.getParameter("idPais");

            String municipioTexto =
                    request.getParameter("idMunicipio");

            String ciudadExterior =
                    request.getParameter("ciudadExterior");

            String direccion =
                    request.getParameter("direccion");

            LocalDate fechaNacimiento = null;

            if (fechaTexto != null
                    && !fechaTexto.trim().isEmpty()) {

                fechaNacimiento =
                        LocalDate.parse(fechaTexto);
            }

            int idPais = 0;

            if (paisTexto != null
                    && !paisTexto.trim().isEmpty()) {

                idPais =
                        Integer.parseInt(paisTexto);
            }

            boolean esGuatemala =
                    ubicacionDAO.esGuatemala(idPais);

            Integer idMunicipio = null;

            if (esGuatemala) {

                if (municipioTexto == null
                        || municipioTexto.trim().isEmpty()) {

                    throw new IllegalArgumentException(
                            "Debe seleccionar un municipio."
                    );
                }

                idMunicipio =
                        Integer.valueOf(municipioTexto);

                ciudadExterior = null;

            } else {

                idMunicipio = null;

                if (ciudadExterior == null
                        || ciudadExterior.trim().isEmpty()) {

                    throw new IllegalArgumentException(
                            "Debe indicar la ciudad o localidad exterior."
                    );
                }
            }

            Usuario usuario =
                    new Usuario(
                            nombre,
                            apellido,
                            correo,
                            contrasena,
                            fechaNacimiento,
                            genero,
                            telefono,
                            tipoDocumento,
                            numeroDocumento,
                            idPais,
                            idMunicipio,
                            ciudadExterior,
                            direccion
                    );

            int idUsuario =
                    usuarioServicio.registrarCliente(usuario);

            request.setAttribute(
                    "mensaje",
                    "Cuenta creada correctamente. Usuario #"
                    + idUsuario
            );

            request.getRequestDispatcher(
                    "/usuario/login.jsp"
            ).forward(request, response);

        } catch (Exception e) {

            try {

                request.setAttribute(
                        "paises",
                        ubicacionDAO.listarPaisesActivos()
                );

                request.setAttribute(
                        "departamentos",
                        ubicacionDAO.listarDepartamentosGuatemala()
                );

            } catch (Exception catalogoError) {

                throw new ServletException(
                        "No fue posible recargar los catálogos.",
                        catalogoError
                );
            }

            request.setAttribute(
                    "error",
                    e.getMessage()
            );

            request.getRequestDispatcher(
                    "/usuario/registro.jsp"
            ).forward(request, response);
        }
    }

}