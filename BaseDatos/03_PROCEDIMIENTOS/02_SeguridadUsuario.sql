/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   03_PROCEDIMIENTOS/02_SeguridadUsuario.sql

   OBJETIVO:
   Centralizar las operaciones de seguridad relacionadas con:
   - Consulta de datos necesarios para autenticación.
   - Registro de intentos de inicio de sesión.
   - Bloqueo temporal por intentos fallidos.
   - Creación y validación de tokens de seguridad.
   - Verificación de correo.
   - Recuperación y cambio de contraseña.

   IMPORTANTE:
   - SQL Server NO valida BCrypt.
   - Java compara la contraseña con el hash BCrypt almacenado.
   - Java genera tokens criptográficamente seguros.
   - Solo se almacena el SHA-256 del token en TokenSeguridad.
   - Nunca se almacena el token original.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


/* ============================================================
   1. OBTENER DATOS PARA AUTENTICACION

   USO:
   Java obtiene el hash BCrypt y el estado de la cuenta.
   La comparación BCrypt se realiza exclusivamente en Java.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerUsuarioAutenticacion
(
    @Correo VARCHAR(150)
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @Correo =
        NULLIF(LOWER(LTRIM(RTRIM(@Correo))), '');

    IF @Correo IS NULL
        THROW 57001, 'El correo es obligatorio.', 1;

    SELECT
        U.IdUsuario,
        U.Correo,
        U.Contrasena,
        U.CorreoVerificado,

        U.IntentosFallidos,
        U.BloqueadoHasta,
        U.UltimoAcceso,

        R.IdRol,
        R.Nombre AS Rol,

        E.IdEstado,
        E.Codigo AS EstadoUsuario,
        E.Nombre AS NombreEstadoUsuario,

        CAST
        (
            CASE
                WHEN U.BloqueadoHasta IS NOT NULL
                 AND U.BloqueadoHasta > SYSDATETIME()
                    THEN 1
                ELSE 0
            END
            AS BIT
        ) AS BloqueoVigente,

        CAST
        (
            CASE
                WHEN E.Codigo IN ('PENDIENTE', 'ACTIVO')
                 AND
                 (
                     U.BloqueadoHasta IS NULL
                     OR U.BloqueadoHasta <= SYSDATETIME()
                 )
                    THEN 1
                ELSE 0
            END
            AS BIT
        ) AS PuedeIniciarSesion

    FROM dbo.Usuario AS U
    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'USUARIO'
    WHERE U.Correo = @Correo;
END;
GO


/* ============================================================
   2. REGISTRAR RESULTADO DE INTENTO DE LOGIN

   @Exitoso = 1:
       - Solo permite completar el login si no existe bloqueo
         temporal vigente.
       - Reinicia IntentosFallidos.
       - Limpia BloqueadoHasta.
       - Actualiza UltimoAcceso.

   @Exitoso = 0:
       - Incrementa IntentosFallidos.
       - Al alcanzar MAX_INTENTOS_LOGIN aplica el bloqueo
         configurado en TIEMPO_BLOQUEO_LOGIN_MIN.

   NOTA:
   La validez de la contraseña ya fue determinada por Java
   utilizando BCrypt antes de invocar este procedimiento.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_RegistrarIntentoLogin
(
    @IdUsuario INT,
    @Exitoso BIT,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @IdUsuario IS NULL
        THROW 57002, 'IdUsuario es obligatorio.', 1;

    IF @Exitoso IS NULL
        THROW 57003, 'Debe indicar si el intento fue exitoso.', 1;

    DECLARE @MaxIntentos INT;
    DECLARE @TiempoBloqueoMin INT;

    SELECT @MaxIntentos =
        TRY_CONVERT(INT, Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'MAX_INTENTOS_LOGIN';

    SELECT @TiempoBloqueoMin =
        TRY_CONVERT(INT, Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'TIEMPO_BLOQUEO_LOGIN_MIN';

    IF @MaxIntentos IS NULL OR @MaxIntentos <= 0
        THROW 57004, 'MAX_INTENTOS_LOGIN no contiene un valor válido.', 1;

    IF @TiempoBloqueoMin IS NULL OR @TiempoBloqueoMin <= 0
        THROW 57005, 'TIEMPO_BLOQUEO_LOGIN_MIN no contiene un valor válido.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IntentosFallidos INT;
        DECLARE @BloqueadoHasta DATETIME2;
        DECLARE @Ahora DATETIME2 = SYSDATETIME();
        DECLARE @BloqueoVigente BIT = 0;
        DECLARE @AutenticacionPermitida BIT = 0;

        SELECT
            @IntentosFallidos = IntentosFallidos,
            @BloqueadoHasta = BloqueadoHasta
        FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK)
        WHERE IdUsuario = @IdUsuario;

        IF @IntentosFallidos IS NULL
            THROW 57006, 'El usuario indicado no existe.', 1;

        IF @BloqueadoHasta IS NOT NULL
           AND @BloqueadoHasta > @Ahora
        BEGIN
            SET @BloqueoVigente = 1;
        END;

        /* Si el bloqueo anterior ya expiró, reiniciar el contador
           antes de evaluar el nuevo intento. */
        IF @BloqueadoHasta IS NOT NULL
           AND @BloqueadoHasta <= @Ahora
        BEGIN
            SET @IntentosFallidos = 0;
            SET @BloqueadoHasta = NULL;

            UPDATE dbo.Usuario
            SET
                IntentosFallidos = 0,
                BloqueadoHasta = NULL
            WHERE IdUsuario = @IdUsuario;
        END;


        IF @Exitoso = 1
        BEGIN

            IF @BloqueoVigente = 1
            BEGIN
                /* Una contraseña correcta no elimina un bloqueo
                   cuya vigencia todavía no ha terminado. */
                SET @AutenticacionPermitida = 0;

                INSERT INTO dbo.Auditoria
                (
                    IdUsuario,
                    Accion,
                    TablaAfectada,
                    IdRegistro,
                    IpOrigen,
                    Descripcion
                )
                VALUES
                (
                    @IdUsuario,
                    'LOGIN_BLOQUEADO',
                    'Usuario',
                    @IdUsuario,
                    @IpOrigen,
                    'Intento de acceso con bloqueo temporal vigente.'
                );
            END
            ELSE
            BEGIN
                UPDATE dbo.Usuario
                SET
                    IntentosFallidos = 0,
                    BloqueadoHasta = NULL,
                    UltimoAcceso = @Ahora
                WHERE IdUsuario = @IdUsuario;

                SET @IntentosFallidos = 0;
                SET @BloqueadoHasta = NULL;
                SET @AutenticacionPermitida = 1;

                INSERT INTO dbo.Auditoria
                (
                    IdUsuario,
                    Accion,
                    TablaAfectada,
                    IdRegistro,
                    IpOrigen,
                    Descripcion
                )
                VALUES
                (
                    @IdUsuario,
                    'LOGIN_EXITOSO',
                    'Usuario',
                    @IdUsuario,
                    @IpOrigen,
                    'Inicio de sesión validado correctamente.'
                );
            END;

        END
        ELSE
        BEGIN

            IF @BloqueoVigente = 0
            BEGIN
                SET @IntentosFallidos = @IntentosFallidos + 1;

                IF @IntentosFallidos >= @MaxIntentos
                BEGIN
                    SET @BloqueadoHasta =
                        DATEADD(MINUTE, @TiempoBloqueoMin, @Ahora);

                    SET @BloqueoVigente = 1;
                END;

                UPDATE dbo.Usuario
                SET
                    IntentosFallidos = @IntentosFallidos,
                    BloqueadoHasta = @BloqueadoHasta
                WHERE IdUsuario = @IdUsuario;
            END;

            INSERT INTO dbo.Auditoria
            (
                IdUsuario,
                Accion,
                TablaAfectada,
                IdRegistro,
                IpOrigen,
                Descripcion
            )
            VALUES
            (
                @IdUsuario,
                CASE
                    WHEN @BloqueoVigente = 1
                        THEN 'LOGIN_FALLIDO_BLOQUEADO'
                    ELSE 'LOGIN_FALLIDO'
                END,
                'Usuario',
                @IdUsuario,
                @IpOrigen,
                CASE
                    WHEN @BloqueoVigente = 1
                        THEN 'Intento fallido. La cuenta mantiene o inicia un bloqueo temporal.'
                    ELSE 'Intento de inicio de sesión fallido.'
                END
            );

        END;


        /* Obtener el estado administrativo actual de la cuenta. */
        DECLARE @EstadoUsuario VARCHAR(40);

        SELECT @EstadoUsuario = E.Codigo
        FROM dbo.Usuario AS U
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'USUARIO'
        WHERE U.IdUsuario = @IdUsuario;

        IF @EstadoUsuario NOT IN ('PENDIENTE', 'ACTIVO')
            SET @AutenticacionPermitida = 0;


        COMMIT TRANSACTION;


        SELECT
            @IdUsuario AS IdUsuario,
            @IntentosFallidos AS IntentosFallidos,
            @BloqueadoHasta AS BloqueadoHasta,

            CAST
            (
                CASE
                    WHEN @BloqueadoHasta IS NOT NULL
                     AND @BloqueadoHasta > SYSDATETIME()
                        THEN 1
                    ELSE 0
                END
                AS BIT
            ) AS BloqueoVigente,

            @AutenticacionPermitida AS AutenticacionPermitida,
            @EstadoUsuario AS EstadoUsuario;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   3. CREAR TOKEN DE SEGURIDAD

   TIPOS:
   - VERIFICACION_CORREO
   - RECUPERACION_CONTRASENA

   Java genera:
   1. Token aleatorio criptográficamente seguro.
   2. SHA-256 del token.
   3. Envía únicamente el hash hexadecimal de 64 caracteres
      a este procedimiento.

   El token original nunca llega a almacenarse en SQL Server.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CrearTokenSeguridad
