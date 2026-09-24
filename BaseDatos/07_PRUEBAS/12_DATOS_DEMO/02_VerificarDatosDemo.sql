/* ============================================================================
   PLATAFORMA APUESTAS - VERIFICACION DE DATOS DEMO
   Archivo: 02_VerificarDatosDemo.sql
   Solo realiza SELECT. No modifica datos.
   ============================================================================ */

SET NOCOUNT ON;

PRINT '=======================================================';
PRINT ' 1. USUARIOS DEMO';
PRINT '=======================================================';

SELECT
    U.IdUsuario,
    U.Correo,
    CONCAT(PU.Nombre, ' ', PU.Apellido) AS NombreCompleto,
    R.Nombre AS Rol,
    E.Codigo AS EstadoUsuario,
    U.CorreoVerificado,
    P.Nombre AS Pais,
    D.Nombre AS Departamento,
    M.Nombre AS Municipio,
    B.IdBilletera,
    B.SaldoDisponible,
    B.SaldoComprometido
FROM dbo.Usuario AS U
INNER JOIN dbo.Rol AS R
    ON R.IdRol = U.IdRol
INNER JOIN dbo.Estado AS E
    ON E.IdEstado = U.IdEstado
INNER JOIN dbo.PerfilUsuario AS PU
    ON PU.IdUsuario = U.IdUsuario
INNER JOIN dbo.Pais AS P
    ON P.IdPais = PU.IdPais
LEFT JOIN dbo.Municipio AS M
    ON M.IdMunicipio = PU.IdMunicipio
LEFT JOIN dbo.Departamento AS D
    ON D.IdDepartamento = M.IdDepartamento
LEFT JOIN dbo.Billetera AS B
    ON B.IdUsuario = U.IdUsuario
WHERE U.Correo LIKE 'cliente.%@apuestas.test'
ORDER BY U.IdUsuario;

PRINT '';
PRINT '=======================================================';
PRINT ' 2. VERIFICACION DE USUARIOS';
PRINT '=======================================================';

SELECT
    U.Correo,
    EV.Codigo AS EstadoVerificacion,
    V.FechaSolicitud,
    V.FechaInicioRevision,
    V.FechaResolucion,
    V.Observacion
FROM dbo.VerificacionUsuario AS V
INNER JOIN dbo.Usuario AS U
    ON U.IdUsuario = V.IdUsuario
INNER JOIN dbo.Estado AS EV
    ON EV.IdEstado = V.IdEstado
WHERE U.Correo LIKE 'cliente.%@apuestas.test'
ORDER BY U.Correo, V.IdVerificacion DESC;

PRINT '';
PRINT '=======================================================';
PRINT ' 3. EVENTOS / MERCADOS / CUOTAS DEMO';
PRINT '=======================================================';

SELECT
    EV.IdEvento,
    D.Nombre AS Deporte,
    L.Nombre AS Liga,
    EV.Nombre AS Evento,
    EV.FechaInicio,
    EE.Codigo AS EstadoEvento,
    M.IdMercado,
    M.Nombre AS Mercado,
    EM.Codigo AS EstadoMercado,
    S.IdSeleccion,
    S.Nombre AS Seleccion,
    C.Valor AS CuotaActiva
FROM dbo.Evento AS EV
INNER JOIN dbo.Liga AS L
    ON L.IdLiga = EV.IdLiga
INNER JOIN dbo.Deporte AS D
    ON D.IdDeporte = L.IdDeporte
INNER JOIN dbo.Estado AS EE
    ON EE.IdEstado = EV.IdEstado
INNER JOIN dbo.Mercado AS M
    ON M.IdEvento = EV.IdEvento
INNER JOIN dbo.Estado AS EM
    ON EM.IdEstado = M.IdEstado
INNER JOIN dbo.Seleccion AS S
    ON S.IdMercado = M.IdMercado
LEFT JOIN dbo.Cuota AS C
    ON C.IdSeleccion = S.IdSeleccion
   AND C.Activo = 1
   AND C.FechaFin IS NULL
WHERE EV.Nombre LIKE 'DEMO IA - %'
ORDER BY EV.FechaInicio, M.IdMercado, S.IdSeleccion;

PRINT '';
PRINT '=======================================================';
PRINT ' 4. BOLETOS DEMO';
PRINT '=======================================================';

SELECT
    B.IdBoleto,
    B.CodigoBoleto,
    U.Correo,
    EB.Codigo AS EstadoBoleto,
    B.TipoBoleto,
    B.MontoApostado,
    B.ComisionServicio,
    (B.MontoApostado + B.ComisionServicio) AS TotalCargo,
    B.CuotaTotal,
    B.GananciaPotencial,
    B.Resultado,
    B.FechaCreacion
FROM dbo.Boleto AS B
INNER JOIN dbo.Usuario AS U
    ON U.IdUsuario = B.IdUsuario
INNER JOIN dbo.Estado AS EB
    ON EB.IdEstado = B.IdEstado
WHERE U.Correo LIKE 'cliente.%@apuestas.test'
ORDER BY B.IdBoleto;

PRINT '';
PRINT '=======================================================';
PRINT ' 5. DETALLE DE BOLETOS';
PRINT '=======================================================';

SELECT
    B.CodigoBoleto,
    U.Correo,
    EV.Nombre AS Evento,
    M.Nombre AS Mercado,
    S.Nombre AS Seleccion,
    DB.CuotaAplicada,
    DB.Resultado
FROM dbo.DetalleBoleto AS DB
INNER JOIN dbo.Boleto AS B
    ON B.IdBoleto = DB.IdBoleto
INNER JOIN dbo.Usuario AS U
    ON U.IdUsuario = B.IdUsuario
INNER JOIN dbo.Seleccion AS S
    ON S.IdSeleccion = DB.IdSeleccion
INNER JOIN dbo.Mercado AS M
    ON M.IdMercado = S.IdMercado
INNER JOIN dbo.Evento AS EV
    ON EV.IdEvento = M.IdEvento
WHERE U.Correo LIKE 'cliente.%@apuestas.test'
ORDER BY B.IdBoleto, DB.IdDetalle;

PRINT '';
PRINT '=======================================================';
PRINT ' 6. RESUMEN DE CANTIDADES';
PRINT '=======================================================';

SELECT
    (SELECT COUNT(*) FROM dbo.Usuario WHERE Correo LIKE 'cliente.%@apuestas.test') AS UsuariosDemo,
    (SELECT COUNT(*) FROM dbo.Liga WHERE Nombre LIKE 'DEMO IA - %') AS LigasDemo,
    (SELECT COUNT(*) FROM dbo.Participante WHERE Nombre LIKE 'DEMO IA - %') AS ParticipantesDemo,
    (SELECT COUNT(*) FROM dbo.Evento WHERE Nombre LIKE 'DEMO IA - %') AS EventosDemo,
    (
        SELECT COUNT(*)
        FROM dbo.Mercado AS M
        INNER JOIN dbo.Evento AS E ON E.IdEvento = M.IdEvento
        WHERE E.Nombre LIKE 'DEMO IA - %'
    ) AS MercadosDemo,
    (
        SELECT COUNT(*)
        FROM dbo.Boleto AS B
        INNER JOIN dbo.Usuario AS U ON U.IdUsuario = B.IdUsuario
        WHERE U.Correo LIKE 'cliente.%@apuestas.test'
    ) AS BoletosDemo;
