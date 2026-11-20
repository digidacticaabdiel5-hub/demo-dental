-- ============================================================
--  Clínica Dental Demo · Base de datos en Supabase (Postgres)
--  Pega TODO este archivo en Supabase → SQL Editor → Run.
--  Se puede correr varias veces: crea lo que falta y actualiza las funciones.
--
--    pacientes 1──N citas N──1 dentistas
--                     │
--                     N──1 servicios
--                     │
--                     1──0..1 resenas
--
--  Además: ajustes y horario (cuándo se atiende), administradores (quién entra
--  al panel) e intentos (límite anti-abuso). Todo con seguridad por fila (RLS):
--  el navegador NO puede leer pacientes ni citas; solo llama a funciones que
--  validan todo aquí adentro.
-- ============================================================

-- ---------- Tablas ----------
create table if not exists ajustes (
  id                   boolean primary key default true check (id),   -- una sola fila
  nombre_negocio       text not null,
  zona_horaria         text not null default 'America/Mexico_City',
  horas                text[] not null,                                -- horas que se ofrecen: {'10:00','11:30',...}
  dias_adelante        int  not null default 5  check (dias_adelante between 1 and 30),
  minutos_anticipacion int  not null default 60 check (minutos_anticipacion between 0 and 1440)
);

create table if not exists horario (
  dia    smallint not null check (dia between 0 and 6),                 -- 0 = domingo … 6 = sábado
  abre   time not null,
  cierra time not null check (cierra > abre),
  primary key (dia, abre)                                               -- un día puede tener dos turnos
);

create table if not exists dentistas (
  id           serial primary key,
  nombre       text not null,
  especialidad text not null default '',
  bio          text not null default '',
  iniciales    text not null default '',
  color_de     text not null default '#2cc2bd',
  color_a      text not null default '#0c6c69',
  activo       boolean not null default true,
  orden        int not null default 0
);

create table if not exists servicios (
  id           serial primary key,
  nombre       text not null unique,
  descripcion  text not null default '',
  duracion_min int  not null default 30 check (duracion_min between 10 and 480),
  precio_desde numeric(10,2) check (precio_desde is null or precio_desde >= 0),   -- null = "Valoración"
  activo       boolean not null default true,
  orden        int not null default 0
);

create table if not exists pacientes (
  id       serial primary key,
  nombre   text not null check (length(nombre) between 3 and 80),
  telefono text not null unique check (telefono ~ '^[0-9]{10}$'),
  creado   timestamptz not null default now()
);

create table if not exists citas (
  id           serial primary key,
  paciente_id  int  not null references pacientes(id),
  dentista_id  int  not null references dentistas(id),
  servicio_id  int  not null references servicios(id),
  fecha        date not null,
  hora         time not null,
  estado       text not null default 'pendiente'
               check (estado in ('pendiente','confirmada','cancelada','atendida','no_asistio')),
  resena_token text unique,               -- nace al marcarla "atendida": es el enlace para opinar
  creada       timestamptz not null default now(),
  actualizada  timestamptz
);
-- Un dentista no puede tener dos citas vivas a la misma hora. Lo garantiza la base.
create unique index if not exists una_cita_por_dentista_y_hora
  on citas (dentista_id, fecha, hora) where estado in ('pendiente','confirmada');
create index if not exists citas_por_fecha on citas (fecha, hora);
create index if not exists citas_por_paciente on citas (paciente_id);

create table if not exists resenas (
  id           serial primary key,
  cita_id      int not null unique references citas(id),     -- una reseña por cita, y solo de citas reales
  calificacion smallint not null check (calificacion between 1 and 5),
  comentario   text not null default '' check (length(comentario) <= 600),
  estado       text not null default 'pendiente' check (estado in ('pendiente','aprobada','oculta')),
  creada       timestamptz not null default now()
);

create table if not exists administradores (
  user_id uuid primary key references auth.users(id) on delete cascade,
  creado  timestamptz not null default now()
);

create table if not exists intentos (
  clave text not null,
  ts    timestamptz not null default now()
);
create index if not exists intentos_por_clave on intentos (clave, ts);

-- ---------- Datos iniciales (solo si están vacías) ----------
insert into ajustes (nombre_negocio, horas, dias_adelante, minutos_anticipacion)
select 'Clínica Dental Demo', array['10:00','11:30','13:00','16:00','17:30','19:00'], 5, 60
where not exists (select 1 from ajustes);

