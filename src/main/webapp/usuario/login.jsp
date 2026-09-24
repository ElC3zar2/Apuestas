<%-- 
    Document   : login
    Created on : 22-ago-2026, 22:56:08
    Author     : Otto
--%>

<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Iniciar sesión — BetZone</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/login.css">
</head>
<body>

    <main class="auth-page">
        <div class="auth-page__backdrop" aria-hidden="true"></div>
        <div class="auth-page__overlay" aria-hidden="true"></div>

        <div class="auth-card">
            <div class="auth-card__brand">
                <span class="dot"></span> BetZone
            </div>
            <h1>Bienvenido de nuevo</h1>
            <p class="auth-card__sub">Iniciá sesión para ver tus cuotas y apuestas activas.</p>

            <%-- Mensaje enviado por el Servlet tras el submit (éxito) --%>
            <% if (request.getAttribute("mensaje") != null) { %>
            <div class="form-alert form-alert--success is-visible" role="alert">
                <%= request.getAttribute("mensaje") %>
            </div>
            <% } %>

            <%-- Error enviado por el Servlet tras el submit (credenciales, etc.) --%>
            <% if (request.getAttribute("error") != null) { %>
            <div class="form-alert form-alert--error is-visible" role="alert">
                <%= request.getAttribute("error") %>
            </div>
            <% } %>

            <%-- Alerta reservada para la validación en el cliente (login.js) --%>
            <div id="login-alert" class="form-alert" role="alert"></div>

            <form id="form-login" class="auth-form" method="POST"
                  action="${pageContext.request.contextPath}/usuario/login" novalidate>

                <div class="field">
                    <input
                        type="email"
                        id="login-email"
                        name="correo"
                        class="field__input"
                        placeholder=" "
                        autocomplete="email"
                        required>
                    <label for="login-email" class="field__label">Correo electrónico</label>
                    <span id="login-email-error" class="field__error"></span>
                </div>

                <div class="field">
                    <input
                        type="password"
                        id="login-password"
                        name="contrasena"
                        class="field__input"
                        placeholder=" "
                        autocomplete="current-password"
                        required>
                    <label for="login-password" class="field__label">Contraseña</label>
                    <button type="button" class="field__toggle" data-target="login-password" aria-label="Mostrar contraseña">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                            <path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"/>
                            <circle cx="12" cy="12" r="3"/>
                        </svg>
                    </button>
                    <span id="login-password-error" class="field__error"></span>
                </div>

                <button type="submit" class="btn btn--submit">Iniciar sesión</button>
            </form>

            <p class="auth-card__footer">
                ¿No tenés cuenta? <a href="${pageContext.request.contextPath}/usuario/registro.jsp">Crear una cuenta</a>
            </p>
            <p class="auth-card__footer">
                <a href="${pageContext.request.contextPath}/index.jsp">Volver al inicio</a>
            </p>
        </div>
    </main>

    <script src="${pageContext.request.contextPath}/js/login.js"></script>
</body>
</html>