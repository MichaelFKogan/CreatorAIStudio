# Setup Instructions

## Initial Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd "Creator AI Studio"
```

### 2. Configure Info.plist

The `Creator-AI-Studio-Info.plist` file contains sensitive API keys and is gitignored. You need to create your own local copy:

1. **Copy the template file:**
   ```bash
   cp Creator-AI-Studio-Info.plist.template Creator-AI-Studio-Info.plist
   ```

2. **Open `Creator-AI-Studio-Info.plist` and replace all placeholder values:**

   - `YOUR_GOOGLE_CLIENT_ID`: Your Google OAuth Client ID
     - Get this from [Google Cloud Console](https://console.cloud.google.com/)
     - The `CFBundleURLSchemes` value should be: `com.googleusercontent.apps.YOUR_CLIENT_ID`
   
   - `YOUR_PROJECT_ID`: Your Supabase project ID
     - Found in your Supabase project URL: `https://YOUR_PROJECT_ID.supabase.co`
     - Also used in `SUPABASE_URL`
   
   - `YOUR_SUPABASE_ANON_KEY`: Your Supabase anonymous/public key
     - Found in Supabase Dashboard → Settings → API
     - This is the "anon" or "public" key (safe to use in client apps)
   
   - `YOUR_WEBHOOK_SECRET`: Your webhook verification secret
     - Generate a random secret: `openssl rand -hex 32`
     - This must match the `WEBHOOK_SECRET` in your Supabase Edge Function secrets

### 3. Configure Supabase Edge Function Secrets

The Edge Functions also need secrets configured. See `Creator AI Studio/API/Supabase/EdgeFunctions/SETUP_INSTRUCTIONS.md` for details.

Required secrets in Supabase Dashboard → Edge Functions → Secrets:
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key (⚠️ **KEEP SECRET**)
- `WEBHOOK_SECRET`: Must match the value in your `Info.plist`
- `WAVESPEED_WEBHOOK_SECRET`: (Optional, if using WaveSpeed)

### 4. Open in Xcode

```bash
open "Creator AI Studio.xcodeproj"
```

### 5. Build and Run

The app should now build and run. If you see errors about missing configuration values, double-check that:
- `Creator-AI-Studio-Info.plist` exists (not just the template)
- All placeholder values have been replaced with actual values
- The file is in the project root directory

## Security Notes

⚠️ **Important:**
- Never commit `Creator-AI-Studio-Info.plist` to git (it's already in `.gitignore`)
- Never commit your Supabase service role key
- The anon key is safe for client apps, but still keep it out of public repos
- Share secrets securely with team members (use a password manager or secure channel)

## Troubleshooting

### App crashes on startup with "not found in Info.plist" error
- Make sure you've created `Creator-AI-Studio-Info.plist` from the template
- Verify all placeholder values have been replaced

### Build errors about missing Info.plist
- Ensure the file is named exactly `Creator-AI-Studio-Info.plist` (case-sensitive)
- Check that it's in the project root directory

### Authentication not working
- Verify your Google Client ID is correct
- Check that the URL scheme matches your Google OAuth configuration
- Ensure Supabase keys are correct
