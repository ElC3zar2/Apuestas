/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   07_PRUEBAS/10_PruebasIntegridad.sql

   OBJETIVO:
   Comprobar reglas estructurales fundamentales:

   1. Documento único.
   2. Una sola cuota activa por selección.
   3. Billetera no admite saldo negativo.
   4. ReferenciaOperacion de Boleto es única.
   5. Cuota debe ser mayor que 1.
   6. Integridad referencial mediante FK.

   Cada escenario utiliza su propia transacción y ROLLBACK.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT OFF;
GO


DECLARE @Correctas INT = 0;
DECLARE @Total INT = 6;


PRINT '=======================================================';
PRINT ' PRUEBAS DE INTEGRIDAD ESTRUCTURAL';
PRINT '=======================================================';
PRINT '';


/* ============================================================
   DATOS BASE
   ============================================================ */

DECLARE @IdRolUsuario INT;
DECLARE @IdEstadoUsuarioPendiente INT;
DECLARE @IdPais INT;
DECLARE @IdMunicipio INT;


SELECT @IdRolUsuario = IdRol
FROM dbo.Rol
WHERE Nombre = 'USUARIO';


SELECT @IdEstadoUsuarioPendiente = E.IdEstado
FROM dbo.Estado AS E
INNER JOIN dbo.TipoEstado AS TE
    ON TE.IdTipoEstado = E.IdTipoEstado
WHERE TE.Codigo = 'USUARIO'
  AND E.Codigo = 'PENDIENTE';


SELECT @IdPais = IdPais
FROM dbo.Pais
WHERE CodigoISO2 = 'GT';


SELECT TOP (1)
    @IdMunicipio = M.IdMunicipio
FROM dbo.Municipio AS M
INNER JOIN dbo.Departamento AS D
    ON D.IdDepartamento = M.IdDepartamento
WHERE D.IdPais = @IdPais
ORDER BY M.IdMunicipio;


IF @IdRolUsuario IS NULL
   OR @IdEstadoUsuarioPendiente IS NULL
   OR @IdPais IS NULL
   OR @IdMunicipio IS NULL
BEGIN
    THROW 70901,
          'Faltan datos base para ejecutar las pruebas de integridad.',
          1;
END;


/* ============================================================
   PRUEBA 1
   DOCUMENTO UNICO
   ============================================================ */

BEGIN TRY

    BEGIN TRANSACTION;


    DECLARE @CodigoDocumento VARCHAR(20) =
        LEFT
        (
            REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
            12
        );


    DECLARE @IdUsuario1 INT;
    DECLARE @IdUsuario2 INT;


    INSERT INTO dbo.Usuario
    (
        IdRol,
        IdEstado,
        Correo,
        Contrasena
    )
    VALUES
    (
        @IdRolUsuario,
        @IdEstadoUsuarioPendiente,
        CONCAT('integridad1.', @CodigoDocumento, '@test.local'),
        'HASH_TEMPORAL'
    );


    SET @IdUsuario1 =
        CONVERT(INT, SCOPE_IDENTITY());


    INSERT INTO dbo.Usuario
    (
        IdRol,
        IdEstado,
        Correo,
        Contrasena
    )
    VALUES
    (
        @IdRolUsuario,
        @IdEstadoUsuarioPendiente,
        CONCAT('integridad2.', @CodigoDocumento, '@test.local'),
        'HASH_TEMPORAL'
    );


    SET @IdUsuario2 =
        CONVERT(INT, SCOPE_IDENTITY());


    INSERT INTO dbo.PerfilUsuario
    (
        IdUsuario,
        Nombre,
        Apellido,
        FechaNacimiento,
        Genero,
        Telefono,
        TipoDocumento,
        NumeroDocumento,
        IdPais,
        IdMunicipio,
        CiudadExterior,
        Direccion
    )
    VALUES
    (
        @IdUsuario1,
        'Usuario',
        'Uno',
        '2000-01-01',
        'M',
        '55551001',
        'DPI',
        'DUP-' + @CodigoDocumento,
        @IdPais,
        @IdMunicipio,
        NULL,
        'Dirección de prueba'
    );


    BEGIN TRY

        INSERT INTO dbo.PerfilUsuario
        (
            IdUsuario,
            Nombre,
            Apellido,
            FechaNacimiento,
            Genero,
            Telefono,
            TipoDocumento,
            NumeroDocumento,
            IdPais,
            IdMunicipio,
            CiudadExterior,
            Direccion
        )
        VALUES
        (
            @IdUsuario2,
            'Usuario',
            'Dos',
            '2000-01-01',
            'M',
            '55551002',
            'DPI',
            'DUP-' + @CodigoDocumento,
            @IdPais,
            @IdMunicipio,
            NULL,
            'Dirección de prueba'
        );


        THROW 70902,
              'Se permitieron dos documentos iguales.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() IN (2601, 2627)
        BEGIN
            PRINT 'PRUEBA 1: OK - Documento duplicado rechazado.';
            SET @Correctas += 1;
        END
        ELSE
            THROW;

    END CATCH;


    IF XACT_STATE() <> 0
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
   UNA SOLA CUOTA ACTIVA POR SELECCION
   ============================================================ */

