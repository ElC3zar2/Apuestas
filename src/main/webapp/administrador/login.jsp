<%-- 
    Document   : login
    Created on : 22-ago-2026, 22:58:11
    Author     : cesar
--%>

<%@page contentType="text/html" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Acceso Administrativo</title>
</head>
<body>

    <h1>Acceso Administrativo</h1>

    <form method="POST">

        <label>Correo:</label>
        <input type="email" name="correo" required>

        <br><br>

        <label>Contraseña:</label>
        <input type="password" name="contrasena" required>

        <br><br>

        <button type="submit">
            Ingresar
        </button>

    </form>

    <br>

    <a href="../index.jsp">
        Regresar
    </a>

</body>
</html>