/* Transporte y catalogos administrativos compartidos. Nunca reintenta escrituras. */
(() => {
    'use strict';
    const base = document.body.dataset.contextPath || '';
    const messages = {400:'Revisa los datos indicados.',401:'La sesión expiró. Vuelve a iniciar sesión.',
        403:'Tu cuenta no tiene permiso para esta operación.',404:'No se encontró el recurso solicitado.',
        405:'El servidor no admite este método.',409:'La operación no corresponde al estado actual.',
        500:'El servidor no pudo confirmar la operación. Consulta su estado antes de repetirla.',
        503:'Servicio temporalmente no disponible. Verifica el estado antes de intentar nuevamente.'};
    let expired = false;
    let leaving = false;
    const controllers = new Set();
    function sessionExpired() {
        expired = true;
        controllers.forEach(controller => controller.abort());
        const content = document.getElementById('contenido');
        if (content) { content.hidden = true; content.inert = true; }
        const identity = document.querySelector('.sidebar .identity');
        if (identity) identity.hidden = true;
        let notice = document.getElementById('admin-session-notice');
        if (!notice) {
            notice = document.createElement('p');notice.id='admin-session-notice';notice.className='warning';notice.setAttribute('role','alert');
            notice.append(document.createTextNode(messages[401]+' '));
            const link=document.createElement('a');link.href=base+'/administrador/login';link.textContent='Iniciar sesión';notice.append(link);
            notice.classList.add('workspace');
            document.body.append(notice);
        }
    }
    async function request(path, options = {}, parseJson = JSON.parse) {
        if(expired){const e=new Error(messages[401]);e.status=401;throw e;}
        const controller=new AbortController();controllers.add(controller);
        const timer=setTimeout(()=>controller.abort(),options.method==='POST'?120000:20000);
        try {
            const response=await fetch(base+path,{credentials:'same-origin',cache:'no-store',...options,
                headers:{Accept:'application/json',...options.headers},signal:controller.signal});
            if(response.status===401 || (response.redirected && new URL(response.url).origin===location.origin
                    && new URL(response.url).pathname===base+'/administrador/login')) {
                sessionExpired();const e=new Error(messages[401]);e.status=401;throw e;
            }
            if(response.redirected)throw new Error('El servidor devolvió una redirección inesperada. Verifica el estado antes de repetir la operación.');
            if(!response.ok){const e=new Error(messages[response.status]||'No fue posible completar la solicitud.');e.status=response.status;throw e;}
            if(!/^application\/json\b/i.test(response.headers.get('content-type')||''))throw new Error('El servidor devolvió HTML u otro contenido inesperado; se esperaba JSON.');
            const raw=await response.text();if(!raw.trim())throw new Error('El servidor devolvió una respuesta vacía.');
            let data;
            try {
                // BIGINT permanece exacto aunque exceda Number.MAX_SAFE_INTEGER.
                const exact=raw.replace(/("(?:idLiquidacion|idTransaccion\w*|idIncidencia\w*)"\s*:\s*)([0-9]+)(?=\s*[,}])/g,(_,prefix,id)=>prefix+(Number.isSafeInteger(Number(id))?id:JSON.stringify(id)));
                // El dashboard puede preservar los decimales del JSON original sin cambiar otros consumidores.
                data=parseJson(exact);
            } catch {throw new Error('El servidor devolvió JSON inválido.');}
            if(!data||data.ok!==true)throw new Error('La respuesta no confirma la operación.');
            if(expired){const e=new Error(messages[401]);e.status=401;throw e;}
            return data;
        } catch(e) {e.endpoint=path.split('?')[0];e.cancelledByNavigation=leaving&&e.name==='AbortError';throw e;}
        finally {clearTimeout(timer);controllers.delete(controller);}
    }
    const node=(tag,text)=>{const el=document.createElement(tag);if(text!==undefined)el.textContent=text;return el;};
    const option=(value,text)=>{const el=node('option',text);el.value=String(value);return el;};
    function choices(select, rows, key, label, placeholder='Selecciona una opción') {
        select.replaceChildren(option('',placeholder));
        rows.forEach(row=>select.append(option(row[key],typeof label==='function'?label(row):row[label])));
        select.disabled=rows.length===0;
    }
    async function participants(sport, active=true) {
        const rows=[];let page=1,total;
        do {
            const data=await request('/administrador/participantes/listar?'+new URLSearchParams({idDeporte:sport,pagina:page,tamanoPagina:100,...(active?{activo:'true'}:{})}));
            if(!Array.isArray(data.participantes)||!Number.isSafeInteger(data.total)||data.total<0||data.pagina!==page
                ||data.participantes.some(p=>p.idDeporte!==Number(sport)))throw new Error('El catálogo de participantes no corresponde al deporte.');
            if(total!==undefined&&total!==data.total)throw new Error('El catálogo cambió durante la consulta. Actualízalo.');
            total=data.total;
            if(!data.participantes.length&&rows.length<total)throw new Error('El catálogo paginado está incompleto.');
            rows.push(...data.participantes);page++;
        } while(rows.length<total);
        if(rows.length!==total||new Set(rows.map(p=>p.idParticipante)).size!==rows.length)throw new Error('Catálogo de participantes inconsistente.');
        return rows;
    }
    const eventLabel=e=>[(e.participante1&&e.participante2?e.participante1+' vs '+e.participante2:e.evento||e.nombre),e.liga,(e.fechaInicio||'').replace('T',' '),e.estadoEvento].filter(Boolean).join(' · ');
    let eventPage=1,eventTotal=0,eventSize=100,pageControls=null;
    function eventsPath(sport){return '/administrador/eventos/listar?'+new URLSearchParams({idDeporte:sport,pagina:eventPage,tamanoPagina:eventSize});}
    function resetEvents(){eventPage=1;eventTotal=0;syncPages(false);}
    function pageData(data){
        if(data.pagina!==eventPage||data.tamanoPagina!==eventSize||!Number.isSafeInteger(data.total)||data.total<0)throw new Error('Pagina de eventos inconsistente.');
        eventTotal=data.total;syncPages(false);
    }
    function syncPages(blocked){if(!pageControls)return;
        pageControls.prev.disabled=blocked||eventPage<=1;pageControls.next.disabled=blocked||eventPage*eventSize>=eventTotal;
        pageControls.label.textContent='Página '+eventPage+' · '+eventTotal+' eventos';
    }
    function eventPagination(form){
        const group=node('div');group.className='toolbar';const prev=node('button','Eventos anteriores'),next=node('button','Eventos siguientes'),label=node('span');
        for(const [button,delta] of [[prev,-1],[next,1]]){button.type='button';button.addEventListener('click',()=>{if(button.disabled)return;eventPage+=delta;form.requestSubmit();});group.append(button);}
        group.append(label);form.after(group);pageControls={prev,next,label};syncPages(false);
    }
    async function csrf() {const data=await request('/administrador/seguridad/csrf');if(typeof data.csrfToken!=='string'||!data.csrfToken)throw new Error('No se obtuvo un token CSRF válido.');return data.csrfToken;}
    function navigation() {
        const role=document.body.dataset.adminRole;
        const allowed={inicio:['AUDITOR'],eventos:['OPERADOR_EVENTOS'],catalogos:['OPERADOR_EVENTOS'],mercados:['OPERADOR_EVENTOS'],
            'en-vivo':['OPERADOR_EVENTOS'],resultados:['OPERADOR_EVENTOS','AUDITOR'],liquidaciones:['CAJERO','AUDITOR'],usuarios:['AUDITOR']};
        document.querySelectorAll('.sidebar nav a').forEach(link=>{
            const target=new URL(link.href,location.href);
            const page=target.pathname.match(/\/administrador\/([^/]+)$/)?.[1];
            if(page)link.hidden=role!=='ADMINISTRADOR'&&!(allowed[page]||[]).includes(role);
            link.removeAttribute('aria-current');
            if(!link.hidden && target.origin===location.origin && target.pathname===location.pathname) {
                if(!target.hash)link.setAttribute('aria-current','page');
                else if(target.hash===(location.hash||'#resumen'))link.setAttribute('aria-current','location');
            }
        });
        if(role==='OPERADOR_EVENTOS'||role==='CAJERO'){
            const brand=document.querySelector('.sidebar .brand');if(brand)brand.href=base+'/administrador/'+(role==='CAJERO'?'liquidaciones':'eventos');
        }
    }
    window.BetZoneAdmin={request,csrf,participants,choices,option,node,eventLabel,eventsPath,eventPagination,pageData,resetEvents,syncPages,messages,sessionExpired};
    navigation();
    window.addEventListener('hashchange',navigation);
    // Ocultar antes de la instantánea BFCache; restaurar mediante el servidor y sus permisos actuales.
    window.addEventListener('pagehide',()=>{leaving=true;document.body.hidden=true;controllers.forEach(c=>c.abort());});
    window.addEventListener('pageshow',event=>{if(event.persisted)location.reload();});
})();
