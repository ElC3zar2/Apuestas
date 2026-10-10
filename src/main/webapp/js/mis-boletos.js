(() => {
    "use strict";
    const contextPath = window.APP_CONTEXT_PATH || "";
    const get = id => document.getElementById(id);
    const filter = get("deporte-boletos"), list = get("lista-boletos"), status = get("estado-historial"), section = get("historial");
    let historyController, version = 0, sportsLoading = false;
    const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
    const id = value => Number.isInteger(value) && value > 0 && value <= 2147483647;
    const count = value => Number.isSafeInteger(value) && value >= 0;
    const numeric = value => typeof value === "number" && Number.isFinite(value);
    const text = value => typeof value === "string" && value.trim() ? value : null;
    const display = value => value === null || value === undefined ? "No disponible" : String(value);
    function node(tag, className, value) { const el = document.createElement(tag); if (className) el.className = className; if (value !== undefined) el.textContent = value; return el; }
    function fecha(value) {
        const match = typeof value === "string" && /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::\d{2}(?:\.\d+)?)?$/.exec(value);
        return match ? `${match[3]}/${match[2]}/${match[1]} · ${match[4]}:${match[5]}` : "No informada";
    }
    function fault(message, session = false) { const error = new Error(message); error.session = session; return error; }
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
        card.append(facts); return card;
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
        fact(facts,"Premio potencial",item.premioPotencial); fact(facts,"Ganancia neta potencial",item.gananciaNetaPotencial);
        fact(facts,"Ganancia potencial (%)",item.porcentajeGananciaPotencial); fact(facts,"Probabilidad implícita (%)",item.probabilidadImplicitaPorcentaje);
        card.append(facts);
        const actions = node("div","ticket-actions");
        const pdf = node("a","pdf-link","Ver boleto PDF ↗");
        pdf.href = contextPath + "/usuario/boletos/imprimir?idBoleto=" + encodeURIComponent(item.idBoleto);
        pdf.target = "_blank"; pdf.rel = "noopener noreferrer"; pdf.setAttribute("aria-label","Ver boleto PDF " + item.codigoBoleto + " (otra pestaña)");
        actions.append(node("p","","Selecciones totales del boleto: " + item.cantidadSelecciones),pdf); card.append(actions);
        const expanded = node("details","ticket-details");
        expanded.append(node("summary","",filtered ? "Ver selecciones del deporte filtrado (" + item.detalles.length + ")" : "Ver selecciones (" + item.detalles.length + ")"));
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
                    || !Array.isArray(item.detalles) || item.detalles.some(detail => !object(detail) || !id(detail.idDetalle) || !id(detail.idSeleccion) || !id(detail.idDeporte) || !numeric(detail.cuotaAplicada) || (sport !== null && detail.idDeporte !== sport))) throw fault("El servidor devolvió un boleto o detalle incompleto.");
            ids.add(item.idBoleto);
        }
    }
    async function cargarHistorial() {
        if (historyController) historyController.abort();
        const current = ++version;
        const sport = filter.value ? Number(filter.value) : null;
        if (sport !== null && (!/^\d+$/.test(filter.value) || !id(sport))) { estado("Selecciona un deporte válido.",false,true); return; }
        const controller = new AbortController(); historyController = controller;
        get("nota-filtro").hidden = sport === null;
        estado(sport === null ? "Cargando historial…" : "Filtrando boletos…",true);
        try {
            const suffix = sport === null ? "" : "?" + new URLSearchParams({idDeporte:String(sport)}).toString();
            const data = await consultar("/usuario/boletos/historial" + suffix,controller);
            if (current !== version) return;
            validar(data,sport);
            if (!data.boletos.length) { estado(sport === null ? "Todavía no tienes boletos en tu historial." : "No hay boletos para el deporte seleccionado. Puedes consultar Todos los deportes."); return; }
            const fragment = document.createDocumentFragment(); data.boletos.forEach(item => fragment.append(boleto(item,sport !== null)));
            list.replaceChildren(fragment); status.hidden = true; get("cantidad-boletos").textContent = data.cantidadBoletos + " boletos mostrados";
        } catch (error) {
            if (current !== version) return;
            estado(error.name === "AbortError" ? "La consulta se interrumpió. Vuelve a intentar." : error.message || "No fue posible cargar el historial.",false,true,error.session === true);
        } finally { if (current === version) section.setAttribute("aria-busy","false"); }
    }
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
