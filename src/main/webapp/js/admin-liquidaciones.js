(() => {
    'use strict';
    const $ = id => document.getElementById(id);
    const base = document.body.dataset.contextPath || '';
    const role = (document.body.dataset.adminRole || '').trim();
    const canOperate = role === 'ADMINISTRADOR' || role === 'CAJERO';
    const canConsult = canOperate || role === 'AUDITOR';
    const routes = {
        list: '/administrador/liquidaciones/listos',
        consult: '/administrador/liquidaciones/consultar',
        settle: '/administrador/liquidaciones/liquidar',
        csrf: '/administrador/seguridad/csrf'
    };
    const errors = {400:'Los parámetros no son válidos.',401:'La sesión expiró. Vuelve a iniciar sesión.',403:'Tu cuenta no tiene permiso para esta operación.',404:'No se encontró una liquidación consultable para ese ID. Esto no confirma que un POST anterior haya fallado.',405:'Método no permitido.',409:'La operación no corresponde al estado actual del boleto. Consulta el estado oficial.',500:'El servidor no pudo procesar la solicitud.',503:'Servicio temporalmente no disponible.'};
    const storageKey = 'betzone-admin-liquidaciones-pendientes:' + base;
    const pending = new Set();
    const confirmed = new Set();
    const ready = new Map();
    const controllers = new Set();
    let busy = false, expired = false, selected = null, storageUsable = true;
    const validId = id => /^[0-9]+$/.test(String(id)) && Number(id) > 0 && Number(id) <= 2147483647;
    try {
        const saved = JSON.parse(sessionStorage.getItem(storageKey) || '[]');
        if (!Array.isArray(saved) || saved.some(id => !validId(id))) throw new Error('invalid-storage');
        saved.forEach(id => pending.add(String(Number(id))));
    } catch { storageUsable = false; }
    function node(tag, text, className) { const el = document.createElement(tag); if (text !== undefined) el.textContent = text; if (className) el.className = className; return el; }
    const display = value => value == null || value === '' ? '—' : typeof value === 'boolean' ? (value ? 'Sí' : 'No') : String(value);
    function status(text, error = false) { $('settlement-status').textContent = text; $('settlement-status').dataset.error = String(error); }
    function sync() {
        document.querySelectorAll('#contenido button, #contenido input').forEach(el => { el.disabled = busy || expired; });
        $('ready-panel').hidden = !canOperate;
        $('settle-panel').hidden = !canOperate;
        $('settlement-query').querySelectorAll('input,button').forEach(el => { el.disabled = busy || expired || !canConsult; });
        $('settle-button').disabled = busy || expired || !canOperate || !storageUsable || !selected || !ready.has(selected) || pending.has(selected) || confirmed.has(selected);
        $('selected-ticket').textContent = selected ? 'Boleto #' + selected + (ready.has(selected) ? ' · devuelto en la lista oficial.' : ' · actualiza la lista para comprobar disponibilidad.') : 'Selecciona un boleto de la lista oficial.';
        $('uncertain-status').textContent = !storageUsable ? 'No se pudo recuperar o guardar la protección de envíos pendientes en esta pestaña. La liquidación permanece deshabilitada.'
            : pending.size ? 'Liquidación pendiente de comprobación para los IDs: ' + [...pending].join(', ') + '. Consulta cada boleto por ID antes de considerar un reintento.' : '';
        $('ready-results').setAttribute('aria-busy',String(busy));
    }
    function persistPending(next) {
        sessionStorage.setItem(storageKey,JSON.stringify([...next]));
        pending.clear(); next.forEach(id => pending.add(id));
    }
    function report(error) {
        const origin = error.status === 401 || error.status === 403 ? 'Servidor HTTP ' + error.status + ' en ' + (error.endpoint || 'la operación solicitada') + ': ' : '';
        status(origin + (error.status ? errors[error.status] || 'No fue posible procesar la solicitud.' : error.name === 'AbortError' ? 'Solicitud interrumpida o demasiado lenta.' : error instanceof TypeError ? 'No fue posible conectar con el servidor.' : error.message),true);
        if (error.status === 401) { expired = true; $('settlement-login').hidden = false; }
    }
    async function api(path, options = {}) {
        const controller = new AbortController(); controllers.add(controller);
        const timeout = setTimeout(() => controller.abort(),15000);
        try {
            const response = await fetch(base+path,{credentials:'same-origin',cache:'no-store',...options,headers:{Accept:'application/json',...options.headers},signal:controller.signal});
            if (response.redirected) { const error = new Error(); error.status = 401; error.endpoint = path.split('?')[0]; throw error; }
            if (!response.ok) { const error = new Error(); error.status = response.status; error.endpoint = path.split('?')[0]; throw error; }
            const raw = await response.text();
            if (!raw.trim()) throw new Error('El servidor devolvió una respuesta vacía.');
            let data;
            try {
                // Conservar los identificadores Long oficiales sin redondearlos al límite de Number.
                const exactIds = raw.replace(/("(?:idLiquidacion|idTransaccionUsuario|idTransaccionCasa|idTransaccion|idTransaccionDevolucionComisionUsuario)"\s*:\s*)([0-9]+)(?=\s*[,}])/g, '$1"$2"');
                data = JSON.parse(exactIds);
            } catch { throw new Error('El servidor devolvió JSON inválido.'); }
            if (!data || data.ok !== true) throw new Error('El servidor no confirmó la solicitud.');
            return data;
        } finally { clearTimeout(timeout); controllers.delete(controller); }
    }
    const labels = {
        idLiquidacion:'ID de liquidación',idBoleto:'ID del boleto',codigoBoleto:'Código del boleto',idUsuario:'ID del cliente',correo:'Correo',tipoBoleto:'Tipo de boleto',resultadoBoleto:'Resultado oficial del boleto',resultado:'Resultado oficial',estadoBoleto:'Estado del boleto',montoApostado:'Monto apostado',comisionServicio:'Comisión de servicio',totalCargo:'Total del cargo',cuotaTotal:'Cuota total',gananciaPotencial:'Ganancia potencial',montoLiquidado:'Monto liquidado',estadoLiquidacion:'Estado de liquidación',idTransaccionUsuario:'ID de transacción del cliente',idTransaccionCasa:'ID de transacción de la casa',fechaCreacion:'Fecha de creación',fechaInicioProceso:'Inicio del proceso',fechaFinalizacion:'Finalización',idUsuarioProceso:'ID del operador',usuarioProceso:'Operador',observacion:'Observación',cantidadSelecciones:'Cantidad de selecciones',seleccionesGanadas:'Selecciones ganadas',seleccionesPerdidas:'Selecciones perdidas',seleccionesAnuladas:'Selecciones anuladas',resultadoPropuesto:'Resultado propuesto por el servidor',gananciaNeta:'Ganancia neta',comisionDevuelta:'Comisión devuelta',idTransaccion:'ID de transacción',referenciaUsuario:'Referencia del cliente',idTransaccionDevolucionComisionUsuario:'ID de devolución de comisión',referenciaDevolucionComisionUsuario:'Referencia de devolución',referenciaCasa:'Referencia de la casa',usuarioDisponibleAnterior:'Disponible anterior del cliente',usuarioDisponiblePosterior:'Disponible posterior del cliente',usuarioComprometidoAnterior:'Comprometido anterior del cliente',usuarioComprometidoPosterior:'Comprometido posterior del cliente',casaDisponibleAnterior:'Disponible anterior de la casa',casaDisponiblePosterior:'Disponible posterior de la casa',solicitudIdempotente:'Solicitud idempotente'
    };
    function table(target, caption, headings, rows) {
        const wrap = node('div',undefined,'table-scroll'); const table = node('table'); table.append(node('caption',caption));
        const header = node('tr'); headings.forEach(text=>{const th=node('th',text);th.scope='col';header.append(th);});
        const thead=node('thead');thead.append(header);table.append(thead);const body=node('tbody');
        if (!rows.length) {const row=node('tr');const cell=node('td','No hay registros disponibles.');cell.colSpan=headings.length;row.append(cell);body.append(row);}
        rows.forEach(values=>{const row=node('tr');values.forEach(value=>{const cell=node('td');if(value instanceof Node)cell.append(value);else cell.textContent=display(value);row.append(cell);});body.append(row);});
        table.append(body);wrap.append(table);target.append(wrap);
    }
    function values(target, result) {
        const dl=node('dl',undefined,'operation-values');
        for(const [key,value] of Object.entries(result)) {
            if (key === 'detalles') continue;
            if (value !== null && typeof value === 'object') continue;
            dl.append(node('dt',labels[key] || key),node('dd',display(value)));
        }
        target.append(dl);
        if (Array.isArray(result.detalles)) table(target,'Detalles oficiales por modalidad',['Modalidad','Pronóstico A','Pronóstico B','Clasificación','Cuota aplicada','Cuota resultado aplicada','Cuota liquidación'],result.detalles.map(detail=>[detail.tipoMercadoAplicado,detail.pronosticoA,detail.pronosticoB,detail.clasificacionAcierto,detail.cuotaAplicada,detail.cuotaResultadoAplicada,detail.cuotaLiquidacion]));
    }
    function button(text, callback) {const el=node('button',text);el.type='button';el.addEventListener('click',()=>{if(!busy&&!expired)callback();});return el;}
    function select(id) {selected=String(id);$('ticket-id').value=selected;sync();}
    async function readList() {
        ready.clear(); $('ready-results').replaceChildren();
        const data=await api(routes.list+'?cantidad='+encodeURIComponent($('ready-count').value));
        if (!Array.isArray(data.boletos) || data.boletos.some(item=>!Number.isInteger(item.idBoleto)||item.idBoleto<=0)) throw new Error('La lista de boletos no cumple el contrato.');
        data.boletos.forEach(ticket=>ready.set(String(ticket.idBoleto),ticket));
        table($('ready-results'),'Boletos devueltos por el servidor',['ID / código','Cliente','Tipo','Apostado','Cuota total','Ganancia potencial','Selecciones (total / ganadas / perdidas / anuladas)','Propuesta oficial','Acciones'],data.boletos.map(ticket=>{
            const actions=node('div');
            actions.append(button('Seleccionar',()=>{
                select(ticket.idBoleto);$('ticket-results').replaceChildren(node('h3','Información de la lista oficial'));values($('ticket-results'),ticket);status('Boleto seleccionado. La propuesta e importes proceden del servidor.');
            }),document.createTextNode(' '),button('Consultar liquidación',()=>consult(ticket.idBoleto)));
            return [ticket.idBoleto+' / '+ticket.codigoBoleto,ticket.correo,ticket.tipoBoleto,ticket.montoApostado,ticket.cuotaTotal,ticket.gananciaPotencial,[ticket.cantidadSelecciones,ticket.seleccionesGanadas,ticket.seleccionesPerdidas,ticket.seleccionesAnuladas].map(display).join(' / '),ticket.resultadoPropuesto,actions];
        }));
    }
    async function readTicket(id) {
        $('ticket-results').replaceChildren();
        const data=await api(routes.consult+'?idBoleto='+encodeURIComponent(id));
        const result=data.resultado;
        if (!result || result.idBoleto !== Number(id) || typeof result.estadoBoleto !== 'string' || typeof result.estadoLiquidacion !== 'string' || !Array.isArray(result.detalles)) throw new Error('La consulta del boleto no cumple el contrato.');
        values($('ticket-results'),result);select(id);
        if (pending.has(String(id))) {
            const next=new Set(pending);next.delete(String(id));
            try {persistPending(next);} catch {storageUsable=false;}
        }
        return result;
    }
    async function list() {
        if(busy||expired||!canOperate)return;
        busy=true;sync();status('Consultando boletos listos…');
        try {await readList();status('Lista oficial actualizada. No se han calculado importes en el navegador.');}
        catch(error){report(error);}finally{busy=false;sync();}
    }
    async function consult(id) {
        if(busy||expired||!canConsult||!validId(id))return;
        id=String(Number(id));busy=true;sync();status('Consultando estado oficial del boleto #'+id+'…');
        try {
            await readTicket(id);
            // Tras comprobar un POST incierto se exige una lista nueva para habilitar otra solicitud.
            ready.delete(id);
            status('Consulta oficial completada. Revisa el estado mostrado. Para liquidar se exige que una nueva lista oficial incluya el boleto.');
        }catch(error){report(error);}finally{busy=false;sync();}
    }
    $('ready-form').addEventListener('submit',event=>{event.preventDefault();list();});
    $('settlement-query').addEventListener('submit',event=>{event.preventDefault();consult($('ticket-id').value);});
    $('settle-form').addEventListener('submit',async event=>{
        event.preventDefault();
        if(busy||expired||!canOperate||!selected||!ready.has(selected)||pending.has(selected)||confirmed.has(selected)||!storageUsable)return;
        const id=selected;
        const ticket=ready.get(id);
        if(!window.confirm('¿Solicitar liquidación del boleto #'+id+' ('+ticket.codigoBoleto+')? El backend aplicará el resultado y los importes oficiales.'))return;
        busy=true;sync();status('Enviando solicitud de liquidación…');let sent=false;
        $('settlement-result').hidden=true;
        try {
            const token=await api(routes.csrf);
            if(typeof token.csrfToken!=='string'||!token.csrfToken)throw new Error('No se obtuvo un token CSRF válido.');
            const next=new Set(pending);next.add(id);
            try{persistPending(next);}catch{storageUsable=false;throw new Error('No se pudo guardar la protección contra reenvíos. No se envió la liquidación.');}
            sent=true;
            const data=await api(routes.settle,{method:'POST',headers:{'X-CSRF-Token':token.csrfToken},body:new URLSearchParams({idBoleto:id})});
            const result=data.resultado;
            if(!result||result.idBoleto!==Number(id)||typeof result.estadoBoleto!=='string'||typeof result.solicitudIdempotente!=='boolean'||result.idLiquidacion==null)throw new Error('La respuesta no contiene una liquidación confirmada del boleto seleccionado.');
            confirmed.add(id);ready.delete(id);
            $('settlement-values').replaceChildren();values($('settlement-values'),result);$('settlement-result').hidden=false;
            status('Liquidación confirmada por el backend. Actualizando consulta y lista…');
            let refreshed=true;
            const refreshErrors=[];
            try{await readTicket(id);}catch(error){refreshed=false;report(error);refreshErrors.push($('settlement-status').textContent);}
            if(!expired){try{await readList();}catch(error){refreshed=false;report(error);refreshErrors.push($('settlement-status').textContent);}}
            if(refreshed)status('Liquidación confirmada. Consulta del boleto y lista oficial actualizadas.');
            else status('Liquidación confirmada; la respuesta se conserva abajo. No se pudo completar la actualización posterior. Reintenta las consultas manualmente. '+refreshErrors.join(' '),true);
        }catch(error){
            report(error);
            if(sent && (!error.status || error.status >= 500 || error.status === 408)){
                ready.delete(id);
                status('La liquidación no quedó confirmada. No se reenvió el POST. Consulta oficialmente el boleto #'+id+' antes de considerar otro envío.',true);
            } else if (sent) {
                const next=new Set(pending);next.delete(id);
                try{persistPending(next);}catch{storageUsable=false;}
            }
        }finally{busy=false;sync();}
    });
    window.addEventListener('pagehide',()=>{controllers.forEach(controller=>controller.abort());});
    sync();
    if(!['ADMINISTRADOR','OPERADOR_EVENTOS','CAJERO','AUDITOR'].includes(role)) {
        status('No se pudo obtener el rol de la sesión administrativa. Vuelve a iniciar sesión; no se consultó el backend de liquidaciones.',true);
        $('settlement-login').hidden=false;
    } else if(!canConsult)status('Tu rol no tiene permisos para consultar u operar liquidaciones.',true);
    const initial=new URLSearchParams(location.search).get('idBoleto');
    if(initial&&validId(initial)&&canConsult){$('ticket-id').value=initial;consult(initial);}
})();
