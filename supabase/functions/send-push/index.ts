import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;

function configKey(directName: string, mapName: string): string {
  const direct = Deno.env.get(directName);
  if (direct) return direct;
  const values = Deno.env.get(mapName);
  if (values) {
    const parsed = JSON.parse(values) as Record<string, string>;
    if (parsed.default) return parsed.default;
  }
  throw new Error(`Missing ${directName}`);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function base64Url(value: string | Uint8Array): string {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function privateKeyBytes(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/\\n/g, "\n")
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

async function firebaseAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    privateKeyBytes(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const body = await response.json();
  if (!response.ok || !body.access_token) {
    throw new Error(body.error_description ?? "Unable to authenticate with Firebase");
  }
  return body.access_token;
}

async function sendMessage(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  type: string,
): Promise<Response> {
  return fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json; UTF-8",
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data: { type },
        android: { priority: "high" },
      },
    }),
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authorization = req.headers.get("Authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) {
      return json({ error: "Authentication required" }, 401);
    }
    const accessToken = authorization.slice("Bearer ".length);
    const userClient = createClient(
      supabaseUrl,
      configKey("SUPABASE_ANON_KEY", "SUPABASE_PUBLISHABLE_KEYS"),
    );
    const { data, error } = await userClient.auth.getUser(accessToken);
    if (error || !data.user) return json({ error: "Invalid session" }, 401);

    const body = await req.json() as Record<string, unknown>;
    const admin = createClient(
      supabaseUrl,
      configKey("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEYS"),
    );
    const action = String(body.action ?? "send");
    if (action === "register" || action === "unregister") {
      const token = String(body.token ?? "").trim();
      if (token.length < 20 || token.length > 4096) {
        return json({ error: "Invalid push token" }, 400);
      }
      if (action === "register") {
        const platform = String(body.platform ?? "unknown").slice(0, 32);
        const { error: registrationError } = await admin.from("push_tokens").upsert({
          token,
          user_id: data.user.id,
          platform,
          updated_at: new Date().toISOString(),
        }, { onConflict: "token" });
        if (registrationError) return json({ error: "Unable to register push token" }, 500);
        return json({ registered: true });
      }
      const { error: removalError } = await admin
        .from("push_tokens")
        .delete()
        .eq("token", token)
        .eq("user_id", data.user.id);
      if (removalError) return json({ error: "Unable to unregister push token" }, 500);
      return json({ unregistered: true });
    }
    if (action !== "send") return json({ error: "Invalid action" }, 400);

    const title = String(body?.title ?? "Trasia notification").slice(0, 80);
    const message = String(body?.body ?? "").slice(0, 240);
    const type = String(body?.type ?? "car_pool").slice(0, 40);
    if (!message) return json({ error: "Notification body is required" }, 400);

    const { data: tokens, error: tokenError } = await admin
      .from("push_tokens")
      .select("token")
      .eq("user_id", data.user.id);
    if (tokenError) return json({ error: "Unable to load push tokens" }, 500);
    if (!tokens?.length) return json({ sent: 0 });

    const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "") as Record<string, string>;
    const fcmAccessToken = await firebaseAccessToken(serviceAccount);
    let sent = 0;
    for (const row of tokens) {
      const token = row.token as string;
      const response = await sendMessage(
        fcmAccessToken,
        serviceAccount.project_id,
        token,
        title,
        message,
        type,
      );
      if (response.ok) {
        sent += 1;
      } else if (response.status === 400 || response.status === 404) {
        await admin.from("push_tokens").delete().eq("user_id", data.user.id).eq("token", token);
      }
    }
    return json({ sent });
  } catch (error) {
    console.error(error);
    return json({ error: "Push notification failed" }, 500);
  }
});
