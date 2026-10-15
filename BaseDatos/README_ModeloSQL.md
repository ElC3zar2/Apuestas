# Modelo SQL para instalación limpia

## Alcance y estado de verificación

Implementación local para revisión: 31 tablas funcionales, 62 procedimientos, 12 vistas, 43 índices explícitos y 6 triggers. Los índices de PK/UNIQUE no forman parte del conteo de índices explícitos.

La revisión inicial analizó los archivos con Microsoft ScriptDom (TSql160Parser), sin ejecutar SQL. Esta comprobación valida sintaxis, no resolución de nombres ni comportamiento transaccional. En la continuación local se consultó la restricción financiera y se reprodujo el defecto de fechas exclusivamente en una tabla temporal. No se aplicaron los procedimientos corregidos a la base ni se ejecutó la prueba 15; esa validación queda pendiente de ejecución manual.

## Instalación

1. LOCAL: abrir 00_INSTALL_LOCAL.sql; requiere permiso para crear PlataformaApuestas. AZURE: abrir 00_INSTALL_AZURE.sql conectado a una base previamente creada y vacía.
2. LOCAL: ejecutar SQLCMD desde `BaseDatos` con `-b -f 65001`. Las 27 inclusiones `:r` usan rutas relativas directas entre comillas; no utilizan `RutaBaseDatos`. No cambiar a sustituciones de variable en el instalador local: sqlcmd v15 fallo con ellas en la ejecucion informada por el usuario. Para AZURE, se conserva su instalador y el uso de `RutaBaseDatos`; en SSMS activar modo SQLCMD.
3. Ejecutar únicamente cuando el equipo autorice la instalación. Ambos instaladores incluyen los mismos scripts funcionales y la misma validación final por nombre. LOCAL agrega creación/selección de base. AZURE conserva la conexión actual.
4. No son migraciones: rechazan una instalación existente con dbo.Usuario. Si una instalación falla parcialmente, revisar el error y preparar nuevamente una base vacía; no interpretar estos archivos como reparación automática.

Orden: tablas → configuración 01 a 08 → procedimientos 01 a 12 → índices → vistas → auditoría → 01_DB/03_VerificarModelo.sql. Las referencias a procedimientos/vistas creados después se usan al invocar los procedimientos, tras completar la instalación. Los demos y pruebas no se incluyen.

La validación comprueba nombres de objetos e índices, columnas nuevas, restricciones habilitadas y confiables, 39 estados por tipo/código, roles, configuraciones, tipos de transacción, deportes, geografía, CASA y administradores. No exige que la base carezca de objetos auxiliares.

## Modalidades y contratos

Se conservan las apuestas CONVENCIONAL SIMPLE/COMPUESTO. MARCADOR_FINAL y PRIMERA_ANOTACION requieren eventos simulados compatibles con exactamente dos participantes, órdenes 1 (A) y 2 (B), y boletos SIMPLE independientes. Esta fase obtiene el resultado estructurado de la simulación.

MARCADOR_FINAL usa una selección genérica: el cliente envía PronosticoA/PronosticoB al cotizar y apostar. El servidor congela las cuotas y nombres al aceptar. EXACTO aplica Valor; RESULTADO aplica ValorResultado únicamente cuando no es exacto y coincide ganador/empate; NO_ACIERTO aplica cero; ANULADO aplica uno. Los retornos incluyen principal y no se suman entre sí. La configuración posterior no modifica boletos aceptados.

PRIMERA_ANOTACION usa dos selecciones vinculadas por FK a los participantes del evento. Gana la primera ANOTACION válida ordenada por Secuencia. Sin anotaciones válidas, se devuelve la apuesta. No se crean tipos de PREMIO separados.

Parámetros opcionales añadidos al final de las interfaces existentes: EsSimulado/DuracionSimulacionSegundos en creación de evento; TipoMercado en creación de mercado; IdParticipante en creación de selección; ValorResultado en cuota; PronosticoA/PronosticoB en cotización y aceptación; IdEventoCancelar en anulación. Revisar las firmas SQL exactas al integrar. Los clientes no envían clasificación, ganador, cuota de liquidación, importe de premio ni secuencia.

