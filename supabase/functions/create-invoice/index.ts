// Edge Function: create-invoice
// Membuat invoice Xendit di sisi server. Secret key TIDAK PERNAH dikirim ke
// client. Client hanya mengirim Firebase ID token + serviceId, dan menerima
// invoice_url. Mengganti pemanggilan Xendit langsung dari aplikasi.
//
// Secrets yang dibutuhkan:
//   XENDIT_SECRET_KEY       — secret key Xendit (BARU, rotate dari yang bocor)
//   FIREBASE_PROJECT_ID     — untuk verifikasi ID token
//   SUPABASE_URL            — otomatis tersedia di Edge runtime
//   SUPABASE_SERVICE_ROLE_KEY — untuk update tabel dengan bypass RLS
//   PAYMENT_SUCCESS_REDIRECT / PAYMENT_FAILURE_REDIRECT (opsional)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { corsHeaders, json } from "../_shared/cors.ts";
import { verifyFirebaseToken } from "../_shared/firebaseAuth.ts";

const XENDIT_URL = "https://api.xendit.co/v2/invoices";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // 1. Autentikasi: pastikan pemanggil adalah user login yang sah.
  let user;
  try {
    user = await verifyFirebaseToken(req.headers.get("Authorization"));
  } catch (e) {
    return json({ error: `Unauthorized: ${e.message}` }, 401);
  }

  // 2. Validasi input.
  let serviceId: string;
  try {
    const body = await req.json();
    serviceId = String(body.serviceId ?? "");
    if (!serviceId) return json({ error: "serviceId wajib" }, 400);
  } catch {
    return json({ error: "Body JSON tidak valid" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 3. Ambil service + verifikasi KEPEMILIKAN (cegah IDOR: user hanya boleh
  //    membayar service miliknya sendiri).
  const { data: service, error: svcErr } = await supabase
    .from("services")
    .select("id, user_id, service_cost, status, device, brand, phoneNumber, xendit_invoice_id, payment_url")
    .eq("id", serviceId)
    .maybeSingle();

  if (svcErr) return json({ error: "DB error" }, 500);
  if (!service) return json({ error: "Service tidak ditemukan" }, 404);
  if (service.user_id !== user.uid) return json({ error: "Bukan milik Anda" }, 403);

  if (service.service_cost == null) {
    return json({ error: "Biaya service belum ditentukan admin" }, 409);
  }
  if (service.status === "PAID" || service.status === "PROCESSED") {
    return json({ error: "Service sudah dibayar" }, 409);
  }

  // Idempoten: jika invoice masih aktif, kembalikan yang ada.
  if (service.payment_url && service.xendit_invoice_id) {
    return json({ invoice_url: service.payment_url });
  }

  // 4. Buat invoice Xendit (secret hanya di sisi server).
  const xenditKey = Deno.env.get("XENDIT_SECRET_KEY");
  if (!xenditKey) return json({ error: "Gateway belum dikonfigurasi" }, 500);

  const basicAuth = "Basic " + btoa(`${xenditKey}:`);
  const externalId = `SERVICE-${serviceId}-${Date.now()}`;

  const xenditRes = await fetch(XENDIT_URL, {
    method: "POST",
    headers: { Authorization: basicAuth, "Content-Type": "application/json" },
    body: JSON.stringify({
      external_id: externalId,
      amount: service.service_cost,
      payer_email: `${service.phoneNumber}@servicehponline.com`,
      description: `Pembayaran Service HP Online - ${service.device} ${service.brand}`,
      success_redirect_url:
        Deno.env.get("PAYMENT_SUCCESS_REDIRECT") ?? "servicehponline://payment/success",
      failure_redirect_url:
        Deno.env.get("PAYMENT_FAILURE_REDIRECT") ?? "servicehponline://payment/failed",
      currency: "IDR",
    }),
  });

  if (!xenditRes.ok) {
    const detail = await xenditRes.text();
    console.error("Xendit error", xenditRes.status, detail);
    return json({ error: "Gagal membuat invoice" }, 502);
  }

  const invoice = await xenditRes.json();

  // 5. Simpan invoice id + url (service-role). external_id disimpan untuk
  //    dicocokkan saat webhook masuk.
  await supabase
    .from("services")
    .update({
      xendit_invoice_id: invoice.id,
      xendit_external_id: externalId,
      payment_url: invoice.invoice_url,
      updated_at: new Date().toISOString(),
    })
    .eq("id", serviceId);

  // 6. Balikan HANYA invoice_url — tidak ada secret yang bocor ke client.
  return json({ invoice_url: invoice.invoice_url });
});
