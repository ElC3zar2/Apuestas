/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   03_PROCEDIMIENTOS/05_Apuestas.sql

   OBJETIVO:
   Centralizar la cotización y el registro atómico de apuestas.

   INCLUYE:
   - Cotización de una apuesta a partir de selecciones actuales.
   - Registro de boleto SIMPLE o COMPUESTO.
   - Captura de las cuotas aplicadas al momento de apostar.
   - Movimiento de SaldoDisponible a SaldoComprometido.
   - TransaccionFinanciera de tipo APUESTA.
   - MovimientoBilletera.
   - Auditoría e idempotencia.

   CONTRATO DE SELECCIONES:
   @SeleccionesJson debe ser un arreglo JSON de IdSeleccion.

   Ejemplos:
       [15]
       [15, 27, 48]

   REGLAS PRINCIPALES:
   - Solo un usuario con rol USUARIO puede apostar.
   - La cuenta debe estar ACTIVA.
   - El correo debe estar verificado.
   - La verificación administrativa más reciente debe estar APROBADA.
   - No puede existir una restricción APOSTAR o TODAS_OPERACIONES vigente.
   - El mercado debe estar ABIERTO.
   - El evento debe estar PROGRAMADO.
   - La apuesta debe registrarse antes del cierre configurado previo al inicio del evento.
   - La selección debe estar activa.
   - Debe existir exactamente una cuota activa por selección.
   - No se permiten dos selecciones del mismo mercado.
   - 1 selección = boleto SIMPLE.
   - 2 o más selecciones = boleto COMPUESTO.
   - El monto debe cumplir MONTO_MINIMO_APUESTA.
   - El usuario no puede apostar más de SaldoDisponible.
   - @ReferenciaOperacion protege contra solicitudes duplicadas.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


