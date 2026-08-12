# ÓNIX — Tienda de ropa con panel administrativo

Un solo archivo: `index.html`. Ábrelo con doble clic. No necesita servidor, ni Node, ni instalación.

**Panel administrativo:** `index.html#/admin` · `admin@onix.mx` / `onix123`

Para dejarla en producción —Supabase, Drive, pagos y dominio— sigue **`PENDIENTES.md`**: ahí está, en orden, todo lo que necesita una llave tuya.

---

## 1. Qué se construyó

**Tienda pública** — portada con bloque principal editable, categorías, destacados, banners promocionales y archivo de ofertas; catálogo con filtros por categoría, talla, color, precio, oferta y disponibilidad, más cinco criterios de orden; ficha de producto con **galería propia por color**, selector color → talla y stock por variante; carrito persistente con cupones y envío calculado; pago con validación; favoritos; búsqueda global; contacto con preguntas frecuentes.

**Panel administrativo** — acceso con sesión, resumen con métricas y gráfica de ventas, productos (crear, editar, duplicar, eliminar), inventario por variante, pedidos con cambio de estado y detalle, clientes, categorías, cupones, portada y configuración de la tienda.

Rutas por hash (`#/productos/[slug]`, `#/admin/pedidos`…) para que el archivo funcione desde el sistema de archivos. Al desplegarlo puedes pasar a URLs limpias; ver el punto 6.

---

## 2. Cómo se conectan el panel y el catálogo

Hay **un solo origen de datos**, el objeto `DB`. Nadie más guarda una copia del catálogo.

```
Panel → DB.guardarProducto() → guarda → DB.emit('productos')
                                             ↓
                              cada vista suscrita se repinta
                                             ↓
                              Catálogo público con el dato nuevo
```

Compruébalo: abre el panel en una pestaña y la tienda en otra. Cambia un precio y guarda; la otra pestaña se actualiza sola (`window.addEventListener('storage')`).

Consecuencias que ya funcionan:

- Cambiar un precio → cambia en catálogo, ficha, carrito y pago.
- Pasar un producto a **borrador** → desaparece de la tienda, sigue en el panel.
- Desactivar una categoría → sus productos salen de la tienda sin borrarse.
- Poner una variante en 0 → esa talla aparece tachada y no se puede comprar.
- Confirmar un pedido → descuenta inventario real, da de alta al cliente y suma un uso al cupón.
- Eliminar un pedido → puede devolver sus piezas al inventario en la misma operación.
- Agregar un color → aparece en la ficha con sus propias fotos y con todas las tallas en la matriz de variantes.

---

## 3. Rutas

### Tienda

| Dirección | Contenido |
|---|---|
| `#/` | Portada: bloque principal, garantías, categorías, destacados, promocionales, ofertas, cierre |
| `#/productos` | Catálogo con buscador, filtros y ordenamiento |
| `#/productos/:slug` | Ficha de producto |
| `#/categorias/:slug` | Catálogo acotado a una familia |
| `#/ofertas` | Archivo con descuento y métricas de ahorro |
| `#/favoritos` | Piezas guardadas en este navegador |
| `#/buscar?q=` | Búsqueda global |
| `#/carrito` · `#/pago` · `#/pedido/:numero` | Los tres pasos de compra |
| `#/contacto` | Formulario validado y preguntas frecuentes |

### Panel

| Dirección | Contenido |
|---|---|
| `#/admin` | Resumen: métricas, ventas por día, inventario bajo, pedidos, más vendidos |
| `#/admin/productos` | Tabla con búsqueda y filtros; editar, duplicar, eliminar |
| `#/admin/productos/nuevo` | Alta y edición (`?editar=slug`), con matriz de variantes |
| `#/admin/inventario` | Existencias por variante, producto a producto |
| `#/admin/pedidos` | Cambio de estado, detalle completo y eliminación con reintegro de inventario |
| `#/admin/clientes` | Alta automática al confirmar un pedido |
| `#/admin/categorias` | Crear, editar, activar y desactivar |
| `#/admin/cupones` | Porcentaje o monto fijo, mínimo de compra y límite de usos |
| `#/admin/portada` | Titular, botones, imagen y banners promocionales |
| `#/admin/configuracion` | Tienda, contacto, envíos e integraciones |

---

## 4. Qué es temporal

| Pieza | Hoy | Después |
|---|---|---|
| Almacenamiento | `localStorage` del navegador | PostgreSQL en Supabase |
| Sesión | Usuario fijo en el código, visible a propósito | Supabase Auth + tabla `admins` |
| Permisos | Comprobación en el navegador | Row Level Security en Postgres |
| Imágenes | Dibujos técnicos SVG generados, en el color real de cada variante | Fotos en Supabase Storage, elegidas desde Google Drive |
| Pagos | El pedido se registra sin cobrar | Mercado Pago, Stripe o PayPal |
| Correos | No se envía nada | Resend, Postmark o similar |

