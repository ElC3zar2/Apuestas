/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   03_PROCEDIMIENTOS/08_AdministracionUsuario.sql

   OBJETIVO:
   Centralizar la administración de usuarios cliente, procesos
   de verificación, estados de cuenta y restricciones.

   INCLUYE:
   - Validación de permisos administrativos.
   - Consulta administrativa del usuario.
   - Consulta de verificaciones pendientes.
   - Inicio de revisión.
   - Aprobación / rechazo de verificación.
   - Reapertura del proceso de verificación.
   - Sincronización segura de habilitación del usuario.
   - Cambio administrativo de estado.
   - Creación y levantamiento de restricciones.

   REGLAS PRINCIPALES:
   - Las operaciones de escritura requieren ADMINISTRADOR ACTIVO.
   - AUDITOR solo puede utilizar consultas administrativas.
   - Este módulo administra únicamente cuentas con rol USUARIO.
   - Una cuenta solo puede quedar ACTIVA cuando:
       CorreoVerificado = 1
       y su verificación más reciente = APROBADA.
   - SUSPENDIDO y CERRADO nunca se activan automáticamente.
   - No se puede cerrar una cuenta con saldo comprometido.
   - Las restricciones de apuesta son independientes del login.
   - Todas las operaciones sensibles quedan en Auditoria.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


/* ============================================================
   1. VALIDAR PERMISO DE ADMINISTRACION DE USUARIOS

   SOLO:
   - ADMINISTRADOR ACTIVO
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ValidarPermisoAdministracionUsuario
(
    @IdUsuarioProceso INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @IdUsuarioProceso IS NULL
        THROW 63001, 'IdUsuarioProceso es obligatorio.', 1;

    DECLARE @Rol VARCHAR(50);
    DECLARE @EstadoUsuario VARCHAR(40);

    SELECT
        @Rol = R.Nombre,
        @EstadoUsuario = E.Codigo
    FROM dbo.Usuario AS U
    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'USUARIO'
    WHERE U.IdUsuario = @IdUsuarioProceso;

    IF @Rol IS NULL
        THROW 63002, 'El usuario que procesa la operación no existe.', 1;

    IF @Rol <> 'ADMINISTRADOR'
        THROW 63003, 'Solo un ADMINISTRADOR puede realizar esta operación.', 1;

    IF @EstadoUsuario <> 'ACTIVO'
        THROW 63004, 'El ADMINISTRADOR debe estar ACTIVO.', 1;
END;
GO


/* ============================================================
   2. OBTENER DETALLE ADMINISTRATIVO DE USUARIO

   PERMISOS DE CONSULTA:
   - ADMINISTRADOR
   - AUDITOR

   DEVUELVE TRES RESULT SETS:
   1. Cuenta + perfil + billetera.
   2. Historial de verificaciones.
   3. Historial de restricciones.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerDetalleAdministrativoUsuario
(
    @IdUsuarioSolicitante INT,
    @IdUsuarioObjetivo INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @IdUsuarioSolicitante IS NULL
        THROW 63005, 'IdUsuarioSolicitante es obligatorio.', 1;

    IF @IdUsuarioObjetivo IS NULL
        THROW 63006, 'IdUsuarioObjetivo es obligatorio.', 1;

    DECLARE @RolSolicitante VARCHAR(50);
    DECLARE @EstadoSolicitante VARCHAR(40);

    SELECT
        @RolSolicitante = R.Nombre,
        @EstadoSolicitante = E.Codigo
    FROM dbo.Usuario AS U
    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'USUARIO'
    WHERE U.IdUsuario = @IdUsuarioSolicitante;

    IF @RolSolicitante IS NULL
        THROW 63007, 'El usuario solicitante no existe.', 1;

    IF @RolSolicitante NOT IN ('ADMINISTRADOR', 'AUDITOR')
        THROW 63008, 'El usuario no tiene permisos para consultar información administrativa.', 1;

    IF @EstadoSolicitante <> 'ACTIVO'
        THROW 63009, 'El usuario solicitante debe estar ACTIVO.', 1;


    DECLARE @RolObjetivo VARCHAR(50);

    SELECT @RolObjetivo = R.Nombre
    FROM dbo.Usuario AS U
    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
    WHERE U.IdUsuario = @IdUsuarioObjetivo;

    IF @RolObjetivo IS NULL
        THROW 63010, 'El usuario objetivo no existe.', 1;

    IF @RolObjetivo <> 'USUARIO'
        THROW 63011, 'Este módulo administrativo solo gestiona cuentas con rol USUARIO.', 1;


    /* --------------------------------------------------------
       RESULT SET 1: CUENTA + PERFIL + BILLETERA
       -------------------------------------------------------- */

    SELECT
        U.IdUsuario,
        U.Correo,
        U.CorreoVerificado,
        U.IntentosFallidos,
        U.BloqueadoHasta,
        U.UltimoAcceso,
        U.FechaRegistro,

        R.Nombre AS Rol,
        EU.Codigo AS EstadoUsuario,
        EU.Nombre AS NombreEstadoUsuario,

        P.Nombre,
        P.Apellido,
        P.FechaNacimiento,
        P.Genero,
        P.Telefono,
        P.TipoDocumento,
        P.NumeroDocumento,

        PA.IdPais,
        PA.CodigoISO2,
        PA.Nombre AS Pais,

        D.IdDepartamento,
        D.Nombre AS Departamento,

        M.IdMunicipio,
        M.Nombre AS Municipio,

        P.CiudadExterior,
        P.Direccion,
        P.FechaActualizacion,

        B.IdBilletera,
        B.SaldoDisponible,
        B.SaldoComprometido,
        CAST
        (
            COALESCE(B.SaldoDisponible, 0)
            + COALESCE(B.SaldoComprometido, 0)
            AS DECIMAL(12,2)
        ) AS SaldoVirtualTotal

    FROM dbo.Usuario AS U

    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol

    INNER JOIN dbo.Estado AS EU
        ON EU.IdEstado = U.IdEstado

    INNER JOIN dbo.TipoEstado AS TEU
        ON TEU.IdTipoEstado = EU.IdTipoEstado
       AND TEU.Codigo = 'USUARIO'

    LEFT JOIN dbo.PerfilUsuario AS P
        ON P.IdUsuario = U.IdUsuario

    LEFT JOIN dbo.Pais AS PA
        ON PA.IdPais = P.IdPais

    LEFT JOIN dbo.Municipio AS M
        ON M.IdMunicipio = P.IdMunicipio

    LEFT JOIN dbo.Departamento AS D
        ON D.IdDepartamento = M.IdDepartamento

    LEFT JOIN dbo.Billetera AS B
        ON B.IdUsuario = U.IdUsuario

    WHERE U.IdUsuario = @IdUsuarioObjetivo;


    /* --------------------------------------------------------
       RESULT SET 2: HISTORIAL DE VERIFICACIONES
       -------------------------------------------------------- */

    SELECT
        V.IdVerificacion,
        EV.Codigo AS EstadoVerificacion,
        EV.Nombre AS NombreEstadoVerificacion,

        V.FechaSolicitud,
        V.FechaInicioRevision,
        V.FechaResolucion,

        V.IdUsuarioRevisor,
        UR.Correo AS UsuarioRevisor,

        V.Observacion

    FROM dbo.VerificacionUsuario AS V

    INNER JOIN dbo.Estado AS EV
        ON EV.IdEstado = V.IdEstado

    INNER JOIN dbo.TipoEstado AS TEV
        ON TEV.IdTipoEstado = EV.IdTipoEstado
       AND TEV.Codigo = 'VERIFICACION'

    LEFT JOIN dbo.Usuario AS UR
        ON UR.IdUsuario = V.IdUsuarioRevisor

    WHERE V.IdUsuario = @IdUsuarioObjetivo

    ORDER BY
        V.IdVerificacion DESC;


    /* --------------------------------------------------------
       RESULT SET 3: HISTORIAL DE RESTRICCIONES
       -------------------------------------------------------- */

    SELECT
        RU.IdRestriccion,
        RU.TipoRestriccion,
        RU.Motivo,
        RU.FechaInicio,
        RU.FechaFin,
        RU.Activa,
        RU.FechaRegistro,

        RU.IdUsuarioRegistro,
        UA.Correo AS UsuarioRegistro,

        CAST
        (
            CASE
                WHEN RU.Activa = 1
                 AND RU.FechaInicio <= SYSDATETIME()
                 AND
                 (
                     RU.FechaFin IS NULL
                     OR RU.FechaFin > SYSDATETIME()
                 )
                    THEN 1
                ELSE 0
            END
            AS BIT
        ) AS Vigente

    FROM dbo.RestriccionUsuario AS RU

    INNER JOIN dbo.Usuario AS UA
        ON UA.IdUsuario = RU.IdUsuarioRegistro

    WHERE RU.IdUsuario = @IdUsuarioObjetivo

    ORDER BY
        RU.FechaRegistro DESC,
        RU.IdRestriccion DESC;
