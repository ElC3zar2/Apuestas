/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS
   SQL SERVER 2022

   ARCHIVO:
   04_INDICES/01_Indices.sql

   OBJETIVO:
   Crear indices adicionales para optimizar las consultas
   frecuentes y operaciones criticas del sistema.

   IMPORTANTE:
   No se duplican indices ya creados automaticamente por
   PRIMARY KEY o restricciones UNIQUE.
   ============================================================ */

USE PlataformaApuestas;
GO


/* ============================================================
   1. USUARIO POR ROL

   Util para:
   - Listar usuarios por rol
   - Administracion de usuarios
   - Seguridad y control de acceso

   Usuario.Correo NO necesita otro indice porque posee UNIQUE.
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Usuario_IdRol'
      AND object_id = OBJECT_ID('Usuario')
)
BEGIN

    CREATE INDEX IX_Usuario_IdRol
    ON Usuario (IdRol);

    PRINT 'Indice IX_Usuario_IdRol creado.';

END;
GO


/* ============================================================
   2. LIGAS POR DEPORTE

   Util para obtener rapidamente las ligas correspondientes
   a un deporte.

   NOTA:
   La restriccion UNIQUE (IdDeporte, Nombre) ya genera
   un indice compuesto, por lo que NO necesitamos crear
   otro indice solamente para IdDeporte.

   Se deja documentado intencionalmente.
   ============================================================ */


