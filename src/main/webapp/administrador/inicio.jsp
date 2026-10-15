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

<%!
private String seguro(Object v) {
    return v == null ? "No disponible" : v.toString().replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
}
%>
<!DOCTYPE html>
<html lang="es"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dashboard — BetZone Admin</title>
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/admin.css">
<script src="${pageContext.request.contextPath}/js/admin-api.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin.js" defer></script>
</head>
<body data-admin-role="<%= adminRoleForView %>" data-context-path="${pageContext.request.contextPath}">
<a class="skip-link" href="#contenido">Ir al contenido</a>
<aside class="sidebar">
<a class="brand" href="${pageContext.request.contextPath}/administrador/inicio">BetZone <span>ADMIN</span></a>
<p class="eyebrow">CENTRO DE OPERACIONES</p>
<nav aria-label="Navegación administrativa">
<a href="#resumen" aria-current="location">Resumen</a><a href="#finanzas">Finanzas</a><a href="#deportes">Deportes</a><a href="#auditoria">Auditoría reciente</a><a href="${pageContext.request.contextPath}/administrador/en-vivo">Control en vivo</a>
<a href="${pageContext.request.contextPath}/administrador/catalogos">Ligas y participantes</a>
<a href="${pageContext.request.contextPath}/administrador/eventos">Administrar eventos</a>
<a href="${pageContext.request.contextPath}/administrador/mercados">Mercados y cuotas</a><a href="${pageContext.request.contextPath}/administrador/resultados" data-nav="resultados">Resultados</a>
<a href="${pageContext.request.contextPath}/administrador/liquidaciones" data-nav="liquidaciones">Liquidaciones</a><a href="${pageContext.request.contextPath}/administrador/usuarios">Administración de usuarios</a></nav>
<div class="identity"><p><%= seguro(request.getSession(false).getAttribute("adminCorreo")) %></p><small><%= seguro(request.getSession(false).getAttribute("adminRol")) %></small></div>
<form id="admin-logout" action="${pageContext.request.contextPath}/administrador/logout" method="post"><button type="submit">Cerrar sesión</button></form>
<p id="logout-status" role="status"></p>
</aside>
<main id="contenido" class="workspace">
<header class="page-header"><div><p class="eyebrow">BETZONE ADMIN</p><h1>Dashboard</h1><p class="muted">Actividad y resultados de la operación.</p></div><a href="${pageContext.request.contextPath}/administrador/inicio">Inicio administrativo ↗</a></header>
<form id="dashboard-filters" class="toolbar">
<label for="horas">Ventana previa <select id="horas" name="horasPrevia"><option value="24">24 horas</option><option value="48">48 horas</option><option value="72">72 horas</option></select></label>
<label for="cantidad">Registros de auditoría <select id="cantidad" name="cantidadAuditoria"><option value="10">10</option><option value="25" selected>25</option><option value="50">50</option><option value="100">100</option></select></label>
<button class="primary" type="submit">Actualizar</button></form>
<p id="dashboard-status" role="status" aria-live="polite">Cargando resumen…</p>
<a id="session-login" href="${pageContext.request.contextPath}/administrador/login" hidden>Volver a iniciar sesión</a>
<div id="dashboard-data" aria-busy="true">
<section id="resumen"><h2>Resumen de actividad</h2><dl class="metrics">
<div><dt>Clientes registrados</dt><dd data-metric="clientesRegistrados">—</dd></div>
<div><dt>Clientes activos</dt><dd data-metric="clientesActivos">—</dd></div>
<div><dt>Eventos totales</dt><dd data-metric="eventosTotales">—</dd></div>
<div><dt>Eventos en progreso</dt><dd data-metric="eventosEnProgreso">—</dd></div>
<div><dt>Pendientes de resultado</dt><dd data-metric="eventosPendienteResultado">—</dd></div>
<div><dt>Boletos totales</dt><dd data-metric="boletosTotales">—</dd></div>
<div><dt>Boletos pendientes</dt><dd data-metric="boletosPendientes">—</dd></div>
<div><dt>Acciones de auditoría · 24 h</dt><dd data-metric="accionesAuditoriaUltimas24Horas">—</dd></div>
</dl></section>
<section id="finanzas"><h2>Finanzas de la casa</h2><dl class="metrics">
<div><dt>Total apostado histórico</dt><dd data-money="totalApostadoHistorico">—</dd></div>
<div><dt>Comisiones realizadas</dt><dd data-money="comisionesRealizadas">—</dd></div>
<div><dt>Premios pagados</dt><dd data-money="premiosPagados">—</dd></div>
<div><dt>Resultado realizado</dt><dd data-money="resultadoCasaRealizado">—</dd></div>
<div><dt>Monto apostado pendiente</dt><dd data-money="montoApostadoPendiente">—</dd></div>
<div><dt>Exposición potencial</dt><dd data-money="exposicionPotencialCasa">—</dd></div>
</dl></section>
<section id="deportes" class="panel"><h2>Actividad por deporte</h2><p class="muted">Los boletos relacionados pueden aparecer en más de un deporte; no deben sumarse.</p><div class="table-scroll"><table><caption>Eventos y apuestas por deporte</caption><thead><tr><th scope="col">Deporte</th><th scope="col">Eventos</th><th scope="col">En progreso</th><th scope="col">Boletos relacionados</th><th scope="col">Monto relacionado</th></tr></thead><tbody id="sports-body"></tbody></table></div></section>
<section id="auditoria" class="panel"><h2>Auditoría reciente</h2><div class="table-scroll"><table><caption>Últimas acciones registradas</caption><thead><tr><th scope="col">Fecha</th><th scope="col">Usuario</th><th scope="col">Acción</th><th scope="col">Tabla</th><th scope="col">Registro</th></tr></thead><tbody id="audit-body"></tbody></table></div></section>
</div><noscript>Activa JavaScript para consultar los datos del dashboard.</noscript>
</main></body></html>




