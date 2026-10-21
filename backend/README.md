# Cauce Backend

Backend REST del sistema **Cauce**, construido con FastAPI. Esta etapa contiene únicamente la infraestructura base (esqueleto): configuración, base de datos, router principal, health check, logging, CORS, manejo básico de errores, migraciones y tests. La lógica de negocio (usuarios, dispositivos, heartbeats, experiencias, contenido, programaciones, comunicación con dispositivos) se incorporará en etapas posteriores.

## Flujo de trabajo (PC + servidor)

- **PC**: edición de código en la carpeta sincronizada (Syncthing). No se ejecuta nada aquí.
- **Servidor**: recibe los cambios por sincronización y ejecuta todo (instalación, tests, migraciones, Docker, servidor de aplicación), conectándose por SSH.
- **PC (pruebas)**: acceso por red local a `http://<IP_SERVIDOR>:8000`.

> El `.stignore` excluye de la sincronización `.venv`, caches de Python, `postgres_data` y el `.env` real. **Debe vivir en la raíz de la carpeta compartida de Syncthing** (un ancestro del proyecto, p. ej. `D:\Syncthing\.stignore` o `D:\Maker-sync\.stignore` — no dentro de `Cauce_Stream`), y se sincroniza entre dispositivos. Práctica más robusta: crear el venv fuera de la carpeta sincronizada (p. ej. `D:\venvs\cauce`), inmune a la sincronización en ambas direcciones.

## Stack

- Python 3.12+
- FastAPI + Uvicorn
- Pydantic v2 / Pydantic Settings
- SQLAlchemy 2.x (async, asyncpg)
- PostgreSQL
- Alembic
- pytest + httpx

## Estructura

```
backend/
├── app/
│   ├── main.py            # Entry point, creación de la app
│   ├── core/              # Configuración, BD, logging, excepciones
│   ├── api/               # Routers y dependencias HTTP
│   │   └── routes/
│   ├── schemas/           # Modelos Pydantic (entrada/salida de API)
│   ├── models/            # Modelos ORM SQLAlchemy (futuro)
│   ├── repositories/      # Acceso a datos (futuro)
│   ├── services/          # Lógica de negocio (futuro)
│   └── utils/
├── alembic/               # Migraciones
├── tests/                 # pytest
├── .env.example
├── alembic.ini
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
└── requirements-dev.txt
```

Separación de responsabilidades: `api` (HTTP) → `services` (negocio) → `repositories` (datos) → `models` (ORM). Los endpoints no contienen lógica de negocio ni SQL directo.

## Requisitos (en el servidor)

- Docker + Docker Compose (recomendado, incluye PostgreSQL), **o**
- Python 3.12+ y PostgreSQL nativos

## Opción A: Docker (recomendado)

Desde SSH, en `backend/`:

```bash
docker compose up --build -d
```

Levanta dos servicios:

- `db`: PostgreSQL 16 (usuario/contraseña/base: `cauce`)
- `backend`: Uvicorn en `0.0.0.0:8000`; ejecuta `alembic upgrade head` antes de arrancar (sin efecto hasta que existan migraciones)

Ver logs o parar:

```bash
docker compose logs -f backend
docker compose down            # (añadir -v para borrar también el volumen de la BD)
```

Desde la PC: `http://<IP_SERVIDOR>:8000/docs`.

## Opción B: entorno virtual en el servidor (Windows)

```powershell
# Por SSH en el servidor
cd D:\Syncthing\Cauce_Stream\backend

python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
```

Si PowerShell bloquea la activación: `Set-ExecutionPolicy -Scope Process RemoteSigned`.

### Configuración (.env)

El `.env` no se sincroniza: crearlo en el servidor a partir del ejemplo:

```bash
cp .env.example .env
```

Variables principales:

