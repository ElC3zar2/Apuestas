<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Realizar apuesta — BetZone</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/inicio-usuario.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/realizar-apuesta.css">
    <script>window.APP_CONTEXT_PATH = "${pageContext.request.contextPath}";</script>
    <script src="${pageContext.request.contextPath}/js/realizar-apuesta.js" defer></script>
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
    <main id="contenido" class="dashboard bet-page" data-session-user="<%= session.getAttribute("idUsuario") instanceof Integer ? session.getAttribute("idUsuario") : "" %>">
        <a class="back-link" href="${pageContext.request.contextPath}/eventos/listar-eventos.jsp">← Volver a eventos</a>
        <div class="bet-heading"><p class="eyebrow">REVISA ANTES DE CONFIRMAR</p><h1>Tu próxima apuesta.</h1><p class="muted">Consulta los importes del servidor y confirma cuando hayas revisado el resumen.</p></div>
        <div class="bet-layout">
            <section class="panel bet-input" aria-labelledby="titulo-monto">
                <p class="eyebrow">01 / COTIZACIÓN</p><h2 id="titulo-monto">Elige tu monto</h2>
                <p id="seleccion-recibida" class="selection-reference"></p>
                <form id="form-cotizar" novalidate>
                    <label for="monto">Monto de apuesta</label>
                    <input id="monto" name="monto" type="text" inputmode="decimal" autocomplete="off" maxlength="20" required aria-describedby="ayuda-monto error-monto" disabled>
                    <p id="ayuda-monto" class="muted field-help">Usa punto decimal y hasta dos decimales. El servidor determina los límites permitidos.</p>
                    <p id="error-monto" class="field-error" role="status"></p>
                    <button id="cotizar" class="button button-primary bet-button" type="submit" disabled>Cotizar apuesta</button>
                </form>
                <p class="muted field-help">Cotizar no registra una apuesta ni reserva saldo. La cuota puede cambiar al confirmar.</p>
                <a id="volver-evento" class="text-link" hidden>Volver al evento ↗</a>
            </section>
            <section class="panel quote-panel" aria-labelledby="titulo-resumen">
                <p class="eyebrow">02 / REVISIÓN</p><h2 id="titulo-resumen">Resumen de cotización</h2>
                <p id="cotizacion-vacia" class="empty-quote">Ingresa un monto y cotiza para ver la selección y los importes reales.</p>
                <div id="cotizacion" hidden><div id="detalle-seleccion" class="selection-detail"></div><dl id="importes-cotizacion" class="amount-summary"></dl></div>
                <p class="muted field-help">La habilitación de tu cuenta, el saldo y la disponibilidad se validan en el servidor.</p>
                <button id="confirmar" class="button button-primary bet-button" type="button" disabled>Confirmar apuesta</button>
            </section>
        </div>
        <section id="estado-apuesta" class="panel operation-status" aria-busy="false" aria-label="Estado de la operación">
            <p id="mensaje-apuesta" role="status">Esperando selección y monto.</p>
            <a id="login-apuesta" class="text-link" href="${pageContext.request.contextPath}/usuario/login" hidden>Iniciar sesión</a>
        </section>
        <section id="resultado-apuesta" class="panel result-panel" hidden aria-labelledby="titulo-resultado">
            <p class="eyebrow">RESULTADO RECIBIDO</p><h2 id="titulo-resultado">Apuesta confirmada</h2>
            <p class="muted">Código del boleto</p><p id="codigo-boleto" class="ticket-code"></p>
            <dl id="importes-resultado" class="amount-summary"></dl>
            <p id="idempotencia" class="muted"></p>
        </section>
        <noscript><p class="notice">Activa JavaScript para cotizar y confirmar. Puedes regresar a Eventos con el enlace superior.</p></noscript>
    </main>
    <footer class="footer"><span>BetZone</span><span>Jugá con responsabilidad. +18.</span></footer>
</body>
</html>