insert into horario (dia, abre, cierra)
select * from (values
  (2,'10:00'::time,'14:00'::time),(2,'16:00','20:00'),
  (3,'10:00','14:00'),(3,'16:00','20:00'),
  (4,'10:00','14:00'),(4,'16:00','20:00'),
  (5,'10:00','14:00'),(5,'16:00','20:00'),
  (6,'10:00','14:00'),(6,'16:00','20:00'),
  (0,'10:00','14:00')) as v(dia, abre, cierra)          -- lunes (1) cerrado
where not exists (select 1 from horario);

insert into dentistas (nombre, especialidad, bio, iniciales, color_de, color_a, orden)
select * from (values
  ('Dr. Ejemplo',  'Odontólogo', 'Te explica el procedimiento, aclara tus dudas y te da seguimiento.', 'E', '#2cc2bd', '#0c6c69', 0),
  ('Dra. Muestra', 'Odontóloga', 'Atención cercana, con recomendaciones claras para cuidar tus tratamientos.', 'M', '#6aa9e8', '#2f5f9e', 1)
) as v(nombre, especialidad, bio, iniciales, color_de, color_a, orden)
where not exists (select 1 from dentistas);

insert into servicios (nombre, descripcion, duracion_min, orden)
select * from (values
  ('Revisión general',      'Revisión completa de dientes, encías y mordida, con el plan explicado.', 30, 0),
  ('Limpieza dental',       'Elimina el sarro y revisa el estado de tus encías.',                       45, 1),
  ('Blanqueamiento dental', 'Aclara el color de tus dientes de forma segura.',                          60, 2),
  ('Carillas y coronas',    'Mejora la forma, el color y la resistencia de tu sonrisa.',                60, 3),
  ('Implantes dentales',    'Reemplaza piezas faltantes con una solución duradera.',                    90, 4),
  ('Endodoncia',            'Tratamiento de conductos para salvar tu diente.',                          90, 5)
) as v(nombre, descripcion, duracion_min, orden)
where not exists (select 1 from servicios);

-- ---------- Utilidades ----------
create or replace function hoy_mx() returns date
language sql stable set search_path = public as $$
  select (now() at time zone (select zona_horaria from ajustes limit 1))::date
$$;

create or replace function es_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from administradores where user_id = auth.uid())
$$;

create or replace function _error(mensaje text, campo text, estado int) returns jsonb
language sql immutable as $$
  select jsonb_build_object('ok', false, 'error', mensaje, 'campo', campo, 'status', estado)
$$;

-- Cuenta intentos por IP (guardada como resumen md5, nunca tal cual). true = ya se pasó del límite.
create or replace function _demasiados(tipo text, maximo int, minutos int) returns boolean
language plpgsql volatile security definer set search_path = public as $$
declare
  hdr  json := nullif(current_setting('request.headers', true), '')::json;
  ip   text := btrim(split_part(coalesce(hdr->>'x-forwarded-for', hdr->>'x-real-ip', '?'), ',', 1));
  llave text := tipo || ':' || md5(ip || tipo);
begin
  if (select count(*) from intentos where clave = llave and ts > now() - make_interval(mins => minutos)) >= maximo then
    return true;
  end if;
  insert into intentos (clave) values (llave);
  if random() < 0.05 then delete from intentos where ts < now() - interval '1 day'; end if;
  return false;
end $$;

-- ---------- Disponibilidad ----------
-- Fechas y horas que se ofrecen según ajustes + horario (sin mirar todavía las citas).
create or replace function horas_ofrecidas()
returns table (fecha date, hora time)
language sql stable security definer set search_path = public as $$
  with a as (select * from ajustes limit 1),
  ahora as (select now() at time zone (select zona_horaria from a) as ts),
  todas as (
    select (ahora.ts::date + i) as f, h::time as t
      from ahora, a, generate_series(0, 20) as i, unnest(a.horas) as h
     where exists (select 1 from horario hr
                    where hr.dia = extract(dow from ahora.ts::date + i)
                      and h::time >= hr.abre
                      and h::time <= hr.cierra - interval '30 minutes')
       and (ahora.ts::date + i) + h::time >= ahora.ts + make_interval(mins => a.minutos_anticipacion)
  ),
  dias as (select distinct f from todas order by f limit (select dias_adelante from a))
  select todas.f, todas.t from todas join dias on dias.f = todas.f order by 1, 2
$$;

