/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.controlador;
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

    @Override
    public void init() {
        usuarioServicio = new UsuarioServicio();
    }

    @Override
    protected void doPost(HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {

        request.setCharacterEncoding("UTF-8");

        try {

            String nombre = request.getParameter("nombre");
            String apellido = request.getParameter("apellido");
            String correo = request.getParameter("correo");
            String contrasena = request.getParameter("contrasena");
            String fechaTexto = request.getParameter("fechaNacimiento");

            LocalDate fechaNacimiento = null;

            if (fechaTexto != null && !fechaTexto.trim().isEmpty()) {
                fechaNacimiento = LocalDate.parse(fechaTexto);
            }

            Usuario usuario = new Usuario(
                    nombre,
                    apellido,
                    correo,
                    contrasena,
                    fechaNacimiento
            );

            int idUsuario =
                    usuarioServicio.registrarCliente(usuario);

            request.setAttribute(
                    "mensaje",
                    "Cuenta creada correctamente. Usuario #" + idUsuario
            );

            request.getRequestDispatcher("/usuario/login.jsp")
                    .forward(request, response);

        } catch (Exception e) {

            request.setAttribute(
                    "error",
                    e.getMessage()
            );

            request.getRequestDispatcher("/usuario/registro.jsp")
                    .forward(request, response);
        }
    }
}