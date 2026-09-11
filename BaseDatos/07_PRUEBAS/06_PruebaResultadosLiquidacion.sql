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
    3. CREAR TRES USUARIOS
    ======================================================== */

    DECLARE @DocumentoAnulado VARCHAR(50) =
        CONCAT('ANU-', @Codigo);


    DECLARE @CorreoA VARCHAR(150) =
        CONCAT('ganador.', @Codigo, '@apuestas.test');

    DECLARE @CorreoB VARCHAR(150) =
        CONCAT('perdedor.', @Codigo, '@apuestas.test');

    DECLARE @CorreoC VARCHAR(150) =
        CONCAT('anulado.', @Codigo, '@apuestas.test');


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


    EXEC dbo.sp_RegistrarUsuarioCliente
        @Nombre = 'Usuario',
        @Apellido = 'Anulado',
        @Correo = @CorreoC,
        @Contrasena =
            '$2a$12$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ123456',
        @FechaNacimiento = '2000-01-01',
        @Genero = 'M',
        @Telefono = '55550203',
        @TipoDocumento = 'DPI',
        @NumeroDocumento = @DocumentoAnulado,
        @IdPais = @IdPais,
        @IdMunicipio = @IdMunicipio,
        @CiudadExterior = NULL,
        @Direccion = 'Dirección prueba anulado';


    DECLARE @IdUsuarioA INT;
    DECLARE @IdUsuarioB INT;
    DECLARE @IdUsuarioC INT;


    SELECT @IdUsuarioA = IdUsuario
    FROM dbo.Usuario
    WHERE Correo = @CorreoA;


    SELECT @IdUsuarioB = IdUsuario
    FROM dbo.Usuario
    WHERE Correo = @CorreoB;


    SELECT @IdUsuarioC = IdUsuario
    FROM dbo.Usuario
    WHERE Correo = @CorreoC;


    IF @IdUsuarioA IS NULL
    OR @IdUsuarioB IS NULL
    OR @IdUsuarioC IS NULL
        THROW 70403, 'No se crearon los tres usuarios de prueba.', 1;


    /* ========================================================
    4. HABILITAR LOS TRES USUARIOS
    ======================================================== */

    DECLARE @IdEstadoVerificacionAprobada INT;


    SELECT @IdEstadoVerificacionAprobada = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'VERIFICACION'
    AND E.Codigo = 'APROBADA';


    IF @IdEstadoVerificacionAprobada IS NULL
        THROW 70425,
            'No existe el estado VERIFICACION/APROBADA.',
            1;


    UPDATE dbo.Usuario
    SET CorreoVerificado = 1
    WHERE IdUsuario IN
    (
        @IdUsuarioA,
        @IdUsuarioB,
        @IdUsuarioC
    );


    UPDATE dbo.VerificacionUsuario
    SET
        IdEstado = @IdEstadoVerificacionAprobada,
        IdUsuarioRevisor = @IdAdministrador,
        FechaInicioRevision = SYSDATETIME(),
        FechaResolucion = SYSDATETIME()
    WHERE IdUsuario IN
    (
        @IdUsuarioA,
        @IdUsuarioB,
        @IdUsuarioC
    );


    EXEC dbo.sp_SincronizarHabilitacionUsuario
        @IdUsuario = @IdUsuarioA;


    EXEC dbo.sp_SincronizarHabilitacionUsuario
        @IdUsuario = @IdUsuarioB;


    EXEC dbo.sp_SincronizarHabilitacionUsuario
        @IdUsuario = @IdUsuarioC;


    IF EXISTS
    (
        SELECT 1
        FROM dbo.Usuario AS U
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
        AND TE.Codigo = 'USUARIO'
        WHERE U.IdUsuario IN
        (
            @IdUsuarioA,
            @IdUsuarioB,
            @IdUsuarioC
        )
        AND
        (
            E.Codigo <> 'ACTIVO'
            OR U.CorreoVerificado <> 1
        )
    )
        THROW 70426,
            'Uno o más usuarios no quedaron habilitados para apostar.',
            1;


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


        IF @IdLiga IS NULL
            THROW 70427,
                'No se creó correctamente la liga de prueba.',
                1;


        /* ========================================================
        PARTICIPANTES DEL EVENTO
        ======================================================== */

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
        WHERE IdDeporte = @IdDeporte
        AND Nombre = @NombreParticipanteA;


        SELECT @IdParticipanteB = IdParticipante
        FROM dbo.Participante
        WHERE IdDeporte = @IdDeporte
        AND Nombre = @NombreParticipanteB;


        IF @IdParticipanteA IS NULL
        OR @IdParticipanteB IS NULL
            THROW 70428,
                'No se crearon correctamente los participantes de prueba.',
                1;


        /* ========================================================
        EVENTO
        ======================================================== */

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
        WHERE IdLiga = @IdLiga
        AND Nombre = @NombreEvento;


        IF @IdEvento IS NULL
            THROW 70429,
                'No se creó correctamente el evento de prueba.',
                1;


        /* ========================================================
        ASOCIAR PARTICIPANTES AL EVENTO
        ======================================================== */

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


        IF
        (
            SELECT COUNT(*)
            FROM dbo.EventoParticipante
            WHERE IdEvento = @IdEvento
            AND IdParticipante IN
            (
                @IdParticipanteA,
                @IdParticipanteB
            )
        ) <> 2
            THROW 70430,
                'Los participantes no quedaron asociados correctamente al evento.',
                1;


    /* ========================================================
        6. MERCADOS + SELECCIONES + CUOTAS
        ======================================================== */

        /* ========================================================
        MERCADO PRINCIPAL:
        - Equipo A -> GANADA
        - Equipo B -> PERDIDA
        ======================================================== */

        EXEC dbo.sp_CrearMercado
            @IdUsuarioProceso = @IdAdministrador,
            @IdEvento = @IdEvento,
            @Nombre = @NombreMercado,
            @Descripcion = 'Prueba resultado ganador y perdedor.',
            @IpOrigen = '127.0.0.1';


        DECLARE @IdMercado INT;


        SELECT @IdMercado = IdMercado
        FROM dbo.Mercado
        WHERE IdEvento = @IdEvento
        AND Nombre = @NombreMercado;


        IF @IdMercado IS NULL
            THROW 70431,
                'No se creó correctamente el mercado principal.',
                1;


        /* ========================================================
        SELECCIONES DEL MERCADO PRINCIPAL
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
            THROW 70432,
                'No se crearon correctamente las selecciones A y B.',
                1;


        /* ========================================================
        CUOTAS DEL MERCADO PRINCIPAL
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
        SEGUNDO MERCADO:
        SE USARA PARA EL BOLETO TOTALMENTE ANULADO
        ======================================================== */

        DECLARE @NombreMercadoAnulado VARCHAR(150) =
            CONCAT('Mercado anulado liquidación ', @Codigo);


        EXEC dbo.sp_CrearMercado
            @IdUsuarioProceso = @IdAdministrador,
            @IdEvento = @IdEvento,
            @Nombre = @NombreMercadoAnulado,
            @Descripcion = 'Mercado destinado a probar anulación total.',
            @IpOrigen = '127.0.0.1';


        DECLARE @IdMercadoAnulado INT;


        SELECT @IdMercadoAnulado = IdMercado
        FROM dbo.Mercado
        WHERE IdEvento = @IdEvento
        AND Nombre = @NombreMercadoAnulado;


        IF @IdMercadoAnulado IS NULL
            THROW 70433,
                'No se creó correctamente el mercado para anulación.',
                1;


        /* ========================================================
            SELECCIONES DEL MERCADO QUE POSTERIORMENTE
            SERA ANULADO

            El sistema exige al menos dos selecciones activas
            para poder abrir un mercado.
            ======================================================== */

            EXEC dbo.sp_CrearSeleccion
                @IdUsuarioProceso = @IdAdministrador,
                @IdMercado = @IdMercadoAnulado,
                @Nombre = 'Selección anulada',
                @IpOrigen = '127.0.0.1';


            EXEC dbo.sp_CrearSeleccion
                @IdUsuarioProceso = @IdAdministrador,
                @IdMercado = @IdMercadoAnulado,
                @Nombre = 'Selección alternativa',
                @IpOrigen = '127.0.0.1';


            DECLARE @IdSeleccionC INT;
            DECLARE @IdSeleccionD INT;


            SELECT @IdSeleccionC = IdSeleccion
            FROM dbo.Seleccion
            WHERE IdMercado = @IdMercadoAnulado
            AND Nombre = 'Selección anulada';


            SELECT @IdSeleccionD = IdSeleccion
            FROM dbo.Seleccion
            WHERE IdMercado = @IdMercadoAnulado
            AND Nombre = 'Selección alternativa';


            IF @IdSeleccionC IS NULL
            OR @IdSeleccionD IS NULL
                THROW 70434,
                    'No se crearon correctamente las selecciones del mercado anulado.',
                    1;


            /* ========================================================
            CUOTAS DEL MERCADO

            Ambas selecciones necesitan una cuota activa para que
            el mercado pueda abrirse correctamente.
            ======================================================== */

            EXEC dbo.sp_RegistrarCuota
                @IdUsuarioProceso = @IdAdministrador,
                @IdSeleccion = @IdSeleccionC,
                @Valor = 1.7000,
                @IpOrigen = '127.0.0.1';


            EXEC dbo.sp_RegistrarCuota
                @IdUsuarioProceso = @IdAdministrador,
                @IdSeleccion = @IdSeleccionD,
                @Valor = 2.0000,
                @IpOrigen = '127.0.0.1';


            IF
            (
                SELECT COUNT(*)
                FROM dbo.Cuota
                WHERE IdSeleccion IN
                (
                    @IdSeleccionC,
                    @IdSeleccionD
                )
                AND Activo = 1
            ) <> 2
                THROW 70435,
                    'El mercado anulado debe poseer dos selecciones con cuota activa.',
                    1;

        /* ========================================================
        PUBLICAR EVENTO
        ======================================================== */

        EXEC dbo.sp_CambiarEstadoEvento
            @IdUsuarioProceso = @IdAdministrador,
            @IdEvento = @IdEvento,
            @NuevoEstado = 'PROGRAMADO',
            @Motivo = 'Prueba liquidación.',
            @IpOrigen = '127.0.0.1';


        /* ========================================================
        ABRIR AMBOS MERCADOS
        ======================================================== */

        EXEC dbo.sp_CambiarEstadoMercado
            @IdUsuarioProceso = @IdAdministrador,
            @IdMercado = @IdMercado,
            @NuevoEstado = 'ABIERTO',
            @Motivo = 'Prueba liquidación.',
            @IpOrigen = '127.0.0.1';


        EXEC dbo.sp_CambiarEstadoMercado
            @IdUsuarioProceso = @IdAdministrador,
            @IdMercado = @IdMercadoAnulado,
            @NuevoEstado = 'ABIERTO',
            @Motivo = 'Prueba liquidación de boleto anulado.',
            @IpOrigen = '127.0.0.1';


        /* ========================================================
        VALIDAR CUOTAS ACTIVAS
        ======================================================== */

        IF
        (
            SELECT COUNT(*)
            FROM dbo.Cuota
            WHERE IdSeleccion IN
            (
                @IdSeleccionA,
                @IdSeleccionB,
                @IdSeleccionC
            )
            AND Activo = 1
        ) <> 3
            THROW 70435,
                'Las tres selecciones deben poseer una cuota activa.',
                1;


    /* ========================================================
        7. SALDOS INICIALES Y CONFIGURACION FINANCIERA
        ======================================================== */

        /* ========================================================
        SALDOS INICIALES DE LOS TRES USUARIOS
        ======================================================== */

        DECLARE @SaldoInicialA DECIMAL(12,2);
        DECLARE @SaldoInicialB DECIMAL(12,2);
        DECLARE @SaldoInicialC DECIMAL(12,2);

        DECLARE @ComprometidoInicialA DECIMAL(12,2);
        DECLARE @ComprometidoInicialB DECIMAL(12,2);
        DECLARE @ComprometidoInicialC DECIMAL(12,2);


        SELECT
            @SaldoInicialA = SaldoDisponible,
            @ComprometidoInicialA = SaldoComprometido
        FROM dbo.Billetera
        WHERE IdUsuario = @IdUsuarioA;


        SELECT
            @SaldoInicialB = SaldoDisponible,
            @ComprometidoInicialB = SaldoComprometido
        FROM dbo.Billetera
        WHERE IdUsuario = @IdUsuarioB;


        SELECT
            @SaldoInicialC = SaldoDisponible,
            @ComprometidoInicialC = SaldoComprometido
        FROM dbo.Billetera
        WHERE IdUsuario = @IdUsuarioC;


        IF @SaldoInicialA IS NULL
        OR @SaldoInicialB IS NULL
        OR @SaldoInicialC IS NULL
            THROW 70404,
                'No se encontraron las billeteras de los tres usuarios.',
                1;


        /* ========================================================
        BILLETERA CASA
        ======================================================== */

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


        IF @IdBilleteraCasa IS NULL
        OR @SaldoCasaInicial IS NULL
            THROW 70405,
                'No se encontró correctamente la billetera CASA.',
                1;


        /* ========================================================
        MONTO MINIMO DE APUESTA
        ======================================================== */

        DECLARE @MontoMinimo DECIMAL(12,2);


        SELECT @MontoMinimo =
            TRY_CONVERT(DECIMAL(12,2), Valor)
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'MONTO_MINIMO_APUESTA';


        IF @MontoMinimo IS NULL
        OR @MontoMinimo <= 0
            THROW 70436,
                'MONTO_MINIMO_APUESTA no contiene un valor válido.',
                1;


        /* ========================================================
        PORCENTAJE DE COMISION
        ======================================================== */

        DECLARE @ComisionPorcentaje DECIMAL(7,4);


        SELECT @ComisionPorcentaje =
            TRY_CONVERT(DECIMAL(7,4), Valor)
        FROM dbo.ConfiguracionSistema
        WHERE Clave = 'COMISION_SERVICIO_PORCENTAJE';


        IF @ComisionPorcentaje IS NULL
        OR @ComisionPorcentaje < 0
        OR @ComisionPorcentaje > 100
            THROW 70437,
                'COMISION_SERVICIO_PORCENTAJE no contiene un valor válido.',
                1;


        /* ========================================================
        MONTO UTILIZADO EN LAS TRES APUESTAS

        Se utiliza al menos Q100.00, pero si la configuración
        aumenta el mínimo, la prueba se adapta automáticamente.
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

        Debe coincidir con la fórmula utilizada por
        sp_RealizarApuesta.
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


        DECLARE @TotalCargo DECIMAL(12,2) =
            @Monto + @ComisionEsperada;


        /* ========================================================
        VALIDAR SALDO SUFICIENTE

        Cada usuario debe poder cubrir:
        MONTO APOSTADO + COMISION.
        ======================================================== */

        IF @SaldoInicialA < @TotalCargo
        OR @SaldoInicialB < @TotalCargo
        OR @SaldoInicialC < @TotalCargo
            THROW 70438,
                'Uno o más usuarios no poseen saldo suficiente para apuesta más comisión.',
                1;


        /* ========================================================
        INFORMACION DE CONTROL
        ======================================================== */

        PRINT '';
        PRINT 'Monto apostado: '
            + CONVERT(VARCHAR(30), @Monto);

        PRINT 'Comisión esperada por boleto: '
            + CONVERT(VARCHAR(30), @ComisionEsperada);

        PRINT 'Cargo total por usuario: '
            + CONVERT(VARCHAR(30), @TotalCargo);


    /* ========================================================
        8. TRES APUESTAS:
            A -> GANADOR
            B -> PERDEDOR
            C -> ANULADO
        ======================================================== */

        /* ========================================================
        JSON DE SELECCIONES
        ======================================================== */

        DECLARE @JsonA NVARCHAR(MAX) =
            N'[' + CONVERT(NVARCHAR(20), @IdSeleccionA) + N']';


        DECLARE @JsonB NVARCHAR(MAX) =
            N'[' + CONVERT(NVARCHAR(20), @IdSeleccionB) + N']';


        DECLARE @JsonC NVARCHAR(MAX) =
            N'[' + CONVERT(NVARCHAR(20), @IdSeleccionC) + N']';


        /* ========================================================
        REFERENCIAS IDEMPOTENTES
        ======================================================== */

        DECLARE @ReferenciaA UNIQUEIDENTIFIER = NEWID();
        DECLARE @ReferenciaB UNIQUEIDENTIFIER = NEWID();
        DECLARE @ReferenciaC UNIQUEIDENTIFIER = NEWID();


        /* ========================================================
        REALIZAR APUESTA A
        ======================================================== */

        EXEC dbo.sp_RealizarApuesta
            @IdUsuario = @IdUsuarioA,
            @SeleccionesJson = @JsonA,
            @Monto = @Monto,
            @ReferenciaOperacion = @ReferenciaA,
            @IpOrigen = '127.0.0.1';


        /* ========================================================
        REALIZAR APUESTA B
        ======================================================== */

        EXEC dbo.sp_RealizarApuesta
            @IdUsuario = @IdUsuarioB,
            @SeleccionesJson = @JsonB,
            @Monto = @Monto,
            @ReferenciaOperacion = @ReferenciaB,
            @IpOrigen = '127.0.0.1';


        /* ========================================================
        REALIZAR APUESTA C
        ======================================================== */

        EXEC dbo.sp_RealizarApuesta
            @IdUsuario = @IdUsuarioC,
            @SeleccionesJson = @JsonC,
            @Monto = @Monto,
            @ReferenciaOperacion = @ReferenciaC,
            @IpOrigen = '127.0.0.1';


        /* ========================================================
        RECUPERAR LOS TRES BOLETOS
        ======================================================== */

        DECLARE @IdBoletoA INT;
        DECLARE @IdBoletoB INT;
        DECLARE @IdBoletoC INT;


        SELECT @IdBoletoA = IdBoleto
        FROM dbo.Boleto
        WHERE ReferenciaOperacion = @ReferenciaA;


        SELECT @IdBoletoB = IdBoleto
        FROM dbo.Boleto
        WHERE ReferenciaOperacion = @ReferenciaB;


        SELECT @IdBoletoC = IdBoleto
        FROM dbo.Boleto
        WHERE ReferenciaOperacion = @ReferenciaC;


        IF @IdBoletoA IS NULL
        OR @IdBoletoB IS NULL
        OR @IdBoletoC IS NULL
            THROW 70439,
                'No se crearon correctamente los tres boletos.',
                1;


        /* ========================================================
        VALIDAR DATOS FINANCIEROS GUARDADOS EN BOLETO
        ======================================================== */

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Boleto
            WHERE IdBoleto IN
            (
                @IdBoletoA,
                @IdBoletoB,
                @IdBoletoC
            )
            AND
            (
                MontoApostado <> @Monto
                OR ComisionServicio <> @ComisionEsperada
                OR Resultado <> 'PENDIENTE'
            )
        )
            THROW 70440,
                'Monto, comisión o resultado inicial de uno de los boletos es incorrecto.',
                1;


        /* ========================================================
        VALIDAR QUE CADA BOLETO TENGA UN SOLO DETALLE
        ======================================================== */

        IF
        (
            SELECT COUNT(*)
            FROM dbo.DetalleBoleto
            WHERE IdBoleto IN
            (
                @IdBoletoA,
                @IdBoletoB,
                @IdBoletoC
            )
        ) <> 3
            THROW 70441,
                'Los tres boletos deben contener exactamente un detalle cada uno.',
                1;


        /* ========================================================
        VALIDAR SELECCION CORRECTA EN CADA BOLETO
        ======================================================== */

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.DetalleBoleto
            WHERE IdBoleto = @IdBoletoA
            AND IdSeleccion = @IdSeleccionA
        )
            THROW 70442,
                'El boleto A no contiene la selección A.',
                1;


        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.DetalleBoleto
            WHERE IdBoleto = @IdBoletoB
            AND IdSeleccion = @IdSeleccionB
        )
            THROW 70443,
                'El boleto B no contiene la selección B.',
                1;


        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.DetalleBoleto
            WHERE IdBoleto = @IdBoletoC
            AND IdSeleccion = @IdSeleccionC
        )
            THROW 70444,
                'El boleto C no contiene la selección C.',
                1;


        /* ========================================================
        VALIDAR BILLETERAS DESPUES DE LAS APUESTAS

        Disponible:
            inicial - apuesta - comisión

        Comprometido:
            inicial + apuesta
        ======================================================== */

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Billetera
            WHERE IdUsuario = @IdUsuarioA
            AND
            (
                SaldoDisponible <>
                    @SaldoInicialA - @TotalCargo

                OR SaldoComprometido <>
                    @ComprometidoInicialA + @Monto
            )
        )
            THROW 70445,
                'La billetera del usuario A quedó incorrecta después de apostar.',
                1;


        IF EXISTS
        (
            SELECT 1
            FROM dbo.Billetera
            WHERE IdUsuario = @IdUsuarioB
            AND
            (
                SaldoDisponible <>
                    @SaldoInicialB - @TotalCargo

                OR SaldoComprometido <>
                    @ComprometidoInicialB + @Monto
            )
        )
            THROW 70446,
                'La billetera del usuario B quedó incorrecta después de apostar.',
                1;


        IF EXISTS
        (
            SELECT 1
            FROM dbo.Billetera
            WHERE IdUsuario = @IdUsuarioC
            AND
            (
                SaldoDisponible <>
                    @SaldoInicialC - @TotalCargo

                OR SaldoComprometido <>
                    @ComprometidoInicialC + @Monto
            )
        )
            THROW 70447,
                'La billetera del usuario C quedó incorrecta después de apostar.',
                1;


        /* ========================================================
        VALIDAR COMISIONES ACREDITADAS A CASA

        Cada apuesta acredita una comisión.
        Por lo tanto:

        CASA =
            saldo inicial
            + comisión A
            + comisión B
            + comisión C
        ======================================================== */

        DECLARE @SaldoCasaPostApuestas DECIMAL(12,2);


        SELECT @SaldoCasaPostApuestas = SaldoDisponible
        FROM dbo.Billetera
        WHERE IdBilletera = @IdBilleteraCasa;


        DECLARE @SaldoCasaEsperadoPostApuestas DECIMAL(12,2) =
            @SaldoCasaInicial
            + (@ComisionEsperada * 3);


        IF @SaldoCasaPostApuestas <>
        @SaldoCasaEsperadoPostApuestas
            THROW 70448,
                'CASA no recibió correctamente las comisiones de las tres apuestas.',
                1;


        /* ========================================================
        VALIDAR TRANSACCIONES DE COMISION

        Si la comisión es mayor a cero deben existir:
        - 1 comisión cobrada al usuario.
        - 1 comisión acreditada a CASA.

        Por cada boleto.
        ======================================================== */

        IF @ComisionEsperada > 0
        BEGIN

            IF
            (
                SELECT COUNT(*)
                FROM dbo.TransaccionFinanciera AS TF
                INNER JOIN dbo.TipoTransaccion AS TT
                    ON TT.IdTipoTransaccion = TF.IdTipoTransaccion
                WHERE TF.IdBoleto IN
                (
                    @IdBoletoA,
                    @IdBoletoB,
                    @IdBoletoC
                )
                AND TT.Codigo = 'COMISION_SERVICIO'
            ) <> 6
                THROW 70449,
                    'Deben existir seis transacciones de comisión para los tres boletos.',
                    1;


            IF
            (
                SELECT COUNT(*)
                FROM dbo.TransaccionFinanciera AS TF
                INNER JOIN dbo.TipoTransaccion AS TT
                    ON TT.IdTipoTransaccion = TF.IdTipoTransaccion
                WHERE TF.IdBoleto IN
                (
                    @IdBoletoA,
                    @IdBoletoB,
                    @IdBoletoC
                )
                AND TF.IdBilletera = @IdBilleteraCasa
                AND TF.Monto = @ComisionEsperada
                AND TT.Codigo = 'COMISION_SERVICIO'
            ) <> 3
                THROW 70450,
                    'CASA debe poseer una comisión por cada boleto.',
                    1;

        END
        ELSE
        BEGIN

            IF EXISTS
            (
                SELECT 1
                FROM dbo.TransaccionFinanciera AS TF
                INNER JOIN dbo.TipoTransaccion AS TT
                    ON TT.IdTipoTransaccion = TF.IdTipoTransaccion
                WHERE TF.IdBoleto IN
                (
                    @IdBoletoA,
                    @IdBoletoB,
                    @IdBoletoC
                )
                AND TT.Codigo = 'COMISION_SERVICIO'
            )
                THROW 70451,
                    'Existen transacciones de comisión aunque la comisión configurada es cero.',
                    1;

        END;


        /* ========================================================
        VALIDAR TRANSACCIONES PRINCIPALES DE APUESTA
        ======================================================== */

        IF
        (
            SELECT COUNT(*)
            FROM dbo.TransaccionFinanciera AS TF
            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion
            WHERE TF.IdBoleto IN
            (
                @IdBoletoA,
                @IdBoletoB,
                @IdBoletoC
            )
            AND TT.Codigo = 'APUESTA'
        ) <> 3
            THROW 70452,
                'Debe existir exactamente una transacción APUESTA por boleto.',
                1;


        PRINT '';
        PRINT 'Tres apuestas registradas: OK';
        PRINT 'Boleto A preparado como futuro GANADOR: OK';
        PRINT 'Boleto B preparado como futuro PERDEDOR: OK';
        PRINT 'Boleto C preparado como futuro ANULADO: OK';
        PRINT 'Comisiones de servicio iniciales: OK';
        PRINT 'Billeteras y saldo CASA posteriores a apuesta: OK';


    /* ========================================================
        9. EVENTO EN VIVO
        ======================================================== */

        EXEC dbo.sp_CambiarEstadoEvento
            @IdUsuarioProceso = @IdAdministrador,
            @IdEvento = @IdEvento,
            @NuevoEstado = 'EN_VIVO',
            @Motivo = 'Inicio simulado del evento.',
            @IpOrigen = '127.0.0.1';


        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Evento AS EV

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = EV.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
            AND TE.Codigo = 'EVENTO'

            WHERE EV.IdEvento = @IdEvento
            AND E.Codigo = 'EN_VIVO'
        )
            THROW 70453,
                'El evento no cambió correctamente a EN_VIVO.',
                1;


        /* ========================================================
            10. CERRAR MERCADO PRINCIPAL
                Y ANULAR MERCADO SECUNDARIO
            ======================================================== */

            /* ========================================================
            MERCADO PRINCIPAL -> CERRADO
            ======================================================== */

            EXEC dbo.sp_CambiarEstadoMercado
                @IdUsuarioProceso = @IdAdministrador,
                @IdMercado = @IdMercado,
                @NuevoEstado = 'CERRADO',
                @Motivo = 'Evento finalizado para prueba.',
                @IpOrigen = '127.0.0.1';


            /* ========================================================
            MERCADO SECUNDARIO -> ANULADO

            Este mercado se utiliza para comprobar el flujo
            de devolución total del boleto C.
            ======================================================== */

            EXEC dbo.sp_CambiarEstadoMercado
                @IdUsuarioProceso = @IdAdministrador,
                @IdMercado = @IdMercadoAnulado,
                @NuevoEstado = 'ANULADO',
                @Motivo = 'Mercado anulado para prueba de devolución total.',
                @IpOrigen = '127.0.0.1';


            /* ========================================================
            VALIDAR MERCADO PRINCIPAL CERRADO
            ======================================================== */

            IF NOT EXISTS
            (
                SELECT 1

                FROM dbo.Mercado AS M

                INNER JOIN dbo.Estado AS E
                    ON E.IdEstado = M.IdEstado

                INNER JOIN dbo.TipoEstado AS TE
                    ON TE.IdTipoEstado = E.IdTipoEstado
                AND TE.Codigo = 'MERCADO'

                WHERE M.IdMercado = @IdMercado
                AND E.Codigo = 'CERRADO'
            )
                THROW 70454,
                    'El mercado principal debe quedar CERRADO.',
                    1;


            /* ========================================================
            VALIDAR MERCADO SECUNDARIO ANULADO
            ======================================================== */

            IF NOT EXISTS
            (
                SELECT 1

                FROM dbo.Mercado AS M

                INNER JOIN dbo.Estado AS E
                    ON E.IdEstado = M.IdEstado

                INNER JOIN dbo.TipoEstado AS TE
                    ON TE.IdTipoEstado = E.IdTipoEstado
                AND TE.Codigo = 'MERCADO'

                WHERE M.IdMercado = @IdMercadoAnulado
                AND E.Codigo = 'ANULADO'
            )
                THROW 70509,
                    'El mercado secundario debe quedar ANULADO.',
                    1;


            PRINT '';
            PRINT 'Mercado principal -> CERRADO: OK';
            PRINT 'Mercado secundario -> ANULADO: OK';


        /* ========================================================
        11. EVENTO -> PENDIENTE_RESULTADO
        ======================================================== */

        EXEC dbo.sp_CambiarEstadoEvento
            @IdUsuarioProceso = @IdAdministrador,
            @IdEvento = @IdEvento,
            @NuevoEstado = 'PENDIENTE_RESULTADO',
            @Motivo = 'Esperando resultado oficial.',
            @IpOrigen = '127.0.0.1';


        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Evento AS EV

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = EV.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
            AND TE.Codigo = 'EVENTO'

            WHERE EV.IdEvento = @IdEvento
            AND E.Codigo = 'PENDIENTE_RESULTADO'
        )
            THROW 70455,
                'El evento no cambió correctamente a PENDIENTE_RESULTADO.',
                1;


        PRINT '';
        PRINT 'Evento EN_VIVO: OK';
        PRINT 'Mercados principal y anulado CERRADOS: OK';
        PRINT 'Evento PENDIENTE_RESULTADO: OK';

    /* ========================================================
        12. REGISTRAR RESULTADO
        ======================================================== */

        EXEC dbo.sp_RegistrarResultadoEvento
            @IdUsuarioProceso = @IdAdministrador,
            @IdEvento = @IdEvento,
            @ResultadoTexto = 'Equipo A 2 - 1 Equipo B',
            @Observacion =
                'Resultado de prueba. Mercado principal resuelto y mercado secundario anulado.',
            @IpOrigen = '127.0.0.1';


        DECLARE @IdResultadoEvento INT;


        SELECT @IdResultadoEvento = IdResultado
        FROM dbo.ResultadoEvento
        WHERE IdEvento = @IdEvento;


        IF @IdResultadoEvento IS NULL
            THROW 70456,
                'No se creó ResultadoEvento.',
                1;


        /* ========================================================
        13. RESOLVER LAS TRES SELECCIONES

        A -> GANADA
        B -> PERDIDA
        C -> ANULADA
        ======================================================== */

        EXEC dbo.sp_ResolverSeleccion
            @IdUsuarioProceso = @IdAdministrador,
            @IdResultadoEvento = @IdResultadoEvento,
            @IdSeleccion = @IdSeleccionA,
            @Resultado = 'GANADA',
            @Observacion = 'Equipo A ganó el evento.',
            @IpOrigen = '127.0.0.1';


        EXEC dbo.sp_ResolverSeleccion
            @IdUsuarioProceso = @IdAdministrador,
            @IdResultadoEvento = @IdResultadoEvento,
            @IdSeleccion = @IdSeleccionB,
            @Resultado = 'PERDIDA',
            @Observacion = 'Equipo B perdió el evento.',
            @IpOrigen = '127.0.0.1';


        EXEC dbo.sp_ResolverSeleccion
            @IdUsuarioProceso = @IdAdministrador,
            @IdResultadoEvento = @IdResultadoEvento,
            @IdSeleccion = @IdSeleccionC,
            @Resultado = 'ANULADA',
            @Observacion =
                'Selección del mercado secundario anulada para prueba de devolución total.',
            @IpOrigen = '127.0.0.1';


        /* ========================================================
        VALIDAR RESOLUCIONES REGISTRADAS

        Todavía NO validamos DetalleBoleto.
        Esa propagación debe ocurrir al oficializar el resultado.
        ======================================================== */

        IF
        (
            SELECT COUNT(*)
            FROM dbo.ResolucionSeleccion
            WHERE IdResultadoEvento = @IdResultadoEvento
            AND IdSeleccion IN
            (
                @IdSeleccionA,
                @IdSeleccionB,
                @IdSeleccionC
            )
        ) <> 3
            THROW 70457,
                'No se registraron las tres resoluciones de selección.',
                1;


        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.ResolucionSeleccion
            WHERE IdResultadoEvento = @IdResultadoEvento
            AND IdSeleccion = @IdSeleccionA
            AND Resultado = 'GANADA'
        )
            THROW 70458,
                'La selección A no quedó resuelta como GANADA.',
                1;


        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.ResolucionSeleccion
            WHERE IdResultadoEvento = @IdResultadoEvento
            AND IdSeleccion = @IdSeleccionB
            AND Resultado = 'PERDIDA'
        )
            THROW 70459,
                'La selección B no quedó resuelta como PERDIDA.',
                1;


        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.ResolucionSeleccion
            WHERE IdResultadoEvento = @IdResultadoEvento
            AND IdSeleccion = @IdSeleccionC
            AND Resultado = 'ANULADA'
        )
            THROW 70460,
                'La selección C no quedó resuelta como ANULADA.',
                1;


        PRINT '';
        PRINT 'ResultadoEvento registrado: OK';
        PRINT 'Selección A -> GANADA: OK';
        PRINT 'Selección B -> PERDIDA: OK';
        PRINT 'Selección C -> ANULADA: OK';


    /* ========================================================
        14. OFICIALIZAR RESULTADO
        ======================================================== */

        EXEC dbo.sp_OficializarResultadoEvento
            @IdUsuarioProceso = @IdAdministrador,
            @IdResultadoEvento = @IdResultadoEvento,
            @Observacion =
                'Resultado oficial de prueba con escenario ganador, perdedor y anulado.',
            @IpOrigen = '127.0.0.1';


        /* ========================================================
        VALIDAR RESULTADO EVENTO = OFICIAL
        ======================================================== */

        IF NOT EXISTS
        (
            SELECT 1

            FROM dbo.ResultadoEvento AS RE

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = RE.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
            AND TE.Codigo = 'RESULTADO_EVENTO'

            WHERE RE.IdResultado = @IdResultadoEvento
            AND E.Codigo = 'OFICIAL'
        )
            THROW 70461,
                'El resultado del evento no quedó OFICIAL.',
                1;


        /* ========================================================
        VALIDAR PROPAGACION AL BOLETO A
        ======================================================== */

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.DetalleBoleto
            WHERE IdBoleto = @IdBoletoA
            AND IdSeleccion = @IdSeleccionA
            AND Resultado = 'GANADA'
        )
            THROW 70462,
                'La selección GANADA no fue propagada al boleto A.',
                1;


        /* ========================================================
        VALIDAR PROPAGACION AL BOLETO B
        ======================================================== */

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.DetalleBoleto
            WHERE IdBoleto = @IdBoletoB
            AND IdSeleccion = @IdSeleccionB
            AND Resultado = 'PERDIDA'
        )
            THROW 70463,
                'La selección PERDIDA no fue propagada al boleto B.',
                1;


        /* ========================================================
        VALIDAR PROPAGACION AL BOLETO C
        ======================================================== */

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.DetalleBoleto
            WHERE IdBoleto = @IdBoletoC
            AND IdSeleccion = @IdSeleccionC
            AND Resultado = 'ANULADA'
        )
            THROW 70464,
                'La selección ANULADA no fue propagada al boleto C.',
                1;


        /* ========================================================
        NINGUN DETALLE DE LOS TRES BOLETOS DEBE CONTINUAR
        PENDIENTE DESPUES DE OFICIALIZAR EL RESULTADO
        ======================================================== */

        IF EXISTS
        (
            SELECT 1
            FROM dbo.DetalleBoleto
            WHERE IdBoleto IN
            (
                @IdBoletoA,
                @IdBoletoB,
                @IdBoletoC
            )
            AND Resultado = 'PENDIENTE'
        )
            THROW 70465,
                'Existen detalles PENDIENTES después de oficializar el resultado.',
                1;


        /* ========================================================
        LOS BOLETOS TODAVIA DEBEN ESTAR PENDIENTES DE LIQUIDACION

        El resultado deportivo ya está resuelto,
        pero GANADOR / PERDEDOR / ANULADO debe determinarlo
        sp_LiquidarBoleto.
        ======================================================== */

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Boleto AS B

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = B.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
            AND TE.Codigo = 'BOLETO'

            WHERE B.IdBoleto IN
            (
                @IdBoletoA,
                @IdBoletoB,
                @IdBoletoC
            )
            AND
            (
                B.Resultado <> 'PENDIENTE'
                OR E.Codigo <> 'PENDIENTE'
            )
        )
            THROW 70466,
                'Uno de los boletos cambió de resultado o estado antes de su liquidación.',
                1;


        PRINT '';
        PRINT 'ResultadoEvento -> OFICIAL: OK';
        PRINT 'Boleto A: Detalle -> GANADA: OK';
        PRINT 'Boleto B: Detalle -> PERDIDA: OK';
        PRINT 'Boleto C: Detalle -> ANULADA: OK';
        PRINT 'Sin detalles PENDIENTES: OK';
        PRINT 'Los tres boletos permanecen pendientes de liquidación: OK';


    /* ========================================================
        15. BOLETOS LISTOS PARA LIQUIDAR

        Deben aparecer los tres escenarios:
        A -> GANADOR propuesto
        B -> PERDEDOR propuesto
        C -> ANULADO propuesto
        ======================================================== */

        EXEC dbo.sp_ObtenerBoletosListosLiquidar
            @IdUsuarioProceso = @IdAdministrador,
            @Cantidad = 100;


        /* ========================================================
        VALIDAR DIRECTAMENTE QUE LOS TRES BOLETOS
        CUMPLEN LAS CONDICIONES DE LIQUIDACION
        ======================================================== */

        IF
        (
            SELECT COUNT(*)

            FROM dbo.Boleto AS B

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = B.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
            AND TE.Codigo = 'BOLETO'

            WHERE B.IdBoleto IN
            (
                @IdBoletoA,
                @IdBoletoB,
                @IdBoletoC
            )

            AND E.Codigo = 'PENDIENTE'

            AND EXISTS
            (
                SELECT 1
                FROM dbo.DetalleBoleto AS DB
                WHERE DB.IdBoleto = B.IdBoleto
            )

            AND NOT EXISTS
            (
                SELECT 1
                FROM dbo.DetalleBoleto AS DB
                WHERE DB.IdBoleto = B.IdBoleto
                    AND DB.Resultado = 'PENDIENTE'
            )

            AND NOT EXISTS
            (
                SELECT 1

                FROM dbo.LiquidacionBoleto AS LB

                INNER JOIN dbo.Estado AS EL
                    ON EL.IdEstado = LB.IdEstado

                INNER JOIN dbo.TipoEstado AS TEL
                    ON TEL.IdTipoEstado = EL.IdTipoEstado
                    AND TEL.Codigo = 'LIQUIDACION'

                WHERE LB.IdBoleto = B.IdBoleto
                    AND EL.Codigo = 'COMPLETADA'
            )
        ) <> 3
            THROW 70467,
                'Los tres boletos deben estar listos para liquidación.',
                1;


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
        18. LIQUIDAR ANULADO

        Este caso debe:
        - devolver el monto apostado;
        - liberar el saldo comprometido;
        - devolver la comisión de servicio;
        - no generar ganancia ni pérdida de apuesta para CASA.
        ======================================================== */

        EXEC dbo.sp_LiquidarBoleto
            @IdUsuarioProceso = @IdAdministrador,
            @IdBoleto = @IdBoletoC,
            @IpOrigen = '127.0.0.1';


        PRINT '';
        PRINT 'Boleto A liquidado como escenario GANADOR: OK';
        PRINT 'Boleto B liquidado como escenario PERDEDOR: OK';
        PRINT 'Boleto C liquidado como escenario ANULADO: OK';


    /* ========================================================
        19. VALIDAR RESULTADO FINAL DE LOS TRES BOLETOS
        ======================================================== */

        /* ========================================================
        BOLETO A -> GANADOR / LIQUIDADO
        ======================================================== */

        IF NOT EXISTS
        (
            SELECT 1

            FROM dbo.Boleto AS B

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = B.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
            AND TE.Codigo = 'BOLETO'

            WHERE B.IdBoleto = @IdBoletoA
            AND B.Resultado = 'GANADOR'
            AND E.Codigo = 'LIQUIDADO'
            AND B.FechaLiquidacion IS NOT NULL
        )
            THROW 70468,
                'El boleto A no quedó GANADOR y LIQUIDADO.',
                1;


        /* ========================================================
        BOLETO B -> PERDEDOR / LIQUIDADO
        ======================================================== */

        IF NOT EXISTS
        (
            SELECT 1

            FROM dbo.Boleto AS B

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = B.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
            AND TE.Codigo = 'BOLETO'

            WHERE B.IdBoleto = @IdBoletoB
            AND B.Resultado = 'PERDEDOR'
            AND E.Codigo = 'LIQUIDADO'
            AND B.FechaLiquidacion IS NOT NULL
        )
            THROW 70469,
                'El boleto B no quedó PERDEDOR y LIQUIDADO.',
                1;


        /* ========================================================
        BOLETO C -> ANULADO / ANULADO
        ======================================================== */

        IF NOT EXISTS
        (
            SELECT 1

            FROM dbo.Boleto AS B

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = B.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
            AND TE.Codigo = 'BOLETO'

            WHERE B.IdBoleto = @IdBoletoC
            AND B.Resultado = 'ANULADO'
            AND E.Codigo = 'ANULADO'
            AND B.FechaLiquidacion IS NOT NULL
        )
            THROW 70470,
                'El boleto C no quedó ANULADO.',
                1;


        /* ========================================================
        VALIDAR REGISTROS DE LIQUIDACION
        ======================================================== */

        DECLARE @PagoEsperadoA DECIMAL(12,2) =
            CONVERT
            (
                DECIMAL(12,2),
                ROUND(@Monto * 1.8500, 2)
            );


        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.LiquidacionBoleto
            WHERE IdBoleto = @IdBoletoA
            AND MontoLiquidado = @PagoEsperadoA
            AND FechaFinalizacion IS NOT NULL
        )
            THROW 70471,
                'La liquidación del boleto ganador tiene un monto incorrecto.',
                1;


        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.LiquidacionBoleto
            WHERE IdBoleto = @IdBoletoB
            AND MontoLiquidado = 0
            AND FechaFinalizacion IS NOT NULL
        )
            THROW 70472,
                'La liquidación del boleto perdedor es incorrecta.',
                1;


        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.LiquidacionBoleto
            WHERE IdBoleto = @IdBoletoC
            AND MontoLiquidado = @Monto
            AND FechaFinalizacion IS NOT NULL
        )
            THROW 70473,
                'La liquidación del boleto anulado no devolvió el monto apostado.',
                1;


        /* ========================================================
        20. VALIDAR SALDO DEL GANADOR

        Después de apostar:
            Disponible =
                inicial - monto - comisión

        Después de ganar:
            Disponible =
                inicial - monto - comisión + premio

        La comisión NO se devuelve al ganador.
        ======================================================== */

        DECLARE @SaldoFinalA DECIMAL(12,2);
        DECLARE @ComprometidoFinalA DECIMAL(12,2);


        SELECT
            @SaldoFinalA = SaldoDisponible,
            @ComprometidoFinalA = SaldoComprometido
        FROM dbo.Billetera
        WHERE IdUsuario = @IdUsuarioA;


        DECLARE @SaldoEsperadoFinalA DECIMAL(12,2) =
            @SaldoInicialA
            - @TotalCargo
            + @PagoEsperadoA;


        IF @SaldoFinalA <> @SaldoEsperadoFinalA
            THROW 70474,
                'El saldo disponible final del usuario ganador es incorrecto.',
                1;


        IF @ComprometidoFinalA <> @ComprometidoInicialA
            THROW 70475,
                'El saldo comprometido del ganador no regresó a su valor inicial.',
                1;


        /* ========================================================
        21. VALIDAR SALDO DEL PERDEDOR

        Pierde:
        - monto apostado;
        - comisión de servicio.

        No recibe devolución.
        ======================================================== */

        DECLARE @SaldoFinalB DECIMAL(12,2);
        DECLARE @ComprometidoFinalB DECIMAL(12,2);


        SELECT
            @SaldoFinalB = SaldoDisponible,
            @ComprometidoFinalB = SaldoComprometido
        FROM dbo.Billetera
        WHERE IdUsuario = @IdUsuarioB;


        DECLARE @SaldoEsperadoFinalB DECIMAL(12,2) =
            @SaldoInicialB
            - @TotalCargo;


        IF @SaldoFinalB <> @SaldoEsperadoFinalB
            THROW 70476,
                'El saldo disponible final del usuario perdedor es incorrecto.',
                1;


        IF @ComprometidoFinalB <> @ComprometidoInicialB
            THROW 70477,
                'El saldo comprometido del perdedor no regresó a su valor inicial.',
                1;


        /* ========================================================
        22. VALIDAR SALDO DEL ANULADO

        El boleto totalmente anulado debe devolver:
        - monto apostado;
        - comisión de servicio.

        Por lo tanto, el usuario debe terminar exactamente
        con sus saldos iniciales.
        ======================================================== */

        DECLARE @SaldoFinalC DECIMAL(12,2);
        DECLARE @ComprometidoFinalC DECIMAL(12,2);


        SELECT
            @SaldoFinalC = SaldoDisponible,
            @ComprometidoFinalC = SaldoComprometido
        FROM dbo.Billetera
        WHERE IdUsuario = @IdUsuarioC;


        IF @SaldoFinalC <> @SaldoInicialC
            THROW 70478,
                'El usuario del boleto anulado no recuperó monto y comisión completamente.',
                1;


        IF @ComprometidoFinalC <> @ComprometidoInicialC
            THROW 70479,
                'El saldo comprometido del usuario anulado no regresó a su valor inicial.',
                1;


        PRINT '';
        PRINT 'Boleto A -> GANADOR / LIQUIDADO: OK';
        PRINT 'Boleto B -> PERDEDOR / LIQUIDADO: OK';
        PRINT 'Boleto C -> ANULADO: OK';
        PRINT 'Monto liquidado ganador: OK';
        PRINT 'Monto liquidado perdedor: OK';
        PRINT 'Devolución del monto anulado: OK';
        PRINT 'Saldo ganador considerando comisión: OK';
        PRINT 'Saldo perdedor considerando comisión: OK';
        PRINT 'Saldo anulado restituido completamente: OK';
        PRINT 'Saldos comprometidos regresaron a su valor inicial: OK';

    /* ========================================================
        23. VALIDAR SALDO FINAL DE CASA

        CASA conserva:
        - comisión del boleto ganador;
        - comisión del boleto perdedor.

        CASA recibe:
        - monto apostado del boleto perdedor.

        CASA paga:
        - ganancia neta del boleto ganador;
        - comisión del boleto totalmente anulado.

        El monto apostado del boleto anulado NO pasa por CASA;
        simplemente vuelve de comprometido a disponible
        en la billetera del usuario.
        ======================================================== */

        DECLARE @SaldoCasaFinal DECIMAL(12,2);


        SELECT @SaldoCasaFinal = SaldoDisponible
        FROM dbo.Billetera
        WHERE IdBilletera = @IdBilleteraCasa;


        IF @SaldoCasaFinal IS NULL
            THROW 70480,
                'No fue posible obtener el saldo final de CASA.',
                1;


        /* ========================================================
        GANANCIA NETA QUE CASA DEBE PAGAR AL GANADOR
        ======================================================== */

        DECLARE @GananciaNetaGanador DECIMAL(12,2) =
            @PagoEsperadoA - @Monto;


        /* ========================================================
        SALDO FINAL ESPERADO DE CASA

        Comisión A          + comisión
        Comisión B          + comisión
        Comisión C          + comisión inicialmente
        Anulación C         - comisión C
        Perdedor B          + monto apostado
        Ganador A           - ganancia neta

        Simplificado:
            inicial
            + 2 comisiones
            + monto perdido
            - ganancia neta ganador
        ======================================================== */

        DECLARE @SaldoCasaEsperado DECIMAL(12,2) =
            @SaldoCasaInicial
            + (@ComisionEsperada * 2)
            + @Monto
            - @GananciaNetaGanador;


        IF @SaldoCasaFinal <> @SaldoCasaEsperado
            THROW 70481,
                'El saldo final de CASA no refleja correctamente apuestas, premio y comisiones.',
                1;


        /* ========================================================
        24. VALIDAR TRANSACCIONES DEL BOLETO GANADOR
        ======================================================== */

        /* ========================================================
        PREMIO DEL USUARIO

        El usuario ganador recibe el pago total:
        monto apostado + ganancia neta.
        ======================================================== */

        IF
        (
            SELECT COUNT(*)

            FROM dbo.TransaccionFinanciera AS TF

            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

            INNER JOIN dbo.Billetera AS B
                ON B.IdBilletera = TF.IdBilletera

            WHERE TF.IdBoleto = @IdBoletoA
            AND B.IdUsuario = @IdUsuarioA
            AND TT.Codigo = 'PREMIO'
            AND TF.Monto = @PagoEsperadoA
        ) <> 1
            THROW 70482,
                'Debe existir exactamente una transacción PREMIO correcta para el ganador.',
                1;


        /* ========================================================
        PAGO DE GANANCIA NETA DESDE CASA

        CASA no paga nuevamente el monto apostado.
        Solo paga:
            premio total - monto apostado
        ======================================================== */

        IF
        (
            SELECT COUNT(*)

            FROM dbo.TransaccionFinanciera AS TF

            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

            WHERE TF.IdBoleto = @IdBoletoA
            AND TF.IdBilletera = @IdBilleteraCasa
            AND TT.Codigo = 'PAGO_PREMIO'
            AND TF.Monto = @GananciaNetaGanador
        ) <> 1
            THROW 70483,
                'Debe existir exactamente un PAGO_PREMIO correcto desde CASA.',
                1;


        /* ========================================================
        25. VALIDAR TRANSACCIONES DEL BOLETO PERDEDOR
        ======================================================== */

        /* ========================================================
        PERDIDA_APUESTA DEL USUARIO
        ======================================================== */

        IF
        (
            SELECT COUNT(*)

            FROM dbo.TransaccionFinanciera AS TF

            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

            INNER JOIN dbo.Billetera AS B
                ON B.IdBilletera = TF.IdBilletera

            WHERE TF.IdBoleto = @IdBoletoB
            AND B.IdUsuario = @IdUsuarioB
            AND TT.Codigo = 'PERDIDA_APUESTA'
            AND TF.Monto = @Monto
        ) <> 1
            THROW 70484,
                'Debe existir exactamente una PERDIDA_APUESTA correcta.',
                1;


        /* ========================================================
        GANANCIA_CASA

        CASA recibe el monto apostado completo del boleto perdido.
        ======================================================== */

        IF
        (
            SELECT COUNT(*)

            FROM dbo.TransaccionFinanciera AS TF

            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

            WHERE TF.IdBoleto = @IdBoletoB
            AND TF.IdBilletera = @IdBilleteraCasa
            AND TT.Codigo = 'GANANCIA_CASA'
            AND TF.Monto = @Monto
        ) <> 1
            THROW 70485,
                'Debe existir exactamente una GANANCIA_CASA correcta.',
                1;


        /* ========================================================
        26. VALIDAR TRANSACCIONES DEL BOLETO ANULADO
        ======================================================== */

        /* ========================================================
        DEVOLUCION DEL MONTO APOSTADO

        La transacción principal del usuario anulado debe devolver
        el monto que estaba comprometido.
        ======================================================== */

        IF
        (
            SELECT COUNT(*)

            FROM dbo.TransaccionFinanciera AS TF

            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

            INNER JOIN dbo.Billetera AS B
                ON B.IdBilletera = TF.IdBilletera

            WHERE TF.IdBoleto = @IdBoletoC
            AND B.IdUsuario = @IdUsuarioC
            AND TT.Codigo = 'DEVOLUCION'
            AND TF.Monto = @Monto
        ) <> 1
            THROW 70486,
                'Debe existir exactamente una DEVOLUCION del monto apostado para el boleto anulado.',
                1;


        /* ========================================================
        DEVOLUCION DE COMISION

        Si la comisión es mayor a cero deben existir dos
        transacciones DEVOLUCION_COMISION:

        1. Una acreditada nuevamente al usuario.
        2. Una contraparte registrada en CASA.
        ======================================================== */

        IF @ComisionEsperada > 0
        BEGIN

            IF
            (
                SELECT COUNT(*)

                FROM dbo.TransaccionFinanciera AS TF

                INNER JOIN dbo.TipoTransaccion AS TT
                    ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

                INNER JOIN dbo.Billetera AS B
                    ON B.IdBilletera = TF.IdBilletera

                WHERE TF.IdBoleto = @IdBoletoC
                AND B.IdUsuario = @IdUsuarioC
                AND TT.Codigo = 'DEVOLUCION_COMISION'
                AND TF.Monto = @ComisionEsperada
            ) <> 1
                THROW 70487,
                    'No existe exactamente una DEVOLUCION_COMISION para el usuario anulado.',
                    1;


            IF
            (
                SELECT COUNT(*)

                FROM dbo.TransaccionFinanciera AS TF

                INNER JOIN dbo.TipoTransaccion AS TT
                    ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

                WHERE TF.IdBoleto = @IdBoletoC
                AND TF.IdBilletera = @IdBilleteraCasa
                AND TT.Codigo = 'DEVOLUCION_COMISION'
                AND TF.Monto = @ComisionEsperada
            ) <> 1
                THROW 70488,
                    'CASA no registró correctamente la devolución de comisión.',
                    1;


            IF
            (
                SELECT COUNT(*)

                FROM dbo.TransaccionFinanciera AS TF

                INNER JOIN dbo.TipoTransaccion AS TT
                    ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

                WHERE TF.IdBoleto = @IdBoletoC
                AND TT.Codigo = 'DEVOLUCION_COMISION'
            ) <> 2
                THROW 70489,
                    'El boleto anulado debe poseer exactamente dos transacciones DEVOLUCION_COMISION.',
                    1;

        END
        ELSE
        BEGIN

            IF EXISTS
            (
                SELECT 1

                FROM dbo.TransaccionFinanciera AS TF

                INNER JOIN dbo.TipoTransaccion AS TT
                    ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

                WHERE TF.IdBoleto = @IdBoletoC
                AND TT.Codigo = 'DEVOLUCION_COMISION'
            )
                THROW 70490,
                    'Existen devoluciones de comisión aunque la comisión configurada sea cero.',
                    1;

        END;


        /* ========================================================
        VALIDAR QUE EL ANULADO NO GENERE GANANCIA PARA CASA
        ======================================================== */

        IF EXISTS
        (
            SELECT 1

            FROM dbo.TransaccionFinanciera AS TF

            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

            WHERE TF.IdBoleto = @IdBoletoC
            AND TT.Codigo IN
            (
                'GANANCIA_CASA',
                'PAGO_PREMIO'
            )
        )
            THROW 70491,
                'Un boleto totalmente anulado no debe generar GANANCIA_CASA ni PAGO_PREMIO.',
                1;


        PRINT '';
        PRINT 'Saldo final de CASA: OK';
        PRINT 'Comisiones retenidas de ganador y perdedor: OK';
        PRINT 'Comisión del boleto anulado devuelta: OK';
        PRINT 'PREMIO del ganador: OK';
        PRINT 'PAGO_PREMIO de CASA: OK';
        PRINT 'PERDIDA_APUESTA: OK';
        PRINT 'GANANCIA_CASA: OK';
        PRINT 'DEVOLUCION del boleto anulado: OK';

        IF @ComisionEsperada > 0
            PRINT 'DEVOLUCION_COMISION usuario + CASA: OK';

        PRINT 'Transacciones financieras de liquidación: OK';


    /* ========================================================
        27. IDEMPOTENCIA DE LIQUIDACION

        Repetir la liquidacion de:
        - GANADOR
        - PERDEDOR
        - ANULADO

        NO debe:
        - crear nuevas liquidaciones;
        - crear nuevas transacciones;
        - crear nuevos movimientos de billetera;
        - volver a pagar premio;
        - volver a acreditar ganancia a CASA;
        - volver a devolver monto;
        - volver a devolver comision;
        - modificar saldos.
        ======================================================== */

        PRINT '';
        PRINT 'PRUEBA DE IDEMPOTENCIA DE LIQUIDACION';


        /* ========================================================
        CAPTURAR CANTIDADES ANTES DE REPETIR
        ======================================================== */

        DECLARE @CantidadLiquidacionesAntes INT;
        DECLARE @CantidadTransaccionesAntes INT;
        DECLARE @CantidadMovimientosAntes INT;


        SELECT @CantidadLiquidacionesAntes = COUNT(*)
        FROM dbo.LiquidacionBoleto
        WHERE IdBoleto IN
        (
            @IdBoletoA,
            @IdBoletoB,
            @IdBoletoC
        );


        IF @CantidadLiquidacionesAntes <> 3
            THROW 70492,
                'Antes de probar idempotencia deben existir exactamente tres liquidaciones.',
                1;


        SELECT @CantidadTransaccionesAntes = COUNT(*)
        FROM dbo.TransaccionFinanciera
        WHERE IdBoleto IN
        (
            @IdBoletoA,
            @IdBoletoB,
            @IdBoletoC
        );


        SELECT @CantidadMovimientosAntes = COUNT(*)

        FROM dbo.MovimientoBilletera AS MB

        INNER JOIN dbo.TransaccionFinanciera AS TF
            ON TF.IdTransaccion = MB.IdTransaccion

        WHERE TF.IdBoleto IN
        (
            @IdBoletoA,
            @IdBoletoB,
            @IdBoletoC
        );


        /* ========================================================
        CAPTURAR SALDOS ANTES DE REPETIR
        ======================================================== */

        DECLARE @SaldoAAntesIdempotencia DECIMAL(12,2);
        DECLARE @ComprometidoAAntesIdempotencia DECIMAL(12,2);

        DECLARE @SaldoBAntesIdempotencia DECIMAL(12,2);
        DECLARE @ComprometidoBAntesIdempotencia DECIMAL(12,2);

        DECLARE @SaldoCAntesIdempotencia DECIMAL(12,2);
        DECLARE @ComprometidoCAntesIdempotencia DECIMAL(12,2);

        DECLARE @SaldoCasaAntesIdempotencia DECIMAL(12,2);
        DECLARE @ComprometidoCasaAntesIdempotencia DECIMAL(12,2);


        SELECT
            @SaldoAAntesIdempotencia = SaldoDisponible,
            @ComprometidoAAntesIdempotencia = SaldoComprometido
        FROM dbo.Billetera
        WHERE IdUsuario = @IdUsuarioA;


        SELECT
            @SaldoBAntesIdempotencia = SaldoDisponible,
            @ComprometidoBAntesIdempotencia = SaldoComprometido
        FROM dbo.Billetera
        WHERE IdUsuario = @IdUsuarioB;


        SELECT
            @SaldoCAntesIdempotencia = SaldoDisponible,
            @ComprometidoCAntesIdempotencia = SaldoComprometido
        FROM dbo.Billetera
        WHERE IdUsuario = @IdUsuarioC;


        SELECT
            @SaldoCasaAntesIdempotencia = SaldoDisponible,
            @ComprometidoCasaAntesIdempotencia = SaldoComprometido
        FROM dbo.Billetera
        WHERE IdBilletera = @IdBilleteraCasa;


        /* ========================================================
        REPETIR LIQUIDACION DEL GANADOR
        ======================================================== */

        EXEC dbo.sp_LiquidarBoleto
            @IdUsuarioProceso = @IdAdministrador,
            @IdBoleto = @IdBoletoA,
            @IpOrigen = '127.0.0.1';


        /* ========================================================
        REPETIR LIQUIDACION DEL PERDEDOR
        ======================================================== */

        EXEC dbo.sp_LiquidarBoleto
            @IdUsuarioProceso = @IdAdministrador,
            @IdBoleto = @IdBoletoB,
            @IpOrigen = '127.0.0.1';


        /* ========================================================
        REPETIR LIQUIDACION DEL ANULADO
        ======================================================== */

        EXEC dbo.sp_LiquidarBoleto
            @IdUsuarioProceso = @IdAdministrador,
            @IdBoleto = @IdBoletoC,
            @IpOrigen = '127.0.0.1';


        /* ========================================================
        27.1 NO DEBEN CREARSE NUEVAS LIQUIDACIONES
        ======================================================== */

        IF
        (
            SELECT COUNT(*)
            FROM dbo.LiquidacionBoleto
            WHERE IdBoleto IN
            (
                @IdBoletoA,
                @IdBoletoB,
                @IdBoletoC
            )
        ) <> @CantidadLiquidacionesAntes
            THROW 70493,
                'La repeticion idempotente creó liquidaciones adicionales.',
                1;


        /* Cada boleto debe seguir teniendo exactamente una. */

        IF
        (
            SELECT COUNT(*)
            FROM dbo.LiquidacionBoleto
            WHERE IdBoleto = @IdBoletoA
        ) <> 1
            THROW 70494,
                'El boleto ganador posee más de una liquidación.',
                1;


        IF
        (
            SELECT COUNT(*)
            FROM dbo.LiquidacionBoleto
            WHERE IdBoleto = @IdBoletoB
        ) <> 1
            THROW 70495,
                'El boleto perdedor posee más de una liquidación.',
                1;


        IF
        (
            SELECT COUNT(*)
            FROM dbo.LiquidacionBoleto
            WHERE IdBoleto = @IdBoletoC
        ) <> 1
            THROW 70496,
                'El boleto anulado posee más de una liquidación.',
                1;


        /* ========================================================
        27.2 NO DEBEN CREARSE TRANSACCIONES FINANCIERAS
        ======================================================== */

        IF
        (
            SELECT COUNT(*)
            FROM dbo.TransaccionFinanciera
            WHERE IdBoleto IN
            (
                @IdBoletoA,
                @IdBoletoB,
                @IdBoletoC
            )
        ) <> @CantidadTransaccionesAntes
            THROW 70497,
                'La repeticion de liquidacion creó transacciones financieras adicionales.',
                1;


        /* ========================================================
        27.3 NO DEBEN CREARSE MOVIMIENTOS DE BILLETERA
        ======================================================== */

        IF
        (
            SELECT COUNT(*)

            FROM dbo.MovimientoBilletera AS MB

            INNER JOIN dbo.TransaccionFinanciera AS TF
                ON TF.IdTransaccion = MB.IdTransaccion

            WHERE TF.IdBoleto IN
            (
                @IdBoletoA,
                @IdBoletoB,
                @IdBoletoC
            )
        ) <> @CantidadMovimientosAntes
            THROW 70498,
                'La repeticion de liquidacion creó movimientos de billetera adicionales.',
                1;


        /* ========================================================
        27.4 GANADOR NO DEBE CAMBIAR NUEVAMENTE
        ======================================================== */

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Billetera
            WHERE IdUsuario = @IdUsuarioA
            AND
            (
                SaldoDisponible <> @SaldoAAntesIdempotencia
                OR SaldoComprometido <> @ComprometidoAAntesIdempotencia
            )
        )
            THROW 70499,
                'La liquidacion idempotente modificó nuevamente al ganador.',
                1;


        /* ========================================================
        27.5 PERDEDOR NO DEBE CAMBIAR NUEVAMENTE
        ======================================================== */

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Billetera
            WHERE IdUsuario = @IdUsuarioB
            AND
            (
                SaldoDisponible <> @SaldoBAntesIdempotencia
                OR SaldoComprometido <> @ComprometidoBAntesIdempotencia
            )
        )
            THROW 70500,
                'La liquidacion idempotente modificó nuevamente al perdedor.',
                1;


        /* ========================================================
        27.6 ANULADO NO DEBE RECIBIR OTRA DEVOLUCION
        ======================================================== */

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Billetera
            WHERE IdUsuario = @IdUsuarioC
            AND
            (
                SaldoDisponible <> @SaldoCAntesIdempotencia
                OR SaldoComprometido <> @ComprometidoCAntesIdempotencia
            )
        )
            THROW 70501,
                'La liquidacion idempotente volvió a modificar al usuario anulado.',
                1;


        /* ========================================================
        27.7 CASA NO DEBE CAMBIAR NUEVAMENTE
        ======================================================== */

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Billetera
            WHERE IdBilletera = @IdBilleteraCasa
            AND
            (
                SaldoDisponible <> @SaldoCasaAntesIdempotencia
                OR SaldoComprometido <> @ComprometidoCasaAntesIdempotencia
            )
        )
            THROW 70502,
                'La liquidacion idempotente modificó nuevamente la billetera CASA.',
                1;


        /* ========================================================
        27.8 VALIDAR ESPECIFICAMENTE QUE NO SE DUPLICARON
        TRANSACCIONES CRITICAS
        ======================================================== */

        IF
        (
            SELECT COUNT(*)
            FROM dbo.TransaccionFinanciera AS TF
            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion
            WHERE TF.IdBoleto = @IdBoletoA
            AND TT.Codigo = 'PREMIO'
        ) <> 1
            THROW 70503,
                'La idempotencia alteró la cantidad de transacciones PREMIO.',
                1;


        IF
        (
            SELECT COUNT(*)
            FROM dbo.TransaccionFinanciera AS TF
            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion
            WHERE TF.IdBoleto = @IdBoletoB
            AND TT.Codigo = 'GANANCIA_CASA'
        ) <> 1
            THROW 70504,
                'La idempotencia alteró la cantidad de transacciones GANANCIA_CASA.',
                1;


        IF
        (
            SELECT COUNT(*)
            FROM dbo.TransaccionFinanciera AS TF
            INNER JOIN dbo.TipoTransaccion AS TT
                ON TT.IdTipoTransaccion = TF.IdTipoTransaccion
            WHERE TF.IdBoleto = @IdBoletoC
            AND TT.Codigo = 'DEVOLUCION'
        ) <> 1
            THROW 70505,
                'La idempotencia alteró la cantidad de transacciones DEVOLUCION.',
                1;


        IF @ComisionEsperada > 0
        BEGIN

            IF
            (
                SELECT COUNT(*)
                FROM dbo.TransaccionFinanciera AS TF
                INNER JOIN dbo.TipoTransaccion AS TT
                    ON TT.IdTipoTransaccion = TF.IdTipoTransaccion
                WHERE TF.IdBoleto = @IdBoletoC
                AND TT.Codigo = 'DEVOLUCION_COMISION'
            ) <> 2
                THROW 70506,
                    'La idempotencia duplicó o eliminó DEVOLUCION_COMISION.',
                    1;

        END;


        PRINT '';
        PRINT 'Idempotencia boleto GANADOR: OK';
        PRINT 'Idempotencia boleto PERDEDOR: OK';
        PRINT 'Idempotencia boleto ANULADO: OK';
        PRINT 'Sin nuevas liquidaciones: OK';
        PRINT 'Sin nuevas transacciones: OK';
        PRINT 'Sin nuevos movimientos de billetera: OK';
        PRINT 'Saldos de usuarios sin cambios: OK';
        PRINT 'Saldo CASA sin cambios: OK';
        PRINT 'Devolucion de comision no duplicada: OK';


    /* ========================================================
        28. CONSULTAR LAS TRES LIQUIDACIONES

        Cada propietario debe poder consultar su propia
        liquidacion.
        ======================================================== */

        PRINT '';
        PRINT 'CONSULTA DE LIQUIDACIONES';


        /* ========================================================
        GANADOR
        ======================================================== */

        EXEC dbo.sp_ObtenerLiquidacionBoleto
            @IdUsuarioSolicitante = @IdUsuarioA,
            @IdBoleto = @IdBoletoA;


        /* ========================================================
        PERDEDOR
        ======================================================== */

        EXEC dbo.sp_ObtenerLiquidacionBoleto
            @IdUsuarioSolicitante = @IdUsuarioB,
            @IdBoleto = @IdBoletoB;


        /* ========================================================
        ANULADO
        ======================================================== */

        EXEC dbo.sp_ObtenerLiquidacionBoleto
            @IdUsuarioSolicitante = @IdUsuarioC,
            @IdBoleto = @IdBoletoC;


        /* ========================================================
        29. VALIDACION FINAL DE LAS LIQUIDACIONES
        ======================================================== */

        IF
        (
            SELECT COUNT(*)

            FROM dbo.LiquidacionBoleto AS LB

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = LB.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
            AND TE.Codigo = 'LIQUIDACION'

            WHERE LB.IdBoleto IN
            (
                @IdBoletoA,
                @IdBoletoB,
                @IdBoletoC
            )
            AND E.Codigo = 'COMPLETADA'
            AND LB.FechaFinalizacion IS NOT NULL
        ) <> 3
            THROW 70507,
                'Las tres liquidaciones deben permanecer COMPLETADAS.',
                1;


        /* ========================================================
        VALIDAR RESULTADOS FINALES DE LOS TRES BOLETOS
        ======================================================== */

        IF
        (
            SELECT COUNT(*)
            FROM dbo.Boleto
            WHERE IdBoleto IN
            (
                @IdBoletoA,
                @IdBoletoB,
                @IdBoletoC
            )
            AND Resultado IN
            (
                'GANADOR',
                'PERDEDOR',
                'ANULADO'
            )
        ) <> 3
            THROW 70508,
                'Los tres boletos no conservan sus resultados finales esperados.',
                1;


        /* ========================================================
        RESULTADO FINAL
        ======================================================== */

        PRINT '';
        PRINT '=======================================================';
        PRINT ' RESULTADO: RESULTADOS Y LIQUIDACION CORRECTOS';
        PRINT '=======================================================';

        PRINT '';
        PRINT 'Escenarios comprobados:';

        PRINT 'Usuario A: GANADOR';
        PRINT 'Usuario B: PERDEDOR';
        PRINT 'Usuario C: ANULADO';

        PRINT '';
        PRINT 'Validaciones financieras:';

        PRINT 'Premio del ganador: OK';
        PRINT 'Perdida del perdedor: OK';
        PRINT 'Devolucion del boleto anulado: OK';

        IF @ComisionEsperada > 0
        BEGIN
            PRINT 'Comision retenida de ganador y perdedor: OK';
            PRINT 'Comision del boleto anulado devuelta: OK';
        END
        ELSE
        BEGIN
            PRINT 'Comision configurada en 0: escenario validado sin movimientos de comision.';
        END;

        PRINT 'Saldo comprometido de los tres usuarios liberado: OK';
        PRINT 'Saldo final de CASA: OK';

        PRINT '';
        PRINT 'Integridad:';

        PRINT 'Tres liquidaciones completadas: OK';
        PRINT 'Idempotencia de GANADOR: OK';
        PRINT 'Idempotencia de PERDEDOR: OK';
        PRINT 'Idempotencia de ANULADO: OK';
        PRINT 'Sin transacciones duplicadas: OK';
        PRINT 'Sin movimientos duplicados: OK';

        PRINT '';
        PRINT 'Consultas de liquidacion por propietario: OK';


        /* ========================================================
        ROLLBACK DE TODA LA PRUEBA
        ======================================================== */

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