END;
GO


/* ============================================================
   3. OBTENER USUARIOS PENDIENTES DE VERIFICACION

   PERMISOS:
   - ADMINISTRADOR
   - AUDITOR

   Devuelve la verificación más reciente de cada usuario
   cuando se encuentra PENDIENTE o EN_REVISION.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerUsuariosPendientesVerificacion
(
    @IdUsuarioSolicitante INT,
    @Cantidad INT = 100
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Cantidad IS NULL OR @Cantidad < 1 OR @Cantidad > 500
        THROW 63012, 'Cantidad debe estar entre 1 y 500.', 1;


    DECLARE @RolSolicitante VARCHAR(50);
    DECLARE @EstadoSolicitante VARCHAR(40);

    SELECT
        @RolSolicitante = R.Nombre,
        @EstadoSolicitante = E.Codigo
    FROM dbo.Usuario AS U
    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'USUARIO'
    WHERE U.IdUsuario = @IdUsuarioSolicitante;

    IF @RolSolicitante IS NULL
        THROW 63013, 'El usuario solicitante no existe.', 1;

    IF @RolSolicitante NOT IN ('ADMINISTRADOR', 'AUDITOR')
        THROW 63014, 'El usuario no tiene permisos para consultar verificaciones.', 1;

    IF @EstadoSolicitante <> 'ACTIVO'
        THROW 63015, 'El usuario solicitante debe estar ACTIVO.', 1;


    SELECT TOP (@Cantidad)
        U.IdUsuario,
        U.Correo,
        U.CorreoVerificado,
        EU.Codigo AS EstadoUsuario,

        P.Nombre,
        P.Apellido,
        P.FechaNacimiento,
        P.TipoDocumento,
        P.NumeroDocumento,

        PA.CodigoISO2,
        PA.Nombre AS Pais,

        D.Nombre AS Departamento,
        M.Nombre AS Municipio,

        P.CiudadExterior,
        P.Direccion,

        V.IdVerificacion,
        EV.Codigo AS EstadoVerificacion,
        V.FechaSolicitud,
        V.FechaInicioRevision,

        V.IdUsuarioRevisor,
        UR.Correo AS UsuarioRevisor

    FROM dbo.Usuario AS U

    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
       AND R.Nombre = 'USUARIO'

    INNER JOIN dbo.Estado AS EU
        ON EU.IdEstado = U.IdEstado

    INNER JOIN dbo.TipoEstado AS TEU
        ON TEU.IdTipoEstado = EU.IdTipoEstado
       AND TEU.Codigo = 'USUARIO'

    INNER JOIN dbo.PerfilUsuario AS P
        ON P.IdUsuario = U.IdUsuario

    INNER JOIN dbo.Pais AS PA
        ON PA.IdPais = P.IdPais

    LEFT JOIN dbo.Municipio AS M
        ON M.IdMunicipio = P.IdMunicipio

    LEFT JOIN dbo.Departamento AS D
        ON D.IdDepartamento = M.IdDepartamento

    INNER JOIN dbo.VerificacionUsuario AS V
        ON V.IdUsuario = U.IdUsuario
       AND V.IdVerificacion =
       (
           SELECT MAX(V2.IdVerificacion)
           FROM dbo.VerificacionUsuario AS V2
           WHERE V2.IdUsuario = U.IdUsuario
       )

    INNER JOIN dbo.Estado AS EV
        ON EV.IdEstado = V.IdEstado

    INNER JOIN dbo.TipoEstado AS TEV
        ON TEV.IdTipoEstado = EV.IdTipoEstado
       AND TEV.Codigo = 'VERIFICACION'

    LEFT JOIN dbo.Usuario AS UR
        ON UR.IdUsuario = V.IdUsuarioRevisor

    WHERE EV.Codigo IN ('PENDIENTE', 'EN_REVISION')

    ORDER BY
        V.FechaSolicitud,
        V.IdVerificacion;
END;
GO


/* ============================================================
   4. SINCRONIZAR HABILITACION DEL USUARIO

   PROCEDIMIENTO AUXILIAR SEGURO.

   ACTIVA exclusivamente cuando:
   - Rol = USUARIO.
   - Estado actual = PENDIENTE.
   - CorreoVerificado = 1.
   - Verificación más reciente = APROBADA.

   NO modifica:
   - SUSPENDIDO
   - CERRADO

   USO:
   Puede ejecutarse después de verificar correo o después de
   aprobar administrativamente la verificación.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_SincronizarHabilitacionUsuario
(
    @IdUsuario INT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @IdUsuario IS NULL
        THROW 63016, 'IdUsuario es obligatorio.', 1;


    DECLARE @IdEstadoActivo INT;

    SELECT @IdEstadoActivo = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'USUARIO'
      AND E.Codigo = 'ACTIVO'
      AND E.Activo = 1;

    IF @IdEstadoActivo IS NULL
        THROW 63017, 'No existe el estado USUARIO/ACTIVO.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;


        DECLARE @Rol VARCHAR(50);
        DECLARE @EstadoActual VARCHAR(40);
        DECLARE @CorreoVerificado BIT;


        SELECT
            @Rol = R.Nombre,
            @EstadoActual = E.Codigo,
            @CorreoVerificado = U.CorreoVerificado

        FROM dbo.Usuario AS U WITH (UPDLOCK, HOLDLOCK)

        INNER JOIN dbo.Rol AS R
            ON R.IdRol = U.IdRol

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado

        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'USUARIO'

        WHERE U.IdUsuario = @IdUsuario;


        IF @Rol IS NULL
            THROW 63018, 'El usuario indicado no existe.', 1;

        IF @Rol <> 'USUARIO'
            THROW 63019, 'La sincronización automática solo aplica a cuentas con rol USUARIO.', 1;


        DECLARE @EstadoVerificacion VARCHAR(40);


        SELECT TOP (1)
            @EstadoVerificacion = E.Codigo

        FROM dbo.VerificacionUsuario AS V

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = V.IdEstado

        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'VERIFICACION'

        WHERE V.IdUsuario = @IdUsuario

        ORDER BY V.IdVerificacion DESC;


        DECLARE @Activado BIT = 0;


        IF @EstadoActual = 'PENDIENTE'
           AND @CorreoVerificado = 1
           AND @EstadoVerificacion = 'APROBADA'
        BEGIN

            UPDATE dbo.Usuario
            SET IdEstado = @IdEstadoActivo
            WHERE IdUsuario = @IdUsuario;

            SET @EstadoActual = 'ACTIVO';
            SET @Activado = 1;

        END;


        COMMIT TRANSACTION;


        SELECT
            @IdUsuario AS IdUsuario,
            @CorreoVerificado AS CorreoVerificado,
            @EstadoVerificacion AS EstadoVerificacion,
            @EstadoActual AS EstadoUsuario,
            @Activado AS Activado;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   5. INICIAR REVISION DE USUARIO

   PENDIENTE -> EN_REVISION
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_IniciarRevisionUsuario
(
    @IdUsuarioProceso INT,
    @IdVerificacion INT,
    @Observacion VARCHAR(500) = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Observacion =
        NULLIF(LTRIM(RTRIM(@Observacion)), '');

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');


    IF @IdVerificacion IS NULL
        THROW 63020, 'IdVerificacion es obligatorio.', 1;


    EXEC dbo.sp_ValidarPermisoAdministracionUsuario
        @IdUsuarioProceso = @IdUsuarioProceso;


    DECLARE @IdEstadoEnRevision INT;

    SELECT @IdEstadoEnRevision = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'VERIFICACION'
      AND E.Codigo = 'EN_REVISION'
      AND E.Activo = 1;

    IF @IdEstadoEnRevision IS NULL
        THROW 63021, 'No existe el estado VERIFICACION/EN_REVISION.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;


        DECLARE @IdUsuario INT;
        DECLARE @EstadoActual VARCHAR(40);


        SELECT
            @IdUsuario = V.IdUsuario,
            @EstadoActual = E.Codigo

        FROM dbo.VerificacionUsuario AS V WITH (UPDLOCK, HOLDLOCK)

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = V.IdEstado

        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'VERIFICACION'

        WHERE V.IdVerificacion = @IdVerificacion;


        IF @IdUsuario IS NULL
            THROW 63022, 'La verificación indicada no existe.', 1;


        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Usuario AS U
            INNER JOIN dbo.Rol AS R
                ON R.IdRol = U.IdRol
            WHERE U.IdUsuario = @IdUsuario
              AND R.Nombre = 'USUARIO'
        )
            THROW 63023, 'La verificación no pertenece a una cuenta cliente.', 1;


        IF @EstadoActual = 'EN_REVISION'
        BEGIN
            COMMIT TRANSACTION;

            SELECT
                @IdVerificacion AS IdVerificacion,
                @IdUsuario AS IdUsuario,
                'EN_REVISION' AS EstadoVerificacion,
                CAST(1 AS BIT) AS SinCambios;

            RETURN;
        END;


        IF @EstadoActual <> 'PENDIENTE'
            THROW 63024, 'Solo una verificación PENDIENTE puede iniciar revisión.', 1;


        UPDATE dbo.VerificacionUsuario
        SET
            IdEstado = @IdEstadoEnRevision,
            IdUsuarioRevisor = @IdUsuarioProceso,
            FechaInicioRevision = SYSDATETIME(),
            Observacion =
                CASE
                    WHEN @Observacion IS NULL
                        THEN Observacion
                    ELSE @Observacion
                END
        WHERE IdVerificacion = @IdVerificacion;


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
            @IdUsuarioProceso,
            'VERIFICACION_INICIADA',
            'VerificacionUsuario',
            @IdVerificacion,
            @IpOrigen,
            CONCAT('Se inició la revisión del usuario ', @IdUsuario, '.')
        );


        COMMIT TRANSACTION;


        SELECT
            @IdVerificacion AS IdVerificacion,
            @IdUsuario AS IdUsuario,
            'EN_REVISION' AS EstadoVerificacion,
            CAST(0 AS BIT) AS SinCambios;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   6. APROBAR VERIFICACION DE USUARIO

   PENDIENTE / EN_REVISION -> APROBADA

   Después intenta habilitar automáticamente al usuario.
   Solo quedará ACTIVO si su correo ya está verificado.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_AprobarVerificacionUsuario
(
    @IdUsuarioProceso INT,
    @IdVerificacion INT,
    @Observacion VARCHAR(500) = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Observacion =
        NULLIF(LTRIM(RTRIM(@Observacion)), '');

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');


    IF @IdVerificacion IS NULL
        THROW 63025, 'IdVerificacion es obligatorio.', 1;


    EXEC dbo.sp_ValidarPermisoAdministracionUsuario
        @IdUsuarioProceso = @IdUsuarioProceso;


    DECLARE @IdEstadoAprobada INT;
    DECLARE @IdEstadoUsuarioActivo INT;


    SELECT @IdEstadoAprobada = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'VERIFICACION'
      AND E.Codigo = 'APROBADA'
      AND E.Activo = 1;


    SELECT @IdEstadoUsuarioActivo = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'USUARIO'
      AND E.Codigo = 'ACTIVO'
      AND E.Activo = 1;


    IF @IdEstadoAprobada IS NULL
        THROW 63026, 'No existe el estado VERIFICACION/APROBADA.', 1;

    IF @IdEstadoUsuarioActivo IS NULL
        THROW 63027, 'No existe el estado USUARIO/ACTIVO.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;


        DECLARE @IdUsuario INT;
        DECLARE @EstadoActual VARCHAR(40);
        DECLARE @CorreoVerificado BIT;
        DECLARE @EstadoCuenta VARCHAR(40);


        SELECT
            @IdUsuario = V.IdUsuario,
            @EstadoActual = EV.Codigo,
            @CorreoVerificado = U.CorreoVerificado,
            @EstadoCuenta = EU.Codigo

        FROM dbo.VerificacionUsuario AS V WITH (UPDLOCK, HOLDLOCK)

        INNER JOIN dbo.Estado AS EV
            ON EV.IdEstado = V.IdEstado

        INNER JOIN dbo.TipoEstado AS TEV
            ON TEV.IdTipoEstado = EV.IdTipoEstado
           AND TEV.Codigo = 'VERIFICACION'

        INNER JOIN dbo.Usuario AS U WITH (UPDLOCK, HOLDLOCK)
            ON U.IdUsuario = V.IdUsuario

        INNER JOIN dbo.Rol AS R
            ON R.IdRol = U.IdRol
           AND R.Nombre = 'USUARIO'

        INNER JOIN dbo.Estado AS EU
            ON EU.IdEstado = U.IdEstado

        INNER JOIN dbo.TipoEstado AS TEU
            ON TEU.IdTipoEstado = EU.IdTipoEstado
           AND TEU.Codigo = 'USUARIO'

        WHERE V.IdVerificacion = @IdVerificacion;


        IF @IdUsuario IS NULL
            THROW 63028, 'La verificación no existe o no pertenece a una cuenta cliente.', 1;


        IF @EstadoActual = 'APROBADA'
        BEGIN
            COMMIT TRANSACTION;

            SELECT
                @IdVerificacion AS IdVerificacion,
                @IdUsuario AS IdUsuario,
                'APROBADA' AS EstadoVerificacion,
                @EstadoCuenta AS EstadoUsuario,
                @CorreoVerificado AS CorreoVerificado,
                CAST(1 AS BIT) AS SinCambios;

            RETURN;
        END;


        IF @EstadoActual NOT IN ('PENDIENTE', 'EN_REVISION')
            THROW 63029, 'La verificación no puede aprobarse en su estado actual.', 1;


        UPDATE dbo.VerificacionUsuario
        SET
            IdEstado = @IdEstadoAprobada,
            IdUsuarioRevisor = @IdUsuarioProceso,
            FechaInicioRevision = COALESCE(FechaInicioRevision, SYSDATETIME()),
            FechaResolucion = SYSDATETIME(),
            Observacion =
                CASE
                    WHEN @Observacion IS NULL
                        THEN Observacion
                    ELSE @Observacion
                END
        WHERE IdVerificacion = @IdVerificacion;


        /* Solo activar automáticamente desde PENDIENTE.
           SUSPENDIDO/CERRADO requieren decisión administrativa. */
        IF @EstadoCuenta = 'PENDIENTE'
           AND @CorreoVerificado = 1
        BEGIN

            UPDATE dbo.Usuario
            SET IdEstado = @IdEstadoUsuarioActivo
            WHERE IdUsuario = @IdUsuario;

            SET @EstadoCuenta = 'ACTIVO';

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
            @IdUsuarioProceso,
            'VERIFICACION_APROBADA',
            'VerificacionUsuario',
            @IdVerificacion,
            @IpOrigen,
            CONCAT
            (
                'Verificación aprobada para usuario ',
                @IdUsuario,
                '. Estado de cuenta resultante=',
                @EstadoCuenta,
                '.'
            )
        );


        COMMIT TRANSACTION;


        SELECT
            @IdVerificacion AS IdVerificacion,
            @IdUsuario AS IdUsuario,
            'APROBADA' AS EstadoVerificacion,
            @EstadoCuenta AS EstadoUsuario,
            @CorreoVerificado AS CorreoVerificado,
            CAST(0 AS BIT) AS SinCambios;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   7. RECHAZAR VERIFICACION DE USUARIO

   PENDIENTE / EN_REVISION -> RECHAZADA

   La cuenta permanece PENDIENTE.
   El motivo es obligatorio.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_RechazarVerificacionUsuario
