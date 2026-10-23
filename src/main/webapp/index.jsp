<%-- 
    Document   : index
    Created on : 22-ago-2026, 22:53:53
    Author     : Otto
--%>

<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" language="java" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BetZone — La nueva era de las apuestas deportivas</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/Style.css">
</head>
<body>

    <!-- ===================== INFORMACIÓN DE LA PLATAFORMA ===================== -->
    <div class="ticker" role="region" aria-label="Información de BetZone">
        <div class="ticker__track">
            <span class="ticker__item">Explorá eventos desde tu cuenta</span>
            <span class="ticker__item">Revisá la cotización antes de confirmar</span>
            <span class="ticker__item">Consultá tus boletos y movimientos</span>
            <span class="ticker__item">Jugá con responsabilidad. +18.</span>
            <!-- Repetición visual para la cinta continua; se anuncia una sola vez. -->
            <span class="ticker__item" aria-hidden="true">Explorá eventos desde tu cuenta</span>
            <span class="ticker__item" aria-hidden="true">Revisá la cotización antes de confirmar</span>
            <span class="ticker__item" aria-hidden="true">Consultá tus boletos y movimientos</span>
            <span class="ticker__item" aria-hidden="true">Jugá con responsabilidad. +18.</span>
        </div>
    </div>

    <!-- ===================== NAVBAR ===================== -->
    <nav class="navbar">
        <a href="${pageContext.request.contextPath}/index.jsp" class="navbar__brand">
            <span class="dot"></span> BetZone
        </a>
        <div class="navbar__actions">
            <a href="${pageContext.request.contextPath}/usuario/login" class="btn btn--login">Iniciar sesión</a>
            <a href="${pageContext.request.contextPath}/registro" class="btn btn--signup">Crear cuenta</a>
            <a href="${pageContext.request.contextPath}/administrador/login" class="btn btn--admin" aria-label="Acceso administrador" title="Acceso administrador">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                    <circle cx="12" cy="12" r="3"></circle>
                    <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"></path>
                </svg>
            </a>
        </div>
    </nav>

    <!-- ===================== HERO ===================== -->
    <header class="hero">
        <div class="hero__backdrop" aria-hidden="true"></div>
        <div class="hero__overlay" aria-hidden="true"></div>

        <svg class="parallax-icon parallax-icon--ball" data-depth="18" viewBox="0 0 100 100" aria-hidden="true">
            <circle cx="50" cy="50" r="46" fill="none" stroke="#F4F6FB" stroke-width="2"/>
            <path d="M50 12 L64 24 L58 42 L42 42 L36 24 Z" fill="#F4F6FB"/>
            <path d="M12 50 L28 44 L42 58 L34 74 L16 70 Z" fill="none" stroke="#F4F6FB" stroke-width="1.6"/>
            <path d="M88 50 L72 44 L58 58 L66 74 L84 70 Z" fill="none" stroke="#F4F6FB" stroke-width="1.6"/>
        </svg>

        <svg class="parallax-icon parallax-icon--chip" data-depth="26" viewBox="0 0 100 100" aria-hidden="true">
            <circle cx="50" cy="50" r="44" fill="none" stroke="#00FF66" stroke-width="3" stroke-dasharray="6 6"/>
            <circle cx="50" cy="50" r="28" fill="none" stroke="#00FF66" stroke-width="2"/>
        </svg>

        <p class="hero__eyebrow">Eventos · Boletos · Billetera</p>
        <h1>La nueva era de las apuestas deportivas</h1>
        <p class="hero__sub">
            Explorá eventos, revisá tus selecciones y consultá tus boletos y tu billetera
            desde tu cuenta BetZone.
        </p>
        <div class="hero__cta">
            <a href="${pageContext.request.contextPath}/registro" class="btn btn--signup">Crear cuenta gratis</a>
            <a href="#catalogo" class="btn btn--ghost">Conocé BetZone</a>
        </div>
    </header>

    <!-- GRID DE TARJETAS  -->
    <section class="cards" id="catalogo">
        <div class="cards__grid">

            <!-- Tarjeta 1: La Acción -->
            <article class="card card--action" tabindex="0">
                <svg class="card__icon" viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="1.6">
                    <path d="M6 34 L24 18 L42 34" />
                    <rect x="6" y="34" width="36" height="8" rx="1"/>
                    <line x1="24" y1="18" x2="24" y2="8"/>
                </svg>
                <h3 class="card__title">La acción</h3>
                <p class="card__reveal">
                    Explorá los eventos y consultá los mercados y las cuotas disponibles desde tu cuenta.
                </p>
            </article>

            <!-- Tarjeta 2: La Estrategia -->
            <article class="card card--strategy" tabindex="0">
                <svg class="card__icon" viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="1.6">
                    <rect x="6" y="6" width="36" height="30" rx="2"/>
                    <path d="M12 30 Q20 16 28 24 T40 14" stroke-dasharray="3 3"/>
                    <line x1="18" y1="42" x2="30" y2="42"/>
                </svg>
                <h3 class="card__title">La estrategia</h3>
                <div class="card__steps">
                    <div><span>1.</span> Elegí tu deporte ⚽</div>
                    <div><span>2.</span> Analizá tu pronóstico 📊</div>
                    <div><span>3.</span> Revisá antes de confirmar ✓</div>
                </div>
            </article>

            <!-- Tarjeta 3: El Catálogo -->
            <article class="card card--catalog" tabindex="0">
                <svg class="card__icon" viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="1.6">
                    <circle cx="16" cy="16" r="8"/>
                    <circle cx="34" cy="16" r="7"/>
                    <circle cx="24" cy="34" r="9"/>
                </svg>
                <h3 class="card__title">El catálogo</h3>
                <p class="card__reveal">
                    Consultá tus boletos, sus comprobantes y los movimientos de tu billetera en un solo lugar.
                </p>
            </article>

        </div>
    </section>

    <!--  FOOTER o Pie de Pagina -->
    <footer class="footer">
        <span>&copy; <%= java.time.Year.now().getValue() %> BetZone. Jugá con responsabilidad. +18.</span>
        <span>Ayuda &amp; soporte</span>
    </footer>

    <script src="${pageContext.request.contextPath}/js/Script.js"></script>
</body>
</html>