/* ============================================================
   1. COTIZAR APUESTA

   Este procedimiento NO crea boleto ni modifica saldos.
   Su resultado es informativo.

   IMPORTANTE:
   La cotización mostrada al usuario puede cambiar.
   sp_RealizarApuesta vuelve a validar y capturar las cuotas
   dentro de su propia transacción.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CotizarApuesta
(
    @SeleccionesJson NVARCHAR(MAX),
    @Monto DECIMAL(12,2)
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @SeleccionesJson =
        NULLIF(LTRIM(RTRIM(@SeleccionesJson)), '');

    IF @SeleccionesJson IS NULL
        THROW 60001, 'SeleccionesJson es obligatorio.', 1;

    IF ISJSON(@SeleccionesJson) <> 1
       OR LEFT(LTRIM(@SeleccionesJson), 1) <> '['
        THROW 60002, 'SeleccionesJson debe ser un arreglo JSON válido.', 1;

    IF @Monto IS NULL OR @Monto <= 0
        THROW 60003, 'Monto debe ser mayor que cero.', 1;


    DECLARE @MontoMinimo DECIMAL(12,2);

    SELECT @MontoMinimo =
        TRY_CONVERT(DECIMAL(12,2), Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'MONTO_MINIMO_APUESTA';

    IF @MontoMinimo IS NULL OR @MontoMinimo <= 0
        THROW 60004, 'MONTO_MINIMO_APUESTA no contiene un valor válido.', 1;

    IF @Monto < @MontoMinimo
        THROW 60005, 'El monto es menor que el mínimo permitido para apostar.', 1;

    DECLARE @AnticipacionCierre INT;

    SELECT @AnticipacionCierre =
        TRY_CONVERT(INT, Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'ANTICIPACION_CIERRE_APUESTA_MIN';

    IF @AnticipacionCierre IS NULL
    OR @AnticipacionCierre < 0
        THROW 60053,
            'ANTICIPACION_CIERRE_APUESTA_MIN no contiene un valor válido.',
            1;

    /* ========================================================
    COMISION DE SERVICIO
    ======================================================== */

    DECLARE @ComisionPorcentaje DECIMAL(7,4);

    SELECT @ComisionPorcentaje =
        TRY_CONVERT(DECIMAL(7,4), Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'COMISION_SERVICIO_PORCENTAJE';


    IF @ComisionPorcentaje IS NULL
    OR @ComisionPorcentaje < 0
    OR @ComisionPorcentaje > 100
        THROW 60057,
            'COMISION_SERVICIO_PORCENTAJE no contiene un valor válido.',
            1;


    DECLARE @ComisionCalculo DECIMAL(38,4) =
        CONVERT(DECIMAL(38,4), @Monto)
        * CONVERT(DECIMAL(38,4), @ComisionPorcentaje)
        / 100;


    IF @ComisionCalculo > 9999999999.99
        THROW 60058,
            'La comisión de servicio excede el rango permitido por el sistema.',
            1;


    DECLARE @ComisionServicio DECIMAL(12,2) =
        CONVERT
        (
            DECIMAL(12,2),
            ROUND(@ComisionCalculo, 2)
        );


    DECLARE @TotalCargoCalculo DECIMAL(38,2) =
        CONVERT(DECIMAL(38,2), @Monto)
        + CONVERT(DECIMAL(38,2), @ComisionServicio);


    IF @TotalCargoCalculo > 9999999999.99
        THROW 60059,
            'El monto total de la apuesta y comisión excede el rango permitido.',
            1;


    DECLARE @TotalCargo DECIMAL(12,2) =
        CONVERT(DECIMAL(12,2), @TotalCargoCalculo);

    DECLARE @AhoraSistema DATETIME2 =
        CAST(
            SYSUTCDATETIME()
            AT TIME ZONE 'UTC'
            AT TIME ZONE 'Central America Standard Time'
            AS DATETIME2
        );

    DECLARE @Entrada TABLE
    (
        Orden INT NOT NULL,
        IdSeleccion INT NULL
    );

    INSERT INTO @Entrada
    (
        Orden,
        IdSeleccion
    )
    SELECT
        CONVERT(INT, [key]) + 1,
        TRY_CONVERT(INT, [value])
    FROM OPENJSON(@SeleccionesJson);


    IF NOT EXISTS
    (
        SELECT 1
        FROM @Entrada
    )
        THROW 60006, 'Debe indicar al menos una selección.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Entrada
        WHERE IdSeleccion IS NULL
           OR IdSeleccion <= 0
    )
        THROW 60007, 'SeleccionesJson contiene un IdSeleccion no válido.', 1;

    IF EXISTS
    (
        SELECT IdSeleccion
        FROM @Entrada
        GROUP BY IdSeleccion
        HAVING COUNT(*) > 1
    )
        THROW 60008, 'No se puede repetir una selección dentro del mismo boleto.', 1;


    DECLARE @Detalle TABLE
    (
        Orden INT NOT NULL,
        IdSeleccion INT NOT NULL,
        NombreSeleccion VARCHAR(150) NOT NULL,

        IdMercado INT NOT NULL,
        NombreMercado VARCHAR(150) NOT NULL,
        EstadoMercado VARCHAR(40) NOT NULL,

        IdEvento INT NOT NULL,
        NombreEvento VARCHAR(200) NOT NULL,
        EstadoEvento VARCHAR(40) NOT NULL,
        FechaInicio DATETIME2 NOT NULL,

        IdCuota INT NOT NULL,
        Cuota DECIMAL(10,4) NOT NULL
    );


    INSERT INTO @Detalle
    (
        Orden,
        IdSeleccion,
        NombreSeleccion,
        IdMercado,
        NombreMercado,
        EstadoMercado,
        IdEvento,
        NombreEvento,
        EstadoEvento,
        FechaInicio,
        IdCuota,
        Cuota
    )
    SELECT
        I.Orden,
        S.IdSeleccion,
        S.Nombre,

        M.IdMercado,
        M.Nombre,
        EM.Codigo,

        EV.IdEvento,
        EV.Nombre,
        EE.Codigo,
        EV.FechaInicio,

        C.IdCuota,
        C.Valor

    FROM @Entrada AS I

    INNER JOIN dbo.Seleccion AS S
        ON S.IdSeleccion = I.IdSeleccion
       AND S.Activo = 1

    INNER JOIN dbo.Mercado AS M
        ON M.IdMercado = S.IdMercado

    INNER JOIN dbo.Estado AS EM
        ON EM.IdEstado = M.IdEstado

    INNER JOIN dbo.TipoEstado AS TEM
        ON TEM.IdTipoEstado = EM.IdTipoEstado
       AND TEM.Codigo = 'MERCADO'

    INNER JOIN dbo.Evento AS EV
        ON EV.IdEvento = M.IdEvento

    INNER JOIN dbo.Estado AS EE
        ON EE.IdEstado = EV.IdEstado

    INNER JOIN dbo.TipoEstado AS TEE
        ON TEE.IdTipoEstado = EE.IdTipoEstado
       AND TEE.Codigo = 'EVENTO'

    INNER JOIN dbo.Cuota AS C
        ON C.IdSeleccion = S.IdSeleccion
       AND C.Activo = 1;


    IF (SELECT COUNT(*) FROM @Detalle)
       <> (SELECT COUNT(*) FROM @Entrada)
        THROW 60009, 'Una o más selecciones no existen, están inactivas o no tienen una cuota activa.', 1;


    IF EXISTS
    (
        SELECT C.IdSeleccion
        FROM dbo.Cuota AS C
        INNER JOIN @Entrada AS I
            ON I.IdSeleccion = C.IdSeleccion
        WHERE C.Activo = 1
        GROUP BY C.IdSeleccion
        HAVING COUNT(*) <> 1
    )
        THROW 60010, 'Existe una selección con más de una cuota activa.', 1;


    IF EXISTS
    (
        SELECT 1
        FROM @Detalle
        WHERE EstadoMercado <> 'ABIERTO'
    )
        THROW 60011, 'Todas las selecciones deben pertenecer a mercados ABIERTOS.', 1;


        IF EXISTS
    (
        SELECT 1
        FROM @Detalle
        WHERE EstadoEvento <> 'PROGRAMADO'
    )
        THROW 60012,
            'Todas las selecciones deben pertenecer a eventos PROGRAMADOS.',
            1;


    IF EXISTS
    (
        SELECT 1
        FROM @Detalle
        WHERE @AhoraSistema >=
            DATEADD(
                MINUTE,
                -@AnticipacionCierre,
                FechaInicio
            )
    )
        THROW 60054,
            'El periodo de apuestas para uno o más eventos ya se encuentra cerrado.',
            1;


    IF EXISTS
    (
        SELECT IdMercado
        FROM @Detalle
        GROUP BY IdMercado
        HAVING COUNT(*) > 1
    )
        THROW 60013, 'No se pueden seleccionar dos resultados del mismo mercado en un boleto.', 1;


    DECLARE @CantidadSelecciones INT =
        (SELECT COUNT(*) FROM @Detalle);

    DECLARE @TipoBoleto VARCHAR(20) =
        CASE
            WHEN @CantidadSelecciones = 1 THEN 'SIMPLE'
            ELSE 'COMPUESTO'
        END;


    DECLARE @CuotaTotalCalculo DECIMAL(38,12) = 1;
    DECLARE @OrdenActual INT = 1;
    DECLARE @CuotaActual DECIMAL(10,4);

    WHILE @OrdenActual <= @CantidadSelecciones
    BEGIN
        SELECT @CuotaActual = Cuota
        FROM @Detalle
        WHERE Orden = @OrdenActual;

        SET @CuotaTotalCalculo =
            @CuotaTotalCalculo * CONVERT(DECIMAL(38,12), @CuotaActual);

        SET @OrdenActual = @OrdenActual + 1;
    END;


    IF @CuotaTotalCalculo > 99999999.9999
        THROW 60014, 'La cuota total excede el rango permitido por el sistema.', 1;


    DECLARE @CuotaTotal DECIMAL(12,4) =
        CONVERT(DECIMAL(12,4), ROUND(@CuotaTotalCalculo, 4));

    DECLARE @GananciaCalculo DECIMAL(38,4) =
        CONVERT(DECIMAL(38,4), @Monto)
        * CONVERT(DECIMAL(38,4), @CuotaTotal);


    IF @GananciaCalculo > 9999999999.99
        THROW 60015, 'La ganancia potencial excede el rango permitido por el sistema.', 1;


    DECLARE @GananciaPotencial DECIMAL(12,2) =
        CONVERT(DECIMAL(12,2), ROUND(@GananciaCalculo, 2));


    /* Primer result set: resumen de cotización. */
    SELECT
        @TipoBoleto AS TipoBoleto,
        @CantidadSelecciones AS CantidadSelecciones,

        @Monto AS MontoApostado,

        @ComisionPorcentaje AS ComisionServicioPorcentaje,
        @ComisionServicio AS ComisionServicio,
        @TotalCargo AS TotalCargo,

        @CuotaTotal AS CuotaTotal,
        @GananciaPotencial AS GananciaPotencial;

    /* Segundo result set: detalle de selecciones y cuotas actuales. */
    SELECT
        Orden,
        IdEvento,
        NombreEvento,
        IdMercado,
        NombreMercado,
        IdSeleccion,
        NombreSeleccion,
        IdCuota,
        Cuota
    FROM @Detalle
    ORDER BY Orden;