(
    @Correo VARCHAR(150),
    @TipoToken VARCHAR(30),
    @TokenHash CHAR(64)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Correo =
        NULLIF(LOWER(LTRIM(RTRIM(@Correo))), '');

    SET @TipoToken =
        NULLIF(UPPER(LTRIM(RTRIM(@TipoToken))), '');

    SET @TokenHash =
        NULLIF(LTRIM(RTRIM(@TokenHash)), '');

    IF @Correo IS NULL
        THROW 57007, 'El correo es obligatorio.', 1;

    IF @TipoToken IS NULL
       OR @TipoToken NOT IN
          ('VERIFICACION_CORREO', 'RECUPERACION_CONTRASENA')
        THROW 57008, 'El tipo de token no es válido.', 1;

    IF @TokenHash IS NULL OR LEN(@TokenHash) <> 64
        THROW 57009, 'TokenHash debe contener 64 caracteres SHA-256 en formato hexadecimal.', 1;


    DECLARE @MinutosVigencia INT;

    IF @TipoToken = 'VERIFICACION_CORREO'
    BEGIN
        SELECT @MinutosVigencia =
            TRY_CONVERT(INT, Valor)
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'TIEMPO_TOKEN_VERIFICACION_MIN';
    END
    ELSE
    BEGIN
        SELECT @MinutosVigencia =
            TRY_CONVERT(INT, Valor)
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'TIEMPO_TOKEN_RECUPERACION_MIN';
    END;

    IF @MinutosVigencia IS NULL OR @MinutosVigencia <= 0
        THROW 57010, 'No existe una vigencia válida configurada para el token solicitado.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IdUsuario INT;
        DECLARE @CorreoVerificado BIT;
        DECLARE @EstadoUsuario VARCHAR(40);

        SELECT
            @IdUsuario = U.IdUsuario,
            @CorreoVerificado = U.CorreoVerificado,
            @EstadoUsuario = E.Codigo
        FROM dbo.Usuario AS U WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'USUARIO'
        WHERE U.Correo = @Correo;

        /* Respuesta genérica para no revelar públicamente si el
           correo existe o si la cuenta está cerrada. */
        IF @IdUsuario IS NULL OR @EstadoUsuario = 'CERRADO'
        BEGIN
            COMMIT TRANSACTION;

            SELECT
                CAST(0 AS BIT) AS TokenCreado,
                CAST(NULL AS INT) AS IdToken,
                CAST(NULL AS INT) AS IdUsuario,
                CAST(NULL AS DATETIME2) AS FechaExpiracion;

            RETURN;
        END;

        IF @TipoToken = 'VERIFICACION_CORREO'
           AND @CorreoVerificado = 1
        BEGIN
            COMMIT TRANSACTION;

            SELECT
                CAST(0 AS BIT) AS TokenCreado,
                CAST(NULL AS INT) AS IdToken,
                @IdUsuario AS IdUsuario,
                CAST(NULL AS DATETIME2) AS FechaExpiracion;

            RETURN;
        END;


        /* Invalidar tokens anteriores todavía pendientes del mismo
           tipo. FechaUso también representa invalidación controlada. */
        UPDATE dbo.TokenSeguridad
        SET FechaUso = SYSDATETIME()
        WHERE IdUsuario = @IdUsuario
          AND TipoToken = @TipoToken
          AND FechaUso IS NULL;


        DECLARE @FechaExpiracion DATETIME2 =
            DATEADD(MINUTE, @MinutosVigencia, SYSDATETIME());

        INSERT INTO dbo.TokenSeguridad
        (
            IdUsuario,
            TipoToken,
            TokenHash,
            FechaExpiracion
        )
        VALUES
        (
            @IdUsuario,
            @TipoToken,
            @TokenHash,
            @FechaExpiracion
        );

        DECLARE @IdToken INT =
            CONVERT(INT, SCOPE_IDENTITY());


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
            @IdUsuario,
            'TOKEN_SEGURIDAD_CREADO',
            'TokenSeguridad',
            @IdToken,
            CONCAT('Token creado para operación ', @TipoToken, '.')
        );


        COMMIT TRANSACTION;


        SELECT
            CAST(1 AS BIT) AS TokenCreado,
            @IdToken AS IdToken,
            @IdUsuario AS IdUsuario,
            @FechaExpiracion AS FechaExpiracion;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   4. VALIDAR TOKEN DE SEGURIDAD

   Este procedimiento NO consume el token.
   Permite a Java comprobar si el hash todavía es válido antes
   de mostrar o procesar la operación correspondiente.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ValidarTokenSeguridad
