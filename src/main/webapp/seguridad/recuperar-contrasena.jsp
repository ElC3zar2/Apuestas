<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"%>
<% response.setHeader("Cache-Control", "no-store"); %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="referrer" content="no-referrer">
    <title>Recuperar contraseña — BetZone</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/inicio-usuario.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/seguridad-usuario.css">
    <script>window.APP_CONTEXT_PATH = "${pageContext.request.contextPath}";</script>
    <script src="${pageContext.request.contextPath}/js/seguridad-usuario.js" defer></script>
</head>
<body>
    <a class="skip-link" href="#contenido">Ir al contenido</a>
    <main id="contenido" class="security-public">
        <section class="panel public-card" aria-labelledby="titulo-publico">
            <a class="brand" href="${pageContext.request.contextPath}/index.jsp"><span class="brand-dot" aria-hidden="true"></span>BetZone</a>
            <p class="eyebrow">SEGURIDAD DE TU ACCESO</p>
            <h1 id="titulo-publico">Recuperar contraseña.</h1>
            <p id="recuperar-ayuda" class="muted">Ingresa tu correo. La respuesta es neutral y no confirma si existe una cuenta asociada.</p>
            <form id="recuperar" class="security-form" data-security="recuperar" action="${pageContext.request.contextPath}/usuario/seguridad/recuperacion-contrasena/solicitar" method="POST" novalidate>
                <div class="security-field"><label for="recuperar-correo">Correo electrónico</label><input id="recuperar-correo" name="correo" type="email" autocomplete="email" maxlength="150" required aria-describedby="recuperar-ayuda"></div>
                <button class="button button-primary" type="submit">Solicitar recuperación</button>
                    <p id="recuperar-mensaje" class="security-message" role="status" aria-live="polite" hidden></p>
                    <a id="recuperar-login" class="security-login text-link" href="${pageContext.request.contextPath}/usuario/login" hidden>Ir a iniciar sesión</a>
            </form>
            <div class="public-links">
                <a href="${pageContext.request.contextPath}/seguridad/restablecer-contrasena.jsp">Ya tengo un código</a>
                <a href="${pageContext.request.contextPath}/usuario/login">Volver a iniciar sesión</a>
            </div>
            <noscript><p class="notice">Activa JavaScript para validar el formulario y ver la respuesta en esta pantalla.</p></noscript>
        </section>
    </main>
    <footer class="footer"><span>BetZone</span><span>Jugá con responsabilidad. +18.</span></footer>
</body>
</html>
