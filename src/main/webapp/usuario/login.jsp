<%-- 
    Document   : login
    Created on : 22-ago-2026, 22:56:08
    Author     : cesar
--%>

<%@page contentType="text/html" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Inicio de Sesión</title>
</head>
<body>

    <h1>Inicio de Sesión</h1>

    <% if (request.getAttribute("mensaje") != null) { %>
        <p style="color: green;">
            <%= request.getAttribute("mensaje") %>
        </p>
    <% } %>

    <% if (request.getAttribute("error") != null) { %>
        <p style="color: red;">
            <%= request.getAttribute("error") %>
        </p>
    <% } %>

    <form method="POST">

        <label>Correo:</label>
        <input type="email" name="correo" required>

        <br><br>

        <label>Contraseña:</label>
        <input type="password" name="contrasena" required>

        <br><br>

        <button type="submit">
            Iniciar sesión
        </button>

    </form>

    <br>

    <a href="registro.jsp">
        Crear una cuenta
    </a>

    <br><br>

    <a href="../index.jsp">
        Regresar
    </a>

</body>
</html>