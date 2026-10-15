/* Validacion compartida de instalacion limpia; se permiten objetos auxiliares.
   Solo lectura de datos y metadatos. Ejecutable individualmente en SSMS. */
SET NOCOUNT ON;
DECLARE @Objetos TABLE(Nombre SYSNAME PRIMARY KEY,Tipo VARCHAR(2));
INSERT @Objetos VALUES
('Rol','U'),
('Pais','U'),
('Departamento','U'),
('Municipio','U'),
('TipoEstado','U'),
('Estado','U'),
('Usuario','U'),
('PerfilUsuario','U'),
('VerificacionUsuario','U'),
('RestriccionUsuario','U'),
('TokenSeguridad','U'),
('Deporte','U'),
('Liga','U'),
('Participante','U'),
('Evento','U'),
('EventoParticipante','U'),
('Mercado','U'),
('Seleccion','U'),
('Cuota','U'),
('IncidenciaEvento','U'),
('ResultadoEvento','U'),
('ResolucionSeleccion','U'),
('Billetera','U'),
('Boleto','U'),
('DetalleBoleto','U'),
('TipoTransaccion','U'),
('TransaccionFinanciera','U'),
('MovimientoBilletera','U'),
('LiquidacionBoleto','U'),
('Auditoria','U'),
('ConfiguracionSistema','U'),
('sp_RegistrarUsuarioCliente','P'),
('sp_ObtenerUsuarioAutenticacion','P'),
('sp_RegistrarIntentoLogin','P'),
('sp_CrearTokenSeguridad','P'),
('sp_ValidarTokenSeguridad','P'),
('sp_VerificarCorreoConToken','P'),
('sp_RestablecerContrasenaConToken','P'),
('sp_CambiarContrasenaUsuario','P'),
('sp_ObtenerBilleteraUsuario','P'),
('sp_ObtenerMovimientosBilletera','P'),
('sp_AjustarSaldoVirtual','P'),
('sp_ValidarPermisoEventos','P'),
('sp_CrearLiga','P'),
('sp_ActualizarLiga','P'),
('sp_CrearParticipante','P'),
('sp_ActualizarParticipante','P'),
('sp_CrearEvento','P'),
('sp_ActualizarEvento','P'),
('sp_AgregarParticipanteEvento','P'),
('sp_CrearMercado','P'),
('sp_CrearSeleccion','P'),
('sp_RegistrarCuota','P'),
('sp_CambiarEstadoEvento','P'),
('sp_CambiarEstadoMercado','P'),
('sp_CotizarApuesta','P'),
('sp_RealizarApuesta','P'),
('sp_ObtenerBoleto','P'),
('sp_RegistrarResultadoEvento','P'),
('sp_ResolverSeleccion','P'),
('sp_OficializarResultadoEvento','P'),
('sp_CorregirResultadoEvento','P'),
('sp_AnularResultadoEvento','P'),
('sp_ValidarPermisoLiquidacion','P'),
('sp_ObtenerBoletosListosLiquidar','P'),
('sp_LiquidarBoleto','P'),
('sp_LiquidarBoletosEvento','P'),
('sp_ObtenerLiquidacionBoleto','P'),
('sp_ValidarPermisoAdministracionUsuario','P'),
('sp_ObtenerDetalleAdministrativoUsuario','P'),
('sp_ObtenerUsuariosPendientesVerificacion','P'),
('sp_SincronizarHabilitacionUsuario','P'),
('sp_IniciarRevisionUsuario','P'),
('sp_AprobarVerificacionUsuario','P'),
('sp_RechazarVerificacionUsuario','P'),
('sp_ReabrirVerificacionUsuario','P'),
('sp_CambiarEstadoUsuarioAdministrativo','P'),
('sp_AgregarRestriccionUsuario','P'),
('sp_LevantarRestriccionUsuario','P'),
('sp_ObtenerAnaliticaBoletosUsuario','P'),
('sp_ObtenerResumenUsuarioPorDeporte','P'),
('sp_ObtenerResumenGeneralUsuario','P'),
('sp_ObtenerEventosExploracion','P'),
('sp_ObtenerDetalleEventoExploracion','P'),
('sp_ObtenerAnaliticaEventosAdministracion','P'),
('sp_ObtenerDashboardAdministrativo','P'),
('sp_IniciarSimulacionEvento','P'),
('sp_RegistrarIncidenciaEvento','P'),
('sp_AnularIncidenciaEvento','P'),
('sp_FinalizarSimulacionEvento','P'),
('sp_ObtenerEstadoSimulacionEvento','P'),
('sp_ResolverApuestasModalidadEvento','P'),
('sp_ObtenerConciliacionCasa','P'),
('vw_EventosDisponibles','V'),
('vw_EventoParticipantes','V'),
('vw_MercadosAbiertos','V'),
('vw_CuotasActuales','V'),
('vw_BoletosUsuario','V'),
('vw_DetalleBoletos','V'),
('vw_HistorialMovimientos','V'),
('vw_EstadoVerificacionUsuario','V'),
('vw_ResumenBilleteras','V'),
('vw_ResumenAdministrativo','V'),
('vw_ResumenModalidades','V'),
('vw_AuditoriaSistema','V'),
('tr_Auditoria_ProtegerHistorial','TR'),
('tr_MovimientoBilletera_ProtegerHistorial','TR'),
('tr_TransaccionFinanciera_ProhibirEliminacion','TR'),
('tr_ConfiguracionSistema_AuditarCambios','TR'),
('tr_ConfiguracionSistema_ProhibirEliminacion','TR'),
('tr_IncidenciaEvento_ProtegerHistorial','TR');
IF EXISTS(SELECT 1 FROM @Objetos O WHERE OBJECT_ID('dbo.'+O.Nombre,O.Tipo) IS NULL)
BEGIN
 SELECT O.* FROM @Objetos O WHERE OBJECT_ID('dbo.'+O.Nombre,O.Tipo) IS NULL;
 THROW 77001,'Faltan objetos funcionales esperados; consultar listado.',1;
