(() => {
    "use strict";
    const dashboard = document.getElementById("contenido");
    if (!dashboard) return;
    const contextPath = dashboard.dataset.contextPath || "";
    const decimal = new Intl.NumberFormat("es-GT", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    const integer = new Intl.NumberFormat("es-GT", { maximumFractionDigits: 0 });

    async function consultar(ruta) {
        const controller = new AbortController();
        const timeout = window.setTimeout(() => controller.abort(), 15000);
        try {
            const response = await fetch(contextPath + ruta, {
                method: "GET", credentials: "same-origin", cache: "no-store",
                headers: { Accept: "application/json" }, signal: controller.signal
            });
            if (response.redirected || response.status === 401) {
                throw new Error("La consulta no pudo completarse con tu sesión actual. Vuelve a iniciar sesión si ha expirado.");
            }
            if (!response.ok) throw new Error("No fue posible completar la consulta. Intenta nuevamente.");
            const type = response.headers.get("content-type") || "";
            if (!type.toLowerCase().includes("application/json")) {
                throw new Error("No se recibió una respuesta válida. Si tu sesión expiró, vuelve a iniciar sesión.");
            }
            let data;
            try { data = await response.json(); }
            catch (error) { throw new Error("No se recibió una respuesta válida. Intenta nuevamente."); }
            if (!data || typeof data !== "object" || Array.isArray(data) || data.ok !== true) {
                throw new Error("No fue posible obtener los datos. Intenta nuevamente.");
            }
            return data;
        } catch (error) {
            if (error.name === "AbortError") throw new Error("La consulta está tardando demasiado. Intenta nuevamente.");
            if (error instanceof TypeError) throw new Error("No se pudo conectar con el servidor. Revisa tu conexión e intenta nuevamente.");
            throw error;
        } finally { window.clearTimeout(timeout); }
    }

    function prepararPanel(id, ruta, extraer, format, permitirNulos) {
        const panel = document.getElementById(id);
        const status = panel.querySelector(".data-status");
        const grid = panel.querySelector("dl");
        const retry = panel.querySelector(".retry");
        const fields = [...panel.querySelectorAll("[data-field]")];
        const loadingText = status.textContent;
        let loading = false;
        async function cargar() {
            if (loading) return;
            loading = true;
            panel.setAttribute("aria-busy", "true");
            grid.classList.add("is-loading");
            status.classList.remove("is-error");
            status.textContent = loadingText;
            retry.hidden = true;
            fields.forEach(field => { field.textContent = "—"; });
            try {
                const values = extraer(await consultar(ruta));
                if (!values || typeof values !== "object" || Array.isArray(values)) throw new Error("El resumen recibido no es válido. Intenta nuevamente.");
                const rendered = fields.map(field => {
                    const key = field.dataset.field;
                    if (!Object.prototype.hasOwnProperty.call(values, key)) throw new Error("El resumen recibido está incompleto. Intenta nuevamente.");
                    const value = values[key];
                    if (value === null && permitirNulos && key !== "cantidadBoletos") return "No disponible";
                    if (typeof value !== "number" || !Number.isFinite(value)
                            || (format === integer && (!Number.isSafeInteger(value) || value < 0))) {
                        throw new Error("El resumen recibido contiene valores inesperados. Intenta nuevamente.");
                    }
                    return format.format(value);
                });
                fields.forEach((field, index) => { field.textContent = rendered[index]; });
                status.textContent = "Datos consultados correctamente.";
            } catch (error) {
                status.classList.add("is-error");
                status.textContent = error.message || "No fue posible cargar este resumen. Intenta nuevamente.";
                retry.hidden = false;
            } finally {
                panel.setAttribute("aria-busy", "false");
                grid.classList.remove("is-loading");
                loading = false;
            }
        }
        retry.addEventListener("click", cargar);
        cargar();
    }
    prepararPanel("resumen-billetera", "/usuario/billetera/resumen", data => data, decimal, false);
    prepararPanel("resumen-actividad", "/usuario/analitica/resumen", data => data.resumen, integer, true);
})();
