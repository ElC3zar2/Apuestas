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
<title>Administrar eventos — BetZone Admin</title>
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/admin.css">
<script src="${pageContext.request.contextPath}/js/admin-api.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin-evento-asistente.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin-gestion.js" defer></script>
</head><body data-context-path="${pageContext.request.contextPath}" data-management="eventos" data-admin-role="<%= adminRoleForView %>">
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
<header class="page-header"><div><p class="eyebrow">ADMINISTRACIÓN DEPORTIVA</p><h1>Administrar eventos</h1><p class="muted">Configuración de eventos, participantes y estados.</p></div></header>
<p class="muted">Las operaciones requieren ADMINISTRADOR u OPERADOR_EVENTOS. El servidor valida permisos, estados y datos oficiales.</p>
<p id="management-status" class="live-status" role="status" aria-live="polite">Selecciona una consulta o completa un formulario.</p>
<a id="management-login" href="${pageContext.request.contextPath}/administrador/login" hidden>Volver a iniciar sesión</a>
<button id="acknowledge-write" type="button" class="critical" hidden>Ya comprobé el resultado; habilitar formularios</button>
<section id="event-wizard" class="panel event-wizard" aria-labelledby="wizard-title">
<p class="eyebrow">NUEVO EVENTO</p><h2 id="wizard-title" tabindex="-1">Crea tu evento paso a paso</h2>
<ol class="wizard-steps" aria-label="Progreso de creación"><li data-step-marker="1">1 · Deporte y liga</li><li data-step-marker="2">2 · Participantes</li><li data-step-marker="3">3 · Configuración</li><li data-step-marker="4">4 · Revisar y crear</li><li data-step-marker="5">5 · Mercados y cuotas</li></ol>
<p id="wizard-status" class="live-status" role="status" aria-live="polite">Empieza seleccionando un deporte y una liga reales.</p>
<form id="wizard-form" novalidate>
<div data-wizard-step="1"><h3>Deporte y liga</h3><div class="toolbar"><button id="wizard-load-sports" type="button">Cargar / actualizar deportes</button></div>
<div class="wizard-fields"><label for="wizard-sport">Deporte<select id="wizard-sport" required><option value="">Carga los deportes disponibles</option></select></label><label for="wizard-league">Liga<select id="wizard-league" required disabled><option value="">Primero selecciona un deporte</option></select></label></div><button id="wizard-load-leagues" type="button">Consultar / actualizar ligas</button><p class="muted">Si no hay ligas disponibles, utiliza <a href="${pageContext.request.contextPath}/administrador/catalogos">Ligas y participantes</a>.</p></div>
<div data-wizard-step="2" hidden><h3>Participantes</h3>
<p class="muted">Se ofrecen participantes activos del deporte con asociación activa a la liga seleccionada, como exige el backend. Si falta uno, asócialo primero en Ligas y participantes. Esto no implica pertenencia exclusiva a una liga.</p>
<div class="toolbar"><label for="wizard-participant-search">Buscar participante<input id="wizard-participant-search" type="search" maxlength="150"></label><button id="wizard-participant-query" type="button">Buscar</button><button id="wizard-participant-prev" type="button">Anteriores</button><span id="wizard-participant-page" role="status"></span><button id="wizard-participant-next" type="button">Siguientes</button></div>
<div class="wizard-fields"><label for="wizard-first"><span id="wizard-first-label">Participante 1</span><select id="wizard-first" required disabled><option value="">Primero selecciona una liga</option></select></label>
<label for="wizard-second"><span id="wizard-second-label">Participante 2</span><select id="wizard-second" required disabled><option value="">Primero selecciona una liga</option></select></label></div>
<div id="wizard-participants" class="wizard-participants"></div><p class="muted">Las selecciones se conservan al buscar o cambiar de página. Antes de crear se comprobará nuevamente que ambos participantes sigan activos en esta liga.</p></div>
<div data-wizard-step="3" hidden><h3>Configurar evento</h3><div class="wizard-fields">
<label for="wizard-name">Nombre del evento<input id="wizard-name" maxlength="200" required></label>
<label for="wizard-start">Inicio programado (hora del servidor)<input id="wizard-start" type="datetime-local" step="1" min="0001-01-01T00:00:00" max="9999-12-31T23:59:59" required></label>
<label for="wizard-end">Fin programado (opcional)<input id="wizard-end" type="datetime-local" step="1" min="0001-01-01T00:00:00" max="9999-12-31T23:59:59"></label>
<label class="wizard-check" for="wizard-simulated"><input id="wizard-simulated" type="checkbox"> Es simulado</label>
<label for="wizard-duration">Duración simulada en segundos (opcional)<input id="wizard-duration" type="number" min="1" max="2147483647" step="1" disabled></label></div><p id="wizard-simulation-help" class="muted">Solo puedes activar simulación si el deporte la permite. Si dejas la duración vacía, se utiliza la configuración del backend. Las fechas se envían tal como las indicas, sin convertir zonas horarias.</p></div>
<div data-wizard-step="4" hidden><h3>Revisar antes de crear</h3><div id="wizard-summary"></div><p class="warning">Crear el evento y asociar cada participante son operaciones independientes. No se publicará ni iniciará automáticamente.</p><button id="wizard-create" type="submit" class="primary">Confirmar y crear evento</button></div>
<div data-wizard-step="5" hidden><h3 id="wizard-outcome-title">Configuración del evento</h3><p id="wizard-created-reference" class="muted"></p><div id="wizard-associations"></div><div class="toolbar"><button id="wizard-reconcile" type="button">Consultar configuración oficial</button><button id="wizard-resume" type="button">Completar asociaciones pendientes</button><a id="wizard-advanced" href="#advanced-event-management">Abrir administración avanzada del evento</a><a id="wizard-markets" hidden>Configurar mercados y cuotas →</a><button id="wizard-new" type="button">Preparar otro evento</button></div></div>
<div id="wizard-recovery" hidden><h3>Comprobar una creación sin respuesta</h3><p class="warning">No vuelvas a crear el evento. Usa Buscar eventos del proceso y localízalo por nombre, liga y fecha, recorriendo las páginas cuando sea necesario. El asistente consultará el detalle antes de vincularlo.</p><div class="toolbar"><button id="wizard-recovery-query" type="button">Buscar eventos del proceso</button><button id="wizard-recovery-prev" type="button" disabled>Anteriores</button><span id="wizard-recovery-page" role="status"></span><button id="wizard-recovery-next" type="button" disabled>Siguientes</button></div><div class="toolbar"><label for="wizard-recovery-id">Evento creado<select id="wizard-recovery-id"><option value="">Consulta eventos por deporte</option></select></label><button id="wizard-recover" type="button">Consultar y vincular evento existente</button></div><p class="muted">La consulta comprueba el estado observado; no demuestra qué petición lo produjo. Si no puedes identificar el evento, solicita revisión manual en <a id="wizard-recovery-advanced" href="#advanced-event-management">administración avanzada</a>.</p></div>
<div class="toolbar wizard-navigation"><button id="wizard-prev" type="button">← Anterior</button><button id="wizard-next" type="button" class="primary">Siguiente →</button></div>
</form></section>
<details class="panel" id="advanced-event-management"><summary>Administración avanzada: consultar, actualizar y cambiar estados</summary><section class="panel" aria-labelledby="query-title"><h2 id="query-title">Consultar información disponible</h2>
<form id="browse-form" class="toolbar"><label for="browse-sport">Deporte<select id="browse-sport" name="idDeporte" required><option value="">Carga los deportes disponibles</option></select></label><button type="submit">Consultar eventos</button></form>
<label for="event-state-filter">Estado<select id="event-state-filter"><option value="">Todos</option><option>BORRADOR</option><option>PROGRAMADO</option><option>EN_VIVO</option><option>SUSPENDIDO</option><option>PENDIENTE_RESULTADO</option><option>FINALIZADO</option><option>CANCELADO</option></select></label>
<button id="load-sports" type="button">Consultar deportes activos</button>
<div id="browse-results" class="management-results"></div>
<form id="detail-form" class="toolbar"><label for="detail-id">Evento<select id="detail-id" name="idEvento" required disabled><option value="">Primero consulta eventos por deporte</option></select></label><button type="submit">Consultar / actualizar evento</button></form>
<div class="toolbar"><a id="selected-live" hidden>Control en vivo del evento</a><a id="selected-markets" hidden>Mercados del evento</a></div>
<p class="muted">Este listado y el detalle son administrativos e incluyen borradores. Consulta el detalle antes de actualizar o cambiar estados. Las transiciones las decide el backend.</p>
<form id="event-participant-query" class="toolbar"><label for="event-participant-search">Buscar participante activo de la liga<input id="event-participant-search" type="search" maxlength="150"></label><button type="submit">Consultar candidatos</button><button id="event-participant-prev" type="button" disabled>Anteriores</button><span id="event-participant-page" role="status"></span><button id="event-participant-next" type="button" disabled>Siguientes</button></form>
<div id="detail-results" class="management-results"></div>
</section>
<section id="operation-result" class="panel" hidden aria-labelledby="result-title"><h2 id="result-title">Respuesta oficial de la operación</h2><div id="operation-values"></div></section>
<div id="management-forms" class="management-grid"></div>
</details><noscript>Activa JavaScript para consultar y operar estos módulos.</noscript>
</main></body></html>