-- Lo que pide la web: días, horas y qué dentistas siguen libres en cada hora.
create or replace function disponibilidad() returns jsonb
language sql stable security definer set search_path = public as $$
  with h as (select * from horas_ofrecidas()),
  doc as (select id, nombre, orden from dentistas where activo),
  hoy as (select hoy_mx() as d),
  libres as (
    select h.fecha, h.hora,
           coalesce((select jsonb_agg(doc.id order by doc.orden, doc.id) from doc
                      where not exists (select 1 from citas c
                                         where c.dentista_id = doc.id and c.fecha = h.fecha and c.hora = h.hora
                                           and c.estado in ('pendiente','confirmada'))), '[]'::jsonb) as libres
      from h
  ),
  por_dia as (
    select fecha, jsonb_agg(jsonb_build_object('t', to_char(hora, 'HH24:MI'), 'libres', libres) order by hora) as horas
      from libres group by fecha
  )
  select jsonb_build_object(
    'dentistas', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'nombre', nombre) order by orden, id) from doc), '[]'::jsonb),
    'dias', coalesce((select jsonb_agg(jsonb_build_object(
        'fecha', to_char(p.fecha, 'YYYY-MM-DD'),
        'etiqueta', case p.fecha - hoy.d when 0 then 'Hoy' when 1 then 'Mañana'
                    else (array['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'])[extract(dow from p.fecha)::int + 1]
                         || ' ' || extract(day from p.fecha)::int end,
        'horas', p.horas) order by p.fecha) from por_dia p, hoy), '[]'::jsonb))
$$;

-- ---------- Apartar cita (lo único que la web puede escribir en citas) ----------
create or replace function apartar_cita(
  p_servicio text, p_dentista int, p_fecha date, p_hora text,
  p_nombre text, p_telefono text, p_trampa text default '')
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_nombre text := left(regexp_replace(btrim(coalesce(p_nombre, '')), '\s+', ' ', 'g'), 80);
  v_tel    text := regexp_replace(coalesce(p_telefono, ''), '\D', '', 'g');
  v_hora   time;
  v_serv   servicios;
  v_doc    dentistas;
  v_pac    int;
  v_id     int;
begin
  if coalesce(p_trampa, '') <> '' then return jsonb_build_object('ok', true); end if;   -- campo trampa: un bot
  if _demasiados('cita', 6, 15) then return _error('Demasiadas solicitudes. Intenta en unos minutos.', null, 429); end if;
  if length(v_nombre) < 3 then return _error('Escribe tu nombre.', 'nombre', 400); end if;
  if length(v_tel) <> 10 then return _error('El teléfono debe tener 10 dígitos.', 'telefono', 400); end if;
  select * into v_serv from servicios where nombre = p_servicio and activo;
  if not found then return _error('Elige un motivo de la lista.', 'servicio', 400); end if;
  if coalesce(p_hora, '') !~ '^\d{2}:\d{2}$' then return _error('Elige una hora.', 'hora', 400); end if;
  v_hora := p_hora::time;
  if not exists (select 1 from horas_ofrecidas() h where h.fecha = p_fecha and h.hora = v_hora) then
    return _error('Ese horario ya no está disponible. Elige otro.', 'hora', 400);
  end if;
  if p_dentista is not null and not exists (select 1 from dentistas where id = p_dentista and activo) then
    return _error('Elige un dentista de la lista.', 'dentista', 400);
  end if;

  -- Dentista libre a esa hora. Sin preferencia: el que tenga menos citas ese día.
  select d.* into v_doc from dentistas d
   where d.activo and (p_dentista is null or d.id = p_dentista)
     and not exists (select 1 from citas c where c.dentista_id = d.id and c.fecha = p_fecha and c.hora = v_hora
                       and c.estado in ('pendiente','confirmada'))
   order by (select count(*) from citas c where c.dentista_id = d.id and c.fecha = p_fecha and c.estado in ('pendiente','confirmada')),
            d.orden, d.id
   limit 1;
  if not found then return _error('Alguien acaba de apartar esa hora. Elige otra.', 'hora', 409); end if;

  if (select count(*) from citas c join pacientes p on p.id = c.paciente_id
       where p.telefono = v_tel and c.fecha >= hoy_mx() and c.estado in ('pendiente','confirmada')) >= 3 then
    return _error('Ese teléfono ya tiene varias citas apartadas. Escríbenos por WhatsApp.', null, 409);
  end if;

  -- Paciente: si ya existe ese teléfono se reutiliza; si no, se crea.
  insert into pacientes (nombre, telefono) values (v_nombre, v_tel)
  on conflict (telefono) do update set nombre = excluded.nombre
  returning id into v_pac;

  begin
    insert into citas (paciente_id, dentista_id, servicio_id, fecha, hora)
    values (v_pac, v_doc.id, v_serv.id, p_fecha, v_hora)
    returning id into v_id;
  exception when unique_violation then
    return _error('Alguien acaba de apartar esa hora. Elige otra.', 'hora', 409);
  end;

  return jsonb_build_object('ok', true, 'cita', jsonb_build_object(
    'id', v_id, 'fecha', to_char(p_fecha, 'YYYY-MM-DD'), 'hora', p_hora,
    'servicio', v_serv.nombre, 'dentista', v_doc.nombre));
