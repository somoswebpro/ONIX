/* ============================================================
   POST /api/webhook
   Mercado Pago avisa aquí cuando cambia un pago. Este es el único
   sitio donde nace un pedido: si el cobro no está aprobado, no se
   descuenta inventario ni se registra nada.

   El aviso NO trae el estado en un formato confiable, así que se
   vuelve a consultar el pago por su id antes de creer nada.
   ============================================================ */

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();

  const token = process.env.MP_ACCESS_TOKEN;
  const url = process.env.SUPABASE_URL;
  const llave = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!token || !url || !llave) {
    console.error('Faltan variables de entorno para el webhook.');
    return res.status(500).end();
  }

  const cuerpo = req.body || {};
  const idPago = cuerpo.data?.id || cuerpo['data.id'];
  const tipo = cuerpo.type || cuerpo.topic;
  if (tipo !== 'payment' || !idPago) {
    /* Otros avisos (planes, suscripciones) se aceptan y se ignoran:
       responder 200 evita que Mercado Pago siga reintentando. */
    return res.status(200).json({ recibido: true });
  }

  try {
    const r = await fetch('https://api.mercadopago.com/v1/payments/' + idPago, {
      headers: { Authorization: 'Bearer ' + token }
    });
    const pago = await r.json();

    if (pago.status !== 'approved') {
      return res.status(200).json({ recibido: true, estado: pago.status });
    }

    const meta = pago.metadata || {};
    const carga = {
      cliente: meta.cliente,
      items: meta.items,
      cupon: meta.cupon || '',
      subtotal: meta.subtotal,
      descuento: meta.descuento,
      envio: meta.envio,
      total: meta.total,
      /* El id del pago va de idempotencia: si Mercado Pago repite el
         aviso, `crear_pedido` reconoce el mismo id y no duplica. */
      id: 'ped_mp_' + idPago,
      numero: 'ONX-' + String(idPago).slice(-5)
    };

    const creado = await fetch(url + '/rest/v1/rpc/crear_pedido', {
      method: 'POST',
      headers: { apikey: llave, Authorization: 'Bearer ' + llave, 'Content-Type': 'application/json' },
      body: JSON.stringify({ carga })
    });

    if (!creado.ok) {
      const detalle = await creado.text();
      console.error('crear_pedido falló', detalle);
      /* Devolver 500 hace que Mercado Pago reintente, que es lo que
         queremos: el cobro ya ocurrió y el pedido tiene que existir. */
      return res.status(500).json({ error: 'No se pudo registrar el pedido.' });
    }

    // Aquí va el correo de confirmación (Resend, Postmark…).
    return res.status(200).json({ recibido: true, creado: true });
  } catch (e) {
    console.error(e);
    return res.status(500).end();
  }
}
