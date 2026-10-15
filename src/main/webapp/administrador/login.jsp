<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"%>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Acceso administrativo — BetZone</title>
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/admin.css">
<script src="${pageContext.request.contextPath}/js/admin.js" defer></script>
</head>
<body class="login-page" data-context-path="${pageContext.request.contextPath}">
<main class="login-card">
<a class="brand" href="${pageContext.request.contextPath}/">BetZone <span>ADMIN</span></a>
<p class="eyebrow">CENTRO DE OPERACIONES</p><h1>Acceso administrativo</h1>
<p class="muted">Ingresa con tu cuenta de personal autorizado.</p>
<form id="admin-login" action="${pageContext.request.contextPath}/administrador/login" method="post">
<label for="correo">Correo electrónico</label><input id="correo" name="correo" type="email" autocomplete="username" required maxlength="254">
<label for="contrasena">Contraseña</label><input id="contrasena" name="contrasena" type="password" autocomplete="current-password" required>
<button class="primary" type="submit">Ingresar al panel</button>
<p id="login-status" role="status" aria-live="polite"></p>
</form>
<a class="muted" href="${pageContext.request.contextPath}/">← Volver a BetZone</a>
</main>
</body></html>
