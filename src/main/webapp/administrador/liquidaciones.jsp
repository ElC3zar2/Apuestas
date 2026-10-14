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
<script src="${pageContext.request.contextPath}/js/admin.js" defer></script>
<script src="${pageContext.request.contextPath}/js/admin-liquidaciones.js" defer></script>
</head><body data-context-path="${pageContext.request.contextPath}" data-admin-role="<%= adminRoleForView %>">
<a class="skip-link" href="#contenido">Ir al contenido</a>
<aside class="sidebar"><a class="brand" href="${pageContext.request.contextPath}/administrador/inicio.jsp">BetZone <span>ADMIN</span></a><p class="eyebrow">CENTRO DE OPERACIONES</p>
<nav aria-label="Navegación administrativa">
<a href="${pageContext.request.contextPath}/administrador/inicio.jsp#resumen">Resumen</a>
<a href="${pageContext.request.contextPath}/administrador/inicio.jsp#finanzas">Finanzas</a>
<a href="${pageContext.request.contextPath}/administrador/inicio.jsp#deportes">Deportes</a>
<a href="${pageContext.request.contextPath}/administrador/inicio.jsp#auditoria">Auditoría reciente</a>
<a href="${pageContext.request.contextPath}/administrador/en-vivo.jsp">Control en vivo</a>
<a href="${pageContext.request.contextPath}/administrador/catalogos.jsp">Ligas y participantes</a>
<a href="${pageContext.request.contextPath}/administrador/eventos.jsp">Administrar eventos</a>
<a href="${pageContext.request.contextPath}/administrador/mercados.jsp">Mercados y cuotas</a>
<a href="${pageContext.request.contextPath}/administrador/resultados.jsp">Resultados</a>
<a href="${pageContext.request.contextPath}/administrador/liquidaciones.jsp" aria-current="page">Liquidaciones</a>
<a href="${pageContext.request.contextPath}/administrador/usuarios.jsp">Administración de usuarios</a></nav><form id="admin-logout" action="${pageContext.request.contextPath}/administrador/logout" method="post"><button type="submit">Cerrar sesión</button></form><p id="logout-status" role="status"></p></aside>
<main id="contenido" class="workspace"><header class="page-header"><div><p class="eyebrow">OPERACIÓN FINANCIERA</p><h1>Liquidaciones</h1><p class="muted">Boletos y valores oficiales del servidor.</p></div></header>
<p class="muted">ADMINISTRADOR y CAJERO pueden listar y liquidar. AUDITOR puede consultar un boleto por ID. Las vistas y operaciones están protegidas por el servidor.</p>
<p id="settlement-status" class="live-status" role="status" aria-live="polite">Consulta un boleto o carga la lista de boletos listos.</p>
<a id="settlement-login" href="${pageContext.request.contextPath}/administrador/login" hidden>Volver a iniciar sesión</a>
<p id="uncertain-status" class="warning" role="status"></p>
<section id="ready-panel" class="panel"><h2>Boletos listos para liquidación</h2><form id="ready-form" class="toolbar"><label for="ready-count">Cantidad máxima<input id="ready-count" name="cantidad" type="number" min="1" max="500" step="1" value="100" required></label><button type="submit">Consultar / actualizar lista</button></form><div id="ready-results" class="management-results"></div></section>
<section class="panel"><h2>Consultar boleto por ID real</h2><form id="settlement-query" class="toolbar"><label for="ticket-id">ID del boleto<input id="ticket-id" name="idBoleto" type="number" min="1" max="2147483647" step="1" required></label><button type="submit">Consultar estado oficial</button></form><div id="ticket-results" class="management-results"></div></section>
<section id="settle-panel" class="panel"><h2>Liquidar boleto seleccionado</h2><p id="selected-ticket" class="muted">Selecciona un boleto de la lista oficial.</p><form id="settle-form" class="live-form"><button id="settle-button" class="critical" type="submit" disabled>Confirmar y liquidar</button></form><p class="warning">Ante una desconexión o respuesta incierta, consulta primero el mismo ID. No se reenvía ningún POST automáticamente. Una consulta fallida no desbloquea la operación.</p></section>
<section id="settlement-result" class="panel" hidden><h2>Respuesta oficial de liquidación</h2><div id="settlement-values" class="management-results"></div></section>
<noscript>Activa JavaScript para consultar y operar liquidaciones.</noscript></main></body></html>