(
    @IdUsuarioProceso INT,
    @IdVerificacion INT,
    @Motivo VARCHAR(500),
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Motivo =
        NULLIF(LTRIM(RTRIM(@Motivo)), '');

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');


    IF @IdVerificacion IS NULL
        THROW 63030, 'IdVerificacion es obligatorio.', 1;

    IF @Motivo IS NULL
        THROW 63031, 'El motivo del rechazo es obligatorio.', 1;


    EXEC dbo.sp_ValidarPermisoAdministracionUsuario
        @IdUsuarioProceso = @IdUsuarioProceso;


    DECLARE @IdEstadoRechazada INT;
    DECLARE @IdEstadoUsuarioPendiente INT;


    SELECT @IdEstadoRechazada = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'VERIFICACION'
      AND E.Codigo = 'RECHAZADA'
      AND E.Activo = 1;


    SELECT @IdEstadoUsuarioPendiente = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'USUARIO'
      AND E.Codigo = 'PENDIENTE'
      AND E.Activo = 1;


    IF @IdEstadoRechazada IS NULL
        THROW 63032, 'No existe el estado VERIFICACION/RECHAZADA.', 1;

    IF @IdEstadoUsuarioPendiente IS NULL
        THROW 63033, 'No existe el estado USUARIO/PENDIENTE.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;


        DECLARE @IdUsuario INT;
        DECLARE @EstadoActual VARCHAR(40);
        DECLARE @EstadoCuenta VARCHAR(40);


        SELECT
            @IdUsuario = V.IdUsuario,
            @EstadoActual = EV.Codigo,
            @EstadoCuenta = EU.Codigo

        FROM dbo.VerificacionUsuario AS V WITH (UPDLOCK, HOLDLOCK)

        INNER JOIN dbo.Estado AS EV
            ON EV.IdEstado = V.IdEstado

        INNER JOIN dbo.TipoEstado AS TEV
            ON TEV.IdTipoEstado = EV.IdTipoEstado
           AND TEV.Codigo = 'VERIFICACION'

        INNER JOIN dbo.Usuario AS U WITH (UPDLOCK, HOLDLOCK)
            ON U.IdUsuario = V.IdUsuario

        INNER JOIN dbo.Rol AS R
            ON R.IdRol = U.IdRol
           AND R.Nombre = 'USUARIO'

        INNER JOIN dbo.Estado AS EU
            ON EU.IdEstado = U.IdEstado

        INNER JOIN dbo.TipoEstado AS TEU
            ON TEU.IdTipoEstado = EU.IdTipoEstado
           AND TEU.Codigo = 'USUARIO'

        WHERE V.IdVerificacion = @IdVerificacion;


        IF @IdUsuario IS NULL
            THROW 63034, 'La verificación no existe o no pertenece a una cuenta cliente.', 1;


        IF @EstadoActual = 'RECHAZADA'
        BEGIN
            COMMIT TRANSACTION;

            SELECT
                @IdVerificacion AS IdVerificacion,
                @IdUsuario AS IdUsuario,
                'RECHAZADA' AS EstadoVerificacion,
                @EstadoCuenta AS EstadoUsuario,
                CAST(1 AS BIT) AS SinCambios;

            RETURN;
        END;


        IF @EstadoActual NOT IN ('PENDIENTE', 'EN_REVISION')
            THROW 63035, 'La verificación no puede rechazarse en su estado actual.', 1;


        UPDATE dbo.VerificacionUsuario
        SET
            IdEstado = @IdEstadoRechazada,
            IdUsuarioRevisor = @IdUsuarioProceso,
            FechaInicioRevision = COALESCE(FechaInicioRevision, SYSDATETIME()),
            FechaResolucion = SYSDATETIME(),
            Observacion = @Motivo
        WHERE IdVerificacion = @IdVerificacion;


        /* Si accidentalmente estuviera ACTIVO antes del rechazo,
           regresar a PENDIENTE. No se alteran SUSPENDIDO/CERRADO. */
        IF @EstadoCuenta = 'ACTIVO'
        BEGIN
            UPDATE dbo.Usuario
            SET IdEstado = @IdEstadoUsuarioPendiente
            WHERE IdUsuario = @IdUsuario;

            SET @EstadoCuenta = 'PENDIENTE';
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
            @IdUsuarioProceso,
            'VERIFICACION_RECHAZADA',
            'VerificacionUsuario',
            @IdVerificacion,
            @IpOrigen,
            CONCAT
            (
                'Verificación rechazada para usuario ',
                @IdUsuario,
                '. Motivo: ',
                @Motivo,
                '.'
            )
        );


        COMMIT TRANSACTION;


        SELECT
            @IdVerificacion AS IdVerificacion,
            @IdUsuario AS IdUsuario,
            'RECHAZADA' AS EstadoVerificacion,
            @EstadoCuenta AS EstadoUsuario,
            CAST(0 AS BIT) AS SinCambios;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   8. REABRIR VERIFICACION DE USUARIO

   Crea una NUEVA VerificacionUsuario/PENDIENTE.

   Reglas:
   - La verificación más reciente debe estar RECHAZADA.
   - No altera el historial anterior.
   - La cuenta debe ser PENDIENTE o SUSPENDIDO.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ReabrirVerificacionUsuario
