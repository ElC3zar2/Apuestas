# Informe de corrección estructural final — BetZone

## 1. Estado

**Completado en archivos y validaciones permitidas.** Preparado para revisión e instalación limpia posterior por el usuario. La instalación SQL y la prueba funcional 16 no se ejecutaron. La base local permanece sin cambios.

## 2. Hallazgos previos

- No existía LigaParticipante ni relación equivalente. El catálogo filtraba solo por deporte y sp_AgregarParticipanteEvento solo comprobaba ese deporte.
- sp_CrearEvento ya protegía deportes sin UnidadMarcador con 76002; faltaba exponer la capacidad al consumidor.
- sp_CrearSeleccion rechazaba IdParticipante para cualquier modalidad distinta de PRIMERA_ANOTACION, aunque la FK al evento ya existía.
- La oficialización ya automatizaba PRIMERA_ANOTACION y MARCADOR_FINAL; CONVENCIONAL requería resolución manual.
- Listado y detalle agrupaban PENDIENTE_RESULTADO y FINALIZADO bajo EstadoVisual FINALIZADO.
- Los códigos 764xx ya pertenecían a operaciones financieras. Los nuevos códigos usan 766xx.
- FiltroCsrf existía sin registro global. Las dos nuevas escrituras lo aplican desde el servlet, incluido el retiro de _csrf de los parámetros de negocio.

## 3. Archivos modificados