| Variable       | Descripción                                          | Ejemplo                                              |
|----------------|------------------------------------------------------|------------------------------------------------------|
| `DATABASE_URL` | URL de PostgreSQL con driver asyncpg                | `postgresql+asyncpg://cauce:cauce@localhost:5432/cauce` |
| `APP_ENV`      | `development` \| `testing` \| `production`           | `development`                                        |
| `DEBUG`        | Modo debug de FastAPI                                | `true`                                               |
| `CORS_ORIGINS` | Orígenes permitidos, separados por coma (vacío = off)| `http://localhost:3000`                              |
| `LOG_LEVEL`    | Nivel de logging                                     | `INFO`                                               |

Con la Opción A la base de datos puede reutilizarse desde el host: si `db` corre por Docker, `DATABASE_URL` con host `localhost` funciona en el servidor.

### Ejecutar el backend

```bash
uvicorn app.main:app --host 0.0.0.0 --reload
```

`--host 0.0.0.0` es imprescindible para que sea alcanzable desde la PC. `--reload` solo para desarrollo.

Endpoints:

- `GET /` → respuesta mínima indicando que el backend funciona
- `GET /api/health` → `{"status": "ok"}`
- `GET /docs` → documentación interactiva (Swagger UI)
- `GET /redoc` → documentación (ReDoc)

Si la PC no conecta: verificar el firewall del servidor (p. ej. permitir el puerto 8000 en el Firewall de Windows: `New-NetFirewallRule -DisplayName "Cauce 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow`).

### Solución de problemas (servidor Windows)

- **`failed to connect to the docker API at npipe:////./pipe/docker_engine`**: el daemon no está corriendo. Abrir Docker Desktop (o `Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"`) y esperar a que `docker info` responda.
- **`error getting credentials ... A specified logon session does not exist`** en cada pull de docker.io: el backend de Docker Desktop consulta el Administrador de credenciales de Windows al tirar de Docker Hub; si Docker Desktop se arrancó desde una sesión SSH (no interactiva), no puede acceder a él. No depende del `config.json` del CLI. Solución sin tocar el proyecto: tirar del mirror público de Amazon (anónimo) y reetiquetar:

  ```powershell
  docker pull public.ecr.aws/docker/library/postgres:16-alpine
  docker pull public.ecr.aws/docker/library/python:3.12-slim
  docker tag public.ecr.aws/docker/library/postgres:16-alpine postgres:16-alpine
  docker tag public.ecr.aws/docker/library/python:3.12-slim python:3.12-slim
  ```

  Solución de fondo (requiere acceso gráfico una única vez): inicio de sesión automático + "Start Docker Desktop when you sign in", para que Docker Desktop corra en la sesión interactiva del usuario.
- **El daemon tras un reinicio del servidor**: Docker Desktop arranca con la sesión del usuario. Habilitar "Start Docker Desktop when you sign in" en Docker Desktop (Settings → General) para que el stack se levante al iniciar sesión.

### Tests

```bash
pytest
```

### Migraciones (Alembic)

Todavía no hay tablas de negocio; los comandos quedan preparados para cuando existan los modelos.

```bash
# Generar una migración a partir de los modelos
alembic revision --autogenerate -m "descripcion"

# Aplicar migraciones pendientes
alembic upgrade head

# Revertir última migración
alembic downgrade -1
```

La URL de la base de datos se toma de la configuración central (`app/core/config.py`), no se duplica en `alembic.ini`. Nota: las revisiones autogeneradas conviene generarlas desde la carpeta donde se edita el código o en el servidor tras sincronizar; el archivo de migración resultante se sincroniza como cualquier código.

## Módulo: usuarios, roles y permisos

Primer módulo funcional. Autenticación JWT local (sin proveedores externos, apto para LAN) y autorización basada en permisos.

### Endpoints

| Método | Ruta | Permiso requerido |
|---|---|---|
| POST | `/api/auth/login` | — (público) |
| POST | `/api/users` | gestión del rol objetivo (`users.mediators.manage` / `users.admins.manage`) |
| GET | `/api/users` | `users.view` |
| GET | `/api/users/{id}` | `users.view` |
| PATCH | `/api/users/{id}` | gestión del rol resultante |
| POST | `/api/users/{id}/activate` · `/deactivate` | gestión del rol del usuario |
| GET | `/api/roles` · `/api/permissions` | `users.view` |
| GET | `/api/roles/{name}/permissions` | `users.view` |
| PUT | `/api/roles/{name}/permissions` | `roles.permissions.manage` |