END;
GO


/* ============================================================
   2. REALIZAR APUESTA

   Operación crítica y atómica.

   FLUJO:
   Usuario apto
       ↓
   Restricciones
       ↓
   Validación de selecciones / mercados / eventos / cuotas
       ↓
   Bloqueo de billetera
       ↓
   Boleto + DetalleBoleto
       ↓
   TransaccionFinanciera(APUESTA)
       ↓
   Disponible disminuye / Comprometido aumenta
       ↓
   MovimientoBilletera
       ↓
   Auditoria
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_RealizarApuesta
(
    @IdUsuario INT,
    @SeleccionesJson NVARCHAR(MAX),
    @Monto DECIMAL(12,2),
    @ReferenciaOperacion UNIQUEIDENTIFIER,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @SeleccionesJson =
        NULLIF(LTRIM(RTRIM(@SeleccionesJson)), '');

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');


    /* ========================================================
       VALIDACIONES DE ENTRADA
       ======================================================== */

    IF @IdUsuario IS NULL
        THROW 60016, 'IdUsuario es obligatorio.', 1;

    IF @SeleccionesJson IS NULL
        THROW 60017, 'SeleccionesJson es obligatorio.', 1;

    IF ISJSON(@SeleccionesJson) <> 1
       OR LEFT(LTRIM(@SeleccionesJson), 1) <> '['
        THROW 60018, 'SeleccionesJson debe ser un arreglo JSON válido.', 1;

    IF @Monto IS NULL OR @Monto <= 0
        THROW 60019, 'Monto debe ser mayor que cero.', 1;

    IF @ReferenciaOperacion IS NULL
        THROW 60020, 'ReferenciaOperacion es obligatoria.', 1;


    DECLARE @MontoMinimo DECIMAL(12,2);

    SELECT @MontoMinimo =
        TRY_CONVERT(DECIMAL(12,2), Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'MONTO_MINIMO_APUESTA';

    IF @MontoMinimo IS NULL OR @MontoMinimo <= 0
        THROW 60021, 'MONTO_MINIMO_APUESTA no contiene un valor válido.', 1;

    IF @Monto < @MontoMinimo
        THROW 60022, 'El monto es menor que el mínimo permitido para apostar.', 1;

    DECLARE @AnticipacionCierre INT;

    SELECT @AnticipacionCierre =
        TRY_CONVERT(INT, Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'ANTICIPACION_CIERRE_APUESTA_MIN';

    IF @AnticipacionCierre IS NULL
    OR @AnticipacionCierre < 0
        THROW 60055,
            'ANTICIPACION_CIERRE_APUESTA_MIN no contiene un valor válido.',
            1;

    /* ========================================================
    COMISION DE SERVICIO
    ======================================================== */

    DECLARE @ComisionPorcentaje DECIMAL(7,4);

    SELECT @ComisionPorcentaje =
        TRY_CONVERT(DECIMAL(7,4), Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'COMISION_SERVICIO_PORCENTAJE';


    IF @ComisionPorcentaje IS NULL
    OR @ComisionPorcentaje < 0
    OR @ComisionPorcentaje > 100
        THROW 60060,
            'COMISION_SERVICIO_PORCENTAJE no contiene un valor válido.',
            1;


    DECLARE @ComisionCalculo DECIMAL(38,4) =
        CONVERT(DECIMAL(38,4), @Monto)
        * CONVERT(DECIMAL(38,4), @ComisionPorcentaje)
        / 100;


    IF @ComisionCalculo > 9999999999.99
        THROW 60061,
            'La comisión de servicio excede el rango permitido por el sistema.',
            1;


    DECLARE @ComisionServicio DECIMAL(12,2) =
        CONVERT
        (
            DECIMAL(12,2),
            ROUND(@ComisionCalculo, 2)
        );


    DECLARE @TotalCargoCalculo DECIMAL(38,2) =
        CONVERT(DECIMAL(38,2), @Monto)
        + CONVERT(DECIMAL(38,2), @ComisionServicio);


    IF @TotalCargoCalculo > 9999999999.99
        THROW 60062,
            'El monto total de la apuesta y comisión excede el rango permitido.',
            1;


    DECLARE @TotalCargo DECIMAL(12,2) =
        CONVERT(DECIMAL(12,2), @TotalCargoCalculo);


    /* ========================================================
       PARSEAR SELECCIONES
       ======================================================== */

    DECLARE @Entrada TABLE
    (
        Orden INT NOT NULL,
        IdSeleccion INT NULL
    );

    INSERT INTO @Entrada
    (
        Orden,
        IdSeleccion
    )
    SELECT
        CONVERT(INT, [key]) + 1,
        TRY_CONVERT(INT, [value])
    FROM OPENJSON(@SeleccionesJson);


    IF NOT EXISTS
    (
        SELECT 1
        FROM @Entrada
    )
        THROW 60023, 'Debe indicar al menos una selección.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Entrada
        WHERE IdSeleccion IS NULL
           OR IdSeleccion <= 0
    )
        THROW 60024, 'SeleccionesJson contiene un IdSeleccion no válido.', 1;

    IF EXISTS
    (
        SELECT IdSeleccion
        FROM @Entrada
        GROUP BY IdSeleccion
        HAVING COUNT(*) > 1
    )
        THROW 60025, 'No se puede repetir una selección dentro del mismo boleto.', 1;


    DECLARE @CantidadSelecciones INT =
        (SELECT COUNT(*) FROM @Entrada);

    DECLARE @TipoBoleto VARCHAR(20) =
        CASE
            WHEN @CantidadSelecciones = 1 THEN 'SIMPLE'
            ELSE 'COMPUESTO'
        END;


    /* ========================================================
       OBTENER CATALOGOS NECESARIOS
       ======================================================== */

    DECLARE @IdEstadoBoletoPendiente INT;
    DECLARE @IdEstadoTransaccionCompletada INT;
    DECLARE @IdTipoTransaccionApuesta INT;
    DECLARE @IdTipoTransaccionComision INT;


    SELECT @IdEstadoBoletoPendiente = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'BOLETO'
      AND E.Codigo = 'PENDIENTE'
      AND E.Activo = 1;

    IF @IdEstadoBoletoPendiente IS NULL
        THROW 60026, 'No existe el estado BOLETO/PENDIENTE.', 1;


    SELECT @IdEstadoTransaccionCompletada = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'TRANSACCION'
      AND E.Codigo = 'COMPLETADA'
      AND E.Activo = 1;

    IF @IdEstadoTransaccionCompletada IS NULL
        THROW 60027, 'No existe el estado TRANSACCION/COMPLETADA.', 1;


    SELECT @IdTipoTransaccionApuesta = IdTipoTransaccion
    FROM dbo.TipoTransaccion
    WHERE Codigo = 'APUESTA'
      AND Activo = 1;

    IF @IdTipoTransaccionApuesta IS NULL
        THROW 60028, 'No existe el tipo de transacción APUESTA activo.', 1;

    SELECT @IdTipoTransaccionComision = IdTipoTransaccion
    FROM dbo.TipoTransaccion
    WHERE Codigo = 'COMISION_SERVICIO'
    AND Activo = 1;


    IF @IdTipoTransaccionComision IS NULL
        THROW 60063,
            'No existe el tipo de transacción COMISION_SERVICIO activo.',
            1;

    BEGIN TRY
        BEGIN TRANSACTION;


        /* ====================================================
           IDEMPOTENCIA TEMPRANA

           La referencia pertenece al boleto y a su transacción.
           Si ya existe un boleto con la misma referencia:
           - Se verifica que corresponda a la misma solicitud.
           - Si coincide, se devuelve sin volver a descontar saldo.
           ==================================================== */

        DECLARE @IdBoletoExistente INT;
        DECLARE @IdUsuarioExistente INT;
        DECLARE @MontoExistente DECIMAL(12,2);
        DECLARE @TipoExistente VARCHAR(20);

        SELECT
            @IdBoletoExistente = B.IdBoleto,
            @IdUsuarioExistente = B.IdUsuario,
            @MontoExistente = B.MontoApostado,
            @TipoExistente = B.TipoBoleto
        FROM dbo.Boleto AS B WITH (UPDLOCK, HOLDLOCK)
        WHERE B.ReferenciaOperacion = @ReferenciaOperacion;


        IF @IdBoletoExistente IS NOT NULL
        BEGIN

            IF @IdUsuarioExistente <> @IdUsuario
               OR @MontoExistente <> @Monto
               OR @TipoExistente <> @TipoBoleto
                THROW 60029, 'ReferenciaOperacion ya pertenece a una apuesta diferente.', 1;


            IF
            (
                SELECT COUNT(*)
                FROM dbo.DetalleBoleto
                WHERE IdBoleto = @IdBoletoExistente
            ) <> @CantidadSelecciones
                THROW 60030, 'ReferenciaOperacion ya pertenece a una apuesta con selecciones diferentes.', 1;


            IF EXISTS
            (
                SELECT 1
                FROM @Entrada AS I
                WHERE NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.DetalleBoleto AS DB
                    WHERE DB.IdBoleto = @IdBoletoExistente
                      AND DB.IdSeleccion = I.IdSeleccion
                )
            )
                THROW 60031, 'ReferenciaOperacion ya pertenece a una apuesta con selecciones diferentes.', 1;


            DECLARE @IdTransaccionExistente BIGINT;

            SELECT @IdTransaccionExistente = IdTransaccion
            FROM dbo.TransaccionFinanciera
            WHERE ReferenciaOperacion = @ReferenciaOperacion
              AND IdBoleto = @IdBoletoExistente;


            COMMIT TRANSACTION;


            SELECT
                B.IdBoleto,
                B.CodigoBoleto,
                B.TipoBoleto,
                B.MontoApostado,
                B.ComisionServicio,
                (B.MontoApostado + B.ComisionServicio) AS TotalCargo,
                B.CuotaTotal,
                B.GananciaPotencial,
                B.Resultado,
                E.Codigo AS EstadoBoleto,
                B.FechaCreacion,
                @IdTransaccionExistente AS IdTransaccion,
                B.ReferenciaOperacion,
                CAST(1 AS BIT) AS SolicitudIdempotente
            FROM dbo.Boleto AS B
            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = B.IdEstado
            WHERE B.IdBoleto = @IdBoletoExistente;

            RETURN;
        END;


        /* Si la referencia ya existe en una transacción pero no
           corresponde a un boleto, la instalación está inconsistente
           o la referencia se reutilizó para otra operación. */
        IF EXISTS
        (
            SELECT 1
            FROM dbo.TransaccionFinanciera WITH (UPDLOCK, HOLDLOCK)
            WHERE ReferenciaOperacion = @ReferenciaOperacion
        )
            THROW 60032, 'ReferenciaOperacion ya fue utilizada por otra transacción financiera.', 1;


        /* ====================================================
           VALIDAR USUARIO
           ==================================================== */

        DECLARE @RolUsuario VARCHAR(50);
        DECLARE @EstadoUsuario VARCHAR(40);
        DECLARE @CorreoVerificado BIT;

        SELECT
            @RolUsuario = R.Nombre,
            @EstadoUsuario = E.Codigo,
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


        IF @RolUsuario IS NULL
            THROW 60033, 'El usuario indicado no existe.', 1;

        IF @RolUsuario <> 'USUARIO'
            THROW 60034, 'Solo las cuentas con rol USUARIO pueden registrar boletos.', 1;

        IF @EstadoUsuario <> 'ACTIVO'
            THROW 60035, 'La cuenta debe estar ACTIVA para realizar apuestas.', 1;

        IF @CorreoVerificado <> 1
            THROW 60036, 'El correo del usuario debe estar verificado antes de apostar.', 1;


        /* ====================================================
           VALIDAR VERIFICACION ADMINISTRATIVA MAS RECIENTE
           ==================================================== */

        DECLARE @EstadoVerificacion VARCHAR(40);

        SELECT TOP (1)
            @EstadoVerificacion = E.Codigo
        FROM dbo.VerificacionUsuario AS V WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = V.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'VERIFICACION'
        WHERE V.IdUsuario = @IdUsuario
        ORDER BY V.IdVerificacion DESC;


        IF @EstadoVerificacion IS NULL
            THROW 60037, 'El usuario no posee un proceso de verificación.', 1;

        IF @EstadoVerificacion <> 'APROBADA'
            THROW 60038, 'La verificación administrativa del usuario debe estar APROBADA para apostar.', 1;


        /* ====================================================
           VALIDAR RESTRICCIONES VIGENTES
           ==================================================== */

        /* Hora utilizada por las fechas internas del sistema,
        manteniendo compatibilidad con RestriccionUsuario. */
        DECLARE @AhoraRestricciones DATETIME2 =
            SYSDATETIME();

        IF EXISTS
        (
            SELECT 1
            FROM dbo.RestriccionUsuario AS RU WITH (UPDLOCK, HOLDLOCK)
            WHERE RU.IdUsuario = @IdUsuario
              AND RU.Activa = 1
              AND RU.TipoRestriccion IN ('APOSTAR', 'TODAS_OPERACIONES')
              AND RU.FechaInicio <= @AhoraRestricciones
              AND
              (
                  RU.FechaFin IS NULL
                  OR RU.FechaFin > @AhoraRestricciones
              )
        )
            THROW 60039, 'El usuario posee una restricción vigente que impide realizar apuestas.', 1;


        /* ====================================================
           VALIDAR Y BLOQUEAR SELECCIONES / MERCADOS / EVENTOS /
           CUOTAS PARA CAPTURAR UN SNAPSHOT CONSISTENTE.
           ==================================================== */

        DECLARE @Detalle TABLE
        (
            Orden INT NOT NULL,
            IdSeleccion INT NOT NULL,
            IdMercado INT NOT NULL,
            IdEvento INT NOT NULL,
            FechaInicio DATETIME2 NOT NULL,
            IdCuota INT NOT NULL,
            Cuota DECIMAL(10,4) NOT NULL
        );


        INSERT INTO @Detalle
        (
            Orden,
            IdSeleccion,
            IdMercado,
            IdEvento,
            FechaInicio,
            IdCuota,
            Cuota
        )
        SELECT
            I.Orden,
            S.IdSeleccion,
            M.IdMercado,
            EV.IdEvento,
            EV.FechaInicio,
            C.IdCuota,
            C.Valor

        FROM @Entrada AS I

        INNER JOIN dbo.Seleccion AS S WITH (UPDLOCK, HOLDLOCK)
            ON S.IdSeleccion = I.IdSeleccion
           AND S.Activo = 1

        INNER JOIN dbo.Mercado AS M WITH (UPDLOCK, HOLDLOCK)
            ON M.IdMercado = S.IdMercado

        INNER JOIN dbo.Estado AS EM
            ON EM.IdEstado = M.IdEstado

        INNER JOIN dbo.TipoEstado AS TEM
            ON TEM.IdTipoEstado = EM.IdTipoEstado
           AND TEM.Codigo = 'MERCADO'

        INNER JOIN dbo.Evento AS EV WITH (UPDLOCK, HOLDLOCK)
            ON EV.IdEvento = M.IdEvento

        INNER JOIN dbo.Estado AS EE
            ON EE.IdEstado = EV.IdEstado

        INNER JOIN dbo.TipoEstado AS TEE
            ON TEE.IdTipoEstado = EE.IdTipoEstado
           AND TEE.Codigo = 'EVENTO'

        INNER JOIN dbo.Cuota AS C WITH (UPDLOCK, HOLDLOCK)
            ON C.IdSeleccion = S.IdSeleccion
           AND C.Activo = 1

        WHERE EM.Codigo = 'ABIERTO'
            AND EE.Codigo = 'PROGRAMADO';


        IF (SELECT COUNT(*) FROM @Detalle)
           <> @CantidadSelecciones
            THROW 60040, 'Una o más selecciones ya no están disponibles para apostar.', 1;

        /* Se obtiene la hora lo más cerca posible de la
        validación definitiva del cierre de apuesta. */
        DECLARE @AhoraEvento DATETIME2 =
            CAST(
                SYSUTCDATETIME()
                AT TIME ZONE 'UTC'
                AT TIME ZONE 'Central America Standard Time'
                AS DATETIME2
            );

        IF EXISTS
        (
            SELECT 1
            FROM @Detalle
            WHERE @AhoraEvento >=
                DATEADD(
                    MINUTE,
                    -@AnticipacionCierre,
                    FechaInicio
                )
        )
            THROW 60056,
                'El periodo de apuestas para uno o más eventos ya se encuentra cerrado.',
                1;


        IF EXISTS
        (
            SELECT C.IdSeleccion
            FROM dbo.Cuota AS C WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN @Entrada AS I
                ON I.IdSeleccion = C.IdSeleccion
            WHERE C.Activo = 1
            GROUP BY C.IdSeleccion
            HAVING COUNT(*) <> 1
        )
            THROW 60041, 'Existe una selección con una cantidad inválida de cuotas activas.', 1;


        IF EXISTS
        (
            SELECT IdMercado
            FROM @Detalle
            GROUP BY IdMercado
            HAVING COUNT(*) > 1
        )
            THROW 60042, 'No se pueden seleccionar dos resultados del mismo mercado en un boleto.', 1;


        /* ====================================================
           CALCULAR CUOTA TOTAL Y GANANCIA POTENCIAL
           ==================================================== */

        DECLARE @CuotaTotalCalculo DECIMAL(38,12) = 1;
        DECLARE @OrdenActual INT = 1;
        DECLARE @CuotaActual DECIMAL(10,4);

        WHILE @OrdenActual <= @CantidadSelecciones
        BEGIN
            SELECT @CuotaActual = Cuota
            FROM @Detalle
            WHERE Orden = @OrdenActual;

            SET @CuotaTotalCalculo =
                @CuotaTotalCalculo * CONVERT(DECIMAL(38,12), @CuotaActual);

            SET @OrdenActual = @OrdenActual + 1;
        END;


        IF @CuotaTotalCalculo > 99999999.9999
            THROW 60043, 'La cuota total excede el rango permitido por el sistema.', 1;


        DECLARE @CuotaTotal DECIMAL(12,4) =
            CONVERT(DECIMAL(12,4), ROUND(@CuotaTotalCalculo, 4));


        DECLARE @GananciaCalculo DECIMAL(38,4) =
            CONVERT(DECIMAL(38,4), @Monto)
            * CONVERT(DECIMAL(38,4), @CuotaTotal);


        IF @GananciaCalculo > 9999999999.99
            THROW 60044, 'La ganancia potencial excede el rango permitido por el sistema.', 1;


        DECLARE @GananciaPotencial DECIMAL(12,2) =
            CONVERT(DECIMAL(12,2), ROUND(@GananciaCalculo, 2));

        /* ====================================================
        LOCALIZAR CASA
        ==================================================== */

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
            THROW 60064,
                'Debe existir exactamente una cuenta CASA activa con billetera.',
                1;


        DECLARE @IdUsuarioCasa INT;
        DECLARE @IdBilleteraCasa INT;

        SELECT
            @IdUsuarioCasa = UC.IdUsuario,
            @IdBilleteraCasa = BC.IdBilletera
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


        /* Bloquear CASA primero para mantener el mismo orden
        utilizado por el proceso de liquidación. */

        DECLARE @CasaDisponibleAnterior DECIMAL(12,2);
        DECLARE @CasaComprometidoAnterior DECIMAL(12,2);

        SELECT
            @CasaDisponibleAnterior = SaldoDisponible,
            @CasaComprometidoAnterior = SaldoComprometido
        FROM dbo.Billetera WITH (UPDLOCK, ROWLOCK)
        WHERE IdBilletera = @IdBilleteraCasa;


        IF @CasaDisponibleAnterior IS NULL
            THROW 60065,
                'No fue posible bloquear la billetera de CASA.',
                1;


        /* ====================================================
           BLOQUEAR BILLETERA Y VALIDAR SALDO
           ==================================================== */

        DECLARE @IdBilletera INT;
        DECLARE @SaldoDisponibleAnterior DECIMAL(12,2);
        DECLARE @SaldoComprometidoAnterior DECIMAL(12,2);

        SELECT
            @IdBilletera = B.IdBilletera,
            @SaldoDisponibleAnterior = B.SaldoDisponible,
            @SaldoComprometidoAnterior = B.SaldoComprometido
        FROM dbo.Billetera AS B WITH (UPDLOCK, ROWLOCK)
        WHERE B.IdUsuario = @IdUsuario;


        IF @IdBilletera IS NULL
            THROW 60045, 'El usuario no posee una billetera.', 1;

        IF @SaldoDisponibleAnterior < @TotalCargo
        THROW 60046,
            'Saldo disponible insuficiente para cubrir la apuesta y la comisión de servicio.', 1;

        DECLARE @SaldoDisponiblePostApuesta DECIMAL(12,2) =
            @SaldoDisponibleAnterior - @Monto;

        DECLARE @SaldoComprometidoPosterior DECIMAL(12,2) =
            @SaldoComprometidoAnterior + @Monto;

        DECLARE @SaldoDisponiblePosterior DECIMAL(12,2) =
            @SaldoDisponiblePostApuesta - @ComisionServicio;


        /* ====================================================
           CREAR BOLETO
           ==================================================== */

        DECLARE @CodigoBoleto VARCHAR(40) =
            CONCAT
            (
                'B-',
                REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', '')
            );

        DECLARE @IdBoleto INT;


        INSERT INTO dbo.Boleto
        (
            CodigoBoleto,
            IdUsuario,
            IdEstado,
            ReferenciaOperacion,
            MontoApostado,
            ComisionServicio,
            CuotaTotal,
            GananciaPotencial,
            TipoBoleto,
            Resultado
        )
        VALUES
        (
            @CodigoBoleto,
            @IdUsuario,
            @IdEstadoBoletoPendiente,
            @ReferenciaOperacion,
            @Monto,
            @ComisionServicio,
            @CuotaTotal,
            @GananciaPotencial,
            @TipoBoleto,
            'PENDIENTE'
        );

        SET @IdBoleto =
            CONVERT(INT, SCOPE_IDENTITY());


        /* ====================================================
           CREAR DETALLES CON LA CUOTA APLICADA
           ==================================================== */

        INSERT INTO dbo.DetalleBoleto
        (
            IdBoleto,
            IdSeleccion,
            CuotaAplicada,
            Resultado
        )
        SELECT
            @IdBoleto,
            D.IdSeleccion,
            D.Cuota,
            'PENDIENTE'
        FROM @Detalle AS D;


        /* ====================================================
           TRANSACCION FINANCIERA DE APUESTA
           ==================================================== */

        DECLARE @IdTransaccion BIGINT;

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
            @IdTipoTransaccionApuesta,
            @IdEstadoTransaccionCompletada,
            @IdBoleto,
            @ReferenciaOperacion,
            @Monto,
            SYSDATETIME(),
            @IdUsuario,
            CONCAT
            (
                'Apuesta ',
                @TipoBoleto,
                ' registrada con ',
                @CantidadSelecciones,
                ' selección(es).'
            )
        );

        SET @IdTransaccion =
            CONVERT(BIGINT, SCOPE_IDENTITY());


        /* ====================================================
           MOVER SALDO DISPONIBLE A COMPROMETIDO
           ==================================================== */

        UPDATE dbo.Billetera
        SET
            SaldoDisponible = @SaldoDisponiblePostApuesta,
            SaldoComprometido = @SaldoComprometidoPosterior
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

            @SaldoDisponibleAnterior,
            @SaldoDisponiblePostApuesta,

            @SaldoComprometidoAnterior,
            @SaldoComprometidoPosterior
        );

    /* ====================================================
    COMISION DE SERVICIO
    ==================================================== */

    DECLARE @IdTransaccionComisionUsuario BIGINT = NULL;
    DECLARE @IdTransaccionComisionCasa BIGINT = NULL;

    DECLARE @ReferenciaComisionUsuario UNIQUEIDENTIFIER = NULL;
    DECLARE @ReferenciaComisionCasa UNIQUEIDENTIFIER = NULL;

    DECLARE @CasaDisponiblePosterior DECIMAL(12,2) =
        @CasaDisponibleAnterior;


    IF @ComisionServicio > 0
    BEGIN

        /* ==================================================
        COBRO DE COMISION AL USUARIO
        ================================================== */

        SET @ReferenciaComisionUsuario = NEWID();


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
            @IdTipoTransaccionComision,
            @IdEstadoTransaccionCompletada,
            @IdBoleto,
            @ReferenciaComisionUsuario,
            @ComisionServicio,
            SYSDATETIME(),
            @IdUsuario,
            CONCAT
            (
                'Comisión de servicio cobrada por boleto ',
                @CodigoBoleto,
                '. Comisión=',
                CONVERT(VARCHAR(30), @ComisionServicio),
                '.'
            )
        );


        SET @IdTransaccionComisionUsuario =
            CONVERT(BIGINT, SCOPE_IDENTITY());


        UPDATE dbo.Billetera
        SET
            SaldoDisponible = @SaldoDisponiblePosterior,
            SaldoComprometido = @SaldoComprometidoPosterior
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
            @IdTransaccionComisionUsuario,

            @SaldoDisponiblePostApuesta,
            @SaldoDisponiblePosterior,

            @SaldoComprometidoPosterior,
            @SaldoComprometidoPosterior
        );


        /* ==================================================
        ACREDITAR COMISION A CASA
        ================================================== */

        SET @CasaDisponiblePosterior =
            @CasaDisponibleAnterior + @ComisionServicio;


        SET @ReferenciaComisionCasa = NEWID();


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
            @IdTipoTransaccionComision,
            @IdEstadoTransaccionCompletada,
            @IdBoleto,
            @ReferenciaComisionCasa,
            @ComisionServicio,
            SYSDATETIME(),
            @IdUsuario,
            CONCAT
            (
                'Comisión de servicio acreditada a CASA por boleto ',
                @CodigoBoleto,
                '. Comisión=',
                CONVERT(VARCHAR(30), @ComisionServicio),
                '.'
            )
        );


        SET @IdTransaccionComisionCasa =
            CONVERT(BIGINT, SCOPE_IDENTITY());


        UPDATE dbo.Billetera
        SET SaldoDisponible = @CasaDisponiblePosterior
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
            @IdTransaccionComisionCasa,

            @CasaDisponibleAnterior,
            @CasaDisponiblePosterior,

            @CasaComprometidoAnterior,
            @CasaComprometidoAnterior
        );

    END;


        /* ====================================================
           AUDITORIA
           ==================================================== */

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            ReferenciaOperacion,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuario,
            'APUESTA_REGISTRADA',
            'Boleto',
            @IdBoleto,
            @ReferenciaOperacion,
            @IpOrigen,
            CONCAT
            (
                'Boleto ',
                @CodigoBoleto,
                '. Tipo=',
                @TipoBoleto,
                '. Monto=',
                CONVERT(VARCHAR(30), @Monto),
                '. ComisionServicio=',
                CONVERT(VARCHAR(30), @ComisionServicio),
                '. TotalCargo=',
                CONVERT(VARCHAR(30), @TotalCargo),
                '. CuotaTotal=',
                CONVERT(VARCHAR(30), @CuotaTotal),
                '. GananciaPotencial=',
                CONVERT(VARCHAR(30), @GananciaPotencial),
                '.'
            )
        );


        COMMIT TRANSACTION;


        /* ====================================================
           RESPUESTA ESTABLE PARA JAVA
           ==================================================== */

        SELECT
            @IdBoleto AS IdBoleto,
            @CodigoBoleto AS CodigoBoleto,
            @TipoBoleto AS TipoBoleto,
            @CantidadSelecciones AS CantidadSelecciones,

            @Monto AS MontoApostado,
            @ComisionPorcentaje AS ComisionServicioPorcentaje,
            @ComisionServicio AS ComisionServicio,
            @TotalCargo AS TotalCargo,
            @CuotaTotal AS CuotaTotal,
            @GananciaPotencial AS GananciaPotencial,

            'PENDIENTE' AS Resultado,
            'PENDIENTE' AS EstadoBoleto,

            @IdBilletera AS IdBilletera,
            @IdTransaccion AS IdTransaccion,
            @IdTransaccionComisionUsuario AS IdTransaccionComisionUsuario,
            @IdTransaccionComisionCasa AS IdTransaccionComisionCasa,
            @ReferenciaOperacion AS ReferenciaOperacion,

            @SaldoDisponibleAnterior AS SaldoDisponibleAnterior,
            @SaldoDisponiblePosterior AS SaldoDisponiblePosterior,

            @SaldoComprometidoAnterior AS SaldoComprometidoAnterior,
            @SaldoComprometidoPosterior AS SaldoComprometidoPosterior,

            @CasaDisponibleAnterior AS CasaDisponibleAnterior,
            @CasaDisponiblePosterior AS CasaDisponiblePosterior,

            CAST(0 AS BIT) AS SolicitudIdempotente

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   3. OBTENER BOLETO

   SEGURIDAD:
   - El propietario puede consultar su boleto.
   - ADMINISTRADOR y AUDITOR pueden consultar cualquier boleto.

   DEVUELVE DOS RESULT SETS:
   1. Encabezado del boleto.
   2. Detalle de selecciones con evento, mercado y cuota aplicada.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerBoleto
