<%-- 
    Document   : registro
    Created on : 22-ago-2026, 22:57:41
    Author     : Otto
--%>

<%@page import="com.apuestas.modelo.Pais"%>
<%@page import="com.apuestas.modelo.Departamento"%>
<%@page import="java.util.List"%>
<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Crear cuenta — BetZone</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/registro.css">
</head>
<body>

    <main class="auth-page">
        <div class="auth-page__backdrop" aria-hidden="true"></div>
        <div class="auth-page__overlay" aria-hidden="true"></div>

        <div class="auth-card auth-card--registro">
            <div class="auth-card__brand">
                <span class="dot"></span> BetZone
            </div>
            <h1>Creá tu cuenta</h1>
            <p class="auth-card__sub">Completá tus datos para empezar a apostar con las mejores cuotas.</p>

            <%-- Error enviado por el Servlet tras el submit --%>
            <% if (request.getAttribute("error") != null) { %>
            <div class="form-alert form-alert--error is-visible" role="alert">
                <%= request.getAttribute("error") %>
            </div>
            <% } %>

            <form class="auth-form" action="${pageContext.request.contextPath}/registro" method="POST">
                <div class="form-grid">

                    <p class="form-section__title">Datos personales</p>

                    <div class="field">
                        <input type="text" id="nombre" name="nombre" class="field__input" placeholder=" " maxlength="100" required>
                        <label for="nombre" class="field__label">Nombre</label>
                    </div>

                    <div class="field">
                        <input type="text" id="apellido" name="apellido" class="field__input" placeholder=" " maxlength="100" required>
                        <label for="apellido" class="field__label">Apellido</label>
                    </div>

                    <div class="field">
                        <input type="email" id="correo" name="correo" class="field__input" placeholder=" " maxlength="150" required>
                        <label for="correo" class="field__label">Correo</label>
                    </div>

                    <div class="field">
                        <input type="password" id="contrasena" name="contrasena" class="field__input" placeholder=" " minlength="8" required>
                        <label for="contrasena" class="field__label">Contraseña</label>
                        <button type="button" class="field__toggle" data-target="contrasena" aria-label="Mostrar contraseña">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                                <path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"/>
                                <circle cx="12" cy="12" r="3"/>
                            </svg>
                        </button>
                    </div>

                    <div class="field field--static">
                        <label for="fechaNacimiento">Fecha de nacimiento</label>
                        <input type="date" id="fechaNacimiento" name="fechaNacimiento" class="field__input" required>
                    </div>

                    <div class="field field--static">
                        <label for="genero">Género</label>
                        <select id="genero" name="genero" class="field__select" required>
                            <option value="">Seleccione</option>
                            <option value="M">Masculino</option>
                            <option value="F">Femenino</option>
                        </select>
                    </div>

                    <p class="form-section__title">Contacto</p>

                    <div class="field--full field-phone">
                        <div class="field field--static">
                            <label for="idPaisTelefono">Código de área</label>
                            <select id="idPaisTelefono" name="idPaisTelefono" class="field__select" required>
                                <option value="">Código de área</option>
                                <%
                                    List<Pais> paisesTelefono = (List<Pais>) request.getAttribute("paises");

                                    if (paisesTelefono != null) {
                                        for (Pais pais : paisesTelefono) {
                                            if (pais.getCodigoTelefonico() == null
                                                    || pais.getCodigoTelefonico().trim().isEmpty()) {
                                                continue;
                                            }
                                %>
                                <option value="<%= pais.getIdPais() %>"
                                        <%= "GT".equals(pais.getCodigoISO2()) ? "selected" : "" %>>
                                    <%= pais.getNombre() %> (<%= pais.getCodigoTelefonico() %>)
                                </option>
                                <%
                                        }
                                    }
                                %>
                            </select>
                        </div>

                        <div class="field">
                            <input type="tel" id="telefono" name="telefono" class="field__input" placeholder=" "
                                   maxlength="15" pattern="[0-9]+" inputmode="numeric"
                                   title="Ingrese únicamente los números del teléfono, sin código de país." required>
                            <label for="telefono" class="field__label">Teléfono</label>
                        </div>
                    </div>

                    <p class="form-section__title">Documento de identidad</p>

                    <div class="field field--static">
                        <label for="tipoDocumento">Tipo de documento</label>
                        <select id="tipoDocumento" name="tipoDocumento" class="field__select"
                                onchange="cambiarTipoDocumento()" required>
                            <option value="">Seleccione</option>
                            <option value="DPI">DPI</option>
                            <option value="PASAPORTE">Pasaporte</option>
                            <option value="OTRO">Otro</option>
                        </select>
                    </div>

                    <div class="field">
                        <input type="text" id="numeroDocumento" name="numeroDocumento" class="field__input"
                               placeholder=" " maxlength="50" required>
                        <label for="numeroDocumento" class="field__label">Número de documento</label>
                        <span id="ayudaDocumento" class="field__hint"></span>
                    </div>

                    <p class="form-section__title">Ubicación</p>

                    <div class="field field--static field--full">
                        <label for="idPais">País</label>
                        <select id="idPais" name="idPais" class="field__select" onchange="cambiarPais()" required>
                            <option value="">Seleccione un país</option>
                            <%
                                List<Pais> paises = (List<Pais>) request.getAttribute("paises");

                                if (paises != null) {
                                    for (Pais pais : paises) {
                            %>
                            <option value="<%= pais.getIdPais() %>" data-codigo="<%= pais.getCodigoISO2() %>">
                                <%= pais.getNombre() %>
                            </option>
                            <%
                                    }
                                }
                            %>
                        </select>
                    </div>

                    <!-- UBICACIÓN GUATEMALA -->
                    <div id="bloqueGuatemala" class="field-conditional" style="display:none;">
                        <div class="field field--static">
                            <label for="idDepartamento">Departamento</label>
                            <select id="idDepartamento" class="field__select" onchange="cargarMunicipios()" disabled>
                                <option value="">Seleccione un departamento</option>
                                <%
                                    List<Departamento> departamentos = (List<Departamento>) request.getAttribute("departamentos");

                                    if (departamentos != null) {
                                        for (Departamento departamento : departamentos) {
                                %>
                                <option value="<%= departamento.getIdDepartamento() %>">
                                    <%= departamento.getNombre() %>
                                </option>
                                <%
                                        }
                                    }
                                %>
                            </select>
                        </div>

                        <div class="field field--static">
                            <label for="idMunicipio">Municipio</label>
                            <select id="idMunicipio" name="idMunicipio" class="field__select" disabled>
                                <option value="">Seleccione primero un departamento</option>
                            </select>
                        </div>
                    </div>

                    <!-- UBICACIÓN EXTRANJERO -->
                    <div id="bloqueExterior" class="field--full" style="display:none;">
                        <div class="field">
                            <input type="text" id="ciudadExterior" name="ciudadExterior" class="field__input"
                                   placeholder=" " maxlength="120" disabled>
                            <label for="ciudadExterior" class="field__label">Ciudad exterior</label>
                        </div>
                    </div>

                    <div class="field field--full">
                        <input type="text" id="direccion" name="direccion" class="field__input" placeholder=" " maxlength="250" required>
                        <label for="direccion" class="field__label">Dirección</label>
                    </div>

                </div>

                <button type="submit" class="btn btn--submit">Crear cuenta</button>
            </form>

            <p class="auth-card__footer">
                ¿Ya tenés cuenta? <a href="${pageContext.request.contextPath}/usuario/login">Iniciá sesión</a>
            </p>
        </div>
    </main>

    <script>
        // El JS externo no puede evaluar EL ({pageContext...}); se lo pasamos así.
        window.APP_CONTEXT_PATH = "${pageContext.request.contextPath}";
    </script>
    <script src="${pageContext.request.contextPath}/js/registro.js"></script>
</body>
</html>