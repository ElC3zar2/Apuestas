<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"%>
<% response.setHeader("Cache-Control", "no-store"); %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="referrer" content="no-referrer">
    <title>Restablecer contraseña — BetZone</title>
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
            <h1 id="titulo-publico">Restablecer contraseña.</h1>
            <p id="restablecer-ayuda" class="muted">Pega el código recibido por correo. La nueva contraseña debe tener al menos 8 caracteres, un máximo de 72 bytes UTF-8 y coincidir con su confirmación.</p>
            <form id="restablecer" class="security-form" data-security="restablecer" action="${pageContext.request.contextPath}/usuario/seguridad/recuperacion-contrasena/restablecer" method="POST" novalidate>
                    <div class="security-field">
                        <label for="restablecer-token">Código de recuperación</label>
                        <div class="security-input">
                            <input id="restablecer-token" name="token" type="password" autocomplete="off" autocapitalize="none" spellcheck="false" data-sensitive="token" required aria-describedby="restablecer-ayuda">
                            <button type="button" class="reveal" data-reveal="restablecer-token" aria-controls="restablecer-token" aria-pressed="false" aria-label="Mostrar código de recuperación">Mostrar</button>
                        </div>
                    </div>
                    <div class="security-field">
                        <label for="restablecer-nuevaContrasena">Nueva contraseña</label>
                        <div class="security-input">
                            <input id="restablecer-nuevaContrasena" name="nuevaContrasena" type="password" autocomplete="new-password" data-sensitive="password" required aria-describedby="restablecer-ayuda">
                            <button type="button" class="reveal" data-reveal="restablecer-nuevaContrasena" aria-controls="restablecer-nuevaContrasena" aria-pressed="false" aria-label="Mostrar nueva contraseña">Mostrar</button>
                        </div>
                    </div>
                    <div class="security-field">
                        <label for="restablecer-confirmarContrasena">Confirmar nueva contraseña</label>
                        <div class="security-input">
                            <input id="restablecer-confirmarContrasena" name="confirmarContrasena" type="password" autocomplete="new-password" data-sensitive="password" required aria-describedby="restablecer-ayuda">
                            <button type="button" class="reveal" data-reveal="restablecer-confirmarContrasena" aria-controls="restablecer-confirmarContrasena" aria-pressed="false" aria-label="Mostrar confirmar nueva contraseña">Mostrar</button>
                        </div>
                    </div>
                <button class="button button-primary" type="submit">Restablecer contraseña</button>
                    <p id="restablecer-mensaje" class="security-message" role="status" aria-live="polite" hidden></p>
                    <a id="restablecer-login" class="security-login text-link" href="${pageContext.request.contextPath}/usuario/login" hidden>Ir a iniciar sesión</a>
            </form>
            <div class="public-links">
                <a href="${pageContext.request.contextPath}/seguridad/recuperar-contrasena.jsp">Solicitar otro código</a>
                <a href="${pageContext.request.contextPath}/usuario/login">Volver a iniciar sesión</a>
            </div>
            <noscript><p class="notice">Activa JavaScript para validar el formulario y ver la respuesta en esta pantalla.</p></noscript>
        </section>
    </main>
    <footer class="footer"><span>BetZone</span><span>Jugá con responsabilidad. +18.</span></footer>
</body>
</html>
