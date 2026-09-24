/* ============================================================================
   PLATAFORMA APUESTAS - DATOS DEMO PARA REVISION
   Archivo: 01_DatosDemoRevision.sql

   OBJETIVO
   -------
   Crear datos persistentes, ficticios y re-ejecutables para demostracion:
   - 6 usuarios cliente con la misma contrasena academica.
   - Billeteras, verificacion de correo y verificacion administrativa.
   - Ligas, participantes, eventos, mercados, selecciones y cuotas.
   - 3 boletos de ejemplo (2 simples + 1 combinado), siempre que el esquema
     y los procedimientos instalados permitan procesarlos.

   TABLAS DE CATALOGO QUE ESTE SCRIPT NO INSERTA, ACTUALIZA NI ELIMINA
   -------------------------------------------------------------------
   dbo.Rol
   dbo.Pais
   dbo.Departamento
   dbo.Municipio
   dbo.TipoEstado
   dbo.Estado
   dbo.Deporte
   dbo.TipoTransaccion
   dbo.ConfiguracionSistema

   NOTA
   ----
   Este script CONSULTA esos catalogos para resolver IDs validos.
   Utiliza los procedimientos oficiales del proyecto para preservar
   reglas de negocio, auditoria, billeteras y estados.

   Contrasena comun de los usuarios demo: Admin123!
   Hash BCrypt utilizado: compatible con org.mindrot.jbcrypt del proyecto.

   Ejecutar conectado a la base PlataformaApuestas.
   No contiene USE para mantener compatibilidad con SQL Server local y Azure SQL.
   ============================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* ============================================================================
   0. VALIDACIONES DE INSTALACION
   ============================================================================ */

IF OBJECT_ID('dbo.sp_RegistrarUsuarioCliente', 'P') IS NULL
    THROW 75001, 'Falta dbo.sp_RegistrarUsuarioCliente. Ejecute primero los procedimientos del proyecto.', 1;

IF OBJECT_ID('dbo.sp_CrearTokenSeguridad', 'P') IS NULL
    THROW 75002, 'Falta dbo.sp_CrearTokenSeguridad.', 1;

IF OBJECT_ID('dbo.sp_VerificarCorreoConToken', 'P') IS NULL
    THROW 75003, 'Falta dbo.sp_VerificarCorreoConToken.', 1;

IF OBJECT_ID('dbo.sp_AprobarVerificacionUsuario', 'P') IS NULL
    THROW 75004, 'Falta dbo.sp_AprobarVerificacionUsuario.', 1;

IF OBJECT_ID('dbo.sp_SincronizarHabilitacionUsuario', 'P') IS NULL
    THROW 75005, 'Falta dbo.sp_SincronizarHabilitacionUsuario.', 1;

IF OBJECT_ID('dbo.sp_CrearLiga', 'P') IS NULL
    THROW 75006, 'Falta dbo.sp_CrearLiga.', 1;

IF OBJECT_ID('dbo.sp_CrearParticipante', 'P') IS NULL
    THROW 75007, 'Falta dbo.sp_CrearParticipante.', 1;

IF OBJECT_ID('dbo.sp_CrearEvento', 'P') IS NULL
    THROW 75008, 'Falta dbo.sp_CrearEvento.', 1;

IF OBJECT_ID('dbo.sp_AgregarParticipanteEvento', 'P') IS NULL
    THROW 75009, 'Falta dbo.sp_AgregarParticipanteEvento.', 1;

IF OBJECT_ID('dbo.sp_CrearMercado', 'P') IS NULL
    THROW 75010, 'Falta dbo.sp_CrearMercado.', 1;

IF OBJECT_ID('dbo.sp_CrearSeleccion', 'P') IS NULL
    THROW 75011, 'Falta dbo.sp_CrearSeleccion.', 1;

IF OBJECT_ID('dbo.sp_RegistrarCuota', 'P') IS NULL
    THROW 75012, 'Falta dbo.sp_RegistrarCuota.', 1;

IF OBJECT_ID('dbo.sp_CambiarEstadoEvento', 'P') IS NULL
    THROW 75013, 'Falta dbo.sp_CambiarEstadoEvento.', 1;

IF OBJECT_ID('dbo.sp_CambiarEstadoMercado', 'P') IS NULL
    THROW 75014, 'Falta dbo.sp_CambiarEstadoMercado.', 1;

IF OBJECT_ID('dbo.sp_RealizarApuesta', 'P') IS NULL
    THROW 75015, 'Falta dbo.sp_RealizarApuesta.', 1;

IF OBJECT_ID('dbo.sp_AjustarSaldoVirtual', 'P') IS NULL
    THROW 75025, 'Falta dbo.sp_AjustarSaldoVirtual.', 1;

DECLARE @IdAdministrador INT;
DECLARE @IdPaisGT INT;
DECLARE @IdDeporteFutbol INT;
DECLARE @IdDeporteBaloncesto INT;
DECLARE @IdDeporteTenis INT;

SELECT TOP (1)
    @IdAdministrador = U.IdUsuario
FROM dbo.Usuario AS U
INNER JOIN dbo.Rol AS R
    ON R.IdRol = U.IdRol
INNER JOIN dbo.Estado AS E
    ON E.IdEstado = U.IdEstado
INNER JOIN dbo.TipoEstado AS TE
    ON TE.IdTipoEstado = E.IdTipoEstado
   AND TE.Codigo = 'USUARIO'
WHERE R.Nombre = 'ADMINISTRADOR'
  AND R.Activo = 1
  AND E.Codigo = 'ACTIVO'
ORDER BY U.IdUsuario;

