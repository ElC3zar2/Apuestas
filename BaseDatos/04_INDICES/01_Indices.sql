/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   04_INDICES/01_Indices.sql

   OBJETIVO:
   Crear los índices definitivos de soporte para:
   - Integridad adicional.
   - Búsquedas frecuentes.
   - Procedimientos almacenados.
   - Concurrencia.
   - Consultas administrativas.
   - Historial financiero y auditoría.

   IMPORTANTE:
   - El script es re-ejecutable.
   - No duplica índices creados automáticamente por PK/UQ
     salvo reglas adicionales que la estructura requiere.
   - No utiliza USE para mantener compatibilidad con Azure SQL.
   ============================================================ */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


/* ============================================================
   1. PERFIL USUARIO
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.PerfilUsuario')
      AND name = 'UX_PerfilUsuario_Documento'
)
BEGIN
    CREATE UNIQUE INDEX UX_PerfilUsuario_Documento
        ON dbo.PerfilUsuario
        (
            TipoDocumento,
            NumeroDocumento
        );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.PerfilUsuario')
      AND name = 'IX_PerfilUsuario_IdPais'
)
BEGIN
    CREATE INDEX IX_PerfilUsuario_IdPais
        ON dbo.PerfilUsuario(IdPais);
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.PerfilUsuario')
      AND name = 'IX_PerfilUsuario_IdMunicipio'
)
BEGIN
    CREATE INDEX IX_PerfilUsuario_IdMunicipio
        ON dbo.PerfilUsuario(IdMunicipio)
        WHERE IdMunicipio IS NOT NULL;
END;
GO


/* ============================================================
   2. USUARIO
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Usuario')
      AND name = 'IX_Usuario_IdRol_IdEstado'
)
BEGIN
    CREATE INDEX IX_Usuario_IdRol_IdEstado
        ON dbo.Usuario
        (
            IdRol,
            IdEstado
        )
        INCLUDE
        (
            Correo,
            CorreoVerificado,
            FechaRegistro
        );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Usuario')
      AND name = 'IX_Usuario_IdEstado_FechaRegistro'
)
BEGIN
    CREATE INDEX IX_Usuario_IdEstado_FechaRegistro
        ON dbo.Usuario
        (
            IdEstado,
            FechaRegistro
        )
        INCLUDE
        (
            IdRol,
            Correo,
            CorreoVerificado
        );
END;
GO


/* ============================================================
   3. VERIFICACION USUARIO
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.VerificacionUsuario')
      AND name = 'IX_VerificacionUsuario_Usuario_Ultima'
)
BEGIN
    CREATE INDEX IX_VerificacionUsuario_Usuario_Ultima
        ON dbo.VerificacionUsuario
        (
            IdUsuario,
            IdVerificacion DESC
        )
        INCLUDE
        (
            IdEstado,
            IdUsuarioRevisor,
            FechaSolicitud,
            FechaInicioRevision,
            FechaResolucion
        );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.VerificacionUsuario')
      AND name = 'IX_VerificacionUsuario_Estado_Solicitud'
)
BEGIN
    CREATE INDEX IX_VerificacionUsuario_Estado_Solicitud
        ON dbo.VerificacionUsuario
        (
            IdEstado,
            FechaSolicitud,
            IdVerificacion
        )
        INCLUDE
        (
            IdUsuario,
            IdUsuarioRevisor
        );
END;
GO


/* ============================================================
   4. RESTRICCIONES DE USUARIO
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.RestriccionUsuario')
      AND name = 'IX_RestriccionUsuario_Vigente'
)
BEGIN
    CREATE INDEX IX_RestriccionUsuario_Vigente
        ON dbo.RestriccionUsuario
        (
            IdUsuario,
            Activa,
            TipoRestriccion,
            FechaInicio,
            FechaFin
        )
        INCLUDE
        (
            IdRestriccion,
            Motivo,
            IdUsuarioRegistro
        );
END;
GO


/* ============================================================
   5. TOKEN SEGURIDAD
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.TokenSeguridad')
      AND name = 'IX_TokenSeguridad_Usuario_Tipo'
)
BEGIN
    CREATE INDEX IX_TokenSeguridad_Usuario_Tipo
        ON dbo.TokenSeguridad
        (
            IdUsuario,
            TipoToken,
            FechaUso,
            FechaExpiracion
        )
        INCLUDE
        (
            IdToken,
            TokenHash
        );
END;
GO


/* ============================================================
   6. GEOGRAFIA
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Departamento')
      AND name = 'IX_Departamento_Pais_Activo'
)
BEGIN
    CREATE INDEX IX_Departamento_Pais_Activo
        ON dbo.Departamento
        (
            IdPais,
            Activo
        )
        INCLUDE
        (
            IdDepartamento,
            Nombre
        );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Municipio')
      AND name = 'IX_Municipio_Departamento_Activo'
)
BEGIN
    CREATE INDEX IX_Municipio_Departamento_Activo
        ON dbo.Municipio
        (
            IdDepartamento,
            Activo
        )
        INCLUDE
        (
            IdMunicipio,
            Nombre
        );
END;
GO


/* ============================================================
   7. LIGAS Y PARTICIPANTES
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Liga')
      AND name = 'IX_Liga_Deporte_Activo'
)
BEGIN
    CREATE INDEX IX_Liga_Deporte_Activo
        ON dbo.Liga
        (
            IdDeporte,
            Activo
        )
        INCLUDE
        (
            IdLiga,
            IdPais,
            Nombre
        );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Liga')
      AND name = 'IX_Liga_IdPais'
)
BEGIN
    CREATE INDEX IX_Liga_IdPais
        ON dbo.Liga(IdPais)
        WHERE IdPais IS NOT NULL;
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Participante')
      AND name = 'UX_Participante_Deporte_Tipo_Nombre'
)
BEGIN
    CREATE UNIQUE INDEX UX_Participante_Deporte_Tipo_Nombre
        ON dbo.Participante
        (
            IdDeporte,
            TipoParticipante,
            Nombre
        );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Participante')
      AND name = 'IX_Participante_Deporte_Activo'
)
BEGIN
    CREATE INDEX IX_Participante_Deporte_Activo
        ON dbo.Participante
        (
            IdDeporte,
            Activo
        )
        INCLUDE
        (
            IdParticipante,
            IdPais,
            Nombre,
            TipoParticipante
        );
END;
GO


/* ============================================================
   8. EVENTOS
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Evento')
      AND name = 'IX_Evento_Liga_FechaInicio'
)
BEGIN
    CREATE INDEX IX_Evento_Liga_FechaInicio
        ON dbo.Evento
        (
            IdLiga,
            FechaInicio
        )
        INCLUDE
        (
            IdEvento,
            IdEstado,
            Nombre,
            FechaFin
        );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Evento')
      AND name = 'IX_Evento_Estado_FechaInicio'
)
BEGIN
    CREATE INDEX IX_Evento_Estado_FechaInicio
        ON dbo.Evento
        (
            IdEstado,
            FechaInicio
        )
        INCLUDE
        (
            IdEvento,
            IdLiga,
            Nombre,
            FechaFin
        );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.EventoParticipante')
      AND name = 'IX_EventoParticipante_Participante'
)
BEGIN
    CREATE INDEX IX_EventoParticipante_Participante
        ON dbo.EventoParticipante
        (
            IdParticipante,
            IdEvento
        )
        INCLUDE
        (
            OrdenParticipante,
            EsLocal
        );
END;
GO


/* ============================================================
   9. MERCADOS Y SELECCIONES
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Mercado')
      AND name = 'UX_Mercado_Evento_Nombre'
)
BEGIN
    CREATE UNIQUE INDEX UX_Mercado_Evento_Nombre
        ON dbo.Mercado
        (
            IdEvento,
            Nombre
        );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Mercado')
      AND name = 'IX_Mercado_Evento_Estado'
)
BEGIN
    CREATE INDEX IX_Mercado_Evento_Estado
        ON dbo.Mercado
        (
            IdEvento,
            IdEstado
        )
        INCLUDE
        (
            IdMercado,
            Nombre,
            Descripcion,
            FechaCreacion
        );
END;
GO


/* ============================================================
   10. CUOTAS
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Cuota')
      AND name = 'UX_Cuota_Seleccion_Activa'
)
BEGIN
    CREATE UNIQUE INDEX UX_Cuota_Seleccion_Activa
        ON dbo.Cuota(IdSeleccion)
        WHERE Activo = 1;
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Cuota')
      AND name = 'IX_Cuota_Seleccion_Historial'
)
BEGIN
    CREATE INDEX IX_Cuota_Seleccion_Historial
        ON dbo.Cuota
        (
            IdSeleccion,
            FechaInicio DESC
        )
        INCLUDE
        (
            IdCuota,
            Valor,
            FechaFin,
            Activo
        );
END;
GO


/* ============================================================
   11. RESULTADOS
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.ResultadoEvento')
      AND name = 'IX_ResultadoEvento_Estado_Fecha'
)
BEGIN
    CREATE INDEX IX_ResultadoEvento_Estado_Fecha
        ON dbo.ResultadoEvento
        (
            IdEstado,
            FechaRegistro
        )
        INCLUDE
        (
            IdResultado,
            IdEvento,
            IdUsuarioRegistro
        );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.ResolucionSeleccion')
      AND name = 'IX_ResolucionSeleccion_ResultadoEvento'
)
BEGIN
    CREATE INDEX IX_ResolucionSeleccion_ResultadoEvento
        ON dbo.ResolucionSeleccion
        (
            IdResultadoEvento,
            Resultado
        )
        INCLUDE
        (
            IdResolucion,
            IdSeleccion,
            FechaResolucion
        );
END;
GO


/* ============================================================
   12. BOLETOS
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Boleto')
      AND name = 'IX_Boleto_Usuario_Fecha'
)
BEGIN
    CREATE INDEX IX_Boleto_Usuario_Fecha
        ON dbo.Boleto
        (
            IdUsuario,
            FechaCreacion DESC
        )
        INCLUDE
        (
            IdBoleto,
            CodigoBoleto,
            IdEstado,
            MontoApostado,
            CuotaTotal,
            GananciaPotencial,
            TipoBoleto,
            Resultado,
            FechaLiquidacion
        );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Boleto')
      AND name = 'IX_Boleto_Estado_Resultado_Fecha'
)
BEGIN
    CREATE INDEX IX_Boleto_Estado_Resultado_Fecha
        ON dbo.Boleto
        (
            IdEstado,
            Resultado,
            FechaCreacion
        )
        INCLUDE
        (
            IdBoleto,
            IdUsuario,
            CodigoBoleto,
            MontoApostado,
            CuotaTotal,
            GananciaPotencial
        );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.DetalleBoleto')
      AND name = 'IX_DetalleBoleto_Seleccion_Resultado'
)
BEGIN
    CREATE INDEX IX_DetalleBoleto_Seleccion_Resultado
        ON dbo.DetalleBoleto
        (
            IdSeleccion,
            Resultado
        )
        INCLUDE
        (
            IdDetalle,
            IdBoleto,
            CuotaAplicada
        );
END;
GO


/* ============================================================
   13. TRANSACCIONES FINANCIERAS
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.TransaccionFinanciera')
      AND name = 'IX_TransaccionFinanciera_Billetera_Fecha'
)
BEGIN
    CREATE INDEX IX_TransaccionFinanciera_Billetera_Fecha
        ON dbo.TransaccionFinanciera
        (
            IdBilletera,
            FechaSolicitud DESC
        )
        INCLUDE
        (
            IdTransaccion,
            IdTipoTransaccion,
            IdEstado,
            IdBoleto,
            Monto,
            FechaProcesamiento,
            IdUsuarioProceso
        );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.TransaccionFinanciera')
      AND name = 'IX_TransaccionFinanciera_Boleto'
)
BEGIN
    CREATE INDEX IX_TransaccionFinanciera_Boleto
        ON dbo.TransaccionFinanciera
        (
            IdBoleto,
            IdTipoTransaccion
        )
        INCLUDE
        (
            IdTransaccion,
            IdBilletera,
            IdEstado,
            ReferenciaOperacion,
            Monto,
            FechaProcesamiento
        )
        WHERE IdBoleto IS NOT NULL;
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.TransaccionFinanciera')
      AND name = 'IX_TransaccionFinanciera_Estado_Fecha'
)
BEGIN
    CREATE INDEX IX_TransaccionFinanciera_Estado_Fecha
        ON dbo.TransaccionFinanciera
        (
            IdEstado,
            FechaSolicitud
        )
        INCLUDE
        (
            IdTransaccion,
            IdBilletera,
            IdTipoTransaccion,
            IdBoleto,
            Monto
        );
END;
GO


/* ============================================================
   14. MOVIMIENTOS DE BILLETERA
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.MovimientoBilletera')
      AND name = 'IX_MovimientoBilletera_Billetera_Fecha'
)
BEGIN
    CREATE INDEX IX_MovimientoBilletera_Billetera_Fecha
        ON dbo.MovimientoBilletera
        (
            IdBilletera,
            FechaMovimiento DESC
        )
        INCLUDE
        (
            IdMovimiento,
            IdTransaccion,
            SaldoDisponibleAnterior,
            SaldoDisponiblePosterior,
            SaldoComprometidoAnterior,
            SaldoComprometidoPosterior
        );
END;
GO


/* ============================================================
   15. LIQUIDACIONES
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.LiquidacionBoleto')
      AND name = 'IX_LiquidacionBoleto_Estado_Fecha'
)
BEGIN
    CREATE INDEX IX_LiquidacionBoleto_Estado_Fecha
        ON dbo.LiquidacionBoleto
        (
            IdEstado,
            FechaCreacion
        )
        INCLUDE
        (
            IdLiquidacion,
            IdBoleto,
            IdTransaccion,
            MontoLiquidado,
            FechaInicioProceso,
            FechaFinalizacion,
            IdUsuarioProceso
        );
END;
GO


/* ============================================================
   16. AUDITORIA
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Auditoria')
      AND name = 'IX_Auditoria_Usuario_Fecha'
)
BEGIN
    CREATE INDEX IX_Auditoria_Usuario_Fecha
        ON dbo.Auditoria
        (
            IdUsuario,
            FechaAccion DESC
        )
        INCLUDE
        (
            IdAuditoria,
            Accion,
            TablaAfectada,
            IdRegistro,
            ReferenciaOperacion,
            IpOrigen
        )
        WHERE IdUsuario IS NOT NULL;
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Auditoria')
      AND name = 'IX_Auditoria_Tabla_Registro_Fecha'
)
BEGIN
    CREATE INDEX IX_Auditoria_Tabla_Registro_Fecha
        ON dbo.Auditoria
        (
            TablaAfectada,
            IdRegistro,
            FechaAccion DESC
        )
        INCLUDE
        (
            IdAuditoria,
            IdUsuario,
            Accion,
            ReferenciaOperacion,
            IpOrigen
        )
        WHERE TablaAfectada IS NOT NULL
          AND IdRegistro IS NOT NULL;
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Auditoria')
      AND name = 'IX_Auditoria_ReferenciaOperacion'
)
BEGIN
    CREATE INDEX IX_Auditoria_ReferenciaOperacion
        ON dbo.Auditoria(ReferenciaOperacion)
        INCLUDE
        (
            IdAuditoria,
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            FechaAccion
        )
        WHERE ReferenciaOperacion IS NOT NULL;
END;
GO


/* ============================================================
   17. VERIFICACION FINAL
   ============================================================ */