END;
IF EXISTS(SELECT 1 FROM sys.triggers T JOIN @Objetos O ON O.Nombre=T.name AND O.Tipo='TR' WHERE T.is_disabled=1)
 THROW 77002,'Hay triggers funcionales deshabilitados.',1;
DECLARE @Indices TABLE(Tabla SYSNAME,Nombre SYSNAME);
INSERT @Indices VALUES
('PerfilUsuario','UX_PerfilUsuario_Documento'),
('PerfilUsuario','IX_PerfilUsuario_IdPais'),
('PerfilUsuario','IX_PerfilUsuario_IdMunicipio'),
('Usuario','IX_Usuario_IdRol_IdEstado'),
('Usuario','IX_Usuario_IdEstado_FechaRegistro'),
('VerificacionUsuario','IX_VerificacionUsuario_Usuario_Ultima'),
('VerificacionUsuario','IX_VerificacionUsuario_Estado_Solicitud'),
('RestriccionUsuario','IX_RestriccionUsuario_Vigente'),
('TokenSeguridad','IX_TokenSeguridad_Usuario_Tipo'),
('Departamento','IX_Departamento_Pais_Activo'),
('Municipio','IX_Municipio_Departamento_Activo'),
('Liga','IX_Liga_Deporte_Activo'),
('Liga','IX_Liga_IdPais'),
('Participante','UX_Participante_Deporte_Tipo_Nombre'),
('Participante','IX_Participante_Deporte_Activo'),
('Evento','IX_Evento_Liga_FechaInicio'),
('Evento','IX_Evento_Estado_FechaInicio'),
('EventoParticipante','IX_EventoParticipante_Participante'),
('Mercado','UX_Mercado_Evento_Nombre'),
('Mercado','IX_Mercado_Evento_Estado'),
('Cuota','UX_Cuota_Seleccion_Activa'),
('Cuota','IX_Cuota_Seleccion_Historial'),
('ResultadoEvento','IX_ResultadoEvento_Estado_Fecha'),
('ResolucionSeleccion','IX_ResolucionSeleccion_ResultadoEvento'),
('Boleto','IX_Boleto_Usuario_Fecha'),
('Boleto','IX_Boleto_Estado_Resultado_Fecha'),
('DetalleBoleto','IX_DetalleBoleto_Seleccion_Resultado'),
('TransaccionFinanciera','IX_TransaccionFinanciera_Billetera_Fecha'),
('TransaccionFinanciera','IX_TransaccionFinanciera_Boleto'),
('TransaccionFinanciera','IX_TransaccionFinanciera_Estado_Fecha'),
('MovimientoBilletera','IX_MovimientoBilletera_Billetera_Fecha'),
('LiquidacionBoleto','IX_LiquidacionBoleto_Estado_Fecha'),
('Auditoria','IX_Auditoria_Usuario_Fecha'),
('Auditoria','IX_Auditoria_Tabla_Registro_Fecha'),
('Auditoria','IX_Auditoria_ReferenciaOperacion'),
('Mercado','UX_Mercado_Marcador'),
('Mercado','UX_Mercado_PrimeraAnotacion'),
('Seleccion','UX_Seleccion_Participante'),
('Seleccion','IX_Seleccion_EventoParticipante'),
('IncidenciaEvento','IX_Incidencia_PrimeraValida'),
('DetalleBoleto','IX_Detalle_ModalidadClasificacion'),
('Boleto','IX_Boleto_ReservaCasa'),
('Evento','IX_Evento_SimulacionEstado');
IF EXISTS(SELECT 1 FROM @Indices E WHERE NOT EXISTS(SELECT 1 FROM sys.indexes I WHERE I.object_id=OBJECT_ID('dbo.'+E.Tabla)
 AND I.name=E.Nombre AND I.is_disabled=0))
 THROW 77003,'Falta un indice funcional o esta deshabilitado.',1;
