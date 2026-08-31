/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   02_CONFIGURACION/01_ConfiguracionSistema.sql

   OBJETIVO:
   Crear los parámetros iniciales de funcionamiento.

   IMPORTANTE:
   - Los valores representan configuración del sistema.
   - No utiliza USE para mantener compatibilidad con Azure SQL.
   - Es re-ejecutable.
   - No modifica configuraciones que ya existan.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    /* ========================================================
       SALDO VIRTUAL INICIAL DEL USUARIO
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'SALDO_INICIAL_USUARIO'
    )
    BEGIN
        INSERT INTO dbo.ConfiguracionSistema
        (
            Clave,
            Valor,
            Descripcion
        )
        VALUES
        (
            'SALDO_INICIAL_USUARIO',
            '500.00',
            'Saldo virtual asignado automáticamente al registrar un usuario cliente.'
        );
    END;


    /* ========================================================
       CAPITAL VIRTUAL INICIAL DE LA CASA
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'SALDO_INICIAL_CASA'
    )
    BEGIN
        INSERT INTO dbo.ConfiguracionSistema
        (
            Clave,
            Valor,
            Descripcion
        )
        VALUES
        (
            'SALDO_INICIAL_CASA',
            '100000.00',
            'Capital virtual inicial asignado a la cuenta CASA.'
        );
    END;


    /* ========================================================
       EDAD MINIMA
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'EDAD_MINIMA_USUARIO'
    )
    BEGIN
        INSERT INTO dbo.ConfiguracionSistema
        (
            Clave,
            Valor,
            Descripcion
        )
        VALUES
        (
            'EDAD_MINIMA_USUARIO',
            '18',
            'Edad mínima requerida para registrar un usuario cliente.'
        );
    END;


    /* ========================================================
       SEGURIDAD DE INICIO DE SESION
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'MAX_INTENTOS_LOGIN'
    )
    BEGIN
        INSERT INTO dbo.ConfiguracionSistema
        (
            Clave,
            Valor,
            Descripcion
        )
        VALUES
        (
            'MAX_INTENTOS_LOGIN',
            '5',
            'Cantidad máxima de intentos fallidos antes de aplicar un bloqueo temporal.'
        );
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'TIEMPO_BLOQUEO_LOGIN_MIN'
    )
    BEGIN
        INSERT INTO dbo.ConfiguracionSistema
        (
            Clave,
            Valor,
            Descripcion
        )
        VALUES
        (
            'TIEMPO_BLOQUEO_LOGIN_MIN',
            '15',
            'Duración en minutos del bloqueo temporal después de exceder los intentos permitidos.'
        );
    END;


    /* ========================================================
       TOKENS DE SEGURIDAD
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'TIEMPO_TOKEN_RECUPERACION_MIN'
    )
    BEGIN
        INSERT INTO dbo.ConfiguracionSistema
        (
            Clave,
            Valor,
            Descripcion
        )
        VALUES
        (
            'TIEMPO_TOKEN_RECUPERACION_MIN',
            '30',
            'Tiempo de vigencia en minutos para un token de recuperación de contraseña.'
        );
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'TIEMPO_TOKEN_VERIFICACION_MIN'
    )
    BEGIN
        INSERT INTO dbo.ConfiguracionSistema
        (
            Clave,
            Valor,
            Descripcion
        )
        VALUES
        (
            'TIEMPO_TOKEN_VERIFICACION_MIN',
            '1440',
            'Tiempo de vigencia en minutos para un token de verificación de correo.'
        );
    END;


    /* ========================================================
       APUESTAS
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'MONTO_MINIMO_APUESTA'
    )
    BEGIN
        INSERT INTO dbo.ConfiguracionSistema
        (
            Clave,
            Valor,
            Descripcion
        )
        VALUES
        (
            'MONTO_MINIMO_APUESTA',
            '1.00',
            'Monto virtual mínimo permitido para registrar una apuesta.'
        );
    END;


    COMMIT TRANSACTION;

    PRINT 'ConfiguracionSistema cargada correctamente.';

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO