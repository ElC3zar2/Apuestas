/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   02_CONFIGURACION/08_DatosIniciales.sql

   OBJETIVO:
   Cargar los datos iniciales propios de PlataformaApuestas:
   - Deportes iniciales.
   - Cuentas administrativas académicas.
   - Cuenta interna CASA.
   - Billetera y carga inicial de saldo virtual de CASA.

   IMPORTANTE:
   - Requiere haber ejecutado previamente:
       01_ConfiguracionSistema.sql
       02_Roles.sql
       03_Estados.sql
       07_TiposTransaccion.sql
   - No utiliza USE para mantener compatibilidad con Azure SQL.
   - Es re-ejecutable.
   - No reinicia saldos ni duplica la carga inicial de CASA.
   - Las contraseñas se almacenan únicamente como hash BCrypt.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    /* ========================================================
       VALIDAR DEPENDENCIAS
       ======================================================== */

    DECLARE @IdRolAdministrador INT;
    DECLARE @IdRolCasa INT;
    DECLARE @IdEstadoUsuarioActivo INT;
    DECLARE @IdEstadoTransaccionCompletada INT;
    DECLARE @IdTipoCargaInicial INT;
    DECLARE @SaldoInicialCasa DECIMAL(12,2);

    SELECT @IdRolAdministrador = IdRol
    FROM dbo.Rol
    WHERE Nombre = 'ADMINISTRADOR'
      AND Activo = 1;

    SELECT @IdRolCasa = IdRol
    FROM dbo.Rol
    WHERE Nombre = 'CASA'
      AND Activo = 1;

    SELECT @IdEstadoUsuarioActivo = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'USUARIO'
      AND E.Codigo = 'ACTIVO'
      AND E.Activo = 1;

    SELECT @IdEstadoTransaccionCompletada = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'TRANSACCION'
      AND E.Codigo = 'COMPLETADA'
      AND E.Activo = 1;

    SELECT @IdTipoCargaInicial = IdTipoTransaccion
    FROM dbo.TipoTransaccion
    WHERE Codigo = 'CARGA_INICIAL'
      AND Activo = 1;

    SELECT @SaldoInicialCasa =
        TRY_CONVERT(DECIMAL(12,2), Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'SALDO_INICIAL_CASA';

    IF @IdRolAdministrador IS NULL
        THROW 54001, 'No existe el rol ADMINISTRADOR activo.', 1;

    IF @IdRolCasa IS NULL
        THROW 54002, 'No existe el rol CASA activo.', 1;

    IF @IdEstadoUsuarioActivo IS NULL
        THROW 54003, 'No existe el estado USUARIO/ACTIVO.', 1;

    IF @IdEstadoTransaccionCompletada IS NULL
        THROW 54004, 'No existe el estado TRANSACCION/COMPLETADA.', 1;

    IF @IdTipoCargaInicial IS NULL
        THROW 54005, 'No existe el tipo de transaccion CARGA_INICIAL.', 1;

    IF @SaldoInicialCasa IS NULL OR @SaldoInicialCasa < 0
        THROW 54006, 'SALDO_INICIAL_CASA no existe o no contiene un valor valido.', 1;


    /* ========================================================
       DEPORTES INICIALES
       ======================================================== */

    DECLARE @Deportes TABLE
    (
        Nombre VARCHAR(100) NOT NULL,
        Descripcion VARCHAR(250) NULL
    );

    INSERT INTO @Deportes
    (
        Nombre,
        Descripcion
    )
    VALUES
        ('Futbol', 'Deporte colectivo disputado entre dos equipos.'),
        ('Baloncesto', 'Deporte colectivo disputado entre dos equipos con anotación por canastas.'),
        ('Beisbol', 'Deporte colectivo disputado por entradas entre dos equipos.'),
        ('Tenis', 'Deporte que puede disputarse de forma individual o por parejas.');

    INSERT INTO dbo.Deporte
    (
        Nombre,
        Descripcion,
        Activo
    )
    SELECT
        D.Nombre,
        D.Descripcion,
        1
    FROM @Deportes AS D
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.Deporte AS DE
        WHERE DE.Nombre = D.Nombre
    );


    /* ========================================================
       USUARIOS ADMINISTRADORES ACADEMICOS

       Contraseña temporal académica utilizada en desarrollo:
       Admin123!

       Los hashes BCrypt tienen sales diferentes.
       Estas cuentas deberán poder cambiar contraseña posteriormente.
       ======================================================== */

    DECLARE @Administradores TABLE
    (
        Correo VARCHAR(150) NOT NULL,
        Contrasena VARCHAR(255) NOT NULL
    );

    INSERT INTO @Administradores
    (
        Correo,
        Contrasena
    )
    VALUES
        (
            'gabriel@apuestas.local',
            '$2a$12$y9tVQWGEeVH776CzAefsBeWONBLgTevtif6lKl8VcJlEvM2IL3zCK'
        ),
        (
            'wilson@apuestas.local',
            '$2a$12$7JUXcSvSMwKRFVYPji5ECOeDLlssjCEd841qlWTLQiynrcj.gaUqS'
        ),
        (
            'otto@apuestas.local',
            '$2a$12$m2Sc1VDDL7c/9k2Trx8beOSumDCEf8tDLSsUJBoE/4pANitW4qmQ6'
        ),
        (
            'kevin@apuestas.local',
            '$2a$12$FI3nVEOZfC9xPswhn1DYqevd59joP.Jl.fmDJXfMzWtsQhtYjFpsu'
        ),
        (
            'fernando@apuestas.local',
            '$2a$12$zvUsdwaA5ohRKBl13OwjL.jMCZMXFO1cMNLKSiBv.7Dnv3eCWIDX2'
        );

    INSERT INTO dbo.Usuario
    (
        IdRol,
        IdEstado,
        Correo,
        Contrasena,
        CorreoVerificado,
        IntentosFallidos
    )
    SELECT
        @IdRolAdministrador,
        @IdEstadoUsuarioActivo,
        A.Correo,
        A.Contrasena,
        1,
        0
    FROM @Administradores AS A
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario AS U
        WHERE U.Correo = A.Correo
    );

    /* Si alguno de los correos académicos ya existe con otro rol,
       se considera una inconsistencia de instalación. */
    IF EXISTS
    (
        SELECT 1
        FROM @Administradores AS A
        INNER JOIN dbo.Usuario AS U
            ON U.Correo = A.Correo
        WHERE U.IdRol <> @IdRolAdministrador
    )
        THROW 54007, 'Existe una cuenta administrativa inicial asociada a un rol diferente de ADMINISTRADOR.', 1;


    /* ========================================================
       CUENTA CASA
       ======================================================== */

    DECLARE @CorreoCasa VARCHAR(150) = 'casa@apuestas.local';
    DECLARE @IdUsuarioCasa INT;
    DECLARE @IdBilleteraCasa INT;
    DECLARE @BilleteraCasaCreada BIT = 0;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE Correo = @CorreoCasa
    )
    BEGIN
        INSERT INTO dbo.Usuario
        (
            IdRol,
            IdEstado,
            Correo,
            Contrasena,
            CorreoVerificado,
            IntentosFallidos
        )
        VALUES
        (
            @IdRolCasa,
            @IdEstadoUsuarioActivo,
            @CorreoCasa,
            '$2a$12$bLx8w0Q0trmFYKe3V2K7vOnARErmKKiyHhVgfV6of54l71zywS1Ti',
            1,
            0
        );
    END;

    SELECT @IdUsuarioCasa = IdUsuario
    FROM dbo.Usuario
    WHERE Correo = @CorreoCasa;

    IF @IdUsuarioCasa IS NULL
        THROW 54008, 'No fue posible localizar o crear la cuenta CASA.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE IdUsuario = @IdUsuarioCasa
          AND IdRol = @IdRolCasa
    )
        THROW 54009, 'La cuenta casa@apuestas.local existe pero no tiene el rol CASA.', 1;


    /* ========================================================
       BILLETERA CASA
       ======================================================== */

    SELECT @IdBilleteraCasa = IdBilletera
    FROM dbo.Billetera
    WHERE IdUsuario = @IdUsuarioCasa;

    IF @IdBilleteraCasa IS NULL
    BEGIN
        INSERT INTO dbo.Billetera
        (
            IdUsuario,
            SaldoDisponible,
            SaldoComprometido
        )
        VALUES
        (
            @IdUsuarioCasa,
            0,
            0
        );

        SET @IdBilleteraCasa = CONVERT(INT, SCOPE_IDENTITY());
        SET @BilleteraCasaCreada = 1;
    END;


    /* ========================================================
       CARGA INICIAL CASA

       La carga solo se crea cuando la billetera nace.
       Re-ejecutar este archivo NO vuelve a sumar el capital.
       ======================================================== */

    IF @BilleteraCasaCreada = 1 AND @SaldoInicialCasa > 0
    BEGIN
        DECLARE @ReferenciaCasa UNIQUEIDENTIFIER = NEWID();
        DECLARE @IdTransaccionCasa BIGINT;
        DECLARE @SaldoAnterior DECIMAL(12,2);
        DECLARE @SaldoPosterior DECIMAL(12,2);
        DECLARE @ComprometidoAnterior DECIMAL(12,2);

        SELECT
            @SaldoAnterior = SaldoDisponible,
            @ComprometidoAnterior = SaldoComprometido
        FROM dbo.Billetera WITH (UPDLOCK, ROWLOCK)
        WHERE IdBilletera = @IdBilleteraCasa;

        SET @SaldoPosterior = @SaldoAnterior + @SaldoInicialCasa;

        INSERT INTO dbo.TransaccionFinanciera
        (
            IdBilletera,
            IdTipoTransaccion,
            IdEstado,
            IdBoleto,
            ReferenciaOperacion,
            Monto,
            FechaProcesamiento,
            IdUsuarioProceso,
            Descripcion
        )
        VALUES
        (
            @IdBilleteraCasa,
            @IdTipoCargaInicial,
            @IdEstadoTransaccionCompletada,
            NULL,
            @ReferenciaCasa,
            @SaldoInicialCasa,
            SYSDATETIME(),
            NULL,
            'Capital virtual inicial de la cuenta CASA.'
        );

        SET @IdTransaccionCasa = CONVERT(BIGINT, SCOPE_IDENTITY());

        UPDATE dbo.Billetera
        SET SaldoDisponible = @SaldoPosterior
        WHERE IdBilletera = @IdBilleteraCasa;

        INSERT INTO dbo.MovimientoBilletera
        (
            IdBilletera,
            IdTransaccion,
            SaldoDisponibleAnterior,
            SaldoDisponiblePosterior,
            SaldoComprometidoAnterior,
            SaldoComprometidoPosterior
        )
        VALUES
        (
            @IdBilleteraCasa,
            @IdTransaccionCasa,
            @SaldoAnterior,
            @SaldoPosterior,
            @ComprometidoAnterior,
            @ComprometidoAnterior
        );
    END;


    COMMIT TRANSACTION;

    PRINT 'Datos iniciales de PlataformaApuestas cargados correctamente.';

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO