import { createRemoteJWKSet, jwtVerify } from "https://esm.sh/jose@5.9.6";

// Kunci publik Firebase (format x509 → JWKS mirror yang dipelihara Google).
const JWKS = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

export interface FirebaseUser {
  uid: string;
  email?: string;
}

/**
 * Verifikasi Firebase ID token dari header Authorization: Bearer <token>.
 * Melempar Error bila tidak valid. Mengembalikan uid (Firebase) pemilik token.
 *
 * FIREBASE_PROJECT_ID wajib diset sebagai secret Edge Function.
 */
export async function verifyFirebaseToken(
  authHeader: string | null,
): Promise<FirebaseUser> {
  if (!authHeader?.startsWith("Bearer ")) {
    throw new Error("Missing bearer token");
  }
  const token = authHeader.slice("Bearer ".length).trim();

  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  if (!projectId) throw new Error("FIREBASE_PROJECT_ID not configured");

  const { payload } = await jwtVerify(token, JWKS, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
  });

  const uid = (payload.sub ?? payload.user_id) as string | undefined;
  if (!uid) throw new Error("Token tanpa subject (uid)");

  return { uid, email: payload.email as string | undefined };
}
