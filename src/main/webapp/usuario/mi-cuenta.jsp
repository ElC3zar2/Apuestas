<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<% response.setHeader("Cache-Control", "no-store"); %>
<%!
    private String textoSeguro(Object valor) {
        if (valor == null) return "No disponible";
        return valor.toString().replace("&", "&amp;").replace("<", "&lt;")
                .replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="referrer" content="no-referrer">
    <title>Mi cuenta — BetZone</title>
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
    <header class="topbar">
        <a class="brand" href="${pageContext.request.contextPath}/usuario/inicio.jsp"><span class="brand-dot" aria-hidden="true"></span>BetZone</a>
        <nav class="navigation" aria-label="Navegación principal">
            <a href="${pageContext.request.contextPath}/usuario/inicio.jsp">Inicio</a>
            <a href="${pageContext.request.contextPath}/eventos/listar-eventos.jsp">Eventos</a>
            <a href="${pageContext.request.contextPath}/apuestas/mis-boletos.jsp">Mis apuestas</a>
            <a href="${pageContext.request.contextPath}/billetera/mi-billetera.jsp">Billetera</a>
            <a href="${pageContext.request.contextPath}/usuario/mi-cuenta.jsp" aria-current="page">Mi cuenta</a>
        </nav>
        <form action="${pageContext.request.contextPath}/usuario/logout" method="POST"><button class="logout" type="submit">Cerrar sesión <span aria-hidden="true">↗</span></button></form>
    </header>
    <main id="contenido" class="dashboard security-page">
        <section class="welcome"><div><p class="eyebrow">TU CUENTA BETZONE</p><h1>Mi cuenta.</h1><p class="muted">Consulta los datos de tu sesión y administra tu seguridad.</p></div></section>
        <section class="panel session-info" aria-labelledby="titulo-sesion">
            <p class="eyebrow">DATOS AL INICIAR SESIÓN</p><h2 id="titulo-sesion">Información de tu cuenta</h2>
            <dl class="session-facts">
                <div><dt>Correo</dt><dd><%= textoSeguro(session.getAttribute("correo")) %></dd></div>
                <div><dt>Estado del usuario</dt><dd><%= textoSeguro(session.getAttribute("estadoUsuario")) %></dd></div>
                <div><dt>Rol</dt><dd><%= textoSeguro(session.getAttribute("rol")) %></dd></div>
                <div><dt>Correo verificado al iniciar sesión</dt><dd><%= Boolean.TRUE.equals(session.getAttribute("correoVerificado")) ? "Sí" : Boolean.FALSE.equals(session.getAttribute("correoVerificado")) ? "No" : "No disponible" %></dd></div>
            </dl>
            <% if (Boolean.FALSE.equals(session.getAttribute("correoVerificado"))) { %>
            <p class="notice">Según los datos de esta sesión, tu correo todavía necesita verificación.</p>
            <% } %>
            <p class="muted security-note">Estos datos corresponden al inicio de sesión. La verificación del correo por sí sola no indica si puedes apostar.</p>
        </section>
        <div class="security-grid">
            <section class="panel" aria-labelledby="titulo-clave">
                <p class="eyebrow">PROTEGE TU ACCESO</p><h2 id="titulo-clave">Cambiar contraseña</h2>
                <p id="cambio-ayuda" class="muted">La nueva contraseña debe tener al menos 8 caracteres y como máximo 72 bytes UTF-8. Ambas contraseñas nuevas deben coincidir.</p>
                <form id="cambio" class="security-form" data-security="cambio" action="${pageContext.request.contextPath}/usuario/seguridad/cambiar-contrasena" method="POST" novalidate>
                    <div class="security-field">
                        <label for="cambio-contrasenaActual">Contraseña actual</label>
                        <div class="security-input">
                            <input id="cambio-contrasenaActual" name="contrasenaActual" type="password" autocomplete="current-password" data-sensitive="password" required aria-describedby="cambio-ayuda">
                            <button type="button" class="reveal" data-reveal="cambio-contrasenaActual" aria-controls="cambio-contrasenaActual" aria-pressed="false" aria-label="Mostrar contraseña actual">Mostrar</button>
                        </div>
                    </div>
                    <div class="security-field">
                        <label for="cambio-nuevaContrasena">Nueva contraseña</label>
                        <div class="security-input">
                            <input id="cambio-nuevaContrasena" name="nuevaContrasena" type="password" autocomplete="new-password" data-sensitive="password" required aria-describedby="cambio-ayuda">
                            <button type="button" class="reveal" data-reveal="cambio-nuevaContrasena" aria-controls="cambio-nuevaContrasena" aria-pressed="false" aria-label="Mostrar nueva contraseña">Mostrar</button>
                        </div>
                    </div>
                    <div class="security-field">
                        <label for="cambio-confirmarContrasena">Confirmar nueva contraseña</label>
                        <div class="security-input">
                            <input id="cambio-confirmarContrasena" name="confirmarContrasena" type="password" autocomplete="new-password" data-sensitive="password" required aria-describedby="cambio-ayuda">
                            <button type="button" class="reveal" data-reveal="cambio-confirmarContrasena" aria-controls="cambio-confirmarContrasena" aria-pressed="false" aria-label="Mostrar confirmar nueva contraseña">Mostrar</button>
                        </div>
                    </div>
                    <button class="button button-primary" type="submit">Actualizar contraseña</button>
                    <p id="cambio-mensaje" class="security-message" role="status" aria-live="polite" hidden></p>
                    <a id="cambio-login" class="security-login text-link" href="${pageContext.request.contextPath}/usuario/login" hidden>Ir a iniciar sesión</a>
                </form>
            </section>
            <section class="panel" aria-labelledby="titulo-correo">
                <p class="eyebrow">VERIFICACIÓN DE CORREO</p><h2 id="titulo-correo">Confirmar tu correo</h2>
                <p class="muted">El servidor envía un código por correo cuando corresponde. Pégalo completo para confirmar; no necesitas abrir un enlace de verificación.</p>
                <form id="verificar-solicitud" class="security-form" data-security="verificar-solicitud" action="${pageContext.request.contextPath}/usuario/seguridad/verificacion-correo/solicitar" method="POST" novalidate>
                    <button class="button button-secondary" type="submit">Solicitar código de verificación</button>
                    <p id="verificar-solicitud-mensaje" class="security-message" role="status" aria-live="polite" hidden></p>
                    <a id="verificar-solicitud-login" class="security-login text-link" href="${pageContext.request.contextPath}/usuario/login" hidden>Ir a iniciar sesión</a>
                </form>
                <form id="verificar-confirmacion" class="security-form code-form" data-security="verificar-confirmacion" action="${pageContext.request.contextPath}/usuario/seguridad/verificacion-correo/confirmar" method="POST" novalidate>
                    <p id="verificar-confirmacion-ayuda" class="muted">Ingresa el código de 43 caracteres recibido por correo. Este formulario confirma el código proporcionado; el estado de esta sesión permanece como al iniciar sesión.</p>
                    <div class="security-field">
                        <label for="verificar-confirmacion-token">Código de verificación</label>
                        <div class="security-input">
                            <input id="verificar-confirmacion-token" name="token" type="password" autocomplete="off" autocapitalize="none" spellcheck="false" data-sensitive="token" required aria-describedby="verificar-confirmacion-ayuda">
                            <button type="button" class="reveal" data-reveal="verificar-confirmacion-token" aria-controls="verificar-confirmacion-token" aria-pressed="false" aria-label="Mostrar código de verificación">Mostrar</button>
                        </div>
                    </div>
                    <button class="button button-primary" type="submit">Confirmar código</button>
                    <p id="verificar-confirmacion-mensaje" class="security-message" role="status" aria-live="polite" hidden></p>
                    <a id="verificar-confirmacion-login" class="security-login text-link" href="${pageContext.request.contextPath}/usuario/login" hidden>Ir a iniciar sesión</a>
                </form>
            </section>
        </div>
        <noscript><p class="notice">Activa JavaScript para validar los formularios y ver las respuestas dentro de esta pantalla.</p></noscript>
    </main>
    <footer class="footer"><span>BetZone</span><span>Jugá con responsabilidad. +18.</span></footer>
</body>
</html>