(
    @TokenHash CHAR(64),
    @TipoToken VARCHAR(30)
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @TokenHash =
        NULLIF(LTRIM(RTRIM(@TokenHash)), '');

    SET @TipoToken =
        NULLIF(UPPER(LTRIM(RTRIM(@TipoToken))), '');

    IF @TokenHash IS NULL OR LEN(@TokenHash) <> 64
        THROW 57011, 'TokenHash no es válido.', 1;

    IF @TipoToken IS NULL
       OR @TipoToken NOT IN
          ('VERIFICACION_CORREO', 'RECUPERACION_CONTRASENA')
        THROW 57012, 'El tipo de token no es válido.', 1;


    DECLARE @IdToken INT;
    DECLARE @IdUsuario INT;
    DECLARE @FechaExpiracion DATETIME2;
    DECLARE @FechaUso DATETIME2;

    SELECT
        @IdToken = T.IdToken,
        @IdUsuario = T.IdUsuario,
        @FechaExpiracion = T.FechaExpiracion,
        @FechaUso = T.FechaUso
    FROM dbo.TokenSeguridad AS T
    WHERE T.TokenHash = @TokenHash
      AND T.TipoToken = @TipoToken;


    SELECT
        CAST
        (
            CASE
                WHEN @IdToken IS NOT NULL
                 AND @FechaUso IS NULL
                 AND @FechaExpiracion > SYSDATETIME()
                    THEN 1
                ELSE 0
            END
            AS BIT
        ) AS Valido,

        @IdToken AS IdToken,
        @IdUsuario AS IdUsuario,
        @FechaExpiracion AS FechaExpiracion;
END;
GO


/* ============================================================
   5. VERIFICAR CORREO MEDIANTE TOKEN

   - Consume el token.
   - Marca CorreoVerificado = 1.
   - NO activa automáticamente la cuenta.
   - La verificación administrativa continúa siendo un proceso
     separado en VerificacionUsuario.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_VerificarCorreoConToken
(
    @TokenHash CHAR(64)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @TokenHash =
        NULLIF(LTRIM(RTRIM(@TokenHash)), '');

    IF @TokenHash IS NULL OR LEN(@TokenHash) <> 64
        THROW 57013, 'TokenHash no es válido.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IdToken INT;
        DECLARE @IdUsuario INT;
        DECLARE @FechaExpiracion DATETIME2;
        DECLARE @FechaUso DATETIME2;

        SELECT
            @IdToken = IdToken,
            @IdUsuario = IdUsuario,
            @FechaExpiracion = FechaExpiracion,
            @FechaUso = FechaUso
        FROM dbo.TokenSeguridad WITH (UPDLOCK, HOLDLOCK)
        WHERE TokenHash = @TokenHash
          AND TipoToken = 'VERIFICACION_CORREO';

        IF @IdToken IS NULL
            THROW 57014, 'El token de verificación no existe.', 1;

        IF @FechaUso IS NOT NULL
            THROW 57015, 'El token de verificación ya fue utilizado o invalidado.', 1;

        IF @FechaExpiracion <= SYSDATETIME()
            THROW 57016, 'El token de verificación ha expirado.', 1;


        UPDATE dbo.Usuario
        SET CorreoVerificado = 1
        WHERE IdUsuario = @IdUsuario;


        UPDATE dbo.TokenSeguridad
        SET FechaUso = SYSDATETIME()
        WHERE IdToken = @IdToken;


        /* Invalidar cualquier otro token de verificación pendiente. */
        UPDATE dbo.TokenSeguridad
        SET FechaUso = SYSDATETIME()
        WHERE IdUsuario = @IdUsuario
          AND TipoToken = 'VERIFICACION_CORREO'
          AND IdToken <> @IdToken
          AND FechaUso IS NULL;


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
            @IdUsuario,
            'CORREO_VERIFICADO',
            'Usuario',
            @IdUsuario,
            'Correo electrónico verificado mediante token de seguridad.'
        );


        COMMIT TRANSACTION;


        SELECT
            @IdUsuario AS IdUsuario,
            CAST(1 AS BIT) AS CorreoVerificado;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   6. RESTABLECER CONTRASEÑA MEDIANTE TOKEN

   Java:
   - Recibe la nueva contraseña del usuario.
   - Genera el nuevo hash BCrypt.
   - Envía únicamente el hash BCrypt a este procedimiento.

   SQL Server:
   - Valida y consume el token.
   - Actualiza el hash.
   - Reinicia intentos fallidos y bloqueo temporal.
   - Invalida otros tokens de recuperación pendientes.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_RestablecerContrasenaConToken
