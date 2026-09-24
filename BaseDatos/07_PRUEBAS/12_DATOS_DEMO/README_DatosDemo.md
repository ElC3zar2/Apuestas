# Datos demo para revisión — PlataformaApuestas

Estos archivos preparan información ficticia para mostrar y probar el sistema sin alterar los catálogos críticos de la base.

## Orden recomendado

1. Ejecutar `01_DatosDemoRevision.sql`.
2. Ejecutar `02_VerificarDatosDemo.sql` para comprobar los datos.
3. Usar la aplicación con los usuarios de prueba.
4. Solo si se desea retirar la información ficticia, ejecutar `03_LimpiarDatosDemo.sql`.

## Credenciales generales

Todos los usuarios cliente creados por el script usan la misma contraseña académica:

**Contraseña:** `Admin123!`

Usuarios:

- `cliente.ana@apuestas.test`
- `cliente.carlos@apuestas.test`
- `cliente.sofia@apuestas.test`
- `cliente.mateo@apuestas.test`
- `cliente.lucia@apuestas.test`
- `cliente.diego@apuestas.test`

Los nombres, documentos, teléfonos, equipos, atletas, eventos y correos son ficticios y se usan únicamente para pruebas académicas.

## Qué se crea

El SQL principal genera seis clientes activos y verificados utilizando el flujo de registro del proyecto. También genera ligas, participantes, cuatro eventos futuros, mercados, selecciones, cuotas y tres boletos de ejemplo: dos simples y uno combinado.

Las fechas de los eventos se calculan desde el día en que se ejecuta por primera vez el script, para que aparezcan como próximos eventos durante la revisión.

## Catálogos protegidos

El script principal **no inserta, actualiza ni elimina** registros de:

`Rol`, `Pais`, `Departamento`, `Municipio`, `TipoEstado`, `Estado`, `Deporte`, `TipoTransaccion` y `ConfiguracionSistema`.

Esos catálogos únicamente se consultan para obtener IDs y configuraciones válidas.

## Consideraciones

El script usa los procedimientos almacenados existentes de PlataformaApuestas en lugar de insertar directamente en las tablas transaccionales. De esa manera respeta las validaciones, estados, billeteras, movimientos financieros y auditoría ya implementados.

No utilizar estas credenciales o estos datos como información de producción.
