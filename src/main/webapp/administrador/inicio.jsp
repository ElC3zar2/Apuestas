<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"%>
<%
    String adminRoleForView = "";
    Object adminCorreoForView = null;
    try {
        javax.servlet.http.HttpSession adminViewSession = request.getSession(false);
        Object adminViewRole = adminViewSession == null ? null : adminViewSession.getAttribute("adminRol");
        adminCorreoForView = adminViewSession == null ? null : adminViewSession.getAttribute("adminCorreo");
        for (String allowedRole : new String[]{"ADMINISTRADOR","OPERADOR_EVENTOS","CAJERO","AUDITOR"})
            if (allowedRole.equals(adminViewRole)) adminRoleForView = allowedRole;
    } catch (IllegalStateException expiredSession) { adminRoleForView = ""; adminCorreoForView = null; }
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
<div class="identity"><p><%= seguro(adminCorreoForView) %></p><small><%= seguro(adminRoleForView) %></small></div>
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
</dl><details><summary>Más indicadores de eventos y boletos</summary><dl class="metrics">
<div><dt>Eventos programados</dt><dd data-metric="eventosProgramados">—</dd></div>
<div><dt>Eventos en previa</dt><dd data-metric="eventosPrevia">—</dd></div>
<div><dt>Eventos finalizados</dt><dd data-metric="eventosFinalizados">—</dd></div>
<div><dt>Boletos ganadores</dt><dd data-metric="boletosGanadores">—</dd></div>
<div><dt>Boletos perdedores</dt><dd data-metric="boletosPerdedores">—</dd></div>
<div><dt>Boletos anulados</dt><dd data-metric="boletosAnulados">—</dd></div>
</dl></details></section>
<section id="finanzas"><h2>Finanzas de la casa</h2><dl class="metrics">
<div><dt>Total apostado histórico</dt><dd data-money="totalApostadoHistorico">—</dd></div>
<div><dt>Comisiones realizadas</dt><dd data-money="comisionesRealizadas">—</dd></div>
<div><dt>Premios pagados</dt><dd data-money="premiosPagados">—</dd></div>
<div><dt>Resultado realizado</dt><dd data-money="resultadoCasaRealizado">—</dd></div>
<div><dt>Monto apostado pendiente</dt><dd data-money="montoApostadoPendiente">—</dd></div>
<div><dt>Exposición potencial</dt><dd data-money="exposicionPotencialCasa">—</dd></div>
</dl><p class="muted">Importes oficiales en GTQ. El resultado realizado puede ser negativo. La exposición corresponde a boletos pendientes y no es una pérdida confirmada; los premios potenciales no son premios pagados.</p>
<details><summary>Detalle de comisiones y premios pendientes</summary><dl class="metrics">
<div><dt>Comisiones históricas</dt><dd data-money="comisionesHistoricas">—</dd></div>
<div><dt>Comisiones pendientes</dt><dd data-money="comisionesPendientes">—</dd></div>
<div><dt>Comisiones devueltas</dt><dd data-money="comisionesDevueltas">—</dd></div>
<div><dt>Ganancia por apuestas perdidas</dt><dd data-money="gananciaCasaPorApuestasPerdidas">—</dd></div>
<div><dt>Premios potenciales pendientes</dt><dd data-money="premioPotencialPendiente">—</dd></div>
</dl></details><p class="muted">Las comisiones realizadas corresponden a boletos ganadores o perdedores. Estos indicadores se consultan por separado y no deben sumarse como categorías independientes.</p>
<details><summary>Consultar conciliación de billeteras CASA</summary><p class="muted">Lectura global recibida con el resumen; no depende del filtro por evento. Se destacan diferencias o reservas fuera de pendiente reportadas. Esta vista no ajusta saldos ni confirma una conciliación contable.</p>
<div class="table-scroll"><table><caption>Conciliación CASA — valores oficiales en GTQ</caption><thead><tr><th scope="col">Referencia de billetera</th><th scope="col">Saldo disponible</th><th scope="col">Saldo comprometido</th><th scope="col">Reservas de boletos</th><th scope="col">Diferencia</th><th scope="col">Reservas fuera de pendiente</th></tr></thead><tbody id="house-body"></tbody></table></div></details></section>
<section id="deportes" class="panel"><h2>Actividad por deporte</h2><p class="muted">Los boletos relacionados pueden aparecer en más de un deporte; no deben sumarse. Los importes relacionados tampoco representan totales únicos entre deportes.</p><div class="table-scroll"><table><caption>Eventos y apuestas por deporte — importes en GTQ</caption><thead><tr><th scope="col">Deporte</th><th scope="col">Eventos</th><th scope="col">En progreso</th><th scope="col">Boletos relacionados</th><th scope="col">Clientes únicos</th><th scope="col">Boletos pendientes</th><th scope="col">Monto relacionado</th><th scope="col">Premio potencial pendiente</th></tr></thead><tbody id="sports-body"></tbody></table></div>
<a href="#analitica-eventos">Consultar actividad por evento</a></section>
<section id="auditoria" class="panel"><h2>Auditoría reciente</h2><div class="table-scroll"><table><caption>Últimas acciones registradas</caption><thead><tr><th scope="col">Fecha</th><th scope="col">Usuario</th><th scope="col">Acción</th><th scope="col">Tabla</th><th scope="col">Registro</th></tr></thead><tbody id="audit-body"></tbody></table></div></section>
</div><noscript>Activa JavaScript para consultar los datos del dashboard.</noscript>
<section id="analitica-eventos" class="panel" aria-labelledby="analytics-title"><h2 id="analytics-title">Actividad por evento</h2>
<p class="muted">Consulta de solo lectura. Los boletos e importes relacionados pueden repetirse entre eventos y no deben sumarse como totales únicos.</p>
<form id="analytics-filters" class="toolbar">
<label for="analytics-sport">Deporte<select id="analytics-sport" name="idDeporte"><option value="">Todos los deportes</option></select></label>
<label for="analytics-view">Estado<select id="analytics-view" name="vista"><option value="TODOS">Todos</option><option value="PROGRAMADOS">Programados</option><option value="PREVIA">En previa</option><option value="EN_PROGRESO">En progreso</option><option value="PENDIENTE_RESULTADO">Pendientes de resultado</option><option value="FINALIZADOS">Finalizados</option><option value="BORRADOR">Borradores</option><option value="SUSPENDIDOS">Suspendidos</option><option value="CANCELADOS">Cancelados</option></select></label>
<label for="analytics-hours">Ventana de previa<select id="analytics-hours" name="horasPrevia"><option value="24">24 horas</option><option value="48">48 horas</option><option value="72">72 horas</option></select></label>
<label for="analytics-limit">Límite de eventos<select id="analytics-limit" name="cantidad"><option value="25">25</option><option value="50">50</option><option value="100" selected>100</option><option value="250">250</option><option value="500">500</option></select></label>
<button type="submit">Consultar eventos</button></form>
<p class="muted">El selector de deportes utiliza los nombres recibidos en el resumen. «Todos los deportes» consulta sin filtro de deporte. El límite no ofrece paginación ni un total general.</p>
<p id="analytics-status" role="status" aria-live="polite">Selecciona los filtros y consulta los eventos.</p>
<div id="analytics-data" aria-busy="false"><div class="table-scroll"><table><caption>Actividad de los eventos consultados — importes en GTQ</caption><thead><tr><th scope="col">Evento / liga / deporte</th><th scope="col">Estado oficial / visual</th><th scope="col">Inicio (hora del servidor)</th><th scope="col">Mercados abiertos / totales</th><th scope="col">Boletos relacionados</th><th scope="col">Clientes únicos</th><th scope="col">Monto relacionado</th><th scope="col">Premio potencial pendiente</th><th scope="col">Exposición potencial</th><th scope="col">Resultado realizado</th></tr></thead><tbody id="analytics-body"></tbody></table></div>
<details><summary>Modalidades de los eventos consultados</summary><p class="muted">Conteos oficiales por evento y modalidad. No determinan ganadores ni permiten crear mercados.</p><div class="table-scroll"><table><caption>Modalidades y clasificaciones de acierto oficiales</caption><thead><tr><th scope="col">Evento</th><th scope="col">Modalidad</th><th scope="col">Detalles</th><th scope="col">Marcadores exactos</th><th scope="col">Aciertos de resultado</th><th scope="col">Aciertos de primera anotación</th></tr></thead><tbody id="modalities-body"></tbody></table></div></details></div></section>
</main></body></html>




