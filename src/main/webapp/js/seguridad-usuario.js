(() => {
    "use strict";
    const contextPath = window.APP_CONTEXT_PATH || "";
    const get = id => document.getElementById(id);
    const contracts = {
        cambio: {route:"cambiar-contrasena",params:["contrasenaActual","nuevaContrasena","confirmarContrasena"],flag:"contrasenaActualizada",success:"El servidor confirmó que la contraseña fue actualizada.",pending:"Actualizando contraseña…"},
        "verificar-solicitud": {route:"verificacion-correo/solicitar",params:[],success:"Solicitud procesada. Si corresponde, revisa tu correo e ingresa el código recibido.",pending:"Solicitando verificación…"},
        "verificar-confirmacion": {route:"verificacion-correo/confirmar",params:["token"],flag:"correoVerificado",success:"El servidor confirmó el código de verificación. El estado mostrado corresponde al inicio de esta sesión; puede actualizarse al volver a iniciar sesión.",pending:"Confirmando código…"},
        recuperar: {route:"recuperacion-contrasena/solicitar",params:["correo"],success:"Si el correo corresponde a una cuenta que puede recuperarse, recibirás instrucciones para restablecer la contraseña. Revisa tu correo.",pending:"Procesando solicitud…"},
        restablecer: {route:"recuperacion-contrasena/restablecer",params:["token","nuevaContrasena","confirmarContrasena"],flag:"contrasenaActualizada",success:"El servidor confirmó que la contraseña fue restablecida. Ya puedes volver a iniciar sesión.",pending:"Restableciendo contraseña…"}
    };
    const forms = Array.from(document.querySelectorAll("[data-security]"));
    const locks = new Set();
    const blank = value => /^[\u0000-\u0020]*$/.test(value);
    const group = name => name.startsWith("verificar-") ? "verificacion" : name;
    function fault(message, session = false) { const error = new Error(message); error.controlled = true; error.session = session; return error; }
    function message(name,value,state = "",session = false) {
        const element = get(name + "-mensaje");
        element.textContent = value; element.hidden = false;
        ["error","success","pending"].forEach(key => element.classList.toggle("is-" + key,key === state));
        get(name + "-login").hidden = !session;
    }
    function lock(name,busy) {
        const key = group(name);
        if (busy) locks.add(key); else locks.delete(key);
        forms.filter(form => group(form.dataset.security) === key).forEach(form => {
            form.setAttribute("aria-busy",String(busy));
            form.querySelectorAll("input,button").forEach(control => { control.disabled = busy; });
        });
    }
    function concealed(form) {
        form.querySelectorAll("[data-reveal]").forEach(button => {
            const input = get(button.dataset.reveal);
            input.type = "password"; button.textContent = "Mostrar";
            button.setAttribute("aria-pressed","false"); button.setAttribute("aria-label",button.dataset.showLabel);
        });
    }
    function clearSensitive(form) {
        form.querySelectorAll("[data-sensitive]").forEach(input => { input.value = ""; });
        concealed(form);
    }
    function validate(name) {
        const contract = contracts[name], data = new URLSearchParams();
        contract.params.forEach(key => { const field = get(name + "-" + key); field.removeAttribute("aria-invalid"); data.set(key,field.value); });
        function invalid(key,text) {
            const field = get(name + "-" + key); field.setAttribute("aria-invalid","true"); field.focus();
            message(name,text,"error"); return null;
        }
        if (contract.params.includes("correo")) {
            const correo = data.get("correo").trim();
            if (!correo || correo.length > 150 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo)) return invalid("correo","Introduce un correo electrónico válido, de hasta 150 caracteres.");
            data.set("correo",correo);
        }
        if (contract.params.includes("token")) {
            // 32 bytes en Base64URL sin padding; el último carácter conserva la forma canónica.
            const token = data.get("token").trim();
            if (!/^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$/.test(token)) return invalid("token","Pega el código completo de 43 caracteres recibido por correo.");
            data.set("token",token);
        }
        if (contract.params.includes("contrasenaActual") && blank(data.get("contrasenaActual"))) return invalid("contrasenaActual","Introduce tu contraseña actual.");
        if (contract.params.includes("nuevaContrasena")) {
            const nueva = data.get("nuevaContrasena");
            if (blank(nueva) || nueva.length < 8 || new TextEncoder().encode(nueva).length > 72) return invalid("nuevaContrasena","La nueva contraseña debe tener al menos 8 caracteres y no superar 72 bytes UTF-8.");
            if (nueva !== data.get("confirmarContrasena")) return invalid("confirmarContrasena","La confirmación debe coincidir con la nueva contraseña.");
        }
        return data;
    }
    async function post(name,body) {
        const contract = contracts[name], controller = new AbortController();
        let timedOut = false;
        const timeout = window.setTimeout(() => { timedOut = true; controller.abort(); },15000);
        try {
            const response = await fetch(contextPath + "/usuario/seguridad/" + contract.route,{
                method:"POST",credentials:"same-origin",cache:"no-store",
                headers:{"Content-Type":"application/x-www-form-urlencoded;charset=UTF-8",Accept:"application/json"},
                body:body.toString(),signal:controller.signal
            });
            if (response.status === 401) throw fault(name === "cambio" ? "No se pudo autenticar la solicitud. Comprueba tu contraseña actual; también es posible que necesites iniciar sesión nuevamente." : "La solicitud requiere una sesión válida. Vuelve a iniciar sesión.",true);
            if (response.redirected) {
                const target = new URL(response.url,window.location.href);
                const login = target.pathname === contextPath + "/usuario/login" || target.pathname === contextPath + "/usuario/login.jsp";
                throw fault(login ? "La consulta fue redirigida al login. Vuelve a iniciar sesión." : "Se recibió una redirección inesperada. No se pudo confirmar el resultado.",login);
            }
            if (!response.ok) {
                const badRequest = name === "verificar-confirmacion" ? "No fue posible confirmar el código. Puede ser inválido, haber expirado o ya haberse utilizado."
                    : name === "restablecer" ? "No fue posible restablecer la contraseña. Revisa los datos; el código puede ser inválido, haber expirado o ya haberse utilizado."
                    : "El servidor rechazó los datos proporcionados. Revísalos antes de volver a enviar.";
                const errors = {400:badRequest,403:"No tienes permiso para realizar esta operación.",404:"La operación solicitada no está disponible.",409:"El servidor rechazó la operación por un conflicto. Revisa el estado antes de repetir.",405:"El servidor no admite este método para la operación.",500:"El servidor no pudo completar la solicitud. No se pudo confirmar el resultado."};
                throw fault(errors[response.status] || "No fue posible completar la solicitud. No se pudo confirmar el resultado.");
            }
            const type = (response.headers.get("content-type") || "").split(";")[0].trim().toLowerCase();
            if (type !== "application/json") throw fault(type === "text/html" ? "Se recibió HTML en lugar de JSON. No se pudo confirmar el resultado; si tu sesión expiró, vuelve a iniciar sesión." : "El servidor devolvió un formato inesperado. No se pudo confirmar el resultado.",type === "text/html");
            let data;
            try { data = await response.json(); }
            catch (error) { if (controller.signal.aborted) throw error; throw fault("La respuesta JSON no es válida. No se pudo confirmar el resultado."); }
            if (data === null || typeof data !== "object" || Array.isArray(data) || data.ok !== true || (contract.flag && data[contract.flag] !== true)) throw fault("La respuesta del servidor tiene una estructura inesperada. No se pudo confirmar el resultado.");
        } catch (error) {
            if (timedOut) throw fault("La solicitud superó el tiempo de espera. No se pudo confirmar el resultado. Comprueba el estado antes de repetirla.");
            if (error.name === "TypeError") throw fault("No se pudo conectar con el servidor. No se pudo confirmar el resultado. Comprueba tu conexión antes de repetir.");
            throw error;
        } finally { window.clearTimeout(timeout); }
    }
    document.querySelectorAll("[data-reveal]").forEach(button => {
        button.dataset.showLabel = button.getAttribute("aria-label");
        button.addEventListener("click",() => {
            const input = get(button.dataset.reveal), show = input.type === "password";
            input.type = show ? "text" : "password"; button.textContent = show ? "Ocultar" : "Mostrar";
            button.setAttribute("aria-pressed",String(show));
            button.setAttribute("aria-label",show ? button.dataset.showLabel.replace(/^Mostrar /,"Ocultar ") : button.dataset.showLabel);
        });
    });
    forms.forEach(form => {
        const name = form.dataset.security;
        if (!contracts[name]) return;
        form.addEventListener("submit",async event => {
            event.preventDefault();
            if (locks.has(group(name))) return;
            const data = validate(name);
            if (!data) return;
            lock(name,true); message(name,contracts[name].pending,"pending");
            try {
                await post(name,data);
                clearSensitive(form); message(name,contracts[name].success,"success");
            } catch (error) {
                message(name,error.controlled ? error.message : "No fue posible completar la solicitud. No se pudo confirmar el resultado.","error",error.session === true);
            } finally { lock(name,false); }
        });
    });
    window.addEventListener("pagehide",() => forms.forEach(clearSensitive));
})();
