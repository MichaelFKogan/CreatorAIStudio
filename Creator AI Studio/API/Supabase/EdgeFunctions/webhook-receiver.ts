// ============================================
// WEBHOOK RECEIVER EDGE FUNCTION
// ============================================
// Deploy this in Supabase Dashboard:
// Dashboard > Edge Functions > Create a new function
// Name: webhook-receiver
// Copy/paste this code

// Webhook Secret: f2fa291c970a1bcf0310e2aecc1189005ee601e0dec33697e3704681fb021728
// Wavespeed Webhook Secret: whsec_5fb599c5eca75157f34d7da3efc734a3422a4b5ae0e6bbf753a09b82e6caebdf
// Supabase URL: https://inaffymocuppuddsewyq.supabase.co
// Supabase Service Role Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImluYWZmeW1vY3VwcHVkZHNld3lxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjIyMjY5MywiZXhwIjoyMDc3Nzk4NjkzfQ.eR5QZ_Q-5FfU_RlVfC5eOJ83N4zPX8f_j9J_0QX74w

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

async function computeHmac(secret: string, payload: string) {
  const keyData = new TextEncoder().encode(secret);
  const payloadData = new TextEncoder().encode(payload);

  const key = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign("HMAC", key, payloadData);

  // convert ArrayBuffer to hex
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// CORS headers for preflight requests
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, webhook-id, webhook-timestamp, webhook-signature",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client with service role (bypasses RLS)
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const webhookSecret =
      Deno.env.get("WEBHOOK_SECRET") ||
      "f2fa291c970a1bcf0310e2aecc1189005ee601e0dec33697e3704681fb021728";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Parse URL to get provider from query params
    const url = new URL(req.url);
    const provider = url.searchParams.get("provider") || "unknown";
    const token = url.searchParams.get("token");

    console.log(`[Webhook] Received callback from provider: ${provider}`);

    // Get raw body for signature verification
    const rawBody = await req.text();
    const payload = JSON.parse(rawBody);

    console.log(
      `[Webhook] Payload:`,
      JSON.stringify(payload).substring(0, 500)
    );

    // ========================================
    // VERIFY WEBHOOK AUTHENTICITY
    // ========================================

    if (provider === "wavespeed") {
      // WaveSpeed uses HMAC-SHA256 signature verification
      const webhookId = req.headers.get("webhook-id");
      const webhookTimestamp = req.headers.get("webhook-timestamp");
      const webhookSignature = req.headers.get("webhook-signature");

      if (webhookId && webhookTimestamp && webhookSignature) {
        // Get the WaveSpeed webhook secret from environment
        const wavespeedSecret = Deno.env.get(
          "5fb599c5eca75157f34d7da3efc734a3422a4b5ae0e6bbf753a09b82e6caebdf"
        );

        if (wavespeedSecret) {
          // Construct signature payload
          const signaturePayload = `${webhookId}.${webhookTimestamp}.${rawBody}`;

          // Compute HMAC-SHA256
          const computedSignature = await computeHmac(
            wavespeedSecret,
            signaturePayload
          );

          // Extract signature from header (format: v3,<hex_signature>)
          const expectedSignature = webhookSignature.split(",")[1];

          if (computedSignature !== expectedSignature) {
            console.error("[Webhook] WaveSpeed signature verification failed");
            // Continue anyway for now, but log the issue
          } else {
            console.log("[Webhook] WaveSpeed signature verified successfully");
          }
        }
      }
    } else if (provider === "runware") {
      // Runware uses token-based verification
      if (token && token !== webhookSecret) {
        console.error("[Webhook] Runware token verification failed");
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    // ========================================
    // EXTRACT DATA FROM PAYLOAD
    // ========================================

    let taskId: string;
    let status: string;
    let resultUrl: string | null = null;
    let errorMessage: string | null = null;

    if (provider === "runware") {
      // Runware payload structure
      // Can be array of responses or single object
      const data = Array.isArray(payload)
        ? payload.find((p: any) => p.taskUUID)
        : payload;

      if (data?.data && Array.isArray(data.data)) {
        // Response wrapped in data array
        const item = data.data[0];
        taskId = item.taskUUID || item.taskUuid || item.task_uuid;
        resultUrl =
          item.videoURL ||
          item.videoUrl ||
          item.video_url ||
          item.imageURL ||
          item.imageUrl ||
          item.image_url;
        status = resultUrl ? "completed" : item.status || "processing";
        errorMessage = data.error || item.error;
      } else {
        taskId = data?.taskUUID || data?.taskUuid || data?.task_uuid;
        resultUrl =
          data?.videoURL ||
          data?.videoUrl ||
          data?.video_url ||
          data?.imageURL ||
          data?.imageUrl ||
          data?.image_url;
        status = resultUrl ? "completed" : data?.status || "processing";
        errorMessage = data?.error;
      }

      console.log(
        `[Webhook] Runware - taskId: ${taskId}, status: ${status}, resultUrl: ${resultUrl?.substring(
          0,
          50
        )}...`
      );
    } else if (provider === "wavespeed") {
      // WaveSpeed payload structure
      taskId = payload.id;
      status =
        payload.status === "completed"
          ? "completed"
          : payload.status === "failed"
          ? "failed"
          : "processing";
      resultUrl = payload.outputs?.[0] || null;
      errorMessage = payload.error || null;

      console.log(
        `[Webhook] WaveSpeed - taskId: ${taskId}, status: ${status}, resultUrl: ${resultUrl?.substring(
          0,
          50
        )}...`
      );
    } else {
      console.error(`[Webhook] Unknown provider: ${provider}`);
      return new Response(JSON.stringify({ error: "Unknown provider" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!taskId) {
      console.error("[Webhook] No task ID found in payload");
      return new Response(JSON.stringify({ error: "No task ID found" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ========================================
    // UPDATE DATABASE
    // ========================================

    const updateData: Record<string, any> = {
      status: status,
      updated_at: new Date().toISOString(),
    };

    if (resultUrl) {
      updateData.result_url = resultUrl;
      updateData.completed_at = new Date().toISOString();
    }

    if (errorMessage) {
      updateData.error_message = errorMessage;
      updateData.completed_at = new Date().toISOString();
    }

    console.log(`[Webhook] Updating pending_jobs for task_id: ${taskId}`);

    const { data: updatedJob, error: dbError } = await supabase
      .from("pending_jobs")
      .update(updateData)
      .eq("task_id", taskId)
      .select()
      .single();

    if (dbError) {
      console.error(`[Webhook] Database error:`, dbError);

      // If job not found, it might have been cleaned up or never created
      if (dbError.code === "PGRST116") {
        console.log(
          `[Webhook] Job not found in database, may have been cleaned up`
        );
        return new Response(
          JSON.stringify({ status: "ok", message: "Job not found" }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      return new Response(
        JSON.stringify({ error: "Database error", details: dbError.message }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`[Webhook] Successfully updated job:`, updatedJob);

    // ========================================
    // TRIGGER PUSH NOTIFICATION (if needed)
    // ========================================

    if (
      status === "completed" &&
      updatedJob?.device_token &&
      !updatedJob?.notification_sent
    ) {
      // Call the send-push-notification Edge Function
      try {
        const pushResponse = await fetch(
          `${supabaseUrl}/functions/v1/send-push-notification`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${supabaseServiceKey}`,
            },
            body: JSON.stringify({
              device_token: updatedJob.device_token,
              job_id: updatedJob.id,
              job_type: updatedJob.job_type,
              title:
                updatedJob.job_type === "video"
                  ? "Video Ready!"
                  : "Image Ready!",
              body: "Your AI generation is complete. Tap to view.",
            }),
          }
        );

        if (pushResponse.ok) {
          // Mark notification as sent
          await supabase
            .from("pending_jobs")
            .update({ notification_sent: true })
            .eq("id", updatedJob.id);

          console.log(`[Webhook] Push notification sent successfully`);
        }
      } catch (pushError) {
        console.error(`[Webhook] Failed to send push notification:`, pushError);
        // Don't fail the webhook for push notification errors
      }
    }

    return new Response(JSON.stringify({ status: "ok", job: updatedJob }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[Webhook] Unexpected error:", error);
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        details: error.message,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
