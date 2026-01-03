# Backend Proxy Implementation Guide

This guide explains how to build a secure backend proxy using Supabase Edge Functions to protect your API keys.

## Overview

Instead of calling Runware/WaveSpeed APIs directly from your iOS app, you'll:
1. Call your Supabase Edge Function
2. Edge Function calls Runware/WaveSpeed with your API keys
3. Edge Function returns the result to your app

**Benefits:**
- ✅ API keys never leave your server
- ✅ Can add rate limiting, authentication, logging
- ✅ Can cache responses
- ✅ Can add usage tracking per user

## Architecture

```
iOS App → Supabase Edge Function → Runware/WaveSpeed API
         (holds API keys)          (returns results)
```

## Step 1: Create Supabase Edge Functions

### 1.1 Install Supabase CLI

```bash
npm install -g supabase
```

### 1.2 Login to Supabase

```bash
supabase login
```

### 1.3 Link Your Project

```bash
cd "/Users/mike/Desktop/Desktop/iOS Apps/Creator AI Studio"
supabase link --project-ref inaffymocuppuddsewyq
```

### 1.4 Create Edge Functions

Create functions for each API:

```bash
supabase functions new runware-proxy
supabase functions new wavespeed-proxy
```

## Step 2: Implement Runware Proxy

Create/edit: `supabase/functions/runware-proxy/index.ts`

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const RUNWARE_API_KEY = Deno.env.get('RUNWARE_API_KEY') || 'zNNJ1KwqNUadOYKQmm58U84JqDjr5qMV'
const RUNWARE_API_URL = 'https://api.runware.ai/v1'

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    }})
  }

  try {
    // Get authenticated user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Verify user with Supabase
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Get request body from iOS app
    const requestBody = await req.json()

    // Forward request to Runware API
    const runwareResponse = await fetch(RUNWARE_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(requestBody),
    })

    const data = await runwareResponse.json()

    // Return response to iOS app
    return new Response(
      JSON.stringify(data),
      {
        status: runwareResponse.status,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

## Step 3: Implement WaveSpeed Proxy

Create/edit: `supabase/functions/wavespeed-proxy/index.ts`

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const WAVESPEED_API_KEY = Deno.env.get('WAVESPEED_API_KEY') || '5fb599c5eca75157f34d7da3efc734a3422a4b5ae0e6bbf753a09b82e6caebdf'

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    }})
  }

  try {
    // Get authenticated user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Verify user with Supabase
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Get request details from iOS app
    const { endpoint, body } = await req.json()

    // Forward request to WaveSpeed API
    const wavespeedResponse = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${WAVESPEED_API_KEY}`,
      },
      body: JSON.stringify(body),
    })

    const data = await wavespeedResponse.json()

    // Return response to iOS app
    return new Response(
      JSON.stringify(data),
      {
        status: wavespeedResponse.status,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

## Step 4: Set Environment Variables

Set your API keys as secrets in Supabase:

```bash
supabase secrets set RUNWARE_API_KEY=zNNJ1KwqNUadOYKQmm58U84JqDjr5qMV
supabase secrets set WAVESPEED_API_KEY=5fb599c5eca75157f34d7da3efc734a3422a4b5ae0e6bbf753a09b82e6caebdf
```

## Step 5: Deploy Edge Functions

```bash
supabase functions deploy runware-proxy
supabase functions deploy wavespeed-proxy
```

## Step 6: Update iOS App to Use Proxies

### 6.1 Update RunwareAPI.swift

Replace direct API calls with calls to your Edge Function:

```swift
// Instead of:
let url = URL(string: "https://api.runware.ai/v1")!

// Use:
let url = URL(string: "https://inaffymocuppuddsewyq.supabase.co/functions/v1/runware-proxy")!

// Add authentication header:
request.setValue("Bearer \(supabaseAuthToken)", forHTTPHeaderField: "Authorization")
```

### 6.2 Update WaveSpeedAPI.swift

Similar changes - point to your Edge Function instead of WaveSpeed directly.

### 6.3 Remove API Keys from iOS App

Once proxies are working, remove all API keys from your iOS code.

## Step 7: Testing

1. Test Edge Functions directly:
```bash
curl -X POST https://inaffymocuppuddsewyq.supabase.co/functions/v1/runware-proxy \
  -H "Authorization: Bearer YOUR_SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

2. Test from iOS app - should work the same as before, but now secure!

## Additional Security Enhancements

### Rate Limiting
Add rate limiting per user in Edge Functions to prevent abuse.

### Usage Tracking
Log all API calls to track usage per user.

### Request Validation
Validate and sanitize all requests before forwarding to APIs.

### Caching
Cache responses for common requests to reduce API costs.

## Cost Considerations

- Supabase Edge Functions: Free tier includes 500K invocations/month
- Additional invocations: $2 per 1M requests
- Much cheaper than exposing API keys and getting abused!

## Next Steps

1. Set up Supabase CLI and link project
2. Create Edge Functions
3. Deploy and test
4. Update iOS app to use proxies
5. Remove API keys from iOS code
6. Monitor usage and costs

## Resources

- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Deno Runtime](https://deno.land/manual)
- [Supabase TypeScript Client](https://supabase.com/docs/reference/javascript/introduction)