(
    @IdUsuarioProceso INT,
    @IdUsuario INT,
    @Observacion VARCHAR(500) = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Observacion =
        NULLIF(LTRIM(RTRIM(@Observacion)), '');

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');


    IF @IdUsuario IS NULL
        THROW 63036, 'IdUsuario es obligatorio.', 1;


    EXEC dbo.sp_ValidarPermisoAdministracionUsuario
        @IdUsuarioProceso = @IdUsuarioProceso;


    DECLARE @IdEstadoVerificacionPendiente INT;

    SELECT @IdEstadoVerificacionPendiente = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'VERIFICACION'
      AND E.Codigo = 'PENDIENTE'
      AND E.Activo = 1;


    IF @IdEstadoVerificacionPendiente IS NULL
        THROW 63037, 'No existe el estado VERIFICACION/PENDIENTE.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;


        DECLARE @EstadoCuenta VARCHAR(40);
        DECLARE @Rol VARCHAR(50);


        SELECT
            @Rol = R.Nombre,
            @EstadoCuenta = E.Codigo

        FROM dbo.Usuario AS U WITH (UPDLOCK, HOLDLOCK)

        INNER JOIN dbo.Rol AS R
            ON R.IdRol = U.IdRol

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado

        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'USUARIO'

        WHERE U.IdUsuario = @IdUsuario;


        IF @Rol IS NULL
            THROW 63038, 'El usuario indicado no existe.', 1;

        IF @Rol <> 'USUARIO'
            THROW 63039, 'Solo se puede reabrir la verificación de una cuenta cliente.', 1;

        IF @EstadoCuenta NOT IN ('PENDIENTE', 'SUSPENDIDO')
            THROW 63040, 'La cuenta debe estar PENDIENTE o SUSPENDIDA para reabrir su verificación.', 1;


        DECLARE @UltimoEstadoVerificacion VARCHAR(40);


        SELECT TOP (1)
            @UltimoEstadoVerificacion = E.Codigo

        FROM dbo.VerificacionUsuario AS V

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = V.IdEstado

        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'VERIFICACION'

        WHERE V.IdUsuario = @IdUsuario

        ORDER BY V.IdVerificacion DESC;


        IF @UltimoEstadoVerificacion <> 'RECHAZADA'
            THROW 63041, 'La verificación más reciente debe estar RECHAZADA para iniciar una nueva solicitud.', 1;


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
            COALESCE
            (
                @Observacion,
                'Nueva solicitud de verificación creada después de un rechazo previo.'
            )
        );


        DECLARE @IdVerificacion INT =
            CONVERT(INT, SCOPE_IDENTITY());


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
            @IdUsuarioProceso,
            'VERIFICACION_REABIERTA',
            'VerificacionUsuario',
            @IdVerificacion,
            @IpOrigen,
            CONCAT
            (
                'Nueva verificación creada para usuario ',
                @IdUsuario,
                '.'
            )
        );


        COMMIT TRANSACTION;


        SELECT
            @IdVerificacion AS IdVerificacion,
            @IdUsuario AS IdUsuario,
            'PENDIENTE' AS EstadoVerificacion;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   9. CAMBIAR ESTADO ADMINISTRATIVO DE USUARIO

   NUEVOS ESTADOS PERMITIDOS:
   - PENDIENTE
   - ACTIVO
   - SUSPENDIDO
   - CERRADO

   REGLAS:
   - Solo cuentas con rol USUARIO.
   - ACTIVO requiere correo verificado + última verificación
     APROBADA.
   - CERRADO requiere SaldoComprometido = 0.
   - Motivo obligatorio para SUSPENDIDO y CERRADO.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CambiarEstadoUsuarioAdministrativo
