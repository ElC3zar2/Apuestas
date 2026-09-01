/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   03_PROCEDIMIENTOS/01_RegistroUsuario.sql

   OBJETIVO:
   Registrar un usuario cliente de forma íntegra y atómica
   contra la estructura definitiva de PlataformaApuestas.

   CREA:
   - Usuario
   - PerfilUsuario
   - VerificacionUsuario
   - Billetera
   - TransaccionFinanciera de CARGA_INICIAL
   - MovimientoBilletera
   - Auditoria del registro

   REGLAS PRINCIPALES:
   - El correo no puede repetirse.
   - El documento no puede repetirse.
   - Se valida la edad mínima configurada.
   - Guatemala requiere municipio y no CiudadExterior.
   - Un país extranjero requiere CiudadExterior y no municipio.
   - La dirección siempre es obligatoria para el cliente.
   - La contraseña se recibe ya protegida con BCrypt desde Java.
   - Todo el registro se confirma o se revierte completo.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


CREATE OR ALTER PROCEDURE dbo.sp_RegistrarUsuarioCliente
(
    @Nombre             VARCHAR(100),
    @Apellido           VARCHAR(100),
    @Correo             VARCHAR(150),
    @Contrasena         VARCHAR(255),
    @FechaNacimiento    DATE,
    @Genero             CHAR(1),
    @Telefono           VARCHAR(25),
    @TipoDocumento      VARCHAR(20),
    @NumeroDocumento    VARCHAR(50),
    @IdPais             INT,
    @IdMunicipio        INT,
    @CiudadExterior     VARCHAR(120),
    @Direccion          VARCHAR(250)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* ========================================================
       1. NORMALIZAR ENTRADAS
       ======================================================== */

    SET @Nombre =
        NULLIF(LTRIM(RTRIM(@Nombre)), '');

    SET @Apellido =
        NULLIF(LTRIM(RTRIM(@Apellido)), '');

    SET @Correo =
        NULLIF(LOWER(LTRIM(RTRIM(@Correo))), '');

    SET @Contrasena =
        NULLIF(LTRIM(RTRIM(@Contrasena)), '');

    SET @Genero =
        UPPER(@Genero);

    SET @Telefono =
        NULLIF(LTRIM(RTRIM(@Telefono)), '');

    SET @TipoDocumento =
        NULLIF(UPPER(LTRIM(RTRIM(@TipoDocumento))), '');

    SET @NumeroDocumento =
        NULLIF(LTRIM(RTRIM(@NumeroDocumento)), '');

    SET @CiudadExterior =
        NULLIF(LTRIM(RTRIM(@CiudadExterior)), '');

    SET @Direccion =
        NULLIF(LTRIM(RTRIM(@Direccion)), '');


    BEGIN TRY

        /* ====================================================
           2. VALIDACIONES GENERALES DE DATOS OBLIGATORIOS
           ==================================================== */

        IF @Nombre IS NULL
            THROW 56001, 'El nombre es obligatorio.', 1;

        IF @Apellido IS NULL
            THROW 56002, 'El apellido es obligatorio.', 1;

        IF @Correo IS NULL
            THROW 56003, 'El correo es obligatorio.', 1;

        IF @Contrasena IS NULL
            THROW 56004, 'La contraseña protegida es obligatoria.', 1;

        IF @FechaNacimiento IS NULL
            THROW 56005, 'La fecha de nacimiento es obligatoria.', 1;

        IF @Genero IS NULL OR @Genero NOT IN ('M', 'F')
            THROW 56006, 'El género debe ser M o F.', 1;

        IF @Telefono IS NULL
            THROW 56007, 'El teléfono es obligatorio.', 1;

        IF @TipoDocumento IS NULL
           OR @TipoDocumento NOT IN ('DPI', 'PASAPORTE', 'OTRO')
            THROW 56008, 'El tipo de documento no es válido.', 1;

        IF @NumeroDocumento IS NULL
            THROW 56009, 'El número de documento es obligatorio.', 1;

        IF @IdPais IS NULL
            THROW 56010, 'El país es obligatorio.', 1;

        IF @Direccion IS NULL
            THROW 56011, 'La dirección es obligatoria.', 1;


        /* ====================================================
           3. OBTENER CONFIGURACION Y CATALOGOS REQUERIDOS
           ==================================================== */

        DECLARE @IdRolUsuario INT;
        DECLARE @IdEstadoUsuarioPendiente INT;
        DECLARE @IdEstadoVerificacionPendiente INT;
        DECLARE @IdEstadoTransaccionCompletada INT;
        DECLARE @IdTipoCargaInicial INT;

        DECLARE @IdGuatemala INT;

        DECLARE @EdadMinima INT;
        DECLARE @EdadUsuario INT;
        DECLARE @FechaActual DATE;

        DECLARE @SaldoInicial DECIMAL(12,2);


        SELECT @IdRolUsuario = IdRol
        FROM dbo.Rol
        WHERE Nombre = 'USUARIO'
          AND Activo = 1;

        IF @IdRolUsuario IS NULL
            THROW 56012, 'No existe el rol USUARIO activo.', 1;


        SELECT @IdEstadoUsuarioPendiente = E.IdEstado
        FROM dbo.Estado AS E
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
        WHERE TE.Codigo = 'USUARIO'
          AND E.Codigo = 'PENDIENTE'
          AND E.Activo = 1;

        IF @IdEstadoUsuarioPendiente IS NULL
            THROW 56013, 'No existe el estado USUARIO/PENDIENTE.', 1;


        SELECT @IdEstadoVerificacionPendiente = E.IdEstado
        FROM dbo.Estado AS E
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
        WHERE TE.Codigo = 'VERIFICACION'
          AND E.Codigo = 'PENDIENTE'
          AND E.Activo = 1;

        IF @IdEstadoVerificacionPendiente IS NULL
            THROW 56014, 'No existe el estado VERIFICACION/PENDIENTE.', 1;


        SELECT @IdEstadoTransaccionCompletada = E.IdEstado
        FROM dbo.Estado AS E
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
        WHERE TE.Codigo = 'TRANSACCION'
          AND E.Codigo = 'COMPLETADA'
          AND E.Activo = 1;

        IF @IdEstadoTransaccionCompletada IS NULL
            THROW 56015, 'No existe el estado TRANSACCION/COMPLETADA.', 1;


        SELECT @IdTipoCargaInicial = IdTipoTransaccion
        FROM dbo.TipoTransaccion
        WHERE Codigo = 'CARGA_INICIAL'
          AND Activo = 1;

        IF @IdTipoCargaInicial IS NULL
            THROW 56016, 'No existe el tipo de transacción CARGA_INICIAL.', 1;


        SELECT @EdadMinima =
            TRY_CONVERT(INT, Valor)
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'EDAD_MINIMA_USUARIO';

        IF @EdadMinima IS NULL OR @EdadMinima < 0
            THROW 56017, 'EDAD_MINIMA_USUARIO no contiene un valor válido.', 1;


        SELECT @SaldoInicial =
            TRY_CONVERT(DECIMAL(12,2), Valor)
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'SALDO_INICIAL_USUARIO';

        IF @SaldoInicial IS NULL OR @SaldoInicial < 0
            THROW 56018, 'SALDO_INICIAL_USUARIO no contiene un valor válido.', 1;


        SELECT @IdGuatemala = IdPais
        FROM dbo.Pais
        WHERE CodigoISO2 = 'GT'
          AND Activo = 1;

        IF @IdGuatemala IS NULL
            THROW 56019, 'Guatemala no se encuentra activa en el catálogo de países.', 1;


        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Pais
            WHERE IdPais = @IdPais
              AND Activo = 1
        )
            THROW 56020, 'El país seleccionado no existe o está inactivo.', 1;


        /* ====================================================
           4. VALIDAR EDAD
           ==================================================== */

        SET @FechaActual = CAST(SYSDATETIME() AS DATE);

        IF @FechaNacimiento > @FechaActual
            THROW 56021, 'La fecha de nacimiento no puede ser futura.', 1;

        SET @EdadUsuario =
            DATEDIFF(YEAR, @FechaNacimiento, @FechaActual)
            -
            CASE
                WHEN DATEADD
                     (
                         YEAR,
                         DATEDIFF(YEAR, @FechaNacimiento, @FechaActual),
                         @FechaNacimiento
                     ) > @FechaActual
                THEN 1
                ELSE 0
            END;

        IF @EdadUsuario < @EdadMinima
            THROW 56022, 'El usuario no cumple con la edad mínima requerida.', 1;


        /* ====================================================
           5. VALIDAR UBICACION

           Guatemala:
           - IdMunicipio obligatorio.
           - CiudadExterior debe ser NULL.
           - El municipio debe pertenecer a Guatemala.

           Extranjero:
           - IdMunicipio debe ser NULL.
           - CiudadExterior obligatoria.
           ==================================================== */

        IF @IdPais = @IdGuatemala
        BEGIN

            IF @IdMunicipio IS NULL
                THROW 56023, 'Para Guatemala debe seleccionar un municipio.', 1;

            IF @CiudadExterior IS NOT NULL
                THROW 56024, 'Para Guatemala no debe registrar CiudadExterior.', 1;

            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.Municipio AS M
                INNER JOIN dbo.Departamento AS D
                    ON D.IdDepartamento = M.IdDepartamento
                WHERE M.IdMunicipio = @IdMunicipio
                  AND M.Activo = 1
                  AND D.Activo = 1
                  AND D.IdPais = @IdGuatemala
            )
                THROW 56025, 'El municipio seleccionado no pertenece a Guatemala o está inactivo.', 1;

        END
        ELSE
        BEGIN

            IF @IdMunicipio IS NOT NULL
                THROW 56026, 'Para un país extranjero no debe seleccionar un municipio de Guatemala.', 1;

            IF @CiudadExterior IS NULL
                THROW 56027, 'Para un país extranjero debe indicar la ciudad o localidad.', 1;

        END;


        /* ====================================================
           6. INICIAR TRANSACCION ATOMICA
           ==================================================== */

        BEGIN TRANSACTION;


        /* ====================================================
           7. EVITAR CORREO DUPLICADO
           HOLDLOCK protege también escenarios concurrentes.
           ==================================================== */

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK)
            WHERE Correo = @Correo
        )
            THROW 56028, 'Ya existe un usuario registrado con ese correo.', 1;


        /* ====================================================
           8. EVITAR DOCUMENTO DUPLICADO

           El índice único filtrado definitivo también reforzará
           esta regla cuando se construya 04_INDICES.
           ==================================================== */

        IF EXISTS
        (
            SELECT 1
            FROM dbo.PerfilUsuario WITH (UPDLOCK, HOLDLOCK)
            WHERE TipoDocumento = @TipoDocumento
              AND NumeroDocumento = @NumeroDocumento
        )
            THROW 56029, 'Ya existe un usuario registrado con ese documento.', 1;


        /* ====================================================
           9. CREAR USUARIO
           ==================================================== */

        DECLARE @IdUsuario INT;
        DECLARE @IdVerificacion INT;
        DECLARE @IdBilletera INT;
        DECLARE @IdTransaccion BIGINT = NULL;

        DECLARE @ReferenciaOperacion UNIQUEIDENTIFIER = NEWID();


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
            @IdRolUsuario,
            @IdEstadoUsuarioPendiente,
            @Correo,
            @Contrasena,
            0,
            0
        );

        SET @IdUsuario = CONVERT(INT, SCOPE_IDENTITY());


        /* ====================================================
           10. CREAR PERFIL PERSONAL
           ==================================================== */

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
            @IdUsuario,
            @Nombre,
            @Apellido,
            @FechaNacimiento,
            @Genero,
            @Telefono,
            @TipoDocumento,
            @NumeroDocumento,
            @IdPais,
            @IdMunicipio,
            @CiudadExterior,
            @Direccion
        );


        /* ====================================================
           11. CREAR VERIFICACION INICIAL
           ==================================================== */

        INSERT INTO dbo.VerificacionUsuario
        (
            IdUsuario,
            IdEstado,
            IdUsuarioRevisor,
            Observacion
        )
        VALUES
        (
            @IdUsuario,
            @IdEstadoVerificacionPendiente,
            NULL,
            'Verificación creada automáticamente durante el registro del usuario.'
        );

        SET @IdVerificacion = CONVERT(INT, SCOPE_IDENTITY());


        /* ====================================================
           12. CREAR BILLETERA EN CERO
           ==================================================== */

        INSERT INTO dbo.Billetera
        (
            IdUsuario,
            SaldoDisponible,
            SaldoComprometido
        )
        VALUES
        (
            @IdUsuario,
            0,
            0
        );

        SET @IdBilletera = CONVERT(INT, SCOPE_IDENTITY());


        /* ====================================================
           13. CARGA INICIAL DE SALDO VIRTUAL

           Si el saldo configurado es 0, la billetera se crea
           normalmente pero no se genera una transacción con
           monto 0 porque TransaccionFinanciera exige Monto > 0.
           ==================================================== */

        IF @SaldoInicial > 0
        BEGIN

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
                @IdBilletera,
                @IdTipoCargaInicial,
                @IdEstadoTransaccionCompletada,
                NULL,
                @ReferenciaOperacion,
                @SaldoInicial,
                SYSDATETIME(),
                NULL,
                'Carga inicial de saldo virtual por registro de usuario.'
            );

            SET @IdTransaccion = CONVERT(BIGINT, SCOPE_IDENTITY());


            UPDATE dbo.Billetera
            SET SaldoDisponible = @SaldoInicial
            WHERE IdBilletera = @IdBilletera;


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
                @IdBilletera,
                @IdTransaccion,
                0,
                @SaldoInicial,
                0,
                0
            );

        END;


        /* ====================================================
           14. AUDITORIA
           ==================================================== */

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            ReferenciaOperacion,
            Descripcion
        )
        VALUES
        (
            @IdUsuario,
            'REGISTRO_USUARIO',
            'Usuario',
            @IdUsuario,
            @ReferenciaOperacion,
            'Registro inicial de usuario cliente.'
        );


        /* ====================================================
           15. CONFIRMAR TRANSACCION
           ==================================================== */

        COMMIT TRANSACTION;


        /* ====================================================
           16. RESPUESTA ESTABLE PARA JAVA
           ==================================================== */

        SELECT
            @IdUsuario AS IdUsuario,
            @IdVerificacion AS IdVerificacion,
            @IdBilletera AS IdBilletera,
            @IdTransaccion AS IdTransaccion,
            @ReferenciaOperacion AS ReferenciaOperacion,
            @SaldoInicial AS SaldoInicial,
            'PENDIENTE' AS EstadoUsuario,
            'PENDIENTE' AS EstadoVerificacion,
            CAST(0 AS BIT) AS CorreoVerificado;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;

END;
GO


PRINT 'Procedimiento dbo.sp_RegistrarUsuarioCliente creado / actualizado correctamente.';
GO