### Modelo de autorización

- Roles fijos de dominio: `ADMINISTRADOR` y `MEDIADOR` (sin CRUD de roles; se crean por seed idempotente al arrancar).
- ADMINISTRADOR recibe todos los permisos; MEDIADOR solo los `*.view` de dispositivos, experiencias, contenido y programaciones.
- Los permisos son un catálogo editable: un administrador puede reasignar los permisos de un rol vía `PUT /api/roles/{name}/permissions` (reemplazo completo; el seed nunca revierte cambios hechos por API).
- La autorización se expresa siempre como permisos (`require_permission("...")`), nunca como comparaciones de nombre de rol.
- Códigos de respuesta: `401` no autenticado, `403` sin permiso o cuenta desactivada, `409` email duplicado, `404` no existe.
- `password_hash` nunca se devuelve en ninguna respuesta.
- **Contraseñas = PIN numérico de 4 dígitos** (política de Cauce para acceso rápido en la sala). El formato se valida igual en login, creación y actualización; los ceros a la izquierda se respetan (`0042`).

### Primer acceso

El seed crea un administrador inicial solo cuando no existe ninguno, con las credenciales de `BOOTSTRAP_ADMIN_EMAIL` / `BOOTSTRAP_ADMIN_PASSWORD` del `.env` (PIN por defecto `0000`). **Cambia su PIN tras el primer inicio de sesión** (PATCH `/api/users/{id}` con tu propio usuario).

## Módulo: dispositivos y heartbeats

Los dispositivos cliente (pantallas, PCs, Android, Raspberry Pi, VR, o cualquier cliente que implemente el contrato) se registran, reportan heartbeat y el servidor determina su estado. El backend es completamente agnóstico del origen del heartbeat: un dispositivo real y un simulador que envíen el mismo payload producen el mismo comportamiento.

### Conceptos del modelo

| Campo | Significado |
|---|---|
| `device_uid` | Identidad estable y única del dispositivo. Se registra **tal como lo expone el dispositivo** (autoconfiguración): puede contener espacios y caracteres arbitrarios y nunca se normaliza (solo límite de 100 caracteres). La IP/puerto son información dinámica; nunca identidad. El heartbeat lo recibe en la ruta, URL-encoded (p. ej. `/api/devices/SALA%20PANTALLA%201/heartbeat`). |
| `status` | Conectividad, determinada **por el servidor**: `online` si hay heartbeat válido reciente; `offline` si pasan más de `DEVICE_OFFLINE_AFTER_SECONDS` (30 s) sin heartbeats. El cliente nunca lo reporta. |
| `device_state` | Estado operativo reportado por el cliente: `active` (en uso / pantalla encendida) / `idle` (en espera / pantalla apagada o suspendida). Generaliza dispositivos con y sin pantalla. **Independiente de `status`**: un dispositivo `idle` sigue enviando heartbeats y permanece `online`. |
| `current_media` | Medio que el dispositivo **reporta estar reproduciendo**: el `id` numérico de un medio de la biblioteca, como texto (ej. `"5"`), o `"unknown"` cuando el heartbeat no reporta un identificador válido. Se envía dentro de `payload.current_media` (opcional). Ausente, nulo o no identificador → `"unknown"`; nunca se conserva el valor previo ni se infiere de otros campos. El atributo retirado `current_application` (nombre de aplicación) **no** se interpreta como medio: los clientes antiguos pueden seguir enviándolo sin romper nada (pasa como dato inerte). |
| `payload` | Atributos dinámicos **específicos del dispositivo** (JSON): medio actual, puerto, batería, carga, etc. Opcional y extensible; los atributos conocidos se validan si están presentes (`current_media` id de medio, `port` 1-65535, `battery_level` 0-100, `is_charging` booleano, `power_source` texto) y los desconocidos se aceptan tal cual. Se fusiona por clave: un atributo ausente **nunca** se interpreta como `false`/`0`/`null` ni borra el valor previo (excepción: `current_media`, explícito en su fila). Las claves reservadas (campos generales, incluido el nombre retirado `display_state`, y datos controlados por el servidor) se rechazan con `422`. Los cambios de payload no generan eventos (métricas como la batería cambian en cada heartbeat). |
| `last_seen` | Marca de tiempo (UTC) del último heartbeat válido. Se actualiza con **cada** heartbeat, aunque nada cambie. |

