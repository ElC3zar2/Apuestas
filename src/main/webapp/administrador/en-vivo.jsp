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
<title>Control en vivo — BetZone Admin</title>
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/admin.css">
<script src="${pageContext.request.contextPath}/js/admin-api.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin-en-vivo.js" defer></script>
</head><body data-context-path="${pageContext.request.contextPath}" data-admin-role="<%= adminRoleForView %>">
<a class="skip-link" href="#contenido">Ir al contenido</a>
<aside class="sidebar">
<a class="brand" href="${pageContext.request.contextPath}/administrador/inicio">BetZone <span>ADMIN</span></a>
<p class="eyebrow">CENTRO DE OPERACIONES</p>
<nav aria-label="Navegación administrativa">
<a href="${pageContext.request.contextPath}/administrador/inicio#resumen">Resumen</a>
<a href="${pageContext.request.contextPath}/administrador/inicio#finanzas">Finanzas</a>
<a href="${pageContext.request.contextPath}/administrador/inicio#deportes">Deportes</a>
<a href="${pageContext.request.contextPath}/administrador/inicio#auditoria">Auditoría reciente</a>
<a href="${pageContext.request.contextPath}/administrador/en-vivo" aria-current="page">Control en vivo</a>
<a href="${pageContext.request.contextPath}/administrador/catalogos">Ligas y participantes</a>
<a href="${pageContext.request.contextPath}/administrador/eventos">Administrar eventos</a>
<a href="${pageContext.request.contextPath}/administrador/mercados">Mercados y cuotas</a><a href="${pageContext.request.contextPath}/administrador/resultados" data-nav="resultados">Resultados</a>
<a href="${pageContext.request.contextPath}/administrador/liquidaciones" data-nav="liquidaciones">Liquidaciones</a><a href="${pageContext.request.contextPath}/administrador/usuarios">Administración de usuarios</a></nav>
<form id="admin-logout" action="${pageContext.request.contextPath}/administrador/logout" method="post"><button type="submit">Cerrar sesión</button></form><p id="logout-status" role="status"></p>
</aside>
<main id="contenido" class="workspace">
<header class="page-header"><div><p class="eyebrow">OPERACIÓN DEPORTIVA</p><h1>Control en vivo</h1><p class="muted">Marcador, tiempo e incidencias oficiales del backend.</p></div></header>
<p class="warning">El cierre automático del servidor todavía no está habilitado. Si la duración se cumple y el estado sigue EN_VIVO, utiliza el cierre manual autorizado. El seguimiento de esta pantalla solo consulta el estado oficial.</p>
<section class="panel"><h2>Seleccionar evento</h2>
<form id="event-search" class="toolbar"><label for="sport">Deporte<select id="sport" name="idDeporte" required><option value="">Cargando deportes…</option></select></label><button type="submit">Buscar eventos</button><button type="button" id="retry-sports">Recargar deportes</button></form>
<p id="catalog-status" class="live-status" role="status"></p>
<form id="event-select" class="toolbar"><label for="event-list">Eventos disponibles<select id="event-list" class="event-picker" required><option value="">Busca eventos por deporte</option></select></label><button type="submit">Abrir evento</button></form>
<form id="event-id-form" hidden><input id="event-id" type="hidden"></form>
</section>
<div class="toolbar"><button id="refresh-event" type="button" disabled>Actualizar / reintentar</button><a id="live-results" hidden>Revisar resultados del evento</a><a id="live-login" href="${pageContext.request.contextPath}/administrador/login" hidden>Volver a iniciar sesión</a></div>
<p id="live-status" class="live-status" role="status" aria-live="polite">Selecciona un evento para consultar su estado.</p>
<p id="tracking-status" class="muted" role="status" aria-live="polite">Seguimiento sin evento seleccionado.</p>
<p id="confirmed-live" class="live-status" role="status" hidden></p>
<section id="uncertain-live" class="panel" hidden aria-labelledby="uncertain-heading"><h2 id="uncertain-heading">Escritura pendiente de conciliación</h2><p id="uncertain-description" class="warning" role="status"></p><p class="muted">La referencia se conserva en memoria durante esta página, incluso al cambiar de evento. Antes de salir o recargar, conserva la UUID y el contexto para el responsable técnico. No se ofrece reenvío: esta vista no dispone de identidad estable del actor para garantizarlo.</p><button id="acknowledge-live" type="button" disabled>Confirmar revisión del estado coincidente</button></section>
<p id="reconciled-live" class="live-status" role="status" hidden></p>
<div id="event-content" hidden aria-busy="false">
<section class="panel"><p class="eyebrow" id="event-sport">Deporte no incluido en el estado de simulación</p><h2 id="event-name"></h2>
<dl class="event-meta"><div><dt>ID</dt><dd id="official-id">—</dd></div><div><dt>Estado oficial</dt><dd id="official-state">—</dd></div><div><dt>Tipo de evento</dt><dd id="official-simulated">—</dd></div><div><dt>Tiempo disponible</dt><dd id="official-time">—</dd></div><div><dt>Inicio real (UTC)</dt><dd id="official-start">—</dd></div><div><dt>Fin real (UTC)</dt><dd id="official-end">—</dd></div></dl><p id="update-status" class="muted" role="status">Sin lectura oficial.</p>
<progress id="official-progress" hidden aria-label="Tiempo oficial de simulación"></progress><p id="time-note" class="muted"></p>
<div id="scoreboard" class="scoreboard"></div><p id="first-score" class="muted"></p>
</section>
<div class="live-grid">
<section class="panel"><h2 id="state-heading">Control del evento</h2><p class="muted">Inicio y cierre manuales: PROGRAMADO → EN_VIVO → PENDIENTE_RESULTADO. Sin pausa ni reanudación simulada. El servidor valida cada transición.</p>
<form id="state-form" class="live-form"><fieldset id="state-fields" aria-labelledby="state-heading" disabled>
<label for="new-state">Solicitar estado<select id="new-state" name="nuevoEstado" required><option value="">Selecciona una transición</option></select></label>
<label for="state-reason">Motivo (obligatorio al cancelar)<textarea id="state-reason" name="motivo" maxlength="250" rows="2"></textarea></label><button class="primary" type="submit">Solicitar transición</button></fieldset></form>
<p id="transition-note" class="muted">Consulta el evento para ver sus transiciones.</p>
<p class="warning">Cerrar la simulación no oficializa resultados ni liquida apuestas. FINALIZADO solo se establece desde la oficialización de resultados. El cierre autónomo del servidor permanece pendiente de habilitación; el panel no lo simula.</p></section>
<section class="panel"><h2 id="incident-heading">Registrar incidencia</h2>
<form id="incident-form" class="live-form"><fieldset id="incident-fields" aria-labelledby="incident-heading" disabled>
<label for="incident-type">Tipo<select id="incident-type" name="tipoIncidencia"><option>ANOTACION</option><option>FALTA</option><option>TARJETA_AMARILLA</option><option>TARJETA_ROJA</option><option>OTRA</option></select></label>
<label for="participant">Participante<select id="participant" name="idParticipante" required></select></label>
<label id="annotation-label" for="annotation">Valor de anotación<input id="annotation" name="valorAnotacion" type="number" min="1" max="2147483647" step="1" required></label>
<label for="description">Descripción (opcional)<textarea id="description" name="descripcion" maxlength="500" rows="2"></textarea></label>
<button class="primary" type="submit">Registrar incidencia</button></fieldset></form><p class="muted">Registro manual para eventos convencionales y simulados EN_VIVO. Las simulaciones requieren inicio real registrado. Anotaciones y tarjetas están sujetas a reglas deportivas de SQL no expuestas íntegramente en el catálogo. No se infiere la unidad por el nombre del deporte. Una solicitud incierta conserva su UUID y bloquea nuevas escrituras; requiere conciliación técnica, sin reenvío automático ni manual desde esta vista.</p></section>
</div>
<section class="panel"><h2>Incidencias oficiales</h2><div class="table-scroll" tabindex="0" role="region" aria-label="Historial de incidencias; desplazamiento horizontal"><table><caption>Incluye las incidencias anuladas. En eventos convencionales se muestra la fecha de registro, no el tiempo deportivo.</caption><thead><tr><th scope="col">ID / secuencia</th><th scope="col">Tipo</th><th scope="col">Participante</th><th scope="col">Valor</th><th scope="col" id="incident-time-heading">Tiempo / registro (UTC)</th><th scope="col">Descripción</th><th scope="col">Estado / motivo</th><th scope="col">Acción</th></tr></thead><tbody id="incidents-body"></tbody></table></div>
<form id="void-form" class="live-form" hidden><h3 id="void-title">Anular incidencia</h3><fieldset id="void-fields" aria-labelledby="void-title"><label for="void-reason">Motivo obligatorio<textarea id="void-reason" name="motivo" maxlength="500" required rows="2"></textarea></label><button type="submit" class="critical">Confirmar anulación</button><button id="void-cancel" type="button">Volver</button></fieldset></form>
</section></div><noscript>Activa JavaScript para operar el panel.</noscript>
</main></body></html>