| Ruta exacta | Motivo |
| --- | --- |
| [BaseDatos/README_ModeloSQL.md](<C:/Users/alumno/Desktop/proyecto/BaseDatos/README_ModeloSQL.md>) | Documentación del modelo, endpoints, códigos y ejecución manual. |
| [BaseDatos/01_DB/02_CrearTablas.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/01_DB/02_CrearTablas.sql>) | Tabla LigaParticipante y claves sin cascada. |
| [BaseDatos/01_DB/03_VerificarModelo.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/01_DB/03_VerificarModelo.sql>) | Verificación nominal, claves/columnas/FK e integridad deportiva. |
| [BaseDatos/02_CONFIGURACION/09_DATOS_INICIALES_OFICIALES.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/02_CONFIGURACION/09_DATOS_INICIALES_OFICIALES.sql>) | Pertenencias oficiales y selecciones con IdParticipante. |
| [BaseDatos/03_PROCEDIMIENTOS/04_EventosMercados.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/03_PROCEDIMIENTOS/04_EventosMercados.sql>) | Asociación/desasociación, pertenencia obligatoria y modalidades de selección. |
| [BaseDatos/03_PROCEDIMIENTOS/10_ExploracionEventos.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/03_PROCEDIMIENTOS/10_ExploracionEventos.sql>) | Separación visual pendiente/final, filtro y orden. |
| [BaseDatos/03_PROCEDIMIENTOS/12_SimulacionModalidades.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/03_PROCEDIMIENTOS/12_SimulacionModalidades.sql>) | Resolución convencional determinística y rechazo transaccional de contradicciones. |
| [BaseDatos/04_INDICES/01_Indices.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/04_INDICES/01_Indices.sql>) | Dos índices de consulta de LigaParticipante. |
| [BaseDatos/07_PRUEBAS/01_VerificarInstalacion.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/07_PRUEBAS/01_VerificarInstalacion.sql>) | Misma verificación nominal del modelo final. |
| [BaseDatos/07_PRUEBAS/04_PruebaEventosMercados.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/07_PRUEBAS/04_PruebaEventosMercados.sql>) | Fixture SQL: asociar por contrato antes de agregar participantes al evento. |
| [BaseDatos/07_PRUEBAS/05_PruebaApuestas.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/07_PRUEBAS/05_PruebaApuestas.sql>) | Fixture SQL: asociar por contrato antes de agregar participantes al evento. |
| [BaseDatos/07_PRUEBAS/06_PruebaResultadosLiquidacion.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/07_PRUEBAS/06_PruebaResultadosLiquidacion.sql>) | Fixture SQL: asociar por contrato antes de agregar participantes al evento. |
| [BaseDatos/07_PRUEBAS/08_PruebaRestricciones.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/07_PRUEBAS/08_PruebaRestricciones.sql>) | Fixture SQL: asociar por contrato antes de agregar participantes al evento. |
| [BaseDatos/07_PRUEBAS/15_PruebaLiquidacionLoteEvento.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/07_PRUEBAS/15_PruebaLiquidacionLoteEvento.sql>) | Fixture SQL: asociar por contrato antes de agregar participantes al evento. |
| [BaseDatos/07_PRUEBAS/11_CONCURRENCIA/01_PrepararConcurrencia.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/07_PRUEBAS/11_CONCURRENCIA/01_PrepararConcurrencia.sql>) | Fixture SQL: asociar por contrato antes de agregar participantes al evento. |
| [BaseDatos/07_PRUEBAS/12_DATOS_DEMO/01_DatosDemoRevision.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/07_PRUEBAS/12_DATOS_DEMO/01_DatosDemoRevision.sql>) | Asociaciones demo y participantes de selecciones declarados por códigos de fixture. |
| [src/main/java/com/apuestas/controlador/AdministracionEventosHttp.java](<C:/Users/alumno/Desktop/proyecto/src/main/java/com/apuestas/controlador/AdministracionEventosHttp.java>) | 76600..76606 y errores de concurrencia → HTTP. |
| [src/main/java/com/apuestas/controlador/AdministracionEventosServlet.java](<C:/Users/alumno/Desktop/proyecto/src/main/java/com/apuestas/controlador/AdministracionEventosServlet.java>) | Dos rutas POST y CSRF efectivo mediante el filtro existente. |
| [src/main/java/com/apuestas/controlador/AdministracionResultadosHttp.java](<C:/Users/alumno/Desktop/proyecto/src/main/java/com/apuestas/controlador/AdministracionResultadosHttp.java>) | 76607 → 409. |
| [src/main/java/com/apuestas/controlador/DeportesExploracionServlet.java](<C:/Users/alumno/Desktop/proyecto/src/main/java/com/apuestas/controlador/DeportesExploracionServlet.java>) | JSON permiteSimulacion y no-store. |
| [src/main/java/com/apuestas/dao/AdministracionEventosDAO.java](<C:/Users/alumno/Desktop/proyecto/src/main/java/com/apuestas/dao/AdministracionEventosDAO.java>) | CallableStatement y DTO estrictos de asociación. |
| [src/main/java/com/apuestas/dao/DeporteDAO.java](<C:/Users/alumno/Desktop/proyecto/src/main/java/com/apuestas/dao/DeporteDAO.java>) | Capacidad derivada en SQL y conexión sustituible para pruebas. |
| [src/main/java/com/apuestas/dao/ParticipanteDAO.java](<C:/Users/alumno/Desktop/proyecto/src/main/java/com/apuestas/dao/ParticipanteDAO.java>) | Filtro por liga, coherencia liga/deporte y parámetros preparados. |
| [src/main/java/com/apuestas/modelo/AdministracionEventosModelos.java](<C:/Users/alumno/Desktop/proyecto/src/main/java/com/apuestas/modelo/AdministracionEventosModelos.java>) | DTO LigaParticipante. |
| [src/main/java/com/apuestas/modelo/Deporte.java](<C:/Users/alumno/Desktop/proyecto/src/main/java/com/apuestas/modelo/Deporte.java>) | Propiedad permiteSimulacion. |
| [src/main/java/com/apuestas/modelo/OperacionAdministracionEventos.java](<C:/Users/alumno/Desktop/proyecto/src/main/java/com/apuestas/modelo/OperacionAdministracionEventos.java>) | Operaciones cerradas de asociación/desasociación. |
| [src/main/java/com/apuestas/servicio/CatalogoParticipantesServicio.java](<C:/Users/alumno/Desktop/proyecto/src/main/java/com/apuestas/servicio/CatalogoParticipantesServicio.java>) | idLiga opcional y validación cerrada. |
| [src/test/java/com/apuestas/controlador/PruebaAdministracionEventos.java](<C:/Users/alumno/Desktop/proyecto/src/test/java/com/apuestas/controlador/PruebaAdministracionEventos.java>) | Fixtures de nuevas operaciones, CSRF y rutas. |
| [src/test/java/com/apuestas/controlador/PruebaAdministracionResultados.java](<C:/Users/alumno/Desktop/proyecto/src/test/java/com/apuestas/controlador/PruebaAdministracionResultados.java>) | Conflicto 76607. |
| [src/test/java/com/apuestas/controlador/PruebaCatalogoParticipantes.java](<C:/Users/alumno/Desktop/proyecto/src/test/java/com/apuestas/controlador/PruebaCatalogoParticipantes.java>) | idLiga, validación, consulta JDBC y errores HTTP. |
| [src/test/java/com/apuestas/controlador/PruebaExploracionEventos.java](<C:/Users/alumno/Desktop/proyecto/src/test/java/com/apuestas/controlador/PruebaExploracionEventos.java>) | EstadoVisual pendiente/final conservado en listado y detalle. |
| [src/test/java/com/apuestas/controlador/PruebaIntegracionBackendAdministrativo.java](<C:/Users/alumno/Desktop/proyecto/src/test/java/com/apuestas/controlador/PruebaIntegracionBackendAdministrativo.java>) | Sesión con token CSRF, conservando las aserciones de identidad. |

