/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   07_PRUEBAS/06_PruebaResultadosLiquidacion.sql

   OBJETIVO:
   Probar el ciclo completo:

   EVENTO
      ↓
   APUESTAS
      ↓
   RESULTADO
      ↓
   RESOLUCION DE SELECCIONES
      ↓
   OFICIALIZACION
      ↓
   LIQUIDACION
      ↓
   USUARIO + CASA

   ESCENARIO:
   - Usuario A apuesta a selección A.
   - Usuario B apuesta a selección B.
   - Selección A = GANADA.
   - Selección B = PERDIDA.
   - Usuario A debe cobrar.
   - Usuario B debe perder su apuesta.
   - CASA paga ganancia neta al ganador.
   - CASA recibe apuesta del perdedor.

   TODA LA PRUEBA TERMINA CON ROLLBACK.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


BEGIN TRY

    BEGIN TRANSACTION;


    PRINT '=======================================================';
    PRINT ' PRUEBA DE RESULTADOS Y LIQUIDACION';
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
        THROW 70401, 'No existe ADMINISTRADOR ACTIVO.', 1;


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
        THROW 70402, 'Faltan catálogos requeridos.', 1;


    DECLARE @Codigo VARCHAR(20) =
        LEFT
        (
            REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
            12
        );
    DECLARE @DocumentoGanador VARCHAR(50) =
        CONCAT('GAN-', @Codigo);

    DECLARE @DocumentoPerdedor VARCHAR(50) =
        CONCAT('PER-', @Codigo);

    DECLARE @NombreParticipanteA VARCHAR(150) =
        CONCAT('Liquidación Equipo A ', @Codigo);

    DECLARE @NombreParticipanteB VARCHAR(150) =
        CONCAT('Liquidación Equipo B ', @Codigo);

    DECLARE @NombreMercado VARCHAR(150) =
        CONCAT('Ganador liquidación ', @Codigo);


    /* ========================================================
       3. CREAR DOS USUARIOS
       ======================================================== */

    DECLARE @CorreoA VARCHAR(150) =
        CONCAT('ganador.', @Codigo, '@apuestas.test');

    DECLARE @CorreoB VARCHAR(150) =
        CONCAT('perdedor.', @Codigo, '@apuestas.test');


    EXEC dbo.sp_RegistrarUsuarioCliente
        @Nombre = 'Usuario',
        @Apellido = 'Ganador',
        @Correo = @CorreoA,
        @Contrasena =
            '$2a$12$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ123456',
        @FechaNacimiento = '2000-01-01',
        @Genero = 'M',
        @Telefono = '55550201',
        @TipoDocumento = 'DPI',
        @NumeroDocumento = @DocumentoGanador,
        @IdPais = @IdPais,
        @IdMunicipio = @IdMunicipio,
        @CiudadExterior = NULL,
        @Direccion = 'Dirección prueba ganador';


    EXEC dbo.sp_RegistrarUsuarioCliente
        @Nombre = 'Usuario',
        @Apellido = 'Perdedor',
        @Correo = @CorreoB,
        @Contrasena =
            '$2a$12$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ123456',
        @FechaNacimiento = '2000-01-01',
        @Genero = 'M',
        @Telefono = '55550202',
        @TipoDocumento = 'DPI',
        @NumeroDocumento = @DocumentoPerdedor,
        @IdPais = @IdPais,
        @IdMunicipio = @IdMunicipio,
        @CiudadExterior = NULL,
        @Direccion = 'Dirección prueba perdedor';


    DECLARE @IdUsuarioA INT;
    DECLARE @IdUsuarioB INT;


    SELECT @IdUsuarioA = IdUsuario
    FROM dbo.Usuario
    WHERE Correo = @CorreoA;


    SELECT @IdUsuarioB = IdUsuario
    FROM dbo.Usuario
    WHERE Correo = @CorreoB;


    IF @IdUsuarioA IS NULL OR @IdUsuarioB IS NULL
        THROW 70403, 'No se crearon los usuarios de prueba.', 1;


    /* ========================================================
       4. HABILITAR AMBOS USUARIOS
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
    WHERE IdUsuario IN (@IdUsuarioA, @IdUsuarioB);


    UPDATE dbo.VerificacionUsuario
    SET
        IdEstado = @IdEstadoVerificacionAprobada,
        IdUsuarioRevisor = @IdAdministrador,
        FechaInicioRevision = SYSDATETIME(),
        FechaResolucion = SYSDATETIME()
    WHERE IdUsuario IN (@IdUsuarioA, @IdUsuarioB);


    EXEC dbo.sp_SincronizarHabilitacionUsuario
        @IdUsuario = @IdUsuarioA;


    EXEC dbo.sp_SincronizarHabilitacionUsuario
        @IdUsuario = @IdUsuarioB;


    /* ========================================================
       5. CREAR ESTRUCTURA DEPORTIVA
       ======================================================== */

    DECLARE @NombreLiga VARCHAR(150) =
        'Liga Liquidación ' + @Codigo;


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


    DECLARE @IdParticipanteA INT;
    DECLARE @IdParticipanteB INT;


    SELECT @IdParticipanteA = IdParticipante
    FROM dbo.Participante
    WHERE Nombre = @NombreParticipanteA

    SELECT @IdParticipanteB = IdParticipante
    FROM dbo.Participante
    WHERE Nombre = @NombreParticipanteB


    DECLARE @NombreEvento VARCHAR(200) =
        'Liquidación A vs B ' + @Codigo;
    
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
       6. MERCADO + SELECCIONES + CUOTAS
       ======================================================== */

    EXEC dbo.sp_CrearMercado
        @IdUsuarioProceso = @IdAdministrador,
        @IdEvento = @IdEvento,
        @Nombre = @NombreMercado,
        @Descripcion = 'Prueba resultado y liquidación.',
        @IpOrigen = '127.0.0.1';


    DECLARE @IdMercado INT;


    SELECT @IdMercado = IdMercado
    FROM dbo.Mercado
    WHERE IdEvento = @IdEvento;


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


    EXEC dbo.sp_CambiarEstadoEvento
        @IdUsuarioProceso = @IdAdministrador,
        @IdEvento = @IdEvento,
        @NuevoEstado = 'PROGRAMADO',
        @Motivo = 'Prueba liquidación.',
        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_CambiarEstadoMercado
        @IdUsuarioProceso = @IdAdministrador,
        @IdMercado = @IdMercado,
        @NuevoEstado = 'ABIERTO',
        @Motivo = 'Prueba liquidación.',
        @IpOrigen = '127.0.0.1';


    /* ========================================================
       7. SALDOS INICIALES
       ======================================================== */

    DECLARE @SaldoInicialA DECIMAL(12,2);
    DECLARE @SaldoInicialB DECIMAL(12,2);


    SELECT @SaldoInicialA = SaldoDisponible
    FROM dbo.Billetera
    WHERE IdUsuario = @IdUsuarioA;


    SELECT @SaldoInicialB = SaldoDisponible
    FROM dbo.Billetera
    WHERE IdUsuario = @IdUsuarioB;


    DECLARE @IdBilleteraCasa INT;
    DECLARE @SaldoCasaInicial DECIMAL(12,2);


    SELECT
        @IdBilleteraCasa = B.IdBilletera,
        @SaldoCasaInicial = B.SaldoDisponible

    FROM dbo.Billetera AS B

    INNER JOIN dbo.Usuario AS U
        ON U.IdUsuario = B.IdUsuario

    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
       AND R.Nombre = 'CASA';


    IF @SaldoCasaInicial IS NULL
        THROW 70404, 'No se encontró la billetera CASA.', 1;


    DECLARE @Monto DECIMAL(12,2) = 100.00;


    IF @SaldoInicialA < @Monto OR @SaldoInicialB < @Monto
        THROW 70405, 'Los usuarios no poseen saldo suficiente para la prueba.', 1;


    /* ========================================================
       8. DOS APUESTAS OPUESTAS
       ======================================================== */

    DECLARE @JsonA NVARCHAR(MAX) =
        N'[' + CONVERT(NVARCHAR(20), @IdSeleccionA) + N']';


    DECLARE @JsonB NVARCHAR(MAX) =
        N'[' + CONVERT(NVARCHAR(20), @IdSeleccionB) + N']';


    DECLARE @ReferenciaA UNIQUEIDENTIFIER = NEWID();
    DECLARE @ReferenciaB UNIQUEIDENTIFIER = NEWID();


    EXEC dbo.sp_RealizarApuesta
        @IdUsuario = @IdUsuarioA,
        @SeleccionesJson = @JsonA,
        @Monto = @Monto,
        @ReferenciaOperacion = @ReferenciaA,
        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_RealizarApuesta
        @IdUsuario = @IdUsuarioB,
        @SeleccionesJson = @JsonB,
        @Monto = @Monto,
        @ReferenciaOperacion = @ReferenciaB,
        @IpOrigen = '127.0.0.1';


    DECLARE @IdBoletoA INT;
    DECLARE @IdBoletoB INT;


    SELECT @IdBoletoA = IdBoleto
    FROM dbo.Boleto
    WHERE ReferenciaOperacion = @ReferenciaA;


    SELECT @IdBoletoB = IdBoleto
    FROM dbo.Boleto
    WHERE ReferenciaOperacion = @ReferenciaB;


    IF @IdBoletoA IS NULL OR @IdBoletoB IS NULL
        THROW 70406, 'No se crearon los dos boletos.', 1;


    /* Ambos deben tener Q100 comprometidos. */

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Billetera
        WHERE IdUsuario IN (@IdUsuarioA, @IdUsuarioB)
          AND SaldoComprometido <> @Monto
    )
        THROW 70407, 'El saldo comprometido previo a liquidación es incorrecto.', 1;


    PRINT '';
    PRINT 'Dos apuestas registradas: OK';


    /* ========================================================
       9. EVENTO EN VIVO
       ======================================================== */

    EXEC dbo.sp_CambiarEstadoEvento
        @IdUsuarioProceso = @IdAdministrador,
        @IdEvento = @IdEvento,
        @NuevoEstado = 'EN_VIVO',
        @Motivo = 'Inicio simulado del evento.',
        @IpOrigen = '127.0.0.1';


    /* ========================================================
       10. CERRAR MERCADO
       ======================================================== */

    EXEC dbo.sp_CambiarEstadoMercado
        @IdUsuarioProceso = @IdAdministrador,
        @IdMercado = @IdMercado,
        @NuevoEstado = 'CERRADO',
        @Motivo = 'Evento finalizado para prueba.',
        @IpOrigen = '127.0.0.1';


    /* ========================================================
       11. EVENTO -> PENDIENTE_RESULTADO
       ======================================================== */

    EXEC dbo.sp_CambiarEstadoEvento
        @IdUsuarioProceso = @IdAdministrador,
        @IdEvento = @IdEvento,
        @NuevoEstado = 'PENDIENTE_RESULTADO',
        @Motivo = 'Esperando resultado oficial.',
        @IpOrigen = '127.0.0.1';


    /* ========================================================
       12. REGISTRAR RESULTADO
       ======================================================== */

    EXEC dbo.sp_RegistrarResultadoEvento
        @IdUsuarioProceso = @IdAdministrador,
        @IdEvento = @IdEvento,
        @ResultadoTexto = 'Equipo A 2 - 1 Equipo B',
        @Observacion = 'Resultado prueba automática.',
        @IpOrigen = '127.0.0.1';


    DECLARE @IdResultadoEvento INT;


    SELECT @IdResultadoEvento = IdResultado
    FROM dbo.ResultadoEvento
    WHERE IdEvento = @IdEvento;


    IF @IdResultadoEvento IS NULL
        THROW 70408, 'No se creó ResultadoEvento.', 1;


    /* ========================================================
       13. RESOLVER SELECCIONES
       ======================================================== */

    EXEC dbo.sp_ResolverSeleccion
        @IdUsuarioProceso = @IdAdministrador,
        @IdResultadoEvento = @IdResultadoEvento,
        @IdSeleccion = @IdSeleccionA,
        @Resultado = 'GANADA',
        @Observacion = 'Equipo A ganó.',
        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_ResolverSeleccion
        @IdUsuarioProceso = @IdAdministrador,
        @IdResultadoEvento = @IdResultadoEvento,
        @IdSeleccion = @IdSeleccionB,
        @Resultado = 'PERDIDA',
        @Observacion = 'Equipo B perdió.',
        @IpOrigen = '127.0.0.1';


    /* ========================================================
       14. OFICIALIZAR RESULTADO
       ======================================================== */

    EXEC dbo.sp_OficializarResultadoEvento
        @IdUsuarioProceso = @IdAdministrador,
        @IdResultadoEvento = @IdResultadoEvento,
        @Observacion = 'Resultado oficial de prueba.',
        @IpOrigen = '127.0.0.1';


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ResultadoEvento AS RE
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = RE.IdEstado
        WHERE RE.IdResultado = @IdResultadoEvento
          AND E.Codigo = 'OFICIAL'
    )
        THROW 70409, 'El resultado no quedó OFICIAL.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.DetalleBoleto
        WHERE IdBoleto = @IdBoletoA
          AND Resultado = 'GANADA'
    )
        THROW 70410, 'El detalle ganador no fue propagado.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.DetalleBoleto
        WHERE IdBoleto = @IdBoletoB
          AND Resultado = 'PERDIDA'
    )
        THROW 70411, 'El detalle perdedor no fue propagado.', 1;


    PRINT 'Resultado y resoluciones: OK';


    /* ========================================================
       15. BOLETOS LISTOS
       ======================================================== */

    EXEC dbo.sp_ObtenerBoletosListosLiquidar
        @IdUsuarioProceso = @IdAdministrador,
        @Cantidad = 100;


    /* ========================================================
       16. LIQUIDAR GANADOR
       ======================================================== */

    EXEC dbo.sp_LiquidarBoleto
        @IdUsuarioProceso = @IdAdministrador,
        @IdBoleto = @IdBoletoA,
        @IpOrigen = '127.0.0.1';


    /* ========================================================
       17. LIQUIDAR PERDEDOR
       ======================================================== */

    EXEC dbo.sp_LiquidarBoleto
        @IdUsuarioProceso = @IdAdministrador,
        @IdBoleto = @IdBoletoB,
        @IpOrigen = '127.0.0.1';


    /* ========================================================
       18. VALIDAR BOLETOS
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Boleto
        WHERE IdBoleto = @IdBoletoA
          AND Resultado = 'GANADOR'
          AND FechaLiquidacion IS NOT NULL
    )
        THROW 70412, 'El boleto A no quedó GANADOR.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Boleto
        WHERE IdBoleto = @IdBoletoB
          AND Resultado = 'PERDEDOR'
          AND FechaLiquidacion IS NOT NULL
    )
        THROW 70413, 'El boleto B no quedó PERDEDOR.', 1;


    /* ========================================================
       19. VALIDAR SALDO GANADOR

       Cuota A = 1.85
       Apuesta = 100
       Pago = 185
       Ganancia neta = 85
       ======================================================== */

    DECLARE @SaldoFinalA DECIMAL(12,2);
    DECLARE @ComprometidoFinalA DECIMAL(12,2);


    SELECT
        @SaldoFinalA = SaldoDisponible,
        @ComprometidoFinalA = SaldoComprometido
    FROM dbo.Billetera
    WHERE IdUsuario = @IdUsuarioA;


    DECLARE @PagoEsperadoA DECIMAL(12,2) =
        ROUND(@Monto * 1.8500, 2);


    IF @SaldoFinalA <>
       @SaldoInicialA - @Monto + @PagoEsperadoA
        THROW 70414, 'El saldo del usuario ganador es incorrecto.', 1;


    IF @ComprometidoFinalA <> 0
        THROW 70415, 'El ganador conserva saldo comprometido.', 1;


    /* ========================================================
       20. VALIDAR SALDO PERDEDOR
       ======================================================== */

    DECLARE @SaldoFinalB DECIMAL(12,2);
    DECLARE @ComprometidoFinalB DECIMAL(12,2);


    SELECT
        @SaldoFinalB = SaldoDisponible,
        @ComprometidoFinalB = SaldoComprometido
    FROM dbo.Billetera
    WHERE IdUsuario = @IdUsuarioB;


    IF @SaldoFinalB <> @SaldoInicialB - @Monto
        THROW 70416, 'El saldo del usuario perdedor es incorrecto.', 1;


    IF @ComprometidoFinalB <> 0
        THROW 70417, 'El perdedor conserva saldo comprometido.', 1;


    /* ========================================================
       21. VALIDAR CASA

       CASA:
       +100 del boleto perdedor
       -85 de ganancia neta del ganador
       Resultado neto CASA = +15
       ======================================================== */

    DECLARE @SaldoCasaFinal DECIMAL(12,2);


    SELECT @SaldoCasaFinal = SaldoDisponible
    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilleteraCasa;


    DECLARE @GananciaNetaGanador DECIMAL(12,2) =
        @PagoEsperadoA - @Monto;


    DECLARE @SaldoCasaEsperado DECIMAL(12,2) =
        @SaldoCasaInicial
        + @Monto
        - @GananciaNetaGanador;


    IF @SaldoCasaFinal <> @SaldoCasaEsperado
        THROW 70418, 'El saldo final de CASA es incorrecto.', 1;


    PRINT '';
    PRINT 'Saldo ganador: OK';
    PRINT 'Saldo perdedor: OK';
    PRINT 'Saldo CASA: OK';


    /* ========================================================
       22. VALIDAR TIPOS DE TRANSACCION
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TransaccionFinanciera AS TF
        INNER JOIN dbo.TipoTransaccion AS TT
            ON TT.IdTipoTransaccion = TF.IdTipoTransaccion
        WHERE TF.IdBoleto = @IdBoletoA
          AND TT.Codigo = 'PREMIO'
    )
        THROW 70419, 'No existe PREMIO para el boleto ganador.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TransaccionFinanciera AS TF
        INNER JOIN dbo.TipoTransaccion AS TT
            ON TT.IdTipoTransaccion = TF.IdTipoTransaccion
        WHERE TF.IdBoleto = @IdBoletoA
          AND TT.Codigo = 'PAGO_PREMIO'
    )
        THROW 70420, 'No existe PAGO_PREMIO de CASA.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TransaccionFinanciera AS TF
        INNER JOIN dbo.TipoTransaccion AS TT
            ON TT.IdTipoTransaccion = TF.IdTipoTransaccion
        WHERE TF.IdBoleto = @IdBoletoB
          AND TT.Codigo = 'PERDIDA_APUESTA'
    )
        THROW 70421, 'No existe PERDIDA_APUESTA.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TransaccionFinanciera AS TF
        INNER JOIN dbo.TipoTransaccion AS TT
            ON TT.IdTipoTransaccion = TF.IdTipoTransaccion
        WHERE TF.IdBoleto = @IdBoletoB
          AND TT.Codigo = 'GANANCIA_CASA'
    )
        THROW 70422, 'No existe GANANCIA_CASA.', 1;


    PRINT 'Transacciones financieras: OK';


    /* ========================================================
       23. IDEMPOTENCIA DE LIQUIDACION
       ======================================================== */

    EXEC dbo.sp_LiquidarBoleto
        @IdUsuarioProceso = @IdAdministrador,
        @IdBoleto = @IdBoletoA,
        @IpOrigen = '127.0.0.1';


    IF
    (
        SELECT COUNT(*)
        FROM dbo.LiquidacionBoleto
        WHERE IdBoleto = @IdBoletoA
    ) <> 1
        THROW 70423, 'La liquidación idempotente creó duplicados.', 1;


    IF EXISTS
    (
        SELECT 1
        FROM dbo.Billetera
        WHERE IdUsuario = @IdUsuarioA
          AND
          (
              SaldoDisponible <> @SaldoFinalA
              OR SaldoComprometido <> 0
          )
    )
        THROW 70424, 'Repetir la liquidación modificó nuevamente el saldo.', 1;


    PRINT 'Idempotencia de liquidación: OK';


    /* ========================================================
       24. CONSULTAR LIQUIDACIONES
       ======================================================== */

    EXEC dbo.sp_ObtenerLiquidacionBoleto
        @IdUsuarioSolicitante = @IdUsuarioA,
        @IdBoleto = @IdBoletoA;


    EXEC dbo.sp_ObtenerLiquidacionBoleto
        @IdUsuarioSolicitante = @IdUsuarioB,
        @IdBoleto = @IdBoletoB;


    /* ========================================================
       RESULTADO FINAL
       ======================================================== */

    PRINT '';
    PRINT '=======================================================';
    PRINT ' RESULTADO: RESULTADOS Y LIQUIDACION CORRECTOS';
    PRINT '=======================================================';

    PRINT 'Usuario A: GANADOR';
    PRINT 'Usuario B: PERDEDOR';
    PRINT 'CASA: movimiento financiero consistente';
    PRINT 'Saldo comprometido liberado correctamente';


    ROLLBACK TRANSACTION;


    PRINT '';
    PRINT 'ROLLBACK realizado.';
    PRINT 'No quedaron datos permanentes.';


END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;


    PRINT '';
    PRINT '=======================================================';
    PRINT ' ERROR EN PRUEBA DE RESULTADOS / LIQUIDACION';
    PRINT '=======================================================';

    PRINT 'Error: '
        + CONVERT(VARCHAR(20), ERROR_NUMBER());

    PRINT 'Mensaje: '
        + ERROR_MESSAGE();

    THROW;

END CATCH;
GO