DECLARE @Columnas TABLE(Tabla SYSNAME,Columna SYSNAME);
INSERT @Columnas VALUES
('Deporte','UnidadMarcador'),('Deporte','PermiteMarcadorFinal'),('Deporte','PermitePrimeraAnotacion'),
('Evento','EsSimulado'),('Evento','DuracionSimulacionSegundos'),('Evento','FechaInicioRealUtc'),('Evento','FechaFinRealUtc'),
('EventoParticipante','MarcadorActual'),('Mercado','TipoMercado'),('Seleccion','IdEvento'),('Seleccion','IdParticipante'),
('Cuota','ValorResultado'),('Boleto','IdBilleteraCasaReserva'),('Boleto','ReservaCasaInicial'),('Boleto','ReservaCasaPendiente'),
('DetalleBoleto','PronosticoA'),('DetalleBoleto','PronosticoB'),('DetalleBoleto','CuotaResultadoAplicada'),
('DetalleBoleto','TipoMercadoAplicado'),('DetalleBoleto','ClasificacionAcierto'),('DetalleBoleto','CuotaLiquidacion'),
('DetalleBoleto','NombreEventoAplicado'),('DetalleBoleto','NombreParticipanteAAplicado'),
('DetalleBoleto','NombreParticipanteBAplicado'),('DetalleBoleto','NombreSeleccionAplicada'),
('ResultadoEvento','MarcadorFinalA'),('ResultadoEvento','MarcadorFinalB'),('ResultadoEvento','IdIncidenciaPrimeraAnotacion');
IF EXISTS(SELECT 1 FROM @Columnas C WHERE COL_LENGTH('dbo.'+C.Tabla,C.Columna) IS NULL)
 THROW 77004,'Faltan columnas del modelo final; este instalador no realiza migraciones.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys F JOIN @Objetos O ON O.Nombre=OBJECT_NAME(F.parent_object_id) AND O.Tipo='U'
 WHERE F.is_disabled=1 OR F.is_not_trusted=1)
 OR EXISTS(SELECT 1 FROM sys.check_constraints C JOIN @Objetos O ON O.Nombre=OBJECT_NAME(C.parent_object_id) AND O.Tipo='U'
 WHERE C.is_disabled=1 OR C.is_not_trusted=1)
 THROW 77005,'Restricciones funcionales deshabilitadas o no confiables.',1;