(
    @TokenHash CHAR(64),
    @NuevaContrasena VARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @TokenHash =
        NULLIF(LTRIM(RTRIM(@TokenHash)), '');

    SET @NuevaContrasena =
        NULLIF(LTRIM(RTRIM(@NuevaContrasena)), '');

    IF @TokenHash IS NULL OR LEN(@TokenHash) <> 64
        THROW 57017, 'TokenHash no es válido.', 1;

    IF @NuevaContrasena IS NULL
        THROW 57018, 'La nueva contraseña protegida es obligatoria.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IdToken INT;
        DECLARE @IdUsuario INT;
        DECLARE @FechaExpiracion DATETIME2;
        DECLARE @FechaUso DATETIME2;

        SELECT
            @IdToken = IdToken,
            @IdUsuario = IdUsuario,
            @FechaExpiracion = FechaExpiracion,
            @FechaUso = FechaUso
        FROM dbo.TokenSeguridad WITH (UPDLOCK, HOLDLOCK)
        WHERE TokenHash = @TokenHash
          AND TipoToken = 'RECUPERACION_CONTRASENA';

        IF @IdToken IS NULL
            THROW 57019, 'El token de recuperación no existe.', 1;

        IF @FechaUso IS NOT NULL
            THROW 57020, 'El token de recuperación ya fue utilizado o invalidado.', 1;

        IF @FechaExpiracion <= SYSDATETIME()
            THROW 57021, 'El token de recuperación ha expirado.', 1;


        UPDATE dbo.Usuario
        SET
            Contrasena = @NuevaContrasena,
            IntentosFallidos = 0,
            BloqueadoHasta = NULL
        WHERE IdUsuario = @IdUsuario;


        IF @@ROWCOUNT = 0
            THROW 57022, 'El usuario asociado al token no existe.', 1;


        UPDATE dbo.TokenSeguridad
        SET FechaUso = SYSDATETIME()
        WHERE IdToken = @IdToken;


        /* Invalidar otros tokens de recuperación pendientes. */
        UPDATE dbo.TokenSeguridad
        SET FechaUso = SYSDATETIME()
        WHERE IdUsuario = @IdUsuario
          AND TipoToken = 'RECUPERACION_CONTRASENA'
          AND IdToken <> @IdToken
          AND FechaUso IS NULL;


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
            @IdUsuario,
            'CONTRASENA_RESTABLECIDA',
            'Usuario',
            @IdUsuario,
            'Contraseña actualizada mediante token de recuperación.'
        );


        COMMIT TRANSACTION;


        SELECT
            @IdUsuario AS IdUsuario,
            CAST(1 AS BIT) AS ContrasenaActualizada;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   7. CAMBIAR CONTRASEÑA DE USUARIO AUTENTICADO

   Este procedimiento NO valida la contraseña actual.
   Java debe autenticar previamente al usuario mediante BCrypt.

   Sirve para el cambio voluntario de contraseña desde una
   sesión autenticada.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CambiarContrasenaUsuario