(
    @IdUsuarioProceso INT,
    @IdUsuarioObjetivo INT,
    @NuevoEstado VARCHAR(40),
    @Motivo VARCHAR(500) = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NuevoEstado =
        NULLIF(UPPER(LTRIM(RTRIM(@NuevoEstado))), '');

    SET @Motivo =
        NULLIF(LTRIM(RTRIM(@Motivo)), '');

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');


    IF @IdUsuarioObjetivo IS NULL
        THROW 63042, 'IdUsuarioObjetivo es obligatorio.', 1;

    IF @NuevoEstado IS NULL
       OR @NuevoEstado NOT IN
          ('PENDIENTE', 'ACTIVO', 'SUSPENDIDO', 'CERRADO')
        THROW 63043, 'NuevoEstado no es válido.', 1;

    IF @NuevoEstado IN ('SUSPENDIDO', 'CERRADO')
       AND @Motivo IS NULL
        THROW 63044, 'El motivo es obligatorio para suspender o cerrar una cuenta.', 1;


    EXEC dbo.sp_ValidarPermisoAdministracionUsuario
        @IdUsuarioProceso = @IdUsuarioProceso;


    DECLARE @IdNuevoEstado INT;

    SELECT @IdNuevoEstado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'USUARIO'
      AND E.Codigo = @NuevoEstado
      AND E.Activo = 1;


    IF @IdNuevoEstado IS NULL
        THROW 63045, 'El estado solicitado no existe o está inactivo.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;


        DECLARE @RolObjetivo VARCHAR(50);
        DECLARE @EstadoActual VARCHAR(40);
        DECLARE @CorreoVerificado BIT;


        SELECT
            @RolObjetivo = R.Nombre,
            @EstadoActual = E.Codigo,
            @CorreoVerificado = U.CorreoVerificado

        FROM dbo.Usuario AS U WITH (UPDLOCK, HOLDLOCK)

        INNER JOIN dbo.Rol AS R
            ON R.IdRol = U.IdRol

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado

        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'USUARIO'

        WHERE U.IdUsuario = @IdUsuarioObjetivo;


        IF @RolObjetivo IS NULL
            THROW 63046, 'El usuario objetivo no existe.', 1;

        IF @RolObjetivo <> 'USUARIO'
            THROW 63047, 'Este procedimiento solo administra cuentas con rol USUARIO.', 1;


        IF @EstadoActual = @NuevoEstado
        BEGIN
            COMMIT TRANSACTION;

            SELECT
                @IdUsuarioObjetivo AS IdUsuario,
                @EstadoActual AS EstadoAnterior,
                @NuevoEstado AS EstadoActual,
                CAST(1 AS BIT) AS SinCambios;

            RETURN;
        END;


        IF @EstadoActual = 'CERRADO'
            THROW 63048, 'Una cuenta CERRADA no puede cambiar de estado mediante este procedimiento.', 1;


        IF @NuevoEstado = 'ACTIVO'
        BEGIN

            DECLARE @EstadoVerificacion VARCHAR(40);


            SELECT TOP (1)
                @EstadoVerificacion = E.Codigo

            FROM dbo.VerificacionUsuario AS V

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = V.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
               AND TE.Codigo = 'VERIFICACION'

            WHERE V.IdUsuario = @IdUsuarioObjetivo

            ORDER BY V.IdVerificacion DESC;


            IF @CorreoVerificado <> 1
                THROW 63049, 'No se puede activar la cuenta porque el correo no está verificado.', 1;

            IF @EstadoVerificacion <> 'APROBADA'
                THROW 63050, 'No se puede activar la cuenta porque su verificación más reciente no está APROBADA.', 1;

        END;


        IF @NuevoEstado = 'CERRADO'
        BEGIN

            DECLARE @SaldoComprometido DECIMAL(12,2);


            SELECT @SaldoComprometido = SaldoComprometido
            FROM dbo.Billetera WITH (UPDLOCK, HOLDLOCK)
            WHERE IdUsuario = @IdUsuarioObjetivo;


            IF @SaldoComprometido IS NOT NULL
               AND @SaldoComprometido > 0
                THROW 63051, 'No se puede cerrar una cuenta que mantiene saldo comprometido en apuestas.', 1;

        END;


        UPDATE dbo.Usuario
        SET IdEstado = @IdNuevoEstado
        WHERE IdUsuario = @IdUsuarioObjetivo;


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
            @IdUsuarioProceso,
            'ESTADO_USUARIO_CAMBIADO',
            'Usuario',
            @IdUsuarioObjetivo,
            @IpOrigen,
            CONCAT
            (
                'Estado ',
                @EstadoActual,
                ' -> ',
                @NuevoEstado,
                CASE
                    WHEN @Motivo IS NULL THEN ''
                    ELSE CONCAT('. Motivo: ', @Motivo)
                END
            )
        );


        COMMIT TRANSACTION;


        SELECT
            @IdUsuarioObjetivo AS IdUsuario,
            @EstadoActual AS EstadoAnterior,
            @NuevoEstado AS EstadoActual,
            CAST(0 AS BIT) AS SinCambios;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   10. AGREGAR RESTRICCION DE USUARIO

   TIPOS:
   - APOSTAR
   - TODAS_OPERACIONES

   La restricción no impide el login por sí misma.
   sp_RealizarApuesta consulta estas restricciones antes de
   registrar un boleto.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_AgregarRestriccionUsuario