BEGIN TRY

    BEGIN TRANSACTION;


    DECLARE @IdDeporte INT;
    DECLARE @IdEstadoEvento INT;
    DECLARE @IdEstadoMercado INT;


    SELECT @IdDeporte = IdDeporte
    FROM dbo.Deporte
    WHERE Nombre = 'Futbol';


    SELECT @IdEstadoEvento = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'EVENTO'
      AND E.Codigo = 'BORRADOR';


    SELECT @IdEstadoMercado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'MERCADO'
      AND E.Codigo = 'BORRADOR';


    DECLARE @CodigoCuota VARCHAR(20) =
        LEFT
        (
            REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
            12
        );


    INSERT INTO dbo.Liga
    (
        IdDeporte,
        IdPais,
        Nombre
    )
    VALUES
    (
        @IdDeporte,
        @IdPais,
        'Liga Integridad ' + @CodigoCuota
    );


    DECLARE @IdLiga INT =
        CONVERT(INT, SCOPE_IDENTITY());


    INSERT INTO dbo.Evento
    (
        IdLiga,
        IdEstado,
        Nombre,
        FechaInicio
    )
    VALUES
    (
        @IdLiga,
        @IdEstadoEvento,
        'Evento Integridad ' + @CodigoCuota,
        DATEADD(DAY, 1, SYSDATETIME())
    );


    DECLARE @IdEvento INT =
        CONVERT(INT, SCOPE_IDENTITY());


    INSERT INTO dbo.Mercado
    (
        IdEvento,
        IdEstado,
        Nombre
    )
    VALUES
    (
        @IdEvento,
        @IdEstadoMercado,
        'Mercado Integridad ' + @CodigoCuota
    );


    DECLARE @IdMercado INT =
        CONVERT(INT, SCOPE_IDENTITY());


    INSERT INTO dbo.Seleccion
    (
        IdMercado,
        Nombre
    )
    VALUES
    (
        @IdMercado,
        'Seleccion Integridad'
    );


    DECLARE @IdSeleccion INT =
        CONVERT(INT, SCOPE_IDENTITY());


    INSERT INTO dbo.Cuota
    (
        IdSeleccion,
        Valor,
        Activo
    )
    VALUES
    (
        @IdSeleccion,
        1.8000,
        1
    );


    BEGIN TRY

        INSERT INTO dbo.Cuota
        (
            IdSeleccion,
            Valor,
            Activo
        )
        VALUES
        (
            @IdSeleccion,
            2.0000,
            1
        );


        THROW 70903,
              'Se permitieron dos cuotas activas.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() IN (2601, 2627)
        BEGIN
            PRINT 'PRUEBA 2: OK - Segunda cuota activa rechazada.';
            SET @Correctas += 1;
        END
        ELSE
            THROW;

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
   BILLETERA NO ADMITE SALDO NEGATIVO
   ============================================================ */

