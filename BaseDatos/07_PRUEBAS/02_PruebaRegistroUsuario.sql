/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   07_PRUEBAS/02_PruebaRegistroUsuario.sql

   OBJETIVO:
   Probar dbo.sp_RegistrarUsuarioCliente y verificar que cree
   correctamente todas las entidades relacionadas.

   IMPORTANTE:
   La prueba termina con ROLLBACK.
   NO deja datos permanentes.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


DECLARE @IdPaisGuatemala INT;
DECLARE @IdMunicipioGuatemala INT;


SELECT @IdPaisGuatemala = IdPais
FROM dbo.Pais
WHERE CodigoISO2 = 'GT'
  AND Activo = 1;


IF @IdPaisGuatemala IS NULL
    THROW 70001, 'No existe Guatemala en el catálogo de países.', 1;


/* Utilizamos el municipio Guatemala del departamento Guatemala. */

SELECT TOP (1)
    @IdMunicipioGuatemala = M.IdMunicipio
FROM dbo.Municipio AS M
INNER JOIN dbo.Departamento AS D
    ON D.IdDepartamento = M.IdDepartamento
WHERE D.IdPais = @IdPaisGuatemala
  AND D.Activo = 1
  AND M.Activo = 1
ORDER BY
    D.IdDepartamento,
    M.IdMunicipio;


IF @IdMunicipioGuatemala IS NULL
    THROW 70002, 'No se encontró ningún municipio activo de Guatemala.', 1;


/* ============================================================
   DATOS UNICOS PARA LA PRUEBA
   ============================================================ */

DECLARE @Identificador VARCHAR(32) =
    REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', '');


DECLARE @Correo VARCHAR(150) =
    CONCAT
    (
        'prueba.',
        LEFT(@Identificador, 12),
        '@apuestas.test'
    );


DECLARE @NumeroDocumento VARCHAR(50) =
    CONCAT
    (
        'TEST-',
        LEFT(@Identificador, 20)
    );


/*
   Este valor representa un hash que SQL Server debe tratar como
   una contraseña ya protegida.

   La validación BCrypt real corresponde a Java.
*/
DECLARE @ContrasenaHash VARCHAR(255) =
    '$2a$12$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ123456';


/* ============================================================
   CAPTURAR RESPUESTA DEL PROCEDIMIENTO
   ============================================================ */

DECLARE @Resultado TABLE
(
    IdUsuario INT,
    IdVerificacion INT,
    IdBilletera INT,
    IdTransaccion BIGINT NULL,
    ReferenciaOperacion UNIQUEIDENTIFIER,
    SaldoInicial DECIMAL(12,2),
    EstadoUsuario VARCHAR(40),
    EstadoVerificacion VARCHAR(40),
    CorreoVerificado BIT
);


/* ============================================================
   INICIAR TRANSACCION DE PRUEBA
   ============================================================ */

