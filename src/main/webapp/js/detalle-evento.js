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
    let lastEvent = null, pollTimer = null, activeController = null;
    let generation = 0, disposed = false, refreshPending = false, stopAfterError = false;
    let sessionExpiredConfirmed = false, transientFailures = 0;
    const refresh = document.getElementById("actualizar-partido");
    const follow = document.getElementById("control-seguimiento");
    const updateStatus = document.getElementById("estado-actualizacion");
    const safeCount = value => Number.isInteger(value) && value >= 0 && value <= 2147483647;
    const safeLongId = value => Number.isSafeInteger(value) && value > 0;
    const visible = () => document.visibilityState !== "hidden";

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
    function put(id, value) {
        const element = document.getElementById(id);
        if (element.textContent !== value) element.textContent = value;
    }
    // Reutilizar nodos con clave conserva foco y posición al actualizar mercados
    // e incidencias. La cronología no es una región aria-live.
    function reconcile(parent, desiredChildren) {
        const keyed = new Map([...parent.children].filter(e => e.hasAttribute("data-live-key")).map(e => [e.getAttribute("data-live-key"), e]));
        desiredChildren.forEach((desired, index) => {
            const key = desired.getAttribute("data-live-key");
            let current = key === null ? parent.children[index] : keyed.get(key);
            if (current && key === null && current.hasAttribute("data-live-key")) current = null;
            // Si una cuota enfocada deja de estar disponible, mantener su nodo
            // sin href y con semántica deshabilitada evita perder el foco.
            if (current && current.tagName === "A" && desired.tagName === "BUTTON"
                    && current.classList.contains("selection-action") && desired.classList.contains("selection-action")) {
                const disabledLink = node("a", "selection-action", desired.textContent);
                disabledLink.setAttribute("role", "button"); disabledLink.setAttribute("aria-disabled", "true"); disabledLink.setAttribute("tabindex", "-1");
                if (desired.hasAttribute("aria-describedby")) disabledLink.setAttribute("aria-describedby", desired.getAttribute("aria-describedby"));
                desired = disabledLink;
            }
            if (!current || current.tagName !== desired.tagName) current = desired;
            else {
                for (const attribute of [...current.attributes]) if (!desired.hasAttribute(attribute.name)) current.removeAttribute(attribute.name);
                for (const attribute of [...desired.attributes]) if (current.getAttribute(attribute.name) !== attribute.value) current.setAttribute(attribute.name, attribute.value);
                if (!desired.children.length) {
                    if (current.textContent !== desired.textContent) current.textContent = desired.textContent;
                } else reconcile(current, [...desired.children]);
            }
            if (parent.children[index] !== current) parent.insertBefore(current, parent.children[index] || null);
        });
        while (parent.children.length > desiredChildren.length) parent.lastElementChild.remove();
    }
    function duration(value) {
        return safeCount(value) ? String(Math.floor(value / 60)) + ":" + String(value % 60).padStart(2, "0") : "Tiempo no disponible";
    }
    function utc(value) {
        return typeof value === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?$/.test(value)
            ? value.replace("T", " ") + " UTC" : null;
    }
    function officialParticipants(event) {
        const ordered = [1,2].map(order => event.participantes.filter(p => p.ordenParticipante === order));
        if (event.participantes.length !== 2 || ordered.some(p => p.length !== 1 || !validId(p[0].idParticipante))
                || ordered[0][0].idParticipante === ordered[1][0].idParticipante) return null;
        return ordered.map(p => p[0]);
    }
    function incidentData(event) {
        if (!Array.isArray(event.incidencias)) return {valid:false, rows:[], duplicate:false};
        const ids = new Map(), sequences = new Map(); let duplicate = false;
        for (const i of event.incidencias) {
            if (!object(i) || !safeLongId(i.idIncidencia) || !validId(i.secuencia) || !safeCount(i.segundoSimulacion)
                    || !text(i.tipoIncidencia) || typeof i.esAnulada !== "boolean"
                    || !(i.idParticipante === null || validId(i.idParticipante))
                    || !(i.valorAnotacion === null || (safeCount(i.valorAnotacion) && i.valorAnotacion > 0))) return {valid:false,rows:[],duplicate};
            if (ids.has(i.idIncidencia)) {
                if (JSON.stringify(ids.get(i.idIncidencia)) !== JSON.stringify(i)) return {valid:false,rows:[],duplicate:true};
                duplicate = true; continue;
            }
            if (sequences.has(i.secuencia)) return {valid:false,rows:[],duplicate:true};
            ids.set(i.idIncidencia,i); sequences.set(i.secuencia,i.idIncidencia);
        }
        return {valid:true,rows:[...ids.values()].sort((a,b)=>b.secuencia-a.secuencia),duplicate};
    }
    function participantName(event, id) {
        if (!validId(id)) return "Participante no informado";
        const matches = event.participantes.filter(p=>p.idParticipante === id);
        return matches.length === 1 && text(matches[0].participante) ? matches[0].participante : "Participante no verificable";
    }
    function renderLive(event) {
        const sim = object(event.simulacion) ? event.simulacion : null;
        const live = event.estadoEvento === "EN_VIVO";
        const preliminary = event.estadoEvento === "PENDIENTE_RESULTADO";
        const suspended = event.estadoEvento === "SUSPENDIDO";
        const official = event.estadoEvento === "FINALIZADO" && event.estadoResultado === "OFICIAL";
        document.querySelector(".live-match").dataset.eventState = event.estadoEvento || "";
        document.querySelector(".score-numbers").hidden = !(live || preliminary || suspended);
        document.querySelector(".match-facts").hidden = !live;
        document.getElementById("incidencias-recientes").hidden = !live;
        put("fase-partido", live ? "Partido en vivo" : preliminary ? "Partido finalizado; resultado pendiente de oficialización."
            : official ? "Resultado final" : event.estadoEvento === "FINALIZADO" ? "Partido finalizado; resultado oficial no confirmado."
            : event.estadoEvento === "CANCELADO" ? "Evento cancelado. No se presenta un resultado deportivo definitivo."
            : suspended ? "Encuentro suspendido; último marcador verificable, sin seguimiento activo."
            : event.estadoEvento === "PROGRAMADO" ? "Encuentro programado · " + fecha(event.fechaInicio) : "Información del evento");
        put("competicion-partido", [text(event.deporte),text(event.liga)].filter(Boolean).join(" / ") || "Competición no informada");
        put("titulo-partido", text(event.nombre) || "Seguimiento deportivo");
        put("estado-partido", "Estado oficial: " + label(event.estadoEvento));
        const pair = officialParticipants(event);
        ["a","b"].forEach((side,index)=>{
            const p = pair && pair[index];
            put("participante-" + side, p && text(p.participante) ? p.participante : "Participante " + side.toUpperCase() + " no disponible");
            put("condicion-" + side, p && typeof p.esLocal === "boolean" ? (p.esLocal ? "Local" : "Visitante") : "");
        });
        let conflict = false;
        const scores = pair ? pair.map((p,index)=>{
            const a = sim ? sim[index === 0 ? "marcadorA" : "marcadorB"] : null, b = p.marcadorActual;
            if ((a !== null && a !== undefined && !safeCount(a)) || (b !== null && b !== undefined && !safeCount(b))
                    || (safeCount(a) && safeCount(b) && a !== b)) conflict = true;
            return safeCount(a) ? a : safeCount(b) ? b : null;
        }) : [null,null];
        put("marcador-a", !conflict && scores[0] !== null ? String(scores[0]) : "—");
        put("marcador-b", !conflict && scores[1] !== null ? String(scores[1]) : "—");
        put("nota-marcador", !(live || preliminary || suspended) ? (official ? "Resultado oficial informado: " + (text(event.resultadoTexto) || "Texto no disponible") : "")
            : conflict ? "Las fuentes del marcador no coinciden. Marcador no verificable."
            : !pair ? "No se puede verificar la correspondencia de los participantes y el marcador."
            : scores.some(s=>s===null) ? "Marcador pendiente de confirmación" : preliminary ? "Marcador PRELIMINAR; pendiente de oficialización."
            : suspended ? "Último marcador informado antes de la suspensión; no es definitivo." : "Marcador informado por el servidor; no implica un resultado definitivo.");
        put("tiempo-partido", duration(sim && sim.segundosTranscurridos));
        put("duracion-partido", sim && safeCount(sim.duracionSimulacionSegundos) ? duration(sim.duracionSimulacionSegundos) : "No disponible");
        put("configuracion-partido", sim && typeof sim.esSimulado === "boolean" ? (sim.esSimulado ? "Simulación manual configurada" : "Simulación no configurada") : "No informada");
        const timeNotice = document.getElementById("tiempo-cumplido");
        timeNotice.hidden = !live || !sim || sim.tiempoVisualCumplido !== true;
        put("tiempo-cumplido", "La duración visual de referencia se cumplió. El estado del partido solo cambia cuando lo informa el backend.");
        const dates = [];
        if (sim && utc(sim.fechaInicioRealUtc)) dates.push("Inicio registrado: " + utc(sim.fechaInicioRealUtc));
        if (sim && utc(sim.fechaFinRealUtc)) dates.push("Fin registrado: " + utc(sim.fechaFinRealUtc));
        put("fechas-simulacion", dates.join(" · "));
        document.getElementById("fechas-simulacion").hidden = !live;
        const incidents = incidentData(event);
        let first = "Primera anotación no informada";
        if (sim && (sim.idPrimeraAnotacion !== null && sim.idPrimeraAnotacion !== undefined)) {
            const matches = incidents.rows.filter(i=>i.idIncidencia === sim.idPrimeraAnotacion);
            first = incidents.valid && safeLongId(sim.idPrimeraAnotacion) && matches.length === 1 && matches[0].tipoIncidencia === "ANOTACION"
                && matches[0].esAnulada === false && validId(sim.idPrimerParticipanteAnotador) && matches[0].idParticipante === sim.idPrimerParticipanteAnotador
                ? participantName(event,sim.idPrimerParticipanteAnotador) + " · " + duration(matches[0].segundoSimulacion) : "Primera anotación no verificable";
        } else if (sim && sim.idPrimerParticipanteAnotador !== null && sim.idPrimerParticipanteAnotador !== undefined) {
            first = "Primera anotación no verificable";
        }
        put("primera-anotacion", first);
        const result = [];
        if (event.estadoEvento === "EN_VIVO") result.push("Partido en curso.");
        else if (event.estadoEvento === "FINALIZADO") result.push("Partido finalizado según el servidor.");
        else if (event.estadoEvento === "PENDIENTE_RESULTADO") result.push("Partido con resultado pendiente.");
        if (event.resultadoPendiente === true) result.push("Resultado deportivo pendiente.");
        if (text(event.resultadoTexto)) result.push((official ? "Resultado final OFICIAL: " : "Texto del resultado consultado: ") + event.resultadoTexto);
        else if (event.resultadoPendiente !== true) result.push("Resultado oficial no informado.");
        if (text(event.estadoResultado)) result.push("Estado del resultado: " + label(event.estadoResultado));
        put("resultado-partido", result.join(" "));
        put("cantidad-incidencias", incidents.valid ? incidents.rows.length + " incidencias recibidas (incluye anuladas)" : "Cantidad no verificable");
        put("nota-incidencias", !incidents.valid ? "La cronología no está disponible o contiene datos inconsistentes. No se reconstruye el marcador."
            : incidents.duplicate ? "Se unificaron incidencias repetidas idénticas. Se conservan las anuladas."
            : !incidents.rows.length ? "No se recibieron incidencias." : "Más recientes primero, por secuencia oficial. Se conservan las anulaciones.");
        const types = {ANOTACION:"Anotación",FALTA:"Falta",TARJETA_AMARILLA:"Tarjeta amarilla",TARJETA_ROJA:"Tarjeta roja",OTRA:"Otra incidencia"};
        put("nota-recientes", !incidents.valid ? "Información de incidencias no verificable." : !incidents.rows.length ? "Sin incidencias registradas."
            : incidents.duplicate ? "Últimas incidencias; duplicados idénticos unificados." : "Más recientes primero, por secuencia oficial.");
        const recent = incidents.valid ? incidents.rows.slice(0,3).map(i=>{
            const li=node("li",i.esAnulada ? "is-annulled" : "");
            li.setAttribute("data-live-key","reciente-"+i.idIncidencia);
            li.textContent=duration(i.segundoSimulacion)+" · "+(Object.prototype.hasOwnProperty.call(types,i.tipoIncidencia)?types[i.tipoIncidencia]:label(i.tipoIncidencia))
                +(i.idParticipante===null?"":" · "+participantName(event,i.idParticipante))+(i.esAnulada?" · ANULADA":"");
            return li;
        }) : [];
        reconcile(document.getElementById("lista-recientes"),recent);
        const items = incidents.rows.map(i=>{
            const li = node("li", "incident" + (i.esAnulada ? " is-annulled" : ""));
            li.setAttribute("data-live-key", "incidencia-" + i.idIncidencia);
            li.append(node("h3", "", duration(i.segundoSimulacion) + " · " + (Object.prototype.hasOwnProperty.call(types,i.tipoIncidencia) ? types[i.tipoIncidencia] : label(i.tipoIncidencia))), node("p", "muted", "Secuencia oficial: " + i.secuencia),
                node("p", "", participantName(event,i.idParticipante)));
            if (i.tipoIncidencia === "ANOTACION" && safeCount(i.valorAnotacion)) li.append(node("p", "", "Valor de anotación informado: " + i.valorAnotacion));
            if (text(i.descripcion)) li.append(node("p", "", i.descripcion));
            if (utc(i.fechaRegistroUtc)) li.append(node("p", "muted", "Registro: " + utc(i.fechaRegistroUtc)));
            if (i.esAnulada) {
                li.append(node("p", "incident-annulment", "ANULADA · " + (text(i.motivoAnulacion) || "Motivo no informado")));
                if (utc(i.fechaAnulacionUtc)) li.append(node("p", "muted", "Anulación: " + utc(i.fechaAnulacionUtc)));
            }
            return li;
        });
        reconcile(document.getElementById("lista-incidencias"),items);
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
    function fallo(message, needsLogin = false) { const error = new Error(message); error.needsLogin = needsLogin; error.controlled = true; return error; }

    async function consultar(controller) {
        let timeout;
        let onAbort;
        try {
            const consulta = async () => {
                const query = new URLSearchParams({ idEvento: String(idEvento) });
                const response = await fetch(contextPath + "/eventos/exploracion/detalle?" + query.toString(), {
                    method: "GET", credentials: "same-origin", cache: "no-store", headers: { Accept: "application/json" }, signal: controller.signal
                });
                if (response.status === 401) { const error = fallo("Tu sesión no está disponible o ha expirado. Inicia sesión para continuar.", true); error.httpStatus = 401; throw error; }
                if (response.redirected) {
                    const target = new URL(response.url, window.location.href);
                    if (target.origin === new URL(window.location.href).origin
                            && (target.pathname === contextPath + "/usuario/login" || target.pathname === contextPath + "/usuario/login.jsp")) {
                        const error = fallo("Tu sesión ha expirado. Inicia sesión para continuar.", true);
                        error.sessionExpired = true;
                        throw error;
                    }
                    throw fallo("El servidor redirigió la consulta a una respuesta inesperada.");
                }
                if (!response.ok) {
                    const messages = {
                        400: "No se pudo consultar el evento con los datos proporcionados.",
                        403: "No tienes permiso para consultar este evento.",
                        404: "El evento solicitado no existe o ya no está disponible.",
                        409: "La información del evento cambió. Vuelve a consultar.",
                        500: "El servidor no pudo cargar el evento. Intenta nuevamente.",
                        503: "La consulta del evento no está disponible temporalmente. Intenta nuevamente."
                    };
                    const error = fallo(messages[response.status] || "No fue posible consultar el evento. Intenta nuevamente.");
                    error.httpStatus = response.status; throw error;
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
            };
            const espera = new Promise((_, reject) => {
                timeout = window.setTimeout(() => {
                    reject(fallo("La consulta tardó demasiado. Vuelve a intentar."));
                    controller.abort();
                }, 15000);
            });
            const cancelled = new Promise((_, reject)=>{
                onAbort = ()=>reject(fallo("La consulta se interrumpió."));
                controller.signal.addEventListener("abort",onAbort,{once:true});
                if (controller.signal.aborted) onAbort();
            });
            return await Promise.race([consulta(), espera, cancelled]);
        } catch (error) {
            if (error && error.controlled) throw error;
            if (error && error.name === "AbortError") throw fallo("La consulta se interrumpió. Vuelve a intentar.");
            throw fallo("No se pudo conectar con el servidor. Revisa tu conexión e intenta nuevamente.");
        } finally { window.clearTimeout(timeout); if (onAbort) controller.signal.removeEventListener("abort",onAbort); }
    }

    function participante(item) {
        const card = node("article", "participant");
        if (validId(item.idParticipante)) card.setAttribute("data-live-key", "participante-" + item.idParticipante);
        card.append(node("h3", "", text(item.participante) || "Nombre no disponible"));
        if (Number.isInteger(item.ordenParticipante)) card.append(node("p", "", "Orden: " + item.ordenParticipante));
        if (item.esLocal === true || item.esLocal === false) card.append(node("p", "", item.esLocal ? "Local" : "Visitante"));
        if (text(item.tipoParticipante)) card.append(node("p", "", label(item.tipoParticipante)));
        if (text(item.pais)) card.append(node("p", "", item.pais));
        return card;
    }
    function seleccion(item, event, market) {
        // Solo habilita la navegación cuando el servidor informa disponibilidad.
        // No calcula vigencia ni autorización personal en el cliente.
        const available = market.estadoMercado === "ABIERTO" && item.puedeSeleccionar === true && event.puedeApostar === true
                && item.seleccionActiva === true && item.cuotaActiva === true
                && validId(item.idSeleccion) && validId(item.idCuota) && decimal(item.cuota) && item.cuota > 0;
        const needsForecast = market.tipoMercado === "MARCADOR_FINAL";
        const knownType = ["CONVENCIONAL", "PRIMERA_ANOTACION", "MARCADOR_FINAL"].includes(market.tipoMercado);
        const ordered = [1,2].map(order => event.participantes.filter(p => p.ordenParticipante === order));
        const verifiedOrder = event.participantes.length === 2 && ordered.every(matches => matches.length === 1
                && validId(matches[0].idParticipante) && text(matches[0].participante))
                && ordered[0][0].idParticipante !== ordered[1][0].idParticipante;
        const occurrences = event.mercados.reduce((total, m) => total + m.selecciones.filter(s => s.idSeleccion === item.idSeleccion).length, 0);
        const canNavigate = available && knownType && validId(event.idEvento) && validId(market.idMercado) && occurrences === 1 && (!needsForecast || verifiedOrder);
        const card = node("article", "selection" + (available ? "" : " is-unavailable"));
        if (validId(item.idSeleccion)) card.setAttribute("data-live-key", "seleccion-" + item.idSeleccion);
        card.append(node("h4", "", text(item.seleccion) || "Selección sin nombre disponible"), node("p", "odd-label", "CUOTA"),
                node("p", "odd", decimal(item.cuota) ? String(item.cuota) : "No disponible"),
                node("p", "selection-status", available ? "Disponible según la consulta del servidor" : "No disponible para seleccionar"));
        const facts = node("dl", "selection-facts");
        if (validId(item.idParticipante)) {
            const matches = event.participantes.filter(participant => participant.idParticipante === item.idParticipante);
            if (matches.length === 1 && text(matches[0].participante)) fact(facts, "Participante asociado", matches[0].participante);
        }
        if (decimal(item.probabilidadImplicitaPorcentaje)) fact(facts, "Probabilidad implícita informada", String(item.probabilidadImplicitaPorcentaje) + " %");
        if (text(item.fechaInicioCuota)) fact(facts, "Inicio de vigencia", fecha(item.fechaInicioCuota));
        if (text(item.fechaFinCuota)) fact(facts, "Fin de vigencia", fecha(item.fechaFinCuota));
        if (text(item.resultadoSeleccion)) fact(facts, "Resultado", label(item.resultadoSeleccion));
        if (text(item.fechaResolucion)) fact(facts, "Resolución", fecha(item.fechaResolucion));
        card.append(facts);
        const action = node(canNavigate ? "a" : "button", "selection-action", canNavigate ? "Seleccionar cuota ↗" : available ? "Información insuficiente para continuar" : "No disponible");
        if (canNavigate) {
            action.href = contextPath + "/apuestas/realizar-apuesta.jsp?idSeleccion=" + encodeURIComponent(item.idSeleccion);
            action.href += "&idEvento=" + encodeURIComponent(event.idEvento) + "&idMercado=" + encodeURIComponent(market.idMercado);
            action.setAttribute("aria-label", "Seleccionar cuota: " + (text(item.seleccion) || "selección disponible"));
        } else { action.type = "button"; action.disabled = true; }
        if (needsForecast) action.setAttribute("aria-describedby", "aviso-modalidad-" + market.idMercado);
        card.append(action);
        return card;
    }
    function mercado(item, event) {
        const card = node("article", "panel market");
        card.setAttribute("data-live-key", "mercado-" + item.idMercado);
        const heading = node("div", "market-heading");
        const title = node("div");
        title.append(node("h3", "", text(item.mercado) || "Mercado sin nombre disponible"));
        if (text(item.descripcionMercado)) title.append(node("p", "market-description", item.descripcionMercado));
        const types = {CONVENCIONAL: "Convencional", MARCADOR_FINAL: "Marcador final", PRIMERA_ANOTACION: "Primera anotación"};
        const type = text(item.tipoMercado);
        const knownType = Object.prototype.hasOwnProperty.call(types, type);
        title.append(node("p", "market-modality", type ? "Modalidad informada: " + (knownType ? types[type] : label(type)) : "Modalidad no informada"));
        heading.append(title, node("span", "status-badge", label(item.estadoMercado)));
        card.append(heading);
        if (type === "MARCADOR_FINAL") {
            const notice = node("p", "notice modality-notice", "Esta modalidad requiere un marcador para ambos participantes. El formulario verificará el evento, la selección y el orden oficial antes de permitir cotizar. Si ese orden no puede verificarse aquí, no se habilita la navegación.");
            notice.id = "aviso-modalidad-" + item.idMercado;
            card.append(notice);
        } else if (type === "CONVENCIONAL" || type === "PRIMERA_ANOTACION") {
            card.append(node("p", "market-description", type === "PRIMERA_ANOTACION"
                ? "Esta modalidad utiliza la selección de un participante y no requiere un pronóstico numérico adicional."
                : "Esta modalidad no requiere un pronóstico numérico adicional."));
        }
        const grid = node("div", "selections-grid");
        if (!item.selecciones.length) grid.append(node("p", "empty-state", "Este mercado no tiene selecciones disponibles para mostrar."));
        else item.selecciones.forEach(itemSelection => grid.append(seleccion(itemSelection, event, item)));
        card.append(grid);
        return card;
    }
    function render(event) {
        renderLive(event);
        put("nombre-evento", text(event.nombre) || "Nombre del evento no disponible");
        put("categoria-evento", [text(event.deporte), text(event.liga)].filter(Boolean).join(" / ") || "Deporte y liga no disponibles");
        put("estado-visual", label(event.estadoVisual));
        const facts = node("dl");
        fact(facts, "Inicio", fecha(event.fechaInicio));
        fact(facts, "Cierre de apuestas", fecha(event.fechaCierreApuestas));
        fact(facts, "Estado del evento", label(event.estadoEvento));
        if (text(event.fechaFin)) fact(facts, "Fin", fecha(event.fechaFin));
        if (text(event.resultadoTexto)) fact(facts, "Resultado informado", event.resultadoTexto);
        if (text(event.estadoResultado)) fact(facts, "Estado del resultado", label(event.estadoResultado));
        reconcile(document.getElementById("ficha-evento"), [...facts.children]);
        const availability = document.getElementById("disponibilidad-evento");
        put("disponibilidad-evento", event.puedeApostar === true ? "El servidor informa que el evento admite apuestas." : event.puedeApostar === false ? "El evento no está disponible para apostar." : "Disponibilidad del evento no informada.");
        availability.classList.toggle("is-open", event.puedeApostar === true);
        const participants = document.createDocumentFragment();
        if (!event.participantes.length) participants.append(node("p", "empty-state", "Este evento no tiene participantes informados."));
        else event.participantes.forEach(item => participants.append(participante(item)));
        reconcile(document.getElementById("participantes"), [...participants.children]);
        const markets = document.createDocumentFragment();
        if (!event.mercados.length) markets.append(node("p", "panel empty-state", "Este evento no tiene mercados informados."));
        else event.mercados.forEach(item => markets.append(mercado(item, event)));
        reconcile(document.getElementById("mercados"), [...markets.children]);
    }
    function clearPoll() { window.clearTimeout(pollTimer); pollTimer = null; }
    function schedule() {
        clearPoll();
        if (disposed || !visible() || loading || !lastEvent || stopAfterError) return;
        let delay = null;
        if (lastEvent.estadoEvento === "EN_VIVO") delay = 3000;
        else if (["PROGRAMADO","PENDIENTE_RESULTADO"].includes(lastEvent.estadoEvento)
                || (lastEvent.estadoEvento === "FINALIZADO" && lastEvent.resultadoPendiente === true)) delay = 60000;
        if (delay !== null) pollTimer = window.setTimeout(()=>{pollTimer = null; cargar();},Math.max(delay, transientFailures ? Math.min(120000,10000 * 2 ** Math.min(transientFailures,4)) : 0));
    }
    async function cargar() {
        if (idEvento === null || loading || disposed || !visible()) return;
        clearPoll();
        loading = true;
        const version = ++generation;
        const controller = new AbortController(); activeController = controller;
        refresh.disabled = true;
        follow.setAttribute("aria-busy","true");
        if (!lastEvent) estado("Cargando evento…", true);
        else if (transientFailures || lastEvent.estadoEvento !== "EN_VIVO") put("estado-actualizacion", "Consultando datos oficiales; se conservan los últimos datos recibidos mientras se actualiza.");
        try {
            const event = await consultar(controller);
            if (version !== generation || disposed || !visible()) return;
            render(event); lastEvent = event; stopAfterError = false; sessionExpiredConfirmed = false; transientFailures = 0;
            statusPanel.setAttribute("aria-busy", "false");
            statusPanel.classList.remove("is-loading");
            statusPanel.hidden = true;
            content.hidden = false;
            follow.hidden = false; follow.classList.remove("is-stale");
            document.getElementById("login-actualizacion").hidden = true;
            refresh.hidden = event.estadoEvento === "EN_VIVO";
            refresh.textContent = "Actualizar partido";
            put("estado-actualizacion", event.estadoEvento === "EN_VIVO" ? "Actualización automática aproximadamente cada 3 segundos."
                : ["PROGRAMADO","PENDIENTE_RESULTADO"].includes(event.estadoEvento) || event.estadoEvento === "FINALIZADO" && event.resultadoPendiente === true ? "Datos oficiales recibidos. Consulta automática aproximadamente cada 60 segundos."
                : event.estadoEvento === "FINALIZADO" && event.resultadoPendiente === false ? "Datos oficiales recibidos. Seguimiento automático detenido: partido finalizado."
                : "Datos oficiales recibidos. Puedes actualizar el partido manualmente.");
        } catch (error) {
            if (version !== generation || disposed || !visible()) return;
            transientFailures += 1;
            refresh.hidden = false; refresh.textContent = "Reintentar actualización";
            if (error && (error.httpStatus === 401 || error.sessionExpired === true)) {
                ownSessionExpired = true;
                ownClear();
                ownState("Tu sesión ha expirado. Inicia sesión y vuelve a consultar tus apuestas.");
            }
            sessionExpiredConfirmed = sessionExpiredConfirmed || Boolean(error && (error.sessionExpired === true || error.httpStatus === 401));
            const needsLogin = sessionExpiredConfirmed || Boolean(error && error.needsLogin);
            // Una sesión expirada permanece detenida hasta recibir datos válidos,
            // incluso si un reintento manual posterior falla por un error transitorio.
            stopAfterError = stopAfterError || Boolean(error && (error.sessionExpired === true || [400,401,403,404].includes(error.httpStatus)));
            if (!lastEvent) estado(error && error.controlled ? error.message : "No fue posible cargar el evento.", false, true, needsLogin);
            else {
                follow.hidden = false; follow.classList.add("is-stale");
                // La lectura anterior conserva su valor informativo, pero no acredita disponibilidad actual.
                document.querySelectorAll("#mercados a.selection-action").forEach(action=>{
                    action.removeAttribute("href");action.setAttribute("aria-disabled","true");
                    action.setAttribute("role","button");action.setAttribute("tabindex","-1");
                    if(action.textContent!=="Actualiza para verificar disponibilidad")action.textContent="Actualiza para verificar disponibilidad";
                });
                put("estado-actualizacion", "No se pudo actualizar. Se muestran los últimos datos recibidos; pueden estar desactualizados."
                    + (needsLogin ? " Inicia sesión para continuar." : " Puedes reintentar manualmente."));
                document.getElementById("login-actualizacion").hidden = !needsLogin;
            }
        } finally {
            if (activeController === controller) {
                loading = false; activeController = null; refresh.disabled = false; follow.setAttribute("aria-busy","false");
                if (refreshPending && visible() && !disposed && !stopAfterError) { refreshPending = false; cargar(); }
                else schedule();
            }
        }
    }
    function visibilityChanged() {
        clearPoll();
        if (!visible()) {
            generation += 1; refreshPending = true;
            if (activeController) activeController.abort();
            if (lastEvent) { follow.classList.add("is-stale"); put("estado-actualizacion","Seguimiento pausado con la pestaña oculta. Se conservan los últimos datos recibidos."); }
        } else if (!disposed && !stopAfterError) {
            if (loading) refreshPending = true;
            else { refreshPending = false; cargar(); }
        }
    }
    function leave() {
        disposed = true; generation += 1; refreshPending = false; clearPoll();
        if (activeController) activeController.abort();
        document.removeEventListener("visibilitychange",visibilityChanged);
    }

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
            try { data = await response.json(); } catch (_) { throw error("La respuesta JSON no es válida."); }
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

    // Esta consulta no participa en cargar()/schedule(): nunca sigue el polling deportivo.
    const ownSection = document.getElementById("apuestas-partido");
    const ownList = document.getElementById("boletos-partido");
    const ownRetry = document.getElementById("reintentar-apuestas-partido");
    let ownController = null, ownVersion = 0, ownDisposed = false, ownSessionExpired = false;
    function ownState(message, busy = false, session = false) {
        ownList.replaceChildren();
        document.getElementById("estado-apuestas-partido").textContent = message;
        document.getElementById("login-apuestas-partido").hidden = !(session || ownSessionExpired);
        ownSection.setAttribute("aria-busy", String(busy));
        ownRetry.disabled = busy || idEvento === null;
    }
    function ownValidate(data) {
        if (data.idDeporte !== null || !Array.isArray(data.boletos) || data.cantidadBoletos !== data.boletos.length) throw new Error("El historial recibido está incompleto.");
        const seen = new Set();
        for (const ticket of data.boletos) {
            if (!object(ticket) || !validId(ticket.idBoleto) || seen.has(ticket.idBoleto) || !Array.isArray(ticket.detalles)
                    || ticket.detalles.some(d => !object(d) || !validId(d.idEvento) || !validId(d.idDetalle))) throw new Error("El historial contiene identificadores o detalles inválidos.");
            seen.add(ticket.idBoleto);
        }
    }
    function ownTicket(ticket, details) {
        const card = node("article", "own-ticket");
        card.append(node("h3", "", text(ticket.codigoBoleto) || "No informado"),
            node("p", "", "Estado oficial: " + (text(ticket.estadoBoleto) || "No informado")),
            node("p", "", "Resultado oficial: " + (text(ticket.resultado) || "No informado")));
        const selections = node("div", "own-selections");
        details.forEach(item => {
            const detail = node("article", "own-selection");
            detail.append(node("h4", "", text(item.mercado) || "Mercado: No informado"));
            const facts = node("dl", "own-facts");
            fact(facts, "Selección", text(item.nombreSeleccionAplicada) || text(item.seleccion) || "No informado");
            fact(facts, "Cuota aplicada", decimal(item.cuotaAplicada) ? String(item.cuotaAplicada) : "No informado");
            fact(facts, "Resultado de selección", text(item.resultadoSeleccion) || "No informado");
            historico(facts, item); detail.append(facts); selections.append(detail);
        });
        card.append(node("p", "muted", details.length + " selecciones de este partido. El boleto puede incluir otras selecciones."), selections);
        const pdf = node("a", "text-link", "Ver boleto PDF (otra pestaña) ↗");
        pdf.href = contextPath + "/usuario/boletos/imprimir?idBoleto=" + encodeURIComponent(ticket.idBoleto);
        pdf.target = "_blank"; pdf.rel = "noopener noreferrer"; card.append(pdf);
        return card;
    }
    async function ownLoad() {
        if (idEvento === null || ownController || ownDisposed || !visible()) return;
        const current = ++ownVersion, controller = new AbortController();
        ownController = controller; ownState("Consultando tus apuestas…", true);
        try {
            const data = await lecturaPersonal("/usuario/boletos/historial", controller);
            if (current !== ownVersion || ownDisposed || !visible()) return;
            ownValidate(data);
            ownSessionExpired = false;
            const cards = [];
            data.boletos.forEach(ticket => {
                const details = ticket.detalles.filter(d => d.idEvento === idEvento);
                if (details.length) cards.push(ownTicket(ticket, details));
            });
            ownState(cards.length ? cards.length + " boletos relacionados." : "No encontramos apuestas tuyas para este partido.");
            ownList.replaceChildren(...cards);
        } catch (e) {
            if (current === ownVersion && !ownDisposed && visible()) ownState(e.message || "No se pudo consultar el historial. Vuelve a intentar.", false, e.session === true);
        } finally {
            if (ownController === controller) { ownController = null; ownRetry.disabled = idEvento === null; ownSection.setAttribute("aria-busy", "false"); }
        }
    }
    function ownClear() {
        ownVersion += 1;
        const controller = ownController; ownController = null;
        ownState("Información personal oculta. Se consultará de nuevo al volver.");
        if (controller) controller.abort();
    }
    ownRetry.addEventListener("click", ownLoad);
    document.addEventListener("visibilitychange", () => { if (!visible()) ownClear(); else ownLoad(); });
    window.addEventListener("pagehide", () => { ownDisposed = true; ownClear(); });
    window.addEventListener("pageshow", e => { if (e.persisted && ownDisposed) { ownDisposed = false; ownLoad(); } });
    if (idEvento !== null) {
        const historyLink = document.getElementById("historial-partido");
        historyLink.href = contextPath + "/apuestas/mis-boletos.jsp?idEvento=" + encodeURIComponent(idEvento);
        historyLink.hidden = false; ownLoad();
    } else ownState("Elige un evento válido para consultar tus apuestas.");
    retry.addEventListener("click", cargar);
    refresh.addEventListener("click", cargar);
    document.addEventListener("visibilitychange",visibilityChanged);
    window.addEventListener("pagehide",leave);
    window.addEventListener("pageshow",event=>{
        if (event.persisted && disposed && idEvento !== null) {
            disposed = false; document.addEventListener("visibilitychange",visibilityChanged);
            if (!stopAfterError) { if (loading) refreshPending = true; else cargar(); }
        }
    });
    if (idEvento === null) estado("El identificador del evento falta o no es un entero positivo válido. Vuelve al listado para elegir un evento.");
    else cargar();
})();