IF @IdAdministrador IS NULL
    THROW 75016, 'No existe un ADMINISTRADOR ACTIVO para procesar los datos demo.', 1;

SELECT @IdPaisGT = IdPais
FROM dbo.Pais
WHERE CodigoISO2 = 'GT'
  AND Activo = 1;

IF @IdPaisGT IS NULL
    THROW 75017, 'Guatemala no existe o no esta activa en dbo.Pais.', 1;

SELECT @IdDeporteFutbol = IdDeporte
FROM dbo.Deporte
WHERE Nombre = 'Futbol'
  AND Activo = 1;

SELECT @IdDeporteBaloncesto = IdDeporte
FROM dbo.Deporte
WHERE Nombre = 'Baloncesto'
  AND Activo = 1;

SELECT @IdDeporteTenis = IdDeporte
FROM dbo.Deporte
WHERE Nombre = 'Tenis'
  AND Activo = 1;

IF @IdDeporteFutbol IS NULL
   OR @IdDeporteBaloncesto IS NULL
   OR @IdDeporteTenis IS NULL
    THROW 75018, 'Faltan los deportes Futbol, Baloncesto o Tenis en el catalogo inicial.', 1;

/* Se toman seis municipios activos de Guatemala.
   No se insertan ni se cambian catalogos. */
DECLARE @MunicipiosDemo TABLE
(
    Orden INT IDENTITY(1,1) PRIMARY KEY,
    IdMunicipio INT NOT NULL,
    Departamento VARCHAR(100) NOT NULL,
    Municipio VARCHAR(100) NOT NULL
);

INSERT INTO @MunicipiosDemo (IdMunicipio, Departamento, Municipio)
SELECT TOP (6)
    M.IdMunicipio,
    D.Nombre,
    M.Nombre
FROM dbo.Municipio AS M
INNER JOIN dbo.Departamento AS D
    ON D.IdDepartamento = M.IdDepartamento
WHERE D.IdPais = @IdPaisGT
  AND D.Activo = 1
  AND M.Activo = 1
ORDER BY D.Nombre, M.Nombre;

IF (SELECT COUNT(*) FROM @MunicipiosDemo) < 6
    THROW 75019, 'Se requieren al menos seis municipios activos de Guatemala.', 1;

PRINT '=======================================================';
PRINT ' INICIO: CARGA DE DATOS DEMO PARA REVISION';
PRINT '=======================================================';

/* ============================================================================
   1. USUARIOS CLIENTE DEMO
   ============================================================================ */

DECLARE @HashContrasena VARCHAR(255) =
    '$2a$12$y9tVQWGEeVH776CzAefsBeWONBLgTevtif6lKl8VcJlEvM2IL3zCK';
-- El hash anterior corresponde a: Admin123!

DECLARE @UsuariosDemo TABLE
(
    Orden INT PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Apellido VARCHAR(100) NOT NULL,
    Correo VARCHAR(150) NOT NULL,
    FechaNacimiento DATE NOT NULL,
    Genero CHAR(1) NOT NULL,
    Telefono VARCHAR(25) NOT NULL,
    NumeroDocumento VARCHAR(50) NOT NULL,
    Direccion VARCHAR(250) NOT NULL,
    IdMunicipio INT NOT NULL
);

INSERT INTO @UsuariosDemo
(
    Orden, Nombre, Apellido, Correo, FechaNacimiento,
    Genero, Telefono, NumeroDocumento, Direccion, IdMunicipio
)
SELECT
    V.Orden,
    V.Nombre,
    V.Apellido,
    V.Correo,
    V.FechaNacimiento,
    V.Genero,
    V.Telefono,
    V.NumeroDocumento,
    V.Direccion,
    M.IdMunicipio
FROM
(
    VALUES
        (1, 'Ana',    'Lopez',    'cliente.ana@apuestas.test',    CONVERT(DATE,'1998-04-12'), 'F', '+50255510001', '2999999990001', 'Zona demo 1, Guatemala'),
        (2, 'Carlos', 'Mendez',   'cliente.carlos@apuestas.test', CONVERT(DATE,'1995-08-23'), 'M', '+50255510002', '2999999990002', 'Zona demo 2, Guatemala'),
        (3, 'Sofia',  'Morales',  'cliente.sofia@apuestas.test',  CONVERT(DATE,'2000-02-17'), 'F', '+50255510003', '2999999990003', 'Zona demo 3, Guatemala'),
        (4, 'Mateo',  'Castillo', 'cliente.mateo@apuestas.test',  CONVERT(DATE,'1997-11-05'), 'M', '+50255510004', '2999999990004', 'Zona demo 4, Guatemala'),
        (5, 'Lucia',  'Ramirez',  'cliente.lucia@apuestas.test',  CONVERT(DATE,'1994-06-30'), 'F', '+50255510005', '2999999990005', 'Zona demo 5, Guatemala'),
        (6, 'Diego',  'Herrera',  'cliente.diego@apuestas.test',  CONVERT(DATE,'1999-09-14'), 'M', '+50255510006', '2999999990006', 'Zona demo 6, Guatemala')
) AS V
(
    Orden, Nombre, Apellido, Correo, FechaNacimiento,
    Genero, Telefono, NumeroDocumento, Direccion
)
INNER JOIN @MunicipiosDemo AS M
    ON M.Orden = V.Orden;

DECLARE
    @UOrden INT,
    @UNombre VARCHAR(100),
    @UApellido VARCHAR(100),
    @UCorreo VARCHAR(150),
    @UFechaNacimiento DATE,
    @UGenero CHAR(1),
    @UTelefono VARCHAR(25),
    @UNumeroDocumento VARCHAR(50),
    @UDireccion VARCHAR(250),
    @UIdMunicipio INT,
    @UIdUsuario INT,
    @UIdVerificacion INT,
    @UEstadoVerificacion VARCHAR(40),
    @UTokenHash CHAR(64);

