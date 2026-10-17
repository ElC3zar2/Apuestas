# Verificación de correo y SMTP

## Estado e integración

La infraestructura ya está integrada. `SolicitarVerificacionCorreoServlet` atiende
`POST /usuario/seguridad/verificacion-correo/solicitar` para una sesión USUARIO.
`VerificacionCorreoServicio` genera un código de 43 caracteres, entrega su hash
SHA-256 al DAO y envía el código al correo de la sesión mediante `CorreoServicio`
y `CorreoSmtpServicio`. La vigencia e invalidación de tokens las decide SQL.

El formulario de `mi-cuenta.jsp`, mediante `seguridad-usuario.js`, solicita y
confirma el código por POST. `ConfirmarVerificacionCorreoServlet` recibe el
parámetro `token` en `/usuario/seguridad/verificacion-correo/confirmar` y utiliza
los procedimientos oficiales de verificación y sincronización en una transacción
JDBC. La respuesta `{"ok":true,"correoVerificado":true}` confirma el correo;
la activación también depende de la aprobación administrativa y las reglas SQL.

Falta configurar y validar un proveedor real en la Gigabyte. Las pruebas aisladas
no comprueban autenticación real, negociación TLS ni recepción en el buzón.

## Configuración externa

`ConfiguracionCorreo.desdeEntorno()` lee el entorno del proceso Java al enviar.
Confirmar un código no necesita configuración SMTP.
No lee ni modifica `config.properties` de base de datos.

| Variable | Regla |
| --- | --- |
| APUESTAS_MAIL_HOST | Host SMTP obligatorio, sin esquema ni puerto. |
| APUESTAS_MAIL_PORT | Puerto obligatorio del proveedor, entero entre 1 y 65535. |
| APUESTAS_MAIL_SECURITY | Exactamente STARTTLS o SSL. |
| APUESTAS_MAIL_USERNAME | Configurar si el proveedor exige autenticación; requiere PASSWORD. |
| APUESTAS_MAIL_PASSWORD | Solo externa; requiere USERNAME. No se recortan sus espacios. |
| APUESTAS_MAIL_FROM | Dirección única obligatoria autorizada por el proveedor. |
| APUESTAS_MAIL_FROM_NAME | Nombre opcional, UTF-8, sin CR/LF. |
| APUESTAS_MAIL_CONNECT_TIMEOUT_MS | Entero positivo; por defecto 10000. |
| APUESTAS_MAIL_READ_TIMEOUT_MS | Entero positivo; por defecto 10000. |
| APUESTAS_MAIL_WRITE_TIMEOUT_MS | Entero positivo; por defecto 10000. |
| APUESTAS_PUBLIC_BASE_URL | Opcional para códigos: ausente o vacía devuelve null en getUrlPublica(). Si se proporciona, se valida estrictamente. |

Los timeouts configurados admiten enteros positivos hasta 2147483647.
Ningún consumidor actual de producción usa `getUrlPublica()`: no hace falta
inventar una URL para el flujo de códigos y no se envían enlaces GET.
Si se proporciona, debe ser absoluta HTTPS, sin credenciales, query ni fragmento,
con puerto válido y ruta normalizada. Se devuelve sin slash final.
HTTP solo se admite para localhost, 127.0.0.1 o [::1]. HTTP con IP de la LAN sigue
rechazado; no usar la dirección LAN de Tomcat para evadir esta validación.
Si no se proporcionan usuario ni contraseña, se usa SMTP sin autenticación, siempre con TLS.

## Uso e integración

El servicio de negocio depende de `CorreoServicio`.
Su implementación `CorreoSmtpServicio` recibe la configuración y acepta `MensajeCorreo`.
Cada mensaje requiere destinatario, asunto y texto plano; HTML es opcional.
Con HTML se envía multipart/alternative, texto primero y HTML después.
No se agrega Reply-To. No hay reglas de verificación ni recuperación en el transportador.

STARTTLS exige negociación TLS; SSL conecta con TLS desde el inicio.
Elegir el puerto y el modo conforme al proveedor; no son intercambiables.
Ambos verifican la identidad del servidor y conservan la validación normal de certificados.
No se habilita debug, no se imprimen propiedades ni mensajes y no hay reintentos.

`EnvioCorreoException` contiene solo un mensaje seguro, sin encadenar respuestas del servidor.
Un error de cierre o una desconexión puede ocurrir después de que el servidor acepte el mensaje.
El caller debe decidir cualquier reintento: el transporte no garantiza entrega al buzón ni evita duplicados.

## Preparación manual de Tomcat

Procedimiento para el operador; no se ejecuta automáticamente en esta fase:

1. Obtener del proveedor el host, puerto, modo TLS, remitente autorizado y,
   cuando corresponda, usuario y secreto SMTP. No escribir secretos en el chat.
2. Configurar las variables de la tabla en el entorno que inicia Tomcat. Si lo
   inicia NetBeans, deben llegar al proceso Java que este inicia. Si funciona como
   servicio de Windows, usar el mecanismo de entorno del servicio y su cuenta;
   configurarlas en otra consola no basta.