### Endpoints

| Método | Ruta | Permiso |
|---|---|---|
| POST | `/api/devices` | `devices.manage` |
| POST | `/api/devices/autoconfig` | `devices.manage` |
| GET | `/api/devices/autoconfig/pending` | `devices.manage` |
| GET | `/api/devices` | `devices.view` |
| GET | `/api/devices/{device_uid}` | `devices.view` |
| DELETE | `/api/devices/{device_uid}` | `devices.manage` |
| GET | `/api/devices/{device_uid}/events` | `devices.view` |
| POST | `/api/devices/{device_uid}/heartbeat` | — (protocolo de dispositivos, sin usuario) |

Reglas: el registro deja el dispositivo `offline` (solo un heartbeat lo pone `online`); un heartbeat de un `device_uid` no registrado devuelve `404` y **no** crea el dispositivo (flujo: registro → heartbeat); la IP del payload es la dirección que el dispositivo declara (no se usa la IP de origen de la conexión); el puerto vive dentro de `payload` (no todos los dispositivos tienen uno y su ausencia no es error); `current_media` también vive dentro de `payload` (ver su fila). `DELETE /api/devices/{device_uid}` (204) elimina el dispositivo **y todo su historial de eventos** en cascada; es pura desregistro: tras el borrado, un heartbeat de ese uid se comporta como dispositivo desconocido (`404`, o nuevo descubrimiento si la autoconfiguración está activa) y nunca se recrea automáticamente.

### Autoconfiguración (descubrimiento de dispositivos)

La autoconfiguración permite descubrir dispositivos a partir de sus heartbeats. Nunca registra nada automáticamente: el registro definitivo lo hace un administrador con el endpoint existente `POST /api/devices`.

- `POST /api/devices/autoconfig` con `{"enabled": true|false}` activa o desactiva el modo. **Desactivado por defecto y tras cada reinicio del backend** (reset en el arranque). El estado vive en PostgreSQL (`autoconfig_state`), no en memoria: todos los workers/instancias ven el mismo modo. Al desactivar se limpia la lista de pendientes.
- Con el modo activado, un heartbeat de un `device_uid` no registrado se acepta con **`202 Accepted`** y `{"device_uid", "status": "pending_registration", "last_seen"}`: sus datos se conservan temporalmente (`device_uid`, `ip_address`, `device_state`, `payload`, `last_seen`) sin crear filas de inventario. Con el modo desactivado se mantiene el `404` actual. Los dispositivos registrados se procesan con normalidad independientemente del modo.
- `GET /api/devices/autoconfig/pending` devuelve los dispositivos detectados que enviaron heartbeat en los últimos `AUTOCONFIG_PENDING_TTL_SECONDS` (30 s, configurable). La caducidad depende solo de la ausencia de heartbeats. Formato (sin `payload`, sin duplicados, sin registrados):

```json
{"devices": [{"device_uid": "tablet-ar-01", "ip_address": "10.15.1.164", "device_state": "active", "last_seen": "2026-10-19T16:30:00Z"}]}
```

- Registro definitivo: el frontend selecciona un pendiente y envía el `device_uid` con la IP confirmada mediante el formulario del endpoint existente; el backend valida duplicados incluso bajo concurrencia (restricción única). Tras un registro exitoso el dispositivo desaparece de pendientes.

### Ejemplos

Registro:

```json
POST /api/devices
{"device_uid": "CAUCE-001", "name": "Pantalla 1", "type": "screen", "ip_address": "10.15.1.151", "port": 8001}
```

