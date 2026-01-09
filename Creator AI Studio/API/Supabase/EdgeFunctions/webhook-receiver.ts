// ============================================
// WEBHOOK RECEIVER EDGE FUNCTION
// ============================================
// Deploy this in Supabase Dashboard:
// Dashboard > Edge Functions > Create a new function
// Name: webhook-receiver
// Copy/paste this code

// Configuration Notes:
// - Webhook Secret: Set via WEBHOOK_SECRET environment variable in Supabase
// - WaveSpeed Webhook Secret: Set via WAVESPEED_WEBHOOK_SECRET environment variable (if using WaveSpeed)
// - Supabase URL: Set via SUPABASE_URL environment variable
// - Supabase Service Role Key: Set via SUPABASE_SERVICE_ROLE_KEY environment variable
//
// IMPORTANT: Never hardcode secrets in this file. Use Supabase Edge Function secrets.

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
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const webhookSecret = Deno.env.get("WEBHOOK_SECRET");

    if (!supabaseUrl) {
      throw new Error("SUPABASE_URL environment variable is required");
    }
    if (!supabaseServiceKey) {
      throw new Error(
        "SUPABASE_SERVICE_ROLE_KEY environment variable is required"
      );
    }
    if (!webhookSecret) {
      throw new Error("WEBHOOK_SECRET environment variable is required");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Parse URL to get provider from query params
    const url = new URL(req.url);
    const provider = url.searchParams.get("provider") || "unknown";
    const token = url.searchParams.get("token");

    console.log(`[Webhook] ========================================`);
    console.log(`[Webhook] Received ${req.method} request`);
    console.log(`[Webhook] URL: ${req.url}`);
    console.log(`[Webhook] Provider from query: ${provider}`);
    console.log(
      `[Webhook] Headers:`,
      Object.fromEntries(req.headers.entries())
    );

    // Get raw body for signature verification
    const rawBody = await req.text();
    const payload = JSON.parse(rawBody);

    console.log(
      `[Webhook] Payload (first 1000 chars):`,
      JSON.stringify(payload).substring(0, 1000)
    );

    // Auto-detect provider from payload structure if not in query params
    let detectedProvider = provider;
    if (provider === "unknown") {
      // Check for fal.ai structure: has request_id/gateway_request_id and status
      if (
        (payload.request_id ||
          payload.requestId ||
          payload.gateway_request_id) &&
        (payload.status === "OK" || payload.status === "ERROR")
      ) {
        detectedProvider = "falai";
        console.log(
          `[Webhook] Auto-detected provider as falai from payload structure`
        );
      }
      // Check for Runware structure: has taskUUID
      else if (
        payload.taskUUID ||
        payload.task_uuid ||
        payload.data?.[0]?.taskUUID
      ) {
        detectedProvider = "runware";
        console.log(
          `[Webhook] Auto-detected provider as runware from payload structure`
        );
      }
      // Check for WaveSpeed structure: has id
      else if (
        payload.id &&
        (payload.status === "completed" || payload.status === "failed")
      ) {
        detectedProvider = "wavespeed";
        console.log(
          `[Webhook] Auto-detected provider as wavespeed from payload structure`
        );
      }
    }

    // Use detected provider if we auto-detected one
    const finalProvider =
      detectedProvider !== "unknown" ? detectedProvider : provider;
    console.log(`[Webhook] Using provider: ${finalProvider}`);

    // ========================================
    // VERIFY WEBHOOK AUTHENTICITY
    // ========================================

    if (finalProvider === "wavespeed") {
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
    } else if (finalProvider === "runware") {
      // Runware uses token-based verification
      if (token && token !== webhookSecret) {
        console.error("[Webhook] Runware token verification failed");
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    } else if (finalProvider === "falai") {
      // Fal.ai uses token-based verification (same as Runware)
      if (token && token !== webhookSecret) {
        console.error("[Webhook] Fal.ai token verification failed");
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

    if (finalProvider === "runware") {
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
    } else if (finalProvider === "wavespeed") {
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
    } else if (finalProvider === "falai") {
      // Fal.ai webhook payload structure
      // Format: { request_id, gateway_request_id, status, payload, error }
      // status can be "OK" or "ERROR"
      // payload contains the result: { video: { url: "...", ... } }

      console.log(
        `[Webhook] Fal.ai - Full payload:`,
        JSON.stringify(payload, null, 2)
      );
      console.log(
        `[Webhook] Fal.ai - Payload keys:`,
        Object.keys(payload).join(", ")
      );

      // Try multiple possible field names for request ID
      taskId =
        payload.request_id ||
        payload.requestId ||
        payload.gateway_request_id ||
        payload.gatewayRequestId ||
        payload.id ||
        payload.requestId ||
        (payload.payload && payload.payload.request_id) ||
        (payload.payload && payload.payload.requestId);

      console.log(
        `[Webhook] Fal.ai - Extracted taskId: ${taskId || "NOT FOUND"}`
      );
      if (!taskId) {
        console.error(
          `[Webhook] Fal.ai - Could not find taskId in payload. Available keys:`,
          Object.keys(payload)
        );
      }
      console.log(`[Webhook] Fal.ai - Status: ${payload.status}`);
      console.log(`[Webhook] Fal.ai - Has payload: ${!!payload.payload}`);
      console.log(
        `[Webhook] Fal.ai - Payload keys: ${
          payload.payload ? Object.keys(payload.payload).join(", ") : "none"
        }`
      );

      // Check status - fal.ai uses "OK" for success, "ERROR" for failure
      if (payload.status === "OK") {
        // For video, the payload structure is: { video: { url: "...", ... } }
        if (payload.payload?.video?.url) {
          status = "completed";
          resultUrl = payload.payload.video.url;
          errorMessage = null;
          console.log(`[Webhook] Fal.ai - Video URL found: ${resultUrl}`);
        } else {
          // Check if payload structure is different
          console.log(
            `[Webhook] Fal.ai - Payload structure:`,
            JSON.stringify(payload.payload, null, 2)
          );
          // Try alternative structure - maybe video is at top level?
          if (payload.video?.url) {
            status = "completed";
            resultUrl = payload.video.url;
            errorMessage = null;
            console.log(
              `[Webhook] Fal.ai - Video URL found at top level: ${resultUrl}`
            );
          } else {
            status = "processing";
            resultUrl = null;
            errorMessage = null;
            console.log(
              `[Webhook] Fal.ai - Status OK but no video URL found, marking as processing`
            );
          }
        }
      } else if (payload.status === "ERROR") {
        status = "failed";
        errorMessage =
          payload.error || payload.payload?.detail || "Video generation failed";
        resultUrl = null;
        console.log(`[Webhook] Fal.ai - Error: ${errorMessage}`);
      } else if (
        payload.status === "IN_PROGRESS" ||
        payload.status === "IN_QUEUE"
      ) {
        status = "processing";
        resultUrl = null;
        errorMessage = null;
        console.log(`[Webhook] Fal.ai - Still processing`);
      } else {
        // Default to processing if status is unclear
        status = "processing";
        resultUrl = null;
        errorMessage = null;
        console.log(
          `[Webhook] Fal.ai - Unknown status: ${payload.status}, defaulting to processing`
        );
      }

      console.log(
        `[Webhook] Fal.ai - Final: taskId: ${taskId}, status: ${status}, resultUrl: ${resultUrl?.substring(
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
