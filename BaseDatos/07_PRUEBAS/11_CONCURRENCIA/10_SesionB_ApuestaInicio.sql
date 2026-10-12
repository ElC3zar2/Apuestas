/* Conexion B: la apuesta puede ganar la carrera o rechazarse; nunca aceptarse despues del inicio. */
SET NOCOUNT ON;
DECLARE @Usuario INT,@Seleccion INT,@Monto DECIMAL(12,2),@Ref UNIQUEIDENTIFIER,@Json NVARCHAR(MAX);
SELECT @Usuario=IdUsuarioPrueba,@Seleccion=IdSeleccionA,@Monto=MontoApuesta,@Ref=ReferenciaA
FROM dbo.PruebaConcurrenciaContexto WHERE IdContexto=1;
IF @Usuario IS NULL THROW 75404,'Falta contexto.',1;
SET @Json=CONCAT('[',@Seleccion,']');
WAITFOR DELAY '00:00:05';
BEGIN TRY
 EXEC dbo.sp_RealizarApuesta @Usuario,@Json,@Monto,@Ref;
END TRY BEGIN CATCH
 IF ERROR_NUMBER() NOT IN(60040,60056) THROW;
 PRINT 'El inicio gano la carrera: apuesta rechazada correctamente.';
END CATCH;
