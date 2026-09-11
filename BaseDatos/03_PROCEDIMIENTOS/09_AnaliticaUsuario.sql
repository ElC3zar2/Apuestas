/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   03_PROCEDIMIENTOS/09_AnaliticaApuestas.sql

   OBJETIVO:
   Centralizar indicadores, estadísticas y resúmenes derivados
   de las apuestas sin modificar la lógica transaccional de
   cotización, registro o liquidación.

   PRINCIPIOS:
   - Solo lectura.
   - No modifica boletos ni saldos.
   - No modifica cuotas.
   - Los indicadores se calculan a partir de datos existentes.
   - Compatible con apuestas SIMPLE y COMPUESTO.
   - Compatible con Futbol, Baloncesto, Beisbol y Tenis.
   ============================================================ */

SET NOCOUNT ON;
GO


/* ============================================================
   1. ANALITICA DE BOLETOS DEL USUARIO

   Devuelve:
   1) Resumen de cada boleto.
   2) Detalle de selecciones con probabilidad implícita.

   @IdDeporte:
   - NULL = todos los deportes.
   - Id válido = boletos que contengan al menos una selección
     correspondiente al deporte solicitado.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerAnaliticaBoletosUsuario
(
    @IdUsuario INT,
    @IdDeporte INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;


    /* ========================================================
       VALIDACIONES
       ======================================================== */

    IF @IdUsuario IS NULL OR @IdUsuario <= 0
        THROW 64001,
            'IdUsuario es obligatorio.',
            1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE IdUsuario = @IdUsuario
    )
        THROW 64002,
            'El usuario indicado no existe.',
            1;


    IF @IdDeporte IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Deporte
           WHERE IdDeporte = @IdDeporte
             AND Activo = 1
       )
        THROW 64003,
            'El deporte indicado no existe o está inactivo.',
            1;


    /* ========================================================
       PRIMER RESULT SET
       RESUMEN DE BOLETOS
       ======================================================== */

    SELECT
        B.IdBoleto,
        B.CodigoBoleto,

        B.TipoBoleto,
        B.Resultado,

        EB.Codigo AS EstadoBoleto,

        B.FechaCreacion,
        B.FechaLiquidacion,


        /* -----------------------------------------------
           INFORMACION FINANCIERA
           ----------------------------------------------- */

        B.MontoApostado,

        B.ComisionServicio,

        (
            B.MontoApostado
            + B.ComisionServicio
        ) AS TotalCargo,


        B.CuotaTotal,


        /* El campo histórico GananciaPotencial realmente
           representa el premio total potencial. */

        B.GananciaPotencial
            AS PremioPotencial,


        /* Premio menos apuesta. */

        CONVERT
        (
            DECIMAL(12,2),
            B.GananciaPotencial
            - B.MontoApostado
        ) AS GananciaNetaPotencial,


        /* -----------------------------------------------
           PORCENTAJE DE GANANCIA POTENCIAL
           ----------------------------------------------- */

        CONVERT
        (
            DECIMAL(9,2),

            ROUND
            (
                (
                    CONVERT
                    (
                        DECIMAL(19,6),
                        B.GananciaPotencial
                        - B.MontoApostado
                    )
                    /
                    NULLIF
                    (
                        CONVERT
                        (
                            DECIMAL(19,6),
                            B.MontoApostado
                        ),
                        0
                    )
                )
                * 100,
                2
            )
        ) AS PorcentajeGananciaPotencial,


        /* -----------------------------------------------
           PROBABILIDAD IMPLICITA DEL BOLETO
           ----------------------------------------------- */

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
                        B.CuotaTotal
                    ),
                    0
                ),
                2
            )
        ) AS ProbabilidadImplicitaPorcentaje,


        /* Cantidad de selecciones del boleto. */

        (
            SELECT COUNT(*)
            FROM dbo.DetalleBoleto AS DB2
            WHERE DB2.IdBoleto = B.IdBoleto
        ) AS CantidadSelecciones


    FROM dbo.Boleto AS B

    INNER JOIN dbo.Estado AS EB
        ON EB.IdEstado = B.IdEstado

    WHERE B.IdUsuario = @IdUsuario

      AND
      (
          @IdDeporte IS NULL

          OR EXISTS
          (
              SELECT 1

              FROM dbo.DetalleBoleto AS DBF

              INNER JOIN dbo.Seleccion AS SF
                  ON SF.IdSeleccion =
                     DBF.IdSeleccion

              INNER JOIN dbo.Mercado AS MF
                  ON MF.IdMercado =
                     SF.IdMercado

              INNER JOIN dbo.Evento AS EVF
                  ON EVF.IdEvento =
                     MF.IdEvento

              INNER JOIN dbo.Liga AS LF
                  ON LF.IdLiga =
                     EVF.IdLiga

              WHERE DBF.IdBoleto =
                    B.IdBoleto

                AND LF.IdDeporte =
                    @IdDeporte
          )
      )

    ORDER BY
        B.FechaCreacion DESC,
        B.IdBoleto DESC;


    /* ========================================================
       SEGUNDO RESULT SET

       DETALLE DE CADA SELECCION DEL BOLETO.

       Aquí podremos mostrar al cliente la probabilidad
       aproximada de cada selección que forma su boleto.
       ======================================================== */

    SELECT
        B.IdBoleto,
        B.CodigoBoleto,

        DB.IdDetalle,

        D.IdDeporte,
        D.Nombre AS Deporte,

        L.IdLiga,
        L.Nombre AS Liga,

        EV.IdEvento,
        EV.Nombre AS Evento,
        EV.FechaInicio,

        M.IdMercado,
        M.Nombre AS Mercado,

        S.IdSeleccion,
        S.Nombre AS Seleccion,

        DB.CuotaAplicada,


        /* Probabilidad aproximada derivada de la
           cuota aceptada cuando se realizó la apuesta. */

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
                        DB.CuotaAplicada
                    ),
                    0
                ),
                2
            )
        ) AS ProbabilidadImplicitaSeleccionPorcentaje,


        DB.Resultado AS ResultadoSeleccion


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

    INNER JOIN dbo.Deporte AS D
        ON D.IdDeporte =
           L.IdDeporte

    WHERE B.IdUsuario =
          @IdUsuario

      AND
      (
          @IdDeporte IS NULL
          OR D.IdDeporte =
             @IdDeporte
      )

    ORDER BY
        B.FechaCreacion DESC,
        B.IdBoleto DESC,
        DB.IdDetalle;