BEGIN TRY

    BEGIN TRANSACTION;


    PRINT '=======================================================';
    PRINT ' PRUEBA DE REGISTRO DE USUARIO';
    PRINT '=======================================================';
    PRINT '';

    PRINT 'Correo temporal: ' + @Correo;
    PRINT 'Documento temporal: ' + @NumeroDocumento;
    PRINT '';


    INSERT INTO @Resultado
    EXEC dbo.sp_RegistrarUsuarioCliente

        @Nombre = 'Usuario',
        @Apellido = 'Prueba',

        @Correo = @Correo,
        @Contrasena = @ContrasenaHash,

        @FechaNacimiento = '2000-01-01',

        @Genero = 'M',

        @Telefono = '55550000',

        @TipoDocumento = 'DPI',
        @NumeroDocumento = @NumeroDocumento,

        @IdPais = @IdPaisGuatemala,

        @IdMunicipio = @IdMunicipioGuatemala,

        @CiudadExterior = NULL,

        @Direccion = 'Dirección de prueba para PlataformaApuestas';


    /* ========================================================
       RESULTADO DEVUELTO POR EL PROCEDIMIENTO
       ======================================================== */

    PRINT '1. RESPUESTA DEL PROCEDIMIENTO';

    SELECT *
    FROM @Resultado;


    DECLARE @IdUsuario INT;
    DECLARE @IdVerificacion INT;
    DECLARE @IdBilletera INT;
    DECLARE @IdTransaccion BIGINT;
    DECLARE @SaldoInicial DECIMAL(12,2);


    SELECT
        @IdUsuario = IdUsuario,
        @IdVerificacion = IdVerificacion,
        @IdBilletera = IdBilletera,
        @IdTransaccion = IdTransaccion,
        @SaldoInicial = SaldoInicial
    FROM @Resultado;


    IF @IdUsuario IS NULL
        THROW 70003, 'El procedimiento no devolvió IdUsuario.', 1;


    /* ========================================================
       2. VERIFICAR USUARIO
       ======================================================== */

    PRINT '';
    PRINT '2. VERIFICAR Usuario';


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE IdUsuario = @IdUsuario
          AND Correo = @Correo
          AND CorreoVerificado = 0
    )
        THROW 70004, 'No se creó correctamente Usuario.', 1;


    SELECT
        U.IdUsuario,
        U.Correo,
        R.Nombre AS Rol,
        E.Codigo AS EstadoUsuario,
        U.CorreoVerificado,
        U.FechaRegistro

    FROM dbo.Usuario AS U

    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol

    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado

    WHERE U.IdUsuario = @IdUsuario;


    /* ========================================================
       3. VERIFICAR PERFIL
       ======================================================== */

    PRINT '';
    PRINT '3. VERIFICAR PerfilUsuario';


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.PerfilUsuario
        WHERE IdUsuario = @IdUsuario
          AND Nombre = 'Usuario'
          AND Apellido = 'Prueba'
          AND IdPais = @IdPaisGuatemala
          AND IdMunicipio = @IdMunicipioGuatemala
          AND CiudadExterior IS NULL
    )
        THROW 70005, 'No se creó correctamente PerfilUsuario.', 1;


    SELECT *
    FROM dbo.PerfilUsuario
    WHERE IdUsuario = @IdUsuario;


    /* ========================================================
       4. VERIFICAR PROCESO DE VERIFICACION
       ======================================================== */

    PRINT '';
    PRINT '4. VERIFICAR VerificacionUsuario';


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.VerificacionUsuario AS V

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = V.IdEstado

        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'VERIFICACION'

        WHERE V.IdUsuario = @IdUsuario
          AND E.Codigo = 'PENDIENTE'
    )
        THROW 70006, 'No se creó correctamente VerificacionUsuario.', 1;


    SELECT
        V.IdVerificacion,
        E.Codigo AS EstadoVerificacion,
        V.FechaSolicitud,
        V.Observacion

    FROM dbo.VerificacionUsuario AS V

    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = V.IdEstado

    WHERE V.IdUsuario = @IdUsuario;


    /* ========================================================
       5. VERIFICAR BILLETERA
       ======================================================== */

    PRINT '';
    PRINT '5. VERIFICAR Billetera';


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Billetera
        WHERE IdBilletera = @IdBilletera
          AND IdUsuario = @IdUsuario
          AND SaldoDisponible = @SaldoInicial
          AND SaldoComprometido = 0
    )
        THROW 70007, 'No se creó correctamente la billetera.', 1;


    SELECT *
    FROM dbo.Billetera
    WHERE IdUsuario = @IdUsuario;


    /* ========================================================
       6. VERIFICAR TRANSACCION DE CARGA INICIAL
       ======================================================== */

    PRINT '';
    PRINT '6. VERIFICAR TransaccionFinanciera';


    IF @SaldoInicial > 0
    BEGIN

        IF NOT EXISTS
        (
            SELECT 1

            FROM dbo.TransaccionFinanciera AS TF

            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

            WHERE TF.IdTransaccion = @IdTransaccion
              AND TF.IdBilletera = @IdBilletera
              AND TT.Codigo = 'CARGA_INICIAL'
              AND TF.Monto = @SaldoInicial
        )
            THROW 70008, 'No se creó correctamente la transacción de carga inicial.', 1;


        SELECT
            TF.IdTransaccion,
            TT.Codigo AS TipoTransaccion,
            TF.Monto,
            E.Codigo AS EstadoTransaccion,
            TF.ReferenciaOperacion,
            TF.FechaProcesamiento

        FROM dbo.TransaccionFinanciera AS TF

        INNER JOIN dbo.TipoTransaccion AS TT
            ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = TF.IdEstado

        WHERE TF.IdTransaccion = @IdTransaccion;

    END;


    /* ========================================================
       7. VERIFICAR MOVIMIENTO
       ======================================================== */

    PRINT '';
    PRINT '7. VERIFICAR MovimientoBilletera';


    IF @SaldoInicial > 0
    BEGIN

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.MovimientoBilletera
            WHERE IdBilletera = @IdBilletera
              AND IdTransaccion = @IdTransaccion
              AND SaldoDisponibleAnterior = 0
              AND SaldoDisponiblePosterior = @SaldoInicial
              AND SaldoComprometidoAnterior = 0
              AND SaldoComprometidoPosterior = 0
        )
            THROW 70009, 'No se creó correctamente MovimientoBilletera.', 1;


        SELECT *
        FROM dbo.MovimientoBilletera
        WHERE IdTransaccion = @IdTransaccion;

    END;


    /* ========================================================
       8. VERIFICAR AUDITORIA
       ======================================================== */

    PRINT '';
    PRINT '8. VERIFICAR Auditoria';


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Auditoria
        WHERE IdUsuario = @IdUsuario
          AND Accion = 'REGISTRO_USUARIO'
          AND TablaAfectada = 'Usuario'
          AND IdRegistro = @IdUsuario
    )
        THROW 70010, 'No se registró correctamente la auditoría del usuario.', 1;


    SELECT
        IdAuditoria,
        IdUsuario,
        Accion,
        TablaAfectada,
        IdRegistro,
        ReferenciaOperacion,
        Descripcion,
        FechaAccion

    FROM dbo.Auditoria

    WHERE IdUsuario = @IdUsuario;


    /* ========================================================
       RESULTADO FINAL
       ======================================================== */

    PRINT '';
    PRINT '=======================================================';
    PRINT ' RESULTADO: PRUEBA DE REGISTRO CORRECTA';
    PRINT ' Todos los componentes fueron creados correctamente.';
    PRINT '=======================================================';


    /* ========================================================
       ELIMINAR TODO LO GENERADO POR LA PRUEBA
       ======================================================== */

    ROLLBACK TRANSACTION;


    PRINT '';
    PRINT 'ROLLBACK realizado.';
    PRINT 'La prueba NO dejó datos permanentes.';


END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;


    PRINT '';
    PRINT '=======================================================';
    PRINT ' RESULTADO: ERROR EN PRUEBA DE REGISTRO';
    PRINT '=======================================================';

    PRINT 'Numero de error: '
        + CONVERT(VARCHAR(20), ERROR_NUMBER());

    PRINT 'Mensaje: '
        + ERROR_MESSAGE();

    THROW;

END CATCH;
GO