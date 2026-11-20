# Clínica Dental Demo — web con base de datos (datos ficticios)

Sitio de un consultorio dental inventado, publicado con **GitHub Pages** y con base de datos en **Supabase** (Postgres).
Cada `git push` a `main` actualiza la web: https://digidacticaabdiel5-hub.github.io/demo-dental/

## Qué guarda la base

```
pacientes 1──N citas N──1 dentistas
                 │
                 N──1 servicios
                 │
                 1──0..1 resenas
```

| Tabla | Para qué sirve |
|---|---|
| `pacientes` | nombre y teléfono (único): si alguien vuelve, se reconoce |
| `dentistas` | el equipo y el "Con quién" al reservar |
| `servicios` | lista, duración y precio; se edita desde el panel |
| `citas` | paciente + dentista + servicio + fecha y hora + estado |
| `resenas` | 1–5 estrellas y comentario; solo de citas atendidas |
| `ajustes`, `horario` | horas que se ofrecen y turnos de cada día |
| `administradores` | qué usuarios de Supabase pueden entrar al panel |
| `intentos` | límite anti-abuso (la IP se guarda como resumen, nunca tal cual) |

Todo está en [`supabase/esquema.sql`](supabase/esquema.sql): tablas, índices, vistas, funciones, un *trigger* y las reglas de seguridad.

## Cómo está protegida
La web usa la **llave pública** de Supabase. Es pública a propósito: lo que protege los datos son las reglas **RLS** (seguridad por fila).
- El público **no puede leer** pacientes, citas ni reseñas sin publicar. Solo llama a funciones que validan todo dentro de la base: `disponibilidad()`, `apartar_cita()`, `sitio_publico()`, `ver_resena()` y `dejar_resena()`.
- Un índice único impide dos citas del mismo dentista a la misma hora, aunque lleguen al mismo tiempo.
- Al marcar una cita "atendida", un *trigger* crea su enlace único de reseña. Sin ese enlace no se puede opinar, y solo se puede una vez.
- El panel exige iniciar sesión **y** estar en la tabla `administradores`. Un usuario cualquiera con sesión ve 0 filas.

## Puesta en marcha (una sola vez)
1. **Crear la base:** en Supabase → **SQL Editor** → pega todo `supabase/esquema.sql` → **Run**.
2. **Conectar la web:** en **Project Settings → API** copia la *Project URL* y la *anon / publishable key* y pégalas en `config.js` (`supabase.url` y `supabase.anonKey`). **Nunca** la `service_role`.
3. **Crear la cuenta del panel:** en **Authentication → Users → Add user**, con tu correo y una contraseña, marcando *Auto Confirm User*. Luego en el SQL Editor:
   ```sql
   insert into administradores (user_id)
   select id from auth.users where email = 'TU_CORREO';
   ```
4. **Cerrar registros:** en **Authentication → Sign In / Providers**, desactiva *Allow new users to sign up*, para que nadie más cree cuentas.
5. **Publicar:** `git add .`, `git commit` y `git push`. GitHub Pages se actualiza en uno o dos minutos.

## Páginas
- `index.html`: la web, con reserva que elige dentista y la sección de reseñas al final.
- `admin.html`: el panel. Tiene citas, historial, reseñas (publicar u ocultar), servicios (editar y agregar) y **estadísticas** con el SQL de cada vista.
- `resena.html?t=…`: donde el paciente deja su reseña. El enlace lo manda el panel por WhatsApp.

Si `config.js` no tiene los datos de Supabase o la base no responde, la web sigue funcionando como antes: las citas abren WhatsApp.

## Notas
- Lleva `noindex`: Google no debería listarlo.
- Todos los datos son ficticios. No se guardan datos de salud.
- El aviso de privacidad es solo de ejemplo.