END;
GO

/* ============================================================
   2. RESUMEN DEL USUARIO POR DEPORTE

   OBJETIVO:
   Mostrar el comportamiento deportivo del cliente en:

   - Futbol
   - Baloncesto
   - Beisbol
   - Tenis

   IMPORTANTE:
   - Solo procesa boletos pertenecientes al usuario solicitado.
   - Evita mezclar información entre clientes.
   - Siempre devuelve los cuatro deportes activos del proyecto.
   - Si el usuario no posee apuestas en un deporte,
     sus contadores aparecen en cero.
   - Los montos financieros NO se duplican por deporte.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerResumenUsuarioPorDeporte
(
    @IdUsuario INT
)
AS
BEGIN
    SET NOCOUNT ON;


    /* ========================================================
       VALIDACIONES
       ======================================================== */

    IF @IdUsuario IS NULL
       OR @IdUsuario <= 0
        THROW 64004,
            'IdUsuario es obligatorio.',
            1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE IdUsuario = @IdUsuario
    )
        THROW 64005,
            'El usuario indicado no existe.',
            1;


    /* ========================================================
       DATOS EXCLUSIVOS DEL USUARIO

       Primero aislamos únicamente sus boletos y selecciones.
       Esto evita mezclar estadísticas de otros clientes.
       ======================================================== */

    ;WITH DatosUsuario AS
    (
        SELECT
            D.IdDeporte,

            B.IdBoleto,
            B.Resultado AS ResultadoBoleto,

            DB.IdDetalle,
            DB.Resultado AS ResultadoSeleccion,
            DB.CuotaAplicada

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

        INNER JOIN dbo.Deporte AS D
            ON D.IdDeporte =
               L.IdDeporte

        WHERE B.IdUsuario =
              @IdUsuario
    )


    /* ========================================================
       ESTADISTICAS POR DEPORTE

       Se comienza desde Deporte para garantizar que aparezcan
       las cuatro opciones aunque el usuario todavía no haya
       realizado apuestas en alguna de ellas.
       ======================================================== */

    SELECT
        D.IdDeporte,
        D.Nombre AS Deporte,


        /* -----------------------------------------------
           BOLETOS
           ----------------------------------------------- */

        COUNT
        (
            DISTINCT DU.IdBoleto
        ) AS CantidadBoletos,


        COUNT
        (
            DISTINCT CASE
                WHEN DU.ResultadoBoleto = 'PENDIENTE'
                    THEN DU.IdBoleto
            END
        ) AS BoletosPendientes,


        COUNT
        (
            DISTINCT CASE
                WHEN DU.ResultadoBoleto = 'GANADOR'
                    THEN DU.IdBoleto
            END
        ) AS BoletosGanadores,


        COUNT
        (
            DISTINCT CASE
                WHEN DU.ResultadoBoleto = 'PERDEDOR'
                    THEN DU.IdBoleto
            END
        ) AS BoletosPerdedores,


        COUNT
        (
            DISTINCT CASE
                WHEN DU.ResultadoBoleto = 'ANULADO'
                    THEN DU.IdBoleto
            END
        ) AS BoletosAnulados,


        /* -----------------------------------------------
           SELECCIONES
           ----------------------------------------------- */

        COUNT
        (
            DU.IdDetalle
        ) AS CantidadSelecciones,


        SUM
        (
            CASE
                WHEN DU.ResultadoSeleccion = 'PENDIENTE'
                    THEN 1
                ELSE 0
            END
        ) AS SeleccionesPendientes,


        SUM
        (
            CASE
                WHEN DU.ResultadoSeleccion = 'GANADA'
                    THEN 1
                ELSE 0
            END
        ) AS SeleccionesGanadas,


        SUM
        (
            CASE
                WHEN DU.ResultadoSeleccion = 'PERDIDA'
                    THEN 1
                ELSE 0
            END
        ) AS SeleccionesPerdidas,


        SUM
        (
            CASE
                WHEN DU.ResultadoSeleccion = 'ANULADA'
                    THEN 1
                ELSE 0
            END
        ) AS SeleccionesAnuladas,


        /* -----------------------------------------------
           CUOTA PROMEDIO
           ----------------------------------------------- */

        CONVERT
        (
            DECIMAL(12,4),

            AVG
            (
                CONVERT
                (
                    DECIMAL(19,6),
                    DU.CuotaAplicada
                )
            )
        ) AS CuotaPromedio,


        /* -----------------------------------------------
           PROBABILIDAD IMPLICITA PROMEDIO

           Primero:
               100 / cuota

           Después:
               promedio de las selecciones del deporte.
           ----------------------------------------------- */

        CONVERT
        (
            DECIMAL(7,2),

            ROUND
            (
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
                            DU.CuotaAplicada
                        ),
                        0
                    )
                ),
                2
            )
        ) AS ProbabilidadImplicitaPromedio,


        /* -----------------------------------------------
           EFECTIVIDAD

           Solo considera selecciones efectivamente
           GANADAS o PERDIDAS.

           PENDIENTE y ANULADA no afectan el porcentaje.
           ----------------------------------------------- */

        CONVERT
        (
            DECIMAL(7,2),

            ROUND
            (
                (
                    CONVERT
                    (
                        DECIMAL(19,6),

                        SUM
                        (
                            CASE
                                WHEN DU.ResultadoSeleccion = 'GANADA'
                                    THEN 1
                                ELSE 0
                            END
                        )
                    )

                    /

                    NULLIF
                    (
                        CONVERT
                        (
                            DECIMAL(19,6),

                            SUM
                            (
                                CASE
                                    WHEN DU.ResultadoSeleccion
                                         IN ('GANADA', 'PERDIDA')
                                        THEN 1
                                    ELSE 0
                                END
                            )
                        ),
                        0
                    )
                )
                * 100,
                2
            )
        ) AS PorcentajeEfectividad


    FROM dbo.Deporte AS D

    LEFT JOIN DatosUsuario AS DU
        ON DU.IdDeporte =
           D.IdDeporte


    WHERE D.Activo = 1

      AND D.Nombre IN
      (
          'Futbol',
          'Baloncesto',
          'Beisbol',
          'Tenis'
      )


    GROUP BY
        D.IdDeporte,
        D.Nombre


    ORDER BY
        CASE D.Nombre
            WHEN 'Futbol' THEN 1
            WHEN 'Baloncesto' THEN 2
            WHEN 'Beisbol' THEN 3
            WHEN 'Tenis' THEN 4
            ELSE 5
        END;
