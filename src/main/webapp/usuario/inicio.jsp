<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
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
    <title>Inicio — BetZone</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/inicio-usuario.css">
    <script src="${pageContext.request.contextPath}/js/inicio-usuario.js" defer></script>
</head>
<body>
    <a class="skip-link" href="#contenido">Ir al contenido</a>
    <header class="topbar">
        <a class="brand" href="${pageContext.request.contextPath}/usuario/inicio.jsp"><span class="brand-dot" aria-hidden="true"></span>BetZone</a>
        <nav class="navigation" aria-label="Navegación principal">
            <a href="${pageContext.request.contextPath}/usuario/inicio.jsp" aria-current="page">Inicio</a>
            <a href="${pageContext.request.contextPath}/eventos/listar-eventos.jsp">Eventos</a>
            <a href="${pageContext.request.contextPath}/apuestas/mis-boletos.jsp">Mis apuestas</a>
            <a href="${pageContext.request.contextPath}/billetera/mi-billetera.jsp">Billetera</a>
            <a href="#mi-cuenta">Mi cuenta</a>
        </nav>
        <form action="${pageContext.request.contextPath}/usuario/logout" method="POST"><button class="logout" type="submit">Cerrar sesión <span aria-hidden="true">↗</span></button></form>
    </header>
    <main id="contenido" class="dashboard" data-context-path="${pageContext.request.contextPath}">
        <section class="welcome" aria-labelledby="bienvenida">
            <div><p class="eyebrow">TU ESPACIO BETZONE</p><h1 id="bienvenida">Bienvenido a tu inicio.</h1>
                <p class="welcome-email"><%= textoSeguro(session.getAttribute("correo")) %></p>
                <p class="muted">Tu saldo, tus apuestas y tu cuenta, en un solo lugar.</p></div>
            <a class="button button-primary" href="${pageContext.request.contextPath}/eventos/listar-eventos.jsp">Explorar eventos <span aria-hidden="true">↗</span></a>
        </section>
        <section class="panel wallet" id="resumen-billetera" aria-labelledby="titulo-billetera" aria-busy="true">
            <div class="section-heading"><div><p class="eyebrow">TUS SALDOS</p><h2 id="titulo-billetera">Resumen de billetera</h2></div><a class="text-link" href="${pageContext.request.contextPath}/billetera/mi-billetera.jsp">Ver billetera ↗</a></div>
            <p class="data-status muted" role="status">Cargando saldos…</p>
            <dl class="wallet-grid is-loading">
                <div class="balance balance-primary"><dt>Saldo disponible</dt><dd data-field="saldoDisponible">—</dd><dd class="balance-note">Saldo disponible en tu billetera.</dd></div>
                <div class="balance"><dt>Saldo comprometido</dt><dd data-field="saldoComprometido">—</dd><dd class="balance-note">Saldo comprometido en apuestas.</dd></div>
                <div class="balance"><dt>Saldo virtual total</dt><dd data-field="saldoVirtualTotal">—</dd><dd class="balance-note">Total informado por tu billetera.</dd></div>
            </dl>
            <button class="retry" type="button" hidden>Volver a intentar</button>
        </section>
        <section class="panel activity" id="resumen-actividad" aria-labelledby="titulo-actividad" aria-busy="true">
            <div class="section-heading"><div><p class="eyebrow">TU RECORRIDO</p><h2 id="titulo-actividad">Resumen de actividad</h2></div><a class="text-link" href="${pageContext.request.contextPath}/apuestas/mis-boletos.jsp">Ver mis apuestas ↗</a></div>
            <p class="data-status muted" role="status">Cargando actividad…</p>
            <dl class="activity-grid is-loading">
                <div class="metric"><dt>Boletos totales</dt><dd data-field="cantidadBoletos">—</dd></div>
                <div class="metric"><dt>Pendientes</dt><dd data-field="boletosPendientes">—</dd></div>
                <div class="metric"><dt>Ganadores</dt><dd data-field="boletosGanadores">—</dd></div>
                <div class="metric"><dt>Perdedores</dt><dd data-field="boletosPerdedores">—</dd></div>
                <div class="metric"><dt>Anulados</dt><dd data-field="boletosAnulados">—</dd></div>
            </dl>
            <button class="retry" type="button" hidden>Volver a intentar</button>
        </section>
        <div class="bottom-grid">
            <section class="panel" aria-labelledby="titulo-accesos">
                <p class="eyebrow">SIGUIENTE PASO</p><h2 id="titulo-accesos">Acciones rápidas</h2>
                <div class="quick-actions">
                    <a href="${pageContext.request.contextPath}/eventos/listar-eventos.jsp"><span><strong>Ver eventos</strong><small>Explora el catálogo de eventos.</small></span><span aria-hidden="true">↗</span></a>
                    <a href="${pageContext.request.contextPath}/apuestas/mis-boletos.jsp"><span><strong>Mis apuestas</strong><small>Accede a tus boletos.</small></span><span aria-hidden="true">↗</span></a>
                    <a href="${pageContext.request.contextPath}/billetera/mi-billetera.jsp"><span><strong>Mi billetera</strong><small>Accede al espacio de tu billetera.</small></span><span aria-hidden="true">↗</span></a>
                </div>
            </section>
            <section class="panel account" id="mi-cuenta" aria-labelledby="titulo-cuenta">
                <p class="eyebrow">MI CUENTA</p><h2 id="titulo-cuenta">Estado de la cuenta</h2>
                <dl class="account-details">
                    <div><dt>Correo</dt><dd><%= textoSeguro(session.getAttribute("correo")) %></dd></div>
                    <div><dt>Estado al iniciar sesión</dt><dd class="account-state"><%= textoSeguro(session.getAttribute("estadoUsuario")) %></dd></div>
                    <div><dt>Correo verificado al iniciar sesión</dt><dd><%= Boolean.TRUE.equals(session.getAttribute("correoVerificado")) ? "Sí" : Boolean.FALSE.equals(session.getAttribute("correoVerificado")) ? "No" : "No disponible" %></dd></div>
                </dl>
                <% if (Boolean.FALSE.equals(session.getAttribute("correoVerificado"))) { %>
                <p class="notice">ⓘ Según los datos de tu sesión, tu correo todavía necesita verificación.</p>
                <% } %>
                <p class="account-note muted">La verificación del correo por sí sola no garantiza que la cuenta esté habilitada para apostar. Estos datos corresponden al inicio de tu sesión.</p>
            </section>
        </div>
        <noscript><p class="notice">Activa JavaScript para consultar los saldos y el resumen de actividad. La navegación y el cierre de sesión siguen disponibles.</p></noscript>
    </main>
    <footer class="footer"><span>BetZone</span><span>Jugá con responsabilidad. +18.</span></footer>
</body>
</html>
