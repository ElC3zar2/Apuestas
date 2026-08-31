/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   07_PRUEBAS/03_PruebaBilletera.sql

   OBJETIVO:
   Probar:
   - sp_ObtenerBilleteraUsuario
   - sp_ObtenerMovimientosBilletera
   - sp_AjustarSaldoVirtual

   IMPORTANTE:
   Toda la prueba termina con ROLLBACK.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


BEGIN TRY

    BEGIN TRANSACTION;


    PRINT '=======================================================';
    PRINT ' PRUEBA DE BILLETERA';
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
        THROW 70101, 'No existe un ADMINISTRADOR ACTIVO.', 1;


    PRINT 'Administrador encontrado: '
        + CONVERT(VARCHAR(20), @IdAdministrador);


    /* ========================================================
       2. CREAR USUARIO TEMPORAL
       ======================================================== */

    DECLARE @IdPaisGuatemala INT;
    DECLARE @IdMunicipioGuatemala INT;


    SELECT @IdPaisGuatemala = IdPais
    FROM dbo.Pais
    WHERE CodigoISO2 = 'GT'
      AND Activo = 1;


    SELECT TOP (1)
        @IdMunicipioGuatemala = M.IdMunicipio

    FROM dbo.Municipio AS M

    INNER JOIN dbo.Departamento AS D
        ON D.IdDepartamento = M.IdDepartamento

    WHERE D.IdPais = @IdPaisGuatemala
      AND M.Activo = 1
      AND D.Activo = 1

    ORDER BY M.IdMunicipio;


    IF @IdPaisGuatemala IS NULL
       OR @IdMunicipioGuatemala IS NULL
        THROW 70102, 'No existe la geografía mínima requerida para la prueba.', 1;


    DECLARE @Identificador VARCHAR(32) =
        REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', '');


    DECLARE @Correo VARCHAR(150) =
        CONCAT
        (
            'billetera.',
            LEFT(@Identificador, 12),
            '@apuestas.test'
        );


    DECLARE @Documento VARCHAR(50) =
        CONCAT
        (
            'BILL-',
            LEFT(@Identificador, 20)
        );


    DECLARE @Registro TABLE
    (
        IdUsuario INT,
        IdVerificacion INT,
        IdBilletera INT,
        IdTransaccion BIGINT NULL,
        ReferenciaOperacion UNIQUEIDENTIFIER,
        SaldoInicial DECIMAL(12,2),
        EstadoUsuario VARCHAR(40),
        EstadoVerificacion VARCHAR(40),
        CorreoVerificado BIT
    );


    INSERT INTO @Registro
    EXEC dbo.sp_RegistrarUsuarioCliente

        @Nombre = 'Prueba',
        @Apellido = 'Billetera',

        @Correo = @Correo,

        @Contrasena =
            '$2a$12$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ123456',

        @FechaNacimiento = '2000-01-01',

        @Genero = 'M',

        @Telefono = '55550001',

        @TipoDocumento = 'DPI',

        @NumeroDocumento = @Documento,

        @IdPais = @IdPaisGuatemala,

        @IdMunicipio = @IdMunicipioGuatemala,

        @CiudadExterior = NULL,

        @Direccion = 'Dirección temporal prueba billetera';


    DECLARE @IdUsuario INT;
    DECLARE @IdBilletera INT;
    DECLARE @SaldoInicial DECIMAL(12,2);


    SELECT
        @IdUsuario = IdUsuario,
        @IdBilletera = IdBilletera,
        @SaldoInicial = SaldoInicial
    FROM @Registro;


    IF @IdUsuario IS NULL
        THROW 70103, 'No se creó el usuario temporal.', 1;


    PRINT '';
    PRINT 'Usuario temporal creado: '
        + CONVERT(VARCHAR(20), @IdUsuario);


    /* ========================================================
       3. CONSULTAR BILLETERA
       ======================================================== */

    PRINT '';
    PRINT '1. CONSULTA INICIAL DE BILLETERA';


    EXEC dbo.sp_ObtenerBilleteraUsuario
        @IdUsuario = @IdUsuario;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Billetera
        WHERE IdBilletera = @IdBilletera
          AND SaldoDisponible = @SaldoInicial
          AND SaldoComprometido = 0
    )
        THROW 70104, 'La billetera inicial no contiene los valores esperados.', 1;


    /* ========================================================
       4. CREDITO ADMINISTRATIVO
       ======================================================== */

    DECLARE @MontoCredito DECIMAL(12,2) = 100.00;

    DECLARE @ReferenciaCredito UNIQUEIDENTIFIER =
        NEWID();


    PRINT '';
    PRINT '2. APLICAR CREDITO ADMINISTRATIVO';


    EXEC dbo.sp_AjustarSaldoVirtual

        @IdUsuarioObjetivo = @IdUsuario,

        @IdUsuarioProceso = @IdAdministrador,

        @Operacion = 'CREDITO',

        @Monto = @MontoCredito,

        @Motivo = 'Prueba automática de crédito virtual.',

        @ReferenciaOperacion = @ReferenciaCredito,

        @IpOrigen = '127.0.0.1';


    DECLARE @SaldoDespuesCredito DECIMAL(12,2);


    SELECT @SaldoDespuesCredito = SaldoDisponible
    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilletera;


    IF @SaldoDespuesCredito <> @SaldoInicial + @MontoCredito
        THROW 70105, 'El crédito administrativo no actualizó correctamente el saldo.', 1;


    PRINT 'Saldo después de crédito: '
        + CONVERT(VARCHAR(30), @SaldoDespuesCredito);


    /* ========================================================
       5. PROBAR IDEMPOTENCIA DEL CREDITO
       ======================================================== */

    PRINT '';
    PRINT '3. REPETIR MISMA REFERENCIA - IDEMPOTENCIA';


    EXEC dbo.sp_AjustarSaldoVirtual

        @IdUsuarioObjetivo = @IdUsuario,

        @IdUsuarioProceso = @IdAdministrador,

        @Operacion = 'CREDITO',

        @Monto = @MontoCredito,

        @Motivo = 'Prueba automática de crédito virtual.',

        @ReferenciaOperacion = @ReferenciaCredito,

        @IpOrigen = '127.0.0.1';


    DECLARE @SaldoDespuesReintento DECIMAL(12,2);


    SELECT @SaldoDespuesReintento = SaldoDisponible
    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilletera;


    IF @SaldoDespuesReintento <> @SaldoDespuesCredito
        THROW 70106, 'La idempotencia falló: el crédito se aplicó dos veces.', 1;


    PRINT 'OK: la misma referencia no volvió a acreditar saldo.';


    /* ========================================================
       6. DEBITO ADMINISTRATIVO
       ======================================================== */

    DECLARE @MontoDebito DECIMAL(12,2) = 40.00;

    DECLARE @ReferenciaDebito UNIQUEIDENTIFIER =
        NEWID();


    PRINT '';
    PRINT '4. APLICAR DEBITO ADMINISTRATIVO';


    EXEC dbo.sp_AjustarSaldoVirtual

        @IdUsuarioObjetivo = @IdUsuario,

        @IdUsuarioProceso = @IdAdministrador,

        @Operacion = 'DEBITO',

        @Monto = @MontoDebito,

        @Motivo = 'Prueba automática de débito virtual.',

        @ReferenciaOperacion = @ReferenciaDebito,

        @IpOrigen = '127.0.0.1';


    DECLARE @SaldoFinal DECIMAL(12,2);


    SELECT @SaldoFinal = SaldoDisponible
    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilletera;


    IF @SaldoFinal <>
       @SaldoInicial + @MontoCredito - @MontoDebito
        THROW 70107, 'El débito administrativo no actualizó correctamente el saldo.', 1;


    PRINT 'Saldo final esperado: '
        + CONVERT
          (
              VARCHAR(30),
              @SaldoInicial + @MontoCredito - @MontoDebito
          );

    PRINT 'Saldo final obtenido: '
        + CONVERT(VARCHAR(30), @SaldoFinal);


    /* ========================================================
       7. SALDO COMPROMETIDO NO DEBE CAMBIAR
       ======================================================== */

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Billetera
        WHERE IdBilletera = @IdBilletera
          AND SaldoComprometido <> 0
    )
        THROW 70108, 'Un ajuste administrativo modificó indebidamente SaldoComprometido.', 1;


    PRINT '';
    PRINT '5. OK: SaldoComprometido permanece en cero.';


    /* ========================================================
       8. VERIFICAR TRANSACCIONES Y MOVIMIENTOS
       ======================================================== */

    DECLARE @CantidadAjustes INT;
    DECLARE @CantidadMovimientos INT;


    SELECT @CantidadAjustes = COUNT(*)

    FROM dbo.TransaccionFinanciera AS TF

    INNER JOIN dbo.TipoTransaccion AS TT
        ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

    WHERE TF.IdBilletera = @IdBilletera
      AND TT.Codigo = 'AJUSTE_ADMIN';


    SELECT @CantidadMovimientos = COUNT(*)

    FROM dbo.MovimientoBilletera AS MB

    INNER JOIN dbo.TransaccionFinanciera AS TF
        ON TF.IdTransaccion = MB.IdTransaccion

    INNER JOIN dbo.TipoTransaccion AS TT
        ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

    WHERE MB.IdBilletera = @IdBilletera
      AND TT.Codigo = 'AJUSTE_ADMIN';


    IF @CantidadAjustes <> 2
        THROW 70109, 'Se esperaban exactamente 2 transacciones AJUSTE_ADMIN.', 1;


    IF @CantidadMovimientos <> 2
        THROW 70110, 'Se esperaban exactamente 2 movimientos de ajuste.', 1;


    PRINT '';
    PRINT '6. TRANSACCIONES AJUSTE_ADMIN: '
        + CONVERT(VARCHAR(10), @CantidadAjustes);

    PRINT 'MOVIMIENTOS AJUSTE_ADMIN: '
        + CONVERT(VARCHAR(10), @CantidadMovimientos);


    /* ========================================================
       9. CONSULTAR HISTORIAL POR PROCEDIMIENTO
       ======================================================== */

    PRINT '';
    PRINT '7. HISTORIAL DE MOVIMIENTOS';


    EXEC dbo.sp_ObtenerMovimientosBilletera

        @IdUsuario = @IdUsuario,

        @Cantidad = 20;


    /* ========================================================
       10. VERIFICAR AUDITORIA
       ======================================================== */

    IF
    (
        SELECT COUNT(*)
        FROM dbo.Auditoria
        WHERE IdUsuario = @IdAdministrador
          AND TablaAfectada = 'Billetera'
          AND IdRegistro = @IdBilletera
          AND Accion IN
              (
                  'AJUSTE_SALDO_CREDITO',
                  'AJUSTE_SALDO_DEBITO'
              )
    ) <> 2
        THROW 70111, 'No se generaron correctamente las auditorías de ajustes.', 1;


    PRINT '';
    PRINT '8. OK: auditoría de crédito y débito encontrada.';


    /* ========================================================
       RESULTADO FINAL
       ======================================================== */

    PRINT '';
    PRINT '=======================================================';
    PRINT ' RESULTADO: PRUEBA DE BILLETERA CORRECTA';
    PRINT '=======================================================';


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
    PRINT ' ERROR EN PRUEBA DE BILLETERA';
    PRINT '=======================================================';

    PRINT ERROR_MESSAGE();

    THROW;

END CATCH;
GO