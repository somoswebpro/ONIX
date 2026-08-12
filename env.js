/* ============================================================
   Copia este archivo a env.js y llena lo que vayas a usar.
   env.js NO se sube al repositorio (está en .gitignore): en
   Vercel se genera durante el despliegue con las variables de
   entorno del proyecto.

   Todo lo de aquí es público por diseño: viaja al navegador.
   Lo que protege tus datos son las políticas RLS de
   supabase/schema.sql, no esconder estas llaves.

   La SERVICE_ROLE y el token de la pasarela NO van aquí: viven
   solo en las variables de entorno del servidor (carpeta api/).
   ============================================================ */
globalThis.ONIX_ENV = {
  /* ── Supabase ── */
  SUPABASE_URL: 'https://qxzaarlhuzssqniffsxx.supabase.co/rest/v1/',
  SUPABASE_ANON_KEY: 'sb_publishable_iKLQvfagaITKEpvFBw0S8g_7UHGMzH_',
  SUPABASE_BUCKET: 'productos',

  /* ── Google Drive + Picker ──
     OJO: con esto encendido el panel deja de abrirse con doble
     clic; OAuth no funciona desde file://. Usa `npx serve .`  */
  GOOGLE_CLIENT_ID: '',
  GOOGLE_API_KEY: '',

  /* ── Pagos ──
     'mercadopago' o el nombre que uses. Vacío = sin cobro: el
     pedido se registra directamente, como en la demostración. */
  PASARELA: '',
  RUTA_PAGO: '/api/crear-preferencia'
};
