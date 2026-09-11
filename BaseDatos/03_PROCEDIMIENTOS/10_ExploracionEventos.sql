/* ============================================================
   3. EXPLORACION DE EVENTOS PARA EL CLIENTE

   OBJETIVO:
   Alimentar la navegación principal del sistema:

   Deporte
       ↓
   PROGRAMADOS / PREVIA / EN PROGRESO / FINALIZADOS
       ↓
   Eventos
       ↓
   Detalle / mercados / apuestas

   IMPORTANTE:
   - Solo lectura.
   - PREVIA es una clasificación visual, no un estado de BD.
   - No habilita apuestas en vivo.
   - @HorasPrevia permite ajustar la ventana sin modificar
     los estados almacenados.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerEventosExploracion
(
    @IdDeporte INT,
    @Vista VARCHAR(20) = 'TODOS',
    @HorasPrevia INT = 24,
    @Cantidad INT = 100
)
AS
BEGIN
    SET NOCOUNT ON;


    /* ========================================================
       NORMALIZAR PARAMETROS
       ======================================================== */

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
       VALIDACIONES
       ======================================================== */

    IF @IdDeporte IS NULL
       OR @IdDeporte <= 0
        THROW 64006,
            'IdDeporte es obligatorio.',
            1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Deporte
        WHERE IdDeporte = @IdDeporte
          AND Activo = 1
    )
        THROW 64007,
            'El deporte indicado no existe o está inactivo.',
            1;


    IF @Vista NOT IN
    (
        'TODOS',
        'PROGRAMADOS',
        'PREVIA',
        'EN_PROGRESO',
        'FINALIZADOS'
    )
        THROW 64008,
            'La vista solicitada no es válida.',
            1;


    IF @HorasPrevia IS NULL
       OR @HorasPrevia <= 0
        THROW 64009,
            'HorasPrevia debe ser mayor que cero.',
            1;


    IF @Cantidad IS NULL
       OR @Cantidad < 1
       OR @Cantidad > 500
        THROW 64010,
            'Cantidad debe estar entre 1 y 500.',
            1;


    /* ========================================================
       HORA ACTUAL DEL SISTEMA - GUATEMALA
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
       ANTICIPACION DE CIERRE DE APUESTAS

       Utilizamos la misma configuración que protege
       sp_CotizarApuesta y sp_RealizarApuesta.
       ======================================================== */

    DECLARE @AnticipacionCierre INT;


    SELECT @AnticipacionCierre =
        TRY_CONVERT(INT, Valor)

    FROM dbo.ConfiguracionSistema

    WHERE Clave =
          'ANTICIPACION_CIERRE_APUESTA_MIN';


    IF @AnticipacionCierre IS NULL
       OR @AnticipacionCierre < 0
        THROW 64011,
            'ANTICIPACION_CIERRE_APUESTA_MIN no contiene un valor válido.',
            1;


    /* ========================================================
       CONSULTA PRINCIPAL
       ======================================================== */

    SELECT TOP (@Cantidad)

        EV.IdEvento,

        D.IdDeporte,
        D.Nombre AS Deporte,

        L.IdLiga,
        L.Nombre AS Liga,

        EV.Nombre AS Evento,


        /* -----------------------------------------------
           PARTICIPANTES
           ----------------------------------------------- */

        PA.Participante1,
        PA.Participante2,
        PA.CantidadParticipantes,


        /* -----------------------------------------------
           FECHAS
           ----------------------------------------------- */

        EV.FechaInicio,
        EV.FechaFin,

        DATEADD
        (
            MINUTE,
            -@AnticipacionCierre,
            EV.FechaInicio
        ) AS FechaCierreApuestas,


        DATEDIFF
        (
            MINUTE,
            @AhoraSistema,
            EV.FechaInicio
        ) AS MinutosParaInicio,


        DATEDIFF
        (
            MINUTE,
            @AhoraSistema,

            DATEADD
            (
                MINUTE,
                -@AnticipacionCierre,
                EV.FechaInicio
            )
        ) AS MinutosParaCierreApuestas,


        /* -----------------------------------------------
           ESTADO REAL Y ESTADO PARA INTERFAZ
           ----------------------------------------------- */

        EE.Codigo AS EstadoEvento,

        EVIS.EstadoVisual,


        /* Si terminó pero todavía no existe resultado
           oficial, la interfaz podrá indicarlo. */

        CONVERT
        (
            BIT,

            CASE
                WHEN EE.Codigo =
                     'PENDIENTE_RESULTADO'
                    THEN 1
                ELSE 0
            END
        ) AS ResultadoPendiente,


        /* -----------------------------------------------
           MERCADOS
           ----------------------------------------------- */

        COALESCE
        (
            MA.CantidadMercados,
            0
        ) AS CantidadMercados,

        COALESCE
        (
            MA.MercadosAbiertos,
            0
        ) AS MercadosAbiertos,

        COALESCE
        (
            MA.SeleccionesDisponibles,
            0
        ) AS SeleccionesDisponibles,


        /* -----------------------------------------------
           PUEDE APOSTAR

           EN_VIVO nunca permite apostar.
           ----------------------------------------------- */

        CONVERT
        (
            BIT,

            CASE
                WHEN EE.Codigo = 'PROGRAMADO'

                 AND @AhoraSistema <
                     DATEADD
                     (
                         MINUTE,
                         -@AnticipacionCierre,
                         EV.FechaInicio
                     )

                 AND COALESCE
                     (
                         MA.MercadosAbiertos,
                         0
                     ) > 0

                 AND COALESCE
                     (
                         MA.SeleccionesDisponibles,
                         0
                     ) > 0

                    THEN 1

                ELSE 0
            END
        ) AS PuedeApostar,


        /* -----------------------------------------------
           RESULTADO / MARCADOR DISPONIBLE
           ----------------------------------------------- */

        RE.ResultadoTexto,

        ERE.Codigo
            AS EstadoResultado


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


    /* ========================================================
       PARTICIPANTES DEL EVENTO

       Por ahora el modelo permite obtener las posiciones
       principales 1 y 2 para las tarjetas.
       ======================================================== */

    OUTER APPLY
    (
        SELECT

            (
                SELECT P1.Nombre

                FROM dbo.EventoParticipante AS EP1

                INNER JOIN dbo.Participante AS P1
                    ON P1.IdParticipante =
                    EP1.IdParticipante

                WHERE EP1.IdEvento =
                    EV.IdEvento

                AND EP1.OrdenParticipante = 1

            ) AS Participante1,


            (
                SELECT P2.Nombre

                FROM dbo.EventoParticipante AS EP2

                INNER JOIN dbo.Participante AS P2
                    ON P2.IdParticipante =
                    EP2.IdParticipante

                WHERE EP2.IdEvento =
                    EV.IdEvento

                AND EP2.OrdenParticipante = 2

            ) AS Participante2,


            (
                SELECT COUNT(*)

                FROM dbo.EventoParticipante AS EP3

                WHERE EP3.IdEvento =
                    EV.IdEvento

            ) AS CantidadParticipantes

    ) AS PA


    /* ========================================================
       RESUMEN DE MERCADOS DEL EVENTO
       ======================================================== */

    OUTER APPLY
    (
        SELECT

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
                DISTINCT

                CASE
                    WHEN EM.Codigo = 'ABIERTO'
                     AND S.Activo = 1
                     AND C.IdCuota IS NOT NULL
                        THEN S.IdSeleccion
                END
            ) AS SeleccionesDisponibles


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


        WHERE M.IdEvento =
              EV.IdEvento

    ) AS MA


    /* ========================================================
       CLASIFICACION VISUAL

       PREVIA:
       Evento PROGRAMADO dentro de @HorasPrevia antes
       de su hora de inicio.
       ======================================================== */

    CROSS APPLY
    (
        SELECT

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


                WHEN EE.Codigo IN
                (
                    'PENDIENTE_RESULTADO',
                    'FINALIZADO'
                )
                    THEN 'FINALIZADO'


                ELSE EE.Codigo

            END AS EstadoVisual

    ) AS EVIS


    /* ========================================================
       RESULTADO DEL EVENTO
       ======================================================== */

    LEFT JOIN dbo.ResultadoEvento AS RE
        ON RE.IdEvento =
           EV.IdEvento


    LEFT JOIN dbo.Estado AS ERE
        ON ERE.IdEstado =
           RE.IdEstado


    LEFT JOIN dbo.TipoEstado AS TERE
        ON TERE.IdTipoEstado =
           ERE.IdTipoEstado

       AND TERE.Codigo =
           'RESULTADO_EVENTO'


    /* ========================================================
       FILTROS
       ======================================================== */

    WHERE D.IdDeporte =
          @IdDeporte


      /* Para la cara pública no mostramos borradores,
         suspendidos ni cancelados en estos cuatro grupos. */

      AND EE.Codigo IN
      (
          'PROGRAMADO',
          'EN_VIVO',
          'PENDIENTE_RESULTADO',
          'FINALIZADO'
      )


      AND
      (
          @Vista = 'TODOS'

          OR
          (
              @Vista = 'PROGRAMADOS'
              AND EVIS.EstadoVisual =
                  'PROGRAMADO'
          )

          OR
          (
              @Vista = 'PREVIA'
              AND EVIS.EstadoVisual =
                  'PREVIA'
          )

          OR
          (
              @Vista = 'EN_PROGRESO'
              AND EVIS.EstadoVisual =
                  'EN_PROGRESO'
          )

          OR
          (
              @Vista = 'FINALIZADOS'
              AND EVIS.EstadoVisual =
                  'FINALIZADO'
          )
      )


    ORDER BY

        CASE EVIS.EstadoVisual
            WHEN 'EN_PROGRESO' THEN 1
            WHEN 'PREVIA' THEN 2
            WHEN 'PROGRAMADO' THEN 3
            WHEN 'FINALIZADO' THEN 4
            ELSE 5
        END,

        CASE
            WHEN EVIS.EstadoVisual =
                 'FINALIZADO'
                THEN NULL
            ELSE EV.FechaInicio
        END ASC,

        CASE
            WHEN EVIS.EstadoVisual =
                 'FINALIZADO'
                THEN EV.FechaInicio
        END DESC,

        EV.IdEvento DESC;
