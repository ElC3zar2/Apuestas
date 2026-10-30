<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"%>
<%
    String adminRoleForView = "";
    try {
        javax.servlet.http.HttpSession adminViewSession = request.getSession(false);
        Object adminViewRole = adminViewSession == null ? null : adminViewSession.getAttribute("adminRol");
        for (String allowedRole : new String[]{"ADMINISTRADOR","OPERADOR_EVENTOS","CAJERO","AUDITOR"})
            if (allowedRole.equals(adminViewRole)) adminRoleForView = allowedRole;
    } catch (IllegalStateException expiredSession) { }
%>

<!DOCTYPE html>
<html lang="es"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mercados y cuotas — BetZone Admin</title>
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/admin.css">
<script src="${pageContext.request.contextPath}/js/admin-api.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin-mercados.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin-gestion.js" defer></script>
</head><body data-admin-role="<%= adminRoleForView %>" data-context-path="${pageContext.request.contextPath}" data-management="mercados">
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
<header class="page-header"><div><p class="eyebrow">ADMINISTRACIÓN DEPORTIVA</p><h1>Mercados y cuotas</h1><p class="muted">Modalidades oficiales, selecciones y registro de cuotas.</p></div></header>
<p class="muted">Las operaciones requieren ADMINISTRADOR u OPERADOR_EVENTOS. El servidor valida permisos, estados y datos oficiales.</p>
<p id="management-status" class="live-status" role="status" aria-live="polite">Selecciona una consulta o completa un formulario.</p>
<a id="management-login" href="${pageContext.request.contextPath}/administrador/login" hidden>Volver a iniciar sesión</a>
<button id="acknowledge-write" type="button" class="critical" hidden>Ya comprobé el resultado; habilitar formularios</button>
<section class="panel" aria-labelledby="query-title"><h2 id="query-title">1. Selecciona un evento</h2>
<form id="browse-form" class="toolbar"><label for="browse-sport">Deporte<select id="browse-sport" name="idDeporte" required><option value="">Carga los deportes disponibles</option></select></label><button type="submit">Consultar eventos</button></form>
<button id="load-sports" type="button">Consultar deportes activos</button>
<div id="browse-results" class="management-results"></div>
<section aria-label="Evento seleccionado"><form id="detail-form" class="toolbar"><label for="detail-id">Evento<select id="detail-id" name="idEvento" required disabled><option value="">Primero consulta eventos por deporte</option></select></label><button type="submit">Consultar / actualizar evento</button></form>
</section><div class="toolbar"><a id="selected-live" hidden>Control en vivo del evento</a><a id="selected-markets" hidden>Mercados del evento</a></div>
<p class="muted">Listado y detalle administrativos, incluidos los borradores. Consulta el evento antes de operar.</p>
<div id="detail-results" class="management-results"></div>
</section>
<section id="market-one" class="panel" aria-labelledby="one-title">
<h2 id="one-title" tabindex="-1">Resultado final 1X2</h2>
<p id="one-preparation" role="status" aria-live="polite"></p>
<div class="toolbar"><a id="one-event-back" hidden>Volver a preparación del evento</a><a id="one-event-program" hidden>Programar evento antes de abrir</a></div>
<ol class="one-steps"><li>Confirmar evento</li><li>Selecciones y cuotas</li><li>Revisar</li><li>Crear y comprobar</li></ol>
<p id="one-context" class="live-status" role="status">Consulta el evento para identificar LOCAL y VISITANTE.</p>
<div id="one-edit">
<label for="one-type">Modalidad<select id="one-type"><option value="CONVENCIONAL">Resultado final 1X2 · CONVENCIONAL</option></select></label>
<p class="muted">Para convencional personalizado, MARCADOR_FINAL o PRIMERA_ANOTACION utiliza la <a href="#manual-markets">administración manual existente</a>.</p>
<label for="one-name">Nombre del mercado<input id="one-name" maxlength="150" value="Resultado final — 1X2" required></label>
<label for="one-description">Descripción (opcional)<textarea id="one-description" maxlength="250" rows="2"></textarea></label>
<div class="one-grid">
<label for="one-odds-1"><strong>1 · LOCAL</strong><span id="one-person-1"></span><input id="one-odds-1" type="text" inputmode="decimal" autocomplete="off" maxlength="32" required aria-describedby="one-odds-help"></label>
<label for="one-odds-X"><strong>X · EMPATE</strong><span id="one-person-X">Empate</span><input id="one-odds-X" type="text" inputmode="decimal" autocomplete="off" maxlength="32" required aria-describedby="one-odds-help"></label>
<label for="one-odds-2"><strong>2 · VISITANTE</strong><span id="one-person-2"></span><input id="one-odds-2" type="text" inputmode="decimal" autocomplete="off" maxlength="32" required aria-describedby="one-odds-help"></label>
</div>
<p id="one-odds-help" class="muted">Introduce las tres cuotas revisadas: mayores que 1, hasta 999999.9999 y cuatro decimales. No se redondean ni se sugieren probabilidades o márgenes.</p>
<button id="one-prepare" type="button" class="primary">Revisar configuración 1X2</button>
</div>
<div id="one-review" hidden><h3>Confirmación previa</h3><div id="one-summary"></div>
<p class="warning">Se creará un mercado, después sus tres selecciones y finalmente las cuotas indicadas. Son siete operaciones independientes del servidor. El mercado permanecerá en BORRADOR.</p>
<div class="toolbar"><button id="one-back" type="button">Volver a editar</button><button id="one-confirm" type="button" class="primary">Confirmar y configurar 1X2</button></div></div>
<div id="one-progress" hidden><h3>Proceso conservado</h3><p id="one-state" role="status" aria-live="polite"></p><p id="one-market-state"></p><div id="one-rows"></div>
<p class="muted">Consultar acredita el estado observado, no qué POST lo produjo. Vincular referencias requiere revisión administrativa explícita. Una operación incierta sin evidencia suficiente mantiene el bloqueo; no se reenvía automáticamente.</p>
<div class="toolbar"><button id="one-check" type="button">Consultar y comprobar proceso</button><button id="one-adopt" type="button">Revisar y vincular referencias observadas</button><button id="one-resume" type="button">Continuar operaciones pendientes</button><button id="one-open" type="button">Revisar y abrir mercado</button><button id="one-release" type="button">Finalizar proceso revisado</button><button id="one-cancel" type="button">Editar plan todavía no enviado</button></div>
<p class="muted">Abrir exige confirmación independiente y evento PROGRAMADO. El asistente no programa ni inicia eventos.</p>
</div>
</section>
<section class="panel" aria-labelledby="market-title"><h2 id="market-title">Mercado seleccionado</h2><label for="market-picker">Mercado<select id="market-picker" disabled><option value="">Consulta primero un evento</option></select></label><div id="market-context" role="status"></div><div id="market-selections" class="management-results"></div><label for="selection-picker">Selección<select id="selection-picker" disabled><option value="">Selecciona un mercado</option></select></label><p id="selection-context" role="status"></p></section>
<section id="operation-result" class="panel" hidden aria-labelledby="result-title"><h2 id="result-title">Respuesta oficial de la operación</h2><div id="operation-values"></div></section>
<section class="panel"><h2 id="manual-markets">Administración manual de mercados</h2><p id="management-selection" class="muted" role="status">Selecciona un evento de la tabla para trabajar con sus datos oficiales.</p><nav id="management-flow" class="operation-nav" aria-label="Operaciones del registro seleccionado"></nav></section><div id="management-forms" class="management-grid connected-forms"></div>
<noscript>Activa JavaScript para consultar y operar estos módulos.</noscript>
</main></body></html>



