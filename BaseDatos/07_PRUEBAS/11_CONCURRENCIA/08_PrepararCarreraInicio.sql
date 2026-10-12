/* Ejecutar 01_PrepararConcurrencia.sql NUEVAMENTE y luego este archivo.
   No usar el contexto ya liquidado de las sesiones 02..07. */
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Evento INT=(SELECT IdEvento FROM dbo.PruebaConcurrenciaContexto WHERE IdContexto=1);
 IF @Evento IS NULL THROW 75400,'Falta contexto de concurrencia.',1;
 IF EXISTS(SELECT 1 FROM dbo.DetalleBoleto D JOIN dbo.Seleccion S ON S.IdSeleccion=D.IdSeleccion WHERE S.IdEvento=@Evento)
    THROW 75401,'Use un contexto nuevo, sin apuestas previas.',1;
 UPDATE EV SET EsSimulado=1,DuracionSimulacionSegundos=300
 FROM dbo.Evento EV JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado WHERE EV.IdEvento=@Evento AND E.Codigo='PROGRAMADO';
 IF @@ROWCOUNT<>1 THROW 75402,'El evento debe estar PROGRAMADO.',1;
 COMMIT;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
