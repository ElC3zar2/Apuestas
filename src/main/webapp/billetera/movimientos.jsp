<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Movimientos — BetZone</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/inicio-usuario.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/billetera-usuario.css">
    <script>window.APP_CONTEXT_PATH = "${pageContext.request.contextPath}";</script>
    <script src="${pageContext.request.contextPath}/js/billetera-usuario.js" defer></script>
</head>
<body data-wallet-page="movimientos">
    <a class="skip-link" href="#contenido">Ir al contenido</a>
    <header class="topbar">
        <a class="brand" href="${pageContext.request.contextPath}/usuario/inicio.jsp"><span class="brand-dot" aria-hidden="true"></span>BetZone</a>
        <nav class="navigation" aria-label="Navegación principal">
            <a href="${pageContext.request.contextPath}/usuario/inicio.jsp">Inicio</a>
            <a href="${pageContext.request.contextPath}/eventos/listar-eventos.jsp">Eventos</a>
            <a href="${pageContext.request.contextPath}/apuestas/mis-boletos.jsp">Mis apuestas</a>
            <a href="${pageContext.request.contextPath}/billetera/mi-billetera.jsp" aria-current="page">Billetera</a>
            <a href="${pageContext.request.contextPath}/usuario/mi-cuenta.jsp">Mi cuenta</a>
        </nav>
        <form action="${pageContext.request.contextPath}/usuario/logout" method="POST"><button class="logout" type="submit">Cerrar sesión <span aria-hidden="true">↗</span></button></form>
    </header>
    <main id="contenido" class="dashboard wallet-page">
        <section class="welcome" aria-labelledby="titulo-pagina">
            <div><p class="eyebrow">TU BILLETERA BETZONE</p><h1 id="titulo-pagina">Movimientos.</h1><p class="muted">Revisa tus transacciones y los cambios de saldo informados por el servidor.</p></div>
            <a class="button button-primary" href="${pageContext.request.contextPath}/billetera/mi-billetera.jsp">Mi billetera ↗</a>
        </section>
        <section class="panel movement-filter" aria-labelledby="titulo-filtros">
            <p class="eyebrow">CONSULTA POR FECHA</p><h2 id="titulo-filtros">Filtrar movimientos</h2>
            <form id="filtros-movimientos" novalidate>
                <div class="filter-fields">
                    <div><label for="fecha-desde">Desde (opcional)</label><input id="fecha-desde" type="datetime-local" step="1" min="0001-01-01T00:00:00" max="9999-12-31T23:59:59"></div>
                    <div><label for="fecha-hasta">Hasta (opcional)</label><input id="fecha-hasta" type="datetime-local" step="1" min="0001-01-01T00:00:00" max="9999-12-31T23:59:59"></div>
                    <div><label for="limite-movimientos">Cantidad máxima (opcional)</label><input id="limite-movimientos" type="number" min="1" max="500" step="1" placeholder="100" aria-describedby="nota-fechas"></div>
                </div>
                <p id="nota-fechas" class="muted">Usa la hora del servidor, sin conversión de zona horaria. Cantidad: 1 a 500; si la omites se consultan hasta 100 movimientos.</p>
                <p id="error-filtros" class="filter-error" role="alert" hidden></p>
                <div class="filter-actions"><button class="button button-primary" type="submit">Aplicar filtros</button><button id="limpiar-filtros" class="button button-secondary" type="button">Limpiar filtros</button></div>
            </form>
        </section>
        <section id="consulta-billetera" aria-labelledby="titulo-resultados" aria-busy="true">
            <div class="section-heading"><h2 id="titulo-resultados">Tu historial</h2><span id="cantidad-movimientos" class="muted" role="status"></span></div>
            <p id="filtros-aplicados" class="muted" role="status"></p>
            <div id="estado-billetera" class="panel wallet-status is-loading">
                <span class="status-symbol" aria-hidden="true">◇</span><p id="mensaje-billetera" role="status">Cargando movimientos…</p>
                <button id="reintentar-billetera" class="retry" type="button" hidden>Volver a intentar</button>
                <a id="login-billetera" class="text-link" href="${pageContext.request.contextPath}/usuario/login" hidden>Iniciar sesión</a>
            </div>
            <div id="datos-billetera" class="movement-list" hidden></div>
            <p class="muted wallet-note">Se muestran los movimientos recibidos hasta el límite consultado. El tipo y la descripción conservan su significado original. Las variaciones de saldo son las informadas por el servidor: no se deduce un premio o reembolso por el signo del monto. Las fechas conservan la hora del servidor.</p>
        </section>
        <noscript><p class="notice">Activa JavaScript para consultar y filtrar movimientos.</p></noscript>
    </main>
    <footer class="footer"><span>BetZone</span><span>Jugá con responsabilidad. +18.</span></footer>
</body>
</html>
