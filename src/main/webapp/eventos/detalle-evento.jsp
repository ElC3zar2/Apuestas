<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Detalle del evento — BetZone</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/inicio-usuario.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/detalle-evento.css">
    <script>window.APP_CONTEXT_PATH = "${pageContext.request.contextPath}";</script>
    <script src="${pageContext.request.contextPath}/js/detalle-evento.js" defer></script>
</head>
<body>
    <a class="skip-link" href="#contenido">Ir al contenido</a>
    <header class="topbar">
        <a class="brand" href="${pageContext.request.contextPath}/usuario/inicio.jsp"><span class="brand-dot" aria-hidden="true"></span>BetZone</a>
        <nav class="navigation" aria-label="Navegación principal">
            <a href="${pageContext.request.contextPath}/usuario/inicio.jsp">Inicio</a>
            <a href="${pageContext.request.contextPath}/eventos/listar-eventos.jsp" aria-current="page">Eventos</a>
            <a href="${pageContext.request.contextPath}/apuestas/mis-boletos.jsp">Mis apuestas</a>
            <a href="${pageContext.request.contextPath}/billetera/mi-billetera.jsp">Billetera</a>
            <a href="${pageContext.request.contextPath}/usuario/inicio.jsp#mi-cuenta">Mi cuenta</a>
        </nav>
        <form action="${pageContext.request.contextPath}/usuario/logout" method="POST"><button class="logout" type="submit">Cerrar sesión <span aria-hidden="true">↗</span></button></form>
    </header>
    <main id="contenido" class="dashboard detail-page">
        <a class="back-link" href="${pageContext.request.contextPath}/eventos/listar-eventos.jsp"><span aria-hidden="true">←</span> Volver a eventos</a>
        <div class="page-heading"><p class="eyebrow">EXPLORA CADA POSIBILIDAD</p><h1>Detalle del evento</h1><p class="muted">Participantes, mercados y cuotas informados por el servidor.</p></div>
        <section id="estado-detalle" class="panel detail-status is-loading" aria-busy="true" aria-label="Estado de la consulta">
            <span class="status-symbol" aria-hidden="true">◇</span>
            <p id="mensaje-detalle" role="status">Cargando evento…</p>
            <button id="reintentar-detalle" class="retry" type="button" hidden>Volver a intentar</button>
            <a id="login-detalle" class="text-link login-link" href="${pageContext.request.contextPath}/usuario/login" hidden>Iniciar sesión</a>
        </section>
        <div id="datos-detalle" hidden>
            <section class="panel event-summary" aria-labelledby="nombre-evento">
                <div class="event-heading"><div><p id="categoria-evento" class="eyebrow"></p><h2 id="nombre-evento"></h2></div><span id="estado-visual" class="status-badge"></span></div>
                <dl id="ficha-evento" class="event-info"></dl>
                <p id="disponibilidad-evento" class="availability-notice"></p>
                <p class="muted personal-note">La disponibilidad del evento y sus selecciones no garantiza que tu cuenta esté autorizada a apostar.</p>
            </section>
            <section class="panel participants-panel" aria-labelledby="titulo-participantes">
                <div class="section-heading"><h2 id="titulo-participantes">Participantes</h2></div>
                <div id="participantes" class="participants-grid"></div>
            </section>
            <section class="markets-section" aria-labelledby="titulo-mercados">
                <div class="section-heading markets-heading"><div><p class="eyebrow">OPCIONES DEL EVENTO</p><h2 id="titulo-mercados">Mercados y selecciones</h2></div></div>
                <div id="mercados" class="markets-list"></div>
                <p class="muted personal-note">Las cuotas corresponden a esta consulta y pueden cambiar. Las fechas conservan la hora enviada por el servidor, sin conversión de zona horaria.</p>
            </section>
        </div>
        <noscript><p class="notice">Activa JavaScript para consultar el detalle. Puedes volver al listado usando el enlace superior.</p></noscript>
    </main>
    <footer class="footer"><span>BetZone</span><span>Jugá con responsabilidad. +18.</span></footer>
</body>
</html>
