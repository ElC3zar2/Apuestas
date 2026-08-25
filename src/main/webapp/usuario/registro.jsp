<%-- 
    Document   : registro
    Created on : 22-ago-2026, 22:57:41
    Author     : cesar
--%>

<%@page contentType="text/html" pageEncoding="UTF-8"%>
<html>
<head>
    <meta charset="UTF-8">
    <title>Crear cuenta</title>
</head>

<body>

    <h1>Crear cuenta</h1>

    <% if (request.getAttribute("error") != null) { %>

        <p style="color:red;">
            <%= request.getAttribute("error") %>
        </p>

    <% } %>

    <form action="${pageContext.request.contextPath}/registro"
          method="POST">

        <label>Nombre:</label>
        <input type="text"
               name="nombre"
               required>

        <br><br>

        <label>Apellido:</label>
        <input type="text"
               name="apellido"
               required>

        <br><br>

        <label>Correo:</label>
        <input type="email"
               name="correo"
               required>

        <br><br>

        <label>Contraseña:</label>
        <input type="password"
               name="contrasena"
               minlength="8"
               required>

        <br><br>

        <label>Fecha de nacimiento:</label>
        <input type="date"
               name="fechaNacimiento">

        <br><br>

        <button type="submit">
            Crear cuenta
        </button>

    </form>

</body>
</html>