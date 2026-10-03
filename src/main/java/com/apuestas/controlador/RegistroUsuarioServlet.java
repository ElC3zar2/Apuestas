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

        response.setContentType("text/html;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");
        request.setAttribute("fechaLimiteNacimiento", usuarioServicio.fechaLimiteNacimiento().toString());
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
            response.setStatus(e instanceof IllegalArgumentException
                    || e instanceof java.time.format.DateTimeParseException ? 400 : 500);

            response.setStatus(500);
            response.getWriter().print("No fue posible cargar el registro.");
        }
    }

    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        request.setCharacterEncoding("UTF-8");

        response.setContentType("text/html;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");
        request.setAttribute("fechaLimiteNacimiento", usuarioServicio.fechaLimiteNacimiento().toString());
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

            String paisTelefonoTexto =
                    request.getParameter("idPaisTelefono");

            String telefonoLocal =
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

            LocalDate fechaNacimiento = usuarioServicio.interpretarFechaNacimiento(fechaTexto);

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

            int idPaisTelefono = 0;

            if (paisTelefonoTexto != null
                    && !paisTelefonoTexto.trim().isEmpty()) {

                idPaisTelefono =
                        Integer.parseInt(
                                paisTelefonoTexto
                        );
            }

            if (idPaisTelefono <= 0) {

                throw new IllegalArgumentException(
                        "Debe seleccionar un código telefónico."
                );
            }


            if (telefonoLocal == null
                    || telefonoLocal.trim().isEmpty()) {

                throw new IllegalArgumentException(
                        "El número de teléfono es obligatorio."
                );
            }

            telefonoLocal =
                    telefonoLocal.trim();

            if (!telefonoLocal.matches("[0-9]+")) {

                throw new IllegalArgumentException(
                        "El teléfono debe contener únicamente números."
                );
            }


            String codigoTelefonico =
                    ubicacionDAO
                            .obtenerCodigoTelefonicoPorPais(
                                    idPaisTelefono
                            );

            if (codigoTelefonico == null
                    || codigoTelefonico.trim().isEmpty()) {

                throw new IllegalArgumentException(
                        "El código telefónico seleccionado no es válido."
                );
            }


            String telefono =
                    codigoTelefonico.trim()
                    + telefonoLocal;

            if (telefono.length() > 25) {

                throw new IllegalArgumentException(
                        "El teléfono completo supera la longitud permitida."
                );
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
            response.setStatus(e instanceof IllegalArgumentException
                    || e instanceof java.time.format.DateTimeParseException ? 400 : 500);

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

                response.setStatus(500);
                response.getWriter().print("No fue posible cargar el registro.");
                return;
            }

            request.setAttribute(
                    "error",
                    e instanceof UsuarioServicio.FechaNacimientoException ? e.getMessage()
                            : (e instanceof IllegalArgumentException || e instanceof java.time.format.DateTimeParseException)
                            ? "Los datos de registro no son validos."
                            : "No fue posible completar el registro."
            );

            request.getRequestDispatcher(
                    "/usuario/registro.jsp"
            ).forward(request, response);
        }
    }

}