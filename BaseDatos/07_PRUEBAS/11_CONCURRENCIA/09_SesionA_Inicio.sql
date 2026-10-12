/* Conexion A: ejecutar casi simultaneamente con 10_SesionB_ApuestaInicio.sql.
   El bloqueo comun garantiza que inicio y apuesta se serialicen. */
SET NOCOUNT ON;
DECLARE @Admin INT,@Evento INT;
SELECT @Admin=IdAdministrador,@Evento=IdEvento FROM dbo.PruebaConcurrenciaContexto WHERE IdContexto=1;
IF @Evento IS NULL THROW 75403,'Falta contexto.',1;
WAITFOR DELAY '00:00:05';
EXEC dbo.sp_IniciarSimulacionEvento @Admin,@Evento;