(
    @IdUsuarioSolicitante INT,
    @IdBoleto INT = NULL,
    @CodigoBoleto VARCHAR(40) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @CodigoBoleto =
        NULLIF(LTRIM(RTRIM(@CodigoBoleto)), '');

    IF @IdUsuarioSolicitante IS NULL
        THROW 60047, 'IdUsuarioSolicitante es obligatorio.', 1;

    IF @IdBoleto IS NULL
       AND @CodigoBoleto IS NULL
        THROW 60048, 'Debe indicar IdBoleto o CodigoBoleto.', 1;


    DECLARE @IdBoletoEncontrado INT;
    DECLARE @IdPropietario INT;

    SELECT TOP (1)
        @IdBoletoEncontrado = B.IdBoleto,
        @IdPropietario = B.IdUsuario
    FROM dbo.Boleto AS B
    WHERE
        (@IdBoleto IS NOT NULL AND B.IdBoleto = @IdBoleto)
        OR
        (@CodigoBoleto IS NOT NULL AND B.CodigoBoleto = @CodigoBoleto)
    ORDER BY
        CASE
            WHEN @IdBoleto IS NOT NULL
             AND B.IdBoleto = @IdBoleto
                THEN 0
            ELSE 1
        END;


    IF @IdBoletoEncontrado IS NULL
        THROW 60049, 'El boleto indicado no existe.', 1;


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
        THROW 60050, 'El usuario solicitante no existe.', 1;

    IF @EstadoSolicitante = 'CERRADO'
        THROW 60051, 'Una cuenta cerrada no puede consultar boletos.', 1;


    IF @IdUsuarioSolicitante <> @IdPropietario
       AND @RolSolicitante NOT IN ('ADMINISTRADOR', 'AUDITOR')
        THROW 60052, 'El usuario no tiene permisos para consultar este boleto.', 1;


    /* Primer result set: encabezado. */
    SELECT
        B.IdBoleto,
        B.CodigoBoleto,

        B.IdUsuario,
        U.Correo,

        B.TipoBoleto,
        B.MontoApostado,
        B.ComisionServicio,
        (B.MontoApostado + B.ComisionServicio) AS TotalCargo,
        B.CuotaTotal,
        B.GananciaPotencial,

        B.Resultado,
        E.Codigo AS EstadoBoleto,

        B.FechaCreacion,
        B.FechaLiquidacion,

        B.ReferenciaOperacion

    FROM dbo.Boleto AS B
    INNER JOIN dbo.Usuario AS U
        ON U.IdUsuario = B.IdUsuario
    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = B.IdEstado
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'BOLETO'

    WHERE B.IdBoleto = @IdBoletoEncontrado;


    /* Segundo result set: detalle. */
    SELECT
        DB.IdDetalle,

        EV.IdEvento,
        EV.Nombre AS Evento,

        M.IdMercado,
        M.Nombre AS Mercado,

        S.IdSeleccion,
        S.Nombre AS Seleccion,

        DB.CuotaAplicada,
        DB.Resultado

    FROM dbo.DetalleBoleto AS DB
    INNER JOIN dbo.Seleccion AS S
        ON S.IdSeleccion = DB.IdSeleccion
    INNER JOIN dbo.Mercado AS M
        ON M.IdMercado = S.IdMercado
    INNER JOIN dbo.Evento AS EV
        ON EV.IdEvento = M.IdEvento

    WHERE DB.IdBoleto = @IdBoletoEncontrado

    ORDER BY DB.IdDetalle;
END;
GO


PRINT '=======================================================';
PRINT ' PROCEDIMIENTOS DE APUESTAS CREADOS / ACTUALIZADOS';
PRINT '=======================================================';
GO