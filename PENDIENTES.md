# PENDIENTES — Qué te toca a ti

El código ya está escrito y probado en todo lo que se puede probar sin llaves. Lo que queda son **credenciales que solo tú puedes generar** y **cuatro decisiones**. Este documento va en orden: si lo sigues de arriba abajo, la tienda queda en producción.

Cada punto dice **dónde** tocar y **cómo saber que quedó bien**.

> **Nunca me mandes por chat** la `SUPABASE_SERVICE_ROLE_KEY`, el *client secret* de Google ni el `MP_ACCESS_TOKEN`. Todo eso vive en `env.js` (local) y en las variables de entorno de Vercel.

---

## Resumen de estado

| Pieza | Código | Falta |
|---|---|---|
| Tienda y panel completos | ✅ listo | — |
| Colores libres con imágenes propias | ✅ listo | — |
| Adaptador de Supabase (`Nube`) | ✅ escrito | tus llaves + probarlo |
| Sesión contra Supabase Auth | ✅ escrito | crear el usuario admin |
| Google Drive + Picker (`Drive`) | ✅ escrito | credenciales de Google Cloud |
| Subida a Storage | ✅ escrito | crear el bucket |
| Cobro (`api/crear-preferencia.js` + `api/webhook.js`) | ✅ escrito | cuenta y token de la pasarela |
| Metadatos y aviso de almacenamiento | ✅ listo | — |
| Eliminación de pedidos con reintegro | ✅ listo | — |
| URLs limpias | ⏳ decisión tuya | punto 6 |
| Correos de confirmación | ⏳ | punto 7 |

Ninguna integración rompe la demostración: mientras `env.js` no exista, todo sigue funcionando contra el navegador.

---

## 1. Supabase — 20 minutos