3. Guardar los secretos en un mecanismo local protegido, fuera del repositorio,
   con acceso limitado al operador y a la cuenta que ejecuta Tomcat. Nunca incluir
   credenciales en Git, JSP, JS, Java, documentación, capturas ni scripts versionados.
4. Reiniciar manualmente el proceso que corresponda para heredar el entorno.
   No imprimir el entorno completo ni las propiedades para comprobarlo.
5. Comprobar la disponibilidad web antes de la prueba con un buzón controlado.

No se requieren nuevas dependencias, cambios SQL ni publicar el puerto 1433.

## Comprobación manual con un correo controlado

Realizar solo con autorización del operador, después de configurar el proveedor,
con un buzón bajo su control y el acceso seguro previsto para las pruebas.

1. Registrar o elegir una cuenta de prueba elegible con ese correo e iniciar sesión.
2. Solicitar un código desde Mi cuenta. La respuesta es genérica: no demuestra
   por sí sola que se haya creado o enviado un token. Una cuenta con correo ya
   verificado puede no generar mensaje.
3. Comprobar la recepción real, incluyendo spam o cuarentena si es necesario.
   Revisar remitente, asunto y caracteres UTF-8. No copiar el código a reportes.
4. Pegar el código completo de 43 caracteres en el formulario de confirmación,
   nunca en una URL. Comprobar la respuesta de correo verificado.
5. Consultar el estado oficial de la cuenta. La pantalla puede mostrar el estado
   del inicio de sesión; volver a iniciar sesión cuando corresponda. Comprobar
   por separado aprobación administrativa y habilitación resultante.
6. Un código consumido, invalidado o expirado debe rechazarse al reutilizarlo.
   No modificar SQL para facilitar la prueba. Una nueva solicitud puede invalidar
   códigos anteriores: utilizar el último código vigente.

Registrar fecha, etapa, resultado observado y códigos HTTP sin secretos, tokens
ni contenido privado. La aceptación SMTP y la entrega al buzón son evidencias
distintas: el proveedor puede aceptar un mensaje y luego retrasarlo, filtrarlo o
devolverlo. Consultar el estado de entrega del proveedor cuando esté disponible
y verificar recepción; una respuesta HTTP no demuestra entrega al buzón.

## Fallos y resultados inciertos

- Configuración ausente o inválida: revisar variables en el proceso correcto,
  host, puerto, modo exacto y pareja usuario/contraseña sin imprimir sus valores.
- Autenticación o remitente rechazados: comprobar los requisitos del proveedor
  fuera del chat y del repositorio.
- DNS, timeout o TLS: revisar conectividad de salida, puerto, modo, certificado e
  identidad del host. No desactivar TLS ni la comprobación de certificados.
- Código inválido: comprobar formato completo, vigencia y consumo previo. La
  confirmación mantiene un error uniforme para no revelar el estado del token.
- Error de configuración o envío: el token se crea antes de enviar SMTP; ese fallo
  no revierte automáticamente su creación. Revisar el buzón antes de solicitar
  manualmente otro código. No afirmar que llegó ni que no llegó.
- Fallo de cierre o desconexión posterior a la aceptación: el resultado puede ser
  incierto. No hay reintentos automáticos. Repetir puede duplicar mensajes o
  invalidar códigos anteriores; revisar el resultado antes de solicitar otro.

No activar trazas SMTP con autenticación o contenido sensible para los reportes.

## Pruebas

`PruebaCorreoSmtp.main` inyecta una fábrica de Transport sin sockets.
También verifica el MIME serializado, las propiedades TLS, los errores y el cierre de recursos.
Incluye URL ausente o vacía, rechazo de URL HTTP de LAN y credenciales incompletas.
Las credenciales de prueba se generan temporalmente y no se almacenan en archivos.
La comprobación del proveedor Angus solo obtiene y cierra el objeto; nunca lo conecta.

Desde la raíz del proyecto, con los componentes ya disponibles en Maven local:

```powershell
& 'C:\Program Files\NetBeans-21\netbeans\java\maven\bin\mvn.cmd' -o test-compile
& 'C:\Program Files\NetBeans-21\netbeans\java\maven\bin\mvn.cmd' -o org.codehaus.mojo:exec-maven-plugin:3.1.0:java '-Dexec.mainClass=com.apuestas.correo.PruebaCorreoSmtp' '-Dexec.classpathScope=test'
```

Estas pruebas no envían correos reales ni sustituyen la comprobación manual.
No usar el transporte por defecto para pruebas que deban permanecer sin red.

## Dependencias

API jakarta.mail:jakarta.mail-api:2.1.3 y proveedor org.eclipse.angus:angus-mail:2.0.4 (runtime).
Activation se resuelve transitivamente. Los servlets existentes siguen usando javax.servlet.
Se conservan Java 11 y Tomcat 9. No se instalan ni actualizan dependencias en esta fase.
