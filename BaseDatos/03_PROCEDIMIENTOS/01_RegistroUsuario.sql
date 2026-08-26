/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS
   ARCHIVO: 03_PROCEDIMIENTOS/01_RegistroUsuario.sql

   PROCEDIMIENTO:
   sp_RegistrarUsuarioCliente

   OBJETIVO:
   Registrar un usuario final y crear automáticamente
   su billetera y movimiento de saldo inicial.

   La operación completa es ATOMICA.
   ============================================================ */

/*USE PlataformaApuestas;
GO*/

CREATE OR ALTER PROCEDURE sp_RegistrarUsuarioCliente
    @Nombre VARCHAR(100),
    @Apellido VARCHAR(100),
    @Correo VARCHAR(150),
    @Contrasena VARCHAR(255),
    @FechaNacimiento DATE = NULL
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRANSACTION;

        DECLARE @IdRolUsuario INT;
        DECLARE @IdUsuario INT;
        DECLARE @IdBilletera INT;
        DECLARE @SaldoInicial DECIMAL(12,2);


        /* ==============================================
           OBTENER ROL DE USUARIO FINAL
           ============================================== */

        SELECT @IdRolUsuario = IdRol
        FROM Rol
        WHERE Nombre = 'USUARIO';


        IF @IdRolUsuario IS NULL
        BEGIN
            THROW 50001,
                  'No existe el rol USUARIO.',
                  1;
        END;


        /* ==============================================
           VALIDAR CORREO
           ============================================== */

        IF EXISTS
        (
            SELECT 1
            FROM Usuario
            WHERE Correo = @Correo
        )
        BEGIN
            THROW 50002,
                  'El correo ya se encuentra registrado.',
                  1;
        END;


        /* ==============================================
           OBTENER SALDO INICIAL
           ============================================== */

        SELECT @SaldoInicial =
            TRY_CAST(Valor AS DECIMAL(12,2))
        FROM ConfiguracionSistema
        WHERE Clave = 'SALDO_INICIAL_USUARIO';


        IF @SaldoInicial IS NULL
        BEGIN
            THROW 50003,
                  'No esta configurado el saldo inicial del usuario.',
                  1;
        END;


        IF @SaldoInicial < 0
        BEGIN
            THROW 50004,
                  'El saldo inicial no puede ser negativo.',
                  1;
        END;


        /* ==============================================
           CREAR USUARIO
           ============================================== */

        INSERT INTO Usuario
        (
            IdRol,
            Nombre,
            Apellido,
            Correo,
            Contrasena,
            FechaNacimiento
        )
        VALUES
        (
            @IdRolUsuario,
            @Nombre,
            @Apellido,
            @Correo,
            @Contrasena,
            @FechaNacimiento
        );


        SET @IdUsuario =
            CONVERT(INT, SCOPE_IDENTITY());


        /* ==============================================
           CREAR BILLETERA
           ============================================== */

        INSERT INTO Billetera
        (
            IdUsuario,
            SaldoDisponible,
            SaldoComprometido
        )
        VALUES
        (
            @IdUsuario,
            @SaldoInicial,
            0
        );


        SET @IdBilletera =
            CONVERT(INT, SCOPE_IDENTITY());


        /* ==============================================
           REGISTRAR MOVIMIENTO INICIAL
           ============================================== */

        IF @SaldoInicial > 0
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
                @IdBilletera,
                'DEPOSITO',
                @SaldoInicial,
                'Saldo inicial asignado automaticamente al crear la cuenta'
            );

        END;


        /* ==============================================
           CONFIRMAR TRANSACCION
           ============================================== */

        COMMIT TRANSACTION;


        /* ==============================================
           DEVOLVER RESULTADO A JAVA
           ============================================== */

        SELECT
            @IdUsuario AS IdUsuario,
            @IdBilletera AS IdBilletera,
            @SaldoInicial AS SaldoInicial;

    END TRY


    BEGIN CATCH

        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        THROW;

    END CATCH;

END;
GO

PRINT 'Procedimiento sp_RegistrarUsuarioCliente creado/actualizado.';
GO