Heartbeat (campos generales + `payload` opcional con atributos del dispositivo; el cliente no puede reportar `status`):

```json
POST /api/devices/CAUCE-001/heartbeat
{
  "ip_address": "10.15.1.151",
  "device_state": "active",
  "payload": {
    "current_media": 5,
    "port": 8000,
    "battery_level": 78,
    "is_charging": false
  }
}
```

Respuesta:

```json
{"device_uid": "CAUCE-001", "status": "online", "device_state": "active", "current_media": "5", "payload": {"port": 8000, "battery_level": 78, "is_charging": false}, "last_seen": "2026-10-07T21:00:00Z"}
```

### Historial de eventos (`device_events`)

Solo se registran **cambios** (heartbeats idénticos no generan historial): `device_registered`, `status_changed`, `device_state_changed`, `media_changed`, `ip_changed`, `port_changed` — cada uno con `previous_value`/`new_value`. El `port_changed` y el `media_changed` se derivan de `payload.port` / `payload.current_media` cuando el dispositivo los reporta. La detección de offline la hace una tarea interna del servidor (barrido periódico, sin brokers externos): `online → offline` genera un único `status_changed`; barridos repetidos sin recuperación no generan eventos; al volver un heartbeat se registra `offline → online`.

Nota sobre validación por tipo: el modelo registra `type` como texto libre y todavía no existe una correspondencia tipo → esquema de payload, por lo que los atributos conocidos (`current_media`, `port`, `battery_level`, `is_charging`, `power_source`) se validan de forma universal. La modificación mínima futura para validar por tipo sería un registro `type → schema` aplicado en `DeviceService.heartbeat` tras obtener el dispositivo.

## Módulo: medios audiovisuales (RF-008, fase 1)

Creación y gestión de medios: imágenes y videos se cargan como archivo real (`multipart/form-data`) y se guardan en el disco del servidor; las URLs externas se registran con sus metadatos sin descargar nada. Los metadatos viven en PostgreSQL (`media`); los binarios en el directorio configurado. La asignación a dispositivos se describe en el módulo siguiente; reproducción y tiempo real quedan fuera.

### Conceptos

| Campo | Significado |
|---|---|
| `name` | Nombre visible. En cargas es el nombre original del archivo (o el indicado en el form); **nunca** se usa como ruta física. |
| `media_type` | `image` \| `video` \| `url`. |
| `mime_type` | Tipo MIME persistido. En cargas es el canónico de la extensión validada; opcional en URLs. |
| `file_size` | Bytes del archivo (solo cargas). |
| `storage_key` | Clave relativa y estable (`images/<uuid>.png`, `videos/<uuid>.mp4`); la ruta física se resuelve con la configuración vigente. Las URLs no tienen clave. |
| `external_url` | Dirección http/https registrada tal cual (solo `url`). El backend **nunca** la descarga ni la sigue. |

### Endpoints

| Método | Ruta | Permiso |
|---|---|---|
| POST | `/api/media` (multipart: `media_type`, `file`, `name?`) | `content.manage` |
| POST | `/api/media/urls` (JSON: `name`, `url`, `mime_type?`) | `content.manage` |
| GET | `/api/media?limit=&offset=` | `content.view` |
| GET | `/api/media/{id}` | `content.view` |
| GET | `/api/media/{id}/file` | `content.view` |
| DELETE | `/api/media/{id}` | `content.manage` |

La creación se divide en dos operaciones con contratos explícitos: `POST /api/media` solo acepta `multipart/form-data` para `image`/`video`; `POST /api/media/urls` acepta JSON para URLs externas. `GET /{id}/file` sirve el binario (`Content-Type` = MIME persistido, `inline`) con el nombre original en `Content-Disposition`; los medios `url` devuelven `404` en esa ruta.

### Validación e integridad

