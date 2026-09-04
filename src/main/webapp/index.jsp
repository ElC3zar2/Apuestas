<%-- 
    Document   : index
    Created on : 22-ago-2026, 22:53:53
    Author     : cesar
--%>

<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>

<!DOCTYPE html>
<html>

<head>
    <meta charset="UTF-8">
    <title>Plataforma de Apuestas</title>
</head>

<body>

    <h1>Plataforma de Apuestas Deportivas</h1>

    <h2>Bienvenido</h2>

    <p>Seleccione una opción:</p>

    <a href="${pageContext.request.contextPath}/usuario/login.jsp">
        Iniciar sesión como usuario
    </a>

    <br><br>

    <a href="${pageContext.request.contextPath}/registro">
        Crear cuenta
    </a>

    <br><br>

    <a href="${pageContext.request.contextPath}/administrador/login.jsp">
        Acceso administrativo
    </a>

</body>

</html>