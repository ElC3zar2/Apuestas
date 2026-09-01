/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   07_PRUEBAS/09_PruebaAuditoria.sql

   OBJETIVO:
   Probar:
   - vw_AuditoriaSistema
   - Auditoría automática de ConfiguracionSistema
   - Protección UPDATE/DELETE de Auditoria
   - Protección UPDATE/DELETE de MovimientoBilletera
   - Protección DELETE de TransaccionFinanciera
   - Protección DELETE de ConfiguracionSistema

   TODAS LAS PRUEBAS SON REVERSIBLES.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT OFF;
GO


DECLARE @PruebasCorrectas INT = 0;
DECLARE @PruebasTotales INT = 5;


PRINT '=======================================================';
PRINT ' PRUEBA DE AUDITORIA Y PROTECCION DE HISTORIALES';
PRINT '=======================================================';
PRINT '';


/* ============================================================
   PRUEBA 1
   MODIFICAR CONFIGURACION DEBE GENERAR AUDITORIA
   ============================================================ */

BEGIN TRY

    BEGIN TRANSACTION;


    DECLARE @IdConfiguracion INT;
    DECLARE @DescripcionOriginal VARCHAR(250);


    SELECT TOP (1)
        @IdConfiguracion = IdConfiguracion,
        @DescripcionOriginal = Descripcion
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'MONTO_MINIMO_APUESTA';


    IF @IdConfiguracion IS NULL
        THROW 70801, 'No existe MONTO_MINIMO_APUESTA.', 1;


    UPDATE dbo.ConfiguracionSistema
    SET Descripcion =
        CONCAT
        (
            COALESCE(@DescripcionOriginal, ''),
            ' [PRUEBA AUDITORIA]'
        )
    WHERE IdConfiguracion = @IdConfiguracion;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Auditoria
        WHERE TablaAfectada = 'ConfiguracionSistema'
          AND IdRegistro = @IdConfiguracion
          AND Accion = 'CONFIGURACION_MODIFICADA'
    )
        THROW 70802,
              'El cambio de configuración no generó auditoría.',
              1;


    PRINT 'PRUEBA 1: OK - ConfiguracionSistema genera auditoría.';

    SET @PruebasCorrectas += 1;


    ROLLBACK TRANSACTION;

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT 'PRUEBA 1: ERROR';
    PRINT ERROR_MESSAGE();

END CATCH;

PRINT '';


/* ============================================================
   PRUEBA 2
   AUDITORIA NO DEBE ACEPTAR UPDATE
   ERROR ESPERADO: 64001
   ============================================================ */

BEGIN TRY

    BEGIN TRANSACTION;


    DECLARE @IdAuditoriaPrueba BIGINT;


    INSERT INTO dbo.Auditoria
    (
        IdUsuario,
        Accion,
        TablaAfectada,
        IdRegistro,
        Descripcion
    )
    VALUES
    (
        NULL,
        'PRUEBA_TEMPORAL',
        'Auditoria',
        0,
        'Registro temporal para comprobar inmutabilidad.'
    );


    SET @IdAuditoriaPrueba =
        CONVERT(BIGINT, SCOPE_IDENTITY());


    BEGIN TRY

        UPDATE dbo.Auditoria
        SET Descripcion = 'MODIFICACION NO PERMITIDA'
        WHERE IdAuditoria = @IdAuditoriaPrueba;


        THROW 70803,
              'Auditoria permitió UPDATE cuando debía bloquearlo.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() = 64001
        BEGIN

            PRINT 'PRUEBA 2: OK - Auditoria bloquea UPDATE.';

            SET @PruebasCorrectas += 1;

        END
        ELSE
        BEGIN
            THROW;
        END;

    END CATCH;


    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT 'PRUEBA 2: ERROR';
    PRINT ERROR_MESSAGE();

END CATCH;

PRINT '';


/* ============================================================
   PRUEBA 3
   MOVIMIENTOBILLETERA NO DEBE ACEPTAR UPDATE
   ERROR ESPERADO: 64002
   ============================================================ */

