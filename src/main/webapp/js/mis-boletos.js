(() => {
    "use strict";
    const contextPath = window.APP_CONTEXT_PATH || "";
    const get = id => document.getElementById(id);
    const filter = get("deporte-boletos"), list = get("lista-boletos"), status = get("estado-historial"), section = get("historial");
    let historyController, version = 0, sportsLoading = false, historyData = null, historySport = null, away = false;
    const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
    const id = value => Number.isInteger(value) && value > 0 && value <= 2147483647;
    const eventParams = new URLSearchParams(window.location.search).getAll("idEvento");
    let eventId = eventParams.length === 1 && /^\d+$/.test(eventParams[0]) && id(Number(eventParams[0])) ? Number(eventParams[0]) : null;
    const eventNotice = get("filtro-evento"), removeEvent = get("quitar-filtro-evento");
    eventNotice.hidden = eventParams.length === 0;
    eventNotice.textContent = eventId === null ? "El filtro de partido no es válido o está duplicado. Se muestra el historial normal." : "Mostrando apuestas del partido #" + eventId + ". Los importes corresponden al boleto completo; puede incluir otras selecciones.";
    removeEvent.hidden = eventId === null;
    const count = value => Number.isSafeInteger(value) && value >= 0;
    const numeric = value => (typeof value === "number" || typeof value === "string" && /^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?$/.test(value)) && Number.isFinite(Number(value));
    const financialKeys = new Set(["montoApostado","comisionServicio","totalCargo","cuotaTotal","premioPotencial","gananciaNetaPotencial","porcentajeGananciaPotencial","probabilidadImplicitaPorcentaje","cuotaAplicada","probabilidadImplicitaSeleccionPorcentaje","cuotaResultadoAplicada","cuotaLiquidacion"]);
    function readFinancial(source) {
        let key = null;
        return JSON.parse(source.replace(/"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/g,(token,offset)=>{
            if (token[0] === '"') { key = /^\s*:/.test(source.slice(offset + token.length)) ? JSON.parse(token) : null; return token; }
            const field = key; key = null; return financialKeys.has(field) ? JSON.stringify(token) : token;
        }));
    }
    const text = value => typeof value === "string" && value.trim() ? value : null;
    const display = value => value === null || value === undefined ? "No disponible" : String(value);
    function node(tag, className, value) { const el = document.createElement(tag); if (className) el.className = className; if (value !== undefined) el.textContent = value; return el; }
    function fecha(value) {
        const match = typeof value === "string" && /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::\d{2}(?:\.\d+)?)?$/.exec(value);
        return match ? `${match[3]}/${match[2]}/${match[1]} · ${match[4]}:${match[5]}` : "No informada";
    }
    function fault(message, session = false) { const error = new Error(message); error.session = session; return error; }

    // Lectura personal independiente; la sesión y la propiedad se autorizan en el servidor.
    function historico(target, item) {
        const value = v => text(v) || "No informado";
        fact(target, "Modalidad histórica", value(item.tipoMercadoAplicado));
        fact(target, "Selección apostada", text(item.nombreSeleccionAplicada) || value(item.seleccion));
        if (item.tipoMercadoAplicado === "MARCADOR_FINAL" || item.pronosticoA != null || item.pronosticoB != null) {
            const forecast = v => Number.isInteger(v) && v >= 0 && v <= 2147483647 ? String(v) : "No informado";
            fact(target, "Pronóstico A · " + value(item.nombreParticipanteAAplicado), forecast(item.pronosticoA));
            fact(target, "Pronóstico B · " + value(item.nombreParticipanteBAplicado), forecast(item.pronosticoB));
        }
        if (text(item.clasificacionAcierto)) fact(target, "Clasificación oficial", item.clasificacionAcierto);
        if (text(item.descripcionAcierto)) fact(target, "Descripción oficial", item.descripcionAcierto);
    }
    async function lecturaPersonal(route, controller) {
        let timer, abort;
        const error = (message, session = false) => Object.assign(new Error(message), {session});
        const request = async () => {
            const response = await fetch(contextPath + route, {method:"GET", credentials:"same-origin", cache:"no-store", headers:{Accept:"application/json"}, signal:controller.signal});
            if (response.status === 401) throw error("Tu sesión ha expirado. Inicia sesión para consultar tus boletos.", true);
            if (response.redirected) {
                const target = new URL(response.url, window.location.href);
                const login = target.origin === new URL(window.location.href).origin
                    && [contextPath + "/usuario/login", contextPath + "/usuario/login.jsp"].includes(target.pathname);
                throw error(login ? "Tu sesión ha expirado. Inicia sesión para consultar tus boletos." : "La consulta fue redirigida a un destino inesperado.", login);
            }
            if (response.status === 403) throw error("No tienes permiso para consultar esta información.");
            if (!response.ok) throw error("El servidor no pudo completar la consulta. Intenta nuevamente.");
            if ((response.headers.get("content-type") || "").split(";")[0].trim().toLowerCase() !== "application/json") throw error("Respuesta inesperada: se esperaba JSON.");
            let data;
            try { data = readFinancial(await response.text()); } catch (_) { throw error("La respuesta JSON no es válida."); }
            if (!object(data) || data.ok !== true) throw error("La respuesta del servidor no es válida.");
            return data;
        };
        try {
            return await Promise.race([request(), new Promise((_, reject) => {
                timer = window.setTimeout(() => { reject(error("La consulta tardó demasiado. Vuelve a intentar.")); controller.abort(); }, 15000);
                abort = () => reject(error("La consulta se interrumpió."));
                controller.signal.addEventListener("abort", abort, {once:true});
                if (controller.signal.aborted) abort();
            })]);
        } catch (e) { throw e instanceof TypeError ? error("No se pudo conectar con el servidor. Revisa tu conexión.") : e; }
        finally { window.clearTimeout(timer); if (abort) controller.signal.removeEventListener("abort", abort); }
    }
    async function consultar(route, controller) {
        let timedOut = false;
        const timeout = window.setTimeout(() => { timedOut = true; controller.abort(); },15000);
        try {
            const response = await fetch(contextPath + route,{method:"GET",credentials:"same-origin",cache:"no-store",headers:{Accept:"application/json"},signal:controller.signal});
            if (response.status === 401) throw fault("Tu sesión no está disponible o ha expirado. Inicia sesión para consultar tus boletos.",true);
            if (response.redirected) {
                const target = new URL(response.url,window.location.href);
                const login = target.pathname === contextPath + "/usuario/login" || target.pathname === contextPath + "/usuario/login.jsp";
                throw fault(login ? "Tu sesión ha expirado. Inicia sesión para consultar tus boletos." : "La consulta fue redirigida a una respuesta inesperada.",login);
            }
            if (!response.ok) {
                const errors = {400:"Los parámetros de la consulta no son válidos.",403:"No tienes permiso para consultar esta información.",404:"La información solicitada no está disponible.",500:"El servidor no pudo completar la consulta. Intenta nuevamente."};
                throw fault(errors[response.status] || "No fue posible completar la consulta.");
            }
            const type = (response.headers.get("content-type") || "").split(";")[0].trim().toLowerCase();
            if (type !== "application/json") throw fault("Se recibió una respuesta inesperada en lugar de JSON. Si tu sesión expiró, vuelve a iniciar sesión.",type === "text/html");
            let data;
            try { data = await response.json(); }
            catch (error) { if (controller.signal.aborted) throw error; throw fault("La respuesta JSON del servidor no es válida."); }
            if (!object(data) || data.ok !== true) throw fault("La respuesta del servidor no contiene un resultado válido.");
            return data;
        } catch (error) {
            if (timedOut) throw fault("La consulta está tardando demasiado. Vuelve a intentar.");
            if (error instanceof TypeError) throw fault("No se pudo conectar con el servidor. Revisa tu conexión.");
            throw error;
        } finally { window.clearTimeout(timeout); }
    }
    function estado(message, loading = false, error = false, session = false) {
        list.replaceChildren(); get("cantidad-boletos").textContent = "";
        status.hidden = false; status.classList.toggle("is-loading",loading); status.classList.toggle("is-error",error);
        get("mensaje-historial").textContent = message; get("reintentar-historial").hidden = !error; get("login-historial").hidden = !session;
        section.setAttribute("aria-busy",String(loading));
    }
    function fact(target,title,value,total = false) { const item = node("div",total ? "total" : ""); item.append(node("dt","",title),node("dd","",display(value))); target.append(item); }
    function badge(value) {
        const colors = {PENDIENTE:"is-pending",GANADOR:"is-winner",PERDEDOR:"is-loser",ANULADO:"",GANADA:"is-winner",PERDIDA:"is-loser",ANULADA:""};
        return node("span","ticket-badge " + (colors[value] || ""),text(value) || "No disponible");
    }
    function detalle(item) {
        const card = node("article","ticket-selection");
        card.append(node("p","selection-category",[text(item.deporte),text(item.liga)].filter(Boolean).join(" / ") || "Deporte y liga no disponibles"),node("h4","",text(item.seleccion) || "Selección no disponible"));
        const facts = node("dl","selection-facts");
        fact(facts,"Evento",text(item.evento) || "No disponible"); fact(facts,"Inicio del evento",fecha(item.fechaInicio));
        fact(facts,"Mercado",text(item.mercado) || "No disponible"); fact(facts,"Cuota aplicada",item.cuotaAplicada);
        fact(facts,"Resultado de selección",text(item.resultadoSeleccion) || "No disponible");
        fact(facts,"Probabilidad implícita (%)",item.probabilidadImplicitaSeleccionPorcentaje);
        historico(facts,item); card.append(facts);
        const eventLink = node("a","text-link","Seguir este evento ↗");
        eventLink.href = contextPath + "/eventos/detalle-evento.jsp?idEvento=" + encodeURIComponent(item.idEvento);
        card.append(eventLink); return card;
    }
    function boleto(item,filtered) {
        const card = node("article","panel ticket");
        const header = node("div","ticket-header"), title = node("div");
        title.append(node("p","ticket-type",item.tipoBoleto),node("h3","ticket-code",item.codigoBoleto),node("p","ticket-id","Boleto #" + item.idBoleto));
        const badges = node("div","ticket-badges");
        const result = badge(item.resultado), state = badge(item.estadoBoleto);
        result.setAttribute("aria-label","Resultado: " + item.resultado); state.setAttribute("aria-label","Estado: " + item.estadoBoleto);
        result.textContent = "Resultado: " + item.resultado; state.textContent = "Estado: " + item.estadoBoleto;
        badges.append(result,state); header.append(title,badges); card.append(header);
        const facts = node("dl","ticket-facts");
        fact(facts,"Creación",fecha(item.fechaCreacion)); fact(facts,"Liquidación",fecha(item.fechaLiquidacion));
        fact(facts,"Monto apostado",item.montoApostado); fact(facts,"Comisión",item.comisionServicio);
        fact(facts,"Total cargado",item.totalCargo,true); fact(facts,"Cuota total",item.cuotaTotal);
        fact(facts,"Premio potencial histórico",item.premioPotencial); fact(facts,"Ganancia neta potencial histórica",item.gananciaNetaPotencial);
        fact(facts,"Ganancia potencial (%)",item.porcentajeGananciaPotencial); fact(facts,"Probabilidad implícita (%)",item.probabilidadImplicitaPorcentaje);
        card.append(facts,node("p","muted","El premio potencial histórico no acredita un pago. Este historial no informa un importe universal de premio efectivamente abonado; consulta los movimientos de tu billetera."));
        const actions = node("div","ticket-actions");
        const pdf = node("a","pdf-link","Ver boleto PDF ↗");
        pdf.href = contextPath + "/usuario/boletos/imprimir?idBoleto=" + encodeURIComponent(item.idBoleto);
        pdf.target = "_blank"; pdf.rel = "noopener noreferrer"; pdf.setAttribute("aria-label","Ver boleto PDF " + item.codigoBoleto + " (otra pestaña)");
        const wallet = node("a","text-link","Consultar movimientos"); wallet.href = contextPath + "/billetera/movimientos.jsp";
        actions.append(node("p","","Selecciones totales del boleto: " + item.cantidadSelecciones),pdf,wallet); card.append(actions);
        const expanded = node("details","ticket-details");
        expanded.append(node("summary","",filtered ? "Ver selecciones que coinciden con los filtros (" + item.detalles.length + ")" : "Ver selecciones (" + item.detalles.length + ")"));
        if (!item.detalles.length) expanded.append(node("p","empty-details",filtered ? "No se recibieron detalles para este deporte." : "Este boleto no tiene detalles informados."));
        else { const details = node("div","selection-list"); item.detalles.forEach(item => details.append(detalle(item))); expanded.append(details); }
        card.append(expanded); return card;
    }
    function validar(data,sport) {
        const numbers = ["montoApostado","comisionServicio","totalCargo","cuotaTotal","premioPotencial","gananciaNetaPotencial"];
        const nullable = ["porcentajeGananciaPotencial","probabilidadImplicitaPorcentaje"];
        if (data.idDeporte !== sport || !count(data.cantidadBoletos) || !Array.isArray(data.boletos) || data.cantidadBoletos !== data.boletos.length) throw fault("El historial recibido está incompleto o no corresponde al filtro.");
        const ids = new Set();
        for (const item of data.boletos) {
            if (!object(item) || !id(item.idBoleto) || ids.has(item.idBoleto) || !text(item.codigoBoleto) || !text(item.tipoBoleto) || !text(item.resultado) || !text(item.estadoBoleto)
                    || !count(item.cantidadSelecciones) || numbers.some(key => !numeric(item[key])) || nullable.some(key => !(item[key] === null || numeric(item[key])))
                    || !Array.isArray(item.detalles) || item.detalles.some(detail => !object(detail) || !id(detail.idEvento) || !id(detail.idDetalle) || !id(detail.idSeleccion) || !id(detail.idDeporte) || !numeric(detail.cuotaAplicada) || (sport !== null && detail.idDeporte !== sport))) throw fault("El servidor devolvió un boleto o detalle incompleto.");
            ids.add(item.idBoleto);
        }
    }
    async function cargarHistorial() {
        if (away || document.visibilityState === "hidden") return;
        if (historyController && historySport === filter.value) return;
        if (historyController) historyController.abort();
        historyData = null; historySport = filter.value;
        const current = ++version;
        const sport = filter.value ? Number(filter.value) : null;
        if (sport !== null && (!/^\d+$/.test(filter.value) || !id(sport))) { estado("Selecciona un deporte válido.",false,true); return; }
        const controller = new AbortController(); historyController = controller;
        get("nota-filtro").hidden = sport === null && eventId === null;
        get("nota-filtro").textContent = "Se muestran únicamente las selecciones que coinciden con los filtros. El total de selecciones y los importes corresponden al boleto completo, que puede contener otras selecciones.";
        estado(sport === null ? "Cargando historial…" : "Filtrando boletos…",true);
        try {
            const suffix = sport === null ? "" : "?" + new URLSearchParams({idDeporte:String(sport)}).toString();
            const data = await lecturaPersonal("/usuario/boletos/historial" + suffix,controller);
            if (current !== version) return;
            validar(data,sport);
            historyData = data; renderHistorial();
        } catch (error) {
            if (current !== version) return;
            estado(error.name === "AbortError" ? "La consulta se interrumpió. Vuelve a intentar." : error.message || "No fue posible cargar el historial.",false,true,error.session === true);
        } finally { if (current === version) { historyController = null; section.setAttribute("aria-busy","false"); } }
    }
    function renderHistorial() {
        if (!historyData) return;
        const tickets = eventId === null ? historyData.boletos : historyData.boletos.map(ticket => ({
            ...ticket, detalles: ticket.detalles.filter(detail => detail.idEvento === eventId)
        })).filter(ticket => ticket.detalles.length);
        get("nota-filtro").hidden = !filter.value && eventId === null;
        if (!tickets.length) { estado(eventId !== null ? "No encontramos apuestas tuyas para este partido con los filtros actuales." : filter.value ? "No hay boletos para el deporte seleccionado." : "Todavía no tienes boletos en tu historial."); return; }
        const fragment = document.createDocumentFragment();
        tickets.forEach(item => fragment.append(boleto(item, Boolean(filter.value) || eventId !== null)));
        list.replaceChildren(fragment); status.hidden = true; get("cantidad-boletos").textContent = tickets.length + " boletos mostrados";
    }
    function clearPersonal() {
        version += 1; historyData = null;
        const controller = historyController; historyController = null;
        estado("Información personal oculta. Se consultará de nuevo al volver.");
        if (controller) controller.abort();
    }
    removeEvent.addEventListener("click", () => {
        eventId = null; eventNotice.hidden = true; removeEvent.hidden = true;
        const url = new URL(window.location.href); url.searchParams.delete("idEvento");
        window.history.replaceState(null,"",url.pathname + url.search + url.hash);
        if (historyData) renderHistorial(); else cargarHistorial();
        filter.focus();
    });
    document.addEventListener("visibilitychange", () => { if (document.visibilityState === "hidden") clearPersonal(); else cargarHistorial(); });
    window.addEventListener("pagehide", () => { away = true; clearPersonal(); });
    window.addEventListener("pageshow", e => { if (e.persisted && away) { away = false; cargarHistorial(); } });
    async function cargarDeportes() {
        if (sportsLoading) return; sportsLoading = true;
        filter.disabled = true; get("reintentar-deportes").hidden = true; get("estado-deportes").classList.remove("is-error"); get("estado-deportes").textContent = "Cargando deportes…";
        try {
            const data = await consultar("/deportes/exploracion",new AbortController());
            if (!Array.isArray(data.deportes) || !count(data.cantidad) || data.cantidad !== data.deportes.length || data.deportes.some(item => !object(item) || !id(item.idDeporte) || !text(item.nombre) || typeof item.activo !== "boolean")) throw fault("El catálogo de deportes recibido no es válido.");
            const selected = filter.value;
            const all = node("option","","Todos los deportes"); all.value = ""; filter.replaceChildren(all);
            data.deportes.forEach(item => { const option = node("option","",item.nombre); option.value = String(item.idDeporte); filter.append(option); });
            filter.value = selected; filter.disabled = false;
            get("estado-deportes").textContent = data.deportes.length ? "Puedes filtrar por los deportes disponibles en el catálogo." : "No hay deportes en el catálogo. El historial completo sigue disponible.";
        } catch (error) { get("estado-deportes").textContent = (error.message || "No fue posible cargar deportes.") + " El historial completo puede consultarse sin este filtro."; get("estado-deportes").classList.add("is-error"); get("reintentar-deportes").hidden = false; }
        finally { sportsLoading = false; }
    }
    filter.addEventListener("change",cargarHistorial);
    get("reintentar-historial").addEventListener("click",cargarHistorial);
    get("reintentar-deportes").addEventListener("click",cargarDeportes);
    cargarHistorial(); cargarDeportes();
})();