DECLARE @Claves TABLE(Clave VARCHAR(100) PRIMARY KEY);
INSERT @Claves VALUES
('SALDO_INICIAL_USUARIO'),('SALDO_INICIAL_CASA'),('EDAD_MINIMA_USUARIO'),('MAX_INTENTOS_LOGIN'),
('TIEMPO_BLOQUEO_LOGIN_MIN'),('TIEMPO_TOKEN_RECUPERACION_MIN'),('TIEMPO_TOKEN_VERIFICACION_MIN'),
('MONTO_MINIMO_APUESTA'),('ANTICIPACION_CIERRE_APUESTA_MIN'),('COMISION_SERVICIO_PORCENTAJE'),
('DURACION_SIMULACION_SEGUNDOS'),('MULTIPLICADOR_MARCADOR_EXACTO_DEFAULT'),
('MULTIPLICADOR_MARCADOR_RESULTADO_DEFAULT'),('MULTIPLICADOR_PRIMERA_ANOTACION_DEFAULT');
IF EXISTS(SELECT 1 FROM @Claves C WHERE NOT EXISTS(SELECT 1 FROM dbo.ConfiguracionSistema S WHERE S.Clave=C.Clave))
 THROW 77006,'Faltan configuraciones.',1;
IF EXISTS(SELECT Nombre FROM (VALUES('ADMINISTRADOR'),('OPERADOR_EVENTOS'),('CAJERO'),('AUDITOR'),('USUARIO'),('CASA')) V(Nombre)
 EXCEPT SELECT Nombre FROM dbo.Rol WHERE Activo=1)
 THROW 77007,'Faltan roles activos.',1;
IF EXISTS(SELECT Codigo FROM (VALUES('CARGA_INICIAL'),('APUESTA'),('COMISION_SERVICIO'),('DEVOLUCION_COMISION'),
 ('PREMIO'),('PERDIDA_APUESTA'),('DEVOLUCION'),('GANANCIA_CASA'),('PAGO_PREMIO'),('AJUSTE_ADMIN'),
 ('RESERVA_CASA'),('LIBERACION_RESERVA_CASA')) V(Codigo) EXCEPT SELECT Codigo FROM dbo.TipoTransaccion WHERE Activo=1)
 THROW 77008,'Faltan tipos de transaccion activos.',1;
IF (SELECT COUNT(*) FROM dbo.Pais WHERE CodigoISO2='GT')<>1
 OR (SELECT COUNT(*) FROM dbo.Departamento D JOIN dbo.Pais P ON P.IdPais=D.IdPais WHERE P.CodigoISO2='GT')<>22
 OR (SELECT COUNT(*) FROM dbo.Municipio M JOIN dbo.Departamento D ON D.IdDepartamento=M.IdDepartamento
      JOIN dbo.Pais P ON P.IdPais=D.IdPais WHERE P.CodigoISO2='GT')<>340
 THROW 77009,'Catalogos geograficos incompletos.',1;
IF EXISTS(SELECT V.Nombre FROM (VALUES('Futbol','GOL'),('Baloncesto','PUNTO'),('Beisbol','CARRERA')) V(Nombre,Unidad)
 WHERE NOT EXISTS(SELECT 1 FROM dbo.Deporte D WHERE D.Nombre=V.Nombre AND D.UnidadMarcador=V.Unidad
 AND D.PermiteMarcadorFinal=1 AND D.PermitePrimeraAnotacion=1 AND D.Activo=1))
 OR NOT EXISTS(SELECT 1 FROM dbo.Deporte WHERE Nombre='Tenis' AND PermiteMarcadorFinal=0 AND PermitePrimeraAnotacion=0 AND Activo=1)
 THROW 77010,'Capacidades deportivas incorrectas.',1;