/* ============================================================
   3. PARTICIPANTES POR DEPORTE

   Util para:
   - Equipos de futbol
   - Equipos de baloncesto
   - Equipos de beisbol
   - Atletas de tenis
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Participante_IdDeporte'
      AND object_id = OBJECT_ID('Participante')
)
BEGIN

    CREATE INDEX IX_Participante_IdDeporte
    ON Participante (IdDeporte);

    PRINT 'Indice IX_Participante_IdDeporte creado.';

END;
GO


/* ============================================================
   4. EVENTOS POR LIGA, ESTADO Y FECHA

   Esta sera una de las consultas mas frecuentes.

   Ejemplo:
   mostrar eventos PROGRAMADOS de determinada liga
   ordenados por fecha.
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Evento_Liga_Estado_Fecha'
      AND object_id = OBJECT_ID('Evento')
)
BEGIN

    CREATE INDEX IX_Evento_Liga_Estado_Fecha
    ON Evento
    (
        IdLiga,
        Estado,
        FechaInicio
    );

    PRINT 'Indice IX_Evento_Liga_Estado_Fecha creado.';

END;
GO


/* ============================================================
   5. EVENTOS GLOBALES POR ESTADO Y FECHA

   Util para la pagina principal:

   SELECT ...
   FROM Evento
   WHERE Estado = 'PROGRAMADO'
   ORDER BY FechaInicio
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Evento_Estado_Fecha'
      AND object_id = OBJECT_ID('Evento')
)
BEGIN

    CREATE INDEX IX_Evento_Estado_Fecha
    ON Evento
    (
        Estado,
        FechaInicio
    )
    INCLUDE
    (
        IdLiga,
        Nombre
    );

    PRINT 'Indice IX_Evento_Estado_Fecha creado.';

END;
GO


/* ============================================================
   6. MERCADOS POR EVENTO

   Cuando un usuario abre un evento necesitaremos recuperar
   todos sus mercados.
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Mercado_IdEvento'
      AND object_id = OBJECT_ID('Mercado')
)
BEGIN

    CREATE INDEX IX_Mercado_IdEvento
    ON Mercado
    (
        IdEvento
    )
    INCLUDE
    (
        Nombre,
        Estado
    );

    PRINT 'Indice IX_Mercado_IdEvento creado.';

END;
GO


/* ============================================================
   7. SELECCIONES POR MERCADO
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Seleccion_IdMercado'
      AND object_id = OBJECT_ID('Seleccion')
)
BEGIN

    CREATE INDEX IX_Seleccion_IdMercado
    ON Seleccion
    (
        IdMercado
    )
    INCLUDE
    (
        Nombre,
        Estado
    );

    PRINT 'Indice IX_Seleccion_IdMercado creado.';

END;
GO


/* ============================================================
   8. CUOTAS POR SELECCION Y ESTADO

   Permite localizar rapidamente la cuota activa correspondiente
   a una seleccion.
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Cuota_Seleccion_Estado'
      AND object_id = OBJECT_ID('Cuota')
)
BEGIN

    CREATE INDEX IX_Cuota_Seleccion_Estado
    ON Cuota
    (
        IdSeleccion,
        Estado
    )
    INCLUDE
    (
        Valor,
        FechaInicio,
        FechaFin
    );

    PRINT 'Indice IX_Cuota_Seleccion_Estado creado.';

END;
GO


/* ============================================================
   9. MOVIMIENTOS DE BILLETERA

   Fundamental para:
   - Historial financiero
   - Auditoria
   - Estado de cuenta

   Normalmente consultaremos:
   WHERE IdBilletera = ?
   ORDER BY FechaMovimiento DESC
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_MovimientoBilletera_Billetera_Fecha'
      AND object_id = OBJECT_ID('MovimientoBilletera')
)
BEGIN

    CREATE INDEX IX_MovimientoBilletera_Billetera_Fecha
    ON MovimientoBilletera
    (
        IdBilletera,
        FechaMovimiento DESC
    )
    INCLUDE
    (
        TipoMovimiento,
        Monto
    );

    PRINT 'Indice IX_MovimientoBilletera_Billetera_Fecha creado.';

END;
GO


/* ============================================================
   10. BOLETOS POR USUARIO

   Fundamental para la pantalla:
   "Mis boletos"

   Permite consultar los boletos de un usuario por estado
   y fecha.
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Boleto_Usuario_Estado_Fecha'
      AND object_id = OBJECT_ID('Boleto')
)
BEGIN

    CREATE INDEX IX_Boleto_Usuario_Estado_Fecha
    ON Boleto
    (
        IdUsuario,
        Estado,
        FechaCreacion DESC
    )
    INCLUDE
    (
        MontoApostado,
        CuotaTotal,
        GananciaPotencial,
        TipoBoleto
    );

    PRINT 'Indice IX_Boleto_Usuario_Estado_Fecha creado.';

END;
GO


/* ============================================================
   11. DETALLES POR BOLETO

   Cuando se consulte un boleto necesitaremos recuperar
   rapidamente todas sus selecciones.
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_DetalleBoleto_IdBoleto'
      AND object_id = OBJECT_ID('DetalleBoleto')
)
BEGIN

    CREATE INDEX IX_DetalleBoleto_IdBoleto
    ON DetalleBoleto
    (
        IdBoleto
    )
    INCLUDE
    (
        IdSeleccion,
        CuotaAplicada,
        Resultado
    );

    PRINT 'Indice IX_DetalleBoleto_IdBoleto creado.';

END;
GO


/* ============================================================
   12. DETALLES POR SELECCION Y RESULTADO

   Sera especialmente util durante la liquidacion de apuestas.

   Cuando finalice un evento podremos localizar los detalles
   afectados por determinadas selecciones.
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_DetalleBoleto_Seleccion_Resultado'
      AND object_id = OBJECT_ID('DetalleBoleto')
)
BEGIN

    CREATE INDEX IX_DetalleBoleto_Seleccion_Resultado
    ON DetalleBoleto
    (
        IdSeleccion,
        Resultado
    )
    INCLUDE
    (
        IdBoleto,
        CuotaAplicada
    );

    PRINT 'Indice IX_DetalleBoleto_Seleccion_Resultado creado.';

END;
GO


/* ============================================================
   13. AUDITORIA POR USUARIO Y FECHA
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Auditoria_Usuario_Fecha'
      AND object_id = OBJECT_ID('Auditoria')
)
BEGIN

    CREATE INDEX IX_Auditoria_Usuario_Fecha
    ON Auditoria
    (
        IdUsuario,
        FechaAccion DESC
    )
    INCLUDE
    (
        Accion,
        TablaAfectada,
        IdRegistro
    );

    PRINT 'Indice IX_Auditoria_Usuario_Fecha creado.';

END;
GO


PRINT '=======================================================';
PRINT ' INDICES VERIFICADOS / CREADOS CORRECTAMENTE';
PRINT '=======================================================';
GO