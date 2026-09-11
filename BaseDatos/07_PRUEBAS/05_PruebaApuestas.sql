/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   07_PRUEBAS/05_PruebaApuestas.sql

   OBJETIVO:
    Probar:
    - sp_CotizarApuesta
    - sp_RealizarApuesta
    - sp_ObtenerBoleto
    - Registro de boleto SIMPLE
    - Persistencia de ComisionServicio
    - Calculo de TotalCargo
    - Descuento de SaldoDisponible
    - Aumento de SaldoComprometido
    - Registro financiero de APUESTA
    - Cobro de COMISION_SERVICIO al usuario
    - Acreditacion de COMISION_SERVICIO a CASA
    - Movimientos de billetera asociados
    - Idempotencia completa por ReferenciaOperacion
    - Lectura mediante vistas operativas

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


    IF @SaldoInicial IS NULL
        THROW 70321,
            'No se pudo obtener la billetera inicial del usuario.',
            1;


    /* ========================================================
    CONFIGURACION DE APUESTA
    ======================================================== */

    DECLARE @MontoMinimo DECIMAL(12,2);


    SELECT @MontoMinimo =
        TRY_CONVERT(DECIMAL(12,2), Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'MONTO_MINIMO_APUESTA';


    IF @MontoMinimo IS NULL
    OR @MontoMinimo <= 0
        THROW 70322,
            'MONTO_MINIMO_APUESTA no contiene un valor válido.',
            1;


    DECLARE @ComisionPorcentaje DECIMAL(7,4);


    SELECT @ComisionPorcentaje =
        TRY_CONVERT(DECIMAL(7,4), Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'COMISION_SERVICIO_PORCENTAJE';


    IF @ComisionPorcentaje IS NULL
    OR @ComisionPorcentaje < 0
    OR @ComisionPorcentaje > 100
        THROW 70323,
            'COMISION_SERVICIO_PORCENTAJE no contiene un valor válido.',
            1;


    /* ========================================================
    MONTO DE PRUEBA
    ======================================================== */

    DECLARE @Monto DECIMAL(12,2);


    SET @Monto =
        CASE
            WHEN @MontoMinimo > 100.00
                THEN @MontoMinimo
            ELSE 100.00
        END;


    /* ========================================================
    CALCULAR COMISION ESPERADA

    Debe utilizar la misma fórmula de sp_CotizarApuesta
    y sp_RealizarApuesta.
    ======================================================== */

    DECLARE @ComisionCalculo DECIMAL(38,4) =
        CONVERT(DECIMAL(38,4), @Monto)
        * CONVERT(DECIMAL(38,4), @ComisionPorcentaje)
        / 100;


    DECLARE @ComisionEsperada DECIMAL(12,2) =
        CONVERT
        (
            DECIMAL(12,2),
            ROUND(@ComisionCalculo, 2)
        );


    DECLARE @TotalCargoEsperado DECIMAL(12,2) =
        CONVERT
        (
            DECIMAL(12,2),
            @Monto + @ComisionEsperada
        );


    IF @SaldoInicial < @TotalCargoEsperado
        THROW 70324,
            'El saldo inicial no permite cubrir la apuesta y la comisión de servicio.',
            1;


    /* ========================================================
    CAPTURAR SALDO INICIAL DE CASA

    Se utilizará después para comprobar que la comisión
    fue acreditada correctamente.
    ======================================================== */

    DECLARE @CantidadCuentasCasa INT;


    SELECT @CantidadCuentasCasa = COUNT(*)
    FROM dbo.Usuario AS UC

    INNER JOIN dbo.Rol AS RC
        ON RC.IdRol = UC.IdRol
    AND RC.Nombre = 'CASA'

    INNER JOIN dbo.Estado AS EC
        ON EC.IdEstado = UC.IdEstado

    INNER JOIN dbo.TipoEstado AS TEC
        ON TEC.IdTipoEstado = EC.IdTipoEstado
    AND TEC.Codigo = 'USUARIO'

    INNER JOIN dbo.Billetera AS BC
        ON BC.IdUsuario = UC.IdUsuario

    WHERE EC.Codigo = 'ACTIVO';


    IF @CantidadCuentasCasa <> 1
        THROW 70325,
            'Debe existir exactamente una cuenta CASA activa con billetera.',
            1;


    DECLARE @IdUsuarioCasa INT;
    DECLARE @IdBilleteraCasa INT;
    DECLARE @SaldoCasaInicial DECIMAL(12,2);
    DECLARE @SaldoComprometidoCasaInicial DECIMAL(12,2);


    SELECT
        @IdUsuarioCasa = UC.IdUsuario,
        @IdBilleteraCasa = BC.IdBilletera,
        @SaldoCasaInicial = BC.SaldoDisponible,
        @SaldoComprometidoCasaInicial = BC.SaldoComprometido
    FROM dbo.Usuario AS UC

    INNER JOIN dbo.Rol AS RC
        ON RC.IdRol = UC.IdRol
    AND RC.Nombre = 'CASA'

    INNER JOIN dbo.Estado AS EC
        ON EC.IdEstado = UC.IdEstado

    INNER JOIN dbo.TipoEstado AS TEC
        ON TEC.IdTipoEstado = EC.IdTipoEstado
    AND TEC.Codigo = 'USUARIO'

    INNER JOIN dbo.Billetera AS BC
        ON BC.IdUsuario = UC.IdUsuario

    WHERE EC.Codigo = 'ACTIVO';


    IF @IdBilleteraCasa IS NULL
    OR @SaldoCasaInicial IS NULL
        THROW 70326,
            'No se pudo obtener la billetera inicial de CASA.',
            1;


    /* ========================================================
    SELECCION PARA LA APUESTA SIMPLE
    ======================================================== */

    DECLARE @SeleccionesJson NVARCHAR(MAX);


    SET @SeleccionesJson =
        N'['
        + CONVERT(NVARCHAR(20), @IdSeleccionA)
        + N']';


    PRINT '';
    PRINT 'Monto apostado: '
        + CONVERT(VARCHAR(30), @Monto);

    PRINT 'Comision esperada: '
        + CONVERT(VARCHAR(30), @ComisionEsperada);

    PRINT 'Total cargo esperado: '
        + CONVERT(VARCHAR(30), @TotalCargoEsperado);


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
        AND ComisionServicio = @ComisionEsperada
        AND TipoBoleto = 'SIMPLE'
        AND Resultado = 'PENDIENTE'
    )
        THROW 70327,
            'Los datos principales del boleto no son correctos.',
            1;


    /* ========================================================
    VALIDAR TOTAL COBRADO DEL BOLETO
    ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Boleto
        WHERE IdBoleto = @IdBoleto
        AND MontoApostado + ComisionServicio =
            @TotalCargoEsperado
    )
        THROW 70328,
            'El total de apuesta más comisión no coincide con el cargo esperado.',
            1;


    /* ========================================================
    VALIDAR CUOTA Y GANANCIA POTENCIAL
    ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Boleto
        WHERE IdBoleto = @IdBoleto
        AND CuotaTotal = 1.8500
        AND GananciaPotencial =
            CONVERT
            (
                DECIMAL(12,2),
                ROUND
                (
                    CONVERT(DECIMAL(38,4), @Monto)
                    * CONVERT(DECIMAL(38,4), 1.8500),
                    2
                )
            )
    )
        THROW 70329,
            'La cuota total o la ganancia potencial del boleto es incorrecta.',
            1;


    /* ========================================================
    VALIDAR DETALLE DEL BOLETO
    ======================================================== */

    IF
    (
        SELECT COUNT(*)
        FROM dbo.DetalleBoleto
        WHERE IdBoleto = @IdBoleto
    ) <> 1
        THROW 70330,
            'El boleto SIMPLE debe contener exactamente un detalle.',
            1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.DetalleBoleto
        WHERE IdBoleto = @IdBoleto
        AND IdSeleccion = @IdSeleccionA
        AND CuotaAplicada = 1.8500
        AND Resultado = 'PENDIENTE'
    )
        THROW 70331,
            'El detalle del boleto no fue creado correctamente.',
            1;


    PRINT 'Boleto, comisión, cuota y detalle: OK';


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


    /* ========================================================
    VALIDAR SALDO DISPONIBLE DEL USUARIO

    Debe disminuir por:
    - monto apostado;
    - comisión de servicio.
    ======================================================== */

    IF @DisponiblePosterior <>
    @SaldoInicial - @TotalCargoEsperado
        THROW 70332,
            'SaldoDisponible no disminuyó por apuesta más comisión.',
            1;


    /* ========================================================
    VALIDAR SALDO COMPROMETIDO DEL USUARIO

    Solo el monto apostado queda comprometido.
    La comisión NO forma parte del saldo comprometido.
    ======================================================== */

    IF @ComprometidoPosterior <>
    @SaldoComprometidoInicial + @Monto
        THROW 70333,
            'SaldoComprometido no aumentó únicamente por el monto apostado.',
            1;


    /* ========================================================
    VALIDAR SALDO DE CASA

    La comisión debe acreditarse inmediatamente
    al SaldoDisponible de CASA.
    ======================================================== */

    DECLARE @SaldoCasaPosterior DECIMAL(12,2);
    DECLARE @SaldoComprometidoCasaPosterior DECIMAL(12,2);


    SELECT
        @SaldoCasaPosterior = SaldoDisponible,
        @SaldoComprometidoCasaPosterior = SaldoComprometido
    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilleteraCasa;


    IF @SaldoCasaPosterior <>
    @SaldoCasaInicial + @ComisionEsperada
        THROW 70334,
            'CASA no recibió correctamente la comisión de servicio.',
            1;


    /* ========================================================
    LA COMISION NO DEBE ALTERAR EL SALDO COMPROMETIDO DE CASA
    ======================================================== */

    IF @SaldoComprometidoCasaPosterior <>
    @SaldoComprometidoCasaInicial
        THROW 70335,
            'La comisión modificó incorrectamente el saldo comprometido de CASA.',
            1;


    PRINT 'Billetera usuario y comisión acreditada a CASA: OK';


    /* ========================================================
    15. VALIDAR TRANSACCIONES FINANCIERAS
    ======================================================== */

    DECLARE @IdBilleteraUsuario INT;


    SELECT @IdBilleteraUsuario = IdBilletera
    FROM dbo.Billetera
    WHERE IdUsuario = @IdUsuario;


    IF @IdBilleteraUsuario IS NULL
        THROW 70336,
            'No se pudo identificar la billetera del usuario.',
            1;


    /* ========================================================
    15.1 TRANSACCION APUESTA
    ======================================================== */

    DECLARE @IdTransaccionApuesta BIGINT;


    SELECT @IdTransaccionApuesta = TF.IdTransaccion
    FROM dbo.TransaccionFinanciera AS TF

    INNER JOIN dbo.TipoTransaccion AS TT
        ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

    WHERE TF.ReferenciaOperacion = @Referencia
    AND TF.IdBoleto = @IdBoleto
    AND TF.IdBilletera = @IdBilleteraUsuario
    AND TF.Monto = @Monto
    AND TT.Codigo = 'APUESTA';


    IF @IdTransaccionApuesta IS NULL
        THROW 70337,
            'No existe la transacción financiera APUESTA correcta.',
            1;


    /* ========================================================
    VALIDAR MOVIMIENTO DE LA APUESTA

    En este movimiento solamente se trasladan los fondos
    apostados desde disponible hacia comprometido.
    La comisión se cobra en un movimiento separado.
    ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.MovimientoBilletera
        WHERE IdBilletera = @IdBilleteraUsuario
        AND IdTransaccion = @IdTransaccionApuesta
        AND SaldoDisponibleAnterior = @SaldoInicial
        AND SaldoDisponiblePosterior =
            @SaldoInicial - @Monto
        AND SaldoComprometidoAnterior =
            @SaldoComprometidoInicial
        AND SaldoComprometidoPosterior =
            @SaldoComprometidoInicial + @Monto
    )
        THROW 70338,
            'MovimientoBilletera de APUESTA incorrecto.',
            1;


    PRINT 'Transacción APUESTA y movimiento: OK';


    /* ========================================================
    15.2 COMISION DE SERVICIO

    Si la configuración produce una comisión mayor que cero,
    deben existir exactamente:

    1. Una transacción que cobra la comisión al usuario.
    2. Una transacción que acredita la comisión a CASA.
    ======================================================== */

    DECLARE @IdTransaccionComisionUsuario BIGINT = NULL;
    DECLARE @IdTransaccionComisionCasa BIGINT = NULL;


    IF @ComisionEsperada > 0
    BEGIN

        /* ====================================================
        COMISION COBRADA AL USUARIO
        ==================================================== */

        IF
        (
            SELECT COUNT(*)
            FROM dbo.TransaccionFinanciera AS TF

            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

            WHERE TF.IdBoleto = @IdBoleto
            AND TF.IdBilletera = @IdBilleteraUsuario
            AND TF.Monto = @ComisionEsperada
            AND TT.Codigo = 'COMISION_SERVICIO'
        ) <> 1
            THROW 70339,
                'Debe existir exactamente una comisión de servicio cobrada al usuario.',
                1;


        SELECT @IdTransaccionComisionUsuario = TF.IdTransaccion
        FROM dbo.TransaccionFinanciera AS TF

        INNER JOIN dbo.TipoTransaccion AS TT
            ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

        WHERE TF.IdBoleto = @IdBoleto
        AND TF.IdBilletera = @IdBilleteraUsuario
        AND TF.Monto = @ComisionEsperada
        AND TT.Codigo = 'COMISION_SERVICIO';


        /* ====================================================
        MOVIMIENTO DE COMISION DEL USUARIO
        ==================================================== */

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.MovimientoBilletera
            WHERE IdBilletera = @IdBilleteraUsuario
            AND IdTransaccion = @IdTransaccionComisionUsuario
            AND SaldoDisponibleAnterior =
                @SaldoInicial - @Monto
            AND SaldoDisponiblePosterior =
                @SaldoInicial - @TotalCargoEsperado
            AND SaldoComprometidoAnterior =
                @SaldoComprometidoInicial + @Monto
            AND SaldoComprometidoPosterior =
                @SaldoComprometidoInicial + @Monto
        )
            THROW 70340,
                'MovimientoBilletera de comisión del usuario incorrecto.',
                1;


        PRINT 'Cobro de comisión al usuario: OK';


        /* ====================================================
        COMISION ACREDITADA A CASA
        ==================================================== */

        IF
        (
            SELECT COUNT(*)
            FROM dbo.TransaccionFinanciera AS TF

            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

            WHERE TF.IdBoleto = @IdBoleto
            AND TF.IdBilletera = @IdBilleteraCasa
            AND TF.Monto = @ComisionEsperada
            AND TT.Codigo = 'COMISION_SERVICIO'
        ) <> 1
            THROW 70341,
                'Debe existir exactamente una comisión de servicio acreditada a CASA.',
                1;


        SELECT @IdTransaccionComisionCasa = TF.IdTransaccion
        FROM dbo.TransaccionFinanciera AS TF

        INNER JOIN dbo.TipoTransaccion AS TT
            ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

        WHERE TF.IdBoleto = @IdBoleto
        AND TF.IdBilletera = @IdBilleteraCasa
        AND TF.Monto = @ComisionEsperada
        AND TT.Codigo = 'COMISION_SERVICIO';


        /* ====================================================
        MOVIMIENTO DE COMISION DE CASA
        ==================================================== */

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.MovimientoBilletera
            WHERE IdBilletera = @IdBilleteraCasa
            AND IdTransaccion = @IdTransaccionComisionCasa
            AND SaldoDisponibleAnterior =
                @SaldoCasaInicial
            AND SaldoDisponiblePosterior =
                @SaldoCasaInicial + @ComisionEsperada
            AND SaldoComprometidoAnterior =
                @SaldoComprometidoCasaInicial
            AND SaldoComprometidoPosterior =
                @SaldoComprometidoCasaInicial
        )
            THROW 70342,
                'MovimientoBilletera de comisión acreditada a CASA incorrecto.',
                1;


        PRINT 'Acreditación de comisión a CASA: OK';

    END
    ELSE
    BEGIN

        /* ====================================================
        SI LA COMISION CONFIGURADA ES CERO

        No deben existir movimientos COMISION_SERVICIO
        asociados al boleto.
        ==================================================== */

        IF EXISTS
        (
            SELECT 1
            FROM dbo.TransaccionFinanciera AS TF

            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

            WHERE TF.IdBoleto = @IdBoleto
            AND TT.Codigo = 'COMISION_SERVICIO'
        )
            THROW 70343,
                'Se registraron comisiones aunque la comisión esperada es cero.',
                1;

    END;


    PRINT 'Transacciones financieras de apuesta y comisión: OK';


    /* ========================================================
    16. PROBAR IDEMPOTENCIA

    Reutilizar la MISMA ReferenciaOperacion no debe:
    - crear otro boleto;
    - crear otra transacción APUESTA;
    - volver a cobrar comisión;
    - volver a acreditar comisión a CASA;
    - crear nuevos movimientos de billetera;
    - modificar nuevamente los saldos.
    ======================================================== */

    PRINT '';
    PRINT '3. PRUEBA DE IDEMPOTENCIA';


    /* ========================================================
    CAPTURAR ESTADO ANTES DE REPETIR LA SOLICITUD
    ======================================================== */

    DECLARE @CantidadBoletosAntes INT;
    DECLARE @CantidadTransaccionesAntes INT;
    DECLARE @CantidadMovimientosAntes INT;

    DECLARE @SaldoUsuarioAntesIdempotencia DECIMAL(12,2);
    DECLARE @ComprometidoUsuarioAntesIdempotencia DECIMAL(12,2);

    DECLARE @SaldoCasaAntesIdempotencia DECIMAL(12,2);
    DECLARE @ComprometidoCasaAntesIdempotencia DECIMAL(12,2);


    SELECT @CantidadBoletosAntes = COUNT(*)
    FROM dbo.Boleto
    WHERE ReferenciaOperacion = @Referencia;


    SELECT @CantidadTransaccionesAntes = COUNT(*)
    FROM dbo.TransaccionFinanciera
    WHERE IdBoleto = @IdBoleto;


    SELECT @CantidadMovimientosAntes = COUNT(*)
    FROM dbo.MovimientoBilletera AS MB

    INNER JOIN dbo.TransaccionFinanciera AS TF
        ON TF.IdTransaccion = MB.IdTransaccion

    WHERE TF.IdBoleto = @IdBoleto;


    SELECT
        @SaldoUsuarioAntesIdempotencia = SaldoDisponible,
        @ComprometidoUsuarioAntesIdempotencia = SaldoComprometido
    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilleteraUsuario;


    SELECT
        @SaldoCasaAntesIdempotencia = SaldoDisponible,
        @ComprometidoCasaAntesIdempotencia = SaldoComprometido
    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilleteraCasa;


    /* ========================================================
    REPETIR EXACTAMENTE LA MISMA OPERACION
    ======================================================== */

    EXEC dbo.sp_RealizarApuesta

        @IdUsuario = @IdUsuario,

        @SeleccionesJson = @SeleccionesJson,

        @Monto = @Monto,

        @ReferenciaOperacion = @Referencia,

        @IpOrigen = '127.0.0.1';


    /* ========================================================
    16.1 NO DEBE CREARSE OTRO BOLETO
    ======================================================== */

    IF
    (
        SELECT COUNT(*)
        FROM dbo.Boleto
        WHERE ReferenciaOperacion = @Referencia
    ) <> @CantidadBoletosAntes
        THROW 70344,
            'La operación idempotente creó un boleto adicional.',
            1;


    IF @CantidadBoletosAntes <> 1
        THROW 70345,
            'La referencia de prueba no identifica exactamente un boleto.',
            1;


    /* ========================================================
    16.2 LA REFERENCIA PRINCIPAL SIGUE PERTENECIENDO
            A UNA SOLA TRANSACCION APUESTA
    ======================================================== */

    IF
    (
        SELECT COUNT(*)
        FROM dbo.TransaccionFinanciera AS TF

        INNER JOIN dbo.TipoTransaccion AS TT
            ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

        WHERE TF.ReferenciaOperacion = @Referencia
        AND TF.IdBoleto = @IdBoleto
        AND TT.Codigo = 'APUESTA'
    ) <> 1
        THROW 70346,
            'La idempotencia alteró la transacción principal APUESTA.',
            1;


    /* ========================================================
    16.3 NO DEBEN CREARSE TRANSACCIONES ADICIONALES

    Incluye:
    - APUESTA
    - COMISION_SERVICIO usuario
    - COMISION_SERVICIO CASA
    ======================================================== */

    IF
    (
        SELECT COUNT(*)
        FROM dbo.TransaccionFinanciera
        WHERE IdBoleto = @IdBoleto
    ) <> @CantidadTransaccionesAntes
        THROW 70347,
            'La repetición idempotente creó transacciones financieras adicionales.',
            1;


    /* ========================================================
    16.4 NO DEBEN CREARSE MOVIMIENTOS ADICIONALES
    ======================================================== */

    IF
    (
        SELECT COUNT(*)
        FROM dbo.MovimientoBilletera AS MB

        INNER JOIN dbo.TransaccionFinanciera AS TF
            ON TF.IdTransaccion = MB.IdTransaccion

        WHERE TF.IdBoleto = @IdBoleto
    ) <> @CantidadMovimientosAntes
        THROW 70348,
            'La repetición idempotente creó movimientos de billetera adicionales.',
            1;


    /* ========================================================
    16.5 LA BILLETERA DEL USUARIO NO DEBE CAMBIAR
    ======================================================== */

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Billetera
        WHERE IdBilletera = @IdBilleteraUsuario
        AND
        (
            SaldoDisponible <>
                @SaldoUsuarioAntesIdempotencia

            OR SaldoComprometido <>
                @ComprometidoUsuarioAntesIdempotencia
        )
    )
        THROW 70349,
            'La repetición idempotente modificó nuevamente la billetera del usuario.',
            1;


    /* ========================================================
    16.6 LA BILLETERA DE CASA TAMPOCO DEBE CAMBIAR
    ======================================================== */

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Billetera
        WHERE IdBilletera = @IdBilleteraCasa
        AND
        (
            SaldoDisponible <>
                @SaldoCasaAntesIdempotencia

            OR SaldoComprometido <>
                @ComprometidoCasaAntesIdempotencia
        )
    )
        THROW 70350,
            'La repetición idempotente acreditó nuevamente fondos a CASA.',
            1;


    /* ========================================================
    16.7 VALIDAR QUE NO SE DUPLICO LA COMISION
    ======================================================== */

    IF @ComisionEsperada > 0
    BEGIN

        IF
        (
            SELECT COUNT(*)
            FROM dbo.TransaccionFinanciera AS TF

            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

            WHERE TF.IdBoleto = @IdBoleto
            AND TF.IdBilletera = @IdBilleteraUsuario
            AND TT.Codigo = 'COMISION_SERVICIO'
        ) <> 1
            THROW 70351,
                'La idempotencia duplicó la comisión cobrada al usuario.',
                1;


        IF
        (
            SELECT COUNT(*)
            FROM dbo.TransaccionFinanciera AS TF

            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

            WHERE TF.IdBoleto = @IdBoleto
            AND TF.IdBilletera = @IdBilleteraCasa
            AND TT.Codigo = 'COMISION_SERVICIO'
        ) <> 1
            THROW 70352,
                'La idempotencia duplicó la comisión acreditada a CASA.',
                1;

    END;


    PRINT 'Idempotencia completa de boleto, apuesta y comisión: OK';


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


    /* ========================================================
    18.1 BOLETO EN VISTA DE USUARIO
    ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.vw_BoletosUsuario
        WHERE IdBoleto = @IdBoleto
        AND IdUsuario = @IdUsuario
        AND MontoApostado = @Monto
        AND TipoBoleto = 'SIMPLE'
        AND Resultado = 'PENDIENTE'
    )
        THROW 70353,
            'El boleto no aparece correctamente en vw_BoletosUsuario.',
            1;


    /* ========================================================
    18.2 DETALLE DEL BOLETO
    ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.vw_DetalleBoletos
        WHERE IdBoleto = @IdBoleto
        AND IdSeleccion = @IdSeleccionA
        AND CuotaAplicada = 1.8500
        AND ResultadoDetalle = 'PENDIENTE'
    )
        THROW 70354,
            'El detalle no aparece correctamente en vw_DetalleBoletos.',
            1;


    /* ========================================================
    18.3 MOVIMIENTO DE APUESTA DEL USUARIO
    ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.vw_HistorialMovimientos
        WHERE IdUsuario = @IdUsuario
        AND IdBoleto = @IdBoleto
        AND TipoTransaccion = 'APUESTA'
        AND Monto = @Monto
        AND VariacionDisponible = -@Monto
        AND VariacionComprometido = @Monto
    )
        THROW 70355,
            'La transacción APUESTA no aparece correctamente en vw_HistorialMovimientos.',
            1;


    /* ========================================================
    18.4 MOVIMIENTOS DE COMISION
    ======================================================== */

    IF @ComisionEsperada > 0
    BEGIN

        /* Comisión cobrada al usuario. */

        IF
        (
            SELECT COUNT(*)
            FROM dbo.vw_HistorialMovimientos
            WHERE IdUsuario = @IdUsuario
            AND IdBoleto = @IdBoleto
            AND TipoTransaccion = 'COMISION_SERVICIO'
            AND Monto = @ComisionEsperada
            AND VariacionDisponible = -@ComisionEsperada
            AND VariacionComprometido = 0
        ) <> 1
            THROW 70356,
                'La comisión del usuario no aparece correctamente en vw_HistorialMovimientos.',
                1;


        /* Comisión acreditada a CASA. */

        IF
        (
            SELECT COUNT(*)
            FROM dbo.vw_HistorialMovimientos
            WHERE IdUsuario = @IdUsuarioCasa
            AND IdBoleto = @IdBoleto
            AND TipoTransaccion = 'COMISION_SERVICIO'
            AND Monto = @ComisionEsperada
            AND VariacionDisponible = @ComisionEsperada
            AND VariacionComprometido = 0
        ) <> 1
            THROW 70357,
                'La comisión acreditada a CASA no aparece correctamente en vw_HistorialMovimientos.',
                1;

    END
    ELSE
    BEGIN

        IF EXISTS
        (
            SELECT 1
            FROM dbo.vw_HistorialMovimientos
            WHERE IdBoleto = @IdBoleto
            AND TipoTransaccion = 'COMISION_SERVICIO'
        )
            THROW 70358,
                'Existen movimientos de comisión aunque la comisión esperada es cero.',
                1;

    END;


    PRINT 'Vistas de boleto, detalle y movimientos financieros: OK';


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