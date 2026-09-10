/* ============================================================
   6. ANALITICA ADMINISTRATIVA POR EVENTO

   OBJETIVO:
   Mostrar a ADMINISTRADOR / AUDITOR la situación operativa
   y financiera de cada evento.

   IMPORTANTE:
   - Un boleto compuesto puede relacionarse con varios eventos.
   - Dentro de UN evento cada boleto se cuenta solamente una vez.
   - Los montos "relacionados" NO deben sumarse entre eventos
     para obtener totales globales, porque un boleto compuesto
     puede aparecer en más de un evento.
   - El dashboard global se calculará posteriormente a nivel
     de boleto para evitar duplicidades.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerAnaliticaEventosAdministracion
(
    @IdUsuarioSolicitante INT,
    @IdDeporte INT = NULL,
    @Vista VARCHAR(30) = 'TODOS',
    @HorasPrevia INT = 24,
    @Cantidad INT = 100
)
AS
BEGIN
    SET NOCOUNT ON;


    SET @Vista =
        UPPER
        (
            LTRIM
            (
                RTRIM
                (
                    COALESCE(@Vista, 'TODOS')
                )
            )
        );


    /* ========================================================
       SEGURIDAD
       ======================================================== */

    DECLARE @Rol VARCHAR(50);
    DECLARE @EstadoUsuario VARCHAR(40);


    SELECT
        @Rol = R.Nombre,
        @EstadoUsuario = E.Codigo

    FROM dbo.Usuario AS U

    INNER JOIN dbo.Rol AS R
        ON R.IdRol =
           U.IdRol

    INNER JOIN dbo.Estado AS E
        ON E.IdEstado =
           U.IdEstado

    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado =
           E.IdTipoEstado

       AND TE.Codigo =
           'USUARIO'

    WHERE U.IdUsuario =
          @IdUsuarioSolicitante;


    IF @Rol IS NULL
        THROW 64018,
            'El usuario solicitante no existe.',
            1;


    IF @EstadoUsuario <> 'ACTIVO'
        THROW 64019,
            'El usuario solicitante debe estar ACTIVO.',
            1;


    IF @Rol NOT IN
    (
        'ADMINISTRADOR',
        'AUDITOR'
    )
        THROW 64020,
            'El usuario no posee permisos para consultar analítica administrativa.',
            1;


    /* ========================================================
       FILTROS
       ======================================================== */

    IF @IdDeporte IS NOT NULL

       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Deporte
           WHERE IdDeporte =
                 @IdDeporte
             AND Activo = 1
       )
        THROW 64021,
            'El deporte indicado no existe o está inactivo.',
            1;


    IF @Vista NOT IN
    (
        'TODOS',
        'PROGRAMADOS',
        'PREVIA',
        'EN_PROGRESO',
        'PENDIENTE_RESULTADO',
        'FINALIZADOS',
        'BORRADOR',
        'SUSPENDIDOS',
        'CANCELADOS'
    )
        THROW 64022,
            'La vista administrativa solicitada no es válida.',
            1;


    IF @HorasPrevia IS NULL
       OR @HorasPrevia <= 0
        THROW 64023,
            'HorasPrevia debe ser mayor que cero.',
            1;


    IF @Cantidad IS NULL
       OR @Cantidad < 1
       OR @Cantidad > 500
        THROW 64024,
            'Cantidad debe estar entre 1 y 500.',
            1;


    DECLARE @AhoraSistema DATETIME2 =
        CAST
        (
            SYSUTCDATETIME()
            AT TIME ZONE 'UTC'
            AT TIME ZONE 'Central America Standard Time'
            AS DATETIME2
        );


    /* ========================================================
       BOLETOS RELACIONADOS CON CADA EVENTO

       DISTINCT evita contar varias veces el mismo boleto
       si contiene más de una selección del mismo evento.
       ======================================================== */

    ;WITH BoletosEvento AS
    (
        SELECT DISTINCT

            M.IdEvento,

            B.IdBoleto,
            B.IdUsuario,

            B.Resultado,

            B.MontoApostado,
            B.ComisionServicio,

            B.CuotaTotal,
            B.GananciaPotencial,

            B.FechaCreacion,

            LB.MontoLiquidado


        FROM dbo.Boleto AS B


        INNER JOIN dbo.DetalleBoleto AS DB
            ON DB.IdBoleto =
               B.IdBoleto


        INNER JOIN dbo.Seleccion AS S
            ON S.IdSeleccion =
               DB.IdSeleccion


        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado =
               S.IdMercado


        LEFT JOIN dbo.LiquidacionBoleto AS LB
            ON LB.IdBoleto =
               B.IdBoleto
    ),


    ResumenBoletos AS
    (
        SELECT

            BE.IdEvento,


            COUNT(*)
                AS BoletosRelacionados,


            COUNT
            (
                DISTINCT BE.IdUsuario
            ) AS ClientesUnicos,


            SUM
            (
                CASE
                    WHEN BE.Resultado = 'PENDIENTE'
                        THEN 1
                    ELSE 0
                END
            ) AS BoletosPendientes,


            SUM
            (
                CASE
                    WHEN BE.Resultado = 'GANADOR'
                        THEN 1
                    ELSE 0
                END
            ) AS BoletosGanadores,


            SUM
            (
                CASE
                    WHEN BE.Resultado = 'PERDEDOR'
                        THEN 1
                    ELSE 0
                END
            ) AS BoletosPerdedores,


            SUM
            (
                CASE
                    WHEN BE.Resultado = 'ANULADO'
                        THEN 1
                    ELSE 0
                END
            ) AS BoletosAnulados,


            SUM
            (
                BE.MontoApostado
            ) AS MontoApostadoRelacionado,


            SUM
            (
                BE.ComisionServicio
            ) AS ComisionRelacionada,


            SUM
            (
                CASE
                    WHEN BE.Resultado = 'PENDIENTE'
                        THEN BE.GananciaPotencial
                    ELSE 0
                END
            ) AS PremioPotencialPendienteRelacionado,


            /* =================================================
               EXPOSICION POTENCIAL

               Si el boleto gana:
               CASA paga ganancia neta.

               La comisión reduce parte de esa exposición.

               Nunca mostramos exposición negativa.
               ================================================= */

            SUM
            (
                CASE

                    WHEN BE.Resultado = 'PENDIENTE'

                     AND
                     (
                         BE.GananciaPotencial
                         - BE.MontoApostado
                         - BE.ComisionServicio
                     ) > 0

                        THEN
                            BE.GananciaPotencial
                            - BE.MontoApostado
                            - BE.ComisionServicio

                    ELSE 0

                END
            ) AS ExposicionPotencialRelacionada,


            /* =================================================
               RESULTADO REALIZADO DE CASA

               PERDEDOR:
                   apuesta + comisión.

               GANADOR:
                   comisión - ganancia neta pagada.

               ANULADO:
                   0.

               PENDIENTE:
                   todavía no realizado.
               ================================================= */

            SUM
            (
                CASE

                    WHEN BE.Resultado = 'PERDEDOR'
                        THEN
                            BE.MontoApostado
                            + BE.ComisionServicio


                    WHEN BE.Resultado = 'GANADOR'
                        THEN
                            BE.ComisionServicio

                            -
                            (
                                COALESCE
                                (
                                    BE.MontoLiquidado,
                                    0
                                )
                                - BE.MontoApostado
                            )


                    WHEN BE.Resultado = 'ANULADO'
                        THEN 0


                    ELSE 0

                END
            ) AS ResultadoCasaRealizadoRelacionado,


            AVG
            (
                CONVERT
                (
                    DECIMAL(19,6),
                    BE.CuotaTotal
                )
            ) AS CuotaPromedioBoletos,


            MAX
            (
                BE.FechaCreacion
            ) AS UltimaApuestaRelacionada


        FROM BoletosEvento AS BE


        GROUP BY
            BE.IdEvento
    ),


    ResumenMercados AS
    (
        SELECT

            M.IdEvento,


            COUNT
            (
                DISTINCT M.IdMercado
            ) AS CantidadMercados,


            COUNT
            (
                DISTINCT
                CASE
                    WHEN EM.Codigo = 'ABIERTO'
                        THEN M.IdMercado
                END
            ) AS MercadosAbiertos,


            COUNT
            (
                DISTINCT S.IdSeleccion
            ) AS CantidadSelecciones,


            COUNT
            (
                DISTINCT
                CASE
                    WHEN S.Activo = 1
                     AND C.IdCuota IS NOT NULL
                        THEN S.IdSeleccion
                END
            ) AS SeleccionesConCuotaActiva


        FROM dbo.Mercado AS M


        INNER JOIN dbo.Estado AS EM
            ON EM.IdEstado =
               M.IdEstado


        INNER JOIN dbo.TipoEstado AS TEM
            ON TEM.IdTipoEstado =
               EM.IdTipoEstado

           AND TEM.Codigo =
               'MERCADO'


        LEFT JOIN dbo.Seleccion AS S
            ON S.IdMercado =
               M.IdMercado


        LEFT JOIN dbo.Cuota AS C
            ON C.IdSeleccion =
               S.IdSeleccion

           AND C.Activo = 1


        GROUP BY
            M.IdEvento
    ),


    EventosAdministracion AS
    (
        SELECT

            EV.IdEvento,

            D.IdDeporte,
            D.Nombre AS Deporte,

            L.IdLiga,
            L.Nombre AS Liga,

            EV.Nombre AS Evento,

            EV.FechaInicio,
            EV.FechaFin,

            EE.Codigo AS EstadoEvento,


            CASE

                WHEN EE.Codigo = 'PROGRAMADO'
                 AND EV.FechaInicio > @AhoraSistema
                 AND EV.FechaInicio <=
                     DATEADD
                     (
                         HOUR,
                         @HorasPrevia,
                         @AhoraSistema
                     )

                    THEN 'PREVIA'


                WHEN EE.Codigo = 'PROGRAMADO'
                    THEN 'PROGRAMADO'


                WHEN EE.Codigo = 'EN_VIVO'
                    THEN 'EN_PROGRESO'


                WHEN EE.Codigo = 'PENDIENTE_RESULTADO'
                    THEN 'PENDIENTE_RESULTADO'


                WHEN EE.Codigo = 'FINALIZADO'
                    THEN 'FINALIZADO'


                WHEN EE.Codigo = 'BORRADOR'
                    THEN 'BORRADOR'


                WHEN EE.Codigo = 'SUSPENDIDO'
                    THEN 'SUSPENDIDO'


                WHEN EE.Codigo = 'CANCELADO'
                    THEN 'CANCELADO'


                ELSE EE.Codigo

            END AS EstadoVisual


        FROM dbo.Evento AS EV


        INNER JOIN dbo.Liga AS L
            ON L.IdLiga =
               EV.IdLiga


        INNER JOIN dbo.Deporte AS D
            ON D.IdDeporte =
               L.IdDeporte


        INNER JOIN dbo.Estado AS EE
            ON EE.IdEstado =
               EV.IdEstado


        INNER JOIN dbo.TipoEstado AS TEE
            ON TEE.IdTipoEstado =
               EE.IdTipoEstado

           AND TEE.Codigo =
               'EVENTO'


        WHERE
        (
            @IdDeporte IS NULL
            OR D.IdDeporte = @IdDeporte
        )
    )


    SELECT TOP (@Cantidad)

        EA.IdEvento,

        EA.IdDeporte,
        EA.Deporte,

        EA.IdLiga,
        EA.Liga,

        EA.Evento,

        EA.FechaInicio,
        EA.FechaFin,

        EA.EstadoEvento,
        EA.EstadoVisual,


        COALESCE
        (
            RM.CantidadMercados,
            0
        ) AS CantidadMercados,


        COALESCE
        (
            RM.MercadosAbiertos,
            0
        ) AS MercadosAbiertos,


        COALESCE
        (
            RM.CantidadSelecciones,
            0
        ) AS CantidadSelecciones,


        COALESCE
        (
            RM.SeleccionesConCuotaActiva,
            0
        ) AS SeleccionesConCuotaActiva,


        COALESCE
        (
            RB.BoletosRelacionados,
            0
        ) AS BoletosRelacionados,


        COALESCE
        (
            RB.ClientesUnicos,
            0
        ) AS ClientesUnicos,


        COALESCE
        (
            RB.BoletosPendientes,
            0
        ) AS BoletosPendientes,


        COALESCE
        (
            RB.BoletosGanadores,
            0
        ) AS BoletosGanadores,


        COALESCE
        (
            RB.BoletosPerdedores,
            0
        ) AS BoletosPerdedores,


        COALESCE
        (
            RB.BoletosAnulados,
            0
        ) AS BoletosAnulados,


        COALESCE
        (
            RB.MontoApostadoRelacionado,
            0
        ) AS MontoApostadoRelacionado,


        COALESCE
        (
            RB.ComisionRelacionada,
            0
        ) AS ComisionRelacionada,


        COALESCE
        (
            RB.PremioPotencialPendienteRelacionado,
            0
        ) AS PremioPotencialPendienteRelacionado,


        COALESCE
        (
            RB.ExposicionPotencialRelacionada,
            0
        ) AS ExposicionPotencialRelacionada,


        COALESCE
        (
            RB.ResultadoCasaRealizadoRelacionado,
            0
        ) AS ResultadoCasaRealizadoRelacionado,


        CONVERT
        (
            DECIMAL(12,4),
            RB.CuotaPromedioBoletos
        ) AS CuotaPromedioBoletos,


        RB.UltimaApuestaRelacionada


    FROM EventosAdministracion AS EA


    LEFT JOIN ResumenMercados AS RM
        ON RM.IdEvento =
           EA.IdEvento


    LEFT JOIN ResumenBoletos AS RB
        ON RB.IdEvento =
           EA.IdEvento


    WHERE
    (
        @Vista = 'TODOS'

        OR
        (
            @Vista = 'PROGRAMADOS'
            AND EA.EstadoVisual = 'PROGRAMADO'
        )

        OR
        (
            @Vista = 'PREVIA'
            AND EA.EstadoVisual = 'PREVIA'
        )

        OR
        (
            @Vista = 'EN_PROGRESO'
            AND EA.EstadoVisual = 'EN_PROGRESO'
        )

        OR
        (
            @Vista = 'PENDIENTE_RESULTADO'
            AND EA.EstadoVisual = 'PENDIENTE_RESULTADO'
        )

        OR
        (
            @Vista = 'FINALIZADOS'
            AND EA.EstadoVisual = 'FINALIZADO'
        )

        OR
        (
            @Vista = 'BORRADOR'
            AND EA.EstadoVisual = 'BORRADOR'
        )

        OR
        (
            @Vista = 'SUSPENDIDOS'
            AND EA.EstadoVisual = 'SUSPENDIDO'
        )

        OR
        (
            @Vista = 'CANCELADOS'
            AND EA.EstadoVisual = 'CANCELADO'
        )
    )


    ORDER BY

        CASE EA.EstadoVisual
            WHEN 'EN_PROGRESO' THEN 1
            WHEN 'PREVIA' THEN 2
            WHEN 'PROGRAMADO' THEN 3
            WHEN 'PENDIENTE_RESULTADO' THEN 4
            WHEN 'FINALIZADO' THEN 5
            WHEN 'SUSPENDIDO' THEN 6
            WHEN 'CANCELADO' THEN 7
            WHEN 'BORRADOR' THEN 8
            ELSE 9
        END,

        EA.FechaInicio DESC;
