/* Retiro logico de eventos demo. No borra usuarios ni historiales.
   Cancela eventos demo no terminales; liquida los boletos que queden listos.
   Los eventos finalizados y sus apuestas se conservan.
   Ejecutar en SSMS solo cuando se desee retirar escenarios demo. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario);
IF @Admin IS NULL THROW 75050,'No existe administrador activo.',1;
DECLARE @Evento INT;
DECLARE eventos CURSOR LOCAL FAST_FORWARD FOR
 SELECT EV.IdEvento FROM dbo.Evento EV JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado
 WHERE (EV.Nombre LIKE 'DEMO IA - %' OR EV.Nombre LIKE 'DEMO V2 - %')
 AND E.Codigo NOT IN('FINALIZADO','CANCELADO');
OPEN eventos; FETCH NEXT FROM eventos INTO @Evento;
WHILE @@FETCH_STATUS=0
BEGIN
 EXEC dbo.sp_AnularResultadoEvento @IdUsuarioProceso=@Admin,@IdResultadoEvento=NULL,
   @Motivo='Retiro logico de escenario demo.',@IdEventoCancelar=@Evento;
 FETCH NEXT FROM eventos INTO @Evento;
END;
CLOSE eventos; DEALLOCATE eventos;
DECLARE @Boleto INT;
DECLARE boletos CURSOR LOCAL FAST_FORWARD FOR
 SELECT B.IdBoleto FROM dbo.Boleto B JOIN dbo.Usuario U ON U.IdUsuario=B.IdUsuario
 JOIN dbo.Estado E ON E.IdEstado=B.IdEstado
 WHERE U.Correo LIKE 'cliente.%@apuestas.test' AND E.Codigo='PENDIENTE'
 AND EXISTS(SELECT 1 FROM dbo.DetalleBoleto D WHERE D.IdBoleto=B.IdBoleto)
 AND NOT EXISTS(SELECT 1 FROM dbo.DetalleBoleto D WHERE D.IdBoleto=B.IdBoleto AND D.Resultado='PENDIENTE');
OPEN boletos; FETCH NEXT FROM boletos INTO @Boleto;
WHILE @@FETCH_STATUS=0
BEGIN
 EXEC dbo.sp_LiquidarBoleto @Admin,@Boleto;
 FETCH NEXT FROM boletos INTO @Boleto;
END;
CLOSE boletos; DEALLOCATE boletos;
PRINT 'Retiro logico completado. El historial se conserva; para reiniciar toda la demo usar una base de pruebas limpia.';