END;
GO

/* ============================================================
   4. DETALLE DE EVENTO PARA EXPLORACION

   OBJETIVO:
   Alimentar la pantalla que se abre cuando el cliente
   selecciona un evento desde:

   Deporte
       ↓
   Programados / Previa / En progreso / Finalizados
       ↓
   Evento
       ↓
   Participantes
   Mercados
   Selecciones
   Cuotas
   Probabilidades
   Resultado

   DEVUELVE:
   1. Encabezado del evento.
   2. Participantes.
   3. Mercados, selecciones, cuotas y probabilidades.

   IMPORTANTE:
   - Solo lectura.
   - No modifica cuotas ni apuestas.
   - Las apuestas solo pueden realizarse antes del cierre.
   - EN_VIVO nunca habilita nuevas apuestas.
   - Para eventos históricos puede mostrar la última cuota
     registrada aunque ya no esté activa.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerDetalleEventoExploracion
(
    @IdEvento INT,
    @HorasPrevia INT = 24
)
AS
BEGIN
    SET NOCOUNT ON;


    /* ========================================================
       VALIDACIONES
       ======================================================== */

    IF @IdEvento IS NULL
       OR @IdEvento <= 0
        THROW 64012,
            'IdEvento es obligatorio.',
            1;


    IF @HorasPrevia IS NULL
       OR @HorasPrevia <= 0
        THROW 64013,
            'HorasPrevia debe ser mayor que cero.',
            1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Evento
        WHERE IdEvento = @IdEvento
    )
        THROW 64014,
            'El evento indicado no existe.',
            1;


    /* ========================================================
       HORA DEL SISTEMA - GUATEMALA
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
       CIERRE DE APUESTAS
       ======================================================== */

    DECLARE @AnticipacionCierre INT;


    SELECT
        @AnticipacionCierre =
            TRY_CONVERT
            (
                INT,
                Valor
            )

    FROM dbo.ConfiguracionSistema

    WHERE Clave =
          'ANTICIPACION_CIERRE_APUESTA_MIN';


    IF @AnticipacionCierre IS NULL
       OR @AnticipacionCierre < 0
        THROW 64015,
            'ANTICIPACION_CIERRE_APUESTA_MIN no contiene un valor válido.',
            1;


    /* ========================================================
       RESULT SET 1
       ENCABEZADO DEL EVENTO
       ======================================================== */

    SELECT
        EV.IdEvento,

        D.IdDeporte,
        D.Nombre AS Deporte,

        L.IdLiga,
        L.Nombre AS Liga,

        EV.Nombre AS Evento,

        EV.FechaInicio,
        EV.FechaFin,


        DATEADD
        (
            MINUTE,
            -@AnticipacionCierre,
            EV.FechaInicio
        ) AS FechaCierreApuestas,


        DATEDIFF
        (
            MINUTE,
            @AhoraSistema,
            EV.FechaInicio
        ) AS MinutosParaInicio,


        DATEDIFF
        (
            MINUTE,
            @AhoraSistema,

            DATEADD
            (
                MINUTE,
                -@AnticipacionCierre,
                EV.FechaInicio
            )
        ) AS MinutosParaCierreApuestas,


        EE.Codigo AS EstadoEvento,


        /* -----------------------------------------------
           ESTADO VISUAL
           ----------------------------------------------- */

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


            WHEN EE.Codigo IN
            (
                'PENDIENTE_RESULTADO',
                'FINALIZADO'
            )
                THEN 'FINALIZADO'


            ELSE EE.Codigo

        END AS EstadoVisual,


        /* -----------------------------------------------
           DISPONIBILIDAD PARA APOSTAR
           ----------------------------------------------- */

        CONVERT
        (
            BIT,

            CASE

                WHEN EE.Codigo = 'PROGRAMADO'

                 AND @AhoraSistema <
                     DATEADD
                     (
                         MINUTE,
                         -@AnticipacionCierre,
                         EV.FechaInicio
                     )

                 AND EXISTS
                 (
                     SELECT 1

                     FROM dbo.Mercado AS MA

                     INNER JOIN dbo.Estado AS EMA
                         ON EMA.IdEstado =
                            MA.IdEstado

                     INNER JOIN dbo.TipoEstado AS TEMA
                         ON TEMA.IdTipoEstado =
                            EMA.IdTipoEstado

                        AND TEMA.Codigo =
                            'MERCADO'

                     INNER JOIN dbo.Seleccion AS SA
                         ON SA.IdMercado =
                            MA.IdMercado

                        AND SA.Activo = 1

                     INNER JOIN dbo.Cuota AS CA
                         ON CA.IdSeleccion =
                            SA.IdSeleccion

                        AND CA.Activo = 1

                     WHERE MA.IdEvento =
                           EV.IdEvento

                       AND EMA.Codigo =
                           'ABIERTO'
                 )

                    THEN 1

                ELSE 0

            END
        ) AS PuedeApostar,


        /* -----------------------------------------------
           CANTIDADES
           ----------------------------------------------- */

        (
            SELECT COUNT(*)

            FROM dbo.Mercado AS MC

            WHERE MC.IdEvento =
                  EV.IdEvento

        ) AS CantidadMercados,


        (
            SELECT COUNT(*)

            FROM dbo.EventoParticipante AS EPC

            WHERE EPC.IdEvento =
                  EV.IdEvento

        ) AS CantidadParticipantes,


        /* -----------------------------------------------
           RESULTADO OFICIAL
           ----------------------------------------------- */

        RE.ResultadoTexto,

        ER.Codigo AS EstadoResultado,


        CONVERT
        (
            BIT,

            CASE
                WHEN EE.Codigo =
                     'PENDIENTE_RESULTADO'
                    THEN 1
                ELSE 0
            END
        ) AS ResultadoPendiente


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


    LEFT JOIN dbo.ResultadoEvento AS RE
        ON RE.IdEvento =
           EV.IdEvento


    LEFT JOIN dbo.Estado AS ER
        ON ER.IdEstado =
           RE.IdEstado


    WHERE EV.IdEvento =
          @IdEvento;


    /* ========================================================
       RESULT SET 2
       PARTICIPANTES DEL EVENTO
       ======================================================== */

    SELECT
        EP.IdEventoParticipante,

        EP.OrdenParticipante,

        EP.EsLocal,

        P.IdParticipante,

        P.Nombre AS Participante,

        P.TipoParticipante,

        P.IdPais,

        PA.Nombre AS Pais,

        PA.CodigoISO2 AS CodigoPais


    FROM dbo.EventoParticipante AS EP


    INNER JOIN dbo.Participante AS P
        ON P.IdParticipante =
           EP.IdParticipante


    LEFT JOIN dbo.Pais AS PA
        ON PA.IdPais =
           P.IdPais


    WHERE EP.IdEvento =
          @IdEvento


    ORDER BY
        EP.OrdenParticipante,
        P.IdParticipante;


    /* ========================================================
       RESULT SET 3
       MERCADOS + SELECCIONES + CUOTAS + PROBABILIDADES

       Para cada selección se obtiene la cuota más reciente.

       Si existe una cuota activa:
           puede utilizarse para apostar.

       Si el evento ya terminó:
           la última cuota sigue siendo útil para consulta
           histórica y estadísticas.
       ======================================================== */

    SELECT
        M.IdMercado,

        M.Nombre AS Mercado,

        M.Descripcion
            AS DescripcionMercado,

        EM.Codigo
            AS EstadoMercado,


        S.IdSeleccion,

        S.Nombre
            AS Seleccion,

        S.Activo
            AS SeleccionActiva,


        CU.IdCuota,

        CU.Valor
            AS Cuota,

        CU.FechaInicio
            AS FechaInicioCuota,

        CU.FechaFin
            AS FechaFinCuota,

        CU.Activo
            AS CuotaActiva,


        /* -----------------------------------------------
           PROBABILIDAD IMPLICITA
           ----------------------------------------------- */

        CASE

            WHEN CU.Valor IS NULL
                THEN NULL

            ELSE

                CONVERT
                (
                    DECIMAL(7,2),

                    ROUND
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
                                CU.Valor
                            ),
                            0
                        ),

                        2
                    )
                )

        END AS ProbabilidadImplicitaPorcentaje,


        /* -----------------------------------------------
           RESULTADO DE LA SELECCION

           Aparecerá cuando exista resolución.
           ----------------------------------------------- */

        RS.Resultado
            AS ResultadoSeleccion,


        RS.FechaResolucion,


        /* -----------------------------------------------
           PUEDE SELECCIONAR PARA APOSTAR
           ----------------------------------------------- */

        CONVERT
        (
            BIT,

            CASE

                WHEN EE.Codigo =
                     'PROGRAMADO'

                 AND EM.Codigo =
                     'ABIERTO'

                 AND S.Activo = 1

                 AND CU.IdCuota
                     IS NOT NULL

                 AND CU.Activo = 1

                 AND @AhoraSistema <
                     DATEADD
                     (
                         MINUTE,
                         -@AnticipacionCierre,
                         EV.FechaInicio
                     )

                    THEN 1

                ELSE 0

            END
        ) AS PuedeSeleccionar


    FROM dbo.Evento AS EV


    INNER JOIN dbo.Estado AS EE
        ON EE.IdEstado =
           EV.IdEstado


    INNER JOIN dbo.TipoEstado AS TEE
        ON TEE.IdTipoEstado =
           EE.IdTipoEstado

       AND TEE.Codigo =
           'EVENTO'


    INNER JOIN dbo.Mercado AS M
        ON M.IdEvento =
           EV.IdEvento


    INNER JOIN dbo.Estado AS EM
        ON EM.IdEstado =
           M.IdEstado


    INNER JOIN dbo.TipoEstado AS TEM
        ON TEM.IdTipoEstado =
           EM.IdTipoEstado

       AND TEM.Codigo =
           'MERCADO'


    INNER JOIN dbo.Seleccion AS S
        ON S.IdMercado =
           M.IdMercado


    /* ========================================================
       ULTIMA CUOTA DE LA SELECCION

       La prioridad es:
       1. Cuota activa.
       2. Última cuota histórica.
       ======================================================== */

    OUTER APPLY
    (
        SELECT TOP (1)

            C.IdCuota,

            C.Valor,

            C.FechaInicio,

            C.FechaFin,

            C.Activo


        FROM dbo.Cuota AS C


        WHERE C.IdSeleccion =
              S.IdSeleccion


        ORDER BY
            C.Activo DESC,
            C.FechaInicio DESC,
            C.IdCuota DESC

    ) AS CU


    LEFT JOIN dbo.ResolucionSeleccion AS RS
        ON RS.IdSeleccion =
           S.IdSeleccion


    WHERE EV.IdEvento =
          @IdEvento


    ORDER BY
        M.IdMercado,
        S.IdSeleccion;
END;
GO