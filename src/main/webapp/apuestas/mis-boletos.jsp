<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mis apuestas — BetZone</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/inicio-usuario.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/mis-boletos.css">
    <script>window.APP_CONTEXT_PATH = "${pageContext.request.contextPath}";</script>
    <script src="${pageContext.request.contextPath}/js/mis-boletos.js" defer></script>
</head>
<body>
    <a class="skip-link" href="#contenido">Ir al contenido</a>
    <header class="topbar">
        <a class="brand" href="${pageContext.request.contextPath}/usuario/inicio.jsp"><span class="brand-dot" aria-hidden="true"></span>BetZone</a>
        <nav class="navigation" aria-label="Navegación principal">
            <a href="${pageContext.request.contextPath}/usuario/inicio.jsp">Inicio</a>
            <a href="${pageContext.request.contextPath}/eventos/listar-eventos.jsp">Eventos</a>
            <a href="${pageContext.request.contextPath}/apuestas/mis-boletos.jsp" aria-current="page">Mis apuestas</a>
            <a href="${pageContext.request.contextPath}/billetera/mi-billetera.jsp">Billetera</a>
            <a href="${pageContext.request.contextPath}/usuario/inicio.jsp#mi-cuenta">Mi cuenta</a>
        </nav>
        <form action="${pageContext.request.contextPath}/usuario/logout" method="POST"><button class="logout" type="submit">Cerrar sesión <span aria-hidden="true">↗</span></button></form>
    </header>
    <main id="contenido" class="dashboard tickets-page">
        <section class="welcome" aria-labelledby="titulo-historial">
            <div><p class="eyebrow">TU HISTORIAL BETZONE</p><h1 id="titulo-historial">Mis apuestas.</h1><p class="muted">Consulta tus boletos, revisa las selecciones y abre el comprobante del servidor.</p></div>
            <a class="button button-primary" href="${pageContext.request.contextPath}/eventos/listar-eventos.jsp">Ver eventos ↗</a>
        </section>
        <section class="panel history-filter" aria-labelledby="titulo-filtro">
            <div><p class="eyebrow">EXPLORA TU ACTIVIDAD</p><h2 id="titulo-filtro">Filtrar por deporte</h2></div>
            <div class="sport-picker"><label for="deporte-boletos">Deporte</label><select id="deporte-boletos" disabled aria-describedby="estado-deportes"><option value="">Todos los deportes</option></select></div>
            <p id="estado-deportes" class="muted filter-message" role="status">Cargando deportes…</p>
            <button id="reintentar-deportes" class="retry" type="button" hidden>Reintentar deportes</button>
        </section>
        <section id="historial" class="history-results" aria-labelledby="titulo-boletos" aria-busy="true">
            <div class="section-heading history-heading"><h2 id="titulo-boletos">Tus boletos</h2><span id="cantidad-boletos" class="muted" role="status"></span></div>
            <p id="nota-filtro" class="notice" hidden>Con el filtro activo se muestran los detalles del deporte seleccionado. El total de selecciones y los importes corresponden al boleto completo.</p>
            <div id="estado-historial" class="panel history-status is-loading">
                <span class="status-symbol" aria-hidden="true">◇</span><p id="mensaje-historial" role="status">Cargando historial…</p>
                <button id="reintentar-historial" class="retry" type="button" hidden>Volver a intentar</button>
                <a id="login-historial" class="text-link login-link" href="${pageContext.request.contextPath}/usuario/login" hidden>Iniciar sesión</a>
            </div>
            <div id="lista-boletos" class="ticket-list"></div>
            <p class="muted pdf-note">El boleto PDF se abre en otra pestaña. Si falta sesión, permiso o el boleto ya no está disponible, allí se mostrará la respuesta del servidor. Las fechas conservan la hora informada por el backend.</p>
        </section>
        <noscript><p class="notice">Activa JavaScript para consultar el historial y filtrar por deporte.</p></noscript>
    </main>
    <footer class="footer"><span>BetZone</span><span>Jugá con responsabilidad. +18.</span></footer>
</body>
</html>
