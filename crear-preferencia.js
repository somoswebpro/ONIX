/* ============================================================
   POST /api/crear-preferencia
   Arma el cobro y devuelve la dirección a la que hay que enviar
   al comprador. Corre en el servidor porque la llave secreta de
   la pasarela no puede viajar al navegador.

   Variables de entorno necesarias en Vercel:
     MP_ACCESS_TOKEN        Token privado de Mercado Pago
     SUPABASE_URL
     SUPABASE_SERVICE_ROLE_KEY   (solo aquí; nunca en el cliente)
     SITIO_URL              https://tu-dominio.com

   Regla que sostiene esto: NO se toca el inventario todavía. El
   pedido se crea cuando el webhook confirma el cobro.
   ============================================================ */

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Método no permitido' });
  }

  const token = process.env.MP_ACCESS_TOKEN;
  const sitio = process.env.SITIO_URL || '';
  if (!token) {
    return res.status(500).json({ error: 'Falta MP_ACCESS_TOKEN en las variables de entorno.' });
  }

  const borrador = req.body || {};
  const items = Array.isArray(borrador.items) ? borrador.items : [];
  if (!items.length) {
    return res.status(400).json({ error: 'El pedido llegó vacío.' });
  }

  /* Los precios se vuelven a leer de la base de datos: el importe
     nunca se acepta desde el navegador, aunque venga en el cuerpo. */
  const precios = await preciosReales(items.map((i) => i.productoId));
  const lineas = items.map((i) => ({
    id: i.sku,
    title: i.nombre + ' · ' + i.talla + ' / ' + i.color,
    quantity: Number(i.cantidad) || 1,
    unit_price: Number(precios[i.productoId] ?? i.precio),
    currency_id: 'MXN'
  }));

  const subtotal = lineas.reduce((t, l) => t + l.unit_price * l.quantity, 0);
  const envio = Number(borrador.envio) || 0;
  const descuento = Number(borrador.descuento) || 0;

  const preferencia = {
    items: lineas,
    payer: {
      name: borrador.cliente?.nombre || '',
      email: borrador.cliente?.correo || '',
      phone: { number: borrador.cliente?.telefono || '' }
    },
    shipments: { cost: envio, mode: 'not_specified' },
    back_urls: {
      success: sitio + '/#/pedido/pendiente',
      failure: sitio + '/#/carrito',
      pending: sitio + '/#/carrito'
    },
    auto_return: 'approved',
    notification_url: sitio + '/api/webhook',
    statement_descriptor: 'ONIX',
    /* Todo lo que el webhook necesitará para crear el pedido. */
    metadata: {
      cliente: borrador.cliente,
      items: items,
      cupon: borrador.cupon || '',
      subtotal: subtotal,
      descuento: descuento,
      envio: envio,
      total: subtotal - descuento + envio
    }
  };

  try {
    const r = await fetch('https://api.mercadopago.com/checkout/preferences', {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
      body: JSON.stringify(preferencia)
    });
    const datos = await r.json();
    if (!r.ok) {
      console.error('Mercado Pago rechazó la preferencia', datos);
      return res.status(502).json({ error: 'La pasarela rechazó el cobro.' });
    }
    /* init_point es producción; sandbox_init_point, pruebas. */
    return res.status(200).json({ url: datos.init_point || datos.sandbox_init_point });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'No se pudo contactar la pasarela.' });
  }
}

/** Lee los precios vigentes en Supabase para no fiarse del cliente. */
async function preciosReales(ids) {
  const url = process.env.SUPABASE_URL;
  const llave = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !llave || !ids.length) return {};
  const filtro = 'id=in.(' + ids.map(encodeURIComponent).join(',') + ')';
  const r = await fetch(url + '/rest/v1/productos?select=id,precio&' + filtro, {
    headers: { apikey: llave, Authorization: 'Bearer ' + llave }
  });
  if (!r.ok) return {};
  const filas = await r.json();
  return filas.reduce((acc, f) => { acc[f.id] = Number(f.precio); return acc; }, {});
}