DECLARE curUsuarios CURSOR LOCAL FAST_FORWARD FOR
SELECT
    Orden, Nombre, Apellido, Correo, FechaNacimiento,
    Genero, Telefono, NumeroDocumento, Direccion, IdMunicipio
FROM @UsuariosDemo
ORDER BY Orden;

OPEN curUsuarios;

FETCH NEXT FROM curUsuarios INTO
    @UOrden, @UNombre, @UApellido, @UCorreo, @UFechaNacimiento,
    @UGenero, @UTelefono, @UNumeroDocumento, @UDireccion, @UIdMunicipio;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @UIdUsuario = NULL;
    SET @UIdVerificacion = NULL;
    SET @UEstadoVerificacion = NULL;
    SET @UTokenHash = NULL;

    SELECT @UIdUsuario = IdUsuario
    FROM dbo.Usuario
    WHERE Correo = @UCorreo;

    IF @UIdUsuario IS NULL
    BEGIN
        EXEC dbo.sp_RegistrarUsuarioCliente
            @Nombre = @UNombre,
            @Apellido = @UApellido,
            @Correo = @UCorreo,
            @Contrasena = @HashContrasena,
            @FechaNacimiento = @UFechaNacimiento,
            @Genero = @UGenero,
            @Telefono = @UTelefono,
            @TipoDocumento = 'DPI',
            @NumeroDocumento = @UNumeroDocumento,
            @IdPais = @IdPaisGT,
            @IdMunicipio = @UIdMunicipio,
            @CiudadExterior = NULL,
            @Direccion = @UDireccion;

        SELECT @UIdUsuario = IdUsuario
        FROM dbo.Usuario
        WHERE Correo = @UCorreo;
    END;

    IF @UIdUsuario IS NULL
        THROW 75020, 'No fue posible localizar un usuario demo despues del registro.', 1;

    /* La cuenta demo debe conservar siempre rol USUARIO. */
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario AS U
        INNER JOIN dbo.Rol AS R
            ON R.IdRol = U.IdRol
        WHERE U.IdUsuario = @UIdUsuario
          AND R.Nombre = 'USUARIO'
    )
        THROW 75021, 'Un correo reservado para datos demo existe con un rol diferente de USUARIO.', 1;

    /* Verificar correo usando el flujo oficial de tokens. */
    IF EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE IdUsuario = @UIdUsuario
          AND CorreoVerificado = 0
    )
    BEGIN
        SET @UTokenHash =
            CONVERT
            (
                CHAR(64),
                CONVERT
                (
                    VARCHAR(64),
                    HASHBYTES
                    (
                        'SHA2_256',
                        CONCAT('DEMO-REVISION-', @UCorreo, '-', CONVERT(VARCHAR(36), NEWID()))
                    ),
                    2
                )
            );

        EXEC dbo.sp_CrearTokenSeguridad
            @Correo = @UCorreo,
            @TipoToken = 'VERIFICACION_CORREO',
            @TokenHash = @UTokenHash;

        EXEC dbo.sp_VerificarCorreoConToken
            @TokenHash = @UTokenHash;
    END;

    SELECT TOP (1)
        @UIdVerificacion = V.IdVerificacion,
        @UEstadoVerificacion = E.Codigo
    FROM dbo.VerificacionUsuario AS V
    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = V.IdEstado
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'VERIFICACION'
    WHERE V.IdUsuario = @UIdUsuario
    ORDER BY V.IdVerificacion DESC;

    IF @UIdVerificacion IS NULL
        THROW 75022, 'Un usuario demo no posee registro de verificacion.', 1;

    IF @UEstadoVerificacion IN ('PENDIENTE', 'EN_REVISION')
    BEGIN
        EXEC dbo.sp_AprobarVerificacionUsuario
            @IdUsuarioProceso = @IdAdministrador,
            @IdVerificacion = @UIdVerificacion,
            @Observacion = 'Aprobacion automatica para datos ficticios de revision academica.',
            @IpOrigen = '127.0.0.1';
    END
    ELSE IF @UEstadoVerificacion <> 'APROBADA'
    BEGIN
        THROW 75023, 'Un usuario demo tiene una verificacion en estado incompatible con la carga.', 1;
    END;

    EXEC dbo.sp_SincronizarHabilitacionUsuario
        @IdUsuario = @UIdUsuario;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario AS U
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'USUARIO'
        WHERE U.IdUsuario = @UIdUsuario
          AND U.CorreoVerificado = 1
          AND E.Codigo = 'ACTIVO'
    )
        THROW 75024, 'Un usuario demo no quedo ACTIVO y con correo verificado.', 1;

    FETCH NEXT FROM curUsuarios INTO
        @UOrden, @UNombre, @UApellido, @UCorreo, @UFechaNacimiento,
        @UGenero, @UTelefono, @UNumeroDocumento, @UDireccion, @UIdMunicipio;
END;

CLOSE curUsuarios;
DEALLOCATE curUsuarios;

PRINT 'Usuarios demo: OK';

/* ============================================================================
   2. LIGAS DEMO
   ============================================================================ */

DECLARE @LigasDemo TABLE
(
    Codigo VARCHAR(30) PRIMARY KEY,
    IdDeporte INT NOT NULL,
    Nombre VARCHAR(150) NOT NULL,
    IdLiga INT NULL
);

