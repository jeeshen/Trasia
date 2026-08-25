import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, stripe-signature",
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

function stripeKey(): string {
  const key = Deno.env.get("STRIPE_SECRET_KEY");
  if (!key || !key.startsWith("sk_test_")) {
    throw new Error("STRIPE_SECRET_KEY must be a Stripe test-mode secret key");
  }
  return key;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function redirectToApp(uri: string): Response {
  return new Response(null, {
    status: 302,
    headers: {
      Location: uri,
      "Cache-Control": "no-store",
    },
  });
}

async function stripeRequest(path: string, options: RequestInit = {}) {
  const response = await fetch(`https://api.stripe.com${path}`, {
    ...options,
    headers: {
      Authorization: `Basic ${btoa(`${stripeKey()}:`)}`,
      ...(options.headers ?? {}),
    },
  });
  const body = await response.json();
  if (!response.ok) {
    throw new Error(body?.error?.message ?? "Stripe request failed");
  }
  return body;
}

function toHex(bytes: ArrayBuffer): string {
  return [...new Uint8Array(bytes)]
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
}

function sameString(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

async function verifyStripeSignature(
  payload: string,
  header: string,
  secret: string,
): Promise<boolean> {
  const fields = header.split(",").map((part) => part.split("=", 2));
  const timestamp = Number(fields.find(([key]) => key === "t")?.[1]);
  const signatures = fields
    .filter(([key]) => key === "v1")
    .map(([, value]) => value);
  if (!timestamp || !signatures.length || Math.abs(Date.now() / 1000 - timestamp) > 300) {
    return false;
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${timestamp}.${payload}`),
  );
  const expected = toHex(digest);
  return signatures.some((signature) => sameString(expected, signature));
}

function adminClient() {
  return createClient(
    supabaseUrl,
    configKey("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEYS"),
  );
}

async function createPaymentIntent(
  req: Request,
  body: Record<string, unknown>,
): Promise<Response> {
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
  if (error || !data.user) {
    return json({ error: "Invalid session" }, 401);
  }

  const amountRm = Number(body?.amount_rm);
  if (![20, 50].includes(amountRm)) {
    return json({ error: "Top-up amount must be RM20 or RM50" }, 400);
  }

  const amountCents = amountRm * 100;
  const topupId = crypto.randomUUID();
  const admin = adminClient();
  const { error: insertError } = await admin.from("credit_topups").insert({
    id: topupId,
    user_id: data.user.id,
    amount_cents: amountCents,
    currency: "myr",
    status: "pending",
  });
  if (insertError) {
    return json({ error: "Unable to create top-up" }, 500);
  }

  const params = new URLSearchParams();
  params.set("amount", String(amountCents));
  params.set("currency", "myr");
  params.set("payment_method_types[0]", "card");
  params.set("metadata[topup_id]", topupId);
  params.set("metadata[user_id]", data.user.id);
  params.set("description", `RM${amountRm} Trasia Hub-Pool credit`);

  try {
    const intent = await stripeRequest("/v1/payment_intents", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: params,
    });
    const { error: updateError } = await admin
      .from("credit_topups")
      .update({ stripe_payment_intent_id: intent.id })
      .eq("id", topupId);
    if (updateError) throw updateError;
    return json({
      payment_intent_id: intent.id,
      payment_intent_client_secret: intent.client_secret,
    });
  } catch (error) {
    await admin.from("credit_topups").update({ status: "failed" }).eq("id", topupId);
    return json({ error: error instanceof Error ? error.message : "Stripe payment failed" }, 502);
  }
}

async function confirmPaymentIntent(
  req: Request,
  body: Record<string, unknown>,
): Promise<Response> {
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return json({ error: "Authentication required" }, 401);
  }

  const accessToken = authorization.slice("Bearer ".length);
  const userClient = createClient(
    supabaseUrl,
    configKey("SUPABASE_ANON_KEY", "SUPABASE_PUBLISHABLE_KEYS"),
  );
  const { data: userData, error: userError } = await userClient.auth.getUser(accessToken);
  if (userError || !userData.user) {
    return json({ error: "Invalid session" }, 401);
  }

  const paymentIntentId = String(body.payment_intent_id ?? "");
  if (!/^pi_[A-Za-z0-9]+$/.test(paymentIntentId)) {
    return json({ error: "Invalid payment intent" }, 400);
  }

  const admin = adminClient();
  const { data: topup, error: topupError } = await admin
    .from("credit_topups")
    .select("id,user_id,amount_cents,currency,status,stripe_payment_intent_id")
    .eq("user_id", userData.user.id)
    .eq("stripe_payment_intent_id", paymentIntentId)
    .maybeSingle();
  if (topupError) return json({ error: "Unable to find top-up" }, 500);
  if (!topup) return json({ error: "Top-up not found" }, 404);
  if (topup.status === "paid") return json({ received: true, status: "paid" });

  try {
    const payment = await stripeRequest(
      `/v1/payment_intents/${encodeURIComponent(paymentIntentId)}`,
    );
    if (
      payment.id !== paymentIntentId ||
      payment.metadata?.topup_id !== topup.id ||
      payment.metadata?.user_id !== userData.user.id ||
      payment.amount !== topup.amount_cents ||
      payment.currency !== topup.currency ||
      payment.status !== "succeeded"
    ) {
      return json({ received: true, status: payment.status ?? "pending" });
    }

    const { error: completeError } = await admin.rpc("complete_credit_topup", {
      p_topup_id: topup.id,
      p_session_id: `payment_intent:${payment.id}`,
      p_payment_intent_id: payment.id,
    });
    if (completeError) return json({ error: "Unable to apply credit" }, 500);
    return json({ received: true, status: "paid" });
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : "Unable to verify payment" },
      502,
    );
  }
}

async function createCheckout(
  req: Request,
  body: Record<string, unknown>,
): Promise<Response> {
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
  if (error || !data.user) {
    return json({ error: "Invalid session" }, 401);
  }

  const amountRm = Number(body?.amount_rm);
  if (![20, 50].includes(amountRm)) {
    return json({ error: "Top-up amount must be RM20 or RM50" }, 400);
  }

  const amountCents = amountRm * 100;
  const topupId = crypto.randomUUID();
  const admin = adminClient();
  const { error: insertError } = await admin.from("credit_topups").insert({
    id: topupId,
    user_id: data.user.id,
    amount_cents: amountCents,
    currency: "myr",
    status: "pending",
  });
  if (insertError) {
    return json({ error: "Unable to create top-up" }, 500);
  }

  const params = new URLSearchParams();
  params.set("mode", "payment");
  params.set("origin_context", "mobile_app");
  params.set("line_items[0][price_data][currency]", "myr");
  params.set("line_items[0][price_data][unit_amount]", String(amountCents));
  params.set("line_items[0][price_data][product_data][name]", "Trasia Hub-Pool credit");
  params.set("line_items[0][price_data][product_data][description]", `RM${amountRm} wallet top-up`);
  params.set("line_items[0][quantity]", "1");
  params.set("payment_method_types[0]", "card");
  params.set("client_reference_id", data.user.id);
  params.set("metadata[topup_id]", topupId);
  params.set("metadata[user_id]", data.user.id);
  params.set("success_url", `${supabaseUrl}/functions/v1/stripe-topup?session_id={CHECKOUT_SESSION_ID}`);
  params.set("cancel_url", `${supabaseUrl}/functions/v1/stripe-topup?cancelled=1`);

  try {
    const session = await stripeRequest("/v1/checkout/sessions", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: params,
    });
    const { error: updateError } = await admin
      .from("credit_topups")
      .update({ stripe_session_id: session.id })
      .eq("id", topupId);
    if (updateError) throw updateError;
    return json({ checkout_url: session.url });
  } catch (error) {
    await admin.from("credit_topups").update({ status: "failed" }).eq("id", topupId);
    return json({ error: error instanceof Error ? error.message : "Stripe checkout failed" }, 502);
  }
}

async function handleWebhook(req: Request): Promise<Response> {
  const payload = await req.text();
  const signature = req.headers.get("stripe-signature");
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!signature || !webhookSecret || !(await verifyStripeSignature(payload, signature, webhookSecret))) {
    return json({ error: "Invalid Stripe signature" }, 400);
  }

  const event = JSON.parse(payload);
  const isCheckoutEvent = event.type === "checkout.session.completed" ||
    event.type === "checkout.session.async_payment_succeeded";
  const isPaymentIntentEvent = event.type === "payment_intent.succeeded";
  if (!isCheckoutEvent && !isPaymentIntentEvent) {
    return json({ received: true });
  }

  const payment = event.data.object;
  const topupId = payment.metadata?.topup_id;
  if (!topupId) return json({ received: true });
  if (isCheckoutEvent && payment.payment_status !== "paid") return json({ received: true });
  if (isPaymentIntentEvent && payment.status !== "succeeded") return json({ received: true });

  const { error } = await adminClient().rpc("complete_credit_topup", {
    p_topup_id: topupId,
    p_session_id: isCheckoutEvent ? payment.id : `payment_intent:${payment.id}`,
    p_payment_intent_id: isCheckoutEvent ? payment.payment_intent ?? "" : payment.id,
  });
  if (error) {
    return json({ error: "Unable to apply credit" }, 500);
  }
  return json({ received: true });
}

async function resultPage(req: Request): Promise<Response> {
  const url = new URL(req.url);
  if (url.searchParams.has("cancelled")) {
    return redirectToApp("trasia://stripe-cancel");
  }
  const sessionId = url.searchParams.get("session_id");
  if (!sessionId || !sessionId.startsWith("cs_")) {
    return new Response("Invalid checkout session.", { status: 400 });
  }
  try {
    const session = await stripeRequest(`/v1/checkout/sessions/${encodeURIComponent(sessionId)}`);
    const appUrl = new URL("trasia://stripe-success");
    appUrl.searchParams.set("session_id", sessionId);
    appUrl.searchParams.set("status", session.payment_status === "paid" ? "paid" : "pending");
    return redirectToApp(appUrl.toString());
  } catch (_) {
    return new Response("Unable to check payment status.", { status: 502 });
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    if (req.method === "GET") return await resultPage(req);
    if (req.headers.has("stripe-signature")) return await handleWebhook(req);
    if (req.method === "POST") {
      const body = await req.json() as Record<string, unknown>;
      if (body.payment_sheet === true) return await createPaymentIntent(req, body);
      if (body.confirm_payment_intent === true) return await confirmPaymentIntent(req, body);
      return await createCheckout(req, body);
    }
    return json({ error: "Method not allowed" }, 405);
  } catch (error) {
    console.error(error);
    return json({ error: "Unexpected server error" }, 500);
  }
});
