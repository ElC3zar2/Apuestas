/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   05_VISTAS/01_Vistas.sql

   OBJETIVO:
   Crear la capa definitiva de lectura para Java, reportes y
   consultas administrativas, evitando repetir JOIN complejos
   en DAO, servicios y JSP.

   PRINCIPIOS:
   - Las vistas NO modifican datos.
   - No exponen contraseñas ni hashes de tokens.
   - Las operaciones críticas siguen realizándose por medio
     de procedimientos almacenados.
   - Las vistas son compatibles con SQL Server 2022 y Azure SQL.
   ============================================================ */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO


/* ============================================================
   1. vw_EventosDisponibles

   Eventos actualmente publicables para apuestas.
   Incluye resumen de participantes y mercados.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_EventosDisponibles
AS
SELECT
    EV.IdEvento,
    EV.Nombre AS Evento,
    EV.FechaInicio,
    EV.FechaFin,
    EV.FechaCreacion,

    EE.Codigo AS EstadoEvento,
    EE.Nombre AS NombreEstadoEvento,

    L.IdLiga,
    L.Nombre AS Liga,

    D.IdDeporte,
    D.Nombre AS Deporte,

    L.IdPais,
    P.CodigoISO2 AS CodigoPais,
    P.Nombre AS Pais,

    (
        SELECT COUNT(*)
        FROM dbo.EventoParticipante AS EP
        WHERE EP.IdEvento = EV.IdEvento
    ) AS CantidadParticipantes,

    (
        SELECT COUNT(*)
        FROM dbo.Mercado AS M
        INNER JOIN dbo.Estado AS EM
            ON EM.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TEM
            ON TEM.IdTipoEstado = EM.IdTipoEstado
           AND TEM.Codigo = 'MERCADO'
        WHERE M.IdEvento = EV.IdEvento
          AND EM.Codigo = 'ABIERTO'
    ) AS MercadosAbiertos

FROM dbo.Evento AS EV

INNER JOIN dbo.Estado AS EE
    ON EE.IdEstado = EV.IdEstado

INNER JOIN dbo.TipoEstado AS TEE
    ON TEE.IdTipoEstado = EE.IdTipoEstado
   AND TEE.Codigo = 'EVENTO'

INNER JOIN dbo.Liga AS L
    ON L.IdLiga = EV.IdLiga

INNER JOIN dbo.Deporte AS D
    ON D.IdDeporte = L.IdDeporte

LEFT JOIN dbo.Pais AS P
    ON P.IdPais = L.IdPais

WHERE EE.Codigo IN ('PROGRAMADO', 'EN_VIVO');
GO


/* ============================================================
   2. vw_EventoParticipantes

   Participantes asociados a cada evento.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_EventoParticipantes
AS
SELECT
    EV.IdEvento,
    EV.Nombre AS Evento,

    EP.IdEventoParticipante,
    EP.OrdenParticipante,
    EP.EsLocal,

    PA.IdParticipante,
    PA.Nombre AS Participante,
    PA.TipoParticipante,
    PA.Activo AS ParticipanteActivo,

    D.IdDeporte,
    D.Nombre AS Deporte,

    PA.IdPais,
    P.CodigoISO2 AS CodigoPais,
    P.Nombre AS Pais

FROM dbo.EventoParticipante AS EP

INNER JOIN dbo.Evento AS EV
    ON EV.IdEvento = EP.IdEvento

INNER JOIN dbo.Participante AS PA
    ON PA.IdParticipante = EP.IdParticipante

INNER JOIN dbo.Deporte AS D
    ON D.IdDeporte = PA.IdDeporte

LEFT JOIN dbo.Pais AS P
    ON P.IdPais = PA.IdPais;
GO


/* ============================================================
   3. vw_MercadosAbiertos

   Mercados actualmente disponibles para recibir apuestas.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_MercadosAbiertos
AS
SELECT
    M.IdMercado,
    M.Nombre AS Mercado,
    M.Descripcion,
    M.FechaCreacion,

    EM.Codigo AS EstadoMercado,
    EM.Nombre AS NombreEstadoMercado,

    EV.IdEvento,
    EV.Nombre AS Evento,
    EV.FechaInicio,
    EV.FechaFin,

    EE.Codigo AS EstadoEvento,

    L.IdLiga,
    L.Nombre AS Liga,

    D.IdDeporte,
    D.Nombre AS Deporte,

    (
        SELECT COUNT(*)
        FROM dbo.Seleccion AS S
        WHERE S.IdMercado = M.IdMercado
          AND S.Activo = 1
    ) AS SeleccionesActivas

FROM dbo.Mercado AS M

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

INNER JOIN dbo.Liga AS L
    ON L.IdLiga = EV.IdLiga

INNER JOIN dbo.Deporte AS D
    ON D.IdDeporte = L.IdDeporte

WHERE EM.Codigo = 'ABIERTO'
  AND EE.Codigo IN ('PROGRAMADO', 'EN_VIVO');
GO


/* ============================================================
   4. vw_CuotasActuales

   Snapshot de selecciones y cuotas activas que pueden mostrarse
   en la interfaz de apuestas.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_CuotasActuales
AS
SELECT
    C.IdCuota,
    C.Valor AS Cuota,
    C.FechaInicio AS FechaInicioCuota,

    S.IdSeleccion,
    S.Nombre AS Seleccion,

    M.IdMercado,
    M.Nombre AS Mercado,

    EV.IdEvento,
    EV.Nombre AS Evento,
    EV.FechaInicio AS FechaInicioEvento,

    L.IdLiga,
    L.Nombre AS Liga,

    D.IdDeporte,
    D.Nombre AS Deporte

FROM dbo.Cuota AS C

INNER JOIN dbo.Seleccion AS S
    ON S.IdSeleccion = C.IdSeleccion
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

INNER JOIN dbo.Liga AS L
    ON L.IdLiga = EV.IdLiga

INNER JOIN dbo.Deporte AS D
    ON D.IdDeporte = L.IdDeporte

WHERE C.Activo = 1
  AND EM.Codigo = 'ABIERTO'
  AND EE.Codigo IN ('PROGRAMADO', 'EN_VIVO');
GO


/* ============================================================
   5. vw_BoletosUsuario

   Resumen de boletos para "Mis boletos" y consultas generales.
   Cada fila representa un boleto.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_BoletosUsuario
AS
SELECT
    B.IdBoleto,
    B.CodigoBoleto,

    B.IdUsuario,
    U.Correo,

    EB.Codigo AS EstadoBoleto,
    EB.Nombre AS NombreEstadoBoleto,

    B.TipoBoleto,
    B.Resultado,

    B.MontoApostado,
    B.CuotaTotal,
    B.GananciaPotencial,

    B.ReferenciaOperacion,

    B.FechaCreacion,
    B.FechaLiquidacion,

    COUNT(DB.IdDetalle) AS CantidadSelecciones,

    SUM
    (
        CASE
            WHEN DB.Resultado = 'GANADA' THEN 1
            ELSE 0
        END
    ) AS SeleccionesGanadas,

    SUM
    (
        CASE
            WHEN DB.Resultado = 'PERDIDA' THEN 1
            ELSE 0
        END
    ) AS SeleccionesPerdidas,

    SUM
    (
        CASE
            WHEN DB.Resultado = 'ANULADA' THEN 1
            ELSE 0
        END
    ) AS SeleccionesAnuladas,

    SUM
    (
        CASE
            WHEN DB.Resultado = 'PENDIENTE' THEN 1
            ELSE 0
        END
    ) AS SeleccionesPendientes

FROM dbo.Boleto AS B

INNER JOIN dbo.Usuario AS U
    ON U.IdUsuario = B.IdUsuario

INNER JOIN dbo.Estado AS EB
    ON EB.IdEstado = B.IdEstado

INNER JOIN dbo.TipoEstado AS TEB
    ON TEB.IdTipoEstado = EB.IdTipoEstado
   AND TEB.Codigo = 'BOLETO'

LEFT JOIN dbo.DetalleBoleto AS DB
    ON DB.IdBoleto = B.IdBoleto

GROUP BY
    B.IdBoleto,
    B.CodigoBoleto,
    B.IdUsuario,
    U.Correo,
    EB.Codigo,
    EB.Nombre,
    B.TipoBoleto,
    B.Resultado,
    B.MontoApostado,
    B.CuotaTotal,
    B.GananciaPotencial,
    B.ReferenciaOperacion,
    B.FechaCreacion,
    B.FechaLiquidacion;
GO


/* ============================================================
   6. vw_DetalleBoletos

   Detalle completo de selecciones incluidas en cada boleto.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_DetalleBoletos
AS
SELECT
    DB.IdDetalle,

    DB.IdBoleto,
    B.CodigoBoleto,
    B.IdUsuario,
    B.TipoBoleto,

    DB.Resultado AS ResultadoDetalle,
    DB.CuotaAplicada,

    S.IdSeleccion,
    S.Nombre AS Seleccion,

    M.IdMercado,
    M.Nombre AS Mercado,

    EV.IdEvento,
    EV.Nombre AS Evento,
    EV.FechaInicio,

    L.IdLiga,
    L.Nombre AS Liga,

    D.IdDeporte,
    D.Nombre AS Deporte

FROM dbo.DetalleBoleto AS DB

INNER JOIN dbo.Boleto AS B
    ON B.IdBoleto = DB.IdBoleto

INNER JOIN dbo.Seleccion AS S
    ON S.IdSeleccion = DB.IdSeleccion

INNER JOIN dbo.Mercado AS M
    ON M.IdMercado = S.IdMercado

INNER JOIN dbo.Evento AS EV
    ON EV.IdEvento = M.IdEvento

INNER JOIN dbo.Liga AS L
    ON L.IdLiga = EV.IdLiga

INNER JOIN dbo.Deporte AS D
    ON D.IdDeporte = L.IdDeporte;
GO


/* ============================================================
   7. vw_HistorialMovimientos

   Historial unificado de billetera y transacciones financieras.
   Útil para usuario, administración y auditoría.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_HistorialMovimientos
AS
SELECT
    U.IdUsuario,
    U.Correo,

    B.IdBilletera,

    M.IdMovimiento,
    M.FechaMovimiento,

    T.IdTransaccion,
    T.ReferenciaOperacion,
    T.IdBoleto,

    TT.Codigo AS TipoTransaccion,
    TT.Nombre AS NombreTipoTransaccion,

    ET.Codigo AS EstadoTransaccion,

    T.Monto,
    T.Descripcion,
    T.FechaSolicitud,
    T.FechaProcesamiento,

    M.SaldoDisponibleAnterior,
    M.SaldoDisponiblePosterior,

    CAST
    (
        M.SaldoDisponiblePosterior
        - M.SaldoDisponibleAnterior
        AS DECIMAL(12,2)
    ) AS VariacionDisponible,

    M.SaldoComprometidoAnterior,
    M.SaldoComprometidoPosterior,

    CAST
    (
        M.SaldoComprometidoPosterior
        - M.SaldoComprometidoAnterior
        AS DECIMAL(12,2)
    ) AS VariacionComprometido,

    T.IdUsuarioProceso,
    UP.Correo AS UsuarioProceso

FROM dbo.MovimientoBilletera AS M

INNER JOIN dbo.Billetera AS B
    ON B.IdBilletera = M.IdBilletera

INNER JOIN dbo.Usuario AS U
    ON U.IdUsuario = B.IdUsuario

INNER JOIN dbo.TransaccionFinanciera AS T
    ON T.IdTransaccion = M.IdTransaccion

INNER JOIN dbo.TipoTransaccion AS TT
    ON TT.IdTipoTransaccion = T.IdTipoTransaccion

INNER JOIN dbo.Estado AS ET
    ON ET.IdEstado = T.IdEstado

INNER JOIN dbo.TipoEstado AS TET
    ON TET.IdTipoEstado = ET.IdTipoEstado
   AND TET.Codigo = 'TRANSACCION'

LEFT JOIN dbo.Usuario AS UP
    ON UP.IdUsuario = T.IdUsuarioProceso;
GO


/* ============================================================
   8. vw_EstadoVerificacionUsuario

   Última verificación conocida por usuario cliente.
   No expone documentos ni información sensible innecesaria.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_EstadoVerificacionUsuario
AS
WITH UltimaVerificacion AS
(
    SELECT
        V.IdVerificacion,
        V.IdUsuario,
        V.IdEstado,
        V.IdUsuarioRevisor,
        V.FechaSolicitud,
        V.FechaInicioRevision,
        V.FechaResolucion,
        V.Observacion,

        ROW_NUMBER() OVER
        (
            PARTITION BY V.IdUsuario
            ORDER BY V.IdVerificacion DESC
        ) AS NumeroFila

    FROM dbo.VerificacionUsuario AS V
)
SELECT
    U.IdUsuario,
    U.Correo,
    U.CorreoVerificado,

    EU.Codigo AS EstadoUsuario,

    UV.IdVerificacion,

    EV.Codigo AS EstadoVerificacion,
    EV.Nombre AS NombreEstadoVerificacion,

    UV.FechaSolicitud,
    UV.FechaInicioRevision,
    UV.FechaResolucion,

    UV.IdUsuarioRevisor,
    UR.Correo AS UsuarioRevisor,

    UV.Observacion,

    CAST
    (
        CASE
            WHEN U.CorreoVerificado = 1
             AND EV.Codigo = 'APROBADA'
             AND EU.Codigo = 'ACTIVO'
                THEN 1
            ELSE 0
        END
        AS BIT
    ) AS HabilitadoParaApostar

FROM dbo.Usuario AS U

INNER JOIN dbo.Rol AS R
    ON R.IdRol = U.IdRol
   AND R.Nombre = 'USUARIO'

INNER JOIN dbo.Estado AS EU
    ON EU.IdEstado = U.IdEstado

INNER JOIN dbo.TipoEstado AS TEU
    ON TEU.IdTipoEstado = EU.IdTipoEstado
   AND TEU.Codigo = 'USUARIO'

LEFT JOIN UltimaVerificacion AS UV
    ON UV.IdUsuario = U.IdUsuario
   AND UV.NumeroFila = 1

LEFT JOIN dbo.Estado AS EV
    ON EV.IdEstado = UV.IdEstado

LEFT JOIN dbo.TipoEstado AS TEV
    ON TEV.IdTipoEstado = EV.IdTipoEstado
   AND TEV.Codigo = 'VERIFICACION'

LEFT JOIN dbo.Usuario AS UR
    ON UR.IdUsuario = UV.IdUsuarioRevisor;
GO


/* ============================================================
   9. vw_ResumenBilleteras

   Resumen general de todas las billeteras, incluyendo CASA.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_ResumenBilleteras
AS
SELECT
    U.IdUsuario,
    U.Correo,

    R.Nombre AS Rol,

    EU.Codigo AS EstadoUsuario,

    B.IdBilletera,
    B.SaldoDisponible,
    B.SaldoComprometido,

    CAST
    (
        B.SaldoDisponible + B.SaldoComprometido
        AS DECIMAL(12,2)
    ) AS SaldoVirtualTotal,

    B.FechaCreacion

FROM dbo.Billetera AS B

INNER JOIN dbo.Usuario AS U
    ON U.IdUsuario = B.IdUsuario

INNER JOIN dbo.Rol AS R
    ON R.IdRol = U.IdRol

INNER JOIN dbo.Estado AS EU
    ON EU.IdEstado = U.IdEstado

INNER JOIN dbo.TipoEstado AS TEU
    ON TEU.IdTipoEstado = EU.IdTipoEstado
   AND TEU.Codigo = 'USUARIO';
GO


/* ============================================================
   10. vw_ResumenAdministrativo

   Resumen agregado para panel administrativo.
   Una sola fila con indicadores principales del sistema.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_ResumenAdministrativo
AS
SELECT
    (
        SELECT COUNT(*)
        FROM dbo.Usuario AS U
        INNER JOIN dbo.Rol AS R
            ON R.IdRol = U.IdRol
        WHERE R.Nombre = 'USUARIO'
    ) AS TotalUsuariosCliente,

    (
        SELECT COUNT(*)
        FROM dbo.Usuario AS U
        INNER JOIN dbo.Rol AS R
            ON R.IdRol = U.IdRol
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'USUARIO'
        WHERE R.Nombre = 'USUARIO'
          AND E.Codigo = 'ACTIVO'
    ) AS UsuariosActivos,

    (
        SELECT COUNT(*)
        FROM dbo.vw_EstadoVerificacionUsuario
        WHERE EstadoVerificacion IN ('PENDIENTE', 'EN_REVISION')
    ) AS VerificacionesPendientes,

    (
        SELECT COUNT(*)
        FROM dbo.Evento AS EV
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = EV.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'EVENTO'
        WHERE E.Codigo IN ('PROGRAMADO', 'EN_VIVO')
    ) AS EventosDisponibles,

    (
        SELECT COUNT(*)
        FROM dbo.Mercado AS M
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'MERCADO'
        WHERE E.Codigo = 'ABIERTO'
    ) AS MercadosAbiertos,

    (
        SELECT COUNT(*)
        FROM dbo.Boleto
    ) AS TotalBoletos,

    (
        SELECT COUNT(*)
        FROM dbo.Boleto
        WHERE Resultado = 'PENDIENTE'
    ) AS BoletosPendientes,

    (
        SELECT COUNT(*)
        FROM dbo.Boleto
        WHERE Resultado = 'GANADOR'
    ) AS BoletosGanadores,

    (
        SELECT COUNT(*)
        FROM dbo.Boleto
        WHERE Resultado = 'PERDEDOR'
    ) AS BoletosPerdedores,

    (
        SELECT COUNT(*)
        FROM dbo.Boleto
        WHERE Resultado = 'ANULADO'
    ) AS BoletosAnulados,

    (
        SELECT COALESCE(SUM(SaldoDisponible), 0)
        FROM dbo.Billetera
    ) AS SaldoDisponibleSistema,

    (
        SELECT COALESCE(SUM(SaldoComprometido), 0)
        FROM dbo.Billetera
    ) AS SaldoComprometidoSistema;
GO


/* ============================================================
   11. VERIFICACION FINAL
   ============================================================ */

SELECT
    S.name AS Esquema,
    V.name AS Vista
FROM sys.views AS V
INNER JOIN sys.schemas AS S
    ON S.schema_id = V.schema_id
WHERE S.name = 'dbo'
  AND V.name IN
  (
      'vw_EventosDisponibles',
      'vw_EventoParticipantes',
      'vw_MercadosAbiertos',
      'vw_CuotasActuales',
      'vw_BoletosUsuario',
      'vw_DetalleBoletos',
      'vw_HistorialMovimientos',
      'vw_EstadoVerificacionUsuario',
      'vw_ResumenBilleteras',
      'vw_ResumenAdministrativo'
  )
ORDER BY V.name;
GO


PRINT '=======================================================';
PRINT ' VISTAS DEFINITIVAS CREADAS / ACTUALIZADAS';
PRINT '=======================================================';
GO