INSERT INTO @LigasDemo (Codigo, IdDeporte, Nombre)
VALUES
    ('LIGA_FUT', @IdDeporteFutbol,     'DEMO IA - Liga Futbol Guatemala'),
    ('LIGA_BAL', @IdDeporteBaloncesto, 'DEMO IA - Liga Baloncesto Guatemala'),
    ('LIGA_TEN', @IdDeporteTenis,      'DEMO IA - Circuito Tenis Guatemala');

DECLARE
    @LCodigo VARCHAR(30),
    @LIdDeporte INT,
    @LNombre VARCHAR(150),
    @LIdLiga INT;

DECLARE curLigas CURSOR LOCAL FAST_FORWARD FOR
SELECT Codigo, IdDeporte, Nombre
FROM @LigasDemo;

OPEN curLigas;
FETCH NEXT FROM curLigas INTO @LCodigo, @LIdDeporte, @LNombre;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @LIdLiga = NULL;

    SELECT @LIdLiga = IdLiga
    FROM dbo.Liga
    WHERE IdDeporte = @LIdDeporte
      AND Nombre = @LNombre;

    IF @LIdLiga IS NULL
    BEGIN
        EXEC dbo.sp_CrearLiga
            @IdUsuarioProceso = @IdAdministrador,
            @IdDeporte = @LIdDeporte,
            @Nombre = @LNombre,
            @IdPais = @IdPaisGT,
            @IpOrigen = '127.0.0.1';

        SELECT @LIdLiga = IdLiga
        FROM dbo.Liga
        WHERE IdDeporte = @LIdDeporte
          AND Nombre = @LNombre;
    END;

    UPDATE @LigasDemo
    SET IdLiga = @LIdLiga
    WHERE Codigo = @LCodigo;

    FETCH NEXT FROM curLigas INTO @LCodigo, @LIdDeporte, @LNombre;
END;

CLOSE curLigas;
DEALLOCATE curLigas;

PRINT 'Ligas demo: OK';

/* ============================================================================
   3. PARTICIPANTES DEMO
   ============================================================================ */

DECLARE @ParticipantesDemo TABLE
(
    Codigo VARCHAR(40) PRIMARY KEY,
    IdDeporte INT NOT NULL,
    Nombre VARCHAR(150) NOT NULL,
    TipoParticipante VARCHAR(30) NOT NULL,
    IdParticipante INT NULL
);

INSERT INTO @ParticipantesDemo
(
    Codigo, IdDeporte, Nombre, TipoParticipante
)
VALUES
    ('FUT_QUETZAL',   @IdDeporteFutbol,     'DEMO IA - Quetzales FC',   'EQUIPO'),
    ('FUT_VOLCAN',    @IdDeporteFutbol,     'DEMO IA - Volcanes FC',    'EQUIPO'),
    ('FUT_JAGUAR',    @IdDeporteFutbol,     'DEMO IA - Jaguar FC',      'EQUIPO'),
    ('FUT_LAGO',      @IdDeporteFutbol,     'DEMO IA - Lago Azul FC',   'EQUIPO'),
    ('BAL_MAYAS',     @IdDeporteBaloncesto, 'DEMO IA - Mayas BC',       'EQUIPO'),
    ('BAL_ALTIPLANO', @IdDeporteBaloncesto, 'DEMO IA - Altiplano BC',   'EQUIPO'),
    ('TEN_ANDREA',    @IdDeporteTenis,      'DEMO IA - Andrea Solis',   'ATLETA'),
    ('TEN_MATEO',     @IdDeporteTenis,      'DEMO IA - Mateo Ruiz',     'ATLETA');

DECLARE
    @PCodigo VARCHAR(40),
    @PIdDeporte INT,
    @PNombre VARCHAR(150),
    @PTipo VARCHAR(30),
    @PIdParticipante INT;

DECLARE curParticipantes CURSOR LOCAL FAST_FORWARD FOR
SELECT Codigo, IdDeporte, Nombre, TipoParticipante
FROM @ParticipantesDemo;

OPEN curParticipantes;
FETCH NEXT FROM curParticipantes INTO @PCodigo, @PIdDeporte, @PNombre, @PTipo;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @PIdParticipante = NULL;

    SELECT TOP (1)
        @PIdParticipante = IdParticipante
    FROM dbo.Participante
    WHERE IdDeporte = @PIdDeporte
      AND Nombre = @PNombre
    ORDER BY IdParticipante;

    IF @PIdParticipante IS NULL
    BEGIN
        EXEC dbo.sp_CrearParticipante
            @IdUsuarioProceso = @IdAdministrador,
            @IdDeporte = @PIdDeporte,
            @Nombre = @PNombre,
            @TipoParticipante = @PTipo,
            @IdPais = @IdPaisGT,
            @IpOrigen = '127.0.0.1';

        SELECT TOP (1)
            @PIdParticipante = IdParticipante
        FROM dbo.Participante
        WHERE IdDeporte = @PIdDeporte
          AND Nombre = @PNombre
        ORDER BY IdParticipante;
    END;

    UPDATE @ParticipantesDemo
    SET IdParticipante = @PIdParticipante
    WHERE Codigo = @PCodigo;

    FETCH NEXT FROM curParticipantes INTO @PCodigo, @PIdDeporte, @PNombre, @PTipo;
END;

CLOSE curParticipantes;
DEALLOCATE curParticipantes;

PRINT 'Participantes demo: OK';

/* ============================================================================
   4. EVENTOS DEMO
   Fechas relativas al momento de la primera ejecucion.
   ============================================================================ */

