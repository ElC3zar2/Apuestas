/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   07_PRUEBAS/05_PruebaApuestas.sql

   OBJETIVO:
   Probar:
   - sp_CotizarApuesta
   - sp_RealizarApuesta
   - sp_ObtenerBoleto
   - Descuento de SaldoDisponible
   - Aumento de SaldoComprometido
   - Registro financiero de APUESTA
   - Idempotencia por ReferenciaOperacion

   TODA LA PRUEBA TERMINA CON ROLLBACK.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


BEGIN TRY

    BEGIN TRANSACTION;


    PRINT '=======================================================';
    PRINT ' PRUEBA DE APUESTAS';
    PRINT '=======================================================';


    /* ========================================================
       1. LOCALIZAR ADMINISTRADOR ACTIVO
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
        THROW 70301, 'No existe un ADMINISTRADOR ACTIVO.', 1;


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
      AND M.Activo = 1
      AND D.Activo = 1
    ORDER BY M.IdMunicipio;


    SELECT @IdDeporte = IdDeporte
    FROM dbo.Deporte
    WHERE Nombre = 'Futbol'
      AND Activo = 1;


    IF @IdPais IS NULL
       OR @IdMunicipio IS NULL
       OR @IdDeporte IS NULL
        THROW 70302, 'Faltan catálogos necesarios para la prueba.', 1;


    DECLARE @Codigo VARCHAR(20) =
        LEFT
        (
            REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
            12
        );
    DECLARE @NombreParticipanteA VARCHAR(150) =
    CONCAT('Apuesta Equipo A ', @Codigo);

    DECLARE @NombreParticipanteB VARCHAR(150) =
        CONCAT('Apuesta Equipo B ', @Codigo);

    DECLARE @NombreMercado VARCHAR(150) =
        CONCAT('Ganador prueba ', @Codigo);


    /* ========================================================
       3. CREAR USUARIO TEMPORAL
       ======================================================== */

    DECLARE @Correo VARCHAR(150) =
        CONCAT('apuesta.', @Codigo, '@apuestas.test');


    DECLARE @Documento VARCHAR(50) =
        CONCAT('AP-', @Codigo);


    EXEC dbo.sp_RegistrarUsuarioCliente

        @Nombre = 'Usuario',
        @Apellido = 'Apuesta',

        @Correo = @Correo,

        @Contrasena =
            '$2a$12$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ123456',

        @FechaNacimiento = '2000-01-01',

        @Genero = 'M',

        @Telefono = '55550100',

        @TipoDocumento = 'DPI',

        @NumeroDocumento = @Documento,

        @IdPais = @IdPais,

        @IdMunicipio = @IdMunicipio,

        @CiudadExterior = NULL,

        @Direccion = 'Dirección temporal prueba apuesta';


    DECLARE @IdUsuario INT;


    SELECT @IdUsuario = IdUsuario
    FROM dbo.Usuario
    WHERE Correo = @Correo;


    IF @IdUsuario IS NULL
        THROW 70303, 'No se creó el usuario temporal.', 1;


    /* ========================================================
       4. HABILITAR USUARIO PARA APOSTAR

       Esta sección prepara el fixture de prueba.
       Las pruebas completas de seguridad/administración
       corresponden a otros scripts.
       ======================================================== */

    DECLARE @IdEstadoVerificacionAprobada INT;


    SELECT @IdEstadoVerificacionAprobada = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'VERIFICACION'
      AND E.Codigo = 'APROBADA';


    UPDATE dbo.Usuario
    SET CorreoVerificado = 1
    WHERE IdUsuario = @IdUsuario;


    UPDATE dbo.VerificacionUsuario
    SET
        IdEstado = @IdEstadoVerificacionAprobada,
        IdUsuarioRevisor = @IdAdministrador,
        FechaInicioRevision = SYSDATETIME(),
        FechaResolucion = SYSDATETIME()
    WHERE IdUsuario = @IdUsuario;


    EXEC dbo.sp_SincronizarHabilitacionUsuario
        @IdUsuario = @IdUsuario;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario AS U
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado
        WHERE U.IdUsuario = @IdUsuario
          AND E.Codigo = 'ACTIVO'
          AND U.CorreoVerificado = 1
    )
        THROW 70304, 'El usuario no quedó ACTIVO.', 1;


    /* ========================================================
       5. CREAR LIGA Y PARTICIPANTES
       ======================================================== */

    DECLARE @NombreLiga VARCHAR(150) =
        CONCAT('Liga Apuesta ', @Codigo);


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


    EXEC dbo.sp_CrearParticipante
    @IdUsuarioProceso = @IdAdministrador,
    @IdDeporte = @IdDeporte,
    @Nombre = @NombreParticipanteA,
    @TipoParticipante = 'EQUIPO',
    @IdPais = @IdPais,
    @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_CrearParticipante
        @IdUsuarioProceso = @IdAdministrador,
        @IdDeporte = @IdDeporte,
        @Nombre = @NombreParticipanteB,
        @TipoParticipante = 'EQUIPO',
        @IdPais = @IdPais,
        @IpOrigen = '127.0.0.1';


    DECLARE @IdParticipante1 INT;
    DECLARE @IdParticipante2 INT;


    SELECT @IdParticipante1 = IdParticipante
    FROM dbo.Participante
    WHERE Nombre = @NombreParticipanteA;


    SELECT @IdParticipante2 = IdParticipante
    FROM dbo.Participante
    WHERE Nombre = @NombreParticipanteB;


    /* ========================================================
        6. CREAR EVENTO
        ======================================================== */

        DECLARE @NombreEvento VARCHAR(200) =
            CONCAT('Prueba apuesta A vs B ', @Codigo);


        DECLARE @FechaInicio DATETIME2 =
            DATEADD(DAY, 1, SYSDATETIME());


        DECLARE @FechaFin DATETIME2 =
            DATEADD(HOUR, 2, @FechaInicio);


        EXEC dbo.sp_CrearEvento
            @IdUsuarioProceso = @IdAdministrador,
            @IdLiga = @IdLiga,
            @Nombre = @NombreEvento,
            @FechaInicio = @FechaInicio,
            @FechaFin = @FechaFin,
            @IpOrigen = '127.0.0.1';


        DECLARE @IdEvento INT;


        SELECT @IdEvento = IdEvento
        FROM dbo.Evento
        WHERE Nombre = @NombreEvento;


        IF @IdEvento IS NULL
            THROW 70318,
                'No se creó correctamente el evento de prueba.',
                1;


        /* ========================================================
        AGREGAR PARTICIPANTES AL EVENTO
        ======================================================== */

        EXEC dbo.sp_AgregarParticipanteEvento
            @IdUsuarioProceso = @IdAdministrador,
            @IdEvento = @IdEvento,
            @IdParticipante = @IdParticipante1,
            @OrdenParticipante = 1,
            @EsLocal = 1,
            @IpOrigen = '127.0.0.1';


        EXEC dbo.sp_AgregarParticipanteEvento
            @IdUsuarioProceso = @IdAdministrador,
            @IdEvento = @IdEvento,
            @IdParticipante = @IdParticipante2,
            @OrdenParticipante = 2,
            @EsLocal = 0,
            @IpOrigen = '127.0.0.1';


        /* ========================================================
        7. CREAR MERCADO Y SELECCIONES
        ======================================================== */

        EXEC dbo.sp_CrearMercado
            @IdUsuarioProceso = @IdAdministrador,
            @IdEvento = @IdEvento,
            @Nombre = @NombreMercado,
            @Descripcion = 'Mercado temporal prueba apuestas.',
            @IpOrigen = '127.0.0.1';


        DECLARE @IdMercado INT;


        SELECT @IdMercado = IdMercado
        FROM dbo.Mercado
        WHERE IdEvento = @IdEvento
        AND Nombre = @NombreMercado;


        IF @IdMercado IS NULL
            THROW 70319,
                'No se creó correctamente el mercado de prueba.',
                1;


        /* ========================================================
        CREAR SELECCIONES
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


        IF @IdSeleccionA IS NULL
        OR @IdSeleccionB IS NULL
            THROW 70320,
                'No se crearon correctamente las selecciones de prueba.',
                1;


    /* ========================================================
       8. CUOTAS
       ======================================================== */

    EXEC dbo.sp_RegistrarCuota
        @IdUsuarioProceso = @IdAdministrador,
        @IdSeleccion = @IdSeleccionA,
        @Valor = 1.8500,
        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_RegistrarCuota
        @IdUsuarioProceso = @IdAdministrador,
        @IdSeleccion = @IdSeleccionB,
        @Valor = 2.1000,
        @IpOrigen = '127.0.0.1';


    /* ========================================================
       9. PUBLICAR EVENTO Y MERCADO
       ======================================================== */

    EXEC dbo.sp_CambiarEstadoEvento
        @IdUsuarioProceso = @IdAdministrador,
        @IdEvento = @IdEvento,
        @NuevoEstado = 'PROGRAMADO',
        @Motivo = 'Prueba de apuesta.',
        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_CambiarEstadoMercado
        @IdUsuarioProceso = @IdAdministrador,
        @IdMercado = @IdMercado,
        @NuevoEstado = 'ABIERTO',
        @Motivo = 'Prueba de apuesta.',
        @IpOrigen = '127.0.0.1';


    /* ========================================================
       10. PREPARAR APUESTA
       ======================================================== */

    DECLARE @SaldoInicial DECIMAL(12,2);
    DECLARE @SaldoComprometidoInicial DECIMAL(12,2);


    SELECT
        @SaldoInicial = SaldoDisponible,
        @SaldoComprometidoInicial = SaldoComprometido
    FROM dbo.Billetera
    WHERE IdUsuario = @IdUsuario;


    DECLARE @MontoMinimo DECIMAL(12,2);


    SELECT @MontoMinimo =
        TRY_CONVERT(DECIMAL(12,2), Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'MONTO_MINIMO_APUESTA';


    DECLARE @Monto DECIMAL(12,2);


    SET @Monto =
        CASE
            WHEN @SaldoInicial >= 100.00
                THEN 100.00
            ELSE @SaldoInicial
        END;


    IF @Monto < @MontoMinimo
        THROW 70305, 'El saldo inicial no permite ejecutar la prueba de apuesta.', 1;


    DECLARE @SeleccionesJson NVARCHAR(MAX);


    SET @SeleccionesJson =
        N'['
        + CONVERT(NVARCHAR(20), @IdSeleccionA)
        + N']';


    /* ========================================================
       11. COTIZAR
       ======================================================== */

    PRINT '';
    PRINT '1. COTIZACION';


    EXEC dbo.sp_CotizarApuesta

        @SeleccionesJson = @SeleccionesJson,

        @Monto = @Monto;


    /* ========================================================
       12. REALIZAR APUESTA
       ======================================================== */

    DECLARE @Referencia UNIQUEIDENTIFIER =
        NEWID();


    PRINT '';
    PRINT '2. REALIZAR APUESTA';


    EXEC dbo.sp_RealizarApuesta

        @IdUsuario = @IdUsuario,

        @SeleccionesJson = @SeleccionesJson,

        @Monto = @Monto,

        @ReferenciaOperacion = @Referencia,

        @IpOrigen = '127.0.0.1';


    DECLARE @IdBoleto INT;


    SELECT @IdBoleto = IdBoleto
    FROM dbo.Boleto
    WHERE ReferenciaOperacion = @Referencia;


    IF @IdBoleto IS NULL
        THROW 70306, 'No se creó el boleto.', 1;


    /* ========================================================
       13. VALIDAR BOLETO
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Boleto
        WHERE IdBoleto = @IdBoleto
          AND IdUsuario = @IdUsuario
          AND MontoApostado = @Monto
          AND TipoBoleto = 'SIMPLE'
          AND Resultado = 'PENDIENTE'
    )
        THROW 70307, 'Los datos del boleto no son correctos.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.DetalleBoleto
        WHERE IdBoleto = @IdBoleto
          AND IdSeleccion = @IdSeleccionA
          AND CuotaAplicada = 1.8500
          AND Resultado = 'PENDIENTE'
    )
        THROW 70308, 'El detalle del boleto no fue creado correctamente.', 1;


    PRINT 'Boleto y detalle: OK';


    /* ========================================================
       14. VALIDAR BILLETERA
       ======================================================== */

    DECLARE @DisponiblePosterior DECIMAL(12,2);
    DECLARE @ComprometidoPosterior DECIMAL(12,2);


    SELECT
        @DisponiblePosterior = SaldoDisponible,
        @ComprometidoPosterior = SaldoComprometido
    FROM dbo.Billetera
    WHERE IdUsuario = @IdUsuario;


    IF @DisponiblePosterior <> @SaldoInicial - @Monto
        THROW 70309, 'SaldoDisponible no disminuyó correctamente.', 1;


    IF @ComprometidoPosterior <>
       @SaldoComprometidoInicial + @Monto
        THROW 70310, 'SaldoComprometido no aumentó correctamente.', 1;


    PRINT 'Saldo disponible y comprometido: OK';


    /* ========================================================
       15. VALIDAR TRANSACCION APUESTA
       ======================================================== */

    DECLARE @IdTransaccionApuesta BIGINT;


    SELECT @IdTransaccionApuesta = TF.IdTransaccion
    FROM dbo.TransaccionFinanciera AS TF
    INNER JOIN dbo.TipoTransaccion AS TT
        ON TT.IdTipoTransaccion = TF.IdTipoTransaccion
    WHERE TF.ReferenciaOperacion = @Referencia
      AND TT.Codigo = 'APUESTA'
      AND TF.IdBoleto = @IdBoleto;


    IF @IdTransaccionApuesta IS NULL
        THROW 70311, 'No existe la transacción financiera APUESTA.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.MovimientoBilletera
        WHERE IdTransaccion = @IdTransaccionApuesta
          AND SaldoDisponibleAnterior = @SaldoInicial
          AND SaldoDisponiblePosterior = @SaldoInicial - @Monto
          AND SaldoComprometidoAnterior = @SaldoComprometidoInicial
          AND SaldoComprometidoPosterior =
              @SaldoComprometidoInicial + @Monto
    )
        THROW 70312, 'MovimientoBilletera de APUESTA incorrecto.', 1;


    PRINT 'Transacción APUESTA y movimiento: OK';


    /* ========================================================
       16. PROBAR IDEMPOTENCIA

       Reutilizar la MISMA ReferenciaOperacion no debe:
       - crear otro boleto;
       - crear otra transacción;
       - descontar saldo nuevamente.
       ======================================================== */

    PRINT '';
    PRINT '3. PRUEBA DE IDEMPOTENCIA';


    EXEC dbo.sp_RealizarApuesta

        @IdUsuario = @IdUsuario,

        @SeleccionesJson = @SeleccionesJson,

        @Monto = @Monto,

        @ReferenciaOperacion = @Referencia,

        @IpOrigen = '127.0.0.1';


    IF
    (
        SELECT COUNT(*)
        FROM dbo.Boleto
        WHERE ReferenciaOperacion = @Referencia
    ) <> 1
        THROW 70313, 'La idempotencia creó más de un boleto.', 1;


    IF
    (
        SELECT COUNT(*)
        FROM dbo.TransaccionFinanciera
        WHERE ReferenciaOperacion = @Referencia
    ) <> 1
        THROW 70314, 'La idempotencia creó más de una transacción.', 1;


    IF EXISTS
    (
        SELECT 1
        FROM dbo.Billetera
        WHERE IdUsuario = @IdUsuario
          AND
          (
              SaldoDisponible <> @DisponiblePosterior
              OR SaldoComprometido <> @ComprometidoPosterior
          )
    )
        THROW 70315, 'La repetición idempotente modificó la billetera.', 1;


    PRINT 'Idempotencia: OK';


    /* ========================================================
       17. CONSULTAR BOLETO
       ======================================================== */

    PRINT '';
    PRINT '4. CONSULTA DEL BOLETO';


    EXEC dbo.sp_ObtenerBoleto

        @IdUsuarioSolicitante = @IdUsuario,

        @IdBoleto = @IdBoleto,

        @CodigoBoleto = NULL;


    /* ========================================================
       18. VERIFICAR VISTAS
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.vw_BoletosUsuario
        WHERE IdBoleto = @IdBoleto
          AND IdUsuario = @IdUsuario
    )
        THROW 70316, 'El boleto no aparece en vw_BoletosUsuario.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.vw_DetalleBoletos
        WHERE IdBoleto = @IdBoleto
          AND IdSeleccion = @IdSeleccionA
    )
        THROW 70317, 'El detalle no aparece en vw_DetalleBoletos.', 1;


    /* ========================================================
       RESULTADO FINAL
       ======================================================== */

    PRINT '';
    PRINT '=======================================================';
    PRINT ' RESULTADO: PRUEBA DE APUESTAS CORRECTA';
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
    PRINT ' ERROR EN PRUEBA DE APUESTAS';
    PRINT '=======================================================';

    PRINT ERROR_MESSAGE();

    THROW;

END CATCH;
GO