- Extensiones permitidas por tipo (image: png/jpg/jpeg/gif/webp; video: mp4/webm/ogg/mov/mkv). El MIME declarado debe corresponder a la extensión (se tolera `application/octet-stream`). Tamaños: `413` si supera `CAUCE_MEDIA_MAX_SIZE_MB` (200 por defecto).
- Nombres de almacenamiento únicos por UUID; el nombre original queda solo como metadato. Sin traversal: toda clave resuelta se verifica dentro del directorio raíz de medios.
- Escritura atómica (`.part` + rename): un fallo nunca deja archivos parciales. Si PostgreSQL falla tras guardar el archivo, el archivo se limpia; si la escritura falla, no se crea registro. Al eliminar, el archivo solo se borra después de verificar que pertenece a ese registro y una vez eliminado el registro.
- Las URLs aceptan únicamente esquemas `http`/`https`.

### Almacenamiento (configuración)

`CAUCE_MEDIA_DIR` define la raíz de los binarios. Absoluta se usa tal cual; relativa se resuelve contra la raíz del proyecto backend; **vacía usa el default estable `backend/data/media`**, calculado respecto al paquete `app`, no del directorio desde el que se invoque `uvicorn` (los archivos sobreviven reinicios y quedan fuera de directorios temporales, fáciles de inspeccionar en Windows). El directorio se crea al escribir.

- **Desarrollo local (Windows, venv + uvicorn)**: no configurar nada (default `backend\data\media`) o poner una ruta absoluta en `.env`.
- **Docker**: `CAUCE_MEDIA_DIR=/app/data/media` con el volumen `media_data:/app/data/media` ya declarado en `docker-compose.yml`; los binarios sobreviven a la recreación del contenedor mientras el volumen persista. No hay que hacer coincidir rutas de Windows dentro del contenedor.

### Ejemplos

```bash
# Subir una imagen
curl -X POST $API/api/media -H "Authorization: Bearer $TOKEN" \
  -F "media_type=image" -F "name=Portada" -F "file=@portada.png"

# Registrar una URL externa
curl -X POST $API/api/media/urls -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{"name":"Loop YouTube","url":"https://example.com/x"}'

# Listar con paginación, ver el archivo, eliminar
curl -H "Authorization: Bearer $TOKEN" "$API/api/media?limit=20&offset=0"
curl -H "Authorization: Bearer $TOKEN" -o portada.png "$API/api/media/1/file"
curl -X DELETE -H "Authorization: Bearer $TOKEN" "$API/api/media/1"
```

Persistencia tras reinicio: la prueba `test_file_survives_service_restart` verifica que una instancia nueva de configuración resuelve la misma ruta física para la misma clave; el procedimiento manual es subir un archivo, reiniciar uvicorn y volver a pedir `GET /api/media/{id}/file`.

## Módulo: asignación de medios a dispositivos (RF-008)

Distingue el medio que la **administración asigna** a un dispositivo del medio que el dispositivo **reporta estar reproduciendo** (`current_media`). Ambos se comparan con una única regla central (`assignment_service.compute_sync_status`): ids iguales → `synchronized`; distinto id, `"unknown"` o nunca reportado → `pending`. Sincronización no implica reproducción exitosa: el protocolo actual solo reporta el identificador del medio.

| Método | Ruta | Permiso |
|---|---|---|
| PUT | `/api/devices/{device_uid}/assignment` (JSON `{"media_id": int}`) | `content.manage` |
| GET | `/api/assignments` | `content.view` |

Reglas:

- La asignación valida que el dispositivo y el medio existen (`404` en otro caso). El cliente identifica el medio por su **id numérico** (`payload.current_media` en el heartbeat): nunca se comparan nombres de archivo con ids.
- Máximo **una asignación vigente por dispositivo** (`device_id` único): asignar otro medio **actualiza** la fila existente, no crea asignaciones activas concurrentes.
- El estado se recalcula al asignar y en **cada heartbeat** (misma transacción que la actualización de `current_media`): en cuanto el dispositivo reporta el id asignado pasa a `synchronized`; si reporta otro id o `"unknown"`, vuelve a `pending`.
- Un dispositivo sin asignación vigente late con normalidad.
- Respuesta de `GET /api/assignments`: una fila por dispositivo asignado con `{id, device_id, device_uid, media_id, media_name, sync_status, revision, created_at, updated_at}` (una única consulta con joins, sin N+1).
- Fuera de esta fase: programación horaria, listas de reproducción, envío de órdenes por WebSocket y reproducción.