Las consultas conservan sus conjuntos principales y amplían columnas o añaden conjuntos de resultados para modalidades, incidencias, reservas y conciliación. Cotizar agrega un tercer conjunto con modalidad/pronóstico/retorno menor. ObtenerBoleto amplía cabecera y detalles; ObtenerLiquidacionBoleto agrega detalles; analítica y exploración agregan conjuntos. La futura integración deberá consumir explícitamente estos resultados; no se modificó Java/frontend.

## Simulación y resultado

Flujo: PROGRAMADO → EN_VIVO → PENDIENTE_RESULTADO → FINALIZADO. sp_IniciarSimulacionEvento inicializa marcador, cierra mercados/cuotas y registra UTC. No se aceptan apuestas EN_VIVO. El reloj predeterminado de 300 segundos es visual y puede excederse: no hay scheduler.

sp_RegistrarIncidenciaEvento asigna secuencia y hora en el servidor; ReferenciaOperacion permite reintentos idempotentes del mismo contenido. ANOTACION incrementa marcador: fútbol 1, baloncesto 1/2/3 y béisbol cualquier entero positivo. Las demás incidencias no puntúan; tarjetas se limitan a fútbol. No se modelan reglas deportivas profesionales.

sp_AnularIncidenciaEvento preserva el registro y exige motivo/usuario/fecha; recalcula marcador y primera anotación válida. La incidencia original no puede editarse ni eliminarse. Se permite corregir mientras el evento está EN_VIVO o PENDIENTE_RESULTADO, antes de liquidaciones. Estos procedimientos actualizan Evento para cambiar VersionFila.

sp_FinalizarSimulacionEvento cierra manualmente y registra resultado pendiente. sp_OficializarResultadoEvento invoca sp_ResolverApuestasModalidadEvento: calcula modalidades y pasa a FINALIZADO. Este último es un auxiliar transaccional y requiere una transacción existente; debe utilizarse a través de la oficialización. No permite pagos previos. Las selecciones convencionales siguen resolviéndose con sp_ResolverSeleccion.

La cancelación crea/anula el resultado y resuelve los detalles como anulados. La liquidación financiera se solicita después mediante sp_LiquidarBoleto; ni oficializar ni cancelar ejecutan automáticamente todos los pagos. La corrección de resultados se rechaza si existe alguna liquidación afectada.

## Finanzas y concurrencia

R = MAX(retorno máximo − monto apostado, comisión). La aceptación exige saldo CASA suficiente antes de acreditar la comisión y reserva R en la misma transacción que boleto, comisión, compromiso del usuario, movimientos y auditoría. La liquidación libera la reserva y aplica premio, pérdida o devolución; ReservaCasaPendiente queda en cero. Si R es cero no se crea un movimiento de importe cero.

RESERVA_CASA y LIBERACION_RESERVA_CASA registran el traslado disponible/comprometido. sp_ObtenerConciliacionCasa compara el comprometido de CASA con reservas pendientes y detecta reservas en boletos ya cerrados. Ajustar saldo virtual no altera el comprometido y verifica conciliación cuando corresponde a CASA.

Las mutaciones deportivas/financieras comparten un bloqueo transaccional exclusivo mediante sp_getapplock, además de los bloqueos existentes. Esto evita la carrera aceptación/inicio y conserva atomicidad, a costa de serializar operaciones de distintos eventos; decisión apropiada para esta fase académica, pendiente de medir antes de escalar. El timeout es 15 segundos y el llamador debe poder reintentar el error de bloqueo.

Las garantías de reglas entre tablas presuponen acceso mediante procedimientos; no se agregó un sistema de permisos SQL para impedir toda escritura directa de cuentas privilegiadas.

## Datos y pruebas posteriores