IF (SELECT COUNT(*) FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado JOIN dbo.Billetera B ON B.IdUsuario=U.IdUsuario
 WHERE R.Nombre='CASA' AND E.Codigo='ACTIVO')<>1
 THROW 77011,'Se requiere una unica CASA activa con billetera.',1;
IF EXISTS(SELECT 1 FROM dbo.Billetera B JOIN dbo.Usuario U ON U.IdUsuario=B.IdUsuario JOIN dbo.Rol R ON R.IdRol=U.IdRol
 WHERE R.Nombre='CASA' AND B.SaldoComprometido<>(SELECT ISNULL(SUM(ReservaCasaPendiente),0) FROM dbo.Boleto WHERE IdBilleteraCasaReserva=B.IdBilletera))
 THROW 77012,'Reservas CASA no concilian.',1;
IF EXISTS(SELECT V.Correo FROM (VALUES('gabriel@apuestas.local'),('wilson@apuestas.local'),('otto@apuestas.local'),
 ('kevin@apuestas.local'),('fernando@apuestas.local')) V(Correo)
 WHERE NOT EXISTS(SELECT 1 FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol JOIN dbo.Estado E ON E.IdEstado=U.IdEstado
 WHERE U.Correo=V.Correo AND R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' AND U.CorreoVerificado=1))
 THROW 77013,'Administradores iniciales incompletos o con roles incoherentes.',1;
IF EXISTS(SELECT V.Tipo,V.Codigo FROM (VALUES
('USUARIO','PENDIENTE'),
('USUARIO','ACTIVO'),
('USUARIO','SUSPENDIDO'),
('USUARIO','CERRADO'),
('VERIFICACION','PENDIENTE'),
('VERIFICACION','EN_REVISION'),
('VERIFICACION','APROBADA'),
('VERIFICACION','RECHAZADA'),
('EVENTO','BORRADOR'),
('EVENTO','PROGRAMADO'),
('EVENTO','EN_VIVO'),
('EVENTO','PENDIENTE_RESULTADO'),
('EVENTO','FINALIZADO'),
('EVENTO','SUSPENDIDO'),
('EVENTO','CANCELADO'),
('MERCADO','BORRADOR'),
('MERCADO','ABIERTO'),
('MERCADO','SUSPENDIDO'),
('MERCADO','CERRADO'),
('MERCADO','LIQUIDADO'),
('MERCADO','ANULADO'),
('RESULTADO_EVENTO','PENDIENTE'),
('RESULTADO_EVENTO','OFICIAL'),
('RESULTADO_EVENTO','CORREGIDO'),
('RESULTADO_EVENTO','ANULADO'),
('BOLETO','PENDIENTE'),
('BOLETO','EN_REVISION'),
('BOLETO','LIQUIDADO'),
('BOLETO','ANULADO'),
('TRANSACCION','PENDIENTE'),
('TRANSACCION','EN_PROCESO'),
('TRANSACCION','COMPLETADA'),
('TRANSACCION','FALLIDA'),
('TRANSACCION','ANULADA'),
('LIQUIDACION','PENDIENTE'),
('LIQUIDACION','EN_PROCESO'),
('LIQUIDACION','COMPLETADA'),
('LIQUIDACION','FALLIDA'),
('LIQUIDACION','ANULADA')) V(Tipo,Codigo)
 EXCEPT SELECT T.Codigo,E.Codigo FROM dbo.Estado E JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado WHERE E.Activo=1)
 THROW 77014,'Faltan estados funcionales activos.',1;
SELECT Tipo,COUNT(*) AS ObjetosEsperadosVerificados FROM @Objetos GROUP BY Tipo;
SELECT COUNT(*) AS IndicesExplicitosVerificados FROM @Indices;
PRINT 'Modelo funcional validado por nombre. No se exige ausencia de objetos auxiliares.';
GO
