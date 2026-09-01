/* ============================================================
   SESION B - APUESTA CONCURRENTE

   Ejecutar en conexión/PC B.

   Ejecutar casi inmediatamente después de iniciar SESION A.
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
    @Referencia = ReferenciaB

FROM dbo.PruebaConcurrenciaContexto
WHERE IdContexto = 1;


IF @IdUsuario IS NULL
    THROW 71201,
          'Primero ejecute 01_PrepararConcurrencia.sql.',
          1;


DECLARE @Json NVARCHAR(MAX) =
    N'['
    + CONVERT(NVARCHAR(20), @IdSeleccion)
    + N']';


PRINT '=======================================================';
PRINT ' SESION B';
PRINT '=======================================================';
PRINT 'Esperando 10 segundos...';


WAITFOR DELAY '00:00:10';


BEGIN TRY

    EXEC dbo.sp_RealizarApuesta

        @IdUsuario = @IdUsuario,

        @SeleccionesJson = @Json,

        @Monto = @Monto,

        @ReferenciaOperacion = @Referencia,

        @IpOrigen = 'SESION_B';


    PRINT '';
    PRINT 'SESION B: APUESTA ACEPTADA';

END TRY
BEGIN CATCH

    PRINT '';
    PRINT 'SESION B: APUESTA RECHAZADA';

    PRINT 'Error: '
        + CONVERT(VARCHAR(20), ERROR_NUMBER());

    PRINT 'Mensaje: '
        + ERROR_MESSAGE();

END CATCH;
GO