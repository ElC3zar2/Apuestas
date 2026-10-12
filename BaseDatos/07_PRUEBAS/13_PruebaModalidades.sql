/* Pruebas V2 de solo lectura + correcciones transaccionales con ROLLBACK.
   Requiere demo 01 y 04. No ejecutar durante uso concurrente de la demo.
   Los escenarios convencionales permanecen cubiertos por 02..10. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario);
IF (SELECT COUNT(*) FROM dbo.Evento WHERE Nombre LIKE 'DEMO V2 - %')<>8
 THROW 75200,'Requiere los ocho escenarios de 12_DATOS_DEMO/04_EscenariosModalidades.sql.',1;
DECLARE @Esperado TABLE(Sufijo INT,Clase VARCHAR(25),Resultado VARCHAR(20),Multiplicador DECIMAL(10,4));
INSERT @Esperado VALUES
 (51,'EXACTO','GANADOR',3),(52,'RESULTADO','GANADOR',1.5),(53,'NO_ACIERTO','PERDEDOR',0),
 (54,'PRIMERA_ANOTACION','GANADOR',1.8),(55,'NO_ACIERTO','PERDEDOR',0),
 (61,'EXACTO','GANADOR',3),(62,'ANULADO','ANULADO',1),
 (71,'ANULADO','ANULADO',1),(72,'ANULADO','ANULADO',1),
 (81,'RESULTADO','GANADOR',1.5),(82,'EXACTO','GANADOR',3),(83,'NO_ACIERTO','PERDEDOR',0),
 (84,'PRIMERA_ANOTACION','GANADOR',1.8),(85,'NO_ACIERTO','PERDEDOR',0);
IF EXISTS(
 SELECT 1 FROM @Esperado X
 LEFT JOIN dbo.Boleto B ON B.ReferenciaOperacion=CONVERT(UNIQUEIDENTIFIER,CONCAT('A3000000-0000-0000-0000-',RIGHT('000000000000'+CONVERT(VARCHAR(12),X.Sufijo),12)))
 LEFT JOIN dbo.DetalleBoleto D ON D.IdBoleto=B.IdBoleto LEFT JOIN dbo.LiquidacionBoleto L ON L.IdBoleto=B.IdBoleto
 WHERE B.IdBoleto IS NULL OR ISNULL(D.ClasificacionAcierto,'')<>X.Clase OR B.Resultado<>X.Resultado
 OR ISNULL(D.CuotaLiquidacion,-1)<>X.Multiplicador OR L.IdLiquidacion IS NULL
 OR L.MontoLiquidado<>ROUND(B.MontoApostado*X.Multiplicador,2) OR B.ReservaCasaPendiente<>0)
 THROW 75201,'Clasificacion, multiplicador, pago o liberacion incorrectos. Usar los valores iniciales aprobados.',1;
IF EXISTS(SELECT 1 FROM dbo.Boleto B JOIN dbo.Usuario U ON U.IdUsuario=B.IdUsuario
 WHERE CONVERT(VARCHAR(36),B.ReferenciaOperacion) LIKE 'A3000000-%'
 AND B.ReservaCasaInicial<>CASE WHEN B.GananciaPotencial-B.MontoApostado>B.ComisionServicio
 THEN B.GananciaPotencial-B.MontoApostado ELSE B.ComisionServicio END)
 THROW 75202,'Reserva inicial no corresponde a la obligacion maxima.',1;
IF EXISTS(SELECT 1 FROM dbo.Billetera C JOIN dbo.Usuario U ON U.IdUsuario=C.IdUsuario JOIN dbo.Rol R ON R.IdRol=U.IdRol
 WHERE R.Nombre='CASA' AND C.SaldoComprometido<>(SELECT ISNULL(SUM(B.ReservaCasaPendiente),0) FROM dbo.Boleto B WHERE B.IdBilleteraCasaReserva=C.IdBilletera))
 THROW 75203,'Conciliacion CASA incorrecta.',1;
IF EXISTS(SELECT 1 FROM dbo.Boleto B WHERE CONVERT(VARCHAR(36),B.ReferenciaOperacion) LIKE 'A3000000-%'
 AND B.Resultado='ANULADO' AND B.ComisionServicio>0 AND
 (SELECT COUNT(*) FROM dbo.TransaccionFinanciera T JOIN dbo.TipoTransaccion TT ON TT.IdTipoTransaccion=T.IdTipoTransaccion
 WHERE T.IdBoleto=B.IdBoleto AND TT.Codigo='DEVOLUCION_COMISION' AND T.Monto=B.ComisionServicio)<>2)
 THROW 75204,'Falta devolucion de comision usuario/CASA.',1;
IF EXISTS(SELECT 1 FROM dbo.Boleto B WHERE CONVERT(VARCHAR(36),B.ReferenciaOperacion) LIKE 'A3000000-%'
 AND B.ReservaCasaInicial>0 AND
 (SELECT COUNT(*) FROM dbo.TransaccionFinanciera T JOIN dbo.TipoTransaccion TT ON TT.IdTipoTransaccion=T.IdTipoTransaccion
 WHERE T.IdBoleto=B.IdBoleto AND TT.Codigo='RESERVA_CASA' AND T.Monto=B.ReservaCasaInicial)<>1)
 THROW 75205,'Reserva ausente o duplicada.',1;
/* Reintento de liquidacion: no cambia saldos ni cantidad de operaciones. */
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Boleto INT=(SELECT IdBoleto FROM dbo.Boleto WHERE ReferenciaOperacion='A3000000-0000-0000-0000-000000000051'),
 @Trans BIGINT=(SELECT COUNT_BIG(*) FROM dbo.TransaccionFinanciera),
 @Mov BIGINT=(SELECT COUNT_BIG(*) FROM dbo.MovimientoBilletera);
 EXEC dbo.sp_LiquidarBoleto @Admin,@Boleto;
 IF @Trans<>(SELECT COUNT_BIG(*) FROM dbo.TransaccionFinanciera) OR @Mov<>(SELECT COUNT_BIG(*) FROM dbo.MovimientoBilletera)
   THROW 75206,'Liquidacion idempotente genero operaciones nuevas.',1;
 ROLLBACK;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