## 4. Archivos nuevos

- [BaseDatos/07_PRUEBAS/16_PruebaCorreccionEstructural.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/07_PRUEBAS/16_PruebaCorreccionEstructural.sql>): 20 casos funcionales SQL aislados, con reversión, y aserciones de exploración.
- [src/test/java/com/apuestas/controlador/PruebaCorreccionEstructural.java](<C:/Users/alumno/Desktop/proyecto/src/test/java/com/apuestas/controlador/PruebaCorreccionEstructural.java>): 78 casos Java seguros para las nuevas escrituras y capacidad de simulación.
- [BaseDatos/INFORME_CorreccionEstructural.md](<C:/Users/alumno/Desktop/proyecto/BaseDatos/INFORME_CorreccionEstructural.md>): este informe de entrega.

## 5. Modelo SQL final

LigaParticipante contiene solo IdLiga INT NOT NULL, IdParticipante INT NOT NULL y Activo BIT NOT NULL DEFAULT 1. PK(IdLiga, IdParticipante), FKs a Liga y Participante con NO ACTION. Índices IX_LigaParticipante_Liga_Activo(IdLiga, Activo, IdParticipante) y IX_LigaParticipante_Participante(IdParticipante, IdLiga) INCLUDE(Activo).

La escritura oficial comprueba el mismo deporte bajo el bloqueo transaccional común de la plataforma. Asociar inserta/reactiva; repetir no duplica la pareja. Desasociar desactiva y conserva el historial. Los datos oficiales se vinculan mediante sus grupos declarados, y los demos mediante sus eventos explícitos; el país no decide pertenencias. La verificación sigue siendo nominal y termina con «Modelo funcional validado por nombre. No se exige ausencia de objetos auxiliares.»

## 6. Contratos backend

| Método y ruta | Parámetros y resultado |
| --- | --- |
| GET /administrador/participantes/listar | Nuevo idLiga opcional, compatible con idDeporte/buscar/pagina/tamanoPagina/activo. JSON paginado anterior. Liga activa y asociación activa; para disponibilidad usar activo=true. |
| POST /administrador/ligas/participantes/asociar | idLiga, idParticipante. 200: {ok:true,resultado:{idLiga,idParticipante,activo:true}}. |
| POST /administrador/ligas/participantes/desasociar | idLiga, idParticipante. 200: mismo DTO con activo:false. |
| GET /deportes/exploracion | Agrega permiteSimulacion booleano a cada deporte, sin quitar campos anteriores. |

Las tres rutas administrativas requieren ADMINISTRADOR u OPERADOR_EVENTOS. Actor desde sesión, nunca desde parámetros. Las escrituras exigen el token de GET /administrador/seguridad/csrf, por X-CSRF-Token o _csrf, con las comprobaciones de origen y sesión existentes. Se conservan parámetros cerrados, rechazo de duplicados/extra, 401/403 JSON, no-store y JDBC preparado. No se incorporaron reintentos financieros.

permiteSimulacion se calcula en el SELECT SQL mediante UnidadMarcador IS NOT NULL, exactamente la regla actual de sp_CrearEvento. No se reproduce esa regla en Java.

## 7. Selecciones

- CONVENCIONAL: participante opcional; si existe debe pertenecer al evento.
- PRIMERA_ANOTACION: participante obligatorio del evento.
- MARCADOR_FINAL: participante NULL y una selección genérica.

Se conserva la FK compuesta y 76010 → 400. Java ya admitía el parámetro opcional y conserva la posición de argumentos.

## 8. Resultados

