(() => {
    "use strict";
    const contextPath = window.APP_CONTEXT_PATH || "";
    const get = id => document.getElementById(id);
    const input = get("monto"), form = get("form-cotizar"), quoteButton = get("cotizar"), confirmButton = get("confirmar");
    const panel = get("estado-apuesta"), message = get("mensaje-apuesta"), login = get("login-apuesta");
    const validId = value => Number.isInteger(value) && value > 0 && value <= 2147483647;
    const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
    const numeric = value => typeof value === "number" && Number.isFinite(value);
    const text = value => typeof value === "string" && value.trim() ? value : null;
    const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const ids = new URLSearchParams(window.location.search).getAll("idSeleccion");
    const selectionId = ids.length === 1 && /^\d+$/.test(ids[0]) && validId(Number(ids[0])) ? Number(ids[0]) : null;
    // Separa el estado local entre cuentas; nunca se envía esta identidad.
    // La autorización sigue siendo exclusivamente responsabilidad del servidor.
    const sessionScope = get("contenido").dataset.sessionUser || "sin-sesion";
    const storageKey = "betzone.apuesta.v1:" + contextPath + ":" + sessionScope + ":" + selectionId;
    let quote = null, operation = null, phase = "idle", busy = false, storageBroken = false;

    function node(tag, value) { const element = document.createElement(tag); if (value !== undefined) element.textContent = value; return element; }
    function estado(value, error = false, session = false) {
        message.textContent = value;
        panel.classList.toggle("is-error", error);
        panel.classList.toggle("is-processing", busy);
        panel.setAttribute("aria-busy", String(busy));
        login.hidden = !session;
    }
    function controls() {
        input.disabled = selectionId === null || busy || phase === "uncertain" || phase === "confirmed" || storageBroken;
        quoteButton.disabled = input.disabled;
        confirmButton.disabled = selectionId === null || busy || storageBroken || phase === "confirmed" || !(quote || phase === "uncertain");
        quoteButton.textContent = busy && phase === "quoting" ? "Cotizando…" : "Cotizar apuesta";
        confirmButton.textContent = busy && phase === "confirming" ? "Confirmando…" : phase === "uncertain" ? "Reintentar misma confirmación" : "Confirmar apuesta";
    }
    function amount() {
        const value = input.value.trim();
        if (!/^\d+(?:\.\d{1,2})?$/.test(value) || !Number.isFinite(Number(value)) || Number(value) <= 0) return null;
        const parts = value.split(".");
        return parts[0].replace(/^0+(?=\d)/, "") + "." + (parts[1] || "").padEnd(2, "0");
    }
    function persist() {
        try { window.sessionStorage.setItem(storageKey, JSON.stringify(operation)); }
        catch (error) { throw new Error("No se pudo conservar la referencia de operación en esta pestaña. No se enviará la confirmación; habilita el almacenamiento del navegador e intenta nuevamente."); }
    }
    function uuid() {
        const crypto = window.crypto;
        if (crypto && typeof crypto.randomUUID === "function") return crypto.randomUUID();
        if (!crypto || typeof crypto.getRandomValues !== "function") throw new Error("Este navegador no permite generar una referencia segura. Utiliza un navegador actualizado.");
        const bytes = crypto.getRandomValues(new Uint8Array(16));
        bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128;
        const h = Array.from(bytes, b => b.toString(16).padStart(2, "0")).join("");
        return h.slice(0,8) + "-" + h.slice(8,12) + "-" + h.slice(12,16) + "-" + h.slice(16,20) + "-" + h.slice(20);
    }
    function fault(value, definitive = false, session = false) { const error = new Error(value); error.definitive = definitive; error.session = session; return error; }
    function publicMessage(data, fallback) {
        const value = object(data) && data.ok === false && text(data.mensaje);
        return value && value.length <= 350 && !/SQLException|Exception|stack\s*trace|\bat\s+[\w.$]+\(|jdbc:|password\s*[=:]/i.test(value) ? value : fallback;
    }
    async function post(route, fields) {
        const controller = new AbortController(); let timedOut = false;
        const timeout = window.setTimeout(() => { timedOut = true; controller.abort(); }, 15000);
        try {
            const body = new URLSearchParams(fields);
            const response = await fetch(contextPath + route, { method: "POST", credentials: "same-origin", cache: "no-store",
                headers: { "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8", Accept: "application/json" }, body: body.toString(), signal: controller.signal });
            if (response.redirected) throw fault("La consulta fue redirigida. Si tu sesión expiró, inicia sesión antes de reintentar.", false, true);
            const type = (response.headers.get("content-type") || "").split(";")[0].trim().toLowerCase();
            if (type !== "application/json") throw fault("El servidor devolvió una respuesta inesperada. Si tu sesión expiró, inicia sesión.", false, type === "text/html" || response.status === 401);
            let data;
            try { data = await response.json(); }
            catch (error) { if (controller.signal.aborted) throw error; throw fault("No se pudo interpretar la respuesta JSON del servidor."); }
            if (!response.ok) {
                const messages = {400:"La solicitud fue rechazada. Revisa el monto y la selección.",401:"Tu sesión no está disponible o ha expirado. Inicia sesión.",403:"La cuenta no está habilitada para esta operación.",409:"La operación presenta un conflicto. Revisa la selección, el saldo y la referencia.",500:"El servidor no pudo completar la respuesta."};
                throw fault(publicMessage(data, messages[response.status] || "No fue posible procesar la solicitud."), object(data) && data.ok === false && [400,401,403,409].includes(response.status), response.status === 401);
            }
            if (!object(data) || data.ok !== true) throw fault("La respuesta del servidor no contiene un resultado válido.");
            return data;
        } catch (error) {
            if (timedOut) throw fault("La solicitud tardó demasiado.");
            if (error instanceof TypeError) throw fault("No se pudo conectar con el servidor.");
            if (error.name === "AbortError") throw fault("La solicitud se interrumpió.");
            throw error;
        } finally { window.clearTimeout(timeout); }
    }
    const moneyFields = ["montoApostado","comisionServicio","totalCargo","cuotaTotal","gananciaPotencial"];
    function validateSummary(data, value) {
        if (!text(data.tipoBoleto) || data.cantidadSelecciones !== 1 || moneyFields.some(key => !numeric(data[key]))
                || data.montoApostado !== Number(value) || !(data.comisionServicioPorcentaje === null || numeric(data.comisionServicioPorcentaje))) throw fault("El resumen recibido está incompleto o no corresponde al monto solicitado.");
    }
    function summary(target, data) {
        const entries = [["Tipo de boleto",data.tipoBoleto],["Selecciones",data.cantidadSelecciones],["Monto apostado",data.montoApostado],["Comisión (%)",data.comisionServicioPorcentaje],["Comisión",data.comisionServicio],["Total a cargar",data.totalCargo],["Cuota total",data.cuotaTotal],["Ganancia potencial",data.gananciaPotencial]];
        const fragment = document.createDocumentFragment();
        for (const [title,value] of entries) { const item = node("div"); if (title === "Total a cargar") item.className = "total"; item.append(node("dt",title),node("dd",value === null || value === undefined ? "No disponible" : String(value))); fragment.append(item); }
        target.replaceChildren(fragment);
    }
    function quoteView(data) {
        const detail = data.detalles[0], target = get("detalle-seleccion");
        target.replaceChildren(node("h3",text(detail.nombreSeleccion) || "Nombre no disponible"),node("p","Evento: " + (text(detail.nombreEvento) || "No disponible")),node("p","Mercado: " + (text(detail.nombreMercado) || "No disponible")),node("p","Cuota informada: " + String(detail.cuota)));
        if (validId(detail.idEvento)) { get("volver-evento").href = contextPath + "/eventos/detalle-evento.jsp?idEvento=" + encodeURIComponent(detail.idEvento); get("volver-evento").hidden = false; }
        summary(get("importes-cotizacion"),data); get("cotizacion").hidden = false; get("cotizacion-vacia").hidden = true;
    }
    function successView(data) {
        get("codigo-boleto").textContent = data.codigoBoleto;
        summary(get("importes-resultado"),data);
        const ref = node("div"); ref.append(node("dt","Referencia de operación"),node("dd",data.referenciaOperacion));
        const id = node("div"); id.append(node("dt","ID del boleto"),node("dd",String(data.idBoleto)));
        get("importes-resultado").append(id,ref);
        get("idempotencia").textContent = data.solicitudIdempotente ? "El servidor reconoció esta operación como un reintento y devolvió el boleto existente." : "El servidor confirmó una nueva apuesta.";
        get("resultado-apuesta").hidden = false;
    }
    form.addEventListener("submit", async event => {
        event.preventDefault(); if (busy || selectionId === null || phase === "uncertain" || phase === "confirmed" || storageBroken) return;
        const value = amount();
        if (!value) { get("error-monto").textContent = "Ingresa un monto mayor que cero, con punto decimal y hasta dos decimales."; input.setAttribute("aria-invalid","true"); return; }
        get("error-monto").textContent = ""; input.setAttribute("aria-invalid","false");
        quote = null; get("cotizacion").hidden = true; get("cotizacion-vacia").hidden = false;
        busy = true; phase = "quoting"; controls(); estado("Consultando cotización…");
        try {
            const data = await post("/apuestas/cotizar",{idSeleccion:String(selectionId),monto:value});
            validateSummary(data,value);
            if (!Array.isArray(data.detalles) || data.detalles.length !== 1 || !object(data.detalles[0]) || data.detalles[0].idSeleccion !== selectionId || !numeric(data.detalles[0].cuota)) throw fault("La cotización no corresponde a la selección recibida.");
            quote = {data,monto:value}; phase = "quoted"; quoteView(data); estado("Cotización lista. Revisa los importes antes de confirmar.");
        } catch (error) { phase = "idle"; estado(error.message + " Puedes volver a cotizar.",true,error.session === true); }
        finally { busy = false; panel.classList.remove("is-processing"); panel.setAttribute("aria-busy","false"); controls(); }
    });
    confirmButton.addEventListener("click", async () => {
        if (busy || selectionId === null || storageBroken || phase === "confirmed" || !(quote || phase === "uncertain")) return;
        const recovering = phase === "uncertain";
        const value = recovering ? operation.monto : quote.monto;
        if (amount() !== value) return;
        try {
            if (!operation || operation.monto !== value) operation = {idSeleccion:selectionId,monto:value,referenciaOperacion:uuid(),status:"pending"};
            operation.status = "pending"; persist();
        } catch (error) { estado(error.message,true); return; }
        busy = true; phase = "confirming"; controls(); estado("Confirmando apuesta. Espera la respuesta del servidor…");
        try {
            const data = await post("/apuestas/realizar",{idSeleccion:String(selectionId),monto:operation.monto,referenciaOperacion:operation.referenciaOperacion});
            validateSummary(data,operation.monto);
            if (!validId(data.idBoleto) || !text(data.codigoBoleto) || typeof data.solicitudIdempotente !== "boolean" || !text(data.referenciaOperacion) || data.referenciaOperacion.toLowerCase() !== operation.referenciaOperacion.toLowerCase()) throw fault("La respuesta de confirmación está incompleta o no corresponde a esta operación.");
            operation.status = "confirmed"; operation.resultado = data; phase = "confirmed";
            successView(data); estado("Apuesta confirmada. Conserva el código del boleto.");
            try { persist(); } catch (error) { estado("Apuesta confirmada. Conserva el código: no se pudo guardar el resultado en esta pestaña."); }
        } catch (error) {
            // Un rechazo del reintento (p. ej. sesión expirada) no demuestra
            // que el primer envío incierto no haya creado ya un boleto.
            const rejected = error.definitive && !recovering;
            phase = rejected ? "idle" : "uncertain";
            if (rejected) { operation.status = "rejected"; quote = null; get("cotizacion").hidden = true; get("cotizacion-vacia").hidden = false; }
            else operation.status = "pending";
            try { persist(); } catch (storageError) { /* El registro pendiente ya se guardó antes del envío. */ }
            estado(error.message + (rejected ? " Revisa los datos y vuelve a cotizar." : " El resultado es incierto: reintenta la misma confirmación con la referencia conservada; no se enviará una operación nueva."),true,error.session === true);
        } finally { busy = false; panel.classList.remove("is-processing"); panel.setAttribute("aria-busy","false"); controls(); }
    });
    input.addEventListener("input", () => {
        if (busy || phase === "uncertain" || phase === "confirmed") return;
        quote = null; phase = "idle"; get("cotizacion").hidden = true; get("cotizacion-vacia").hidden = false; get("volver-evento").hidden = true;
        get("error-monto").textContent = ""; input.setAttribute("aria-invalid","false");
        if (operation && amount() !== operation.monto) {
            try { window.sessionStorage.removeItem(storageKey); operation = null; }
            catch (error) { storageBroken = true; estado("No se pudo actualizar la referencia guardada. Recarga la página antes de continuar.",true); controls(); return; }
        }
        estado("El monto cambió. Solicita una nueva cotización."); controls();
    });
    if (selectionId === null) { estado("La selección falta o su identificador no es válido. Vuelve a Eventos para elegir una selección.",true); controls(); return; }
    get("seleccion-recibida").textContent = "Selección recibida · #" + selectionId;
    estado("Ingresa el monto para consultar el nombre, el evento, el mercado y los importes reales.");
    try {
        const saved = window.sessionStorage.getItem(storageKey);
        if (saved) {
            operation = JSON.parse(saved);
            if (!object(operation) || operation.idSeleccion !== selectionId || !text(operation.monto) || !uuidPattern.test(operation.referenciaOperacion) || !["pending","rejected","confirmed"].includes(operation.status)) throw new Error();
            input.value = operation.monto; if (amount() !== operation.monto) throw new Error();
            if (operation.status === "pending") { phase = "uncertain"; estado("Hay una confirmación pendiente de respuesta en esta pestaña. Reintenta con el mismo monto y referencia para recuperar su resultado.",true); }
            if (operation.status === "confirmed") {
                validateSummary(operation.resultado,operation.monto);
                if (!validId(operation.resultado.idBoleto) || !text(operation.resultado.codigoBoleto) || !text(operation.resultado.referenciaOperacion) || operation.resultado.referenciaOperacion.toLowerCase() !== operation.referenciaOperacion.toLowerCase()) throw new Error();
                phase = "confirmed"; successView(operation.resultado); estado("Se muestra el último resultado confirmado recibido y guardado en esta pestaña.");
            }
        }
    } catch (error) { storageBroken = true; estado("No se pudo recuperar de forma segura el estado de esta operación. No se enviarán confirmaciones nuevas desde esta página.",true); }
    controls();
})();