BEGIN TRY

    DECLARE @IdBilletera INT;


    SELECT TOP (1)
        @IdBilletera = IdBilletera
    FROM dbo.Billetera
    ORDER BY IdBilletera;


    IF @IdBilletera IS NULL
        THROW 70904, 'No existe billetera para la prueba.', 1;


    BEGIN TRANSACTION;


    BEGIN TRY

        UPDATE dbo.Billetera
        SET SaldoDisponible = -1
        WHERE IdBilletera = @IdBilletera;


        THROW 70905,
              'Billetera permitió saldo negativo.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() = 547
        BEGIN
            PRINT 'PRUEBA 3: OK - Saldo negativo rechazado.';
            SET @Correctas += 1;
        END
        ELSE
            THROW;

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
   REFERENCIAOPERACION DE BOLETO DEBE SER UNICA
   ============================================================ */

BEGIN TRY

    BEGIN TRANSACTION;


    DECLARE @IdUsuarioBoleto INT;


    SELECT TOP (1)
        @IdUsuarioBoleto = IdUsuario
    FROM dbo.Usuario
    ORDER BY IdUsuario;


    DECLARE @IdEstadoBoletoPendiente INT;


    SELECT @IdEstadoBoletoPendiente = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'BOLETO'
      AND E.Codigo = 'PENDIENTE';


    DECLARE @Referencia UNIQUEIDENTIFIER =
        NEWID();


    INSERT INTO dbo.Boleto
    (
        CodigoBoleto,
        IdUsuario,
        IdEstado,
        ReferenciaOperacion,
        MontoApostado,
        CuotaTotal,
        GananciaPotencial,
        TipoBoleto
    )
    VALUES
    (
        'I-' + REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
        @IdUsuarioBoleto,
        @IdEstadoBoletoPendiente,
        @Referencia,
        10.00,
        2.0000,
        20.00,
        'SIMPLE'
    );


    BEGIN TRY

        INSERT INTO dbo.Boleto
        (
            CodigoBoleto,
            IdUsuario,
            IdEstado,
            ReferenciaOperacion,
            MontoApostado,
            CuotaTotal,
            GananciaPotencial,
            TipoBoleto
        )
        VALUES
        (
            'I-' + REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
            @IdUsuarioBoleto,
            @IdEstadoBoletoPendiente,
            @Referencia,
            10.00,
            2.0000,
            20.00,
            'SIMPLE'
        );


        THROW 70906,
              'Boleto permitió ReferenciaOperacion duplicada.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() IN (2601, 2627)
        BEGIN
            PRINT 'PRUEBA 4: OK - ReferenciaOperacion duplicada rechazada.';
            SET @Correctas += 1;
        END
        ELSE
            THROW;

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
   CUOTA DEBE SER > 1
   ============================================================ */

