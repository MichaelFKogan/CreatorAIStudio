# Supabase Webhook Setup Instructions

Follow these steps to set up webhooks for your Creator AI Studio app.

## Step 1: Create the Database Table

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project: `inaffymocuppuddsewyq`
3. Navigate to **SQL Editor** in the left sidebar
4. Click **New Query**
5. Copy the entire contents of `Database/pending_jobs_setup.sql` and paste it
6. Click **Run** to execute the SQL

### Verify the Setup

Run these queries to verify everything was created:

```sql
-- Check table exists
SELECT * FROM pending_jobs LIMIT 1;

-- Check RLS is enabled
SELECT relname, relrowsecurity FROM pg_class WHERE relname = 'pending_jobs';

-- Check Realtime is enabled
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'pending_jobs';
```

### Step 1b: Create the User Devices Table (for Push Notifications)

If you use push notifications so users get notified when a job completes:

1. In **SQL Editor**, click **New Query**
2. Copy the entire contents of `Database/user_devices_setup.sql` and paste it
3. Click **Run** to execute the SQL

This creates the `user_devices` table where the app stores each user’s APNs device token (upserted when they sign in or when the token is received).

## Step 2: Set Up Environment Secrets

1. Go to **Project Settings** > **Edge Functions**
2. Scroll to **Edge Function Secrets**
3. Add these secrets:

| Secret Name                | Value                    | Description                                                                             |
| -------------------------- | ------------------------ | --------------------------------------------------------------------------------------- |
| `WEBHOOK_SECRET`           | `your-secret-token-here` | A random string for Runware webhook verification. Generate with: `openssl rand -hex 32` |
| `WAVESPEED_WEBHOOK_SECRET` | (from WaveSpeed API)     | Get this from WaveSpeed API by calling `GET /api/v3/webhook/secret`                     |

### Get WaveSpeed Webhook Secret

```bash
curl --location --request GET 'https://api.wavespeed.ai/api/v3/webhook/secret' \
--header 'Authorization: Bearer YOUR_WAVESPEED_API_KEY'
```

The response will be like: `{"secret": "whsec_xxxxx"}`. Remove the `whsec_` prefix and use the rest as your secret.

## Step 3: Deploy the Webhook Receiver Edge Function

1. Go to **Edge Functions** in the left sidebar
2. Click **Create a new function**
3. Name it: `webhook-receiver`
4. Copy the entire contents of `webhook-receiver.ts` and paste it
5. Click **Deploy**

### Test the Webhook

After deployment, your webhook URL will be:

```
https://inaffymocuppuddsewyq.supabase.co/functions/v1/webhook-receiver
```

Test it with curl:

```bash
curl -X POST 'https://inaffymocuppuddsewyq.supabase.co/functions/v1/webhook-receiver?provider=runware&token=YOUR_WEBHOOK_SECRET' \
-H 'Content-Type: application/json' \
-d '{"taskUUID": "test-123", "status": "completed", "imageURL": "https://example.com/image.jpg"}'

curl -X POST 'https://inaffymocuppuddsewyq.supabase.co/functions/v1/webhook-receiver?provider=runware&token=<Supabase service role key>' \
-H 'Content-Type: application/json' \
-d '{"taskUUID": "test-123", "status": "completed", "imageURL": "https://example.com/image.jpg"}'

curl -X POST 'https://inaffymocuppuddsewyq.supabase.co/functions/v1/webhook-receiver?provider=runware&token=<Supabase service role key>' \
-H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImluYWZmeW1vY3VwcHVkZHNld3lxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjIyMjY5MywiZXhwIjoyMDc3Nzk4NjkzfQ.eR5QZ_Q-5FfU_RlVfC5eOJ83N4zPX8f_j9J_0QX74w' \
-H 'Content-Type: application/json' \
-d '{
  "taskUUID": "test-123",
  "status": "completed",
  "imageURL": "https://example.com/image.jpg"
}'

curl -X POST 'https://inaffymocuppuddsewyq.supabase.co/functions/v1/webhook-receiver?provider=runware&token=<Supabase service role key>' \
-H 'Content-Type: application/json' \
-d '{
  "taskUUID": "test-123",
  "status": "completed",
  "imageURL": "https://example.com/image.jpg"
}'


```

## Step 4: Deploy the Push Notification Edge Function (Optional)

This is optional until you set up APNs:

1. Go to **Edge Functions**
2. Click **Create a new function**
3. Name it: `send-push-notification`
4. Copy the contents of `send-push-notification.ts` and paste it
5. Click **Deploy**

### Push trigger (optional)

The `push_notification_trigger.sql` only sets `notification_sent` on the row so job updates always commit. It does **not** call the Edge Function from the database (to avoid rollbacks). To actually send a push when a job completes, your **webhook-receiver** Edge Function must call `send-push-notification` after it updates `pending_jobs` to completed (using the job’s `device_token` from the row). The source in `Documentation/webhook-receiver.ts` includes this call; redeploy that version if your deployed webhook-receiver doesn’t send push. For a real push to appear on the device, you still need to add APNs secrets and implement the APNs HTTP request in `send-push-notification`.

### APNs Setup (For Future)

When you're ready to enable push notifications:

1. Go to Apple Developer Console
2. Create an APNs Key (Keys > Create a key > Enable APNs)
3. Download the .p8 file
4. Add these secrets to Supabase:
   - `APNS_KEY_ID`: The Key ID shown in Apple Developer Console
   - `APNS_TEAM_ID`: Your Apple Team ID
   - `APNS_KEY`: The contents of your .p8 file
   - `APNS_BUNDLE_ID`: Your app's bundle ID (e.g., `com.yourcompany.CreatorAIStudio`)

## Webhook URLs for API Integration

Use these URLs in your iOS app:

### Runware Webhook URL

```
https://inaffymocuppuddsewyq.supabase.co/functions/v1/webhook-receiver?provider=runware&token=YOUR_WEBHOOK_SECRET
```

### WaveSpeed Webhook URL

```
https://inaffymocuppuddsewyq.supabase.co/functions/v1/webhook-receiver?provider=wavespeed
```

## Troubleshooting

### Check Edge Function Logs

1. Go to **Edge Functions** > Select your function
2. Click **Logs** to see recent invocations

### Common Issues

1. **"Unauthorized" error**: Check your `WEBHOOK_SECRET` matches what you're sending in the token parameter
2. **"Job not found" in logs**: The pending_job record may not have been created yet in the iOS app
3. **RLS errors**: Make sure you're using the service role key in the Edge Function (it's automatic with `SUPABASE_SERVICE_ROLE_KEY`)

## Security Notes

- Never expose your `WEBHOOK_SECRET` in client code
- The secret is only used for verification between the APIs and your Edge Function
- RLS ensures users can only see their own jobs
- The Edge Function uses the service role to bypass RLS when updating job status
