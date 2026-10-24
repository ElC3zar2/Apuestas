(() => {
    "use strict";
    const contextPath = window.APP_CONTEXT_PATH || "";
    const sportSelect = document.getElementById("deporte");
    const sportsStatus = document.getElementById("deportes-status");
    const sportsRetry = document.getElementById("reintentar-deportes");
    const leagueSelect = document.getElementById("liga");
    const leaguesStatus = document.getElementById("ligas-status");
    const leaguesRetry = document.getElementById("reintentar-ligas");
    const views = document.getElementById("vistas");
    const results = document.getElementById("resultados");
    const state = document.getElementById("estado-eventos");
    const eventsStatus = document.getElementById("eventos-status");
    const eventsRetry = document.getElementById("reintentar-eventos");
    const list = document.getElementById("lista-eventos");
    const count = document.getElementById("cantidad-eventos");
    const historyPanel = document.getElementById("apuestas-propias");
    const historyStatus = document.getElementById("apuestas-status");
    const historyRetry = document.getElementById("reintentar-apuestas");
    const historyLogin = document.getElementById("login-apuestas");
    let eventsController;
    let requestVersion = 0;
    let sportsLoading = false;
    let leaguesController;
    let leaguesVersion = 0;
    let activeLeagueIds = new Set();
    let loadedEvents = null;
    let historyController = null, historyVersion = 0, historyLoading = false, historyReady = false;
    let ownEvents = new Map(), ticketCount = 0, disposed = false;
    const cardCache = new Map();
    const visible = () => document.visibilityState !== "hidden";

    const validId = value => Number.isInteger(value) && value > 0 && value <= 2147483647;
    const selectedSport = () => /^\d+$/.test(sportSelect.value) && validId(Number(sportSelect.value)) ? Number(sportSelect.value) : null;
    const text = value => typeof value === "string" && value.trim() ? value : null;
    const validCount = value => Number.isSafeInteger(value) && value >= 0;
    function node(tag, className, content) {
        const element = document.createElement(tag);
        if (className) element.className = className;
        if (content !== undefined) element.textContent = content;
        return element;
    }

    function fallo(message, needsLogin = false) { const error = new Error(message); error.controlled = true; error.needsLogin = needsLogin; return error; }
    async function consultar(ruta, controller) {
        let timedOut = false;
        let timeout;
        let onAbort;
        try {
            const consulta = async () => {
                const response = await fetch(contextPath + ruta, {
                    method: "GET", credentials: "same-origin", cache: "no-store",
                    headers: { Accept: "application/json" }, signal: controller.signal
                });
                if (controller.signal.aborted) {
                    const error = fallo("La consulta se interrumpió."); error.name = "AbortError"; throw error;
                }
                let redirectedToLogin = false;
                if (response.redirected) {
                    const target = new URL(response.url, window.location.href);
                    redirectedToLogin = target.origin === new URL(window.location.href).origin
                        && [contextPath + "/usuario/login", contextPath + "/usuario/login.jsp"].includes(target.pathname);
                }
                if (response.status === 401 || redirectedToLogin) {
                    if (ruta !== "/usuario/boletos/historial") {
                        descartarHistorial();
                        historyStatus.textContent = "No se pudieron verificar tus apuestas. Tu sesión puede haber expirado; inicia sesión o reintenta.";
                        historyLogin.hidden = false; historyRetry.hidden = false;
                    }
                    throw fallo("No se pudo completar la consulta con tu sesión actual. Vuelve a iniciar sesión si ha expirado.",true);
                }
                if (response.redirected) throw fallo("La consulta fue redirigida a una respuesta inesperada.");
                if (!response.ok) {
                    if (response.status === 403 && ruta !== "/usuario/boletos/historial") {
                        descartarHistorial();
                        historyStatus.textContent = "No se pudieron verificar tus apuestas con los permisos actuales. Puedes reintentar la verificación.";
                        historyRetry.hidden = false; historyLogin.hidden = true;
                    }
                    const messages = {400: "Los parámetros de la consulta no son válidos.", 403: "No tienes permiso para realizar esta consulta.",
                        404: "La información solicitada no está disponible.", 500: "El servidor no pudo completar la consulta.", 503: "La consulta no está disponible temporalmente."};
                    throw fallo(messages[response.status] || "No fue posible completar la consulta. Intenta nuevamente.");
                }
                if (!/^application\/json\s*(?:;|$)/i.test(response.headers.get("content-type") || "")) throw fallo("El servidor devolvió una respuesta inesperada. No se recibieron datos JSON.");
                let data;
                try { data = await response.json(); }
                catch (error) {
                    if (controller.signal.aborted) throw error;
                    throw fallo("La respuesta JSON del servidor no es válida. Intenta nuevamente.");
                }
                if (!data || typeof data !== "object" || Array.isArray(data) || data.ok !== true) throw fallo("La respuesta del servidor no contiene un resultado válido.");
                return data;
            };
            const espera = new Promise((_, reject) => {
                timeout = window.setTimeout(() => {
                    timedOut = true;
                    reject(fallo("La consulta está tardando demasiado. Intenta nuevamente."));
                    controller.abort();
                }, 15000);
            });
            const cancelled = new Promise((_, reject)=>{
                onAbort = ()=>{ const error = fallo("La consulta se interrumpió."); error.name = "AbortError"; reject(error); };
                controller.signal.addEventListener("abort",onAbort,{once:true});
                if (controller.signal.aborted) onAbort();
            });
            return await Promise.race([consulta(), espera, cancelled]);
        } catch (error) {
            if (timedOut) throw fallo("La consulta está tardando demasiado. Intenta nuevamente.");
            if (error && (error.controlled || error.name === "AbortError")) throw error;
            throw fallo("No se pudo conectar con el servidor. Revisa tu conexión e intenta nuevamente.");
        } finally { window.clearTimeout(timeout); if (onAbort) controller.signal.removeEventListener("abort",onAbort); }
    }

    function descartarHistorial() {
        historyVersion += 1;
        if (historyController) historyController.abort();
        historyController = null; historyLoading = false; historyReady = false;
        ownEvents = new Map(); ticketCount = 0;
        historyPanel.setAttribute("aria-busy","false");
        renderEventos(); notaHistorial();
    }
    function indexarHistorial(data) {
        if (data.idDeporte !== null || !validCount(data.cantidadBoletos) || !Array.isArray(data.boletos)
                || data.cantidadBoletos !== data.boletos.length) throw fallo("El historial recibido está incompleto.");
        const tickets = new Map(), index = new Map();
        for (const ticket of data.boletos) {
            if (!ticket || !validId(ticket.idBoleto) || !text(ticket.codigoBoleto) || !text(ticket.estadoBoleto) || !text(ticket.resultado)
                    || !Array.isArray(ticket.detalles) || ticket.detalles.some(d=>!d || !validId(d.idEvento) || !validId(d.idDeporte) || !validId(d.idSeleccion))) throw fallo("El historial contiene un boleto o detalle inválido.");
            const signature = JSON.stringify([ticket.codigoBoleto,ticket.estadoBoleto,ticket.resultado,
                [...new Set(ticket.detalles.map(d=>JSON.stringify([d.idEvento,d.idDeporte,d.idSeleccion])))].sort()]);
            if (tickets.has(ticket.idBoleto)) {
                if (tickets.get(ticket.idBoleto) !== signature) throw fallo("El historial contiene boletos duplicados inconsistentes.");
                continue;
            }
            tickets.set(ticket.idBoleto,signature);
            const pending = ticket.estadoBoleto === "PENDIENTE" && ticket.resultado === "PENDIENTE";
            for (const detail of ticket.detalles) {
                if (!index.has(detail.idEvento)) index.set(detail.idEvento,{idDeporte:detail.idDeporte,tickets:new Set(),pending:false});
                const entry = index.get(detail.idEvento);
                if (entry.idDeporte !== detail.idDeporte) throw fallo("La asociación de eventos del historial es inconsistente.");
                entry.tickets.add(ticket.idBoleto); entry.pending = entry.pending || pending;
            }
        }
        return {index,count:tickets.size};
    }
    function notaHistorial() {
        let note = "Mis apuestas sigue siendo la fuente para consultar tus boletos, incluidos los partidos que no aparecen en este catálogo limitado a 100 eventos por consulta.";
        if (historyReady && loadedEvents && loadedEvents.sport === selectedSport()) {
            const received = new Set(loadedEvents.items.map(e=>e.idEvento));
            const missing = [...ownEvents].filter(([id,entry])=>entry.idDeporte === loadedEvents.sport && !received.has(id)).length;
            if (missing) note = missing + (missing === 1 ? " partido con apuestas no aparece" : " partidos con apuestas no aparecen")
                + " en el catálogo recibido para este deporte y estado. Eso no elimina tus apuestas: consúltalas en Mis apuestas. El catálogo está limitado a 100 eventos.";
        }
        document.getElementById("nota-historial").textContent = note;
    }
    async function cargarHistorial() {
        if (historyLoading || disposed || !visible()) return;
        descartarHistorial();
        const version = historyVersion, controller = new AbortController();
        historyController = controller; historyLoading = true;
        historyPanel.setAttribute("aria-busy","true"); historyStatus.classList.remove("is-error");
        historyStatus.textContent = "Consultando tus apuestas…"; historyRetry.hidden = true; historyLogin.hidden = true;
        const vigente = ()=>version === historyVersion && !disposed && visible();
        try {
            const data = await consultar("/usuario/boletos/historial",controller);
            if (!vigente()) return;
            const indexed = indexarHistorial(data);
            ownEvents = indexed.index; ticketCount = indexed.count; historyReady = true;
            historyStatus.textContent = ticketCount === 0 ? "No hay apuestas registradas en tu historial. Puedes seguir explorando eventos."
                : "Tus apuestas se verificaron. Se priorizan tus partidos dentro del listado recibido y los filtros seleccionados.";
            renderEventos(); notaHistorial();
        } catch (error) {
            if (!vigente()) return;
            historyStatus.textContent = "No se pudieron verificar tus apuestas. Puedes continuar explorando eventos."
                + (error.needsLogin ? " Tu sesión puede haber expirado; inicia sesión para volver a verificarlas." : " Reintenta la verificación cuando quieras.");
            historyStatus.classList.add("is-error"); historyRetry.hidden = false; historyLogin.hidden = !error.needsLogin;
        } finally {
            if (version === historyVersion) { historyLoading = false; historyController = null; historyPanel.setAttribute("aria-busy","false"); }
        }
    }
    function association(event) {
        const entry = historyReady ? ownEvents.get(event.idEvento) : null;
        return entry && entry.idDeporte === event.idDeporte ? entry : null;
    }
    function priority(event) {
        const own = association(event), live = event.estadoEvento === "EN_VIVO";
        if (live && own) return 0;
        if (own && own.pending) return 1;
        if (live) return 2;
        if (event.estadoEvento === "PROGRAMADO") return 3;
        return 4; // Finalizados u otros estados: no se inventa su estado deportivo.
    }

    function prepararLigas(message) {
        leagueSelect.replaceChildren(node("option", "", message));
        leagueSelect.firstChild.value = "";
        leagueSelect.value = "";
        leagueSelect.disabled = true;
        activeLeagueIds = new Set();
    }

    async function cargarLigas() {
        const version = ++leaguesVersion;
        if (leaguesController) leaguesController.abort();
        const sport = selectedSport();
        prepararLigas(sport === null ? "Selecciona primero un deporte" : "Cargando ligas…");
        leaguesRetry.hidden = true;
        leaguesStatus.classList.remove("is-error");
        leaguesStatus.textContent = sport === null ? "Selecciona primero un deporte para consultar sus ligas." : "Cargando ligas…";
        leagueSelect.setAttribute("aria-busy", String(sport !== null));
        renderEventos();
        if (sport === null) return;
        const controller = new AbortController();
        leaguesController = controller;
        const vigente = () => version === leaguesVersion && selectedSport() === sport;
        try {
            const data = await consultar("/ligas/exploracion?" + new URLSearchParams({idDeporte: String(sport)}), controller);
            if (!vigente()) return;
            const ids = new Set();
            if (data.idDeporte !== sport || !validCount(data.cantidad) || !Array.isArray(data.ligas) || data.cantidad !== data.ligas.length
                    || data.ligas.some(item => {
                        if (!item || !validId(item.idLiga) || item.idDeporte !== sport || !text(item.nombre)
                                || typeof item.activo !== "boolean" || !(item.idPais === null || validId(item.idPais)) || ids.has(item.idLiga)) return true;
                        ids.add(item.idLiga); return false;
                    })) throw fallo("El servidor devolvió un catálogo de ligas inválido para este deporte.");
            const leagues = data.ligas.filter(item => item.activo);
            prepararLigas("Todas las ligas");
            for (const league of leagues) {
                const option = node("option", "", league.nombre);
                option.value = String(league.idLiga);
                leagueSelect.append(option);
                activeLeagueIds.add(league.idLiga);
            }
            leagueSelect.disabled = !leagues.length;
            leaguesStatus.textContent = leagues.length ? "Puedes filtrar el listado cargado por una liga o ver Todas las ligas." : "No hay ligas activas disponibles. Puedes seguir consultando eventos por deporte.";
        } catch (error) {
            if (!vigente() || error.name === "AbortError") return;
            prepararLigas("Todas las ligas");
            leaguesStatus.textContent = (error.controlled ? error.message : "No fue posible cargar las ligas.") + " Puedes seguir consultando eventos por deporte.";
            leaguesStatus.classList.add("is-error");
            leaguesRetry.hidden = false;
        } finally {
            if (vigente()) { leagueSelect.setAttribute("aria-busy", "false"); leaguesController = null; }
        }
    }

    function renderEventos() {
        if (!loadedEvents || loadedEvents.sport !== selectedSport()) return;
        const league = leagueSelect.value ? Number(leagueSelect.value) : null;
        const filtered = league === null ? loadedEvents.items : loadedEvents.items.filter(event => event.idLiga === league);
        const events = filtered.map((event,index)=>({event,index})).sort((a,b)=>priority(a.event)-priority(b.event)||a.index-b.index).map(item=>item.event);
        if (!events.length) {
            estadoEventos(league === null ? "No hay eventos en el listado recibido para este deporte y estado. Prueba con otro filtro."
                : "No hay coincidencias para esta liga en el listado actualmente cargado. Puede haber otros eventos fuera de este listado.");
        } else {
            const focused = document.activeElement;
            const cards = events.map(event=>{
                let cached = cardCache.get(event.idEvento);
                if (!cached) { cached = tarjeta(event); cardCache.set(event.idEvento,cached); }
                const own = association(event);
                cached.personal.hidden = !own; cached.card.classList.toggle("has-own-bet",Boolean(own));
                const message = own ? "Tienes " + own.tickets.size + (own.tickets.size === 1 ? " boleto asociado" : " boletos asociados") : "";
                if (cached.label.textContent !== message) cached.label.textContent = message;
                return cached.card;
            });
            cards.forEach((card,index)=>{ if (list.children[index] !== card) list.insertBefore(card,list.children[index] || null); });
            while (list.children.length > cards.length) list.lastElementChild.remove();
            if (focused && list.contains(focused) && document.activeElement !== focused) focused.focus({preventScroll:true});
            state.hidden = true;
            eventsStatus.textContent = `${events.length} eventos mostrados del listado cargado.`;
        }
        count.textContent = `${events.length} de ${loadedEvents.items.length} eventos recibidos · consulta limitada a 100`;
        notaHistorial();
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
        const personal = node("div", "personal-event"), ownLabel = node("p", "own-event-label");
        const ownLink = node("a", "", "Ver Mis apuestas ↗");
        ownLink.href = contextPath + "/apuestas/mis-boletos.jsp";
        personal.hidden = true; personal.append(ownLabel,ownLink); card.append(personal);
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
        return {card,personal,label:ownLabel};
    }

    async function cargarEventos() {
        if (eventsController) eventsController.abort();
        const version = ++requestVersion;
        loadedEvents = null; cardCache.clear(); notaHistorial();
        const sport = selectedSport();
        if (sport === null) { estadoEventos("Selecciona un deporte para explorar sus eventos."); return; }
        const controller = new AbortController();
        eventsController = controller;
        const vista = views.querySelector("input:checked").value;
        const params = new URLSearchParams({ idDeporte: sportSelect.value, vista, cantidad: "100", horasPrevia: "24" });
        estadoEventos("Cargando eventos…", true);
        try {
            const data = await consultar("/eventos/exploracion?" + params.toString(), controller);
            if (version !== requestVersion || selectedSport() !== sport) return;
            const ids = new Set();
            if (!Array.isArray(data.eventos) || !validCount(data.cantidad) || data.cantidad !== data.eventos.length
                    || data.cantidad > 100 || data.eventos.some(event => {
                        if (!event || !validId(event.idEvento) || !validId(event.idLiga) || event.idDeporte !== sport || ids.has(event.idEvento)) return true;
                        ids.add(event.idEvento); return false;
                    })) throw fallo("El servidor devolvió un listado de eventos inválido.");
            loadedEvents = {sport, items: data.eventos};
            renderEventos();
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

    sportSelect.addEventListener("change", () => {
        loadedEvents = null;
        views.disabled = selectedSport() === null;
        cargarLigas(); cargarEventos();
    });
    leagueSelect.addEventListener("change", () => {
        if (leagueSelect.value && (!/^\d+$/.test(leagueSelect.value) || !activeLeagueIds.has(Number(leagueSelect.value)))) leagueSelect.value = "";
        renderEventos();
    });
    leaguesRetry.addEventListener("click", cargarLigas);
    views.addEventListener("change", cargarEventos);
    sportsRetry.addEventListener("click", cargarDeportes);
    eventsRetry.addEventListener("click", cargarEventos);
    historyRetry.addEventListener("click", cargarHistorial);
    document.addEventListener("visibilitychange",()=>{
        if (!visible()) {
            descartarHistorial(); historyStatus.textContent = "Verificación de apuestas pausada. Se consultará de nuevo al volver a esta pestaña.";
            historyRetry.hidden = true; historyLogin.hidden = true;
        } else cargarHistorial();
    });
    window.addEventListener("focus",cargarHistorial);
    window.addEventListener("pagehide",()=>{ disposed = true; descartarHistorial(); });
    window.addEventListener("pageshow",event=>{ if (event.persisted) { disposed = false; cargarHistorial(); } });
    cargarDeportes();
    cargarHistorial();
})();