end $$;

-- ---------- Reseñas ----------
-- Al marcar una cita "atendida" nace su enlace único para reseñar.
create or replace function _cita_actualizada() returns trigger
language plpgsql as $$
begin
  if new.estado = 'atendida' and new.resena_token is null then
    new.resena_token := replace(gen_random_uuid()::text, '-', '');
  end if;
  if new.estado is distinct from old.estado then new.actualizada := now(); end if;
  return new;
end $$;
drop trigger if exists cita_actualizada on citas;
create trigger cita_actualizada before update on citas for each row execute function _cita_actualizada();

create or replace function ver_resena(p_token text) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select jsonb_build_object('ok', true, 'nombre', split_part(p.nombre, ' ', 1), 'servicio', s.nombre,
                               'dentista', d.nombre, 'fecha', to_char(c.fecha, 'YYYY-MM-DD'),
                               'ya', exists (select 1 from resenas r where r.cita_id = c.id))
       from citas c join pacientes p on p.id = c.paciente_id
       join servicios s on s.id = c.servicio_id join dentistas d on d.id = c.dentista_id
      where c.resena_token = p_token and c.estado = 'atendida'),
    _error('Este enlace no es válido.', null, 404))
$$;

create or replace function dejar_resena(p_token text, p_calificacion int, p_comentario text default '')
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_cita int;
begin
  if _demasiados('resena', 10, 15) then return _error('Demasiados intentos. Espera unos minutos.', null, 429); end if;
  if p_calificacion is null or p_calificacion not between 1 and 5 then return _error('Elige de 1 a 5 estrellas.', null, 400); end if;
  select id into v_cita from citas where resena_token = p_token and estado = 'atendida';
  if not found then return _error('Este enlace no es válido.', null, 404); end if;
  begin
    insert into resenas (cita_id, calificacion, comentario)
    values (v_cita, p_calificacion, left(btrim(regexp_replace(coalesce(p_comentario, ''), '\s+', ' ', 'g')), 600));
  exception when unique_violation then
    return _error('Ya dejaste tu reseña de esta cita. ¡Gracias!', null, 409);
  end;
  return jsonb_build_object('ok', true);
end $$;

-- ---------- Lo que muestra la web: servicios, equipo y reseñas publicadas ----------
create or replace function sitio_publico() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'services', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'name', nombre, 'desc', descripcion, 'duration', duracion_min || ' min',
        'price', case when precio_desde is null then 'Valoración'
                      else 'Desde $' || to_char(precio_desde, 'FM999,999,990') end) order by orden, id)
      from servicios where activo), '[]'::jsonb),
    'team', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'name', nombre, 'role', especialidad, 'bio', bio, 'initials', iniciales, 'from', color_de, 'to', color_a) order by orden, id)
      from dentistas where activo), '[]'::jsonb),
    'reviews', (select jsonb_build_object(
        'total', count(*),
        'promedio', round(avg(calificacion), 1),
        'items', coalesce((select jsonb_agg(x order by x->>'creada' desc) from (
            select jsonb_build_object(
              'nombre', split_part(p.nombre, ' ', 1) ||
                        case when split_part(p.nombre, ' ', 2) <> '' then ' ' || upper(left(split_part(p.nombre, ' ', 2), 1)) || '.' else '' end,
              'calificacion', r.calificacion, 'comentario', r.comentario, 'servicio', s.nombre, 'dentista', d.nombre,
              'mes', (array['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'])
                       [extract(month from r.creada at time zone 'America/Mexico_City')::int]
                     || ' ' || extract(year from r.creada at time zone 'America/Mexico_City')::int,
              'creada', r.creada) as x
              from resenas r join citas c on c.id = r.cita_id join pacientes p on p.id = c.paciente_id
              join servicios s on s.id = c.servicio_id join dentistas d on d.id = c.dentista_id
             where r.estado = 'aprobada' order by r.creada desc limit 12) t), '[]'::jsonb))
      from resenas where estado = 'aprobada'))