PRIMERA_ANOTACION conserva su cálculo por incidencias y MARCADOR_FINAL su clasificación por pronóstico. Se agrega CONVENCIONAL solo con dos participantes en órdenes 1/2, marcador estructurado y deporte habilitado para marcador final. La forma activa debe ser exactamente A/B, con marcador desigual, o A/B/una neutral NULL. La neutral gana únicamente en empate.

Más selecciones, varias neutrales, participantes repetidos/ajenos, ausencia de datos o empate A/B sin neutral quedan manuales; 61024 impide oficializar mientras falten resoluciones. Los nombres no intervienen en decisiones. Una resolución compatible del mismo ResultadoEvento permanece intacta; una contradicción produce 76607 y revierte toda la oficialización. Repetir no agrega resoluciones duplicadas.

Se conserva oficialización deportiva → Evento FINALIZADO, ResultadoEvento OFICIAL, mercados LIQUIDADOS → liquidación financiera separada. No se modificó sp_LiquidarBoletosEvento ni el archivo 07_Liquidacion.sql.

## 9. Exploración de usuario

PENDIENTE_RESULTADO se expone como EstadoVisual PENDIENTE_RESULTADO y aparece en TODOS. FINALIZADO conserva EstadoVisual FINALIZADO. FINALIZADOS exige un evento realmente FINALIZADO. No se añadió una categoría pública ni se usó FechaFin para simular oficialización. Orden: EN_PROGRESO, PREVIA, PROGRAMADO, PENDIENTE_RESULTADO, FINALIZADO.

## 10. Códigos SQL / HTTP

| SQL | Contrato | HTTP |
| --- | --- | --- |
| 76600 | Identificadores inválidos | 400 |
| 76601 | Liga inexistente | 404 |
| 76602 | Participante inexistente | 404 |
| 76603 | Deportes incompatibles | 409 |
| 76604 | Liga/participante inactivo al asociar | 409 |
| 76605 | Asociación inexistente | 404 |
| 76606 | Participante sin asociación activa con liga del evento | 409 |
| 76607 | Resolución convencional previa contradictoria | 409 |
| 76002, 76010, 61024 | Simulación incompatible, participante incompatible, resolución pendiente; conservados | 409, 400, 409 |
| 76900, 1205, 1222 | Concurrencia en administración de eventos | 503 |
| 77015, 77016 | Verificación de claves/columnas/coherencia de LigaParticipante | Solo instalación |

## 11. Pruebas ejecutadas

Compilador instalado: javac 26.0.1 con **--release 11**, UTF-8. Se compilaron todas las fuentes principales y de prueba. Salida exclusivamente temporal; no se usó Maven para evitar escrituras en target. Las suites usaron dobles JDBC, sin SQL Server, SMTP ni servicios externos.

Comandos reales de compilación en PowerShell:

```powershell
& 'C:\Program Files\Apache NetBeans\jdk\bin\javac.exe' '@C:\Users\alumno\AppData\Local\Temp\betzone-final-0yky_f3f\classes.args'
& 'C:\Program Files\Apache NetBeans\jdk\bin\javac.exe' '@C:\Users\alumno\AppData\Local\Temp\betzone-final-0yky_f3f\test-classes.args'
```

Ambos: código de salida 0. La advertencia de tipos no comprobados de PruebaSeguridadBackend ya corresponde a su uso de dobles. Los archivos de argumentos contienen --release 11, -encoding UTF-8, classpath de dependencias locales y carpetas temporales de salida. El runtime de pruebas antepone servlet-api.jar de Tomcat local: la API Java EE de compilación no contiene los recursos de ejecución GenericServlet.

Cada comando de la tabla se ejecutó con este ejecutable y este prefijo de argumentos:

```powershell
$javaEstructural = 'C:\Program Files\Apache NetBeans\jdk\bin\java.exe'
$argsEstructural = 'C:\Users\alumno\AppData\Local\Temp\betzone-final-0yky_f3f'
```