BEGIN TRY

    DECLARE @IdMovimiento BIGINT;


    SELECT TOP (1)
        @IdMovimiento = IdMovimiento
    FROM dbo.MovimientoBilletera
    ORDER BY IdMovimiento;


    IF @IdMovimiento IS NULL
        THROW 70804,
              'No existe MovimientoBilletera para ejecutar la prueba.',
              1;


    BEGIN TRANSACTION;


    BEGIN TRY

        UPDATE dbo.MovimientoBilletera
        SET FechaMovimiento = FechaMovimiento
        WHERE IdMovimiento = @IdMovimiento;


        THROW 70805,
              'MovimientoBilletera permitió UPDATE.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() = 64002
        BEGIN

            PRINT 'PRUEBA 3: OK - MovimientoBilletera es inmutable.';

            SET @PruebasCorrectas += 1;

        END
        ELSE
        BEGIN
            THROW;
        END;

    END CATCH;


    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT 'PRUEBA 3: ERROR';
    PRINT ERROR_MESSAGE();

END CATCH;

PRINT '';


/* ============================================================
   PRUEBA 4
   TRANSACCIONFINANCIERA NO DEBE ACEPTAR DELETE
   ERROR ESPERADO: 64003
   ============================================================ */

BEGIN TRY

    DECLARE @IdTransaccion BIGINT;


    SELECT TOP (1)
        @IdTransaccion = IdTransaccion
    FROM dbo.TransaccionFinanciera
    ORDER BY IdTransaccion;


    IF @IdTransaccion IS NULL
        THROW 70806,
              'No existe TransaccionFinanciera para ejecutar la prueba.',
              1;


    BEGIN TRANSACTION;


    BEGIN TRY

        DELETE FROM dbo.TransaccionFinanciera
        WHERE IdTransaccion = @IdTransaccion;


        THROW 70807,
              'TransaccionFinanciera permitió DELETE.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() = 64003
        BEGIN

            PRINT 'PRUEBA 4: OK - TransaccionFinanciera bloquea DELETE.';

            SET @PruebasCorrectas += 1;

        END
        ELSE
        BEGIN
            THROW;
        END;

    END CATCH;


    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT 'PRUEBA 4: ERROR';
    PRINT ERROR_MESSAGE();

END CATCH;

PRINT '';


/* ============================================================
   PRUEBA 5
   CONFIGURACIONSISTEMA NO DEBE ACEPTAR DELETE
   ERROR ESPERADO: 64004
   ============================================================ */

BEGIN TRY

    DECLARE @IdConfiguracionEliminar INT;


    SELECT TOP (1)
        @IdConfiguracionEliminar = IdConfiguracion
    FROM dbo.ConfiguracionSistema
    ORDER BY IdConfiguracion;


    IF @IdConfiguracionEliminar IS NULL
        THROW 70808,
              'No existe ConfiguracionSistema para ejecutar la prueba.',
              1;


    BEGIN TRANSACTION;


    BEGIN TRY

        DELETE FROM dbo.ConfiguracionSistema
        WHERE IdConfiguracion = @IdConfiguracionEliminar;


        THROW 70809,
              'ConfiguracionSistema permitió DELETE.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() = 64004
        BEGIN

            PRINT 'PRUEBA 5: OK - ConfiguracionSistema bloquea DELETE.';

            SET @PruebasCorrectas += 1;

        END
        ELSE
        BEGIN
            THROW;
        END;

    END CATCH;


    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT 'PRUEBA 5: ERROR';
    PRINT ERROR_MESSAGE();

END CATCH;

PRINT '';


/* ============================================================
   VISTA DE AUDITORIA
   ============================================================ */

PRINT 'VERIFICACION DE vw_AuditoriaSistema';

SELECT TOP (20)
    *
FROM dbo.vw_AuditoriaSistema
ORDER BY IdAuditoria DESC;


/* ============================================================
   RESULTADO
   ============================================================ */

PRINT '';
PRINT '=======================================================';

PRINT 'PRUEBAS CORRECTAS: '
    + CONVERT(VARCHAR(10), @PruebasCorrectas)
    + ' / '
    + CONVERT(VARCHAR(10), @PruebasTotales);


IF @PruebasCorrectas = @PruebasTotales
BEGIN

    PRINT ' RESULTADO: AUDITORIA Y TRIGGERS CORRECTOS';

END
ELSE
BEGIN

    PRINT ' RESULTADO: EXISTEN PRUEBAS DE AUDITORIA PENDIENTES';

END;

PRINT '=======================================================';
GO