## Seguridad: clave compartida de dispositivos

Los endpoints del **protocolo de dispositivos** (sin usuario) se protegen con un secreto compartido entre el servidor y todos los clientes Cauce Stream: `CAUCE_DEVICE_SECRET` (variable de entorno; el mismo valor en el servidor y en el `.env` de cada cliente). El cliente lo envía en el header **`X-Device-Key`**.

Endpoints protegidos:

| Endpoint | Comportamiento con clave válida |
|---|---|
| `POST /api/devices/{uid}/heartbeat` | `200`/`202`; sin clave o clave errónea → `401 {"code": "device_key_invalid"}` |
| `WS /api/devices/{uid}/ws` | handshake aceptado; sin clave/errónea → cierre `1008` "Invalid device key" |
| `GET /api/media/{id}/file` | descarga del medio (así el cliente obtiene los archivos asignados sin usuario) |

Reglas:

- **Doble vía en la descarga de medios**: `X-Device-Key` válido **o** token de usuario con `content.view`. El resto de endpoints de administración (listar, subir, asignar, usuarios, etc.) ignoran la clave de dispositivo y siguen exigiendo permisos de usuario: la clave nunca eleva privilegios administrativos.
- **Modo transición**: si `CAUCE_DEVICE_SECRET` está vacía, la autenticación de dispositivos queda deshabilitada (todo funciona como hoy) y el arranque registra un warning. Al definirla, cada cliente debe enviar el mismo valor o será rechazado (`401`/cierre `1008`).
- La comparación es de tiempo constante y la clave jamás se registra en logs.
- Rotación: cambiar el valor en el servidor y en todos los clientes a la vez (clave compartida, no por dispositivo; la identidad por dispositivo llegará en una fase posterior si se necesita).

En el cliente (Flutter, `client/.env`): `CAUCE_DEVICE_SECRET=<mismo valor>`; el servicio de heartbeat lo envía automáticamente en `X-Device-Key`.

## Módulo: notificaciones de reproducción por WebSocket

Canal de control servidor → dispositivo para entregar la asignación vigente. **No sustituye al heartbeat**: la conectividad (`online`/`offline`) y el medio reproducido (`current_media`) siguen determinándose exclusivamente por heartbeats. Conexión (desde la LAN): `ws://<IP_SERVIDOR>:8000/api/devices/<device_uid>/ws` — sin credenciales de usuario (protocolo de dispositivos, igual que el heartbeat; la autenticación de dispositivos llegará con la fase de seguridad). Solo dispositivos registrados: si el uid no existe, el handshake se rechaza (`close 1008`, "Device not registered").

### Flujo

```
admin: PUT /api/devices/{uid}/assignment ──► commit PostgreSQL ──► playback.command (si conectado)
dispositivo: WS connect ──► playback.sync (asignación vigente persistida, o assignment: null)
```

1. Al conectar, el servidor envía `playback.sync` con el estado **persistido** en ese momento: la asignación vigente o `assignment: null` (sin asignación, mensaje inequívoco). Independiente de los mensajes perdidos: todo se reconstruye desde PostgreSQL al reconectarse (también tras reiniciar el backend).
2. Al asignar, el backend **persiste primero** (commit) y notifica después con `playback.command`. Si el dispositivo está desconectado, la asignación queda guardada y se entrega en la próxima conexión vía `playback.sync`.
3. `revision` es **monótona por dispositivo** (persistida en la asignación): 1 en la primera asignación, +1 en cada cambio. Regla del cliente: aplicar solo órdenes con `revision` mayor que la última aplicada; una orden antigua jamás sustituye el estado más reciente (el servidor tampoco encola órdenes: siempre envía el último estado confirmado).
4. Enviar el mensaje **no marca nada como reproducido**: `sync_status` solo cambia por la comparación central (heartbeat con `current_media`).