DECLARE @EventosDemo TABLE
(
    Codigo VARCHAR(40) PRIMARY KEY,
    CodigoLiga VARCHAR(30) NOT NULL,
    Nombre VARCHAR(200) NOT NULL,
    DiasInicio INT NOT NULL,
    DuracionHoras INT NOT NULL,
    Participante1 VARCHAR(40) NOT NULL,
    Participante2 VARCHAR(40) NOT NULL,
    IdEvento INT NULL
);

INSERT INTO @EventosDemo
(
    Codigo, CodigoLiga, Nombre, DiasInicio, DuracionHoras,
    Participante1, Participante2
)
VALUES
    ('EV_FUT_1', 'LIGA_FUT', 'DEMO IA - Quetzales FC vs Volcanes FC', 2, 2, 'FUT_QUETZAL', 'FUT_VOLCAN'),
    ('EV_FUT_2', 'LIGA_FUT', 'DEMO IA - Jaguar FC vs Lago Azul FC',   4, 2, 'FUT_JAGUAR',  'FUT_LAGO'),
    ('EV_BAL_1', 'LIGA_BAL', 'DEMO IA - Mayas BC vs Altiplano BC',    3, 3, 'BAL_MAYAS',   'BAL_ALTIPLANO'),
    ('EV_TEN_1', 'LIGA_TEN', 'DEMO IA - Andrea Solis vs Mateo Ruiz',  5, 4, 'TEN_ANDREA',  'TEN_MATEO');

DECLARE
    @ECodigo VARCHAR(40),
    @ECodigoLiga VARCHAR(30),
    @ENombre VARCHAR(200),
    @EDiasInicio INT,
    @EDuracionHoras INT,
    @EParticipante1 VARCHAR(40),
    @EParticipante2 VARCHAR(40),
    @EIdLiga INT,
    @EIdEvento INT,
    @EIdParticipante1 INT,
    @EIdParticipante2 INT,
    @EFechaInicio DATETIME2,
    @EFechaFin DATETIME2;

DECLARE curEventos CURSOR LOCAL FAST_FORWARD FOR
SELECT
    Codigo, CodigoLiga, Nombre, DiasInicio, DuracionHoras,
    Participante1, Participante2
FROM @EventosDemo;

OPEN curEventos;
FETCH NEXT FROM curEventos INTO
    @ECodigo, @ECodigoLiga, @ENombre, @EDiasInicio, @EDuracionHoras,
    @EParticipante1, @EParticipante2;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @EIdLiga = IdLiga
    FROM @LigasDemo
    WHERE Codigo = @ECodigoLiga;

    SELECT @EIdParticipante1 = IdParticipante
    FROM @ParticipantesDemo
    WHERE Codigo = @EParticipante1;

    SELECT @EIdParticipante2 = IdParticipante
    FROM @ParticipantesDemo
    WHERE Codigo = @EParticipante2;

    SET @EIdEvento = NULL;

    SELECT @EIdEvento = IdEvento
    FROM dbo.Evento
    WHERE IdLiga = @EIdLiga
      AND Nombre = @ENombre;

    IF @EIdEvento IS NULL
    BEGIN
        SET @EFechaInicio =
            DATEADD(HOUR, 19, CAST(DATEADD(DAY, @EDiasInicio, CAST(SYSDATETIME() AS DATE)) AS DATETIME2));

        SET @EFechaFin =
            DATEADD(HOUR, @EDuracionHoras, @EFechaInicio);

        EXEC dbo.sp_CrearEvento
            @IdUsuarioProceso = @IdAdministrador,
            @IdLiga = @EIdLiga,
            @Nombre = @ENombre,
            @FechaInicio = @EFechaInicio,
            @FechaFin = @EFechaFin,
            @IpOrigen = '127.0.0.1';

        SELECT @EIdEvento = IdEvento
        FROM dbo.Evento
        WHERE IdLiga = @EIdLiga
          AND Nombre = @ENombre;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.EventoParticipante
        WHERE IdEvento = @EIdEvento
          AND IdParticipante = @EIdParticipante1
    )
    BEGIN
        EXEC dbo.sp_AgregarParticipanteEvento
            @IdUsuarioProceso = @IdAdministrador,
            @IdEvento = @EIdEvento,
            @IdParticipante = @EIdParticipante1,
            @OrdenParticipante = 1,
            @EsLocal = 1,
            @IpOrigen = '127.0.0.1';
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.EventoParticipante
        WHERE IdEvento = @EIdEvento
          AND IdParticipante = @EIdParticipante2
    )
    BEGIN
        EXEC dbo.sp_AgregarParticipanteEvento
            @IdUsuarioProceso = @IdAdministrador,
            @IdEvento = @EIdEvento,
            @IdParticipante = @EIdParticipante2,
            @OrdenParticipante = 2,
            @EsLocal = 0,
            @IpOrigen = '127.0.0.1';
    END;

    UPDATE @EventosDemo
    SET IdEvento = @EIdEvento
    WHERE Codigo = @ECodigo;

    FETCH NEXT FROM curEventos INTO
        @ECodigo, @ECodigoLiga, @ENombre, @EDiasInicio, @EDuracionHoras,
        @EParticipante1, @EParticipante2;
END;

CLOSE curEventos;
DEALLOCATE curEventos;

PRINT 'Eventos demo: OK';

/* ============================================================================
   5. MERCADOS, SELECCIONES Y CUOTAS
   ============================================================================ */

DECLARE @MercadosDemo TABLE
(
    Codigo VARCHAR(50) PRIMARY KEY,
    CodigoEvento VARCHAR(40) NOT NULL,
    Nombre VARCHAR(150) NOT NULL,
    Descripcion VARCHAR(250) NULL,
    IdMercado INT NULL
);

