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
<title>Ligas y participantes — BetZone Admin</title>
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/admin.css">
<script src="${pageContext.request.contextPath}/js/admin-api.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin-gestion.js" defer></script>
</head><body data-admin-role="<%= adminRoleForView %>" data-context-path="${pageContext.request.contextPath}" data-management="catalogos">
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
<header class="page-header"><div><p class="eyebrow">ADMINISTRACIÓN DEPORTIVA</p><h1>Ligas y participantes</h1><p class="muted">Selecciona deportes, ligas y participantes por nombre.</p></div></header>
<p class="muted">Las operaciones requieren ADMINISTRADOR u OPERADOR_EVENTOS. El servidor valida permisos, estados y datos oficiales.</p>
<p id="management-status" class="live-status" role="status" aria-live="polite">Selecciona una consulta o completa un formulario.</p>
<a id="management-login" href="${pageContext.request.contextPath}/administrador/login" hidden>Volver a iniciar sesión</a>
<button id="acknowledge-write" type="button" class="critical" hidden>Ya comprobé el resultado; habilitar formularios</button>
<section class="panel" aria-labelledby="query-title"><h2 id="query-title">Consultar información disponible</h2>
<form id="browse-form" class="toolbar"><label for="browse-sport">Deporte<select id="browse-sport" name="idDeporte" required><option value="">Carga los deportes disponibles</option></select></label><button type="submit">Consultar ligas</button></form>
<button id="load-sports" type="button">Consultar deportes activos</button>
<div id="browse-results" class="management-results"></div>
<p class="muted">Los participantes se consultan por deporte y los países se cargan desde el catálogo. País vacío elimina la asociación.</p>
</section>
<section id="operation-result" class="panel" hidden aria-labelledby="result-title"><h2 id="result-title">Respuesta oficial de la operación</h2><div id="operation-values"></div></section>
<div id="management-forms" class="management-grid"></div>
<noscript>Activa JavaScript para consultar y operar estos módulos.</noscript>
</main></body></html>