END;
GO

/* ============================================================
   7. DASHBOARD ADMINISTRATIVO GLOBAL / CASA

   OBJETIVO:
   Proporcionar la vista ejecutiva y operativa general
   de PlataformaApuestas.

   DEVUELVE:

   RESULT SET 1
   - Indicadores globales.
   - Usuarios.
   - Eventos.
   - Boletos.
   - Comisiones.
   - Exposición.
   - Resultado financiero realizado de CASA.

   RESULT SET 2
   - Resumen de los cuatro deportes.
   - Eventos.
   - Boletos relacionados.
   - Clientes.
   - Selecciones.
   - Cuotas y probabilidades.

   RESULT SET 3
   - Actividad reciente de auditoría.

   IMPORTANTE:
   - Los indicadores financieros globales se calculan
     directamente desde BOLETO.
   - No se suman montos de eventos para evitar duplicar
     boletos compuestos.
   - Las cantidades financieras por deporte se consideran
     RELACIONADAS y no deben sumarse entre deportes.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerDashboardAdministrativo
(
    @IdUsuarioSolicitante INT,
    @HorasPrevia INT = 24,
    @CantidadAuditoria INT = 25
)
AS
BEGIN
    SET NOCOUNT ON;


    /* ========================================================
       VALIDACIONES DE PARAMETROS
       ======================================================== */

    IF @IdUsuarioSolicitante IS NULL
       OR @IdUsuarioSolicitante <= 0
        THROW 64025,
            'IdUsuarioSolicitante es obligatorio.',
            1;


    IF @HorasPrevia IS NULL
       OR @HorasPrevia <= 0
        THROW 64026,
            'HorasPrevia debe ser mayor que cero.',
            1;


    IF @CantidadAuditoria IS NULL
       OR @CantidadAuditoria < 1
       OR @CantidadAuditoria > 100
        THROW 64027,
            'CantidadAuditoria debe estar entre 1 y 100.',
            1;


    /* ========================================================
       SEGURIDAD ADMINISTRATIVA
       ======================================================== */

    DECLARE @Rol VARCHAR(50);
    DECLARE @EstadoUsuario VARCHAR(40);


    SELECT
        @Rol =
            R.Nombre,

        @EstadoUsuario =
            E.Codigo

    FROM dbo.Usuario AS U


    INNER JOIN dbo.Rol AS R
        ON R.IdRol =
           U.IdRol


    INNER JOIN dbo.Estado AS E
        ON E.IdEstado =
           U.IdEstado


    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado =
           E.IdTipoEstado

       AND TE.Codigo =
           'USUARIO'


    WHERE U.IdUsuario =
          @IdUsuarioSolicitante;


    IF @Rol IS NULL
        THROW 64028,
            'El usuario solicitante no existe.',
            1;


    IF @EstadoUsuario <> 'ACTIVO'
        THROW 64029,
            'El usuario solicitante debe estar ACTIVO.',
            1;


    IF @Rol NOT IN
    (
        'ADMINISTRADOR',
        'AUDITOR'
    )
        THROW 64030,
            'El usuario no posee permisos para consultar el dashboard administrativo.',
            1;


    /* ========================================================
       HORA DE REFERENCIA - GUATEMALA
       ======================================================== */

    DECLARE @AhoraSistema DATETIME2 =
        CAST
        (
            SYSUTCDATETIME()
            AT TIME ZONE 'UTC'
            AT TIME ZONE 'Central America Standard Time'
            AS DATETIME2
        );


    /* ========================================================
       RESULT SET 1
       DASHBOARD GLOBAL
       ======================================================== */

    SELECT

        /* ====================================================
           USUARIOS CLIENTES
           ==================================================== */

        (
            SELECT COUNT(*)

            FROM dbo.Usuario AS U

            INNER JOIN dbo.Rol AS R
                ON R.IdRol =
                   U.IdRol

            WHERE R.Nombre =
                  'USUARIO'

        ) AS ClientesRegistrados,


        (
            SELECT COUNT(*)

            FROM dbo.Usuario AS U

            INNER JOIN dbo.Rol AS R
                ON R.IdRol =
                   U.IdRol

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado =
                   U.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado =
                   E.IdTipoEstado

               AND TE.Codigo =
                   'USUARIO'

            WHERE R.Nombre =
                  'USUARIO'

              AND E.Codigo =
                  'ACTIVO'

        ) AS ClientesActivos,


        /* ====================================================
           EVENTOS
           ==================================================== */

        (
            SELECT COUNT(*)
            FROM dbo.Evento
        ) AS EventosTotales,


        /* PROGRAMADOS que todavía no están en PREVIA */

        (
            SELECT COUNT(*)

            FROM dbo.Evento AS EV

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado =
                   EV.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado =
                   E.IdTipoEstado

               AND TE.Codigo =
                   'EVENTO'

            WHERE E.Codigo =
                  'PROGRAMADO'

              AND EV.FechaInicio >
                  DATEADD
                  (
                      HOUR,
                      @HorasPrevia,
                      @AhoraSistema
                  )

        ) AS EventosProgramados,


        /* PROGRAMADOS dentro de ventana PREVIA */

        (
            SELECT COUNT(*)

            FROM dbo.Evento AS EV

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado =
                   EV.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado =
                   E.IdTipoEstado

               AND TE.Codigo =
                   'EVENTO'

            WHERE E.Codigo =
                  'PROGRAMADO'

              AND EV.FechaInicio >
                  @AhoraSistema

              AND EV.FechaInicio <=
                  DATEADD
                  (
                      HOUR,
                      @HorasPrevia,
                      @AhoraSistema
                  )

        ) AS EventosPrevia,


        (
            SELECT COUNT(*)

            FROM dbo.Evento AS EV

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado =
                   EV.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado =
                   E.IdTipoEstado

               AND TE.Codigo =
                   'EVENTO'

            WHERE E.Codigo =
                  'EN_VIVO'

        ) AS EventosEnProgreso,


        (
            SELECT COUNT(*)

            FROM dbo.Evento AS EV

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado =
                   EV.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado =
                   E.IdTipoEstado

               AND TE.Codigo =
                   'EVENTO'

            WHERE E.Codigo =
                  'PENDIENTE_RESULTADO'

        ) AS EventosPendienteResultado,


        (
            SELECT COUNT(*)

            FROM dbo.Evento AS EV

            INNER JOIN dbo.Estado AS E
                ON E.IdEstado =
                   EV.IdEstado

            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado =
                   E.IdTipoEstado

               AND TE.Codigo =
                   'EVENTO'

            WHERE E.Codigo =
                  'FINALIZADO'

        ) AS EventosFinalizados,


        /* ====================================================
           BOLETOS
           ==================================================== */

        (
            SELECT COUNT(*)
            FROM dbo.Boleto

        ) AS BoletosTotales,


        (
            SELECT COUNT(*)

            FROM dbo.Boleto

            WHERE Resultado =
                  'PENDIENTE'

        ) AS BoletosPendientes,


        (
            SELECT COUNT(*)

            FROM dbo.Boleto

            WHERE Resultado =
                  'GANADOR'

        ) AS BoletosGanadores,


        (
            SELECT COUNT(*)

            FROM dbo.Boleto

            WHERE Resultado =
                  'PERDEDOR'

        ) AS BoletosPerdedores,


        (
            SELECT COUNT(*)

            FROM dbo.Boleto

            WHERE Resultado =
                  'ANULADO'

        ) AS BoletosAnulados,


        /* ====================================================
           MONTO HISTORICO
           ==================================================== */

        COALESCE
        (
            (
                SELECT
                    SUM(B.MontoApostado)

                FROM dbo.Boleto AS B
            ),
            0
        ) AS TotalApostadoHistorico,


        COALESCE
        (
            (
                SELECT
                    SUM(B.ComisionServicio)

                FROM dbo.Boleto AS B
            ),
            0
        ) AS ComisionesHistoricas,


        /* Comisiones correspondientes a apuestas
           ya definitivamente ganadas o perdidas. */

        COALESCE
        (
            (
                SELECT

                    SUM
                    (
                        CASE

                            WHEN B.Resultado
                                 IN
                                 (
                                     'GANADOR',
                                     'PERDEDOR'
                                 )

                                THEN
                                    B.ComisionServicio

                            ELSE 0

                        END
                    )

                FROM dbo.Boleto AS B
            ),
            0
        ) AS ComisionesRealizadas,


        /* Comisión actualmente asociada a boletos
           todavía pendientes. */

        COALESCE
        (
            (
                SELECT

                    SUM
                    (
                        CASE

                            WHEN B.Resultado =
                                 'PENDIENTE'

                                THEN
                                    B.ComisionServicio

                            ELSE 0

                        END
                    )

                FROM dbo.Boleto AS B
            ),
            0
        ) AS ComisionesPendientes,


        /* Comisión que tuvo que ser devuelta por
           anulación completa. */

        COALESCE
        (
            (
                SELECT

                    SUM
                    (
                        CASE

                            WHEN B.Resultado =
                                 'ANULADO'

                                THEN
                                    B.ComisionServicio

                            ELSE 0

                        END
                    )

                FROM dbo.Boleto AS B
            ),
            0
        ) AS ComisionesDevueltas,


        /* ====================================================
           DINERO EN APUESTAS PENDIENTES
           ==================================================== */

        COALESCE
        (
            (
                SELECT

                    SUM
                    (
                        CASE

                            WHEN B.Resultado =
                                 'PENDIENTE'

                                THEN
                                    B.MontoApostado

                            ELSE 0

                        END
                    )

                FROM dbo.Boleto AS B
            ),
            0
        ) AS MontoApostadoPendiente,


        COALESCE
        (
            (
                SELECT

                    SUM
                    (
                        CASE

                            WHEN B.Resultado =
                                 'PENDIENTE'

                                THEN
                                    B.GananciaPotencial

                            ELSE 0

                        END
                    )

                FROM dbo.Boleto AS B
            ),
            0
        ) AS PremioPotencialPendiente,


        /* ====================================================
           EXPOSICION POTENCIAL DE CASA

           Premio
           - monto apostado
           - comisión

           Solo boletos pendientes.

           Nunca se muestra negativa.
           ==================================================== */

        COALESCE
        (
            (
                SELECT

                    SUM
                    (
                        CASE

                            WHEN B.Resultado = 'PENDIENTE'

                             AND
                             (
                                 B.GananciaPotencial
                                 - B.MontoApostado
                                 - B.ComisionServicio
                             ) > 0

                                THEN
                                    B.GananciaPotencial
                                    - B.MontoApostado
                                    - B.ComisionServicio

                            ELSE 0

                        END
                    )

                FROM dbo.Boleto AS B
            ),
            0
        ) AS ExposicionPotencialCasa,


        /* ====================================================
           APUESTAS PERDIDAS POR CLIENTES

           Este capital queda a favor de CASA.
           ==================================================== */

        COALESCE
        (
            (
                SELECT

                    SUM
                    (
                        CASE

                            WHEN B.Resultado =
                                 'PERDEDOR'

                                THEN
                                    B.MontoApostado

                            ELSE 0

                        END
                    )

                FROM dbo.Boleto AS B
            ),
            0
        ) AS GananciaCasaPorApuestasPerdidas,


        /* ====================================================
           PREMIOS PAGADOS
           ==================================================== */

        COALESCE
        (
            (
                SELECT

                    SUM
                    (
                        CASE

                            WHEN B.Resultado =
                                 'GANADOR'

                                THEN
                                    COALESCE
                                    (
                                        LB.MontoLiquidado,
                                        0
                                    )

                            ELSE 0

                        END
                    )

                FROM dbo.Boleto AS B

                LEFT JOIN dbo.LiquidacionBoleto AS LB
                    ON LB.IdBoleto =
                       B.IdBoleto
            ),
            0
        ) AS PremiosPagados,


        /* ====================================================
           RESULTADO FINANCIERO REALIZADO DE CASA

           PERDEDOR:
               + apuesta
               + comisión

           GANADOR:
               + comisión
               - ganancia neta del cliente

           ANULADO:
               0

           PENDIENTE:
               todavía no realizado.
           ==================================================== */

        COALESCE
        (
            (
                SELECT

                    SUM
                    (
                        CASE

                            WHEN B.Resultado =
                                 'PERDEDOR'

                                THEN
                                    B.MontoApostado
                                    + B.ComisionServicio


                            WHEN B.Resultado =
                                 'GANADOR'

                                THEN
                                    B.ComisionServicio

                                    -
                                    (
                                        COALESCE
                                        (
                                            LB.MontoLiquidado,
                                            0
                                        )

                                        - B.MontoApostado
                                    )


                            WHEN B.Resultado =
                                 'ANULADO'

                                THEN 0


                            ELSE 0

                        END
                    )

                FROM dbo.Boleto AS B


                LEFT JOIN dbo.LiquidacionBoleto AS LB
                    ON LB.IdBoleto =
                       B.IdBoleto
            ),
            0
        ) AS ResultadoCasaRealizado,


        /* ====================================================
           AUDITORIA
           ==================================================== */

        (
            SELECT COUNT(*)

            FROM dbo.Auditoria AS A

            WHERE A.FechaAccion >=
                  DATEADD
                  (
                      HOUR,
                      -24,
                      SYSDATETIME()
                  )

        ) AS AccionesAuditoriaUltimas24Horas;


    /* ========================================================
       RESULT SET 2
       RESUMEN DE LOS CUATRO DEPORTES
       ======================================================== */

    ;WITH EventosDeporte AS
    (
        SELECT

            D.IdDeporte,

            EV.IdEvento,

            EE.Codigo
                AS EstadoEvento,

            EV.FechaInicio


        FROM dbo.Deporte AS D


        LEFT JOIN dbo.Liga AS L
            ON L.IdDeporte =
               D.IdDeporte


        LEFT JOIN dbo.Evento AS EV
            ON EV.IdLiga =
               L.IdLiga


        LEFT JOIN dbo.Estado AS EE
            ON EE.IdEstado =
               EV.IdEstado
    ),


    ResumenEventos AS
    (
        SELECT

            ED.IdDeporte,


            COUNT
            (
                ED.IdEvento
            ) AS EventosTotales,


            SUM
            (
                CASE

                    WHEN ED.EstadoEvento =
                         'PROGRAMADO'

                     AND ED.FechaInicio >
                         DATEADD
                         (
                             HOUR,
                             @HorasPrevia,
                             @AhoraSistema
                         )

                        THEN 1

                    ELSE 0

                END
            ) AS Programados,


            SUM
            (
                CASE

                    WHEN ED.EstadoEvento =
                         'PROGRAMADO'

                     AND ED.FechaInicio >
                         @AhoraSistema

                     AND ED.FechaInicio <=
                         DATEADD
                         (
                             HOUR,
                             @HorasPrevia,
                             @AhoraSistema
                         )

                        THEN 1

                    ELSE 0

                END
            ) AS Previa,


            SUM
            (
                CASE

                    WHEN ED.EstadoEvento =
                         'EN_VIVO'

                        THEN 1

                    ELSE 0

                END
            ) AS EnProgreso,


            SUM
            (
                CASE

                    WHEN ED.EstadoEvento =
                         'PENDIENTE_RESULTADO'

                        THEN 1

                    ELSE 0

                END
            ) AS PendienteResultado,


            SUM
            (
                CASE

                    WHEN ED.EstadoEvento =
                         'FINALIZADO'

                        THEN 1

                    ELSE 0

                END
            ) AS Finalizados


        FROM EventosDeporte AS ED


        GROUP BY
            ED.IdDeporte
    ),


    BoletosDeporte AS
    (
        /* DISTINCT:
           un mismo boleto se cuenta una sola vez
           dentro de cada deporte. */

        SELECT DISTINCT

            L.IdDeporte,

            B.IdBoleto,
            B.IdUsuario,

            B.Resultado,

            B.MontoApostado,
            B.ComisionServicio,

            B.CuotaTotal,
            B.GananciaPotencial


        FROM dbo.Boleto AS B


        INNER JOIN dbo.DetalleBoleto AS DB
            ON DB.IdBoleto =
               B.IdBoleto


        INNER JOIN dbo.Seleccion AS S
            ON S.IdSeleccion =
               DB.IdSeleccion


        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado =
               S.IdMercado


        INNER JOIN dbo.Evento AS EV
            ON EV.IdEvento =
               M.IdEvento


        INNER JOIN dbo.Liga AS L
            ON L.IdLiga =
               EV.IdLiga
    ),


    ResumenBoletos AS
    (
        SELECT

            BD.IdDeporte,


            COUNT(*)
                AS BoletosRelacionados,


            COUNT
            (
                DISTINCT BD.IdUsuario
            ) AS ClientesUnicos,


            SUM
            (
                CASE
                    WHEN BD.Resultado = 'PENDIENTE'
                        THEN 1
                    ELSE 0
                END
            ) AS BoletosPendientes,


            SUM
            (
                CASE
                    WHEN BD.Resultado = 'GANADOR'
                        THEN 1
                    ELSE 0
                END
            ) AS BoletosGanadores,


            SUM
            (
                CASE
                    WHEN BD.Resultado = 'PERDEDOR'
                        THEN 1
                    ELSE 0
                END
            ) AS BoletosPerdedores,


            SUM
            (
                CASE
                    WHEN BD.Resultado = 'ANULADO'
                        THEN 1
                    ELSE 0
                END
            ) AS BoletosAnulados,


            SUM
            (
                BD.MontoApostado
            ) AS MontoApostadoRelacionado,


            SUM
            (
                BD.ComisionServicio
            ) AS ComisionRelacionada,


            SUM
            (
                CASE

                    WHEN BD.Resultado =
                         'PENDIENTE'

                        THEN
                            BD.GananciaPotencial

                    ELSE 0

                END
            ) AS PremioPotencialPendienteRelacionado


        FROM BoletosDeporte AS BD


        GROUP BY
            BD.IdDeporte
    ),


    SeleccionesDeporte AS
    (
        SELECT

            L.IdDeporte,

            COUNT
            (
                DB.IdDetalle
            ) AS CantidadSeleccionesApostadas,


            SUM
            (
                CASE

                    WHEN DB.Resultado =
                         'PENDIENTE'

                        THEN 1

                    ELSE 0

                END
            ) AS SeleccionesPendientes,


            SUM
            (
                CASE

                    WHEN DB.Resultado =
                         'GANADA'

                        THEN 1

                    ELSE 0

                END
            ) AS SeleccionesGanadas,


            SUM
            (
                CASE

                    WHEN DB.Resultado =
                         'PERDIDA'

                        THEN 1

                    ELSE 0

                END
            ) AS SeleccionesPerdidas,


            AVG
            (
                CONVERT
                (
                    DECIMAL(19,6),
                    DB.CuotaAplicada
                )
            ) AS CuotaPromedio,


            AVG
            (
                CONVERT
                (
                    DECIMAL(19,6),
                    100.0
                )

                /

                NULLIF
                (
                    CONVERT
                    (
                        DECIMAL(19,6),
                        DB.CuotaAplicada
                    ),
                    0
                )
            ) AS ProbabilidadImplicitaPromedio


        FROM dbo.DetalleBoleto AS DB


        INNER JOIN dbo.Seleccion AS S
            ON S.IdSeleccion =
               DB.IdSeleccion


        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado =
               S.IdMercado


        INNER JOIN dbo.Evento AS EV
            ON EV.IdEvento =
               M.IdEvento


        INNER JOIN dbo.Liga AS L
            ON L.IdLiga =
               EV.IdLiga


        GROUP BY
            L.IdDeporte
    )


    SELECT

        D.IdDeporte,

        D.Nombre
            AS Deporte,


        COALESCE
        (
            RE.EventosTotales,
            0
        ) AS EventosTotales,


        COALESCE
        (
            RE.Programados,
            0
        ) AS Programados,


        COALESCE
        (
            RE.Previa,
            0
        ) AS Previa,


        COALESCE
        (
            RE.EnProgreso,
            0
        ) AS EnProgreso,


        COALESCE
        (
            RE.PendienteResultado,
            0
        ) AS PendienteResultado,


        COALESCE
        (
            RE.Finalizados,
            0
        ) AS Finalizados,


        COALESCE
        (
            RB.BoletosRelacionados,
            0
        ) AS BoletosRelacionados,


        COALESCE
        (
            RB.ClientesUnicos,
            0
        ) AS ClientesUnicos,


        COALESCE
        (
            RB.BoletosPendientes,
            0
        ) AS BoletosPendientes,


        COALESCE
        (
            RB.BoletosGanadores,
            0
        ) AS BoletosGanadores,


        COALESCE
        (
            RB.BoletosPerdedores,
            0
        ) AS BoletosPerdedores,


        COALESCE
        (
            RB.BoletosAnulados,
            0
        ) AS BoletosAnulados,


        COALESCE
        (
            RB.MontoApostadoRelacionado,
            0
        ) AS MontoApostadoRelacionado,


        COALESCE
        (
            RB.ComisionRelacionada,
            0
        ) AS ComisionRelacionada,


        COALESCE
        (
            RB.PremioPotencialPendienteRelacionado,
            0
        ) AS PremioPotencialPendienteRelacionado,


        COALESCE
        (
            SD.CantidadSeleccionesApostadas,
            0
        ) AS CantidadSeleccionesApostadas,


        COALESCE
        (
            SD.SeleccionesPendientes,
            0
        ) AS SeleccionesPendientes,


        COALESCE
        (
            SD.SeleccionesGanadas,
            0
        ) AS SeleccionesGanadas,


        COALESCE
        (
            SD.SeleccionesPerdidas,
            0
        ) AS SeleccionesPerdidas,


        CONVERT
        (
            DECIMAL(12,4),
            SD.CuotaPromedio
        ) AS CuotaPromedio,


        CONVERT
        (
            DECIMAL(7,2),

            ROUND
            (
                SD.ProbabilidadImplicitaPromedio,
                2
            )

        ) AS ProbabilidadImplicitaPromedio


    FROM dbo.Deporte AS D


    LEFT JOIN ResumenEventos AS RE
        ON RE.IdDeporte =
           D.IdDeporte


    LEFT JOIN ResumenBoletos AS RB
        ON RB.IdDeporte =
           D.IdDeporte


    LEFT JOIN SeleccionesDeporte AS SD
        ON SD.IdDeporte =
           D.IdDeporte


    WHERE D.Activo = 1

      AND D.Nombre IN
      (
          'Futbol',
          'Baloncesto',
          'Beisbol',
          'Tenis'
      )


    ORDER BY

        CASE D.Nombre

            WHEN 'Futbol'
                THEN 1

            WHEN 'Baloncesto'
                THEN 2

            WHEN 'Beisbol'
                THEN 3

            WHEN 'Tenis'
                THEN 4

            ELSE 5

        END;


    /* ========================================================
       RESULT SET 3
       AUDITORIA RECIENTE

       Permite alimentar un bloque de:
       "Actividad reciente del sistema".
       ======================================================== */

    SELECT TOP (@CantidadAuditoria)

        A.IdAuditoria,

        A.FechaAccion,

        A.IdUsuario,

        U.Correo,

        A.Accion,

        A.TablaAfectada,

        A.IdRegistro,

        A.ReferenciaOperacion,

        A.IpOrigen,

        A.Descripcion


    FROM dbo.Auditoria AS A


    LEFT JOIN dbo.Usuario AS U
        ON U.IdUsuario =
           A.IdUsuario


    ORDER BY

        A.FechaAccion DESC,

        A.IdAuditoria DESC;

END;
GO