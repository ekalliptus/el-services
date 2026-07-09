// Edge Function: firebase-bridge
// Menjembatani autentikasi Firebase -> Supabase. Client mengirim Firebase ID
// token; fungsi memverifikasinya lalu MENERBITKAN Supabase access token
// (di-sign dengan SUPABASE_JWT_SECRET) yang membawa claim firebase_uid.
//
// Setelah client memanggil supabase.auth.setSession(...), auth.uid() menjadi
// valid dan RLS bisa memfilter services.user_id = firebase_uid pemanggil —
// menutup IDOR (H-2) tanpa mengorbankan realtime.
//
// Secrets:
//   FIREBASE_PROJECT_ID
//   SUPABASE_JWT_SECRET   (Project Settings -> API -> JWT Secret)
//
// Deploy: supabase functions deploy firebase-bridge --no-verify-jwt

import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";
import { corsHeaders, json } from "../_shared/cors.ts";
import { verifyFirebaseToken } from "../_shared/firebaseAuth.ts";

// UUID v5 deterministik dari firebase uid agar 'sub' stabil per user.
async function uuidV5FromUid(uid: string): Promise<string> {
  // Namespace tetap (acak sekali, boleh diganti asal konsisten).
  const namespace = "6f9619ff-8b86-d011-b42d-00cf4fc964ff";
  const data = new TextEncoder().encode(namespace + uid);
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-1", data));
  const b = hash.slice(0, 16);
  b[6] = (b[6] & 0x0f) | 0x50; // versi 5
  b[8] = (b[8] & 0x3f) | 0x80; // varian
  const hex = [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${
    hex.slice(16, 20)
  }-${hex.slice(20)}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  let user;
  try {
    user = await verifyFirebaseToken(req.headers.get("Authorization"));
  } catch (e) {
    return json({ error: `Unauthorized: ${e.message}` }, 401);
  }

  const secret = Deno.env.get("SUPABASE_JWT_SECRET");
  if (!secret) return json({ error: "JWT secret belum dikonfigurasi" }, 500);

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );

  const sub = await uuidV5FromUid(user.uid);
  const now = getNumericDate(0);
  const exp = getNumericDate(60 * 60); // 1 jam

  const accessToken = await create(
    { alg: "HS256", typ: "JWT" },
    {
      sub,
      aud: "authenticated",
      role: "authenticated",
      iat: now,
      exp,
      email: user.email ?? "",
      // Claim yang dipakai RLS untuk mencocokkan services.user_id.
      app_metadata: { provider: "firebase", firebase_uid: user.uid },
      user_metadata: { firebase_uid: user.uid },
    },
    key,
  );

  // Client memakai token ini sebagai access & refresh (refresh via re-bridge).
  return json({ access_token: accessToken, expires_in: 3600, sub });
});
