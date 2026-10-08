(() => {
    "use strict";
    const contextPath = window.APP_CONTEXT_PATH || "";
    const statusPanel = document.getElementById("estado-detalle");
    const statusText = document.getElementById("mensaje-detalle");
    const retry = document.getElementById("reintentar-detalle");
    const login = document.getElementById("login-detalle");
    const content = document.getElementById("datos-detalle");
    const validId = value => Number.isInteger(value) && value > 0 && value <= 2147483647;
    const text = value => typeof value === "string" && value.trim() ? value : null;
    const decimal = value => typeof value === "number" && Number.isFinite(value);
    const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
    const label = value => text(value) ? value.replace(/_/g, " ") : "No disponible";
    const params = new URLSearchParams(window.location.search);
    const ids = params.getAll("idEvento");
    const rawId = ids.length === 1 ? ids[0] : "";
    const idEvento = /^\d+$/.test(rawId) && validId(Number(rawId)) ? Number(rawId) : null;
    let loading = false;

    function node(tag, className, value) {
        const element = document.createElement(tag);
        if (className) element.className = className;
        if (value !== undefined) element.textContent = value;
        return element;
    }
    // El backend entrega LocalDateTime sin zona horaria: no se convierte la hora.
    function fecha(value) {
        const match = typeof value === "string" && /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::\d{2}(?:\.\d+)?)?$/.exec(value);
        return match ? `${match[3]}/${match[2]}/${match[1]} · ${match[4]}:${match[5]}` : "No disponible";
    }
    function fact(list, title, value) {
        const item = node("div");
        item.append(node("dt", "", title), node("dd", "", value));
        list.append(item);
    }
    function estado(message, busy = false, canRetry = false, needsLogin = false) {
        content.hidden = true;
        statusPanel.hidden = false;
        statusPanel.setAttribute("aria-busy", String(busy));
        statusPanel.classList.toggle("is-loading", busy);
        statusPanel.classList.toggle("is-error", !busy);
        statusText.textContent = message;
        retry.hidden = !canRetry;
        login.hidden = !needsLogin;
    }
    function fallo(message, needsLogin = false) { const error = new Error(message); error.needsLogin = needsLogin; return error; }

    async function consultar() {
        const controller = new AbortController();
        let timedOut = false;
        const timeout = window.setTimeout(() => { timedOut = true; controller.abort(); }, 15000);
        try {
            const query = new URLSearchParams({ idEvento: String(idEvento) });
            const response = await fetch(contextPath + "/eventos/exploracion/detalle?" + query.toString(), {
                method: "GET", credentials: "same-origin", cache: "no-store", headers: { Accept: "application/json" }, signal: controller.signal
            });
            if (response.status === 401) throw fallo("Tu sesión no está disponible o ha expirado. Inicia sesión para continuar.", true);
            if (response.redirected) {
                const target = new URL(response.url, window.location.href);
                if (target.pathname === contextPath + "/usuario/login" || target.pathname === contextPath + "/usuario/login.jsp") throw fallo("Tu sesión ha expirado. Inicia sesión para continuar.", true);
                throw fallo("El servidor redirigió la consulta a una respuesta inesperada.");
            }
            if (!response.ok) {
                const messages = {
                    400: "No se pudo consultar el evento con los datos proporcionados.",
                    403: "No tienes permiso para consultar este evento.",
                    404: "El evento solicitado no existe o ya no está disponible.",
                    409: "La información del evento cambió. Vuelve a consultar.",
                    500: "El servidor no pudo cargar el evento. Intenta nuevamente."
                };
                throw fallo(messages[response.status] || "No fue posible consultar el evento. Intenta nuevamente.");
            }
            const type = (response.headers.get("content-type") || "").split(";")[0].trim().toLowerCase();
            if (type !== "application/json") throw fallo("Se esperaba JSON y se recibió otra respuesta. Si tu sesión expiró, vuelve a iniciar sesión.", type === "text/html");
            let data;
            try { data = await response.json(); }
            catch (error) { if (controller.signal.aborted) throw error; throw fallo("La respuesta JSON no es válida. Intenta nuevamente."); }
            if (!object(data) || data.ok !== true || !object(data.evento) || data.evento.idEvento !== idEvento
                    || !Array.isArray(data.evento.participantes) || !Array.isArray(data.evento.mercados)
                    || data.evento.participantes.some(item => !object(item))
                    || data.evento.mercados.some(item => !object(item) || !validId(item.idMercado) || !Array.isArray(item.selecciones) || item.selecciones.some(selection => !object(selection)))) {
                throw fallo("El servidor devolvió un detalle de evento incompleto o inesperado.");
            }
            return data.evento;
        } catch (error) {
            if (timedOut) throw fallo("La consulta tardó demasiado. Vuelve a intentar.");
            if (error instanceof TypeError) throw fallo("No se pudo conectar con el servidor. Revisa tu conexión e intenta nuevamente.");
            if (error.name === "AbortError") throw fallo("La consulta se interrumpió. Vuelve a intentar.");
            throw error;
        } finally { window.clearTimeout(timeout); }
    }

    function participante(item) {
        const card = node("article", "participant");
        card.append(node("h3", "", text(item.participante) || "Nombre no disponible"));
        if (Number.isInteger(item.ordenParticipante)) card.append(node("p", "", "Orden: " + item.ordenParticipante));
        if (item.esLocal === true || item.esLocal === false) card.append(node("p", "", item.esLocal ? "Local" : "Visitante"));
        if (text(item.tipoParticipante)) card.append(node("p", "", label(item.tipoParticipante)));
        if (text(item.pais)) card.append(node("p", "", item.pais));
        return card;
    }
    function seleccion(item, event) {
        // Solo habilita la navegación cuando el servidor informa disponibilidad.
        // No calcula vigencia ni autorización personal en el cliente.
        const available = item.puedeSeleccionar === true && event.puedeApostar === true
                && item.seleccionActiva === true && item.cuotaActiva === true
                && validId(item.idSeleccion) && validId(item.idCuota) && decimal(item.cuota) && item.cuota > 0;
        const card = node("article", "selection" + (available ? "" : " is-unavailable"));
        card.append(node("h4", "", text(item.seleccion) || "Selección sin nombre disponible"), node("p", "odd-label", "CUOTA"),
                node("p", "odd", decimal(item.cuota) ? String(item.cuota) : "No disponible"),
                node("p", "selection-status", available ? "Disponible para seleccionar" : "No disponible para seleccionar"));
        const facts = node("dl", "selection-facts");
        if (decimal(item.probabilidadImplicitaPorcentaje)) fact(facts, "Probabilidad implícita informada", String(item.probabilidadImplicitaPorcentaje) + " %");
        if (text(item.fechaInicioCuota)) fact(facts, "Inicio de vigencia", fecha(item.fechaInicioCuota));
        if (text(item.fechaFinCuota)) fact(facts, "Fin de vigencia", fecha(item.fechaFinCuota));
        if (text(item.resultadoSeleccion)) fact(facts, "Resultado", label(item.resultadoSeleccion));
        if (text(item.fechaResolucion)) fact(facts, "Resolución", fecha(item.fechaResolucion));
        card.append(facts);
        const action = node(available ? "a" : "button", "selection-action", available ? "Seleccionar cuota ↗" : "No disponible");
        if (available) {
            action.href = contextPath + "/apuestas/realizar-apuesta.jsp?idSeleccion=" + encodeURIComponent(item.idSeleccion);
            action.setAttribute("aria-label", "Seleccionar cuota: " + (text(item.seleccion) || item.idSeleccion));
        } else { action.type = "button"; action.disabled = true; }
        card.append(action);
        return card;
    }
    function mercado(item, event) {
        const card = node("article", "panel market");
        const heading = node("div", "market-heading");
        const title = node("div");
        title.append(node("h3", "", text(item.mercado) || "Mercado sin nombre disponible"));
        if (text(item.descripcionMercado)) title.append(node("p", "market-description", item.descripcionMercado));
        heading.append(title, node("span", "status-badge", label(item.estadoMercado)));
        card.append(heading);
        const grid = node("div", "selections-grid");
        if (!item.selecciones.length) grid.append(node("p", "empty-state", "Este mercado no tiene selecciones disponibles para mostrar."));
        else item.selecciones.forEach(itemSelection => grid.append(seleccion(itemSelection, event)));
        card.append(grid);
        return card;
    }
    function render(event) {
        document.getElementById("nombre-evento").textContent = text(event.nombre) || "Nombre del evento no disponible";
        document.getElementById("categoria-evento").textContent = [text(event.deporte), text(event.liga)].filter(Boolean).join(" / ") || "Deporte y liga no disponibles";
        document.getElementById("estado-visual").textContent = label(event.estadoVisual);
        const facts = node("dl");
        fact(facts, "Inicio", fecha(event.fechaInicio));
        fact(facts, "Cierre de apuestas", fecha(event.fechaCierreApuestas));
        fact(facts, "Estado del evento", label(event.estadoEvento));
        if (text(event.fechaFin)) fact(facts, "Fin", fecha(event.fechaFin));
        if (text(event.resultadoTexto)) fact(facts, "Resultado informado", event.resultadoTexto);
        if (text(event.estadoResultado)) fact(facts, "Estado del resultado", label(event.estadoResultado));
        document.getElementById("ficha-evento").replaceChildren(...facts.children);
        const availability = document.getElementById("disponibilidad-evento");
        availability.textContent = event.puedeApostar === true ? "El servidor informa que el evento admite apuestas." : event.puedeApostar === false ? "El evento no está disponible para apostar." : "Disponibilidad del evento no informada.";
        availability.classList.toggle("is-open", event.puedeApostar === true);
        const participants = document.createDocumentFragment();
        if (!event.participantes.length) participants.append(node("p", "empty-state", "Este evento no tiene participantes informados."));
        else event.participantes.forEach(item => participants.append(participante(item)));
        document.getElementById("participantes").replaceChildren(participants);
        const markets = document.createDocumentFragment();
        if (!event.mercados.length) markets.append(node("p", "panel empty-state", "Este evento no tiene mercados informados."));
        else event.mercados.forEach(item => markets.append(mercado(item, event)));
        document.getElementById("mercados").replaceChildren(markets);
    }
    async function cargar() {
        if (loading) return;
        loading = true;
        estado("Cargando evento…", true);
        try {
            render(await consultar());
            statusPanel.setAttribute("aria-busy", "false");
            statusPanel.classList.remove("is-loading");
            statusPanel.hidden = true;
            content.hidden = false;
        } catch (error) { estado(error.message || "No fue posible cargar el evento.", false, true, error.needsLogin === true); }
        finally { loading = false; }
    }
    retry.addEventListener("click", cargar);
    if (idEvento === null) estado("El identificador del evento falta o no es un entero positivo válido. Vuelve al listado para elegir un evento.");
    else cargar();
})();