| Comando PowerShell | Casos | Resultado |
| --- | ---: | --- |
| `& $javaEstructural "@$argsEstructural\PruebaCorreccionEstructural.args"` | 78 | 0 fallos, salida 0 |
| `& $javaEstructural "@$argsEstructural\PruebaCatalogoParticipantes.args"` | 107 | 0 fallos, salida 0 |
| `& $javaEstructural "@$argsEstructural\PruebaAdministracionEventos.args"` | 1217 | 0 fallos, salida 0 |
| `& $javaEstructural "@$argsEstructural\PruebaContratosAdministracionEventos.args"` | 105 | 0 fallos, salida 0 |
| `& $javaEstructural "@$argsEstructural\PruebaIntegracionBackendAdministrativo.args"` | 881 | 0 fallos, salida 0 |
| `& $javaEstructural "@$argsEstructural\PruebaAdministracionResultados.args"` | 606 | 0 fallos, salida 0 |
| `& $javaEstructural "@$argsEstructural\PruebaSeguridadBackend.args"` | 116 | 0 fallos, salida 0 |
| `& $javaEstructural "@$argsEstructural\PruebaExploracionEventos.args"` | 53 | 0 fallos, salida 0 |

**Total final: 3,163 casos, cero fallos.** Los mensajes de error emitidos por la suite de seguridad son escenarios controlados esperados. Las primeras ejecuciones detectaron un recurso de servlet faltante y un fixture de sesión sin token; se corrigió el entorno de ejecución y la preparación de la sesión, sin debilitar aserciones.

Validación SQL estática: Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser(true), cargado desde SSMS 22. Para cada texto: StringReader → parser.Parse(reader, ref errors). Se analizaron 56 scripts SQL, ambos instaladores expandidos y ambos cuerpos dinámicos del auxiliar de exploración de la prueba 16: **60 entradas, cero errores**. Solo análisis de texto, sin conexión SQL. Las 27 inclusiones locales permanecen entre comillas, relativas y con archivos existentes; ambos instaladores son idénticos a sus originales. Esta validación no certifica resolución de nombres ni comportamiento transaccional en SQL Server.

Se verificó UTF-8 de los archivos cambiados, sin caracteres de reemplazo ni mojibake nuevo, y se conservaron BOM/finales de línea preexistentes.

## 12. Prueba SQL manual

Ejecutar completo en SSMS, después de la instalación limpia:

[BaseDatos/07_PRUEBAS/16_PruebaCorreccionEstructural.sql](<C:/Users/alumno/Desktop/proyecto/BaseDatos/07_PRUEBAS/16_PruebaCorreccionEstructural.sql>)

Sin transacción ambiental y sin otras sesiones escribiendo. Requiere los datos oficiales y un usuario aprobado con saldo para tres boletos. Usa fixtures CE16 con GUID y revierte cada caso; puede avanzar identity aunque no persistan filas.

Esperado: 20 mensajes PASS CE16 caso ..., validación adicional del contrato visual y «CE16: 20 casos funcionales y contrato visual OK. Sin datos persistidos.». Cubre pertenencia, PK, deporte, modalidades, A/B/neutral, empate, ambigüedad, contradicción y conservación de resolución manual, idempotencia, primera anotación, pronóstico exacto, oficialización, saldos/reservas/ausencia de pagos y exploración TODOS/FINALIZADOS.

No se ejecutó esta prueba ni las demás pruebas SQL funcionales. La prueba 15 conserva sus commits y requiere una base descartable, según sus instrucciones existentes.

## 13. Instalación

Según análisis estático y pruebas Java, los archivos quedan preparados para que el usuario haga una instalación limpia y las validaciones funcionales posteriores. **No se afirma que una instalación SQL haya pasado.** 00_INSTALL_LOCAL.sql conserva byte por byte su contenido y sus inclusiones, compatibles con la invocación prevista desde BaseDatos:

```powershell
sqlcmd ... -b -f 65001 -i "00_INSTALL_LOCAL.sql"
```

La revisión no ejecutó SQLCMD ni conectó a SQL Server. No se produjo una migración de la base existente.

## 14. Riesgos / pendientes reales

- El usuario debe instalar desde cero y ejecutar en SSMS la prueba 16 y las suites SQL pertinentes; ScriptDom no sustituye su ejecución.
- Verificar caracteres especiales y repetir el flujo administrativo Java contra la nueva base. El esquema local actual aún no contiene estos cambios; desplegar backend junto con la nueva instalación.
- Los consumidores frontend deberán utilizar idLiga y permiteSimulacion en su fase posterior. No se editó JSP, CSS, JS ni assets.
- El filtro CSRF general permanece sin registro global, como estaba; las nuevas asociaciones sí exigen CSRF. Este trabajo no activa seguridad global sobre los consumidores existentes.

No se modificó login/registro, configuración, credenciales, pom.xml, .gitignore, .git, NetBeans ni target.

## 15. Git

**No se ejecutó ningún comando Git.**
