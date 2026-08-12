-- ============================================================
--  ÓNIX — Esquema de base de datos
--  Ejecutar en Supabase → SQL Editor. Idempotente.
--
--  Los nombres de tabla y columna son los mismos que usa el
--  objeto DB del archivo index.html, para que migrar consista en
--  cambiar el cuerpo de cada método por una consulta.
-- ============================================================

-- ── Tablas ──────────────────────────────────────────────────

create table if not exists categorias (
  id          text primary key,
  slug        text not null unique,
  nombre      text not null,
  descripcion text default '',
  -- { origen:'url'|'generado', url|arte, tono }
  imagen      jsonb not null default '{}'::jsonb,
  activa      boolean not null default true,
  orden       integer not null default 0,
  destacada   boolean not null default false,
  creado_en   timestamptz not null default now()
);

create table if not exists productos (
  id             text primary key,
  slug           text not null unique,
  nombre         text not null,
  resumen        text default '',
  descripcion    text default '',
  precio         numeric(10,2) not null check (precio >= 0),
  precio_antes   numeric(10,2) not null default 0 check (precio_antes >= 0),
  categoria      text references categorias(slug) on delete set null,
  sku            text not null,
  -- Solo referencias. Los binarios viven en Storage o en Drive.
  -- Galería de respaldo, cuando un color no trae fotos propias.
  imagenes       jsonb not null default '[]'::jsonb,
  -- [{ nombre, hex, imagenes:[...] }] — cada color lleva SUS fotos:
  -- elegirlo en la ficha cambia la galería entera.
  colores        jsonb not null default '[]'::jsonb,
  tallas         jsonb not null default '[]'::jsonb,
  -- [{ color, talla, stock, sku }] — la unidad real de inventario.
  -- El stock del producto es la suma de esto, nunca un número aparte.
  variantes      jsonb not null default '[]'::jsonb,
  composicion    text default '',
  cuidados       jsonb not null default '[]'::jsonb,
  corte          text default '',
  etiqueta       text,
  estado         text not null default 'borrador'
                 check (estado in ('activo','borrador','archivado')),
  destacado      boolean not null default false,
  nuevo          boolean not null default false,
  valoracion     numeric(2,1) not null default 0,
  resenas        integer not null default 0,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create index if not exists productos_categoria_idx on productos(categoria);
create index if not exists productos_estado_idx    on productos(estado);
-- Búsqueda por texto en español, sin acentos.
create index if not exists productos_busqueda_idx on productos
  using gin (to_tsvector('spanish',
    coalesce(nombre,'') || ' ' || coalesce(resumen,'') || ' ' || coalesce(composicion,'')));

create table if not exists clientes (
  id        text primary key,
  nombre    text not null,
  correo    text not null unique,
  telefono  text default '',
  direccion text default '',
  creado_en timestamptz not null default now()
);

create table if not exists pedidos (
  id             text primary key,
  numero         text not null unique,
  cliente_id     text references clientes(id) on delete set null,
  -- Copia congelada al momento del pedido: si el cliente cambia de
  -- domicilio, el histórico no se reescribe.
  cliente        jsonb not null default '{}'::jsonb,
  items          jsonb not null default '[]'::jsonb,
  cupon          text default '',
  subtotal       numeric(10,2) not null default 0,
  descuento      numeric(10,2) not null default 0,
  envio          numeric(10,2) not null default 0,
  total          numeric(10,2) not null default 0,
  estado         text not null default 'pendiente'
                 check (estado in ('pendiente','confirmado','preparando','enviado','entregado','cancelado')),
  notas          text default '',
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create index if not exists pedidos_estado_idx on pedidos(estado);
create index if not exists pedidos_fecha_idx  on pedidos(creado_en desc);

create table if not exists cupones (
  id        text primary key,
  codigo    text not null unique,
  tipo      text not null default 'porcentaje' check (tipo in ('porcentaje','fijo')),
  valor     numeric(10,2) not null check (valor > 0),
  minimo    numeric(10,2) not null default 0,
  max_usos  integer not null default 0,   -- 0 = ilimitado
  usos      integer not null default 0,
  activo    boolean not null default true,
  creado_en timestamptz not null default now()
);

-- Portada, banners, bloque de cierre y configuración de la tienda:
-- cuatro registros, no cuatro tablas.
create table if not exists contenido (
  id             text primary key,
  valor          jsonb not null default '{}'::jsonb,
  actualizado_en timestamptz not null default now()
);

-- Quién puede administrar. Se llena a mano con el id de auth.users.
create table if not exists admins (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  correo    text,
  creado_en timestamptz not null default now()
);

-- ── Autorización ────────────────────────────────────────────
-- Esta es la barrera real. Ocultar botones en el navegador no lo es:
-- hoy cualquiera puede abrir la consola y llamar a ONIX.DB.

create or replace function es_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admins where user_id = auth.uid());
$$;

alter table categorias enable row level security;
alter table productos  enable row level security;
alter table clientes   enable row level security;
alter table pedidos    enable row level security;
alter table cupones    enable row level security;
alter table contenido  enable row level security;
alter table admins     enable row level security;

-- Lectura pública: solo lo que debe verse en la tienda.
drop policy if exists "catálogo público" on productos;
create policy "catálogo público" on productos
  for select using (estado = 'activo' or es_admin());

drop policy if exists "categorías públicas" on categorias;
create policy "categorías públicas" on categorias
  for select using (activa = true or es_admin());

drop policy if exists "contenido público" on contenido;
create policy "contenido público" on contenido for select using (true);

-- Escritura: exclusiva de administradores.
drop policy if exists "admin escribe productos" on productos;
create policy "admin escribe productos" on productos
  for all using (es_admin()) with check (es_admin());

drop policy if exists "admin escribe categorías" on categorias;
create policy "admin escribe categorías" on categorias
  for all using (es_admin()) with check (es_admin());

drop policy if exists "admin escribe contenido" on contenido;
create policy "admin escribe contenido" on contenido
  for all using (es_admin()) with check (es_admin());

drop policy if exists "admin gestiona cupones" on cupones;
create policy "admin gestiona cupones" on cupones
  for all using (es_admin()) with check (es_admin());

-- Pedidos y clientes: nadie los lee desde el navegador salvo el admin.
-- Los pedidos entran por la función de abajo, no por INSERT directo.
drop policy if exists "admin gestiona pedidos" on pedidos;
create policy "admin gestiona pedidos" on pedidos
  for all using (es_admin()) with check (es_admin());

drop policy if exists "admin gestiona clientes" on clientes;
create policy "admin gestiona clientes" on clientes
  for all using (es_admin()) with check (es_admin());

drop policy if exists "admin se ve a sí mismo" on admins;
create policy "admin se ve a sí mismo" on admins
  for select using (user_id = auth.uid());

-- ── Inventario transaccional ────────────────────────────────
-- Sin esto, dos compras simultáneas pueden vender la misma última pieza.

create or replace function descontar_inventario(lineas jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  linea   jsonb;
  actual  int;
begin
  for linea in select * from jsonb_array_elements(lineas) loop
    select (v->>'stock')::int into actual
    from productos p, jsonb_array_elements(p.variantes) v
    where p.id = linea->>'productoId'
      and v->>'color' = linea->>'color'
      and v->>'talla' = linea->>'talla'
    for update;

    if actual is null then
      raise exception 'La variante solicitada ya no existe.';
    end if;
    if actual < (linea->>'cantidad')::int then
      raise exception 'Sin existencias suficientes.';
    end if;

    update productos p
    set variantes = (
      select jsonb_agg(
        case when v->>'color' = linea->>'color' and v->>'talla' = linea->>'talla'
             then jsonb_set(v, '{stock}', to_jsonb((v->>'stock')::int - (linea->>'cantidad')::int))
             else v end)
      from jsonb_array_elements(p.variantes) v),
        actualizado_en = now()
    where p.id = linea->>'productoId';
  end loop;
end;
$$;

-- Crear el pedido y descontar el inventario son una sola operación.
create or replace function crear_pedido(carga jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  nuevo_pedido pedidos;
  id_cliente   text;
begin
  -- Idempotencia primero: el webhook de la pasarela repite el aviso del
  -- mismo pago, y sin esto el inventario se descontaría dos veces.
  if carga ? 'id' then
    select * into nuevo_pedido from pedidos where id = carga->>'id';
    if found then
      return to_jsonb(nuevo_pedido);
    end if;
  end if;

  insert into clientes (id, nombre, correo, telefono, direccion)
  values (
    coalesce(carga->'cliente'->>'id', 'cli_' || gen_random_uuid()),
    carga->'cliente'->>'nombre',
    lower(carga->'cliente'->>'correo'),
    coalesce(carga->'cliente'->>'telefono', ''),
    coalesce(carga->'cliente'->>'direccion', ''))
  on conflict (correo) do update
    set nombre = excluded.nombre,
        telefono = excluded.telefono,
        direccion = excluded.direccion
  returning id into id_cliente;

  update cupones set usos = usos + 1
  where codigo = coalesce(carga->>'cupon', '') and codigo <> '';

  perform descontar_inventario(carga->'items');

  insert into pedidos (id, numero, cliente_id, cliente, items, cupon, subtotal, descuento, envio, total, estado)
  values (
    coalesce(carga->>'id', 'ped_' || gen_random_uuid()),
    coalesce(carga->>'numero', 'ONX-' || lpad((floor(random()*99999))::text, 5, '0')),
    id_cliente,
    coalesce(carga->'cliente', '{}'::jsonb),
    carga->'items',
    coalesce(carga->>'cupon', ''),
    coalesce((carga->>'subtotal')::numeric, 0),
    coalesce((carga->>'descuento')::numeric, 0),
    coalesce((carga->>'envio')::numeric, 0),
    coalesce((carga->>'total')::numeric, 0),
    'pendiente')
  returning * into nuevo_pedido;

  return to_jsonb(nuevo_pedido);
end;
$$;

grant execute on function crear_pedido(jsonb) to anon, authenticated;

-- ── Storage ─────────────────────────────────────────────────
-- Crear el bucket público `productos` desde el panel, y luego:

drop policy if exists "fotos públicas" on storage.objects;
create policy "fotos públicas" on storage.objects
  for select using (bucket_id = 'productos');

drop policy if exists "admin sube fotos" on storage.objects;
create policy "admin sube fotos" on storage.objects
  for insert with check (bucket_id = 'productos' and es_admin());

drop policy if exists "admin borra fotos" on storage.objects;
create policy "admin borra fotos" on storage.objects
  for delete using (bucket_id = 'productos' and es_admin());

-- ── Después de ejecutar esto ────────────────────────────────
-- 1. Authentication → Users → crear tu usuario administrador.
-- 2. insert into admins (user_id, correo) values ('<uuid-del-usuario>', 'tu@correo.mx');
-- 3. Storage → New bucket → `productos`, marcado como público.
-- 4. Copiar env.example.js a env.js con SUPABASE_URL y SUPABASE_ANON_KEY.
-- 5. Comprobar con una cuenta sin permisos que NO pueda escribir.