$$;

-- ---------- Vistas para el panel (respetan RLS: solo administradores ven filas) ----------
drop view if exists v_citas cascade;
create view v_citas with (security_invoker = true) as
  select c.id, to_char(c.fecha, 'YYYY-MM-DD') as fecha, to_char(c.hora, 'HH24:MI') as hora,
         c.estado, c.creada, c.resena_token,
         p.id as paciente_id, p.nombre, p.telefono,
         d.id as dentista_id, d.nombre as dentista,
         s.id as servicio_id, s.nombre as servicio,
         r.calificacion, r.estado as resena_estado
    from citas c
    join pacientes p on p.id = c.paciente_id
    join dentistas d on d.id = c.dentista_id
    join servicios s on s.id = c.servicio_id
    left join resenas r on r.cita_id = c.id;

drop view if exists v_resenas cascade;
create view v_resenas with (security_invoker = true) as
  select r.id, r.calificacion, r.comentario, r.estado, r.creada,
         v.nombre, v.servicio, v.dentista, v.fecha
    from resenas r join v_citas v on v.id = r.cita_id;

drop view if exists v_servicios cascade;
create view v_servicios with (security_invoker = true) as
  select s.*, (select count(*)::int from citas c where c.servicio_id = s.id) as citas
    from servicios s;

-- ---------- Estadísticas (cada una es una vista; el panel muestra su SQL) ----------
drop view if exists est_servicios cascade;
create view est_servicios with (security_invoker = true) as
  select s.nombre as etiqueta, count(c.id)::int as valor
    from servicios s
    left join citas c on c.servicio_id = s.id and c.estado <> 'cancelada' and c.fecha >= hoy_mx() - 30
   group by s.id, s.nombre
   order by valor desc, s.nombre;

drop view if exists est_faltas cascade;
create view est_faltas with (security_invoker = true) as
  select extract(isodow from fecha)::int as dia,
         round(100.0 * count(*) filter (where estado = 'no_asistio') / count(*))::int as valor,
         count(*)::int as total
    from citas
   where estado in ('atendida', 'no_asistio')
   group by 1
   order by 1;

drop view if exists est_horas cascade;
create view est_horas with (security_invoker = true) as
  select to_char(hora, 'HH24:MI') as etiqueta, count(*)::int as valor
    from citas
   where estado <> 'cancelada'
   group by hora
   order by hora;

drop view if exists est_regresan cascade;
create view est_regresan with (security_invoker = true) as
  select case when n = 1 then 'Una sola cita' else 'Regresaron' end as etiqueta, count(*)::int as valor
    from (select paciente_id, count(*) as n from citas where estado <> 'cancelada' group by paciente_id) t
   group by 1
   order by 1 desc;

drop view if exists est_dentistas cascade;
create view est_dentistas with (security_invoker = true) as
  select d.nombre as etiqueta, count(c.id)::int as valor
    from dentistas d
    left join citas c on c.dentista_id = d.id and c.estado = 'atendida'
   group by d.id, d.nombre
   order by valor desc, d.nombre;

drop view if exists est_calificacion cascade;
create view est_calificacion with (security_invoker = true) as
  select d.nombre as etiqueta, round(avg(r.calificacion), 1)::float8 as valor, count(r.id)::int as total
    from dentistas d
    left join citas c on c.dentista_id = d.id
    left join resenas r on r.cita_id = c.id and r.estado <> 'oculta'
   group by d.id, d.nombre
   order by valor desc nulls last, d.nombre;