SELECT
    OBJECT_SCHEMA_NAME(I.object_id) AS Esquema,
    OBJECT_NAME(I.object_id) AS Tabla,
    I.name AS Indice,
    I.is_unique AS EsUnico,
    I.has_filter AS EsFiltrado,
    I.filter_definition AS Filtro
FROM sys.indexes AS I
WHERE I.object_id IN
(
    OBJECT_ID('dbo.Usuario'),
    OBJECT_ID('dbo.PerfilUsuario'),
    OBJECT_ID('dbo.VerificacionUsuario'),
    OBJECT_ID('dbo.RestriccionUsuario'),
    OBJECT_ID('dbo.TokenSeguridad'),
    OBJECT_ID('dbo.Evento'),
    OBJECT_ID('dbo.Mercado'),
    OBJECT_ID('dbo.Cuota'),
    OBJECT_ID('dbo.Boleto'),
    OBJECT_ID('dbo.TransaccionFinanciera'),
    OBJECT_ID('dbo.MovimientoBilletera'),
    OBJECT_ID('dbo.LiquidacionBoleto'),
    OBJECT_ID('dbo.Auditoria')
)
AND I.name IS NOT NULL
ORDER BY
    Tabla,
    Indice;
GO


PRINT '=======================================================';
PRINT ' INDICES DEFINITIVOS CREADOS / VERIFICADOS';
PRINT '=======================================================';
GO