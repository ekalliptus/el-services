// Edge Function: xendit-webhook
// SATU-SATUNYA tempat status pembayaran services boleh berubah menjadi
// PAID/PROCESSED. Dipanggil oleh Xendit (server-to-server), diverifikasi
// dengan x-callback-token. Client TIDAK boleh lagi menulis services.status
// (dikunci oleh RLS).
//
// Konfigurasi di dashboard Xendit: set Invoice callback URL ke
//   https://<project-ref>.functions.supabase.co/xendit-webhook
// dan salin Verification Token ke secret XENDIT_CALLBACK_TOKEN.
//
// Secrets:
//   XENDIT_CALLBACK_TOKEN     — verification token dari dashboard Xendit
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY
//
// Deploy dengan --no-verify-jwt agar Xendit (tanpa JWT Supabase) bisa memanggil;
// keamanan dijamin oleh x-callback-token.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { json } from "../_shared/cors.ts";

// Peta status Xendit → status internal aplikasi.
function mapStatus(xenditStatus: string): string | null {
  switch (xenditStatus) {
    case "PAID":
    case "SETTLED":
      return "PROCESSED"; // pembayaran sukses → service masuk antrian proses
    case "EXPIRED":
      return "PENDING"; // invoice kadaluarsa, biarkan user buat ulang
    default:
      return null; // status lain: abaikan
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // 1. Verifikasi token callback (timing-safe-ish via panjang tetap).
  const expected = Deno.env.get("XENDIT_CALLBACK_TOKEN");
  const got = req.headers.get("x-callback-token");
  if (!expected || !got || got !== expected) {
    return json({ error: "Invalid callback token" }, 401);
  }

  let event: Record<string, unknown>;
  try {
    event = await req.json();
  } catch {
    return json({ error: "Body tidak valid" }, 400);
  }

  const invoiceId = event.id as string | undefined;
  const externalId = event.external_id as string | undefined;
  const xenditStatus = event.status as string | undefined;
  if (!xenditStatus || (!invoiceId && !externalId)) {
    return json({ error: "Payload tidak lengkap" }, 400);
  }

  const internalStatus = mapStatus(xenditStatus);
  if (!internalStatus) return json({ received: true, ignored: xenditStatus });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 2. Cocokkan invoice ke service. Utamakan external_id (kita yang buat),
  //    fallback ke xendit_invoice_id.
  const match = externalId
    ? { col: "xendit_external_id", val: externalId }
    : { col: "xendit_invoice_id", val: invoiceId! };

  const { data: svc } = await supabase
    .from("services")
    .select("id, status")
    .eq(match.col, match.val)
    .maybeSingle();

  if (!svc) {
    // 200 agar Xendit tidak retry selamanya untuk invoice yang tak dikenal.
    return json({ received: true, matched: false });
  }

  // 3. Idempoten: jangan turunkan status yang sudah final.
  if (svc.status === "PROCESSED" || svc.status === "PAID") {
    return json({ received: true, already: svc.status });
  }

  await supabase
    .from("services")
    .update({ status: internalStatus, updated_at: new Date().toISOString() })
    .eq("id", svc.id);

  return json({ received: true, status: internalStatus });
});