1. Crea el proyecto en [supabase.com](https://supabase.com).
2. **SQL Editor** → pega y ejecuta `supabase/schema.sql` completo.
3. **Authentication → Users → Add user** → tu correo y una contraseña.
4. **SQL Editor** → autorízate como administrador (copia el UUID de la lista de usuarios):
   ```sql
   insert into admins (user_id, correo) values ('PEGA-AQUÍ-EL-UUID', 'tu@correo.mx');
   ```
5. **Storage → New bucket** → nombre `productos`, marcado como **público**.
6. **Settings → API** → copia `Project URL` y `anon public`.
7. Copia `env.example.js` a **`env.js`** y llena:
   ```js
   SUPABASE_URL: 'https://xxxx.supabase.co',
   SUPABASE_ANON_KEY: 'eyJ...',
   ```
8. **En `index.html`**, busca `<div id="app"></div>` y **justo antes** del `<script>` que le sigue, agrega:
   ```html
   <script src="env.js"></script>
   ```
   Es el único cambio que hay que hacer a mano dentro del archivo.

**Cómo saber que quedó:** entra a `#/admin`. El recuadro de arriba debe decir **«Origen de datos: Supabase»** en lugar de «navegador (localStorage)». Si dice lo otro, `env.js` no se cargó.

**Ojo — el catálogo inicial.** Las tablas nacen vacías. Para subir los 18 productos de la demostración, abre la tienda **sin** `env.js`, entra a la consola del navegador y ejecuta:
```js
copy(JSON.stringify(ONIX.DB.crudo(), null, 2))
```
Eso deja el estado completo en el portapapeles; pégalo en un archivo y súbelo con el importador de Supabase, o créalos desde el panel ya conectado. Es más rápido de lo que suena: el panel ya guarda contra Supabase en cuanto `env.js` existe.

**Prueba de seguridad, no la saltes:** crea un segundo usuario **sin** meterlo en `admins`, entra con él e intenta guardar un producto. Debe fallar. Si guarda, revisa que ejecutaste la sección de políticas del `schema.sql` completa.

---

## 2. Google Drive + Picker — 30 minutos

1. [console.cloud.google.com](https://console.cloud.google.com) → crea un proyecto.
2. **APIs y servicios → Biblioteca** → habilita **Google Drive API** y **Google Picker API**.
3. **Pantalla de consentimiento OAuth** → tipo *Externo* → nombre de la app, tu correo de soporte y tu dominio. Mientras esté en modo *Prueba*, agrega tu cuenta en **Usuarios de prueba**.
4. **Credenciales → Crear → ID de cliente de OAuth** → *Aplicación web*.
   - **Orígenes autorizados de JavaScript**: `https://tu-dominio.vercel.app` y `http://localhost:3000`
   - No hace falta URI de redirección: el flujo es de token, no de código.
5. **Credenciales → Crear → Clave de API** → restríngela a las dos APIs de arriba.
6. Ponlas en `env.js`:
   ```js
   GOOGLE_CLIENT_ID: '....apps.googleusercontent.com',
   GOOGLE_API_KEY: 'AIza...',
   ```

**El scope es `drive.file`** (solo los archivos que elijas en el Picker). Es el mínimo y te evita el proceso de verificación de Google, que tarda semanas. No lo amplíes a `drive.readonly` salvo que de verdad lo necesites.

**Lo que cambia el día que enciendes esto:** OAuth **no funciona desde `file://`**. A partir de aquí el panel necesita servidor:
```bash
npx serve .        # y abres http://localhost:3000
```
La tienda pública puede seguir abriéndose con doble clic; el panel no.

**Cómo saber que quedó:** en `#/admin/productos/nuevo`, en cualquier color, el botón **Elegir de Google Drive** debe abrir el selector de Google. Si el bucket de Storage ya existe, la foto se copia a Supabase y lo que se guarda es la URL de Storage, no la de Drive.

**Mi recomendación, por si sirve:** deja que Drive sea solo el lugar de donde eliges, y que las fotos vivan en Storage. Los enlaces `drive.google.com/uc?export=view` se caen bajo tráfico, no tienen CDN ni redimensionado, y atan el catálogo a una cuenta personal. El código ya hace esa copia automáticamente cuando ambas cosas están configuradas (`Drive.copiarAStorage`).

---

## 3. Pagos — 40 minutos

Aquí se acaba lo estático: hacen falta las dos funciones de `api/`, que Vercel ejecuta en el servidor.

1. Crea la cuenta de vendedor en [Mercado Pago](https://www.mercadopago.com.mx/developers) (para México: cubre tarjeta, meses sin intereses, OXXO y SPEI).
2. **Tus integraciones → Credenciales de producción** → copia el **Access Token**.
3. En Vercel, **Settings → Environment Variables**, agrega:

   | Variable | Valor |
   |---|---|
   | `MP_ACCESS_TOKEN` | El token privado |
   | `SUPABASE_URL` | La misma del punto 1 |
   | `SUPABASE_SERVICE_ROLE_KEY` | **Settings → API → service_role.** Solo aquí |
   | `SITIO_URL` | `https://tu-dominio.com` |

4. En `env.js` enciende el cobro del lado del cliente:
   ```js
   PASARELA: 'mercadopago',
   ```
5. En Mercado Pago, **Webhooks** → apunta a `https://tu-dominio.com/api/webhook`, evento *Pagos*.

**Cómo está armado el circuito** (y por qué así):

```
Cliente confirma → /api/crear-preferencia → Mercado Pago
                          ↓                       ↓
              relee precios de la BD        cliente paga
                                                  ↓
                                        /api/webhook (cobro aprobado)
                                                  ↓
                                     crear_pedido() en Postgres
                                     ├── descuenta inventario
                                     ├── da de alta al cliente
                                     └── registra el pedido
```

Dos decisiones que ya están tomadas en el código y conviene que sepas:
- **El importe se vuelve a leer de la base de datos** en el servidor. Lo que manda el navegador se ignora; si no, cualquiera podría editar el precio antes de pagar.
- **El pedido nace en el webhook, no al confirmar.** Así el inventario solo se toca cuando el dinero entró. La función `crear_pedido` es idempotente por el id del pago, así que si Mercado Pago repite el aviso —lo hace— no se duplica nada.

**Para probar sin cobrar de verdad:** usa las credenciales de *prueba* y las tarjetas de prueba de Mercado Pago. Verifica que un pago rechazado **no** cree pedido ni mueva inventario.

Si vas a vender fuera de México, dime y cambio las dos funciones a Stripe: la forma es la misma.

---

## 4. Decisión: ¿cuándo se aparta el inventario?

Hoy: **al confirmarse el pago**. Antes de eso, dos personas pueden tener la última pieza en el carrito y solo una se la lleva; la otra ve el aviso de que se agotó al pagar.

La alternativa es apartarla al agregar al carrito, con un tiempo de expiración. Es más amable con el comprador y bastante más trabajo: tabla de reservas, trabajo programado que las libera y un cálculo de «disponible = stock − reservado». Con series de 200 piezas, mi opinión es que no vale la pena todavía.

**Dime cuál quieres.** Si eliges reservas, lo implemento.

---

## 5. Decisión: dominio y correo

- Compra el dominio y agrégalo en **Vercel → Settings → Domains**.
- En Supabase, **Authentication → URL Configuration**, pon tu dominio en *Site URL*.
- Actualiza los orígenes autorizados de Google (punto 2.4) con el dominio real.

---

## 6. Decisión: URLs limpias

Hoy las direcciones son `#/productos/sudadera-oxido-oversize`. Funciona, se puede compartir y sobrevive a recargar, **pero**: Google indexa mal el hash y las vistas previas de WhatsApp o Instagram no pueden mostrar la foto y el título del producto, porque el servidor nunca ve la parte que va después del `#`.

Si la tienda depende de búsqueda orgánica o de compartir enlaces, hay que quitar el hash:

1. En `index.html`, en `partesRuta()` (sección 10), cambiar `location.hash` por `location.pathname`.
2. Reemplazar `href="#/..."` por `href="/..."` e interceptar los clics con `history.pushState`.
3. El `vercel.json` incluido ya reescribe todo a `index.html` (y respeta `/api`).

Es medio día de trabajo. Para SEO de verdad —meta por producto en el HTML que llega al navegador— haría falta generar las páginas en el servidor, y ahí ya estamos hablando de la versión Next.js que también tienes. **Dime qué peso tiene el SEO en este proyecto** y te digo cuál de los dos caminos conviene.

---

## 7. Correos de confirmación

Falta el aviso al cliente cuando el pedido entra y cuando sale. Va en `api/webhook.js`, donde dice `// Aquí va el correo de confirmación`.

Necesitas una cuenta en [Resend](https://resend.com) (o Postmark), verificar tu dominio con los registros DNS que te den, y agregar `RESEND_API_KEY` a las variables de Vercel. Cuando lo tengas, escribo la plantilla.

---

## 8. Antes de abrir al público

- [ ] Un usuario sin permisos **no** puede escribir (prueba del punto 1)
- [ ] Un pago rechazado no crea pedido ni mueve inventario
- [ ] El aviso de privacidad y los términos dicen algo real, no el texto de relleno actual
- [ ] Los precios y el costo de envío de **Configuración** son los definitivos
- [ ] Probaste una compra completa desde un teléfono, no solo desde la computadora
- [ ] Cambiaste el nombre y los datos de contacto de la tienda
- [ ] Las fotos reales sustituyeron a los dibujos técnicos, al menos en los productos que más se venden

---

## Cómo funcionan los colores (lo que pediste)

Cada color es **un objeto con sus propias imágenes**, no una etiqueta:

```js
colores: [
  { nombre: 'Verde militar', hex: '#4a5340', imagenes: [ … ] },
  { nombre: 'Arena',        hex: '#c9b79c', imagenes: [ … ] }
]
```

Elegir un color en la ficha cambia **la galería completa** —foto principal y miniaturas—, no solo el recuadro del selector. La portada del catálogo es la primera foto del primer color con existencias.

**Para dar de alta un color:** `#/admin/productos/nuevo` → bloque *Colores e imágenes* → escribe el nombre, elige el color con el selector (o escribe el hexadecimal) y pulsa **Agregar color**. La matriz de variantes se recalcula sola: el color nuevo aparece con todas las tallas en cero, listo para capturar existencias.

**Mientras no haya fotos**, el color nuevo recibe un dibujo técnico **en ese color**, generado a partir del hexadecimal: la tela toma el color real y el trazo se aclara u oscurece según convenga para que se lea. Por eso «Vino» se ve vino y «Arena» se ve arena, sin que subas nada.

**Para poner fotos reales**, en la fila del color pulsa el icono de imagen. Dentro puedes:
- agregar por **dirección web** (cualquier URL pública, incluido un CDN que ya uses);
- **elegir de Google Drive** (punto 2);
- **subir a Storage** (punto 1);
- reordenar: la primera imagen es la portada;
- mezclar fotos con dibujos, por si tienes fotografiados solo algunos colores.

Si un color se queda sin fotos propias, la tienda usa la galería general del producto. Ningún producto se queda con un hueco gris.