Los instaladores conservan catálogos, CASA con saldo inicial, y cinco administradores activos/verificados con rol ADMINISTRADOR. Los SQL de registro y seguridad se conservan byte a byte. No se crean clientes de presentación en instalación: el demo optativo usa el registro existente para seis clientes ficticios.

Ejecutar posteriormente en una base de pruebas limpia: verificación 01, pruebas existentes 02 a 10; revisar cada cabecera por sus datos y efectos. Para las nuevas modalidades: demo 01_DatosDemoRevision, demo 04_EscenariosModalidades, demo 02_VerificarDatosDemo, pruebas 13_PruebaModalidades y 14_PruebasNegativasModalidades, con configuraciones predeterminadas. Las pruebas de modalidades deben correrse antes de que venza la ventana de apuesta de los eventos programados; repetir en una base limpia para reproducir fechas.

Concurrencia convencional: seguir los archivos 01 a 07 de 11_CONCURRENCIA. Carrera apuesta/inicio: generar un contexto NUEVO con 01_PrepararConcurrencia, ejecutar 08_PrepararCarreraInicio y lanzar 09_SesionA_Inicio y 10_SesionB_ApuestaInicio en dos sesiones SSMS; luego 11_VerificarCarreraInicio. No reutilizar un contexto ya apostado/liquidado. Son aceptables cero apuestas (inicio primero) o una apuesta previa al inicio; nunca una aceptación posterior. El evento de prueba queda EN_VIVO y debe cancelarse/liquidarse mediante procedimientos o descartarse con la base de pruebas.

La limpieza demo es lógica: cancela eventos pendientes y liquida boletos elegibles. No borra usuarios, movimientos, auditoría ni incidencias; para reiniciar completamente, el equipo debe reconstruir una base de pruebas limpia.

## Pendiente de revisión

Instalación y ejecución real en SSMS, resultados de las pruebas funcionales y concurrentes y posterior integración de consumidores. No se ejecutaron SQL ni pruebas de base de datos durante esta implementación. No se implementaron funciones excluidas como apuestas en vivo, cuotas dinámicas, cash-out, dinero real o migraciones.

Liquidacion administrativa por evento: `sp_LiquidarBoletosEvento(@IdUsuarioProceso INT, @IdEvento INT, @IpOrigen VARCHAR(45) = NULL)` devuelve resumen y detalle, sin transaccion global. Cada boleto se confirma por separado bajo el mismo bloqueo de operacion del procedimiento individual. Los compuestos con cualquier seleccion pendiente se omiten. `sp_LiquidarBoleto` conserva el contrato habitual y admite al final `@EmitirResultado BIT = 1`; el lote usa 0. Los rechazos de negocio del procedimiento individual revierten solo el boleto y se omiten, sin replicar calculos financieros. Un fallo interno o de concurrencia posterior no deshace pagos anteriores: repetir la solicitud recupera esos boletos como idempotentes, sin volver a sumarlos al monto nuevo. La clasificacion nueva/idempotente se establece bajo bloqueo por boleto; un pago concurrente anterior a adquirir ese bloqueo se informa como ya liquidado.

Prueba local pendiente de ejecucion real: `07_PRUEBAS/15_PruebaLiquidacionLoteEvento.sql`, sobre una base descartable. El lote rechaza transacciones ambientales (62043): no envolver toda la prueba en un rollback global. SQL 62040/62041/62042 corresponden a HTTP 400/404/409; 62043/62044 son errores internos (500). No se requiere modificar instaladores.

La prueba SQL 15 valida automaticamente cantidades e importes contra el estado persistido y el esquema de los dos ResultSet con `WITH RESULT SETS`. Imprime el resumen esperado junto al real para comparacion visual; no utiliza `INSERT EXEC`, que puede introducir una transaccion ambiental. Las pruebas Java verifican estrictamente resumen, detalle y metadatos JDBC.

## Correccion local de fechas y preparacion de la prueba 15