**Importante sobre los permisos:** hoy, quien abra la consola del navegador puede llamar a `ONIX.DB` y escribir. Eso es aceptable en una demostración local y deja de serlo el día que haya datos reales. La barrera de verdad son las políticas RLS de `supabase/schema.sql`: con ellas, Postgres rechaza el `UPDATE` aunque la petición llegue directamente a la API sin pasar por la interfaz.

---

## 5. Conectar Supabase

1. Crea un proyecto en [supabase.com](https://supabase.com).
2. **SQL Editor** → pega y ejecuta `supabase/schema.sql` (tablas, políticas RLS y las funciones `descontar_inventario` y `crear_pedido`).
3. **Authentication → Users** → crea tu usuario administrador.
4. **SQL Editor** → autorízalo:
   ```sql
   insert into admins (user_id, correo) values ('<uuid-del-usuario>', 'tu@correo.mx');
   ```
5. **Storage → New bucket** → `productos`, marcado como público.
6. Copia `env.example.js` a `env.js` y llena `SUPABASE_URL` y `SUPABASE_ANON_KEY` (**Settings → API**).
7. En `index.html`, antes del `<script>` principal, añade:
   ```html
   <script src="env.js"></script>
   ```

Los puntos de conexión están marcados en el código: cada método de `DB` (sección 3) es una función pequeña que hoy toca un arreglo en memoria y mañana hará la consulta. Ninguna vista necesita enterarse, porque ninguna vista lee los datos directamente.

---

## 6. Desplegar en Vercel

```bash
git init && git add . && git commit -m "Tienda ÓNIX"
git remote add origin https://github.com/TU-USUARIO/TU-REPO.git
git push -u origin main
```

En Vercel: **Add New → Project → importar el repositorio**. Framework: **Other**. Sin comando de build ni carpeta de salida — es un sitio estático.

`env.js` está en `.gitignore` a propósito. Genéralo en el despliegue con un comando de build:

```
echo "globalThis.ONIX_ENV={SUPABASE_URL:'$SUPABASE_URL',SUPABASE_ANON_KEY:'$SUPABASE_ANON_KEY'}" > env.js
```

**URLs limpias (opcional).** Para pasar de `#/productos/x` a `/productos/x`, sustituye `partesRuta()` por `location.pathname`, cambia los `href` y deja el `vercel.json` incluido, que reescribe todo a `index.html`.

---

## 7. Variables de entorno

| Variable | Para qué | ¿Puede verse en el navegador? |
|---|---|---|
| `SUPABASE_URL` | Dirección del proyecto | Sí |
| `SUPABASE_ANON_KEY` | Llave pública del cliente | Sí, está diseñada para eso |
| `SUPABASE_BUCKET` | Bucket de fotos (`productos`) | Sí |
| `SUPABASE_SERVICE_ROLE_KEY` | Tareas de servidor y migraciones | **Nunca.** Ignora RLS |

---

## 8. De demostración a producción

1. Ejecuta `supabase/schema.sql` y crea el usuario administrador.
2. Sube el catálogo inicial a las tablas, o créalo desde el panel ya conectado.
3. Sustituye los dibujos generados por fotos reales: solo cambia el valor del campo `imagenes` a `{ origen:'url', url:'…' }`.
4. Configura `env.js` y verifica que el resumen del panel deje de decir «navegador (localStorage)».
5. Prueba con una cuenta sin permisos que **no** pueda escribir. Si puede, revisa las políticas antes de seguir.
6. Conecta la pasarela en el paso 3 de `#/pago`: cobra primero y solo después llama a `crear_pedido`.
7. Añade correos de confirmación y da de alta tu dominio.

---

## La dirección visual

**El taller, no la pasarela.** Lo que define el sistema no es el negro: es la etiqueta cosida.

- **Color.** La paleta que enviaste, mapeada a una escala usable: `#eaeaea` (fondo de página), `#acaba9` (bordes), `#75706f` (texto secundario), `#2c2c2c` (superficies elevadas), `#121212` (el negro protagonista). Los grises son **ligeramente cálidos**, no neutros puros. Es intencional: da carácter sin meter color. Blanco puro solo en `--papel`, para las tarjetas.
- **Tipografía.** Archivo (variable, con eje de ancho) para titulares e Instrument Sans para interfaz. Subconjuntadas e incrustadas en base64 dentro del `<style id="fuentes">`: es el único bloque que no conviene editar a mano.
- **La firma.** Todo el sistema tipográfico secundario imita las etiquetas cosidas de una prenda: mayúsculas diminutas, muy espaciadas (`.etiqueta`). Los separadores estructurales no son líneas sino **pespuntes** (`.costura`). Y las tarjetas revelan la ficha técnica al pasar el cursor, como si levantaras la etiqueta interior. En móvil no hay hover, así que ahí nunca vive información esencial.
- **Imágenes.** Como todavía no hay fotografía, `media()` dibuja **fichas técnicas planas** en SVG —el lenguaje con el que se especifica una prenda antes de existir—, con encuadre propio por tipo de prenda y tres tonos. El catálogo se ve intencional y no como una plantilla con huecos grises.

---

## Colores e imágenes

Cada color es un objeto con **sus propias fotos**:

```js
colores: [{ nombre: 'Verde militar', hex: '#4a5340', imagenes: [ … ] }]
```

Elegir un color en la ficha cambia la galería entera. Se puede dar de alta **cualquier** color desde el panel —nombre libre y selector de color—, y mientras no haya fotografía el dibujo técnico se genera **en ese color**, calculando el contraste del trazo a partir de la luminosidad. Las fotos reales entran por URL, desde Google Drive o subiéndolas a Storage. Detalle en `PENDIENTES.md`.

## Estructura del archivo

Todo va numerado por secciones, para navegarlo con búsqueda de texto.

**CSS** (en `<head>`): 1 tokens · 2 base · 3 firma visual · 4 estructura · 5 botones · 6 insignias · 7 campos · 8 media · 9 aviso y cabecera · 10 hero · 11 garantías · 12 categorías · 13 productos · 14 promocionales · 15 cierre · 16 pie · 17 cabecera interior · 18 catálogo · 19 ficha · 20 carrito · 21 contacto · 22 modal · 23 panel · 24 contención · 25 accesibilidad · 26 avisos flotantes · 27 acceso · 28 favoritos · 29 pago · 30 piezas del panel · 31 editor de colores · 32 aviso de almacenamiento.

**JavaScript** (al final del `<body>`): 1 utilidades · 2 datos semilla · **3 origen de datos (`DB`)** · 4 sesión · 5 carrito y favoritos · 6 iconos y media · **6 bis nube (Supabase)** · **6 ter Drive** · **6 quater pagos** · 7 piezas de interfaz · 8 tienda pública · 9 panel administrativo · 10 enrutador y eventos.

No hay ningún `onclick` en el marcado: todos los eventos se delegan una vez sobre `document`.

---

## Compatibilidad con datos ya guardados

Los datos que el navegador tenga de una versión anterior **no se pierden ni rompen la tienda**: al arrancar se completan los campos que falten (por ejemplo, las imágenes por color, que antes no existían). La función que lo hace está en la sección 3, se llama `migrar()`, y es donde hay que añadir cada campo nuevo que se invente más adelante.

## Verificación realizada

- Sintaxis del JavaScript validada con `node --check`.
- Las 20 rutas revisadas con Playwright en **escritorio (1440), tablet (834) y móvil (390)**: sin errores de consola, sin vistas vacías y sin desbordamiento horizontal.
- Circuito completo probado de punta a punta: acceso al panel (rechaza contraseña incorrecta), cambio de precio visible en la tienda, borrador que desaparece del catálogo pero sigue en el panel, variante en cero que tacha la talla, compra con cupón que valida los cinco campos de envío, descuenta inventario, da de alta al cliente y crea el pedido; cambio de estado del pedido, categoría desactivada que retira sus productos, portada editable, alta de cupón, favoritos y restauración de la demostración.
- Sincronización entre pestañas comprobada: guardar un precio en el panel actualiza la ficha abierta en otra pestaña.
- Rastreo automático que pulsa **todos** los controles de las 20 rutas y vigila errores de consola, vistas en blanco y desplazamiento horizontal.
- Casos límite: última pieza, producto eliminado que seguía en un carrito, cupón que deja de aplicar, slug repetido, tablas sin resultados y datos guardados por versiones anteriores.

---

## Notas

- Los datos viven en `localStorage`. Vaciar el navegador los borra; **Resumen → Restaurar demostración** los devuelve.
- Las tipografías van dentro del archivo: funciona sin conexión y sin carpetas externas.
- `window.ONIX` expone `DB`, `Carrito`, `Favoritos`, `Auth`, `Nube`, `Drive`, `PAGOS` y `estado` para depurar desde la consola.
- Las funciones de `api/` solo corren en Vercel; en local necesitas `vercel dev`. Sin ellas, el pago sigue el camino de la demostración.

## Qué revisar antes de continuar

1. **El nombre.** ÓNIX es provisional. Se cambia desde el panel, en Configuración.
2. **Precios y copy.** Los 18 productos tienen nombres, telas, cortes y descripciones reales en español de México.
3. **La firma visual.** Etiquetas de prenda y pespuntes: si no te convence la dirección, es el momento de cambiarla.
4. **Las fichas técnicas dibujadas.** Si ya tienes fotos, dilo y cambio las fuentes.
5. **Reglas de negocio.** Envío gratis desde $1,200, envío estándar de $149 y cambios durante 30 días — todo editable en Configuración.

---

## Archivos

```
index.html                 La tienda y el panel completos
env.example.js             Plantilla de llaves (cópiala a env.js)
vercel.json                Reescrituras y cabeceras de seguridad
.gitignore
PENDIENTES.md              Qué te toca a ti para terminar
supabase/schema.sql        Tablas, RLS y funciones transaccionales
api/crear-preferencia.js   Arma el cobro (servidor)
api/webhook.js             Confirma el cobro y crea el pedido (servidor)
```
