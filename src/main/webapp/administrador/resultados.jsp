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
<html lang="es"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Resultados — BetZone Admin</title>
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/admin.css">
<script src="${pageContext.request.contextPath}/js/admin-api.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin-resultados.js" defer></script>
</head><body data-context-path="${pageContext.request.contextPath}" data-management="resultados" data-admin-role="<%= adminRoleForView %>">
<a class="skip-link" href="#contenido">Ir al contenido</a>
<aside class="sidebar"><a class="brand" href="${pageContext.request.contextPath}/administrador/inicio">BetZone <span>ADMIN</span></a><p class="eyebrow">CENTRO DE OPERACIONES</p>
<nav aria-label="Navegación administrativa">
<a href="${pageContext.request.contextPath}/administrador/inicio#resumen">Resumen</a>
<a href="${pageContext.request.contextPath}/administrador/inicio#finanzas">Finanzas</a>
<a href="${pageContext.request.contextPath}/administrador/inicio#deportes">Deportes</a>
<a href="${pageContext.request.contextPath}/administrador/inicio#auditoria">Auditoría reciente</a>
<a href="${pageContext.request.contextPath}/administrador/en-vivo">Control en vivo</a>
<a href="${pageContext.request.contextPath}/administrador/catalogos" data-nav="catalogos">Ligas y participantes</a>
<a href="${pageContext.request.contextPath}/administrador/eventos" data-nav="eventos">Administrar eventos</a>
<a href="${pageContext.request.contextPath}/administrador/mercados" data-nav="mercados">Mercados y cuotas</a>
<a href="${pageContext.request.contextPath}/administrador/resultados" data-nav="resultados">Resultados</a>
<a href="${pageContext.request.contextPath}/administrador/liquidaciones" data-nav="liquidaciones">Liquidaciones</a><a href="${pageContext.request.contextPath}/administrador/usuarios">Administración de usuarios</a></nav><form id="admin-logout" action="${pageContext.request.contextPath}/administrador/logout" method="post"><button type="submit">Cerrar sesión</button></form><p id="logout-status" role="status"></p></aside>
<main id="contenido" class="workspace">
<header class="page-header"><div><p class="eyebrow">ADMINISTRACIÓN DEPORTIVA</p><h1>Resultados deportivos</h1><p class="muted">Registro, resolución, oficialización y revisión de resultados.</p></div></header>
<p class="muted">Registrar, resolver y oficializar: ADMINISTRADOR u OPERADOR_EVENTOS. Corregir y anular: solo ADMINISTRADOR. El servidor valida cada operación.</p>
<p id="management-status" class="live-status" role="status" aria-live="polite">Selecciona un evento para consultar su resultado oficial.</p>
<a id="management-login" href="${pageContext.request.contextPath}/administrador/login" hidden>Volver a iniciar sesión</a>
<section id="uncertain-result" class="panel" aria-labelledby="uncertain-title" hidden><h2 id="uncertain-title">Escritura pendiente de conciliación</h2><p id="uncertain-values" class="warning" role="status"></p><p class="muted">Se conserva en memoria de esta página, incluso al cambiar de evento. Antes de salir o recargar, conserva el expediente para el responsable técnico. No es persistencia durable ni garantía transaccional. No se ofrece reenvío del POST.</p><button id="acknowledge-result" type="button" disabled>Confirmar revisión del registro y estado originales</button></section>
<p id="reconciliation-result" class="live-status" role="status" hidden></p>
<section class="panel" aria-labelledby="query-title"><h2 id="query-title">1. Selecciona un evento</h2>
<form id="browse-form" class="toolbar"><label for="browse-sport">Deporte<select id="browse-sport" name="idDeporte" required><option value="">Carga los deportes disponibles</option></select></label><label for="browse-state">Estado del evento<select id="browse-state" name="estado"><option value="">Todos los estados</option><option>BORRADOR</option><option>PROGRAMADO</option><option>EN_VIVO</option><option>SUSPENDIDO</option><option>PENDIENTE_RESULTADO</option><option>FINALIZADO</option><option>CANCELADO</option></select></label><button type="submit">Consultar eventos</button></form>
<button id="load-sports" type="button">Consultar deportes activos</button>
<div id="browse-results" class="management-results"></div>
<section aria-label="Evento seleccionado"><form id="detail-form" class="toolbar"><label for="detail-id">Evento<select id="detail-id" name="idEvento" required disabled><option value="">Primero consulta eventos por deporte</option></select></label><button type="submit">Consultar / actualizar evento</button></form>
</section><details class="advanced-reference"><summary>Consultar un ID real de evento</summary><form id="direct-event-form" class="toolbar"><label for="direct-event-id">ID del evento<input id="direct-event-id" name="idEvento" inputmode="numeric" maxlength="10" required></label><button type="submit">Consultar ID del evento</button></form></details><div class="toolbar"><button id="refresh-result" type="button" disabled>Actualizar lectura del evento</button><a id="selected-event" hidden>Administrar evento</a><a id="selected-live" hidden>Control en vivo del evento</a><a id="selected-markets" hidden>Mercados del evento</a></div>
<p class="muted">Consulta administrativa paginada. Un listado vacío no demuestra que un evento no exista.</p>
<p id="reading-status" class="live-status" role="status">Sin lectura oficial.</p>
<div id="detail-results" class="management-results"></div>
</section>
<section id="results-flow" class="panel" aria-labelledby="results-flow-title"><h2 id="results-flow-title">Flujo del evento</h2><ol class="wizard-steps"><li>Evento</li><li>Resultado preliminar</li><li>Resoluciones</li><li>Oficialización</li><li>Liquidaciones</li></ol><p id="result-next" role="status" aria-live="polite">Consulta el contexto oficial para ver el siguiente paso.</p><ul id="official-requirements"></ul><a id="selected-settlements" hidden>Consultar liquidaciones del evento</a><p class="muted">La navegación solo abre la vista financiera. Oficializar no liquida boletos; un boleto compuesto puede depender de otros eventos.</p></section>
<section id="operation-result" class="panel" hidden aria-labelledby="result-title"><h2 id="result-title">Confirmaciones oficiales de POST</h2><div id="operation-values"></div></section>
<p class="warning">Oficializar aplica resoluciones deportivas y finaliza el evento; no paga premios ni liquida financieramente boletos. MARCADOR_FINAL y PRIMERA_ANOTACION se resuelven por SQL.</p><p id="result-context" class="muted" role="status">Consulta el evento y su resultado antes de operar.</p><section id="operations-panel" class="panel"><h2>2. Elige una operación</h2><p id="management-selection" class="muted" role="status">Los IDs operativos se obtienen de las consultas oficiales.</p><nav id="management-flow" class="operation-nav" aria-label="Operaciones del resultado seleccionado"></nav></section><p id="operation-note" class="muted" role="status"></p><div id="management-forms" class="management-grid connected-forms" aria-busy="false"></div>
<noscript>Activa JavaScript para consultar y operar estos módulos.</noscript>
</main></body></html>





