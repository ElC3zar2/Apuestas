/* ============================================================
   SESION A - APUESTA CONCURRENTE

   Ejecutar en conexión/PC A.

   Después de presionar Ejecutar existe una espera de 10 segundos.
   Durante esos 10 segundos ejecutar también la SESION B.
   ============================================================ */

SET NOCOUNT ON;
GO


DECLARE @IdUsuario INT;
DECLARE @IdSeleccion INT;
DECLARE @Monto DECIMAL(12,2);
DECLARE @Referencia UNIQUEIDENTIFIER;


SELECT
    @IdUsuario = IdUsuarioPrueba,
    @IdSeleccion = IdSeleccionA,
    @Monto = MontoApuesta,
    @Referencia = ReferenciaA

FROM dbo.PruebaConcurrenciaContexto
WHERE IdContexto = 1;


IF @IdUsuario IS NULL
    THROW 71101,
          'Primero ejecute 01_PrepararConcurrencia.sql.',
          1;


DECLARE @Json NVARCHAR(MAX) =
    N'['
    + CONVERT(NVARCHAR(20), @IdSeleccion)
    + N']';


PRINT '=======================================================';
PRINT ' SESION A';
PRINT '=======================================================';
PRINT 'Esperando 10 segundos...';
PRINT 'Ejecute AHORA la SESION B en otra conexión.';


WAITFOR DELAY '00:00:10';


BEGIN TRY

    EXEC dbo.sp_RealizarApuesta

        @IdUsuario = @IdUsuario,

        @SeleccionesJson = @Json,

        @Monto = @Monto,

        @ReferenciaOperacion = @Referencia,

        @IpOrigen = 'SESION_A';


    PRINT '';
    PRINT 'SESION A: APUESTA ACEPTADA';

END TRY
BEGIN CATCH

    PRINT '';
    PRINT 'SESION A: APUESTA RECHAZADA';

    PRINT 'Error: '
        + CONVERT(VARCHAR(20), ERROR_NUMBER());

    PRINT 'Mensaje: '
        + ERROR_MESSAGE();

END CATCH;
GO