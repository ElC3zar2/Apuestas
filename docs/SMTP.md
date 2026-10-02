# Infraestructura SMTP

Este componente no está conectado todavía a usuarios, tokens ni endpoints.

## Configuración externa

Crear `ConfiguracionCorreo.desdeEntorno()` al configurar el futuro servicio de negocio.
No lee ni modifica `config.properties` de base de datos.

| Variable | Regla |
| --- | --- |
| APUESTAS_MAIL_HOST | Host SMTP obligatorio, sin esquema ni puerto. |
| APUESTAS_MAIL_PORT | Puerto obligatorio, entero entre 1 y 65535. |
| APUESTAS_MAIL_SECURITY | Exactamente STARTTLS o SSL. |
| APUESTAS_MAIL_USERNAME | Opcional; requiere PASSWORD si está presente. |
| APUESTAS_MAIL_PASSWORD | Solo externa; requiere USERNAME. No se recortan sus espacios. |
| APUESTAS_MAIL_FROM | Dirección única obligatoria. |
| APUESTAS_MAIL_FROM_NAME | Nombre opcional, UTF-8, sin CR/LF. |
| APUESTAS_MAIL_CONNECT_TIMEOUT_MS | Entero positivo; por defecto 10000. |
| APUESTAS_MAIL_READ_TIMEOUT_MS | Entero positivo; por defecto 10000. |
| APUESTAS_MAIL_WRITE_TIMEOUT_MS | Entero positivo; por defecto 10000. |
| APUESTAS_PUBLIC_BASE_URL | URL absoluta HTTPS, sin credenciales, query ni fragmento. |

HTTP solo se admite para localhost, 127.0.0.1 o [::1] durante desarrollo local.
La URL base se devuelve sin slash final. No se construyen enlaces en este bloque.
Configurar las variables en el entorno del proceso Tomcat, sin guardarlas en código ni en el repositorio.
Si no se proporcionan usuario ni contraseña, se usa SMTP sin autenticación, siempre con TLS.

## Uso e integración

El servicio de negocio dependerá de `CorreoServicio`.
Su implementación `CorreoSmtpServicio` recibe la configuración y acepta `MensajeCorreo`.
Cada mensaje requiere destinatario, asunto y texto plano; HTML es opcional.
Con HTML se envía multipart/alternative, texto primero y HTML después.
No se agrega Reply-To. No hay reglas de verificación ni recuperación en el transportador.

STARTTLS exige negociación TLS; SSL conecta con TLS desde el inicio.
Ambos verifican la identidad del servidor y conservan la validación normal de certificados.
No se habilita debug, no se imprimen propiedades ni mensajes y no hay reintentos.

`EnvioCorreoException` contiene solo un mensaje seguro, sin encadenar respuestas del servidor.
Un error de cierre o una desconexión puede ocurrir después de que el servidor acepte el mensaje.
El caller debe decidir cualquier reintento: el transporte no garantiza entrega al buzón ni evita duplicados.

## Pruebas

`PruebaCorreoSmtp.main` inyecta una fábrica de Transport sin sockets.
También verifica el MIME serializado, las propiedades TLS, los errores y el cierre de recursos.
Las credenciales de prueba se generan temporalmente y no se almacenan en archivos.
La comprobación del proveedor Angus solo obtiene y cierra el objeto; nunca lo conecta.

Compilar con Maven test-compile y ejecutar el main con las dependencias Maven en el classpath.
No usar el transporte por defecto para pruebas que deban permanecer sin red.

## Dependencias

API jakarta.mail:jakarta.mail-api:2.1.3 y proveedor org.eclipse.angus:angus-mail:2.0.4 (runtime).
Activation se resuelve transitivamente. Los servlets existentes siguen usando javax.servlet.