(
    @IdUsuarioProceso INT,
    @IdUsuarioObjetivo INT,
    @TipoRestriccion VARCHAR(30),
    @Motivo VARCHAR(500),
    @FechaFin DATETIME2 = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @TipoRestriccion =
        NULLIF(UPPER(LTRIM(RTRIM(@TipoRestriccion))), '');

    SET @Motivo =
        NULLIF(LTRIM(RTRIM(@Motivo)), '');

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');


    IF @IdUsuarioObjetivo IS NULL
        THROW 63052, 'IdUsuarioObjetivo es obligatorio.', 1;

    IF @TipoRestriccion IS NULL
       OR @TipoRestriccion NOT IN ('APOSTAR', 'TODAS_OPERACIONES')
        THROW 63053, 'TipoRestriccion debe ser APOSTAR o TODAS_OPERACIONES.', 1;

    IF @Motivo IS NULL
        THROW 63054, 'El motivo de la restricción es obligatorio.', 1;

    IF @FechaFin IS NOT NULL
       AND @FechaFin <= SYSDATETIME()
        THROW 63055, 'FechaFin debe ser futura.', 1;


    EXEC dbo.sp_ValidarPermisoAdministracionUsuario
        @IdUsuarioProceso = @IdUsuarioProceso;


    BEGIN TRY
        BEGIN TRANSACTION;


        DECLARE @RolObjetivo VARCHAR(50);
        DECLARE @EstadoObjetivo VARCHAR(40);


        SELECT
            @RolObjetivo = R.Nombre,
            @EstadoObjetivo = E.Codigo

        FROM dbo.Usuario AS U WITH (UPDLOCK, HOLDLOCK)

        INNER JOIN dbo.Rol AS R
            ON R.IdRol = U.IdRol

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado

        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'USUARIO'

        WHERE U.IdUsuario = @IdUsuarioObjetivo;


        IF @RolObjetivo IS NULL
            THROW 63056, 'El usuario objetivo no existe.', 1;

        IF @RolObjetivo <> 'USUARIO'
            THROW 63057, 'Solo se pueden aplicar restricciones a cuentas con rol USUARIO.', 1;

        IF @EstadoObjetivo = 'CERRADO'
            THROW 63058, 'No se puede agregar una restricción a una cuenta cerrada.', 1;


        IF EXISTS
        (
            SELECT 1
            FROM dbo.RestriccionUsuario WITH (UPDLOCK, HOLDLOCK)
            WHERE IdUsuario = @IdUsuarioObjetivo
              AND TipoRestriccion = @TipoRestriccion
              AND Activa = 1
              AND FechaInicio <= SYSDATETIME()
              AND
              (
                  FechaFin IS NULL
                  OR FechaFin > SYSDATETIME()
              )
        )
            THROW 63059, 'El usuario ya posee una restricción vigente del mismo tipo.', 1;


        INSERT INTO dbo.RestriccionUsuario
        (
            IdUsuario,
            IdUsuarioRegistro,
            TipoRestriccion,
            Motivo,
            FechaInicio,
            FechaFin,
            Activa
        )
        VALUES
        (
            @IdUsuarioObjetivo,
            @IdUsuarioProceso,
            @TipoRestriccion,
            @Motivo,
            SYSDATETIME(),
            @FechaFin,
            1
        );


        DECLARE @IdRestriccion INT =
            CONVERT(INT, SCOPE_IDENTITY());


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
            @IdUsuarioProceso,
            'RESTRICCION_USUARIO_AGREGADA',
            'RestriccionUsuario',
            @IdRestriccion,
            @IpOrigen,
            CONCAT
            (
                'Restricción ',
                @TipoRestriccion,
                ' aplicada al usuario ',
                @IdUsuarioObjetivo,
                '. Motivo: ',
                @Motivo,
                '.'
            )
        );


        COMMIT TRANSACTION;


        SELECT
            @IdRestriccion AS IdRestriccion,
            @IdUsuarioObjetivo AS IdUsuario,
            @TipoRestriccion AS TipoRestriccion,
            @Motivo AS Motivo,
            @FechaFin AS FechaFin,
            CAST(1 AS BIT) AS Activa;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   11. LEVANTAR RESTRICCION DE USUARIO

   - Activa = 0
   - FechaFin = momento del levantamiento
   - El motivo administrativo se conserva en Auditoria.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_LevantarRestriccionUsuario
