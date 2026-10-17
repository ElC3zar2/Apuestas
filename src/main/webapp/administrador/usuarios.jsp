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
<title>Administración de usuarios — BetZone Admin</title>
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/admin.css">
<script src="${pageContext.request.contextPath}/js/admin-api.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin-usuarios.js" defer></script>
</head><body data-context-path="${pageContext.request.contextPath}" data-admin-role="<%= adminRoleForView %>">
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
<a href="${pageContext.request.contextPath}/administrador/liquidaciones" data-nav="liquidaciones">Liquidaciones</a><a href="${pageContext.request.contextPath}/administrador/usuarios" aria-current="page">Administración de usuarios</a></nav><form id="admin-logout" action="${pageContext.request.contextPath}/administrador/logout" method="post"><button type="submit">Cerrar sesión</button></form><p id="logout-status" role="status"></p></aside>
<main id="contenido" class="workspace">
<header class="page-header"><div><p class="eyebrow">ADMINISTRACIÓN DE CUENTAS</p><h1>Administración de usuarios</h1><p class="muted">Verificación, estados y restricciones de cuentas cliente.</p></div></header>
<p class="muted">ADMINISTRADOR puede consultar y modificar. AUDITOR puede consultar. El servidor valida los permisos y las condiciones de cada operación.</p>
<p id="users-status" class="live-status" role="status" aria-live="polite">Selecciona una cuenta del listado de verificaciones pendientes.</p>
<a id="users-login" href="${pageContext.request.contextPath}/administrador/login" hidden>Volver a iniciar sesión</a>
<p id="users-uncertain" class="warning" role="status" hidden>Hay una operación sin confirmación. Consulta de nuevo el detalle del mismo usuario antes de considerar un reintento. No se reenvía ningún POST automáticamente.</p>
<section class="panel"><h2>Usuarios pendientes de verificación</h2>
<form id="pending-form" class="toolbar"><label for="pending-count">Cantidad máxima<input id="pending-count" name="cantidad" type="number" min="1" max="500" step="1" value="100" required></label><button type="submit">Consultar / actualizar pendientes</button></form>
<p class="muted">Esta consulta incluye verificaciones pendientes o en revisión; no es un listado general de usuarios.</p>
<section id="users-batch" class="users-batch" hidden aria-labelledby="batch-title">
<h3 id="batch-title">Aprobación de verificaciones por lote</h3>
<p class="warning">La interfaz por lotes no puede autorizarse para uso real hasta que se instale y valide el procedimiento SQL corregido.</p>
<p class="muted">Selecciona únicamente identidades que hayas revisado y decidido aprobar. La selección no sustituye la revisión de identidad.</p>
<div class="toolbar"><label class="batch-choice"><input id="batch-all" type="checkbox"> Seleccionar todos los elegibles visibles (máximo 40)</label><button id="batch-clear" type="button">Limpiar selección</button><strong id="batch-count" role="status">Seleccionados: 0 de 40</strong></div>
<label for="batch-observation">Observación administrativa común (opcional, máximo 500 caracteres)</label>
<textarea id="batch-observation" maxlength="500" rows="3"></textarea>
<button id="batch-approve" type="button" class="primary" disabled>Aprobar seleccionados</button>
</section>
<div id="pending-results" class="management-results"></div>
</section>
<section id="batch-results" class="panel users-batch" hidden aria-labelledby="batch-results-title">
<h2 id="batch-results-title">Resultado del lote</h2>
<p id="batch-progress" role="status" aria-live="polite"></p>
<div id="batch-summary" class="management-results"></div>
<div id="batch-rows" class="management-results"></div>
<button id="batch-dismiss" type="button">Descartar resultados revisados e iniciar otro lote</button>
</section>
<section class="panel"><h2>Consultar usuario</h2><p class="muted">Este módulo consulta únicamente cuentas cliente con rol USUARIO. Las cuentas administrativas no están admitidas por este contrato.</p>
<section class="panel"><h2>Buscar cuentas</h2><form id="user-search" class="toolbar"><label for="user-search-text">Nombre o correo<input id="user-search-text" name="buscar" type="search" maxlength="150"></label><button type="submit">Buscar usuarios</button></form>
<div class="toolbar"><button id="users-prev" type="button" disabled>Anterior</button><span id="users-page" role="status"></span><button id="users-next" type="button" disabled>Siguiente</button></div><div id="user-search-results" class="management-results"></div>
<form id="user-query" hidden><input id="user-id" name="idUsuario" type="hidden"></form></section>
<div id="user-detail" hidden><h3 id="user-identity"></h3><p id="user-email" class="muted"></p><div id="user-account" class="management-results"></div>
<details id="review-data"><summary>Datos personales para revisión de identidad</summary><p class="muted">Consulta estos datos solo cuando sean necesarios para revisar la cuenta seleccionada.</p><div id="user-personal" class="management-results"></div></details>
<h3>Historial de verificaciones</h3><p class="muted">Selecciona un registro real para iniciar, aprobar o rechazar su verificación.</p><div id="user-verifications" class="management-results"></div>
<h3>Restricciones registradas</h3><div id="user-restrictions" class="management-results"></div></div>
</section>
<section id="users-operation-result" class="panel" hidden><h2>Respuesta oficial de la operación</h2><div id="users-operation-values" class="management-results"></div></section>
<section id="users-operation-panel" hidden><h2>Operaciones sobre la cuenta consultada</h2><p id="operation-user" class="muted"></p><p class="muted">Los IDs de operación se cargan desde el detalle. Aprobar no garantiza activación: el backend comprueba el correo y el estado de la cuenta.</p><nav id="users-flow" class="operation-nav" aria-label="Operaciones de la cuenta consultada"></nav><div id="users-forms" class="management-grid connected-forms"></div></section>
<noscript>Activa JavaScript para consultar y administrar usuarios.</noscript></main></body></html>


