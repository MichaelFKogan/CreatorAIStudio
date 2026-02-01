// ============================================
// PUSH NOTIFICATION EDGE FUNCTION (APNs)
// ============================================
// Deploy in Supabase: Edge Functions > send-push-notification
//
// Required secrets (Supabase Edge Function secrets):
//   APNS_KEY_ID    - APNs key ID from Apple Developer
//   APNS_TEAM_ID   - Apple Team ID
//   APNS_KEY       - Full contents of your .p8 file (PEM)
//   APNS_BUNDLE_ID - App bundle ID (e.g. com.runspeedai....)
//
// Optional: APNS_USE_SANDBOX - set to "true" for dev/sandbox (default), "false" for production

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { SignJWT, importPKCS8 } from "npm:jose@4.14.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface PushPayload {
  device_token: string;
  job_id: string;
  job_type: "image" | "video";
  title: string;
  body: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: PushPayload = await req.json();

    console.log(`[Push] Sending notification for job: ${payload.job_id}`);

    const apnsKeyId = Deno.env.get("APNS_KEY_ID");
    const apnsTeamId = Deno.env.get("APNS_TEAM_ID");
    const apnsKey = Deno.env.get("APNS_KEY");
    const apnsBundleId = Deno.env.get("APNS_BUNDLE_ID");

    if (!apnsKeyId || !apnsTeamId || !apnsKey || !apnsBundleId) {
      console.log("[Push] APNs not configured - skipping");
      return new Response(
        JSON.stringify({ status: "skipped", reason: "APNs not configured" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Sandbox for dev builds, production for TestFlight/App Store
    const useSandbox =
      (Deno.env.get("APNS_USE_SANDBOX") ?? "true").toLowerCase() === "true";
    const apnsHost = useSandbox
      ? "api.sandbox.push.apple.com"
      : "api.push.apple.com";
    const apnsUrl = `https://${apnsHost}/3/device/${payload.device_token}`;

    // 1. Import .p8 key and sign JWT (ES256)
    const privateKey = await importPKCS8(apnsKey, "ES256");
    const now = Math.floor(Date.now() / 1000);
    const jwt = await new SignJWT({})
      .setProtectedHeader({ alg: "ES256", kid: apnsKeyId })
      .setIssuer(apnsTeamId)
      .setIssuedAt(now)
      .setExpirationTime(now + 3600)
      .sign(privateKey);

    // 2. Build APNs payload
    const apnsPayload = {
      aps: {
        alert: { title: payload.title, body: payload.body },
        sound: "default",
        badge: 1,
        "mutable-content": 1,
      },
      job_id: payload.job_id,
      job_type: payload.job_type,
    };

    // 3. POST to APNs
    const response = await fetch(apnsUrl, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": apnsBundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify(apnsPayload),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`[Push] APNs error ${response.status}:`, errorText);
      return new Response(
        JSON.stringify({
          status: "error",
          reason: "APNs rejected",
          details: errorText,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`[Push] Delivered for job: ${payload.job_id}`);
    return new Response(
      JSON.stringify({ status: "ok", message: "Push notification sent" }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("[Push] Error:", error);
    return new Response(
      JSON.stringify({ error: String(error?.message ?? error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