END;
GO

/* ============================================================
   5. RESUMEN GENERAL DEL USUARIO

   OBJETIVO:
   Alimentar el panel "Mi resumen" del cliente.

   DEVUELVE:
   - Cantidad de boletos.
   - Estados y resultados.
   - Dinero apostado.
   - Comisiones.
   - Premio potencial pendiente.
   - Premios obtenidos.
   - Resultado neto realizado.
   - Efectividad.
   - Probabilidad implícita promedio.

   IMPORTANTE:
   - Solo consulta datos del usuario indicado.
   - PENDIENTES no afectan resultado neto realizado.
   - ANULADOS producen resultado neto 0 porque se devuelve
     apuesta y comisión.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerResumenGeneralUsuario
(
    @IdUsuario INT
)
AS
BEGIN
    SET NOCOUNT ON;


    /* ========================================================
       VALIDACIONES
       ======================================================== */

    IF @IdUsuario IS NULL
       OR @IdUsuario <= 0
        THROW 64016,
            'IdUsuario es obligatorio.',
            1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE IdUsuario = @IdUsuario
    )
        THROW 64017,
            'El usuario indicado no existe.',
            1;


    /* ========================================================
       RESUMEN GENERAL
       ======================================================== */

    SELECT

        COUNT(B.IdBoleto)
            AS CantidadBoletos,


        SUM
        (
            CASE
                WHEN B.Resultado = 'PENDIENTE'
                    THEN 1
                ELSE 0
            END
        ) AS BoletosPendientes,


        SUM
        (
            CASE
                WHEN B.Resultado = 'GANADOR'
                    THEN 1
                ELSE 0
            END
        ) AS BoletosGanadores,


        SUM
        (
            CASE
                WHEN B.Resultado = 'PERDEDOR'
                    THEN 1
                ELSE 0
            END
        ) AS BoletosPerdedores,


        SUM
        (
            CASE
                WHEN B.Resultado = 'ANULADO'
                    THEN 1
                ELSE 0
            END
        ) AS BoletosAnulados,


        /* ====================================================
           MOVIMIENTO HISTORICO
           ==================================================== */

        COALESCE
        (
            SUM(B.MontoApostado),
            0
        ) AS TotalApostado,


        COALESCE
        (
            SUM(B.ComisionServicio),
            0
        ) AS TotalComisionesHistoricas,


        COALESCE
        (
            SUM
            (
                B.MontoApostado
                + B.ComisionServicio
            ),
            0
        ) AS TotalCargoHistorico,


        /* ====================================================
           POTENCIAL TODAVIA ABIERTO
           ==================================================== */

        COALESCE
        (
            SUM
            (
                CASE
                    WHEN B.Resultado = 'PENDIENTE'
                        THEN B.GananciaPotencial
                    ELSE 0
                END
            ),
            0
        ) AS PremioPotencialPendiente,


        COALESCE
        (
            SUM
            (
                CASE
                    WHEN B.Resultado = 'PENDIENTE'
                        THEN
                            B.GananciaPotencial
                            - B.MontoApostado
                    ELSE 0
                END
            ),
            0
        ) AS GananciaNetaPotencialPendiente,


        /* ====================================================
           PREMIOS YA LIQUIDADOS
           ==================================================== */

        COALESCE
        (
            SUM
            (
                CASE
                    WHEN B.Resultado = 'GANADOR'
                        THEN COALESCE
                             (
                                 LB.MontoLiquidado,
                                 0
                             )
                    ELSE 0
                END
            ),
            0
        ) AS TotalPremiosGanadores,


        /* ====================================================
           DEVOLUCIONES POR ANULACION

           Incluye apuesta + comisión.
           ==================================================== */

        COALESCE
        (
            SUM
            (
                CASE
                    WHEN B.Resultado = 'ANULADO'
                        THEN
                            COALESCE
                            (
                                LB.MontoLiquidado,
                                B.MontoApostado
                            )
                            + B.ComisionServicio
                    ELSE 0
                END
            ),
            0
        ) AS TotalDevueltoPorAnulacion,


        /* ====================================================
           RESULTADO NETO REALIZADO DEL CLIENTE

           GANADOR:
           monto recibido - apuesta - comisión.

           PERDEDOR:
           pierde apuesta + comisión.

           ANULADO:
           0.

           PENDIENTE:
           todavía no forma parte del resultado realizado.
           ==================================================== */

        COALESCE
        (
            SUM
            (
                CASE

                    WHEN B.Resultado = 'GANADOR'
                        THEN
                            COALESCE
                            (
                                LB.MontoLiquidado,
                                0
                            )
                            - B.MontoApostado
                            - B.ComisionServicio


                    WHEN B.Resultado = 'PERDEDOR'
                        THEN
                            -(
                                B.MontoApostado
                                + B.ComisionServicio
                             )


                    WHEN B.Resultado = 'ANULADO'
                        THEN 0


                    ELSE 0

                END
            ),
            0
        ) AS ResultadoNetoRealizado,


        /* ====================================================
           EFECTIVIDAD

           Solo GANADOR y PERDEDOR.
           ==================================================== */

        CONVERT
        (
            DECIMAL(7,2),

            ROUND
            (
                CONVERT
                (
                    DECIMAL(19,6),

                    SUM
                    (
                        CASE
                            WHEN B.Resultado = 'GANADOR'
                                THEN 1
                            ELSE 0
                        END
                    )
                )

                /

                NULLIF
                (
                    CONVERT
                    (
                        DECIMAL(19,6),

                        SUM
                        (
                            CASE
                                WHEN B.Resultado
                                     IN ('GANADOR', 'PERDEDOR')
                                    THEN 1
                                ELSE 0
                            END
                        )
                    ),
                    0
                )

                * 100,
                2
            )
        ) AS PorcentajeEfectividad,


        /* ====================================================
           CUOTA PROMEDIO
           ==================================================== */

        CONVERT
        (
            DECIMAL(12,4),

            AVG
            (
                CONVERT
                (
                    DECIMAL(19,6),
                    B.CuotaTotal
                )
            )
        ) AS CuotaPromedio,


        /* ====================================================
           PROBABILIDAD IMPLICITA PROMEDIO DE SUS BOLETOS
           ==================================================== */

        CONVERT
        (
            DECIMAL(7,2),

            ROUND
            (
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
                            B.CuotaTotal
                        ),
                        0
                    )
                ),
                2
            )
        ) AS ProbabilidadImplicitaPromedio


    FROM dbo.Boleto AS B


    LEFT JOIN dbo.LiquidacionBoleto AS LB
        ON LB.IdBoleto =
           B.IdBoleto


    WHERE B.IdUsuario =
          @IdUsuario;
END;
GO