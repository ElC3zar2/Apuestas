<%-- 
    Document   : login
    Created on : 22-ago-2026, 22:56:08
    Author     : cesar
--%>

<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>

<!DOCTYPE html>
<html>

<head>
    <meta charset="UTF-8">
    <title>Iniciar sesión</title>
</head>

<body>

    <h1>Iniciar sesión</h1>

    <%
        if (request.getAttribute("mensaje") != null) {
    %>

    <p style="color:green;">
        <%= request.getAttribute("mensaje") %>
    </p>

    <%
        }
    %>

    <%
        if (request.getAttribute("error") != null) {
    %>

    <p style="color:red;">
        <%= request.getAttribute("error") %>
    </p>

    <%
        }
    %>

    <form method="POST"
          action="${pageContext.request.contextPath}/login">

        <label>Correo:</label>

        <input
            type="email"
            name="correo"
            required>

        <br><br>

        <label>Contraseña:</label>

        <input
            type="password"
            name="contrasena"
            required>

        <br><br>

        <button type="submit">
            Iniciar sesión
        </button>

    </form>

    <br>

    <a href="${pageContext.request.contextPath}/registro">
        Crear una cuenta
    </a>

    <br><br>

    <a href="${pageContext.request.contextPath}/">
        Volver al inicio
    </a>

</body>

</html>