INSERT INTO @MercadosDemo
(
    Codigo, CodigoEvento, Nombre, Descripcion
)
VALUES
    ('MER_FUT1_1X2',  'EV_FUT_1', 'Resultado final', 'Ganador del partido o empate.'),
    ('MER_FUT1_G25',  'EV_FUT_1', 'Total de goles 2.5', 'Total de goles del partido.'),
    ('MER_FUT2_1X2',  'EV_FUT_2', 'Resultado final', 'Ganador del partido o empate.'),
    ('MER_BAL1_WIN',  'EV_BAL_1', 'Ganador del partido', 'Ganador al finalizar el encuentro.'),
    ('MER_TEN1_WIN',  'EV_TEN_1', 'Ganador del partido', 'Ganador del encuentro de tenis.');

DECLARE @SeleccionesDemo TABLE
(
    CodigoMercado VARCHAR(50) NOT NULL,
    CodigoSeleccion VARCHAR(60) PRIMARY KEY,
    Nombre VARCHAR(150) NOT NULL,
    Cuota DECIMAL(10,4) NOT NULL,
    IdSeleccion INT NULL
);

INSERT INTO @SeleccionesDemo
(
    CodigoMercado, CodigoSeleccion, Nombre, Cuota
)
VALUES
    ('MER_FUT1_1X2', 'SEL_FUT1_LOCAL',   'Quetzales FC',  1.8500),
    ('MER_FUT1_1X2', 'SEL_FUT1_EMPATE',  'Empate',        3.2000),
    ('MER_FUT1_1X2', 'SEL_FUT1_VISITA',  'Volcanes FC',   2.4000),

    ('MER_FUT1_G25', 'SEL_FUT1_MAS25',   'Mas de 2.5',    1.9000),
    ('MER_FUT1_G25', 'SEL_FUT1_MENOS25', 'Menos de 2.5',  1.8000),

    ('MER_FUT2_1X2', 'SEL_FUT2_LOCAL',    'Jaguar FC',     2.0500),
    ('MER_FUT2_1X2', 'SEL_FUT2_EMPATE',   'Empate',        3.0000),
    ('MER_FUT2_1X2', 'SEL_FUT2_VISITA',   'Lago Azul FC',  2.1500),

    ('MER_BAL1_WIN', 'SEL_BAL1_LOCAL',     'Mayas BC',      1.7000),
    ('MER_BAL1_WIN', 'SEL_BAL1_VISITA',    'Altiplano BC',  2.0500),

    ('MER_TEN1_WIN', 'SEL_TEN1_LOCAL',     'Andrea Solis',  1.6500),
    ('MER_TEN1_WIN', 'SEL_TEN1_VISITA',    'Mateo Ruiz',    2.2000);

DECLARE
    @MCodigo VARCHAR(50),
    @MCodigoEvento VARCHAR(40),
    @MNombre VARCHAR(150),
    @MDescripcion VARCHAR(250),
    @MIdEvento INT,
    @MIdMercado INT;

DECLARE curMercados CURSOR LOCAL FAST_FORWARD FOR
SELECT Codigo, CodigoEvento, Nombre, Descripcion
FROM @MercadosDemo;

OPEN curMercados;
FETCH NEXT FROM curMercados INTO @MCodigo, @MCodigoEvento, @MNombre, @MDescripcion;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @MIdEvento = IdEvento
    FROM @EventosDemo
    WHERE Codigo = @MCodigoEvento;

    SET @MIdMercado = NULL;

    SELECT @MIdMercado = IdMercado
    FROM dbo.Mercado
    WHERE IdEvento = @MIdEvento
      AND Nombre = @MNombre;

    IF @MIdMercado IS NULL
    BEGIN
        EXEC dbo.sp_CrearMercado
            @IdUsuarioProceso = @IdAdministrador,
            @IdEvento = @MIdEvento,
            @Nombre = @MNombre,
            @Descripcion = @MDescripcion,
            @IpOrigen = '127.0.0.1';

        SELECT @MIdMercado = IdMercado
        FROM dbo.Mercado
        WHERE IdEvento = @MIdEvento
          AND Nombre = @MNombre;
    END;

    UPDATE @MercadosDemo
    SET IdMercado = @MIdMercado
    WHERE Codigo = @MCodigo;

    FETCH NEXT FROM curMercados INTO @MCodigo, @MCodigoEvento, @MNombre, @MDescripcion;
END;

CLOSE curMercados;
DEALLOCATE curMercados;

DECLARE
    @SCodigoMercado VARCHAR(50),
    @SCodigoSeleccion VARCHAR(60),
    @SNombre VARCHAR(150),
    @SCuota DECIMAL(10,4),
    @SIdMercado INT,
    @SIdSeleccion INT;

DECLARE curSelecciones CURSOR LOCAL FAST_FORWARD FOR
SELECT CodigoMercado, CodigoSeleccion, Nombre, Cuota
FROM @SeleccionesDemo;

