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
<header class="page-header"><div><p class="eyebrow">OPERACIÓN FINANCIERA</p><h1>Liquidaciones por evento</h1><p class="muted">El servidor liquida los boletos elegibles y devuelve el resumen oficial.</p></div></header>
<p id="settlement-status" class="live-status" role="status" aria-live="polite">Selecciona un deporte y un evento.</p>
<a id="settlement-login" href="${pageContext.request.contextPath}/administrador/login" hidden>Volver a iniciar sesión</a>
<section class="panel"><h2>Seleccionar evento</h2><form id="event-filter" class="toolbar">
<label for="settlement-sport">Deporte<select id="settlement-sport" required><option value="">Cargando deportes…</option></select></label>
<button type="submit">Buscar / actualizar eventos</button></form>
<label for="settlement-event">Evento<select id="settlement-event" required disabled><option value="">Primero selecciona un deporte</option></select></label>
<p class="muted">Los eventos se consultan por páginas e incluyen todos los estados autorizados, también los cancelados.</p>
<div id="settlement-event-info"></div>
<form id="settle-form"><button id="settle-button" type="submit" class="critical" disabled>Liquidar evento</button></form>
<p class="warning">Un envío procesa el lote completo. Ante una respuesta incierta, verifica el estado antes de volver a enviarlo. No hay reintentos automáticos.</p>
<button id="settlement-ack" type="button" hidden>Ya verifiqué el estado; permitir un nuevo envío manual</button>
</section>
<section id="settlement-result" class="panel" hidden><h2>Resultado oficial del lote</h2><div id="settlement-values" class="management-results"></div><div id="settlement-details" class="table-scroll"></div></section>
<details class="panel"><summary>Consulta individual de auditoría</summary><p class="muted">Selecciona un boleto del último lote o usa una referencia oficial conocida. La API disponible no ofrece un catálogo de todos los boletos liquidados.</p>
<select id="batch-ticket"><option value="">Selecciona un boleto del lote</option></select>
<form id="settlement-query" class="toolbar"><label for="ticket-id">Referencia oficial de boleto<input id="ticket-id" name="idBoleto" type="number" min="1" max="2147483647" required></label><button type="submit">Consultar liquidación</button></form><div id="ticket-results"></div></details>
<noscript>Activa JavaScript para consultar y operar liquidaciones.</noscript></main></body></html>
