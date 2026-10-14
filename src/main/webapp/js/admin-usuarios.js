(() => {
    'use strict';
    const $ = id => document.getElementById(id);
    const base = document.body.dataset.contextPath || '';
    const role = (document.body.dataset.adminRole || '').trim();
    const writable = role === 'ADMINISTRADOR';
    const readable = writable || role === 'AUDITOR';
    const prefix = '/administrador/usuarios/';
    const field = (name, label, type = 'textarea', required = false) => ({name,label,type,required});
    const target = (name, label) => field(name,label,'target',true);
    const operations = [
        ['verificacion/iniciar','Iniciar revisión',[target('idVerificacion','Verificación seleccionada'),field('observacion','Observación (opcional)')]],
        ['verificacion/aprobar','Aprobar verificación',[target('idVerificacion','Verificación seleccionada'),field('observacion','Observación (opcional)')]],
        ['verificacion/rechazar','Rechazar verificación',[target('idVerificacion','Verificación seleccionada'),field('motivo','Motivo obligatorio','textarea',true)]],
        ['verificacion/reabrir','Reabrir verificación',[target('idUsuario','Usuario consultado'),field('observacion','Observación (opcional)')]],
        ['estado/cambiar','Cambiar estado de cuenta',[target('idUsuario','Usuario consultado'),field('nuevoEstado','Nuevo estado','state',true),field('motivo','Motivo (obligatorio para suspender o cerrar)')]],
        ['restricciones/agregar','Aplicar restricción',[target('idUsuario','Usuario consultado'),field('tipoRestriccion','Tipo de restricción','restriction',true),field('motivo','Motivo obligatorio','textarea',true),field('fechaFin','Fin (opcional, hora del servidor)','datetime-local')]],
        ['restricciones/levantar','Levantar restricción',[target('idRestriccion','Restricción seleccionada'),field('motivoLevantamiento','Motivo obligatorio','textarea',true)]]
    ];
    const errors = {400:'Los parámetros no son válidos.',401:'La sesión expiró. Vuelve a iniciar sesión.',403:'Acceso no permitido para esta operación.',404:'No se encontró el usuario o registro solicitado.',405:'Método no permitido.',409:'La operación no es compatible con el estado actual.',500:'El servidor no pudo procesar la solicitud.',503:'Servicio temporalmente no disponible.'};
    const labels = {idUsuario:'ID de usuario',idVerificacion:'ID de verificación',idRestriccion:'ID de restricción',estadoVerificacion:'Estado de verificación',estadoUsuario:'Estado de cuenta',correoVerificado:'Correo verificado',sinCambios:'Sin cambios',estadoAnterior:'Estado anterior',estadoActual:'Estado actual',tipoRestriccion:'Tipo de restricción',motivo:'Motivo',fechaFin:'Fecha de fin',activa:'Activa'};
    const forms = new Map(), controllers = new Set(), uncertain = new Set();
    const operationPanels = new Map(), operationButtons = new Map();
    let detail = null, busy = false, expired = false, stale = false;
    const display = value => value == null || value === '' ? '—' : typeof value === 'boolean' ? (value ? 'Sí' : 'No') : String(value);
    const identity = user => [user.nombre,user.apellido].filter(Boolean).join(' ').trim() || user.correo || 'Cuenta consultada';
    const validId = value => /^[0-9]+$/.test(String(value)) && Number(value)>0 && Number(value)<=2147483647;
    function node(tag,text,className) {const el=document.createElement(tag);if(text!==undefined)el.textContent=text;if(className)el.className=className;return el;}
    function status(text,error=false) {$('users-status').textContent=text;$('users-status').dataset.error=String(error);}
    function recordId(form,name) {return Number(form.elements.namedItem(name)?.value);}
    function latestVerification() {
        return detail?.verificaciones.reduce((latest,item)=>!latest||item.idVerificacion>latest.idVerificacion?item:latest,null);
    }
    function available(route,form) {
        if(!writable||!detail||stale||uncertain.has(detail.usuario.idUsuario))return false;
        const account=detail.usuario;
        const verification=detail.verificaciones.find(item=>item.idVerificacion===recordId(form,'idVerificacion'));
        switch(route){
            case 'verificacion/iniciar':return verification?.estadoVerificacion==='PENDIENTE';
            case 'verificacion/aprobar':case 'verificacion/rechazar':return ['PENDIENTE','EN_REVISION'].includes(verification?.estadoVerificacion);
            case 'verificacion/reabrir':return ['PENDIENTE','SUSPENDIDO'].includes(account.estadoUsuario)&&latestVerification()?.estadoVerificacion==='RECHAZADA';
            case 'estado/cambiar':return account.estadoUsuario!=='CERRADO';
            case 'restricciones/agregar':return account.estadoUsuario!=='CERRADO';
            case 'restricciones/levantar':return detail.restricciones.some(item=>item.idRestriccion===recordId(form,'idRestriccion')&&item.activa===true);
            default:return false;
        }
    }
    function sync() {
        for(const id of ['pending-form','user-query'])$(id).querySelectorAll('input,button').forEach(el=>{el.disabled=busy||expired||!readable;});
        document.querySelectorAll('[data-user-action]').forEach(el=>{el.disabled=busy||expired;});
        for(const [route,form] of forms)form.querySelector('fieldset').disabled=busy||expired||!available(route,form);
        for(const [route,button] of operationButtons)button.disabled=busy||expired||!available(route,forms.get(route));
        $('users-operation-panel').hidden=!detail||!writable||stale;
        $('users-uncertain').hidden=!uncertain.size;
        $('users-forms').setAttribute('aria-busy',String(busy));
    }
    function report(error) {
        const message=error.status?(error.serverMessage||errors[error.status]||'No fue posible procesar la solicitud.')
            :error.name==='AbortError'?'La solicitud tardó demasiado o fue interrumpida. Reintenta la consulta manualmente.'
            :error instanceof TypeError?'No fue posible conectar con el servidor.':error.message;
        status((error.status===401||error.status===403?'Servidor HTTP '+error.status+' en '+(error.endpoint||'la operación solicitada')+': ':'')+message,true);
        if(error.status===401){expired=true;$('users-login').hidden=false;}
    }
    async function api(path,options={}) {
        const controller=new AbortController();controllers.add(controller);const timer=setTimeout(()=>controller.abort(),15000);
        try{
            const response=await fetch(base+path,{credentials:'same-origin',cache:'no-store',...options,headers:{Accept:'application/json',...options.headers},signal:controller.signal});
            if(response.redirected){const error=new Error();error.status=401;error.endpoint=path.split('?')[0];throw error;}
            const raw=await response.text();let data;
            try{data=raw.trim()?JSON.parse(raw):null;}catch{data=null;}
            if(!response.ok){const error=new Error();error.status=response.status;error.endpoint=path.split('?')[0];if(data?.ok===false&&typeof data.mensaje==='string')error.serverMessage=data.mensaje;throw error;}
            if(!raw.trim())throw new Error('El servidor devolvió una respuesta vacía.');
            if(!data||data.ok!==true)throw new Error('El servidor no devolvió un JSON de éxito válido.');
            return data;
        }finally{clearTimeout(timer);controllers.delete(controller);}
    }
    function values(target,rows) {
        const dl=node('dl',undefined,'operation-values');
        rows.forEach(([label,value])=>dl.append(node('dt',label),node('dd',display(value))));target.append(dl);
    }
    function button(text,callback) {const el=node('button',text);el.type='button';el.dataset.userAction='true';el.addEventListener('click',()=>{if(!busy&&!expired)callback();});return el;}
    function table(target,caption,headings,rows) {
        const wrap=node('div',undefined,'table-scroll'),table=node('table'),thead=node('thead'),header=node('tr'),body=node('tbody');
        table.append(node('caption',caption));headings.forEach(text=>{const th=node('th',text);th.scope='col';header.append(th);});thead.append(header);table.append(thead);
        if(!rows.length){const row=node('tr'),cell=node('td','No hay registros disponibles.');cell.colSpan=headings.length;row.append(cell);body.append(row);}
        rows.forEach(cells=>{const row=node('tr');cells.forEach(value=>{const cell=node('td');if(value instanceof Node)cell.append(value);else cell.textContent=display(value);row.append(cell);});body.append(row);});
        table.append(body);wrap.append(table);target.append(wrap);
    }
    function pickVerification(id) {
        if(!detail?.verificaciones.some(item=>item.idVerificacion===id))return;
        for(const form of forms.values()){const control=form.elements.namedItem('idVerificacion');if(control)control.value=String(id);}
        const verification=detail.verificaciones.find(item=>item.idVerificacion===id);
        if(verification.estadoVerificacion==='PENDIENTE')openUserOperation('verificacion/iniciar',true);
        else if(verification.estadoVerificacion==='EN_REVISION')openUserOperation('verificacion/aprobar',true);
        else {const next=[...forms].find(([route,form])=>available(route,form));if(next)openUserOperation(next[0]);}
        status('Verificación seleccionada para '+identity(detail.usuario)+'. Revisa el estado y las observaciones antes de confirmar.');sync();
    }
    function pickRestriction(id) {
        if(!detail?.restricciones.some(item=>item.idRestriccion===id&&item.activa===true))return;
        forms.get('restricciones/levantar').elements.idRestriccion.value=String(id);openUserOperation('restricciones/levantar',true);status('Restricción seleccionada para '+identity(detail.usuario)+'. Escribe el motivo para levantarla.');sync();
    }
    function openUserOperation(route,focus=false){
        for(const [key,panel] of operationPanels)panel.hidden=key!==route;
        for(const [key,button] of operationButtons)button.setAttribute('aria-pressed',String(key===route));
        if(focus){$('users-operation-panel').hidden=false;const panel=operationPanels.get(route);panel.scrollIntoView({behavior:'smooth',block:'center'});panel.focus();}
    }
    function clearUserDisplay() {
        $('user-detail').hidden=true;
        $('users-operation-panel').hidden=true;
        $('review-data').open=false;
        for(const id of ['user-identity','user-email','user-account','user-personal','user-verifications','user-restrictions','operation-user'])$(id).replaceChildren();
    }
    function renderDetail(next) {
        const user=next.usuario;
        const changed=detail?.usuario.idUsuario!==user.idUsuario;
        if(changed){for(const form of forms.values())form.reset();$('review-data').open=false;$('users-operation-result').hidden=true;}
        detail=next;stale=false;
        $('user-id').value=String(user.idUsuario);$('user-detail').hidden=false;
        $('user-identity').textContent=identity(user);$('user-email').textContent=display(user.correo);
        $('operation-user').textContent='Cuenta seleccionada: '+identity(user)+' · '+display(user.correo);
        $('user-account').replaceChildren();
        values($('user-account'),[['Estado',user.nombreEstadoUsuario||user.estadoUsuario],['Correo verificado',user.correoVerificado],['Registro',user.fechaRegistro],['Rol',user.rol],['ID de referencia',user.idUsuario]]);
        $('user-personal').replaceChildren();
        values($('user-personal'),[['Nacimiento',user.fechaNacimiento],['Género',user.genero],['Teléfono',user.telefono],['Tipo de documento',user.tipoDocumento],['Documento',user.numeroDocumento],['País',user.pais],['Departamento',user.departamento],['Municipio',user.municipio],['Ciudad exterior',user.ciudadExterior],['Dirección',user.direccion]]);
        $('user-verifications').replaceChildren();
        table($('user-verifications'),'Verificaciones devueltas por el servidor',['Estado','Solicitud','Inicio de revisión','Resolución','Revisor','Observación','Referencia','Acción'],next.verificaciones.map(item=>[item.nombreEstadoVerificacion||item.estadoVerificacion,item.fechaSolicitud,item.fechaInicioRevision,item.fechaResolucion,item.usuarioRevisor,item.observacion,item.idVerificacion,writable?button('Seleccionar verificación',()=>pickVerification(item.idVerificacion)):'Solo consulta']));
        $('user-restrictions').replaceChildren();
        table($('user-restrictions'),'Restricciones oficiales; vigencia proporcionada por el backend',['Tipo','Motivo','Inicio','Fin','Activa','Vigente','Registrada por','Referencia','Acción'],next.restricciones.map(item=>[item.tipoRestriccion,item.motivo,item.fechaInicio,item.fechaFin,item.activa,item.vigente,item.usuarioRegistro,item.idRestriccion,writable&&item.activa?button('Seleccionar para levantar',()=>pickRestriction(item.idRestriccion)):'—']));
        for(const form of forms.values()){
            const userId=form.elements.namedItem('idUsuario');if(userId)userId.value=String(user.idUsuario);
            const verification=form.elements.namedItem('idVerificacion');if(verification&&!next.verificaciones.some(item=>item.idVerificacion===Number(verification.value)))verification.value='';
            const restriction=form.elements.namedItem('idRestriccion');if(restriction&&!next.restricciones.some(item=>item.idRestriccion===Number(restriction.value)))restriction.value='';
        }
        uncertain.delete(user.idUsuario);
        if(changed){const next=[...forms].find(([route,form])=>available(route,form));openUserOperation(next?next[0]:operations[0][0]);}
    }
    async function readDetail(id) {
        clearUserDisplay();
        const data=await api(prefix+'detalle?'+new URLSearchParams({idUsuario:String(id)}));
        const next=data.detalle;
        if(!next||next.usuario?.idUsuario!==Number(id)||next.usuario.rol!=='USUARIO'||typeof next.usuario.correo!=='string'||!Array.isArray(next.verificaciones)||!Array.isArray(next.restricciones)
            ||next.verificaciones.some(item=>!validId(item.idVerificacion))||next.restricciones.some(item=>!validId(item.idRestriccion)))throw new Error('El detalle recibido no cumple el contrato del usuario solicitado.');
        renderDetail(next);
    }
    async function consult(id) {
        if(busy||expired||!readable||!validId(id))return;
        const changed=detail&&detail.usuario.idUsuario!==Number(id);
        const drafted=[...document.querySelectorAll('#users-forms textarea, #users-forms input[type="datetime-local"], #users-forms select')].some(el=>el.value.trim());
        if(changed&&drafted&&!window.confirm('Consultar otra cuenta descartará los borradores actuales. ¿Continuar?')){status('Consulta cancelada. Actualiza el detalle de la cuenta antes de operar.',true);return;}
        $('user-id').value=String(Number(id));
        $('users-operation-result').hidden=true;
        $('users-operation-values').replaceChildren();
        clearUserDisplay();
        if(changed){for(const form of forms.values())form.reset();detail=null;}
        busy=true;stale=true;sync();status('Consultando detalle del usuario…');
        try{await readDetail(Number(id));status('Detalle actualizado. Las operaciones usan los registros oficiales mostrados.');}
        catch(error){report(error);status('No se pudo consultar el usuario #'+Number(id)+'. '+$('users-status').textContent,true);}finally{busy=false;sync();}
    }
    async function readPending() {
        $('pending-results').replaceChildren();
        const data=await api(prefix+'pendientes?'+new URLSearchParams({cantidad:$('pending-count').value}));
        if(!Array.isArray(data.usuarios)||data.usuarios.some(user=>!validId(user.idUsuario)||typeof user.correo!=='string'))throw new Error('La respuesta de pendientes no cumple el contrato.');
        table($('pending-results'),'Usuarios pendientes o en revisión',['Usuario','Correo','Estado de cuenta','Verificación','Correo verificado','Solicitud','Acción'],data.usuarios.map(user=>[identity(user),user.correo,user.estadoUsuario,user.estadoVerificacion,user.correoVerificado,user.fechaSolicitud,button('Consultar usuario',()=>consult(user.idUsuario))]));
    }
    function validateOutcome(route,result,payload,userId) {
        if(!result||Array.isArray(result)||result.idUsuario!==userId)throw new Error('Respuesta sin confirmación para la cuenta seleccionada.');
        if(route.startsWith('verificacion/')){
            if(!validId(result.idVerificacion)||typeof result.estadoVerificacion!=='string')throw new Error('Respuesta de verificación inesperada.');
            if(payload.has('idVerificacion')&&result.idVerificacion!==Number(payload.get('idVerificacion')))throw new Error('La verificación devuelta no coincide con la operación.');
        }else if(route==='estado/cambiar'){
            if(result.estadoActual!==payload.get('nuevoEstado')||typeof result.sinCambios!=='boolean')throw new Error('Respuesta de estado inesperada.');
        }else if(!validId(result.idRestriccion)||typeof result.activa!=='boolean'||(route==='restricciones/levantar'&&result.idRestriccion!==Number(payload.get('idRestriccion'))))throw new Error('Respuesta de restricción inesperada.');
    }
    function renderForms() {
        for(const [route,title,fields] of operations){
            const section=node('section',undefined,'panel');section.append(node('h3',title));
            section.id='user-operation-'+route.replaceAll('/','-');section.tabIndex=-1;operationPanels.set(route,section);
            const choice=node('button',title);choice.type='button';choice.setAttribute('aria-controls',section.id);choice.setAttribute('aria-pressed','false');choice.addEventListener('click',()=>{if(!busy&&!expired&&available(route,forms.get(route)))openUserOperation(route,true);});operationButtons.set(route,choice);$('users-flow').append(choice);
            const form=node('form',undefined,'live-form');form.dataset.operation=route;form.action=base+prefix+route;form.method='post';
            const fieldset=node('fieldset');
            for(const schema of fields){
                const label=node('label',schema.label);const select=schema.type==='state'||schema.type==='restriction';
                const input=node(select?'select':schema.type==='textarea'?'textarea':'input');input.id='user-'+route.replaceAll('/','-')+'-'+schema.name;input.name=schema.name;input.required=schema.required;label.htmlFor=input.id;
                if(schema.type==='target'){input.type='text';input.readOnly=true;input.placeholder='Selecciona un registro del detalle';label.classList.add('reference-field');}
                if(schema.type==='textarea'){input.maxLength=500;input.rows=3;}
                if(schema.type==='datetime-local'){input.type='datetime-local';input.step='1';input.min='0001-01-01T00:00:00';input.max='9999-12-31T23:59:59';}
                if(select){const options=schema.type==='state'?['PENDIENTE','ACTIVO','SUSPENDIDO','CERRADO']:['APOSTAR','TODAS_OPERACIONES'];const empty=node('option','Selecciona una opción');empty.value='';input.append(empty);for(const value of options){const item=node('option',value);item.value=value;input.append(item);}}
                label.append(input);fieldset.append(label);
            }
            if(route==='estado/cambiar')fieldset.append(node('small','El backend exige correo verificado y última verificación aprobada para activar; no permite cambiar una cuenta cerrada ni cerrarla con saldo comprometido.'));
            if(route==='verificacion/reabrir')fieldset.append(node('small','Requiere última verificación rechazada y cuenta pendiente o suspendida. Se crea una nueva solicitud; no se modifica el historial.'));
            if(route==='restricciones/agregar')fieldset.append(node('small','Fecha opcional sin conversión de zona horaria. La vigencia y los conflictos los valida el servidor.'));
            const submit=node('button',title,'primary');submit.type='submit';fieldset.append(submit);form.append(fieldset);section.append(form);$('users-forms').append(section);forms.set(route,form);
            if(route==='estado/cambiar')form.elements.nuevoEstado.addEventListener('change',()=>{form.elements.motivo.required=['SUSPENDIDO','CERRADO'].includes(form.elements.nuevoEstado.value);});
            form.addEventListener('submit',async event=>{
                event.preventDefault();if(busy||expired||!available(route,form))return;
                const userId=detail.usuario.idUsuario,payload=new URLSearchParams();
                for(const schema of fields){let value=form.elements.namedItem(schema.name).value.trim();if(schema.required&&!value){status('Completa: '+schema.label,true);return;}if(schema.type==='datetime-local'&&/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value))value+=':00';if(value)payload.set(schema.name,value);}
                if(route==='estado/cambiar'&&['SUSPENDIDO','CERRADO'].includes(payload.get('nuevoEstado'))&&!payload.get('motivo')){status('El motivo es obligatorio para suspender o cerrar.',true);return;}
                if(!window.confirm(title+' para '+identity(detail.usuario)+' ('+detail.usuario.correo+'). ¿Confirmar?'))return;
                busy=true;sync();status('Procesando operación…');let sent=false;
                $('users-operation-result').hidden=true;
                try{
                    const csrf=await api('/administrador/seguridad/csrf');if(typeof csrf.csrfToken!=='string'||!csrf.csrfToken)throw new Error('El servidor no devolvió un token CSRF válido.');
                    sent=true;const data=await api(prefix+route,{method:'POST',headers:{'X-CSRF-Token':csrf.csrfToken},body:payload});validateOutcome(route,data.resultado,payload,userId);
                    $('users-operation-values').replaceChildren();values($('users-operation-values'),Object.entries(data.resultado).filter(([key])=>Object.hasOwn(labels,key)).map(([key,value])=>[labels[key],value]));$('users-operation-result').hidden=false;
                    for(const schema of fields)if(schema.type!=='target')form.elements.namedItem(schema.name).value='';
                    if(route==='estado/cambiar')form.elements.motivo.required=false;
                    stale=true;let refreshed=true;
                    try{await readDetail(userId);if(data.resultado.idVerificacion)pickVerification(data.resultado.idVerificacion);}catch(error){refreshed=false;report(error);}
                    if(!expired){try{await readPending();}catch(error){refreshed=false;report(error);}}
                    status(title+': confirmado por el servidor.'+(refreshed?' Detalle y pendientes actualizados.':' La respuesta se conserva; no se pudo completar la actualización. Reintenta las consultas manualmente.'),!refreshed);
                }catch(error){
                    report(error);
                    if(sent&&(!error.status||error.status>=500||error.status===408)){uncertain.add(userId);stale=true;status('Operación sin confirmación. Conservamos tus campos. Consulta el detalle del mismo usuario antes de considerar un reintento.',true);}
                    else if(sent&&error.status===409)stale=true;
                }finally{busy=false;sync();}
            });
        }
    }
    $('pending-form').addEventListener('submit',async event=>{event.preventDefault();if(busy||expired||!readable)return;busy=true;sync();status('Consultando usuarios pendientes…');try{await readPending();status('Pendientes actualizados.');}catch(error){report(error);}finally{busy=false;sync();}});
    $('user-query').addEventListener('submit',event=>{event.preventDefault();consult($('user-id').value);});
    $('user-id').addEventListener('input',()=>{
        if(detail&&Number($('user-id').value)!==detail.usuario.idUsuario){stale=true;clearUserDisplay();$('users-operation-result').hidden=true;sync();}
    });
    window.addEventListener('pagehide',()=>{controllers.forEach(controller=>controller.abort());});
    renderForms();openUserOperation(operations[0][0]);sync();
    if(!['ADMINISTRADOR','OPERADOR_EVENTOS','CAJERO','AUDITOR'].includes(role)){
        status('No se pudo obtener el rol de la sesión administrativa. Vuelve a iniciar sesión. No se ha consultado el backend de usuarios.',true);
        $('users-login').hidden=false;
    }else if(!readable)status('Tu rol no tiene permiso para consultar o administrar usuarios.',true);
    const initial=new URLSearchParams(location.search).get('idUsuario');
    if(readable&&validId(initial)){$('user-id').value=initial;consult(initial);}
})();