El usuario informo una instalacion local correcta en `ML-RefVm-941826\SQLEXPRESS`, base `PlataformaApuestas`, con 31 tablas, 62 procedimientos, 12 vistas, 6 triggers y 43 indices explicitos. Tambien comprobo los catalogos Unicode; no se modificaron esos datos ni sus scripts.

La revision reprodujo realmente el defecto temporal mediante autenticacion de Windows y una tabla temporal: 20 000 inserciones con `FechaProcesamiento=SYSDATETIME()` y `FechaSolicitud DEFAULT SYSDATETIME()` produjeron 30 inversiones (procesamiento anterior a solicitud). La restriccion `CK_TransaccionFinanciera_Fechas` de la base esta habilitada y es confiable. El orden de evaluacion de dos expresiones de reloj no garantiza el orden temporal exigido; se elimina esa dependencia asignando ambas columnas desde una variable.

`sp_RealizarApuesta` usa `@FechaTransaccionApuesta` para FechaSolicitud y FechaProcesamiento en sus tres inserciones de apuesta y comisiones. La reserva conserva su par de fechas ya correcto. Con autorizacion adicional del usuario, se aplico el mismo arreglo minimo en el archivo de `sp_AjustarSaldoVirtual`, que financia la prueba. No se cambiaron importes, saldos, reservas, firmas, resultados ni la restriccion. Los procedimientos de liquidacion permanecen intactos.

Los defectos de inclusiones del instalador y de fechas eran preexistentes. La columna equivocada `ResultadoEvento.IdResultadoEvento` y el presupuesto insuficiente pertenecian al nuevo script 15: se conserva la correccion manual a `IdResultado` (sin reemplazar parametros/FK llamados IdResultadoEvento). La prueba financia exclusivamente su usuario nuevo con `sp_AjustarSaldoVirtual`, referencia UUID y credito minimo de Q2000, aumentado si nueve apuestas de monto minimo mas comision requieren mas saldo. Comprueba el saldo recibido y su transaccion, movimiento y auditoria, sin escribir directamente SaldoDisponible. Limpia solamente sus procedimientos y tablas temporales para admitir una repeticion en la misma conexion. Los escenarios persistentes usan un sufijo aleatorio nuevo; no se borran usuarios semilla ni se revierten globalmente los boletos liquidados.

No se aplicaron los procedimientos corregidos a la base ni se reejecuto la prueba 15 en esta revision: la ejecucion solicitada fue rechazada. Los comandos manuales siguientes usan autenticacion de Windows, sin contrasenas. No ejecutar el instalador limpio sobre la base existente. Desde PowerShell:

```powershell
Set-Location 'C:\Users\alumno\Desktop\proyecto\BaseDatos'
sqlcmd -S 'ML-RefVm-941826\SQLEXPRESS' -d PlataformaApuestas -E -b -f 65001 -i '.\03_PROCEDIMIENTOS\03_Billetera.sql'
# Continuar solo si el comando anterior termino con codigo 0.
sqlcmd -S 'ML-RefVm-941826\SQLEXPRESS' -d PlataformaApuestas -E -b -f 65001 -i '.\03_PROCEDIMIENTOS\05_Apuestas.sql'
# Continuar solo si el comando anterior termino con codigo 0.
sqlcmd -S 'ML-RefVm-941826\SQLEXPRESS' -d PlataformaApuestas -E -b -f 65001 -i '.\07_PRUEBAS\15_PruebaLiquidacionLoteEvento.sql'
```

Repetir el ultimo comando para crear otro escenario. Para comprobar repeticion en la misma conexion, abrir SSMS, seleccionar PlataformaApuestas y ejecutar dos veces el archivo completo sin transaccion ambiental. Los datos propios de prueba permanecen auditables. La comparacion de cada resumen emitido con ESPERADO sigue siendo visual; las aserciones automaticas validan el esquema de salida y el estado persistido. La validacion completa de los pagos corregidos queda pendiente de esa ejecucion manual.