BEGIN TRY

    BEGIN TRANSACTION;


    DECLARE @IdDeporte5 INT;
    DECLARE @IdEstadoEvento5 INT;
    DECLARE @IdEstadoMercado5 INT;


    SELECT @IdDeporte5 = IdDeporte
    FROM dbo.Deporte
    WHERE Nombre = 'Futbol';


    SELECT @IdEstadoEvento5 = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'EVENTO'
      AND E.Codigo = 'BORRADOR';


    SELECT @IdEstadoMercado5 = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'MERCADO'
      AND E.Codigo = 'BORRADOR';


    DECLARE @Codigo5 VARCHAR(12) =
        LEFT
        (
            REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
            12
        );


    INSERT INTO dbo.Liga
    (
        IdDeporte,
        IdPais,
        Nombre
    )
    VALUES
    (
        @IdDeporte5,
        @IdPais,
        'Liga Cuota Check ' + @Codigo5
    );


    DECLARE @IdLiga5 INT =
        CONVERT(INT, SCOPE_IDENTITY());


    INSERT INTO dbo.Evento
    (
        IdLiga,
        IdEstado,
        Nombre,
        FechaInicio
    )
    VALUES
    (
        @IdLiga5,
        @IdEstadoEvento5,
        'Evento Cuota Check ' + @Codigo5,
        DATEADD(DAY, 1, SYSDATETIME())
    );


    DECLARE @IdEvento5 INT =
        CONVERT(INT, SCOPE_IDENTITY());


    INSERT INTO dbo.Mercado
    (
        IdEvento,
        IdEstado,
        Nombre
    )
    VALUES
    (
        @IdEvento5,
        @IdEstadoMercado5,
        'Mercado Cuota Check ' + @Codigo5
    );


    DECLARE @IdMercado5 INT =
        CONVERT(INT, SCOPE_IDENTITY());


    INSERT INTO dbo.Seleccion
    (
        IdMercado,
        Nombre
    )
    VALUES
    (
        @IdMercado5,
        'Seleccion Check'
    );


    DECLARE @IdSeleccion5 INT =
        CONVERT(INT, SCOPE_IDENTITY());


    BEGIN TRY

        INSERT INTO dbo.Cuota
        (
            IdSeleccion,
            Valor,
            Activo
        )
        VALUES
        (
            @IdSeleccion5,
            1.0000,
            1
        );


        THROW 70907,
              'Cuota permitió Valor <= 1.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() = 547
        BEGIN
            PRINT 'PRUEBA 5: OK - Cuota <= 1 rechazada.';
            SET @Correctas += 1;
        END
        ELSE
            THROW;

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
   PRUEBA 6
   FOREIGN KEY DEBE IMPEDIR REFERENCIA INEXISTENTE
   ============================================================ */

BEGIN TRY

    BEGIN TRANSACTION;


    DECLARE @IdUsuarioFK INT;
    DECLARE @IdEstadoBoletoFK INT;


    SELECT TOP (1)
        @IdUsuarioFK = IdUsuario
    FROM dbo.Usuario
    ORDER BY IdUsuario;


    SELECT @IdEstadoBoletoFK = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'BOLETO'
      AND E.Codigo = 'PENDIENTE';


    INSERT INTO dbo.Boleto
    (
        CodigoBoleto,
        IdUsuario,
        IdEstado,
        ReferenciaOperacion,
        MontoApostado,
        CuotaTotal,
        GananciaPotencial,
        TipoBoleto
    )
    VALUES
    (
        'FK-' + REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
        @IdUsuarioFK,
        @IdEstadoBoletoFK,
        NEWID(),
        10.00,
        2.0000,
        20.00,
        'SIMPLE'
    );


    DECLARE @IdBoletoFK INT =
        CONVERT(INT, SCOPE_IDENTITY());


    BEGIN TRY

        INSERT INTO dbo.DetalleBoleto
        (
            IdBoleto,
            IdSeleccion,
            CuotaAplicada
        )
        VALUES
        (
            @IdBoletoFK,
            2147483647,
            2.0000
        );


        THROW 70908,
              'La FK permitió una selección inexistente.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() = 547
        BEGIN
            PRINT 'PRUEBA 6: OK - FK rechazó IdSeleccion inexistente.';
            SET @Correctas += 1;
        END
        ELSE
            THROW;

    END CATCH;


    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT 'PRUEBA 6: ERROR';
    PRINT ERROR_MESSAGE();

END CATCH;

PRINT '';


/* ============================================================
   RESULTADO FINAL
   ============================================================ */

PRINT '=======================================================';

PRINT 'PRUEBAS CORRECTAS: '
    + CONVERT(VARCHAR(10), @Correctas)
    + ' / '
    + CONVERT(VARCHAR(10), @Total);


IF @Correctas = @Total
BEGIN

    PRINT ' RESULTADO: INTEGRIDAD ESTRUCTURAL CORRECTA';

END
ELSE
BEGIN

    PRINT ' RESULTADO: EXISTEN REGLAS DE INTEGRIDAD POR REVISAR';

END;

PRINT '=======================================================';
GO