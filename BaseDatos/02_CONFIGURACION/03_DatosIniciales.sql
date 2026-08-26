/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS
   SQL SERVER 2022

   ARCHIVO:
   02_CONFIGURACION/03_DatosIniciales.sql

   OBJETIVO:
   Registrar los datos iniciales necesarios para que una
   instalación nueva del sistema pueda comenzar a funcionar.

   INCLUYE:
   - Deportes iniciales
   - Usuarios administradores
   - Cuenta interna CASA
   - Billetera inicial de CASA

   NO INCLUYE:
   - Datos temporales de pruebas
   - Eventos de prueba
   - Boletos de prueba
   ============================================================ */

/*USE PlataformaApuestas;
GO*/


/* ============================================================
   1. DEPORTES INICIALES
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM Deporte
    WHERE Nombre = 'Futbol'
)
BEGIN

    INSERT INTO Deporte
    (
        Nombre,
        Descripcion
    )
    VALUES
    (
        'Futbol',
        'Eventos y mercados relacionados con futbol'
    );

END;


IF NOT EXISTS
(
    SELECT 1
    FROM Deporte
    WHERE Nombre = 'Baloncesto'
)
BEGIN

    INSERT INTO Deporte
    (
        Nombre,
        Descripcion
    )
    VALUES
    (
        'Baloncesto',
        'Eventos y mercados relacionados con baloncesto'
    );

END;


IF NOT EXISTS
(
    SELECT 1
    FROM Deporte
    WHERE Nombre = 'Beisbol'
)
BEGIN

    INSERT INTO Deporte
    (
        Nombre,
        Descripcion
    )
    VALUES
    (
        'Beisbol',
        'Eventos y mercados relacionados con beisbol'
    );

END;


IF NOT EXISTS
(
    SELECT 1
    FROM Deporte
    WHERE Nombre = 'Tenis'
)
BEGIN

    INSERT INTO Deporte
    (
        Nombre,
        Descripcion
    )
    VALUES
    (
        'Tenis',
        'Eventos y mercados relacionados con tenis'
    );

END;

PRINT 'Deportes iniciales verificados.';
GO


/* ============================================================
   2. OBTENER ROL ADMINISTRADOR
   ============================================================ */

DECLARE @IdRolAdministrador INT;

SELECT @IdRolAdministrador = IdRol
FROM Rol
WHERE Nombre = 'ADMINISTRADOR';


IF @IdRolAdministrador IS NULL
BEGIN

    THROW 51001,
          'No existe el rol ADMINISTRADOR. Ejecute primero 02_Roles.sql.',
          1;

END;


/* ============================================================
   3. USUARIOS ADMINISTRADORES

   Contraseña temporal para ambiente académico:
   Admin123!

   La contraseña NO se almacena en texto plano.
   Los valores almacenados corresponden a hashes BCrypt.
   ============================================================ */


/* ---------------- GABRIEL ---------------- */

IF NOT EXISTS
(
    SELECT 1
    FROM Usuario
    WHERE Correo = 'gabriel@apuestas.local'
)
BEGIN

    INSERT INTO Usuario
    (
        IdRol,
        Nombre,
        Apellido,
        Correo,
        Contrasena
    )
    VALUES
    (
        @IdRolAdministrador,
        'Gabriel',
        'Administrador',
        'gabriel@apuestas.local',
        '$2a$12$y9tVQWGEeVH776CzAefsBeWONBLgTevtif6lKl8VcJlEvM2IL3zCK'
    );

END;


/* ---------------- WILSON ---------------- */

IF NOT EXISTS
(
    SELECT 1
    FROM Usuario
    WHERE Correo = 'wilson@apuestas.local'
)
BEGIN

    INSERT INTO Usuario
    (
        IdRol,
        Nombre,
        Apellido,
        Correo,
        Contrasena
    )
    VALUES
    (
        @IdRolAdministrador,
        'Wilson',
        'Administrador',
        'wilson@apuestas.local',
        '$2a$12$7JUXcSvSMwKRFVYPji5ECOeDLlssjCEd841qlWTLQiynrcj.gaUqS'
    );

END;


/* ---------------- OTTO ---------------- */

IF NOT EXISTS
(
    SELECT 1
    FROM Usuario
    WHERE Correo = 'otto@apuestas.local'
)
BEGIN

    INSERT INTO Usuario
    (
        IdRol,
        Nombre,
        Apellido,
        Correo,
        Contrasena
    )
    VALUES
    (
        @IdRolAdministrador,
        'Otto',
        'Administrador',
        'otto@apuestas.local',
        '$2a$12$m2Sc1VDDL7c/9k2Trx8beOSumDCEf8tDLSsUJBoE/4pANitW4qmQ6'
    );

END;


/* ---------------- KEVIN ---------------- */

