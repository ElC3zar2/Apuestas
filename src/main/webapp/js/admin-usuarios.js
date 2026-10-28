(() => {
    'use strict';
    const $ = id => document.getElementById(id);
    const base = document.body.dataset.contextPath || '';
    const role = (document.body.dataset.adminRole || '').trim();
    const writable = role === 'ADMINISTRADOR';
    const readable = writable || role === 'AUDITOR';
    // Disponibilidad visual; cada escritura sigue autorizada por sesion, CSRF y backend.
    const approvalsEnabled = true;
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
    const batchSelection = new Map(), batchChecks = new Map();
    const batchStates = {activo:'Aprobado y ACTIVO',correo:'Aprobado, pendiente de correo',
        suspendido:'Aprobado, cuenta SUSPENDIDA (sin reactivación)',omitido:'Omitido por cambio de estado',
        rechazado:'Rechazado por el backend',incierto:'Resultado incierto',pendiente:'No procesado'};
    let pendingRows = [], batchResults = null, batchRunning = false, batchStopped = false;
    let detail = null, busy = false, expired = false, stale = false, searchPage=1, searchTotal=0, searchText="";
    let leaving = false, searchRevision = 0, searchValid = false;
    const live = () => !leaving && !expired && !$('contenido').hidden;
    const display = value => value == null ? 'No disponible' : value === '' ? 'Vacío' : typeof value === 'boolean' ? (value ? 'Sí' : 'No')
        : typeof value === 'string' ? value.replace(/^(\d{4}-\d{2}-\d{2})T/, '$1 ') : typeof value === 'number' && Number.isFinite(value) ? String(value) : 'No disponible';
    const identity = user => [user.nombre,user.apellido].filter(Boolean).join(' ').trim() || user.correo || 'Cuenta consultada';
    const validId = value => /^[0-9]+$/.test(String(value)) && Number(value)>0 && Number(value)<=2147483647;
    function node(tag,text,className) {const el=document.createElement(tag);if(text!==undefined)el.textContent=text;if(className)el.className=className;return el;}
    function status(text,error=false) {if(leaving)return;$('users-status').textContent=text;$('users-status').dataset.error=String(error);}
    function recordId(form,name) {return Number(form.elements.namedItem(name)?.value);}
    function latestVerification() {
        // El procedimiento oficial selecciona TOP(1) ORDER BY IdVerificacion DESC.
        return detail?.verificaciones.reduce((latest,item)=>!latest||item.idVerificacion>latest.idVerificacion?item:latest,null);
    }
    function available(route,form) {
        if(!writable||!detail||stale||uncertain.has(detail.usuario.idUsuario))return false;
        const account=detail.usuario;
        const verification=detail.verificaciones.find(item=>item.idVerificacion===recordId(form,'idVerificacion'));
        switch(route){
            case 'verificacion/iniciar':return verification?.estadoVerificacion==='PENDIENTE';
            case 'verificacion/aprobar':return approvalsEnabled&&verification?.estadoVerificacion==='EN_REVISION'&&account.estadoUsuario!=='CERRADO';
            case 'verificacion/rechazar':return ['PENDIENTE','EN_REVISION'].includes(verification?.estadoVerificacion);
            case 'verificacion/reabrir':return ['PENDIENTE','SUSPENDIDO'].includes(account.estadoUsuario)&&latestVerification()?.estadoVerificacion==='RECHAZADA';
            case 'estado/cambiar':return account.estadoUsuario!=='CERRADO';
            case 'restricciones/agregar':return account.estadoUsuario!=='CERRADO';
            case 'restricciones/levantar':return detail.restricciones.some(item=>item.idRestriccion===recordId(form,'idRestriccion')&&item.activa===true);
            default:return false;
        }
    }
    function sync() {
        if(leaving)return;
        for(const id of ['pending-form','user-query','user-search'])$(id).querySelectorAll('input,button,select').forEach(el=>{el.disabled=busy||expired||!readable;});
        document.querySelectorAll('[data-user-action]').forEach(el=>{el.disabled=busy||expired;});
        for(const [route,form] of forms)form.querySelector('fieldset').disabled=busy||expired||!available(route,form);
        for(const [route,button] of operationButtons)button.disabled=busy||expired||!available(route,forms.get(route));
        $('users-operation-panel').hidden=!detail||!writable||stale;
        $('users-uncertain').hidden=!uncertain.size;
        $('users-prev').disabled=busy||expired||!readable||!searchValid||searchPage<=1;
        $('users-next').disabled=busy||expired||!readable||!searchValid||searchPage*50>=searchTotal;
        $('users-forms').setAttribute('aria-busy',String(busy));
        syncBatch();
    }
    function report(error) {
        if(leaving)return;
        const message=error.status?(errors[error.status]||'No fue posible procesar la solicitud.')
            :error.name==='AbortError'?'La solicitud tardó demasiado o fue interrumpida. Reintenta la consulta manualmente.'
            :error instanceof TypeError?'No fue posible conectar con el servidor.':error.message;
        status(message,true);
        if(error.status===401){expired=true;$('users-login').hidden=false;}
    }
    async function api(path, options = {}) {
        if(!live())throw new DOMException('Consulta interrumpida.','AbortError');
        const data=await window.BetZoneAdmin.request(path, options);
        if(!live())throw new DOMException('Consulta interrumpida.','AbortError');
        return data;
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
        table.append(body);wrap.append(table);wrap.tabIndex=0;wrap.setAttribute('role','region');wrap.setAttribute('aria-label',caption);target.append(wrap);
    }
    function pickVerification(id) {
        if(!detail?.verificaciones.some(item=>item.idVerificacion===id))return;
        for(const form of forms.values()){const control=form.elements.namedItem('idVerificacion');if(control)control.value=String(id);}
        const verification=detail.verificaciones.find(item=>item.idVerificacion===id);
        if(verification.estadoVerificacion==='PENDIENTE')openUserOperation('verificacion/iniciar',true);
        else if(verification.estadoVerificacion==='EN_REVISION')openUserOperation(approvalsEnabled?'verificacion/aprobar':'verificacion/rechazar',true);
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
        values($('user-account'),[['Estado de cuenta',user.estadoUsuario],['Correo verificado',user.correoVerificado],['Última verificación administrativa',latestVerification()?.estadoVerificacion],['Restricciones vigentes',next.restricciones.filter(item=>item.vigente).length],['Registro',user.fechaRegistro],['Rol',user.rol],['ID de referencia',user.idUsuario]]);
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
            ||typeof next.usuario.correoVerificado!=='boolean'||!['PENDIENTE','ACTIVO','SUSPENDIDO','CERRADO'].includes(next.usuario.estadoUsuario)
            ||next.verificaciones.some(item=>!item||!Number.isInteger(item.idVerificacion)||!validId(item.idVerificacion)||!['PENDIENTE','EN_REVISION','APROBADA','RECHAZADA'].includes(item.estadoVerificacion))
            ||new Set(next.verificaciones.map(item=>item.idVerificacion)).size!==next.verificaciones.length
            ||next.restricciones.some(item=>!item||!Number.isInteger(item.idRestriccion)||!validId(item.idRestriccion)||typeof item.activa!=='boolean'||typeof item.vigente!=='boolean'||!['APOSTAR','TODAS_OPERACIONES'].includes(item.tipoRestriccion))
            ||new Set(next.restricciones.map(item=>item.idRestriccion)).size!==next.restricciones.length)throw new Error('El detalle recibido no cumple el contrato del usuario solicitado.');
        renderDetail(next);
    }
    async function consult(id) {
        if(busy||expired||!readable||!validId(id))return;
        const changed=detail&&detail.usuario.idUsuario!==Number(id);
        const drafted=[...document.querySelectorAll('#users-forms textarea, #users-forms input[type="datetime-local"], #users-forms select')].some(el=>el.value.trim());
        if(changed&&drafted&&!window.confirm('Consultar otra cuenta descartará los borradores actuales. ¿Continuar?')){status('Consulta cancelada. Se conserva la cuenta seleccionada y sus borradores.');return;}
        $('user-id').value=String(Number(id));
        $('users-operation-result').hidden=true;
        $('users-operation-values').replaceChildren();
        clearUserDisplay();
        if(changed){for(const form of forms.values())form.reset();detail=null;}
        busy=true;stale=true;sync();status('Consultando detalle del usuario…');
        try{await readDetail(Number(id));if(live())status('Detalle actualizado. Las operaciones usan los registros oficiales mostrados.');}
        catch(error){report(error);}finally{busy=false;if(live())sync();}
    }
    async function readPending() {
        batchSelection.clear();batchChecks.clear();pendingRows=[];syncBatch();
        $('pending-results').replaceChildren();
        const amount=$('pending-count').value;
        if(!/^\d{1,3}$/.test(amount)||Number(amount)<1||Number(amount)>500)throw new Error('Selecciona una cantidad entre 1 y 500.');
        const data=await api(prefix+'pendientes?'+new URLSearchParams({cantidad:amount}));
        if(!Array.isArray(data.usuarios)||data.cantidad!==data.usuarios.length||data.usuarios.length>Number(amount)||data.usuarios.some(user=>!user||!validId(user.idUsuario)||typeof user.correo!=='string'))throw new Error('La respuesta de pendientes no cumple el contrato.');
        const userIds=new Set(),verificationIds=new Set();
        if(data.usuarios.some(user=>!Number.isInteger(user.idUsuario)||!Number.isInteger(user.idVerificacion)
                ||!validId(user.idVerificacion)||typeof user.correoVerificado!=='boolean'
                ||userIds.has(user.idUsuario)||verificationIds.has(user.idVerificacion)
                ||!userIds.add(user.idUsuario)||!verificationIds.add(user.idVerificacion)))
            throw new Error('El listado contiene referencias duplicadas o inconsistentes.');
        pendingRows=data.usuarios.map(user=>({idUsuario:user.idUsuario,idVerificacion:user.idVerificacion,
            nombre:user.nombre,apellido:user.apellido,correo:user.correo,rol:user.rol,
            estadoUsuario:user.estadoUsuario,estadoVerificacion:user.estadoVerificacion,
            correoVerificado:user.correoVerificado,fechaSolicitud:user.fechaSolicitud}));
        table($('pending-results'),'Usuarios pendientes o en revisión',
            [...(writable?['Seleccionar']:[]),'Usuario','Correo','Estado de cuenta','Verificación','Correo verificado','Solicitud','Acción'],
            pendingRows.map(user=>[...(writable?[batchCheckbox(user)]:[]),identity(user),user.correo,user.estadoUsuario,user.estadoVerificacion,user.correoVerificado,user.fechaSolicitud,button('Consultar usuario',()=>consult(user.idUsuario))]));
        syncBatch();
    }
    function batchEligible(user) {
        // El listado oficial solo devuelve cuentas cliente; el detalle vuelve a validar el rol.
        return writable&&!uncertain.has(user.idUsuario)&&(!user.rol||user.rol==='USUARIO')&&Number.isInteger(user.idUsuario)
            &&validId(user.idUsuario)&&Number.isInteger(user.idVerificacion)&&validId(user.idVerificacion)
            &&user.estadoVerificacion==='EN_REVISION'
            &&['PENDIENTE','ACTIVO','SUSPENDIDO'].includes(user.estadoUsuario);
    }
    function batchCheckbox(user) {
        const input=node('input');input.type='checkbox';input.className='batch-row-choice';
        input.setAttribute('aria-label','Seleccionar '+identity(user)+' · '+user.correo);
        input.addEventListener('change',()=>{
            if(busy||expired||batchResults||!batchEligible(user)){input.checked=false;return;}
            if(input.checked){
                if(batchSelection.size>=40){input.checked=false;status('No puedes seleccionar más de 40 verificaciones.',true);}
                else batchSelection.set(user.idUsuario,{...user});
            }else batchSelection.delete(user.idUsuario);
            syncBatch();
        });
        batchChecks.set(user.idUsuario,input);return input;
    }
    function syncBatch() {
        const blocked=busy||expired||!writable||batchResults!==null;
        $('users-batch').hidden=!writable;
        $('batch-count').textContent='Seleccionados: '+batchSelection.size+' de 40';
        for(const user of pendingRows){const box=batchChecks.get(user.idUsuario);if(box){box.checked=batchSelection.has(user.idUsuario);box.disabled=blocked||!batchEligible(user);}}
        const eligible=pendingRows.filter(batchEligible);
        $('batch-all').disabled=blocked||!eligible.length;
        $('batch-all').checked=eligible.length>0&&eligible.length<=40&&eligible.every(user=>batchSelection.has(user.idUsuario));
        $('batch-all').indeterminate=batchSelection.size>0&&!$('batch-all').checked;
        $('batch-clear').disabled=blocked||!batchSelection.size;
        $('batch-observation').disabled=blocked;
        $('batch-approve').disabled=!approvalsEnabled||blocked||batchSelection.size===0||batchSelection.size>40;
        $('batch-dismiss').disabled=busy||batchRunning;
    }
    function renderBatch() {
        if(!batchResults||!live())return;
        $('batch-results').hidden=false;
        const counts=Object.fromEntries(Object.keys(batchStates).map(key=>[key,0]));
        batchResults.forEach(row=>counts[row.state]++);
        $('batch-summary').replaceChildren();
        values($('batch-summary'),[['Seleccionados',batchResults.length],...Object.entries(batchStates).map(([key,label])=>[label,counts[key]])]);
        $('batch-rows').replaceChildren();
        table($('batch-rows'),'Resultado conservado para revisión administrativa',
            ['Usuario','Correo','Verificación','Resultado','Detalle','Acción'],
            batchResults.map(row=>[identity(row.user),row.user.correo,row.user.idVerificacion,batchStates[row.state],row.note,
                button('Consultar usuario',()=>consult(row.user.idUsuario))]));
        sync();
    }
    async function batchDetail(user) {
        const data=await api(prefix+'detalle?'+new URLSearchParams({idUsuario:String(user.idUsuario)}));
        const next=data.detalle;
        if(!next||next.usuario?.idUsuario!==user.idUsuario||!Array.isArray(next.verificaciones)
                ||typeof next.usuario.correoVerificado!=='boolean'||typeof next.usuario.estadoUsuario!=='string'
                ||typeof next.usuario.rol!=='string'||typeof next.usuario.correo!=='string')
            throw new Error('El detalle no confirma la cuenta solicitada.');
        const ids=new Set();
        if(next.verificaciones.some(v=>!Number.isInteger(v.idVerificacion)||!validId(v.idVerificacion)
                ||typeof v.estadoVerificacion!=='string'||ids.has(v.idVerificacion)||!ids.add(v.idVerificacion)))
            throw new Error('Historial de verificación inconsistente.');
        const latest=next.verificaciones.reduce((last,v)=>!last||v.idVerificacion>last.idVerificacion?v:last,null);
        return {account:next.usuario,latest};
    }
    function batchUnchanged(user,current) {
        return current.account.rol==='USUARIO'&&current.account.estadoUsuario===user.estadoUsuario
            &&current.account.nombre===user.nombre&&current.account.apellido===user.apellido
            &&current.account.correo===user.correo&&current.account.correoVerificado===user.correoVerificado
            &&current.account.estadoUsuario!=='CERRADO'&&current.latest?.idVerificacion===user.idVerificacion
            &&current.latest.estadoVerificacion===user.estadoVerificacion
            &&current.latest.estadoVerificacion==='EN_REVISION';
    }
    async function reconcileBatch(row) {
        try {
            const current=await batchDetail(row.user);
            row.note+=' Consulta posterior: cuenta '+current.account.estadoUsuario+', última verificación '
                +(current.latest?current.latest.idVerificacion+' / '+current.latest.estadoVerificacion:'ausente')
                +'. Esta consulta no demuestra qué solicitud produjo ese estado.';
        }catch(error){if(error.status===401)report(error);row.note+=' No fue posible reconciliar el detalle oficial.';}
    }
    async function approveBatch() {
        if(!approvalsEnabled)return;
        if(busy||expired||!writable||batchResults||!batchSelection.size||batchSelection.size>40)return;
        const selected=[...batchSelection.values()].map(user=>({...user}));
        if(selected.some(user=>!batchEligible(user))||new Set(selected.map(u=>u.idVerificacion)).size!==selected.length)return;
        const observation=$('batch-observation').value.trim();
        if(observation.length>500){status('La observación no puede superar 500 caracteres.',true);return;}
        const confirmation='Aprobar '+selected.length+' verificaciones administrativas de identidades ya revisadas:\n\n'
            +selected.map(u=>identity(u)+' · '+u.correo+' · '+u.estadoVerificacion+' · correo verificado: '+display(u.correoVerificado)).join('\n')
            +'\n\nAprobar la identidad NO confirma el correo. Sin correo verificado puede continuar PENDIENTE. '
            +'La activación depende del backend; una cuenta suspendida no se reactiva. ¿Confirmas la aprobación?';
        if(!window.confirm(confirmation))return;
        busy=true;batchRunning=true;batchStopped=false;stale=true;sync();
        batchResults=selected.map(user=>({user,state:'pendiente',note:'No se ha enviado una aprobación.'}));
        renderBatch();
        try {
            for(let index=0;index<batchResults.length;index++){
                if(!live()){batchStopped=true;break;}
                const row=batchResults[index];let sent=false,phase='detalle';
                $('batch-progress').textContent='Procesando '+(index+1)+' de '+batchResults.length+': '+identity(row.user);
                try {
                    const current=await batchDetail(row.user);
                    if(!batchUnchanged(row.user,current)){row.state='omitido';row.note='El registro cambió o dejó de ser elegible. No se envió POST.';renderBatch();continue;}
                    phase='csrf';
                    const csrf=await api('/administrador/seguridad/csrf');
                    if(typeof csrf.csrfToken!=='string'||!/^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$/.test(csrf.csrfToken))
                        throw new Error('No se obtuvo autorización CSRF válida.');
                    const payload=new URLSearchParams({idVerificacion:String(row.user.idVerificacion)});
                    if(observation)payload.set('observacion',observation);
                    phase='aprobar';sent=true;
                    const data=await api(prefix+'verificacion/aprobar',{method:'POST',headers:{'X-CSRF-Token':csrf.csrfToken},body:payload});
                    const result=data.resultado;
                    validateOutcome('verificacion/aprobar',result,payload,row.user.idUsuario,current.account);
                    if(result.estadoVerificacion!=='APROBADA'||typeof result.correoVerificado!=='boolean'
                            ||typeof result.sinCambios!=='boolean'||!['ACTIVO','PENDIENTE','SUSPENDIDO'].includes(result.estadoUsuario)
                            ||result.estadoUsuario==='ACTIVO'&&!result.correoVerificado
                            ||result.estadoUsuario==='PENDIENTE'&&result.correoVerificado)
                        throw new Error('La respuesta no confirma un resultado de aprobación consistente.');
                    row.resultado={...result};
                    row.state=result.estadoUsuario==='ACTIVO'?'activo':result.estadoUsuario==='SUSPENDIDO'?'suspendido':'correo';
                    row.note='Respuesta oficial: APROBADA; cuenta '+result.estadoUsuario+'; correo verificado: '
                        +display(result.correoVerificado)+'. '+(result.sinCambios?'El servidor informó sin cambios; no se atribuye una aprobación nueva.':'Operación confirmada.');
                }catch(error){
                    const definite=Number.isInteger(error.status)&&[400,401,403,404,405,409].includes(error.status);
                    if(sent&&!definite){
                        row.state='incierto';row.note='POST sin resultado concluyente. Se detuvieron las escrituras; no se reintenta.';
                        uncertain.add(row.user.idUsuario);await reconcileBatch(row);
                    }else if(sent){row.state='rechazado';row.note='HTTP '+error.status+': '+(errors[error.status]||'Solicitud rechazada.');}
                    else if(error.status===404&&phase==='detalle'){row.state='omitido';row.note='El registro ya no está disponible. No se envió POST.';}
                    else row.note='No se envió POST: no se pudo validar '+(phase==='csrf'?'CSRF':'el detalle')+'.';
                    if(error.status===401)report(error);
                    // 409/400/404 oficiales de un POST permiten seguir; un 403 detiene
                    // el lote para revisar permisos/CSRF. Cualquier ambigüedad detiene.
                    if(!definite||[401,403,405].includes(error.status)||phase==='csrf'){
                        batchStopped=true;renderBatch();break;
                    }
                }
                renderBatch();
            }
        }finally{
            if(live()){try{await readPending();}catch(error){report(error);batchStopped=true;}}
            batchRunning=false;busy=false;
            if(live())$('batch-progress').textContent=(batchStopped?'Lote detenido. Revisión manual obligatoria antes de otro lote.':'Lote finalizado.')
                +' Los resultados se conservan; no se reenvía ninguna aprobación.';
            renderBatch();
        }
    }
    function localDate(value) {
        const m=/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,7}))?)?$/.exec(value);
        if(!m)return null;
        const y=Number(m[1]),month=Number(m[2]),day=Number(m[3]),days=[31,y%4===0&&(y%100!==0||y%400===0)?29:28,31,30,31,30,31,31,30,31,30,31];
        if(y<1||month<1||month>12||day<1||day>days[month-1]||Number(m[4])>23||Number(m[5])>59||Number(m[6]||0)>59)return null;
        const fraction=(m[7]||'').replace(/0+$/,'');
        return m[1]+'-'+m[2]+'-'+m[3]+'T'+m[4]+':'+m[5]+':'+(m[6]||'00')+(fraction?'.'+fraction:'');
    }
    function validateOutcome(route,result,payload,userId,account=detail?.usuario) {
        if(!result||Array.isArray(result)||result.idUsuario!==userId)throw new Error('Respuesta sin confirmación para la cuenta seleccionada.');
        if(route.startsWith('verificacion/')){
            if(!Number.isInteger(result.idVerificacion)||!validId(result.idVerificacion)||typeof result.estadoVerificacion!=='string')throw new Error('Respuesta de verificación inesperada.');
            if(payload.has('idVerificacion')&&result.idVerificacion!==Number(payload.get('idVerificacion')))throw new Error('La verificación devuelta no coincide con la operación.');
            const expected={'verificacion/iniciar':'EN_REVISION','verificacion/aprobar':'APROBADA','verificacion/rechazar':'RECHAZADA','verificacion/reabrir':'PENDIENTE'}[route];
            if(result.estadoVerificacion!==expected||(route!=='verificacion/reabrir'&&typeof result.sinCambios!=='boolean'))throw new Error('La respuesta no confirma el estado oficial de verificación.');
            if(route==='verificacion/aprobar'&&(!['ACTIVO','PENDIENTE','SUSPENDIDO'].includes(result.estadoUsuario)||typeof result.correoVerificado!=='boolean'
                    ||(result.estadoUsuario==='ACTIVO'&&!result.correoVerificado)||(result.estadoUsuario==='PENDIENTE'&&result.correoVerificado)
                    ||(account?.estadoUsuario==='SUSPENDIDO'&&result.estadoUsuario!=='SUSPENDIDO')))
                throw new Error('La respuesta de aprobación no confirma un estado de cuenta consistente.');
            if(route==='verificacion/rechazar'&&!['PENDIENTE','ACTIVO','SUSPENDIDO','CERRADO'].includes(result.estadoUsuario))throw new Error('Respuesta de rechazo incompleta.');
            if(route==='verificacion/reabrir'&&detail?.usuario.idUsuario===userId&&detail.verificaciones.some(v=>v.idVerificacion===result.idVerificacion))throw new Error('La reapertura no confirma una nueva solicitud.');
        }else if(route==='estado/cambiar'){
            if(result.estadoActual!==payload.get('nuevoEstado')||result.estadoAnterior!==account?.estadoUsuario||typeof result.sinCambios!=='boolean'
                    ||result.sinCambios!==(result.estadoAnterior===result.estadoActual))throw new Error('Respuesta de estado inesperada.');
        }else{
            if(!Number.isInteger(result.idRestriccion)||!validId(result.idRestriccion)||typeof result.activa!=='boolean'||!['APOSTAR','TODAS_OPERACIONES'].includes(result.tipoRestriccion))throw new Error('Respuesta de restricción inesperada.');
            if(route==='restricciones/levantar'){
                const selected=detail?.restricciones.find(r=>r.idRestriccion===Number(payload.get('idRestriccion')));
                if(result.idRestriccion!==Number(payload.get('idRestriccion'))||result.activa!==false||typeof result.sinCambios!=='boolean'||result.tipoRestriccion!==selected?.tipoRestriccion)throw new Error('El servidor no confirmó el levantamiento seleccionado.');
            }else if(result.activa!==true||result.tipoRestriccion!==payload.get('tipoRestriccion')||result.motivo!==payload.get('motivo')
                    ||(payload.has('fechaFin')?localDate(result.fechaFin||'')!==payload.get('fechaFin'):result.fechaFin!==null))throw new Error('El servidor no confirmó la restricción solicitada.');
        }
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
            if(route==='verificacion/aprobar')section.append(node('p','Inicia la revisión y comprueba la identidad antes de aprobar. El backend autoriza y confirma el resultado.','muted'));
            const submit=node('button',title,'primary');submit.type='submit';fieldset.append(submit);form.append(fieldset);section.append(form);$('users-forms').append(section);forms.set(route,form);
            if(route==='estado/cambiar')form.elements.nuevoEstado.addEventListener('change',()=>{form.elements.motivo.required=['SUSPENDIDO','CERRADO'].includes(form.elements.nuevoEstado.value);});
            form.addEventListener('submit',async event=>{
                event.preventDefault();if(busy||expired||!available(route,form))return;
                const userId=detail.usuario.idUsuario,payload=new URLSearchParams();
                for(const schema of fields){let value=form.elements.namedItem(schema.name).value.trim();if(schema.required&&!value){status('Completa: '+schema.label,true);return;}
                    if(schema.type==='textarea'&&value.length>500){status('El texto no puede superar 500 caracteres.',true);return;}
                    if(schema.type==='datetime-local'&&value){value=localDate(value);if(!value){status('La fecha de fin no es válida. Conserva la hora local del servidor.',true);return;}}
                    if(value)payload.set(schema.name,value);}
                if(payload.has('idUsuario')&&payload.get('idUsuario')!==String(userId)){status('La cuenta de la operación no corresponde al detalle seleccionado.',true);return;}
                if(route==='estado/cambiar'&&!['PENDIENTE','ACTIVO','SUSPENDIDO','CERRADO'].includes(payload.get('nuevoEstado'))){status('Selecciona un estado oficial.',true);return;}
                if(route==='restricciones/agregar'&&!['APOSTAR','TODAS_OPERACIONES'].includes(payload.get('tipoRestriccion'))){status('Selecciona un tipo de restricción oficial.',true);return;}
                if(route==='estado/cambiar'&&['SUSPENDIDO','CERRADO'].includes(payload.get('nuevoEstado'))&&!payload.get('motivo')){status('El motivo es obligatorio para suspender o cerrar.',true);return;}
                const consequences=route==='estado/cambiar'&&payload.get('nuevoEstado')==='CERRADO'?' Cerrar la cuenta impide reactivarla desde este módulo.':route==='restricciones/levantar'?' Se levantará la restricción '+detail.restricciones.find(r=>r.idRestriccion===Number(payload.get('idRestriccion')))?.tipoRestriccion+'.':'';
                if(!window.confirm(title+' para '+identity(detail.usuario)+' ('+detail.usuario.correo+').'+consequences+' ¿Confirmar?'))return;
                busy=true;sync();status('Procesando operación…');let sent=false;
                $('users-operation-result').hidden=true;
                try{
                    if(route==='verificacion/aprobar'){
                        const previous=detail.usuario;
                        const selected=detail.verificaciones.find(v=>v.idVerificacion===Number(payload.get('idVerificacion')));
                        const current=await batchDetail(previous);
                        if(!selected||!batchUnchanged({...previous,idVerificacion:selected.idVerificacion,estadoVerificacion:selected.estadoVerificacion},current)){
                            stale=true;throw new Error('La cuenta o verificación cambió. Consulta nuevamente el detalle antes de aprobar.');
                        }
                    }
                    const csrf=await api('/administrador/seguridad/csrf');if(typeof csrf.csrfToken!=='string'||!/^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$/.test(csrf.csrfToken))throw new Error('El servidor no devolvió un token CSRF válido.');
                    sent=true;const data=await api(prefix+route,{method:'POST',headers:{'X-CSRF-Token':csrf.csrfToken},body:payload});validateOutcome(route,data.resultado,payload,userId);
                    $('users-operation-values').replaceChildren();values($('users-operation-values'),Object.entries(data.resultado).filter(([key])=>Object.hasOwn(labels,key)).map(([key,value])=>[labels[key],value]));$('users-operation-result').hidden=false;
                    for(const schema of fields)if(schema.type!=='target')form.elements.namedItem(schema.name).value='';
                    if(route==='estado/cambiar')form.elements.motivo.required=false;
                    stale=true;let refreshed=true;
                    try{await readDetail(userId);if(data.resultado.idVerificacion)pickVerification(data.resultado.idVerificacion);}catch(error){refreshed=false;report(error);}
                    if(!expired){try{await readPending();}catch(error){refreshed=false;report(error);}}
                    status(title+(data.resultado.sinCambios===true?': confirmado sin cambios.':': confirmado por el servidor.')+(refreshed?' Detalle y pendientes actualizados.':' La respuesta se conserva; no se pudo completar la actualización. Reintenta las consultas manualmente.'),!refreshed);
                }catch(error){
                    report(error);
                    if(!live())return;
                    if(sent&&![400,401,403,404,405,409].includes(error.status)){uncertain.add(userId);stale=true;status('Operación sin confirmación. Conservamos tus campos. Consulta el detalle del mismo usuario antes de considerar un reintento.',true);}
                    else if(sent&&error.status===409)stale=true;
                }finally{busy=false;sync();}
            });
        }
    }
    async function searchUsers(page){
        if(busy||expired||!readable)return;
        const requestedText=$('user-search-text').value.trim(),requestedState=$('user-search-state').value,revision=++searchRevision;
        if($('user-search-text').value.length>150||!Number.isInteger(page)||page<1||((page-1)*50)>2147483647){status('La búsqueda admite hasta 150 caracteres y una página válida.',true);return;}
        searchText=requestedText;searchValid=false;busy=true;sync();status('Buscando usuarios…');$('user-search-results').replaceChildren();$('users-page').textContent='Consultando página '+page+'…';
        try {
            const params=new URLSearchParams({buscar:requestedText,pagina:page,tamanoPagina:50});
            if(requestedState)params.set('estado',requestedState);
            const data=await api('/administrador/usuarios/buscar?'+params);
            if(revision!==searchRevision||requestedText!==$('user-search-text').value.trim()||requestedState!==$('user-search-state').value)return;
            if(!Array.isArray(data.usuarios)||data.pagina!==page||data.tamanoPagina!==50||!Number.isSafeInteger(data.total)||data.total<0
                    ||(page>1&&(page-1)*50>=data.total)||data.usuarios.length!==Math.min(50,Math.max(0,data.total-(page-1)*50))
                    ||data.usuarios.some(user=>!user||!Number.isInteger(user.idUsuario)||!validId(user.idUsuario)||typeof user.correo!=='string'||!user.correo.trim()
                        ||!(user.nombre===null||typeof user.nombre==='string')||!(user.apellido===null||typeof user.apellido==='string')
                        ||user.rol!=='USUARIO'||!['PENDIENTE','ACTIVO','SUSPENDIDO','CERRADO'].includes(user.estadoUsuario)||requestedState&&user.estadoUsuario!==requestedState)
                    ||new Set(data.usuarios.map(user=>user.idUsuario)).size!==data.usuarios.length)throw new Error('La página recibida es inconsistente. Vuelve a buscar desde la primera página.');
            searchPage=page;searchTotal=data.total;searchValid=true;$('users-page').textContent='Página '+page+' · '+data.total+' cuentas · '+(requestedState||'TODOS');
            table($('user-search-results'),'Cuentas encontradas',['Nombre','Correo','Estado','Rol','Acción'],data.usuarios.map(user=>[identity(user),user.correo,user.estadoUsuario,user.rol,user.rol==='USUARIO'?button('Seleccionar cuenta',()=>consult(user.idUsuario)):'Datos básicos disponibles en esta fila']));
            status(data.usuarios.length?'Selecciona una cuenta para consultar su detalle.':'No se encontraron cuentas con los filtros seleccionados.');
        }catch(e){if(revision!==searchRevision)return;if(live()){searchTotal=0;searchValid=false;$('users-page').textContent='Consulta sin confirmar. Vuelve a buscar.';}report(e);}finally{busy=false;sync();}
    }
    $('batch-all').addEventListener('change',()=>{
        if(busy||expired||!writable||batchResults)return;
        batchSelection.clear();
        if($('batch-all').checked){
            const eligible=pendingRows.filter(batchEligible);
            eligible.slice(0,40).forEach(user=>batchSelection.set(user.idUsuario,{...user}));
            if(eligible.length>40)status('Se seleccionaron los primeros 40 elegibles visibles. Revisa las identidades antes de confirmar.');
        }
        syncBatch();
    });
    $('batch-clear').addEventListener('click',()=>{if(busy||expired||!writable||batchResults)return;batchSelection.clear();syncBatch();});
    $('batch-approve').addEventListener('click',approveBatch);
    $('batch-dismiss').addEventListener('click',()=>{
        if(busy||batchRunning||!batchResults)return;
        if(!window.confirm('¿Ya revisaste los resultados y los registros no procesados? Descartarlos no reenvía solicitudes. Los resultados inciertos requieren consultar manualmente la cuenta antes de volver a seleccionarla.'))return;
        batchResults=null;batchSelection.clear();$('batch-results').hidden=true;
        $('batch-summary').replaceChildren();$('batch-rows').replaceChildren();syncBatch();
    });
    $('user-search-text').addEventListener('input',()=>{++searchRevision;searchPage=1;searchTotal=0;searchValid=false;$('user-search-results').replaceChildren();$('users-page').textContent='Búsqueda modificada. Consulta nuevamente.';sync();});
    $('user-search-state').addEventListener('change',()=>{++searchRevision;searchPage=1;searchTotal=0;searchValid=false;$('user-search-results').replaceChildren();$('users-page').textContent='Filtro modificado. Consulta nuevamente.';sync();if(!busy)searchUsers(1);});
    $('user-search').addEventListener('submit',event=>{event.preventDefault();searchUsers(1);});
    $('users-prev').addEventListener('click',()=>{if(searchPage>1)searchUsers(searchPage-1);});
    $('users-next').addEventListener('click',()=>{if(searchPage*50<searchTotal)searchUsers(searchPage+1);});
    $('pending-form').addEventListener('submit',async event=>{event.preventDefault();if(busy||expired||!readable)return;busy=true;sync();status('Consultando usuarios pendientes…');try{await readPending();status('Pendientes actualizados.');}catch(error){report(error);}finally{busy=false;sync();}});
    $('user-query').addEventListener('submit',event=>{event.preventDefault();consult($('user-id').value);});
    $('user-id').addEventListener('input',()=>{
        if(detail&&Number($('user-id').value)!==detail.usuario.idUsuario){stale=true;clearUserDisplay();$('users-operation-result').hidden=true;sync();}
    });
    window.addEventListener('pagehide',()=>{leaving=true;++searchRevision;controllers.forEach(controller=>controller.abort());});
    renderForms();openUserOperation(operations[0][0]);sync();
    if(!['ADMINISTRADOR','OPERADOR_EVENTOS','CAJERO','AUDITOR'].includes(role)){
        status('No se pudo obtener el rol de la sesión administrativa. Vuelve a iniciar sesión. No se ha consultado el backend de usuarios.',true);
        $('users-login').hidden=false;
    }else if(!readable)status('Tu rol no tiene permiso para consultar o administrar usuarios.',true);
    const initial=new URLSearchParams(location.search).get('idUsuario');
    if(readable&&validId(initial)){$('user-id').value=initial;consult(initial);}
    else if(readable)$('pending-form').requestSubmit();
})();