create or replace function estadisticas() returns jsonb
language plpgsql stable security invoker set search_path = public as $$
declare v record; salida jsonb := '[]'::jsonb; filas jsonb;
begin
  if not es_admin() then raise exception 'Solo administradores' using errcode = '42501'; end if;
  for v in select * from (values
      (1, 'est_servicios',    'Servicios más pedidos',               'Citas de los últimos 30 días y las que vienen, sin contar canceladas.', 'citas'),
      (2, 'est_faltas',       'Pacientes que no llegan, por día',    'De las citas ya pasadas: qué porcentaje se marcó "No asistió".',        '%'),
      (3, 'est_horas',        'Horas más populares',                 'Todas las citas sin contar canceladas.',                                 'citas'),
      (4, 'est_regresan',     'Pacientes nuevos y los que regresan', 'Cuántos pacientes tienen una sola cita y cuántos ya volvieron.',         'pacientes'),
      (5, 'est_dentistas',    'Citas atendidas por dentista',        'Solo las marcadas como "Atendida".',                                     'citas'),
      (6, 'est_calificacion', 'Calificación promedio por dentista',  'Promedio de estrellas de las reseñas que no se ocultaron.',              '★')
    ) as x(orden, vista, titulo, nota, unidad) order by orden
  loop
    execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from %I) t', v.vista) into filas;
    salida := salida || jsonb_build_object('id', v.vista, 'titulo', v.titulo, 'nota', v.nota, 'unidad', v.unidad,
      'sql', 'create view ' || v.vista || ' as' || chr(10) || pg_get_viewdef(v.vista::regclass, true), 'filas', filas);
  end loop;
  return salida;
end $$;

-- ---------- Seguridad por fila (RLS) ----------
alter table ajustes         enable row level security;
alter table horario         enable row level security;
alter table dentistas       enable row level security;
alter table servicios       enable row level security;
alter table pacientes       enable row level security;
alter table citas           enable row level security;
alter table resenas         enable row level security;
alter table administradores enable row level security;
alter table intentos        enable row level security;   -- sin políticas: nadie la toca desde fuera

drop policy if exists "leer ajustes" on ajustes;
create policy "leer ajustes" on ajustes for select to anon, authenticated using (true);
drop policy if exists "admin ajustes" on ajustes;
create policy "admin ajustes" on ajustes for all to authenticated using (es_admin()) with check (es_admin());

drop policy if exists "leer horario" on horario;
create policy "leer horario" on horario for select to anon, authenticated using (true);
drop policy if exists "admin horario" on horario;
create policy "admin horario" on horario for all to authenticated using (es_admin()) with check (es_admin());

drop policy if exists "leer dentistas activos" on dentistas;
create policy "leer dentistas activos" on dentistas for select to anon, authenticated using (activo or es_admin());
drop policy if exists "admin dentistas" on dentistas;
create policy "admin dentistas" on dentistas for all to authenticated using (es_admin()) with check (es_admin());

drop policy if exists "leer servicios activos" on servicios;
create policy "leer servicios activos" on servicios for select to anon, authenticated using (activo or es_admin());
drop policy if exists "admin servicios" on servicios;
create policy "admin servicios" on servicios for all to authenticated using (es_admin()) with check (es_admin());

-- Pacientes, citas y reseñas: solo administradores. La web pública usa las funciones de arriba.
drop policy if exists "admin pacientes" on pacientes;
create policy "admin pacientes" on pacientes for all to authenticated using (es_admin()) with check (es_admin());
drop policy if exists "admin citas" on citas;
create policy "admin citas" on citas for all to authenticated using (es_admin()) with check (es_admin());
drop policy if exists "admin resenas" on resenas;
create policy "admin resenas" on resenas for all to authenticated using (es_admin()) with check (es_admin());

drop policy if exists "verse a si mismo" on administradores;
create policy "verse a si mismo" on administradores for select to authenticated using (user_id = auth.uid());

-- ---------- Permisos de la Data API ----------
-- El proyecto se creó SIN "dar acceso automático a tablas nuevas", así que aquí se da solo lo necesario.
-- Los permisos dicen qué se puede intentar; RLS (arriba) decide qué filas se ven de verdad.
grant usage on schema public to anon, authenticated;
grant select on ajustes, horario, dentistas, servicios to anon, authenticated;
grant select, insert, update, delete on ajustes, horario, dentistas, servicios, pacientes, citas, resenas to authenticated;
grant select on administradores to authenticated;
grant select on v_citas, v_resenas, v_servicios,
                est_servicios, est_faltas, est_horas, est_regresan, est_dentistas, est_calificacion to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Funciones que puede llamar la web pública (anon) y el panel (authenticated).
grant execute on function disponibilidad(), sitio_publico(), ver_resena(text), dejar_resena(text, int, text),
  apartar_cita(text, int, date, text, text, text, text), hoy_mx() to anon, authenticated;
grant execute on function es_admin() to anon, authenticated;      -- lo usan las reglas RLS
grant execute on function estadisticas() to authenticated;

-- Funciones internas: que no se puedan llamar desde la web.
revoke execute on function _demasiados(text, int, int) from public, anon, authenticated;
revoke execute on function horas_ofrecidas() from public, anon, authenticated;
revoke execute on function estadisticas() from public, anon;