(
    @IdUsuario INT,
    @NuevaContrasena VARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NuevaContrasena =
        NULLIF(LTRIM(RTRIM(@NuevaContrasena)), '');

    IF @IdUsuario IS NULL
        THROW 57023, 'IdUsuario es obligatorio.', 1;

    IF @NuevaContrasena IS NULL
        THROW 57024, 'La nueva contraseña protegida es obligatoria.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK)
            WHERE IdUsuario = @IdUsuario
        )
            THROW 57025, 'El usuario indicado no existe.', 1;


        UPDATE dbo.Usuario
        SET
            Contrasena = @NuevaContrasena,
            IntentosFallidos = 0,
            BloqueadoHasta = NULL
        WHERE IdUsuario = @IdUsuario;


        /* Al cambiar voluntariamente la contraseña, cualquier
           recuperación pendiente deja de ser válida. */
        UPDATE dbo.TokenSeguridad
        SET FechaUso = SYSDATETIME()
        WHERE IdUsuario = @IdUsuario
          AND TipoToken = 'RECUPERACION_CONTRASENA'
          AND FechaUso IS NULL;


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
            @IdUsuario,
            'CONTRASENA_CAMBIADA',
            'Usuario',
            @IdUsuario,
            'Contraseña actualizada desde una sesión autenticada.'
        );


        COMMIT TRANSACTION;


        SELECT
            @IdUsuario AS IdUsuario,
            CAST(1 AS BIT) AS ContrasenaActualizada;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


PRINT '=======================================================';
PRINT ' PROCEDIMIENTOS DE SEGURIDAD CREADOS / ACTUALIZADOS';
PRINT '=======================================================';
GO