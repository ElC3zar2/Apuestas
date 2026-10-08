<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Eventos — BetZone</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/inicio-usuario.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/eventos-usuario.css">
    <script>window.APP_CONTEXT_PATH = "${pageContext.request.contextPath}";</script>
    <script src="${pageContext.request.contextPath}/js/eventos-usuario.js" defer></script>
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
    <main id="contenido" class="dashboard events-page">
        <section class="welcome" aria-labelledby="titulo-eventos">
            <div><p class="eyebrow">EXPLORA EL CATÁLOGO</p><h1 id="titulo-eventos">Cada evento, a tu alcance.</h1><p class="muted">Elige un deporte y consulta sus eventos, estados y mercados.</p></div>
            <span class="catalog-label">EVENTOS / BETZONE</span>
        </section>
        <section class="panel filters-panel" aria-labelledby="titulo-filtros">
            <div class="filter-heading"><div><p class="eyebrow">ENCUENTRA TU EVENTO</p><h2 id="titulo-filtros">Explorar por deporte</h2></div>
                <div class="sport-picker"><label for="deporte">Deporte</label><select id="deporte" disabled aria-describedby="deportes-status"><option value="">Cargando deportes…</option></select></div>
            </div>
            <p id="deportes-status" class="muted" role="status">Cargando deportes…</p>
            <button id="reintentar-deportes" class="retry" type="button" hidden>Reintentar deportes</button>
            <fieldset class="view-filters" id="vistas" disabled>
                <legend>Estado de los eventos</legend>
                <label><input type="radio" name="vista" value="TODOS" checked><span>Todos</span></label>
                <label><input type="radio" name="vista" value="PROGRAMADOS"><span>Programados</span></label>
                <label><input type="radio" name="vista" value="PREVIA"><span>Próximos / Previa</span></label>
                <label><input type="radio" name="vista" value="EN_PROGRESO"><span>En progreso</span></label>
                <label><input type="radio" name="vista" value="FINALIZADOS"><span>Finalizados</span></label>
            </fieldset>
        </section>
        <section class="results-section" id="resultados" aria-labelledby="titulo-resultados" aria-busy="false">
            <div class="section-heading results-heading"><h2 id="titulo-resultados">Eventos</h2><span id="cantidad-eventos" class="muted" role="status"></span></div>
            <div class="results-state panel" id="estado-eventos"><span class="state-mark" aria-hidden="true">◇</span><p id="eventos-status" role="status">Selecciona un deporte para explorar sus eventos.</p><button id="reintentar-eventos" class="retry" type="button" hidden>Reintentar eventos</button></div>
            <div class="event-grid" id="lista-eventos"></div>
            <p class="catalog-note muted">La disponibilidad del evento no determina la habilitación de tu cuenta para apostar. Las fechas se muestran tal como las informa el servidor.</p>
        </section>
        <noscript><p class="notice">Activa JavaScript para cargar los deportes y eventos. La navegación y el cierre de sesión siguen disponibles.</p></noscript>
    </main>
    <footer class="footer"><span>BetZone</span><span>Jugá con responsabilidad. +18.</span></footer>
</body>
</html>