OPEN curSelecciones;
FETCH NEXT FROM curSelecciones INTO
    @SCodigoMercado, @SCodigoSeleccion, @SNombre, @SCuota;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @SIdMercado = IdMercado
    FROM @MercadosDemo
    WHERE Codigo = @SCodigoMercado;

    SET @SIdSeleccion = NULL;

    SELECT @SIdSeleccion = IdSeleccion
    FROM dbo.Seleccion
    WHERE IdMercado = @SIdMercado
      AND Nombre = @SNombre;

    IF @SIdSeleccion IS NULL
    BEGIN
        EXEC dbo.sp_CrearSeleccion
            @IdUsuarioProceso = @IdAdministrador,
            @IdMercado = @SIdMercado,
            @Nombre = @SNombre,
            @IpOrigen = '127.0.0.1';

        SELECT @SIdSeleccion = IdSeleccion
        FROM dbo.Seleccion
        WHERE IdMercado = @SIdMercado
          AND Nombre = @SNombre;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Cuota
        WHERE IdSeleccion = @SIdSeleccion
          AND Activo = 1
          AND FechaFin IS NULL
    )
    BEGIN
        EXEC dbo.sp_RegistrarCuota
            @IdUsuarioProceso = @IdAdministrador,
            @IdSeleccion = @SIdSeleccion,
            @Valor = @SCuota,
            @IpOrigen = '127.0.0.1';
    END;

    UPDATE @SeleccionesDemo
    SET IdSeleccion = @SIdSeleccion
    WHERE CodigoSeleccion = @SCodigoSeleccion;

    FETCH NEXT FROM curSelecciones INTO
        @SCodigoMercado, @SCodigoSeleccion, @SNombre, @SCuota;
END;

CLOSE curSelecciones;
DEALLOCATE curSelecciones;

/* Publicar eventos. */
DECLARE @PubIdEvento INT;

DECLARE curPublicarEventos CURSOR LOCAL FAST_FORWARD FOR
SELECT IdEvento
FROM @EventosDemo
WHERE IdEvento IS NOT NULL;

OPEN curPublicarEventos;
FETCH NEXT FROM curPublicarEventos INTO @PubIdEvento;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Evento AS EV
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = EV.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'EVENTO'
        WHERE EV.IdEvento = @PubIdEvento
          AND E.Codigo = 'PROGRAMADO'
    )
    BEGIN
        EXEC dbo.sp_CambiarEstadoEvento
            @IdUsuarioProceso = @IdAdministrador,
            @IdEvento = @PubIdEvento,
            @NuevoEstado = 'PROGRAMADO',
            @Motivo = 'Publicacion de evento ficticio para revision academica.',
            @IpOrigen = '127.0.0.1';
    END;

    FETCH NEXT FROM curPublicarEventos INTO @PubIdEvento;
END;

CLOSE curPublicarEventos;
DEALLOCATE curPublicarEventos;

/* Abrir mercados. */
DECLARE @PubIdMercado INT;

DECLARE curAbrirMercados CURSOR LOCAL FAST_FORWARD FOR
SELECT IdMercado
FROM @MercadosDemo
WHERE IdMercado IS NOT NULL;

OPEN curAbrirMercados;
FETCH NEXT FROM curAbrirMercados INTO @PubIdMercado;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Mercado AS M
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'MERCADO'
        WHERE M.IdMercado = @PubIdMercado
          AND E.Codigo = 'ABIERTO'
    )
    BEGIN
        EXEC dbo.sp_CambiarEstadoMercado
            @IdUsuarioProceso = @IdAdministrador,
            @IdMercado = @PubIdMercado,
            @NuevoEstado = 'ABIERTO',
            @Motivo = 'Apertura de mercado ficticio para revision academica.',
            @IpOrigen = '127.0.0.1';
    END;

    FETCH NEXT FROM curAbrirMercados INTO @PubIdMercado;
END;

CLOSE curAbrirMercados;
DEALLOCATE curAbrirMercados;

PRINT 'Mercados, selecciones y cuotas demo: OK';

/* ============================================================================
   6. BOLETOS DE EJEMPLO
   - 2 apuestas simples
   - 1 apuesta combinada
   Las referencias son fijas para no duplicar boletos al re-ejecutar.
   ============================================================================ */

DECLARE @IdSelFut1Local INT =
    (SELECT IdSeleccion FROM @SeleccionesDemo WHERE CodigoSeleccion = 'SEL_FUT1_LOCAL');

DECLARE @IdSelBal1Local INT =
    (SELECT IdSeleccion FROM @SeleccionesDemo WHERE CodigoSeleccion = 'SEL_BAL1_LOCAL');

DECLARE @IdSelTen1Local INT =
    (SELECT IdSeleccion FROM @SeleccionesDemo WHERE CodigoSeleccion = 'SEL_TEN1_LOCAL');

DECLARE @MontoMinimoApuesta DECIMAL(12,2);

SELECT @MontoMinimoApuesta =
    TRY_CONVERT(DECIMAL(12,2), Valor)
FROM dbo.ConfiguracionSistema
WHERE Clave = 'MONTO_MINIMO_APUESTA';

IF @MontoMinimoApuesta IS NULL OR @MontoMinimoApuesta <= 0
BEGIN
    THROW 75026, 'MONTO_MINIMO_APUESTA no contiene un valor valido.', 1;
END;

DECLARE @ApuestasDemo TABLE
(
    Correo VARCHAR(150) NOT NULL,
    Referencia UNIQUEIDENTIFIER NOT NULL,
    Monto DECIMAL(12,2) NOT NULL,
    SeleccionesJson NVARCHAR(MAX) NOT NULL
);

INSERT INTO @ApuestasDemo (Correo, Referencia, Monto, SeleccionesJson)
VALUES
(
    'cliente.ana@apuestas.test',
    'D3A00000-0000-0000-0000-000000000001',
    @MontoMinimoApuesta,
    N'[' + CONVERT(NVARCHAR(20), @IdSelFut1Local) + N']'
),
(
    'cliente.carlos@apuestas.test',
    'D3A00000-0000-0000-0000-000000000002',
    @MontoMinimoApuesta + 50.00,
    N'[' + CONVERT(NVARCHAR(20), @IdSelBal1Local) + N']'
),
(
    'cliente.sofia@apuestas.test',
    'D3A00000-0000-0000-0000-000000000003',
    @MontoMinimoApuesta + 25.00,
    N'['
        + CONVERT(NVARCHAR(20), @IdSelFut1Local)
        + N','
        + CONVERT(NVARCHAR(20), @IdSelTen1Local)
        + N']'
);

