/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   07_PRUEBAS/07_PruebaSeguridad.sql

   OBJETIVO:
   Probar:
   - sp_ObtenerUsuarioAutenticacion
   - sp_RegistrarIntentoLogin
   - Bloqueo por intentos fallidos
   - Desbloqueo al expirar el tiempo
   - sp_CrearTokenSeguridad
   - sp_ValidarTokenSeguridad
   - sp_VerificarCorreoConToken
   - sp_RestablecerContrasenaConToken
   - sp_CambiarContrasenaUsuario

   IMPORTANTE:
   SQL Server NO compara BCrypt.
   Java es responsable de validar la contraseña real.

   TODA LA PRUEBA TERMINA CON ROLLBACK.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


BEGIN TRY

    BEGIN TRANSACTION;


    PRINT '=======================================================';
    PRINT ' PRUEBA DE SEGURIDAD';
    PRINT '=======================================================';


    /* ========================================================
       1. GEOGRAFIA
       ======================================================== */

    DECLARE @IdPais INT;
    DECLARE @IdMunicipio INT;


    SELECT @IdPais = IdPais
    FROM dbo.Pais
    WHERE CodigoISO2 = 'GT'
      AND Activo = 1;


    SELECT TOP (1)
        @IdMunicipio = M.IdMunicipio
    FROM dbo.Municipio AS M
    INNER JOIN dbo.Departamento AS D
        ON D.IdDepartamento = M.IdDepartamento
    WHERE D.IdPais = @IdPais
      AND D.Activo = 1
      AND M.Activo = 1
    ORDER BY M.IdMunicipio;


    IF @IdPais IS NULL OR @IdMunicipio IS NULL
        THROW 70501, 'No existe la geografía necesaria para la prueba.', 1;


    /* ========================================================
       2. CREAR USUARIO TEMPORAL
       ======================================================== */

    DECLARE @Codigo VARCHAR(20) =
        LEFT
        (
            REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
            12
        );

    DECLARE @Documento VARCHAR(50) =
        CONCAT('SEG-', @Codigo);

    DECLARE @Correo VARCHAR(150) =
        CONCAT('seguridad.', @Codigo, '@apuestas.test');


    DECLARE @HashInicial VARCHAR(255) =
        '$2a$12$HashInicialTemporalParaPruebaSeguridad12345678901234567890';


    EXEC dbo.sp_RegistrarUsuarioCliente

        @Nombre = 'Usuario',
        @Apellido = 'Seguridad',

        @Correo = @Correo,

        @Contrasena = @HashInicial,

        @FechaNacimiento = '2000-01-01',

        @Genero = 'M',

        @Telefono = '55550300',

        @TipoDocumento = 'DPI',

        @NumeroDocumento = @Documento,

        @IdPais = @IdPais,

        @IdMunicipio = @IdMunicipio,

        @CiudadExterior = NULL,

        @Direccion = 'Dirección temporal prueba seguridad';


    DECLARE @IdUsuario INT;


    SELECT @IdUsuario = IdUsuario
    FROM dbo.Usuario
    WHERE Correo = @Correo;


    IF @IdUsuario IS NULL
        THROW 70502, 'No se creó el usuario temporal.', 1;


    PRINT '';
    PRINT 'Usuario temporal: '
        + CONVERT(VARCHAR(20), @IdUsuario);


    /* ========================================================
       3. OBTENER DATOS PARA AUTENTICACION
       ======================================================== */

    PRINT '';
    PRINT '1. OBTENER USUARIO PARA AUTENTICACION';


    EXEC dbo.sp_ObtenerUsuarioAutenticacion
        @Correo = @Correo;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE IdUsuario = @IdUsuario
          AND Correo = @Correo
          AND Contrasena = @HashInicial
    )
        THROW 70503, 'La información de autenticación no coincide.', 1;


    PRINT 'Consulta de autenticación: OK';


    /* ========================================================
       4. INTENTOS FALLIDOS
       ======================================================== */

    DECLARE @MaxIntentos INT;


    SELECT @MaxIntentos =
        TRY_CONVERT(INT, Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'MAX_INTENTOS_LOGIN';


    IF @MaxIntentos IS NULL OR @MaxIntentos <= 0
        THROW 70504, 'MAX_INTENTOS_LOGIN no es válido.', 1;


    PRINT '';
    PRINT '2. SIMULAR INTENTOS FALLIDOS';


    DECLARE @Contador INT = 1;


    WHILE @Contador <= @MaxIntentos
    BEGIN

        EXEC dbo.sp_RegistrarIntentoLogin

            @IdUsuario = @IdUsuario,

            @Exitoso = 0,

            @IpOrigen = '127.0.0.1';


        SET @Contador = @Contador + 1;

    END;


    DECLARE @IntentosFallidos INT;
    DECLARE @BloqueadoHasta DATETIME2;


    SELECT
        @IntentosFallidos = IntentosFallidos,
        @BloqueadoHasta = BloqueadoHasta

    FROM dbo.Usuario
    WHERE IdUsuario = @IdUsuario;


    IF @IntentosFallidos < @MaxIntentos
        THROW 70505, 'No se registraron correctamente los intentos fallidos.', 1;


    IF @BloqueadoHasta IS NULL
       OR @BloqueadoHasta <= SYSDATETIME()
        THROW 70506, 'El usuario no quedó bloqueado.', 1;


    PRINT 'Bloqueo temporal aplicado: OK';


    /* ========================================================
       5. CONTRASEÑA CORRECTA NO DEBE ELIMINAR BLOQUEO VIGENTE
       ======================================================== */

    PRINT '';
    PRINT '3. LOGIN CORRECTO DURANTE BLOQUEO';


    EXEC dbo.sp_RegistrarIntentoLogin

        @IdUsuario = @IdUsuario,

        @Exitoso = 1,

        @IpOrigen = '127.0.0.1';


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE IdUsuario = @IdUsuario
          AND BloqueadoHasta > SYSDATETIME()
    )
        THROW 70507, 'Una contraseña correcta eliminó indebidamente el bloqueo vigente.', 1;


    PRINT 'Bloqueo respetado: OK';


    /* ========================================================
       6. SIMULAR EXPIRACION DEL BLOQUEO
       ======================================================== */

    UPDATE dbo.Usuario
    SET BloqueadoHasta =
        DATEADD(MINUTE, -1, SYSDATETIME())
    WHERE IdUsuario = @IdUsuario;


    EXEC dbo.sp_RegistrarIntentoLogin

        @IdUsuario = @IdUsuario,

        @Exitoso = 1,

        @IpOrigen = '127.0.0.1';


    IF EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE IdUsuario = @IdUsuario
          AND
          (
              IntentosFallidos <> 0
              OR BloqueadoHasta IS NOT NULL
              OR UltimoAcceso IS NULL
          )
    )
        THROW 70508, 'El login posterior a la expiración no limpió correctamente el bloqueo.', 1;


    PRINT 'Desbloqueo por expiración: OK';


    /* ========================================================
       7. TOKEN DE VERIFICACION DE CORREO
       ======================================================== */

    PRINT '';
    PRINT '4. TOKEN DE VERIFICACION DE CORREO';


    DECLARE @TokenVerificacion CHAR(64);


    SET @TokenVerificacion =
        CONVERT
        (
            CHAR(64),
            HASHBYTES
            (
                'SHA2_256',
                CONCAT
                (
                    'VERIFICACION-',
                    CONVERT(VARCHAR(36), NEWID())
                )
            ),
            2
        );


    EXEC dbo.sp_CrearTokenSeguridad

        @Correo = @Correo,

        @TipoToken = 'VERIFICACION_CORREO',

        @TokenHash = @TokenVerificacion;


    DECLARE @IdTokenVerificacion INT;


    SELECT @IdTokenVerificacion = IdToken
    FROM dbo.TokenSeguridad
    WHERE TokenHash = @TokenVerificacion
      AND TipoToken = 'VERIFICACION_CORREO';


    IF @IdTokenVerificacion IS NULL
        THROW 70509, 'No se creó el token de verificación.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TokenSeguridad
        WHERE IdToken = @IdTokenVerificacion
          AND FechaUso IS NULL
          AND FechaExpiracion > SYSDATETIME()
    )
        THROW 70510, 'El token de verificación no está vigente.', 1;


    EXEC dbo.sp_ValidarTokenSeguridad

        @TokenHash = @TokenVerificacion,

        @TipoToken = 'VERIFICACION_CORREO';


    /* ========================================================
       8. VERIFICAR CORREO
       ======================================================== */

    EXEC dbo.sp_VerificarCorreoConToken
        @TokenHash = @TokenVerificacion;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE IdUsuario = @IdUsuario
          AND CorreoVerificado = 1
    )
        THROW 70511, 'El correo no quedó verificado.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TokenSeguridad
        WHERE IdToken = @IdTokenVerificacion
          AND FechaUso IS NOT NULL
    )
        THROW 70512, 'El token de verificación no fue consumido.', 1;


    PRINT 'Verificación de correo: OK';


    /* ========================================================
       9. TOKEN DE RECUPERACION
       ======================================================== */

    PRINT '';
    PRINT '5. RECUPERACION DE CONTRASENA';


    DECLARE @TokenRecuperacion CHAR(64);


    SET @TokenRecuperacion =
        CONVERT
        (
            CHAR(64),
            HASHBYTES
            (
                'SHA2_256',
                CONCAT
                (
                    'RECUPERACION-',
                    CONVERT(VARCHAR(36), NEWID())
                )
            ),
            2
        );


    EXEC dbo.sp_CrearTokenSeguridad

        @Correo = @Correo,

        @TipoToken = 'RECUPERACION_CONTRASENA',

        @TokenHash = @TokenRecuperacion;


    DECLARE @IdTokenRecuperacion INT;


    SELECT @IdTokenRecuperacion = IdToken
    FROM dbo.TokenSeguridad
    WHERE TokenHash = @TokenRecuperacion;


    IF @IdTokenRecuperacion IS NULL
        THROW 70513, 'No se creó el token de recuperación.', 1;


    EXEC dbo.sp_ValidarTokenSeguridad

        @TokenHash = @TokenRecuperacion,

        @TipoToken = 'RECUPERACION_CONTRASENA';


    /* Simular cuenta con intentos/bloqueo previo. */

    UPDATE dbo.Usuario
    SET
        IntentosFallidos = 2,
        BloqueadoHasta =
            DATEADD(MINUTE, 10, SYSDATETIME())
    WHERE IdUsuario = @IdUsuario;


    DECLARE @NuevoHash VARCHAR(255) =
        '$2a$12$NuevaContrasenaHashPruebaRecuperacion123456789012345678';


    EXEC dbo.sp_RestablecerContrasenaConToken

        @TokenHash = @TokenRecuperacion,

        @NuevaContrasena = @NuevoHash;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE IdUsuario = @IdUsuario
          AND Contrasena = @NuevoHash
          AND IntentosFallidos = 0
          AND BloqueadoHasta IS NULL
    )
        THROW 70514, 'La recuperación no actualizó correctamente la contraseña.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TokenSeguridad
        WHERE IdToken = @IdTokenRecuperacion
          AND FechaUso IS NOT NULL
    )
        THROW 70515, 'El token de recuperación no fue consumido.', 1;


    PRINT 'Restablecimiento de contraseña: OK';


    /* ========================================================
       10. CAMBIO VOLUNTARIO DE CONTRASENA
       ======================================================== */

    PRINT '';
    PRINT '6. CAMBIO VOLUNTARIO DE CONTRASENA';


    /* Crear un token pendiente para comprobar que el cambio
       voluntario lo invalida. */

    DECLARE @TokenPendiente CHAR(64);


    SET @TokenPendiente =
        CONVERT
        (
            CHAR(64),
            HASHBYTES
            (
                'SHA2_256',
                CONCAT
                (
                    'RECUPERACION-PENDIENTE-',
                    CONVERT(VARCHAR(36), NEWID())
                )
            ),
            2
        );


    EXEC dbo.sp_CrearTokenSeguridad

        @Correo = @Correo,

        @TipoToken = 'RECUPERACION_CONTRASENA',

        @TokenHash = @TokenPendiente;


    DECLARE @HashFinal VARCHAR(255) =
        '$2a$12$HashFinalCambioVoluntarioPrueba123456789012345678901234';


    EXEC dbo.sp_CambiarContrasenaUsuario

        @IdUsuario = @IdUsuario,

        @NuevaContrasena = @HashFinal;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE IdUsuario = @IdUsuario
          AND Contrasena = @HashFinal
          AND IntentosFallidos = 0
          AND BloqueadoHasta IS NULL
    )
        THROW 70516, 'El cambio voluntario de contraseña falló.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TokenSeguridad
        WHERE TokenHash = @TokenPendiente
          AND FechaUso IS NOT NULL
    )
        THROW 70517, 'El cambio de contraseña no invalidó el token de recuperación pendiente.', 1;


    PRINT 'Cambio voluntario e invalidación de tokens: OK';


    /* ========================================================
       11. AUDITORIA
       ======================================================== */

    PRINT '';
    PRINT '7. VERIFICAR AUDITORIA';


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Auditoria
        WHERE IdUsuario = @IdUsuario
          AND Accion = 'CORREO_VERIFICADO'
    )
        THROW 70518, 'No existe auditoría de correo verificado.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Auditoria
        WHERE IdUsuario = @IdUsuario
          AND Accion = 'CONTRASENA_RESTABLECIDA'
    )
        THROW 70519, 'No existe auditoría de recuperación de contraseña.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Auditoria
        WHERE IdUsuario = @IdUsuario
          AND Accion = 'CONTRASENA_CAMBIADA'
    )
        THROW 70520, 'No existe auditoría de cambio de contraseña.', 1;


    PRINT 'Auditoría de seguridad: OK';


    /* ========================================================
       RESULTADO FINAL
       ======================================================== */

    PRINT '';
    PRINT '=======================================================';
    PRINT ' RESULTADO: PRUEBA DE SEGURIDAD CORRECTA';
    PRINT '=======================================================';


    ROLLBACK TRANSACTION;


    PRINT 'ROLLBACK realizado.';
    PRINT 'No quedaron datos permanentes.';


END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;


    PRINT '';
    PRINT '=======================================================';
    PRINT ' ERROR EN PRUEBA DE SEGURIDAD';
    PRINT '=======================================================';

    PRINT 'Error: '
        + CONVERT(VARCHAR(20), ERROR_NUMBER());

    PRINT 'Mensaje: '
        + ERROR_MESSAGE();

    THROW;

END CATCH;
GO