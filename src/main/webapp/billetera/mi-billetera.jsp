<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mi billetera — BetZone</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/inicio-usuario.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/billetera-usuario.css">
    <script>window.APP_CONTEXT_PATH = "${pageContext.request.contextPath}";</script>
    <script src="${pageContext.request.contextPath}/js/billetera-usuario.js" defer></script>
</head>
<body data-wallet-page="resumen">
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
            <div><p class="eyebrow">TU BILLETERA BETZONE</p><h1 id="titulo-pagina">Mi billetera.</h1><p class="muted">Consulta los saldos y la información de tu billetera.</p></div>
            <a class="button button-primary" href="${pageContext.request.contextPath}/billetera/movimientos.jsp">Ver movimientos ↗</a>
        </section>
        <section id="consulta-billetera" aria-labelledby="titulo-resultados" aria-busy="true">
            <div class="section-heading"><h2 id="titulo-resultados">Tus saldos</h2><span class="muted">Información del servidor</span></div>
            <div id="estado-billetera" class="panel wallet-status is-loading">
                <span class="status-symbol" aria-hidden="true">◇</span><p id="mensaje-billetera" role="status">Cargando billetera…</p>
                <button id="reintentar-billetera" class="retry" type="button" hidden>Volver a intentar</button>
                <a id="login-billetera" class="text-link" href="${pageContext.request.contextPath}/usuario/login" hidden>Iniciar sesión</a>
            </div>
            <div id="datos-billetera" hidden></div>
            <p class="muted wallet-note">Los importes se muestran tal como los devuelve el servidor. Esta pantalla permite consultar tu billetera y su historial.</p>
        </section>
        <noscript><p class="notice">Activa JavaScript para consultar tu billetera.</p></noscript>
    </main>
    <footer class="footer"><span>BetZone</span><span>Jugá con responsabilidad. +18.</span></footer>
</body>
</html>