DECLARE
    @ACorreo VARCHAR(150),
    @AReferencia UNIQUEIDENTIFIER,
    @AMonto DECIMAL(12,2),
    @ASeleccionesJson NVARCHAR(MAX),
    @AIdUsuario INT,
    @ASaldo DECIMAL(12,2),
    @AComisionPct DECIMAL(7,4),
    @ATotalNecesario DECIMAL(12,2),
    @ACreditoNecesario DECIMAL(12,2),
    @AReferenciaCredito UNIQUEIDENTIFIER;

SELECT @AComisionPct =
    TRY_CONVERT(DECIMAL(7,4), Valor)
FROM dbo.ConfiguracionSistema
WHERE Clave = 'COMISION_SERVICIO_PORCENTAJE';

IF @AComisionPct IS NULL
    SET @AComisionPct = 0;

DECLARE curApuestas CURSOR LOCAL FAST_FORWARD FOR
SELECT Correo, Referencia, Monto, SeleccionesJson
FROM @ApuestasDemo;

OPEN curApuestas;
FETCH NEXT FROM curApuestas INTO
    @ACorreo, @AReferencia, @AMonto, @ASeleccionesJson;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Boleto
        WHERE ReferenciaOperacion = @AReferencia
    )
    BEGIN
        SELECT @AIdUsuario = IdUsuario
        FROM dbo.Usuario
        WHERE Correo = @ACorreo;

        SELECT @ASaldo = B.SaldoDisponible
        FROM dbo.Billetera AS B
        WHERE B.IdUsuario = @AIdUsuario;

        SET @ATotalNecesario =
            CONVERT
            (
                DECIMAL(12,2),
                ROUND(@AMonto + (@AMonto * @AComisionPct / 100.0), 2)
            );

        /* Si el saldo inicial configurado fuera pequeno, se completa
           solamente lo necesario para poder crear el boleto demo.
           No se cambia ConfiguracionSistema. */
        IF @ASaldo < @ATotalNecesario + 100.00
        BEGIN
            SET @ACreditoNecesario =
                (@ATotalNecesario + 100.00) - @ASaldo;

            SET @AReferenciaCredito = NEWID();

            EXEC dbo.sp_AjustarSaldoVirtual
                @IdUsuarioObjetivo = @AIdUsuario,
                @IdUsuarioProceso = @IdAdministrador,
                @Operacion = 'CREDITO',
                @Monto = @ACreditoNecesario,
                @Motivo = 'Credito para datos demo de revision academica.',
                @ReferenciaOperacion = @AReferenciaCredito,
                @IpOrigen = '127.0.0.1';
        END;

        EXEC dbo.sp_RealizarApuesta
            @IdUsuario = @AIdUsuario,
            @SeleccionesJson = @ASeleccionesJson,
            @Monto = @AMonto,
            @ReferenciaOperacion = @AReferencia,
            @IpOrigen = '127.0.0.1';
    END;

    FETCH NEXT FROM curApuestas INTO
        @ACorreo, @AReferencia, @AMonto, @ASeleccionesJson;
END;

CLOSE curApuestas;
DEALLOCATE curApuestas;

PRINT 'Boletos demo: OK';

/* ============================================================================
   7. RESUMEN FINAL
   ============================================================================ */

PRINT '';
PRINT '=======================================================';
PRINT ' DATOS DEMO CREADOS / VERIFICADOS CORRECTAMENTE';
PRINT '=======================================================';
PRINT ' Usuarios demo: 6';
PRINT ' Contrasena comun: Admin123!';
PRINT ' Datos de catalogo critico: NO MODIFICADOS';
PRINT '=======================================================';

SELECT
    U.IdUsuario,
    U.Correo,
    PU.Nombre,
    PU.Apellido,
    E.Codigo AS EstadoUsuario,
    U.CorreoVerificado,
    B.SaldoDisponible,
    B.SaldoComprometido
FROM dbo.Usuario AS U
INNER JOIN dbo.PerfilUsuario AS PU
    ON PU.IdUsuario = U.IdUsuario
INNER JOIN dbo.Estado AS E
    ON E.IdEstado = U.IdEstado
INNER JOIN dbo.Billetera AS B
    ON B.IdUsuario = U.IdUsuario
WHERE U.Correo LIKE 'cliente.%@apuestas.test'
ORDER BY U.IdUsuario;

SELECT
    EV.IdEvento,
    D.Nombre AS Deporte,
    L.Nombre AS Liga,
    EV.Nombre AS Evento,
    EV.FechaInicio,
    E.Codigo AS EstadoEvento
FROM dbo.Evento AS EV
INNER JOIN dbo.Liga AS L
    ON L.IdLiga = EV.IdLiga
INNER JOIN dbo.Deporte AS D
    ON D.IdDeporte = L.IdDeporte
INNER JOIN dbo.Estado AS E
    ON E.IdEstado = EV.IdEstado
WHERE EV.Nombre LIKE 'DEMO IA - %'
ORDER BY EV.FechaInicio;

SELECT
    B.IdBoleto,
    B.CodigoBoleto,
    U.Correo,
    B.TipoBoleto,
    B.MontoApostado,
    B.ComisionServicio,
    B.CuotaTotal,
    B.GananciaPotencial,
    B.Resultado
FROM dbo.Boleto AS B
INNER JOIN dbo.Usuario AS U
    ON U.IdUsuario = B.IdUsuario
WHERE U.Correo LIKE 'cliente.%@apuestas.test'
ORDER BY B.IdBoleto;
