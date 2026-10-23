<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"%>
<%
    // session=false evita crear sesiones: leer la ya validada por el filtro, sin sessionScope.
    String adminRoleForView = "";
    try {
        javax.servlet.http.HttpSession existingAdminSession = request.getSession(false);
        Object existingAdminRole = existingAdminSession == null ? null : existingAdminSession.getAttribute("adminRol");
        for (String allowedAdminRole : new String[]{"ADMINISTRADOR", "OPERADOR_EVENTOS", "CAJERO", "AUDITOR"}) {
            if (allowedAdminRole.equals(existingAdminRole)) {
                adminRoleForView = allowedAdminRole;
                break;
            }
        }
    } catch (IllegalStateException expiredAdminSession) {
        // Una sesión expirada no proporciona un rol ni habilita operaciones.
    }
%>
<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Liquidaciones — BetZone Admin</title>
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/admin.css">
<script src="${pageContext.request.contextPath}/js/admin-api.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin-liquidaciones.js" defer></script>
</head><body data-context-path="${pageContext.request.contextPath}" data-admin-role="<%= adminRoleForView %>">
<a class="skip-link" href="#contenido">Ir al contenido</a>
<aside class="sidebar"><a class="brand" href="${pageContext.request.contextPath}/administrador/inicio">BetZone <span>ADMIN</span></a><p class="eyebrow">CENTRO DE OPERACIONES</p>
<nav aria-label="Navegación administrativa">
<a href="${pageContext.request.contextPath}/administrador/inicio#resumen">Resumen</a>
<a href="${pageContext.request.contextPath}/administrador/inicio#finanzas">Finanzas</a>
<a href="${pageContext.request.contextPath}/administrador/inicio#deportes">Deportes</a>
<a href="${pageContext.request.contextPath}/administrador/inicio#auditoria">Auditoría reciente</a>
<a href="${pageContext.request.contextPath}/administrador/en-vivo">Control en vivo</a>
<a href="${pageContext.request.contextPath}/administrador/catalogos">Ligas y participantes</a>
<a href="${pageContext.request.contextPath}/administrador/eventos">Administrar eventos</a>
<a href="${pageContext.request.contextPath}/administrador/mercados">Mercados y cuotas</a>
<a href="${pageContext.request.contextPath}/administrador/resultados">Resultados</a>
<a href="${pageContext.request.contextPath}/administrador/liquidaciones" aria-current="page">Liquidaciones</a>
<a href="${pageContext.request.contextPath}/administrador/usuarios">Administración de usuarios</a></nav><form id="admin-logout" action="${pageContext.request.contextPath}/administrador/logout" method="post"><button type="submit">Cerrar sesión</button></form><p id="logout-status" role="status"></p></aside>
<main id="contenido" class="workspace">
<header class="page-header"><div><p class="eyebrow">OPERACIÓN FINANCIERA</p><h1>Liquidaciones</h1><p class="muted">Consulta y procesamiento oficial por boleto o evento. Los importes y pagos pertenecen al servidor.</p></div></header>
<p id="settlement-status" class="live-status" role="status" aria-live="polite">Verificando permisos de la vista.</p>
<a id="settlement-login" href="${pageContext.request.contextPath}/administrador/login" hidden>Volver a iniciar sesión</a>
<p id="read-guard" class="integration-note" role="status" aria-live="polite"></p>
<section id="settlement-uncertain" class="panel warning" hidden><h2 id="uncertain-title">Operación financiera sin confirmación</h2><p id="uncertain-values" role="status" aria-live="assertive"></p><p>El marcador de esta pestaña guarda solo referencias mínimas, no una prueba financiera. No identifica de forma fiable al actor entre sesiones y no cubre otras pestañas. No lo borres para repetir un envío. El responsable técnico debe conciliarlo con el backend.</p></section>
<section id="ready-section" class="panel" hidden><h2>Boletos elegibles</h2><form id="ready-form" class="toolbar"><label for="ready-count">Límite solicitado (vacío: 100)<input id="ready-count" name="cantidad" inputmode="numeric" maxlength="3" value="100"></label><button type="submit">Consultar boletos listos</button></form><p id="ready-info" role="status">Hasta 500 boletos por consulta; sin paginación. Un listado vacío no acredita ausencia de otros boletos.</p><div id="ready-results"></div><label for="eligible-ticket">Boleto del listado oficial<select id="eligible-ticket" disabled><option value="">Consulta los boletos elegibles</option></select></label></section>
<section id="audit-section" class="panel" hidden><h2>Liquidación individual y auditoría</h2><p class="muted">Consulta una referencia oficial conocida. Un 404 no demuestra que el boleto no exista ni que no se haya movido dinero. Para preparar un boleto sin liquidación, selecciónalo del listado oficial.</p><form id="settlement-query" class="toolbar"><label for="ticket-id">Referencia oficial idBoleto<input id="ticket-id" name="idBoleto" inputmode="numeric" maxlength="10" required></label><button type="submit">Consultar liquidación</button></form><p id="ticket-context" role="status">Sin boleto seleccionado.</p><div id="ticket-results"></div></section>
<div id="operation-sections" hidden>
<section class="panel"><h2>Liquidar boleto seleccionado</h2><form id="settle-ticket-form"><fieldset><legend>Operación individual con referencia oficial vigente</legend><p>Se enviará únicamente idBoleto. El servidor puede devolver una liquidación nueva o una ya existente. Requiere confirmación expresa.</p><button id="settle-ticket-button" type="submit" class="critical" disabled>Liquidar boleto</button></fieldset></form></section>
<section class="panel"><h2>Liquidación por evento</h2><form id="event-filter" class="toolbar">
<label for="settlement-sport">Deporte<select id="settlement-sport" required><option value="">Cargando deportes…</option></select></label>
<button type="submit">Buscar / actualizar eventos</button></form>
<label for="settlement-event">Evento<select id="settlement-event" required disabled><option value="">Primero selecciona un deporte</option></select></label>
<p class="muted">Los eventos se consultan por páginas e incluyen todos los estados autorizados, también los cancelados.</p>
<p id="event-page-info" role="status">Sin página administrativa consultada.</p><div id="settlement-event-info" role="status"></div>
<form id="settle-form"><fieldset><legend>Confirmación del lote del evento seleccionado</legend><button id="settle-button" type="submit" class="critical" disabled>Liquidar evento</button></fieldset></form>
<p class="warning">El lote puede confirmar boletos individualmente: no equivale a una transacción financiera global. Una interrupción puede dejar pagos parciales. No hay reintentos automáticos ni desbloqueo por una afirmación del operador.</p>
</section>
</div><section id="settlement-result" class="panel" hidden><h2>Confirmaciones oficiales históricas</h2><p>Un GET fallido o un cambio de contexto no elimina el DTO confirmado. Una respuesta idempotente no representa un pago nuevo. Los boletos omitidos no se presentan como liquidados.</p><div id="settlement-values" class="management-results"></div></section>
<noscript>Activa JavaScript para consultar y operar liquidaciones.</noscript></main></body></html>
