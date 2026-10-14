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
<script src="${pageContext.request.contextPath}/js/admin.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin-gestion.js" defer></script>
</head><body data-context-path="${pageContext.request.contextPath}" data-management="resultados" data-admin-role="<%= adminRoleForView %>">
<a class="skip-link" href="#contenido">Ir al contenido</a>
<aside class="sidebar"><a class="brand" href="${pageContext.request.contextPath}/administrador/inicio.jsp">BetZone <span>ADMIN</span></a><p class="eyebrow">CENTRO DE OPERACIONES</p>
<nav aria-label="Navegación administrativa">
<a href="${pageContext.request.contextPath}/administrador/inicio.jsp#resumen">Resumen</a>
<a href="${pageContext.request.contextPath}/administrador/inicio.jsp#finanzas">Finanzas</a>
<a href="${pageContext.request.contextPath}/administrador/inicio.jsp#deportes">Deportes</a>
<a href="${pageContext.request.contextPath}/administrador/inicio.jsp#auditoria">Auditoría reciente</a>
<a href="${pageContext.request.contextPath}/administrador/en-vivo.jsp">Control en vivo</a>
<a href="${pageContext.request.contextPath}/administrador/catalogos.jsp" data-nav="catalogos">Ligas y participantes</a>
<a href="${pageContext.request.contextPath}/administrador/eventos.jsp" data-nav="eventos">Administrar eventos</a>
<a href="${pageContext.request.contextPath}/administrador/mercados.jsp" data-nav="mercados">Mercados y cuotas</a>
<a href="${pageContext.request.contextPath}/administrador/resultados.jsp" data-nav="resultados">Resultados</a>
<a href="${pageContext.request.contextPath}/administrador/liquidaciones.jsp" data-nav="liquidaciones">Liquidaciones</a><a href="${pageContext.request.contextPath}/administrador/usuarios.jsp">Administración de usuarios</a></nav><form id="admin-logout" action="${pageContext.request.contextPath}/administrador/logout" method="post"><button type="submit">Cerrar sesión</button></form><p id="logout-status" role="status"></p></aside>
<main id="contenido" class="workspace">
<header class="page-header"><div><p class="eyebrow">ADMINISTRACIÓN DEPORTIVA</p><h1>Resultados deportivos</h1><p class="muted">Registro, resolución, oficialización y revisión de resultados.</p></div></header>
<p class="muted">Registrar, resolver y oficializar: ADMINISTRADOR u OPERADOR_EVENTOS. Corregir y anular: solo ADMINISTRADOR. El servidor valida cada operación.</p>
<p id="management-status" class="live-status" role="status" aria-live="polite">Selecciona una consulta o completa un formulario.</p>
<a id="management-login" href="${pageContext.request.contextPath}/administrador/login" hidden>Volver a iniciar sesión</a>
<button id="acknowledge-write" type="button" class="critical" hidden>Ya comprobé el resultado; habilitar formularios</button>
<section class="panel" aria-labelledby="query-title"><h2 id="query-title">1. Selecciona un evento</h2>
<form id="browse-form" class="toolbar"><label for="browse-sport">Deporte<select id="browse-sport" name="idDeporte" required><option value="">Carga los deportes disponibles</option></select></label><button type="submit">Consultar eventos</button></form>
<button id="load-sports" type="button">Consultar deportes activos</button>
<div id="browse-results" class="management-results"></div>
<details class="advanced-reference"><summary>Consultar un evento por ID real (avanzado)</summary><form id="detail-form" class="toolbar"><label for="detail-id">ID real del evento<input id="detail-id" name="idEvento" type="number" min="1" max="2147483647" step="1" required></label><button type="submit">Consultar / actualizar evento</button></form>
</details><div class="toolbar"><a id="selected-live" hidden>Control en vivo del evento</a><a id="selected-markets" hidden>Mercados del evento</a></div>
<p class="muted">La exploración puede omitir datos no publicados. Un listado vacío no confirma que no existan registros administrativos.</p>
<div id="detail-results" class="management-results"></div>
</section>
<section id="operation-result" class="panel" hidden aria-labelledby="result-title"><h2 id="result-title">Respuesta oficial de la operación</h2><div id="operation-values"></div></section>
<p class="warning">Terminar un evento no oficializa su resultado. La resolución manual no determina ganadores en el navegador; el backend valida CONVENCIONAL, MARCADOR_FINAL y PRIMERA_ANOTACION.</p><p class="muted">La consulta pública no incluye el ID administrativo del resultado. Usa el ID real devuelto al registrar o proporcionado por administración para resultados anteriores.</p><p id="result-context" class="muted" role="status">Consulta un evento para trabajar con sus resultados. El ID de un resultado previo puede introducirse manualmente si no está disponible.</p><section class="panel"><h2>2. Elige una operación</h2><p id="management-selection" class="muted" role="status">Selecciona un evento de la tabla para trabajar con sus datos oficiales.</p><nav id="management-flow" class="operation-nav" aria-label="Operaciones del registro seleccionado"></nav></section><div id="management-forms" class="management-grid connected-forms"></div>
<noscript>Activa JavaScript para consultar y operar estos módulos.</noscript>
</main></body></html>





