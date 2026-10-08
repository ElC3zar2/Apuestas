(() => {
    "use strict";
    const contextPath = window.APP_CONTEXT_PATH || "";
    const sportSelect = document.getElementById("deporte");
    const sportsStatus = document.getElementById("deportes-status");
    const sportsRetry = document.getElementById("reintentar-deportes");
    const views = document.getElementById("vistas");
    const results = document.getElementById("resultados");
    const state = document.getElementById("estado-eventos");
    const eventsStatus = document.getElementById("eventos-status");
    const eventsRetry = document.getElementById("reintentar-eventos");
    const list = document.getElementById("lista-eventos");
    const count = document.getElementById("cantidad-eventos");
    let eventsController;
    let requestVersion = 0;
    let sportsLoading = false;

    const validId = value => Number.isSafeInteger(value) && value > 0;
    const text = value => typeof value === "string" && value.trim() ? value : null;
    const validCount = value => Number.isSafeInteger(value) && value >= 0;
    function node(tag, className, content) {
        const element = document.createElement(tag);
        if (className) element.className = className;
        if (content !== undefined) element.textContent = content;
        return element;
    }

    async function consultar(ruta, controller) {
        let timedOut = false;
        const timeout = window.setTimeout(() => { timedOut = true; controller.abort(); }, 15000);
        try {
            const response = await fetch(contextPath + ruta, {
                method: "GET", credentials: "same-origin", cache: "no-store",
                headers: { Accept: "application/json" }, signal: controller.signal
            });
            if (response.redirected || response.status === 401) throw new Error("No se pudo completar la consulta con tu sesión actual. Vuelve a iniciar sesión si ha expirado.");
            if (!response.ok) throw new Error("El servidor no pudo completar la consulta. Intenta nuevamente.");
            if (!(response.headers.get("content-type") || "").toLowerCase().includes("application/json")) throw new Error("El servidor devolvió una respuesta inesperada. No se recibieron datos JSON.");
            let data;
            try { data = await response.json(); }
            catch (error) {
                if (controller.signal.aborted) throw error;
                throw new Error("La respuesta JSON del servidor no es válida. Intenta nuevamente.");
            }
            if (!data || typeof data !== "object" || Array.isArray(data) || data.ok !== true) throw new Error("La respuesta del servidor no contiene un resultado válido.");
            return data;
        } catch (error) {
            if (timedOut) throw new Error("La consulta está tardando demasiado. Intenta nuevamente.");
            if (error instanceof TypeError) throw new Error("No se pudo conectar con el servidor. Revisa tu conexión e intenta nuevamente.");
            throw error;
        } finally { window.clearTimeout(timeout); }
    }

    function estadoEventos(message, loading = false, error = false) {
        list.replaceChildren();
        count.textContent = "";
        state.hidden = false;
        state.classList.toggle("is-loading", loading);
        state.classList.toggle("is-error", error);
        eventsStatus.textContent = message;
        eventsRetry.hidden = !error;
        results.setAttribute("aria-busy", String(loading));
    }

    // LocalDateTime llega sin zona horaria: se conserva la fecha del servidor,
    // sin convertirla a la zona del navegador ni añadir una zona supuesta.
    function fecha(value) {
        if (!text(value)) return "No disponible";
        const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::\d{2}(?:\.\d+)?)?$/.exec(value);
        return match ? `${match[3]}/${match[2]}/${match[1]} · ${match[4]}:${match[5]}` : "No disponible";
    }
    function tarjeta(event) {
        const card = node("article", "panel event-card");
        const top = node("div", "event-topline");
        const category = [text(event.deporte), text(event.liga)].filter(Boolean).join(" / ");
        top.append(node("p", "event-category", category || "Deporte / liga no disponibles"));
        const visual = text(event.estadoVisual) || text(event.estadoEvento);
        top.append(node("span", "event-badge" + (event.estadoVisual === "EN_PROGRESO" ? " is-live" : ""), visual ? visual.replace(/_/g, " ") : "Estado no disponible"));
        card.append(top, node("h3", "", text(event.evento) || "Evento sin nombre disponible"));
        const participants = [text(event.participante1), text(event.participante2)].filter(Boolean);
        if (participants.length) card.append(node("p", "event-participants", participants.join(" · ")));
        const facts = node("dl", "event-facts");
        const entries = [
            ["Inicio", fecha(event.fechaInicio)],
            ["Cierre de apuestas", fecha(event.fechaCierreApuestas)],
            ["Mercados abiertos", validCount(event.mercadosAbiertos) ? String(event.mercadosAbiertos) : "No disponible"],
            ["Selecciones disponibles", validCount(event.seleccionesDisponibles) ? String(event.seleccionesDisponibles) : "No disponible"]
        ];
        for (const [label, value] of entries) { const item = node("div"); item.append(node("dt", "", label), node("dd", "", value)); facts.append(item); }
        const footer = node("div", "event-footer");
        const availability = event.puedeApostar === true ? "Evento abierto para apuestas" : event.puedeApostar === false ? "Evento no disponible para apostar" : "Disponibilidad no informada";
        const link = node("a", "event-link", "Ver evento ↗");
        link.href = contextPath + "/eventos/detalle-evento.jsp?idEvento=" + encodeURIComponent(event.idEvento);
        link.setAttribute("aria-label", "Ver evento: " + (text(event.evento) || event.idEvento));
        footer.append(node("span", "availability" + (event.puedeApostar === true ? " is-open" : ""), availability), link);
        card.append(facts, footer);
        return card;
    }

    async function cargarEventos() {
        if (eventsController) eventsController.abort();
        const version = ++requestVersion;
        if (!sportSelect.value) { estadoEventos("Selecciona un deporte para explorar sus eventos."); return; }
        const controller = new AbortController();
        eventsController = controller;
        const vista = views.querySelector("input:checked").value;
        const params = new URLSearchParams({ idDeporte: sportSelect.value, vista, cantidad: "100", horasPrevia: "24" });
        estadoEventos("Cargando eventos…", true);
        try {
            const data = await consultar("/eventos/exploracion?" + params.toString(), controller);
            if (version !== requestVersion) return;
            if (!Array.isArray(data.eventos) || !validCount(data.cantidad) || data.cantidad !== data.eventos.length
                    || data.eventos.some(event => !event || !validId(event.idEvento))) throw new Error("El servidor devolvió un listado de eventos inválido.");
            if (!data.eventos.length) { estadoEventos("No hay eventos para este deporte y esta vista. Prueba con otro filtro."); return; }
            const fragment = document.createDocumentFragment();
            data.eventos.forEach(event => fragment.append(tarjeta(event)));
            list.replaceChildren(fragment);
            state.hidden = true;
            count.textContent = `${data.eventos.length} eventos mostrados · máximo 100`;
            eventsStatus.textContent = `${data.eventos.length} eventos cargados.`;
        } catch (error) {
            if (version !== requestVersion || error.name === "AbortError") return;
            estadoEventos(error.message || "No fue posible cargar los eventos.", false, true);
        } finally { if (version === requestVersion) results.setAttribute("aria-busy", "false"); }
    }

    async function cargarDeportes() {
        if (sportsLoading) return;
        sportsLoading = true;
        sportSelect.disabled = true;
        views.disabled = true;
        sportsRetry.hidden = true;
        sportsStatus.classList.remove("is-error");
        sportsStatus.textContent = "Cargando deportes…";
        try {
            const data = await consultar("/deportes/exploracion", new AbortController());
            if (!Array.isArray(data.deportes) || !validCount(data.cantidad) || data.cantidad !== data.deportes.length
                    || data.deportes.some(sport => !sport || !validId(sport.idDeporte) || !text(sport.nombre) || typeof sport.activo !== "boolean")) throw new Error("El servidor devolvió un catálogo de deportes inválido.");
            const sports = data.deportes.filter(sport => sport.activo);
            sportSelect.replaceChildren(node("option", "", sports.length ? "Selecciona un deporte" : "Sin deportes disponibles"));
            sportSelect.firstChild.value = "";
            for (const sport of sports) { const option = node("option", "", sport.nombre); option.value = String(sport.idDeporte); sportSelect.append(option); }
            sportSelect.disabled = !sports.length;
            sportsStatus.textContent = sports.length ? "Selecciona un deporte. Previa muestra los eventos de las próximas 24 horas." : "No hay deportes activos disponibles.";
            if (!sports.length) { sportsRetry.hidden = false; estadoEventos("No hay deportes activos para consultar eventos."); }
        } catch (error) {
            sportsStatus.textContent = error.message || "No fue posible cargar los deportes.";
            sportsStatus.classList.add("is-error");
            sportSelect.replaceChildren(node("option", "", "Deportes no disponibles"));
            sportSelect.firstChild.value = "";
            sportsRetry.hidden = false;
            estadoEventos("Los eventos estarán disponibles cuando se cargue el catálogo de deportes.");
        } finally { sportsLoading = false; }
    }

    sportSelect.addEventListener("change", () => { views.disabled = !sportSelect.value; cargarEventos(); });
    views.addEventListener("change", cargarEventos);
    sportsRetry.addEventListener("click", cargarDeportes);
    eventsRetry.addEventListener("click", cargarEventos);
    cargarDeportes();
})();
