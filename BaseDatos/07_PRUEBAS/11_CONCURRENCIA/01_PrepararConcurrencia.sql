/* ============================================================
   ARCHIVO:
   07_PRUEBAS/11_CONCURRENCIA/01_PrepararConcurrencia.sql

   OBJETIVO:
   Crear un escenario persistente para probar concurrencia.

   ESCENARIO:
   - Usuario ACTIVO y verificado.
   - Saldo exacto: Q500.
   - Evento PROGRAMADO.
   - Mercado ABIERTO.
   - Selección con cuota 2.0000.
   - Sesión A intentará apostar Q400.
   - Sesión B intentará apostar Q400.

   RESULTADO ESPERADO POSTERIOR:
   Solo una apuesta debe ser aceptada.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


/* ============================================================
   TABLA TEMPORAL DE COORDINACION ENTRE CONEXIONES

   Es una tabla normal porque debe poder consultarse desde:
   - otra ventana de SSMS;
   - otra computadora;
   - otra conexión JDBC.

   Una nueva preparación elimina únicamente esta tabla de
   coordinación. Los datos de pruebas anteriores permanecen
   auditables hasta una reconstrucción limpia.
   ============================================================ */

IF OBJECT_ID('dbo.PruebaConcurrenciaContexto', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.PruebaConcurrenciaContexto;
END;
GO


CREATE TABLE dbo.PruebaConcurrenciaContexto
(
    IdContexto TINYINT NOT NULL
        CONSTRAINT PK_PruebaConcurrenciaContexto
        PRIMARY KEY,

    CodigoPrueba VARCHAR(20) NOT NULL,

    IdAdministrador INT NOT NULL,

    IdUsuarioPrueba INT NOT NULL,
    IdBilleteraUsuario INT NOT NULL,

    IdBilleteraCasa INT NOT NULL,

    IdEvento INT NOT NULL,
    IdMercado INT NOT NULL,

    IdSeleccionA INT NOT NULL,
    IdSeleccionB INT NOT NULL,

    ReferenciaA UNIQUEIDENTIFIER NOT NULL,
    ReferenciaB UNIQUEIDENTIFIER NOT NULL,

    MontoApuesta DECIMAL(12,2) NOT NULL,
    CuotaSeleccionA DECIMAL(10,4) NOT NULL,

    SaldoInicialUsuario DECIMAL(12,2) NOT NULL,

    IdBoletoGanador INT NULL,

    SaldoUsuarioAntesLiquidacion DECIMAL(12,2) NULL,
    ComprometidoAntesLiquidacion DECIMAL(12,2) NULL,

    SaldoCasaAntesLiquidacion DECIMAL(12,2) NULL,

    MontoLiquidadoEsperado DECIMAL(12,2) NULL,
    GananciaNetaEsperada DECIMAL(12,2) NULL,

    EstadoPrueba VARCHAR(40) NOT NULL,

    FechaPreparacion DATETIME2 NOT NULL
        CONSTRAINT DF_PruebaConcurrencia_Fecha
        DEFAULT SYSDATETIME()
);
GO


BEGIN TRY

    BEGIN TRANSACTION;


    PRINT '=======================================================';
    PRINT ' PREPARANDO PRUEBA DE CONCURRENCIA';
    PRINT '=======================================================';


    /* ========================================================
       1. ADMINISTRADOR
       ======================================================== */

    DECLARE @IdAdministrador INT;


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
      AND E.Codigo = 'ACTIVO'

    ORDER BY U.IdUsuario;


    IF @IdAdministrador IS NULL
        THROW 71001, 'No existe un ADMINISTRADOR ACTIVO.', 1;


    /* ========================================================
       2. CATALOGOS
       ======================================================== */

    DECLARE @IdPais INT;
    DECLARE @IdMunicipio INT;
    DECLARE @IdDeporte INT;


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


    SELECT @IdDeporte = IdDeporte
    FROM dbo.Deporte
    WHERE Nombre = 'Futbol'
      AND Activo = 1;


    IF @IdPais IS NULL
       OR @IdMunicipio IS NULL
       OR @IdDeporte IS NULL
        THROW 71002, 'Faltan catálogos para preparar concurrencia.', 1;


    DECLARE @Codigo VARCHAR(20) =
        LEFT
        (
            REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
            12
        );


    /* ========================================================
       3. CREAR USUARIO
       ======================================================== */

    DECLARE @Correo VARCHAR(150) =
        CONCAT('concurrencia.', @Codigo, '@apuestas.test');


    EXEC dbo.sp_RegistrarUsuarioCliente

        @Nombre = 'Usuario',
        @Apellido = 'Concurrencia',

        @Correo = @Correo,

        @Contrasena =
            '$2a$12$HashTemporalConcurrencia123456789012345678901234567890',

        @FechaNacimiento = '2000-01-01',

        @Genero = 'M',

        @Telefono = '55552000',

        @TipoDocumento = 'DPI',

        @NumeroDocumento = 'CON-' + @Codigo,

        @IdPais = @IdPais,

        @IdMunicipio = @IdMunicipio,

        @CiudadExterior = NULL,

        @Direccion = 'Dirección temporal prueba concurrencia';


    DECLARE @IdUsuario INT;
    DECLARE @IdBilleteraUsuario INT;


    SELECT @IdUsuario = IdUsuario
    FROM dbo.Usuario
    WHERE Correo = @Correo;


    SELECT @IdBilleteraUsuario = IdBilletera
    FROM dbo.Billetera
    WHERE IdUsuario = @IdUsuario;


    IF @IdUsuario IS NULL
       OR @IdBilleteraUsuario IS NULL
        THROW 71003, 'No se creó correctamente el usuario de concurrencia.', 1;


    /* ========================================================
       4. VERIFICAR CORREO UTILIZANDO TOKEN
       ======================================================== */

    DECLARE @TokenHash CHAR(64);


    SET @TokenHash =
        CONVERT
        (
            CHAR(64),
            HASHBYTES
            (
                'SHA2_256',
                CONCAT
                (
                    'CONCURRENCIA-',
                    CONVERT(VARCHAR(36), NEWID())
                )
            ),
            2
        );


    EXEC dbo.sp_CrearTokenSeguridad

        @Correo = @Correo,

        @TipoToken = 'VERIFICACION_CORREO',

        @TokenHash = @TokenHash;


    EXEC dbo.sp_VerificarCorreoConToken
        @TokenHash = @TokenHash;


    /* ========================================================
       5. APROBAR VERIFICACION ADMINISTRATIVA
       ======================================================== */

    DECLARE @IdVerificacion INT;


    SELECT TOP (1)
        @IdVerificacion = IdVerificacion
    FROM dbo.VerificacionUsuario
    WHERE IdUsuario = @IdUsuario
    ORDER BY IdVerificacion DESC;


    EXEC dbo.sp_AprobarVerificacionUsuario

        @IdUsuarioProceso = @IdAdministrador,

        @IdVerificacion = @IdVerificacion,

        @Observacion =
            'Aprobación automática para prueba de concurrencia.',

        @IpOrigen = '127.0.0.1';


    IF NOT EXISTS
    (
        SELECT 1

        FROM dbo.Usuario AS U

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado

        WHERE U.IdUsuario = @IdUsuario
          AND U.CorreoVerificado = 1
          AND E.Codigo = 'ACTIVO'
    )
        THROW 71004, 'El usuario de concurrencia no quedó ACTIVO.', 1;


    /* ========================================================
       6. DEJAR SALDO EXACTAMENTE EN Q500
       ======================================================== */

    DECLARE @SaldoActual DECIMAL(12,2);


    SELECT @SaldoActual = SaldoDisponible
    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilleteraUsuario;


    IF @SaldoActual < 500.00
    BEGIN

        EXEC dbo.sp_AjustarSaldoVirtual

            @IdUsuarioObjetivo = @IdUsuario,

            @IdUsuarioProceso = @IdAdministrador,

            @Operacion = 'CREDITO',

            @Monto = 500.00 - @SaldoActual,

            @Motivo =
                'Preparación de saldo para prueba de concurrencia.',

            @ReferenciaOperacion = NEWID(),

            @IpOrigen = '127.0.0.1';

    END;


    IF @SaldoActual > 500.00
    BEGIN

        EXEC dbo.sp_AjustarSaldoVirtual

            @IdUsuarioObjetivo = @IdUsuario,

            @IdUsuarioProceso = @IdAdministrador,

            @Operacion = 'DEBITO',

            @Monto = @SaldoActual - 500.00,

            @Motivo =
                'Preparación de saldo para prueba de concurrencia.',

            @ReferenciaOperacion = NEWID(),

            @IpOrigen = '127.0.0.1';

    END;


    SELECT @SaldoActual = SaldoDisponible
    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilleteraUsuario;


    IF @SaldoActual <> 500.00
        THROW 71005, 'No fue posible dejar el saldo del usuario en Q500.', 1;


    /* ========================================================
       7. CASA
       ======================================================== */

    DECLARE @IdBilleteraCasa INT;


    SELECT @IdBilleteraCasa = B.IdBilletera

    FROM dbo.Billetera AS B

    INNER JOIN dbo.Usuario AS U
        ON U.IdUsuario = B.IdUsuario

    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
       AND R.Nombre = 'CASA'

    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado

    WHERE E.Codigo = 'ACTIVO';


    IF @IdBilleteraCasa IS NULL
        THROW 71006, 'No existe billetera CASA activa.', 1;


    /* ========================================================
       8. LIGA
       ======================================================== */

    DECLARE @NombreLiga VARCHAR(100) =
        'Liga Concurrencia ' + @Codigo;


    EXEC dbo.sp_CrearLiga

        @IdUsuarioProceso = @IdAdministrador,

        @IdDeporte = @IdDeporte,

        @Nombre = @NombreLiga,

        @IdPais = @IdPais,

        @IpOrigen = '127.0.0.1';


    DECLARE @IdLiga INT;


    SELECT @IdLiga = IdLiga
    FROM dbo.Liga
    WHERE IdDeporte = @IdDeporte
      AND Nombre = @NombreLiga;


    /* ========================================================
       9. PARTICIPANTES
       ======================================================== */

    EXEC dbo.sp_CrearParticipante

        @IdUsuarioProceso = @IdAdministrador,

        @IdDeporte = @IdDeporte,

        @Nombre = 'Concurrente A ' + @Codigo,

        @TipoParticipante = 'EQUIPO',

        @IdPais = @IdPais,

        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_CrearParticipante

        @IdUsuarioProceso = @IdAdministrador,

        @IdDeporte = @IdDeporte,

        @Nombre = 'Concurrente B ' + @Codigo,

        @TipoParticipante = 'EQUIPO',

        @IdPais = @IdPais,

        @IpOrigen = '127.0.0.1';


    DECLARE @IdParticipanteA INT;
    DECLARE @IdParticipanteB INT;


    SELECT @IdParticipanteA = IdParticipante
    FROM dbo.Participante
    WHERE Nombre = 'Concurrente A ' + @Codigo;


    SELECT @IdParticipanteB = IdParticipante
    FROM dbo.Participante
    WHERE Nombre = 'Concurrente B ' + @Codigo;


    /* ========================================================
       10. EVENTO
       ======================================================== */

    DECLARE @NombreEvento VARCHAR(200) =
        'Concurrencia A vs B ' + @Codigo;


    DECLARE @FechaInicio DATETIME2 =
        DATEADD(DAY, 1, SYSDATETIME());


    EXEC dbo.sp_CrearEvento

        @IdUsuarioProceso = @IdAdministrador,

        @IdLiga = @IdLiga,

        @Nombre = @NombreEvento,

        @FechaInicio = @FechaInicio,

        @FechaFin = DATEADD(HOUR, 2, @FechaInicio),

        @IpOrigen = '127.0.0.1';


    DECLARE @IdEvento INT;


    SELECT @IdEvento = IdEvento
    FROM dbo.Evento
    WHERE Nombre = @NombreEvento;


    EXEC dbo.sp_AgregarParticipanteEvento

        @IdUsuarioProceso = @IdAdministrador,

        @IdEvento = @IdEvento,

        @IdParticipante = @IdParticipanteA,

        @OrdenParticipante = 1,

        @EsLocal = 1,

        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_AgregarParticipanteEvento

        @IdUsuarioProceso = @IdAdministrador,

        @IdEvento = @IdEvento,

        @IdParticipante = @IdParticipanteB,

        @OrdenParticipante = 2,

        @EsLocal = 0,

        @IpOrigen = '127.0.0.1';


    /* ========================================================
       11. MERCADO
       ======================================================== */

    DECLARE @NombreMercado VARCHAR(150) =
        'Ganador Concurrencia ' + @Codigo;


    EXEC dbo.sp_CrearMercado

        @IdUsuarioProceso = @IdAdministrador,

        @IdEvento = @IdEvento,

        @Nombre = @NombreMercado,

        @Descripcion = 'Mercado para prueba simultánea.',

        @IpOrigen = '127.0.0.1';


    DECLARE @IdMercado INT;


    SELECT @IdMercado = IdMercado
    FROM dbo.Mercado
    WHERE IdEvento = @IdEvento
      AND Nombre = @NombreMercado;


    /* ========================================================
       12. SELECCIONES
       ======================================================== */

    EXEC dbo.sp_CrearSeleccion

        @IdUsuarioProceso = @IdAdministrador,

        @IdMercado = @IdMercado,

        @Nombre = 'Equipo A',

        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_CrearSeleccion

        @IdUsuarioProceso = @IdAdministrador,

        @IdMercado = @IdMercado,

        @Nombre = 'Equipo B',

        @IpOrigen = '127.0.0.1';


    DECLARE @IdSeleccionA INT;
    DECLARE @IdSeleccionB INT;


    SELECT @IdSeleccionA = IdSeleccion
    FROM dbo.Seleccion
    WHERE IdMercado = @IdMercado
      AND Nombre = 'Equipo A';


    SELECT @IdSeleccionB = IdSeleccion
    FROM dbo.Seleccion
    WHERE IdMercado = @IdMercado
      AND Nombre = 'Equipo B';


    /* ========================================================
       13. CUOTAS
       ======================================================== */

    EXEC dbo.sp_RegistrarCuota

        @IdUsuarioProceso = @IdAdministrador,

        @IdSeleccion = @IdSeleccionA,

        @Valor = 2.0000,

        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_RegistrarCuota

        @IdUsuarioProceso = @IdAdministrador,

        @IdSeleccion = @IdSeleccionB,

        @Valor = 1.8000,

        @IpOrigen = '127.0.0.1';


    /* ========================================================
       14. PUBLICAR EVENTO Y MERCADO
       ======================================================== */

    EXEC dbo.sp_CambiarEstadoEvento

        @IdUsuarioProceso = @IdAdministrador,

        @IdEvento = @IdEvento,

        @NuevoEstado = 'PROGRAMADO',

        @Motivo = 'Prueba de concurrencia.',

        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_CambiarEstadoMercado

        @IdUsuarioProceso = @IdAdministrador,

        @IdMercado = @IdMercado,

        @NuevoEstado = 'ABIERTO',

        @Motivo = 'Prueba de concurrencia.',

        @IpOrigen = '127.0.0.1';


    /* ========================================================
       15. GUARDAR CONTEXTO COMPARTIDO
       ======================================================== */

    INSERT INTO dbo.PruebaConcurrenciaContexto
    (
        IdContexto,
        CodigoPrueba,
        IdAdministrador,
        IdUsuarioPrueba,
        IdBilleteraUsuario,
        IdBilleteraCasa,
        IdEvento,
        IdMercado,
        IdSeleccionA,
        IdSeleccionB,
        ReferenciaA,
        ReferenciaB,
        MontoApuesta,
        CuotaSeleccionA,
        SaldoInicialUsuario,
        EstadoPrueba
    )
    VALUES
    (
        1,
        @Codigo,
        @IdAdministrador,
        @IdUsuario,
        @IdBilleteraUsuario,
        @IdBilleteraCasa,
        @IdEvento,
        @IdMercado,
        @IdSeleccionA,
        @IdSeleccionB,
        NEWID(),
        NEWID(),
        400.00,
        2.0000,
        500.00,
        'LISTO_APUESTAS'
    );


    COMMIT TRANSACTION;


    PRINT '';
    PRINT '=======================================================';
    PRINT ' ESCENARIO PREPARADO CORRECTAMENTE';
    PRINT '=======================================================';
    PRINT '';
    PRINT 'Saldo usuario: Q500';
    PRINT 'Cada sesión intentará apostar: Q400';
    PRINT '';
    PRINT 'SIGUIENTE:';
    PRINT 'Abrir 02_SesionA_Apuesta.sql';
    PRINT 'Abrir 03_SesionB_Apuesta.sql';
    PRINT 'Ejecutarlos casi simultáneamente.';


    SELECT *
    FROM dbo.PruebaConcurrenciaContexto;

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT ERROR_MESSAGE();

    THROW;

END CATCH;
GO