/* Anular la primera anotacion cambia marcador y primer anotador sin borrar historial. */
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Evento INT=(SELECT IdEvento FROM dbo.Evento WHERE Nombre='DEMO V2 - EN_VIVO'),
 @B INT,@Original BIGINT,@NuevaRef UNIQUEIDENTIFIER=NEWID(),@VersionAntes BINARY(8);
 SELECT @B=IdParticipante FROM dbo.EventoParticipante WHERE IdEvento=@Evento AND OrdenParticipante=2;
 SELECT @Original=IdIncidencia FROM dbo.IncidenciaEvento WHERE ReferenciaOperacion='B3000000-0000-0000-0000-000000000031';
 SELECT @VersionAntes=VersionFila FROM dbo.Evento WHERE IdEvento=@Evento;
 EXEC dbo.sp_RegistrarIncidenciaEvento @Admin,@Evento,'ANOTACION',@NuevaRef,@B,1;
 EXEC dbo.sp_RegistrarIncidenciaEvento @Admin,@Evento,'ANOTACION',@NuevaRef,@B,1;
 IF (SELECT COUNT(*) FROM dbo.IncidenciaEvento WHERE ReferenciaOperacion=@NuevaRef)<>1
    THROW 75207,'Incidencia no idempotente.',1;
 EXEC dbo.sp_AnularIncidenciaEvento @Admin,@Original,'Correccion de prueba.';
 IF (SELECT TOP(1) IdParticipante FROM dbo.IncidenciaEvento WHERE IdEvento=@Evento AND TipoIncidencia='ANOTACION' AND EsAnulada=0 ORDER BY Secuencia)<>@B
    THROW 75208,'Primera anotacion no fue recalculada.',1;
 IF EXISTS(SELECT 1 FROM dbo.EventoParticipante WHERE IdEvento=@Evento
   AND MarcadorActual<>CASE OrdenParticipante WHEN 1 THEN 0 ELSE 1 END)
    THROW 75209,'Marcador no fue recalculado.',1;
 IF (SELECT VersionFila FROM dbo.Evento WHERE IdEvento=@Evento)=@VersionAntes
    THROW 75210,'VersionFila de Evento no refleja cambios deportivos.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Auditoria WHERE Accion='INCIDENCIA_ANULADA' AND IdRegistro=@Original)
    THROW 75211,'Falta auditoria de anulacion.',1;
 ROLLBACK;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
PRINT 'Pruebas V2 correctas: exacto, resultado, empate, perdida, primera anotacion, anulacion, reservas, idempotencia y marcador.';