(
    @IdUsuarioProceso INT,
    @IdRestriccion INT,
    @MotivoLevantamiento VARCHAR(500),
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @MotivoLevantamiento =
        NULLIF(LTRIM(RTRIM(@MotivoLevantamiento)), '');

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');


    IF @IdRestriccion IS NULL
        THROW 63060, 'IdRestriccion es obligatorio.', 1;

    IF @MotivoLevantamiento IS NULL
        THROW 63061, 'El motivo del levantamiento es obligatorio.', 1;


    EXEC dbo.sp_ValidarPermisoAdministracionUsuario
        @IdUsuarioProceso = @IdUsuarioProceso;


    BEGIN TRY
        BEGIN TRANSACTION;


        DECLARE @IdUsuarioObjetivo INT;
        DECLARE @TipoRestriccion VARCHAR(30);
        DECLARE @Activa BIT;


        SELECT
            @IdUsuarioObjetivo = IdUsuario,
            @TipoRestriccion = TipoRestriccion,
            @Activa = Activa

        FROM dbo.RestriccionUsuario WITH (UPDLOCK, HOLDLOCK)

        WHERE IdRestriccion = @IdRestriccion;


        IF @IdUsuarioObjetivo IS NULL
            THROW 63062, 'La restricción indicada no existe.', 1;


        IF @Activa = 0
        BEGIN
            COMMIT TRANSACTION;

            SELECT
                @IdRestriccion AS IdRestriccion,
                @IdUsuarioObjetivo AS IdUsuario,
                @TipoRestriccion AS TipoRestriccion,
                CAST(0 AS BIT) AS Activa,
                CAST(1 AS BIT) AS SinCambios;

            RETURN;
        END;


        UPDATE dbo.RestriccionUsuario
        SET
            Activa = 0,
            FechaFin = SYSDATETIME()
        WHERE IdRestriccion = @IdRestriccion;


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
            @IdUsuarioProceso,
            'RESTRICCION_USUARIO_LEVANTADA',
            'RestriccionUsuario',
            @IdRestriccion,
            @IpOrigen,
            CONCAT
            (
                'Restricción ',
                @TipoRestriccion,
                ' levantada para usuario ',
                @IdUsuarioObjetivo,
                '. Motivo: ',
                @MotivoLevantamiento,
                '.'
            )
        );


        COMMIT TRANSACTION;


        SELECT
            @IdRestriccion AS IdRestriccion,
            @IdUsuarioObjetivo AS IdUsuario,
            @TipoRestriccion AS TipoRestriccion,
            CAST(0 AS BIT) AS Activa,
            CAST(0 AS BIT) AS SinCambios;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


PRINT '=======================================================';
PRINT ' PROCEDIMIENTOS DE ADMINISTRACION DE USUARIO CREADOS / ACTUALIZADOS';
PRINT '=======================================================';
GO