IF NOT EXISTS
(
    SELECT 1
    FROM Usuario
    WHERE Correo = 'kevin@apuestas.local'
)
BEGIN

    INSERT INTO Usuario
    (
        IdRol,
        Nombre,
        Apellido,
        Correo,
        Contrasena
    )
    VALUES
    (
        @IdRolAdministrador,
        'Kevin',
        'Administrador',
        'kevin@apuestas.local',
        '$2a$12$FI3nVEOZfC9xPswhn1DYqevd59joP.Jl.fmDJXfMzWtsQhtYjFpsu'
    );

END;


/* ---------------- FERNANDO ---------------- */

IF NOT EXISTS
(
    SELECT 1
    FROM Usuario
    WHERE Correo = 'fernando@apuestas.local'
)
BEGIN

    INSERT INTO Usuario
    (
        IdRol,
        Nombre,
        Apellido,
        Correo,
        Contrasena
    )
    VALUES
    (
        @IdRolAdministrador,
        'Fernando',
        'Administrador',
        'fernando@apuestas.local',
        '$2a$12$zvUsdwaA5ohRKBl13OwjL.jMCZMXFO1cMNLKSiBv.7Dnv3eCWIDX2'
    );

END;

PRINT 'Usuarios administradores verificados.';
GO


/* ============================================================
   4. CUENTA INTERNA DE LA CASA

   CASA no representa a una persona.
   Es una cuenta interna del sistema que puede participar
   financieramente dentro de la simulacion.
   ============================================================ */

DECLARE @IdRolCasa INT;
DECLARE @IdUsuarioCasa INT;
DECLARE @SaldoInicialCasa DECIMAL(12,2);


SELECT @IdRolCasa = IdRol
FROM Rol
WHERE Nombre = 'CASA';


IF @IdRolCasa IS NULL
BEGIN

    THROW 51002,
          'No existe el rol CASA. Ejecute primero 02_Roles.sql.',
          1;

END;


/* Obtener capital inicial configurado */

SELECT @SaldoInicialCasa =
    TRY_CAST(Valor AS DECIMAL(12,2))
FROM ConfiguracionSistema
WHERE Clave = 'SALDO_INICIAL_CASA';


IF @SaldoInicialCasa IS NULL
BEGIN

    THROW 51003,
          'No se encuentra configurado SALDO_INICIAL_CASA.',
          1;

END;


IF @SaldoInicialCasa < 0
BEGIN

    THROW 51004,
          'El saldo inicial de CASA no puede ser negativo.',
          1;

END;


/* Crear usuario CASA */

IF NOT EXISTS
(
    SELECT 1
    FROM Usuario
    WHERE Correo = 'casa@apuestas.local'
)
BEGIN

    INSERT INTO Usuario
    (
        IdRol,
        Nombre,
        Apellido,
        Correo,
        Contrasena
    )
    VALUES
    (
        @IdRolCasa,
        'Casa',
        'Sistema',
        'casa@apuestas.local',
        '$2a$12$bLx8w0Q0trmFYKe3V2K7vOnARErmKKiyHhVgfV6of54l71zywS1Ti'
    );

END;


/* Obtener Id de CASA */

SELECT @IdUsuarioCasa = IdUsuario
FROM Usuario
WHERE Correo = 'casa@apuestas.local';


IF @IdUsuarioCasa IS NULL
BEGIN

    THROW 51005,
          'No fue posible obtener el usuario CASA.',
          1;

END;


/* ============================================================
   5. CREAR BILLETERA DE CASA
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM Billetera
    WHERE IdUsuario = @IdUsuarioCasa
)
BEGIN

    INSERT INTO Billetera
    (
        IdUsuario,
        SaldoDisponible,
        SaldoComprometido
    )
    VALUES
    (
        @IdUsuarioCasa,
        @SaldoInicialCasa,
        0
    );

END;


/* ============================================================
   6. REGISTRAR MOVIMIENTO FINANCIERO INICIAL DE CASA

   Esto permite que el saldo inicial tenga trazabilidad.
   ============================================================ */

DECLARE @IdBilleteraCasa INT;

SELECT @IdBilleteraCasa = IdBilletera
FROM Billetera
WHERE IdUsuario = @IdUsuarioCasa;


IF NOT EXISTS
(
    SELECT 1
    FROM MovimientoBilletera
    WHERE IdBilletera = @IdBilleteraCasa
      AND TipoMovimiento = 'DEPOSITO'
      AND Descripcion = 'Capital inicial de la casa'
)
AND @SaldoInicialCasa > 0
BEGIN

    INSERT INTO MovimientoBilletera
    (
        IdBilletera,
        TipoMovimiento,
        Monto,
        Descripcion
    )
    VALUES
    (
        @IdBilleteraCasa,
        'DEPOSITO',
        @SaldoInicialCasa,
        'Capital inicial de la casa'
    );

END;

GO


PRINT '=======================================================';
PRINT ' DATOS INICIALES VERIFICADOS CORRECTAMENTE';
PRINT '=======================================================';
GO