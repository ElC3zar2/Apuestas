(() => {
    "use strict";
    const contextPath = window.APP_CONTEXT_PATH || "";
    const get = id => document.getElementById(id);
    const input = get("monto"), form = get("form-cotizar"), quoteButton = get("cotizar"), confirmButton = get("confirmar");
    const inputs = [input, get("pronostico-a"), get("pronostico-b")];
    const panel = get("estado-apuesta"), message = get("mensaje-apuesta"), login = get("login-apuesta");
    const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
    const numeric = value => typeof value === "number" && Number.isFinite(value);
    const text = value => typeof value === "string" && value.trim() ? value : null;
    const validId = value => Number.isInteger(value) && value > 0 && value <= 2147483647;
    const validForecast = value => Number.isInteger(value) && value >= 0 && value <= 2147483647;
    const types = {CONVENCIONAL:"Convencional", PRIMERA_ANOTACION:"Primera anotación", MARCADOR_FINAL:"Marcador final"};
    const knownType = value => typeof value === "string" && Object.prototype.hasOwnProperty.call(types, value);
    const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const params = new URLSearchParams(window.location.search);
    function navId(name) {
        const values = params.getAll(name);
        return values.length === 1 && /^\d+$/.test(values[0]) && validId(Number(values[0])) ? Number(values[0]) : null;
    }
    const selectionId = navId("idSeleccion"), eventId = navId("idEvento"), marketId = navId("idMercado");
    const invalidNav = selectionId === null || (params.has("idEvento") && eventId === null) || (params.has("idMercado") && marketId === null);
    // Se conserva la clave v1: nunca descartar una operación anterior posiblemente enviada.
    const sessionScope = get("contenido").dataset.sessionUser || "sin-sesion";
    const storageKey = "betzone.apuesta.v1:" + contextPath + ":" + sessionScope + ":" + selectionId;
    let context = null, quote = null, operation = null, phase = "idle", busy = false, blocked = false, ready = false;

    function node(tag, value) { const e = document.createElement(tag); if (value !== undefined) e.textContent = value; return e; }
    function fault(value, definitive = false, session = false) {
        const error = new Error(value); error.controlled = true; error.definitive = definitive; error.session = session; return error;
    }
    function estado(value, error = false, session = false) {
        message.textContent = value;
        panel.classList.toggle("is-error", error); panel.classList.toggle("is-processing", busy);
        panel.setAttribute("aria-busy", String(busy)); login.hidden = !session;
    }
    function controls() {
        const locked = blocked || !ready || busy || phase === "uncertain" || phase === "confirmed";
        input.disabled = locked;
        inputs.slice(1).forEach(field => { field.disabled = locked || !context || context.tipoMercado !== "MARCADOR_FINAL"; });
        quoteButton.disabled = locked;
        confirmButton.disabled = blocked || busy || phase === "confirmed" || !(quote || phase === "uncertain");
        quoteButton.textContent = busy && phase === "quoting" ? "Cotizando…" : "Cotizar apuesta";
        confirmButton.textContent = busy && phase === "confirming" ? "Confirmando…" : phase === "uncertain" ? "Reintentar misma confirmación" : "Confirmar apuesta";
    }
    function amount(value = input.value) {
        if (typeof value !== "string" || !/^\d+(?:\.\d{1,2})?$/.test(value) || value.length > 20 || !/[1-9]/.test(value)) return null;
        const parts = value.split(".");
        return parts[0].replace(/^0+(?=\d)/, "") + "." + (parts[1] || "").padEnd(2, "0");
    }
    // Normalización textual para comparar decimales, nunca para calcular dinero.
    function decimalKey(value) {
        if (typeof value !== "string") return null;
        const match = /^(\d+)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$/.exec(value);
        if (!match) return null;
        const exponent = Number(match[3] || "0");
        if (!Number.isInteger(exponent) || Math.abs(exponent) > 400) return null;
        const digits = match[1] + (match[2] || ""), point = match[1].length + exponent;
        const expanded = point <= 0 ? "0." + "0".repeat(-point) + digits
            : point >= digits.length ? digits + "0".repeat(point - digits.length)
            : digits.slice(0, point) + "." + digits.slice(point);
        const parts = expanded.split(".");
        return parts[0].replace(/^0+(?=\d)/, "") + "." + (parts[1] || "").replace(/0+$/, "");
    }
    function readJson(source) {
        const data = JSON.parse(source);
        const exact = JSON.parse(source.replace(/"(?:[^"\\]|\\.)*"|(-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)/g,
            (token, number) => number === undefined ? token : JSON.stringify(number)));
        return {data, exact};
    }
    async function request(route, fields) {
        const controller = new AbortController(); let timeout;
        try {
            const run = async () => {
                const options = {method:fields ? "POST" : "GET", credentials:"same-origin", cache:"no-store",
                    headers:{Accept:"application/json"}, signal:controller.signal};
                if (fields) {
                    options.headers["Content-Type"] = "application/x-www-form-urlencoded;charset=UTF-8";
                    options.body = new URLSearchParams(fields).toString();
                }
                const response = await fetch(contextPath + route, options);
                if (response.redirected) throw fault("La solicitud fue redirigida. Revisa tu sesión antes de reintentar.",false,true);
                if (!/^application\/json\s*(?:;|$)/i.test(response.headers.get("content-type") || "")) {
                    throw fault("El servidor devolvió un formato inesperado. No se pudo verificar el resultado.",false,response.status === 401);
                }
                let result;
                try { result = readJson(await response.text()); }
                catch (error) { throw fault("No se pudo interpretar la respuesta JSON del servidor."); }
                const data = result.data;
                if (!response.ok) {
                    const messages = {400:"La solicitud fue rechazada. Revisa selección, monto y pronósticos.",
                        401:"Tu sesión no está disponible o ha expirado. Inicia sesión.",403:"La cuenta no está habilitada para esta operación.",
                        404:"La información solicitada no está disponible.",409:"La operación presenta un conflicto; no se pudo verificar su resultado.",
                        500:"El servidor no pudo completar la respuesta.",503:"La operación no está disponible temporalmente."};
                    // 409 puede significar una referencia ya usada, no necesariamente rechazo sin boleto.
                    // Solo los rechazos concretos del contrato permiten empezar otra operación.
                    const rejected409 = object(data) && [
                        "Una o más selecciones ya no están disponibles o el periodo de apuestas cerró.",
                        "El saldo disponible es insuficiente para cubrir la apuesta y su comisión.",
                        "No fue posible aceptar la apuesta con la disponibilidad actual."
                    ].includes(data.mensaje);
                    const definitive = object(data) && data.ok === false
                        && ([400,401,403].includes(response.status) || (response.status === 409 && rejected409));
                    throw fault(messages[response.status] || "No fue posible procesar la solicitud.",definitive,response.status === 401);
                }
                if (!object(data) || data.ok !== true || ![200,201].includes(response.status)) throw fault("La respuesta del servidor no contiene un resultado válido.");
                return result;
            };
            const wait = new Promise((_, reject) => {
                timeout = window.setTimeout(() => { reject(fault("La solicitud tardó demasiado.")); controller.abort(); },15000);
            });
            return await Promise.race([run(), wait]);
        } catch (error) {
            if (error && error.controlled) throw error;
            throw fault("No se pudo conectar con el servidor. No se pudo verificar el resultado.");
        } finally { window.clearTimeout(timeout); }
    }
    function participants(event) {
        if (!Array.isArray(event.participantes) || event.participantes.length !== 2) throw fault("No se puede verificar el orden de los dos participantes. Vuelve a Eventos.");
        const ordered = [1,2].map(order => event.participantes.filter(p => object(p) && p.ordenParticipante === order));
        if (ordered.some(matches => matches.length !== 1) || ordered.some(matches => !validId(matches[0].idParticipante) || !text(matches[0].participante))
                || ordered[0][0].idParticipante === ordered[1][0].idParticipante) throw fault("El orden de los participantes es ambiguo. Vuelve a Eventos.");
        return ordered.map(matches => ({idParticipante:matches[0].idParticipante, nombre:matches[0].participante, ordenParticipante:matches[0].ordenParticipante}));
    }
    async function verifyEvent(id, expectedMarket, expectedType) {
        const {data} = await request("/eventos/exploracion/detalle?" + new URLSearchParams({idEvento:String(id)}));
        const event = data.evento;
        if (!object(event) || event.idEvento !== id || !Array.isArray(event.mercados)) throw fault("El detalle del evento no es válido. Vuelve a Eventos.");
        const matches = [];
        for (const market of event.mercados) {
            if (!object(market) || !validId(market.idMercado) || !Array.isArray(market.selecciones)) throw fault("El detalle de mercados está incompleto.");
            for (const selection of market.selecciones) if (object(selection) && selection.idSeleccion === selectionId) matches.push({market,selection});
        }
        if (matches.length !== 1) throw fault("La selección no pertenece inequívocamente al evento. Vuelve a Eventos.");
        const {market,selection} = matches[0];
        if (!knownType(market.tipoMercado) || (expectedMarket !== null && market.idMercado !== expectedMarket)
                || (expectedType && market.tipoMercado !== expectedType)) throw fault("No se pudo verificar la modalidad y el mercado de la selección. Vuelve a Eventos.");
        if (event.puedeApostar !== true || selection.puedeSeleccionar !== true || selection.seleccionActiva !== true
                || selection.cuotaActiva !== true || !validId(selection.idCuota) || !numeric(selection.cuota) || selection.cuota <= 0) {
            throw fault("La selección no está disponible según la consulta del servidor. Vuelve a Eventos.");
        }
        return {idEvento:id,idMercado:market.idMercado,tipoMercado:market.tipoMercado,
            participantes:market.tipoMercado === "MARCADOR_FINAL" ? participants(event) : [],
            nombreSeleccion:text(selection.seleccion) || "Selección", nombreMercado:text(market.mercado) || "Mercado"};
    }
    function showContext() {
        get("pronosticos").hidden = !context || context.tipoMercado !== "MARCADOR_FINAL";
        if (!context) return;
        get("seleccion-recibida").textContent = (context.nombreSeleccion || "Selección verificada") + " · " + types[context.tipoMercado];
        get("volver-evento").href = contextPath + "/eventos/detalle-evento.jsp?idEvento=" + encodeURIComponent(context.idEvento);
        get("volver-evento").hidden = false;
        if (context.tipoMercado === "MARCADOR_FINAL") {
            get("nombre-participante-a").textContent = "A · " + context.participantes[0].nombre;
            get("nombre-participante-b").textContent = "B · " + context.participantes[1].nombre;
        }
    }
    function forecast(field) {
        const value = field.value;
        return /^\d{1,10}$/.test(value) && validForecast(Number(value)) ? Number(value) : null;
    }
    function snapshot(showErrors = false) {
        const monto = amount();
        if (showErrors) {
            get("error-monto").textContent = monto === null ? "Ingresa un monto mayor que cero, con punto y hasta dos decimales." : "";
            input.setAttribute("aria-invalid",String(monto === null));
        }
        let a = null, b = null;
        if (context && context.tipoMercado === "MARCADOR_FINAL") {
            [a,b] = inputs.slice(1).map((field,index) => {
                const value = forecast(field);
                if (showErrors) {
                    get(index === 0 ? "error-pronostico-a" : "error-pronostico-b").textContent = value === null ? "Introduce un entero de 0 a 2147483647." : "";
                    field.setAttribute("aria-invalid",String(value === null));
                }
                return value;
            });
            if (a === null || b === null) return null;
        }
        return monto === null ? null : {idSeleccion:selectionId,monto,pronosticoA:a,pronosticoB:b};
    }
    function same(a,b) {
        return a && b && a.idSeleccion === b.idSeleccion && a.monto === b.monto
            && a.pronosticoA === b.pronosticoA && a.pronosticoB === b.pronosticoB;
    }
    function fieldsFor(value) {
        const fields = {idSeleccion:String(value.idSeleccion),monto:value.monto};
        if (value.pronosticoA !== null) { fields.pronosticoA = String(value.pronosticoA); fields.pronosticoB = String(value.pronosticoB); }
        return fields;
    }
    function clearQuote() {
        quote = null; get("cotizacion").hidden = true; get("cotizacion-vacia").hidden = false;
        get("importes-cotizacion").replaceChildren(); get("detalle-seleccion").replaceChildren();
    }
    const moneyFields = ["montoApostado","comisionServicio","totalCargo","cuotaTotal","gananciaPotencial"];
    const validExact = (value, original) => typeof original === "string"
        && /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$/.test(original) && Number(original) === value;
    function validateSummary(result,value) {
        const {data,exact} = result;
        if (!object(data) || data.ok !== true || !object(exact) || data.tipoBoleto !== "SIMPLE" || data.cantidadSelecciones !== 1
                || moneyFields.some(k => !numeric(data[k]) || (k !== "gananciaPotencial" && data[k] < 0) || !validExact(data[k],exact[k]))
                || decimalKey(exact.montoApostado) !== decimalKey(value.monto)
                || !(data.comisionServicioPorcentaje === null || (numeric(data.comisionServicioPorcentaje) && data.comisionServicioPorcentaje >= 0
                    && validExact(data.comisionServicioPorcentaje,exact.comisionServicioPorcentaje)))) {
            throw fault("El resumen oficial está incompleto o no corresponde al monto solicitado.");
        }
    }
    function validateQuote(result,value) {
        validateSummary(result,value);
        const d = result.data, detail = Array.isArray(d.detalles) && d.detalles.length === 1 ? d.detalles[0] : null;
        if (!knownType(d.tipoMercado) || !object(detail) || detail.idSeleccion !== selectionId || !validId(detail.idEvento)
                || !validId(detail.idMercado) || !validId(detail.idCuota) || !numeric(detail.cuota) || detail.cuota <= 0
                || (context && (context.tipoMercado !== d.tipoMercado || context.idEvento !== detail.idEvento || context.idMercado !== detail.idMercado))
                || (eventId !== null && eventId !== detail.idEvento) || (marketId !== null && marketId !== detail.idMercado)) throw fault("La cotización no corresponde a la selección, evento o modalidad.");
        if (d.tipoMercado === "MARCADOR_FINAL") {
            if (!context || value.pronosticoA === null || d.pronosticoA !== value.pronosticoA || d.pronosticoB !== value.pronosticoB) throw fault("La cotización no corresponde al pronóstico solicitado. Vuelve a Eventos si falta información.");
        } else if (value.pronosticoA !== null || d.pronosticoA !== null || d.pronosticoB !== null) throw fault("La cotización incluye pronósticos incompatibles con la modalidad.");
        for (const k of ["cuotaResultado","premioResultadoPotencial","premioExactoOMaximo"]) {
            if (!(d[k] === null || (numeric(d[k]) && d[k] >= 0 && typeof result.exact[k] === "string"))) throw fault("Los importes adicionales de la cotización son inválidos.");
        }
        return detail;
    }
    function summary(target,result,quoteResult = false) {
        const d = result.data, exact = result.exact;
        const entries = [["Tipo de boleto",d.tipoBoleto],["Selecciones",String(d.cantidadSelecciones)],
            ["Monto apostado",exact.montoApostado],["Comisión (%)",d.comisionServicioPorcentaje === null ? null : exact.comisionServicioPorcentaje],
            ["Comisión",exact.comisionServicio],["Total a cargar",exact.totalCargo],["Cuota total",exact.cuotaTotal],["Ganancia potencial",exact.gananciaPotencial]];
        if (quoteResult && d.tipoMercado === "MARCADOR_FINAL") entries.push(
            ["Cuota por resultado",d.cuotaResultado === null ? null : exact.cuotaResultado],
            ["Premio potencial por resultado",d.premioResultadoPotencial === null ? null : exact.premioResultadoPotencial],
            ["Premio exacto o máximo potencial",d.premioExactoOMaximo === null ? null : exact.premioExactoOMaximo]);
        const fragment = document.createDocumentFragment();
        for (const [title,value] of entries) {
            const item = node("div"); if (title === "Total a cargar") item.className = "total";
            item.append(node("dt",title),node("dd",value === null ? "No disponible" : value)); fragment.append(item);
        }
        target.replaceChildren(fragment);
    }
    function quoteView(result) {
        const d = result.data, detail = d.detalles[0];
        const target = get("detalle-seleccion");
        target.replaceChildren(node("h3",text(detail.nombreSeleccion) || "Selección"),
            node("p","Evento: " + (text(detail.nombreEvento) || "No disponible")),
            node("p","Mercado: " + (text(detail.nombreMercado) || "No disponible")),
            node("p","Modalidad: " + types[d.tipoMercado]),node("p","Cuota informada: " + result.exact.detalles[0].cuota));
        if (d.tipoMercado === "MARCADOR_FINAL") target.append(node("p",context.participantes[0].nombre + ": " + d.pronosticoA),
            node("p",context.participantes[1].nombre + ": " + d.pronosticoB));
        summary(get("importes-cotizacion"),result,true); get("cotizacion").hidden = false; get("cotizacion-vacia").hidden = true;
    }
    function validateConfirmation(result,value,reference) {
        validateSummary(result,value);
        const d = result.data;
        if (!validId(d.idBoleto) || !text(d.codigoBoleto) || typeof d.solicitudIdempotente !== "boolean"
                || !text(d.referenciaOperacion) || d.referenciaOperacion.toLowerCase() !== reference.toLowerCase()) throw fault("La confirmación recibida no permite verificar esta operación.");
    }
    function successView(result,cached = false) {
        const d = result.data;
        get("codigo-boleto").textContent = d.codigoBoleto; summary(get("importes-resultado"),result);
        const reference = node("div"); reference.append(node("dt","Referencia de operación"),node("dd",d.referenciaOperacion));
        get("importes-resultado").append(reference);
        get("idempotencia").textContent = cached ? "Resultado recibido anteriormente y guardado en esta pestaña; no es una nueva confirmación del servidor."
            : d.solicitudIdempotente ? "El servidor devolvió el boleto existente para esta misma operación; no informa un nuevo cobro."
            : "El servidor confirmó el boleto. Esto no es un resultado deportivo ni una liquidación.";
        get("resultado-apuesta").hidden = false;
    }
    function uuid() {
        const crypto = window.crypto;
        if (crypto && typeof crypto.randomUUID === "function") return crypto.randomUUID();
        if (!crypto || typeof crypto.getRandomValues !== "function") throw fault("El navegador no permite generar una referencia segura.");
        const bytes = crypto.getRandomValues(new Uint8Array(16)); bytes[6] = (bytes[6]&15)|64; bytes[8] = (bytes[8]&63)|128;
        const h = Array.from(bytes,b=>b.toString(16).padStart(2,"0")).join("");
        return h.slice(0,8)+"-"+h.slice(8,12)+"-"+h.slice(12,16)+"-"+h.slice(16,20)+"-"+h.slice(20);
    }
    function persist() {
        try {
            const saved = JSON.stringify(operation);
            window.sessionStorage.setItem(storageKey,saved);
            if (window.sessionStorage.getItem(storageKey) !== saved) throw new Error();
        } catch (error) { throw fault("No se pudo conservar la operación antes del envío. No se enviará una confirmación nueva."); }
    }
    form.addEventListener("submit",async event => {
        event.preventDefault();
        if (busy || blocked || !ready || phase === "uncertain" || phase === "confirmed") return;
        const value = snapshot(true); clearQuote(); controls();
        if (!value) return;
        busy = true; phase = "quoting"; controls(); estado("Consultando cotización oficial…");
        try {
            const result = await request("/apuestas/cotizar",fieldsFor(value));
            const detail = validateQuote(result,value);
            // Enlaces antiguos: la cotización identifica el evento, el GET confirma su asociación.
            if (!context) {
                context = await verifyEvent(detail.idEvento,detail.idMercado,result.data.tipoMercado); showContext();
                if (context.tipoMercado === "MARCADOR_FINAL") throw fault("Vuelve a Eventos para introducir un pronóstico verificado.");
            }
            if (!same(snapshot(),value)) throw fault("Los datos cambiaron durante la consulta. Solicita otra cotización.");
            quote = {result,value}; phase = "quoted"; quoteView(result);
            estado("Cotización lista. Revisa los importes potenciales antes de confirmar; todavía no se ha registrado una apuesta.");
        } catch (error) { phase = "idle"; clearQuote(); estado((error.controlled ? error.message : "No fue posible cotizar.") + " Puedes volver a cotizar.",true,Boolean(error.session)); }
        finally { busy = false; controls(); panel.setAttribute("aria-busy","false"); panel.classList.remove("is-processing"); }
    });
    confirmButton.addEventListener("click",async () => {
        if (busy || blocked || phase === "confirmed" || !(quote || phase === "uncertain")) return;
        const recovering = phase === "uncertain";
        const value = recovering ? operation : quote.value;
        if (!same(snapshot(),value)) { estado("Los datos actuales no coinciden con la operación. No se enviará la confirmación.",true); return; }
        try {
            if (!recovering) operation = {version:2,...value,...context,referenciaOperacion:uuid(),status:"pending"};
            persist();
        } catch (error) { estado(error.controlled ? error.message : "No se pudo preparar la operación.",true); return; }
        busy = true; phase = "confirming"; controls(); estado("Confirmando apuesta. Espera la respuesta del servidor…");
        try {
            const fields = fieldsFor(operation); fields.referenciaOperacion = operation.referenciaOperacion;
            const result = await request("/apuestas/realizar",fields);
            validateConfirmation(result,operation,operation.referenciaOperacion);
            operation.status = "confirmed"; operation.resultado = result.data; operation.resultadoExacto = result.exact; phase = "confirmed";
            successView(result); estado("Boleto confirmado. Conserva el código y la referencia.");
            try { persist(); } catch (error) { estado("Boleto confirmado. Conserva el código: no se pudo guardar el resultado; la referencia previa permanece pendiente."); }
        } catch (error) {
            const rejected = error.definitive === true && !recovering;
            operation.status = rejected ? "rejected" : "pending"; phase = rejected ? "idle" : "uncertain";
            clearQuote();
            try { persist(); } catch (storageError) { /* La operación original ya se guardó antes de enviar. */ }
            estado((error.controlled ? error.message : "No se pudo verificar la respuesta.") + (rejected
                ? " El servidor rechazó la solicitud. Revisa los datos y vuelve a cotizar."
                : " Resultado incierto: conserva esta referencia y reintenta únicamente la misma operación."),true,Boolean(error.session));
        } finally { busy = false; controls(); panel.setAttribute("aria-busy","false"); panel.classList.remove("is-processing"); }
    });
    inputs.forEach(field => field.addEventListener("input",() => {
        if (busy || blocked || phase === "uncertain" || phase === "confirmed") return;
        clearQuote(); phase = "idle"; inputs.forEach(e=>e.setAttribute("aria-invalid","false"));
        ["error-monto","error-pronostico-a","error-pronostico-b"].forEach(id=>{get(id).textContent="";});
        // Nunca borrar una referencia pendiente. Un nuevo envío válido obtiene su propio UUID.
        estado("Los datos cambiaron. Solicita una nueva cotización."); controls();
    }));
    function restore() {
        const saved = window.sessionStorage.getItem(storageKey);
        if (!saved) return false;
        operation = JSON.parse(saved);
        if (!object(operation) || operation.idSeleccion !== selectionId || typeof operation.referenciaOperacion !== "string"
                || !uuidPattern.test(operation.referenciaOperacion) || !["pending","rejected","confirmed"].includes(operation.status)
                || amount(operation.monto) !== operation.monto) throw new Error();
        const legacy = operation.version === undefined || operation.version === 1;
        if (legacy) {
            if ("tipoMercado" in operation || (operation.version === undefined && ("pronosticoA" in operation || "pronosticoB" in operation))
                    || (operation.version === 1 && (operation.pronosticoA !== null || operation.pronosticoB !== null))) throw new Error();
            operation.version = 1;
            operation.pronosticoA = null; operation.pronosticoB = null;
        } else {
            if (operation.version !== 2 || !knownType(operation.tipoMercado) || !validId(operation.idEvento) || !validId(operation.idMercado)
                    || (eventId !== null && eventId !== operation.idEvento) || (marketId !== null && marketId !== operation.idMercado)) throw new Error();
            if (operation.tipoMercado === "MARCADOR_FINAL") {
                if (!validForecast(operation.pronosticoA) || !validForecast(operation.pronosticoB)) throw new Error();
                const p = operation.participantes;
                if (!Array.isArray(p) || p.length !== 2 || p.some((v,i)=>!object(v)||!validId(v.idParticipante)||v.ordenParticipante!==i+1||!text(v.nombre))
                        || p[0].idParticipante === p[1].idParticipante) throw new Error();
            } else if (operation.pronosticoA !== null || operation.pronosticoB !== null) throw new Error();
        }
        input.value = operation.monto;
        if (!legacy) { context = operation; showContext(); }
        if (operation.pronosticoA !== null) { inputs[1].value = String(operation.pronosticoA); inputs[2].value = String(operation.pronosticoB); }
        if (operation.status === "pending") {
            ready = true; phase = "uncertain";
            estado("Hay una confirmación pendiente. Solo puedes reintentar sus mismos datos y referencia; no se creará otra operación.",true);
            return true;
        }
        if (operation.status === "confirmed") {
            const result = {data:operation.resultado,exact:operation.resultadoExacto || readJson(JSON.stringify(operation.resultado)).exact};
            validateConfirmation(result,operation,operation.referenciaOperacion);
            phase = "confirmed"; ready = true; successView(result,true);
            estado("Se muestra un resultado guardado anteriormente en esta pestaña.");
            return true;
        }
        return false;
    }
    async function initialize() {
        get("reintentar-contexto").hidden = true; busy = true; ready = false; controls(); estado("Verificando la selección y su modalidad…");
        try {
            context = eventId !== null ? await verifyEvent(eventId,marketId) : null;
            if (context) showContext();
            ready = true; estado(context ? "Selección verificada. Introduce el monto y, si corresponde, tu pronóstico."
                : "Enlace anterior: la cotización debe identificar una modalidad compatible. Si requiere marcador final, vuelve a Eventos.");
        } catch (error) { estado(error.controlled ? error.message : "No se pudo verificar la selección. Vuelve a Eventos.",true,Boolean(error.session)); get("reintentar-contexto").hidden = false; }
        finally { busy = false; controls(); panel.setAttribute("aria-busy","false"); panel.classList.remove("is-processing"); }
    }
    get("reintentar-contexto").addEventListener("click",()=>{if(!busy&&!blocked&&phase!=="uncertain"&&phase!=="confirmed")initialize();});
    if (invalidNav) { blocked = true; estado("Los identificadores faltan, están duplicados o no son válidos. Vuelve a Eventos.",true); controls(); return; }
    try { if (restore()) { controls(); return; } }
    catch (error) { blocked = true; estado("No se pudo recuperar con seguridad la operación guardada. Se bloquean nuevas confirmaciones; conserva la pestaña y solicita revisión.",true); controls(); return; }
    initialize();
})();