### Mensajes del servidor (protocolo versión 1)

`playback.sync` (al conectar; sin asignación):

```json
{"type": "playback.sync", "protocol": 1, "device_uid": "SALA 1", "assignment": null, "sent_at": "2026-10-19T18:00:00Z"}
```

`playback.sync` / `playback.command` con asignación (el comando se envía en cada cambio confirmado):

```json
{
  "type": "playback.command",
  "protocol": 1,
  "device_uid": "SALA 1",
  "assignment": {
    "assignment_id": 3,
    "media_id": 5,
    "revision": 2,
    "sync_status": "pending",
    "media": {
      "name": "portada.png",
      "media_type": "image",
      "mime_type": "image/png",
      "file_size": 20480,
      "file_url": "/api/media/5/file",
      "external_url": null
    }
  },
  "sent_at": "2026-10-19T18:00:00Z"
}
```

- `media_type` distingue `image` / `video` / `url`.
- `file_url` es el **endpoint de descarga existente** (`/api/media/{id}/file`, relativo) solo para `image`/`video`; para `url` se entrega `external_url` y `file_url: null`. No se inventan URLs. Nota de autenticación: ese endpoint hoy exige permiso `content.view` (token de usuario); hasta la fase de seguridad de dispositivos, un cliente-dispositivo no puede descargar con ese endpoint sin credenciales.
- `sync_status` es el estado persistido en ese instante (`synchronized` | `pending`).

### Mensajes del cliente (opcional, solo confirmaciones)

```json
{"type": "playback.ack", "assignment_id": 3, "revision": 2}
{"type": "playback.error", "assignment_id": 3, "revision": 2, "error": {"code": "download_failed", "message": "..."}}   // code ≤ 50, message ≤ 500
```

- Se validan contra la **última orden de ese mismo dispositivo** (`assignment_id` + `revision`): confirmaciones obsoletas o de otra asignación se ignoran (un cliente no puede referenciar asignaciones ajenas; la conexión está ligada al uid de su ruta).
- **Efecto exacto: ninguno sobre el estado.** Se registran en el log; jamás modifican `current_media` ni `sync_status`.
- Mensajes malformados/desconocidos se ignoran sin cerrar la conexión. Tamaño máximo entrante: 8 KB; sobrepasarlo cierra con `1009`.

### Gestión de conexiones y robustez

- Una conexión por dispositivo (identificada por `device_uid`). Conexión duplicada: **gana la más nueva**; la anterior se cierra con `4000` ("Replaced by a newer connection").
- El gestor vive **en memoria del proceso** (sin Redis/brokers para el MVP): las notificaciones en tiempo real requieren ejecutar el backend en **un único proceso/worker de uvicorn**; las conexiones no se comparten entre workers. PostgreSQL permite reconstruir el estado tras cualquier reinicio (`playback.sync`).
- Envíos aislados por cliente: un fallo de envío o desconexión abrupta limpia esa conexión y nunca interrumpe las solicitudes HTTP ni los heartbeats. El bucle de recepción nunca bloquea el event loop.
- Códigos de cierre: `1008` (dispositivo no registrado), `1009` (mensaje excesivo), `4000` (reemplazado), `1000` (desconexión normal).

### Probarlo

```bash
# con el backend corriendo (uvicorn, 1 worker):
wscat -c ws://<IP_SERVIDOR>:8000/api/devices/SALA%201/ws
# 1) recibe playback.sync de inmediato
# 2) en otra terminal, asignar un medio (token de admin):
curl -X PUT $API/api/devices/SALA%201/assignment -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{"media_id": 5}'
# 3) wscat recibe playback.command
# 4) confirmar recepción:  {"type":"playback.ack","assignment_id":3,"revision":2}
```

(El uid va URL-encoded en la ruta, igual que en el heartbeat.)

## Próximas etapas

Sobre este esqueleto se añadirán: dispositivos cliente, estado/disponibilidad, heartbeats, configuración de dispositivos, experiencias de la Sala Cauce, distribución y reproducción de contenido, programaciones y comunicación servidor-dispositivos.
