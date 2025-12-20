# Video Model Addition Guide

This guide provides step-by-step instructions for adding new video models to the Creator AI Studio app. Follow this process whenever you need to integrate a new video generation model.

## Overview

When adding a new video model, you need to update **4 main files**:

1. `TaskManager/ModelConfigurationManager.swift` - API configurations, capabilities, descriptions, image names, durations, aspect ratios, and resolutions
2. `TaskManager/PricingManager.swift` - Pricing configurations
3. `Pages/4 Video/Data/VideoModelData.json` - Model display data
4. `API/Runware/RunwareAPI.swift` - Provider-specific settings (if needed)

---

## Step 1: ModelConfigurationManager.swift

This is the central configuration file. You need to add entries in **7 different sections**:

### 1.1 API Configurations (`apiConfigurations` dictionary)

Add the model's API configuration in the `// MARK: VIDEO MODELS API` section:

```swift
"Model Name": APIConfiguration(
    provider: .runware,
    endpoint: "https://api.runware.ai/v1",
    runwareModel: "provider:model@version",  // e.g., "alibaba:wan@2.6"
    aspectRatio: nil,
    wavespeedConfig: nil,
    runwareConfig: RunwareConfig(
        imageToImageMethod: "frameImages",
        strength: nil,
        additionalTaskParams: [
            "taskType": "videoInference",
            "deliveryMethod": "async"
        ],
        requiresDimensions: true,
        imageCompressionQuality: 0.9,
        outputFormat: "MP4",
        outputType: "URL",
        outputQuality: nil
    )
)
```

**Key fields:**

- `runwareModel`: The exact model identifier from Runware API (check documentation)
- `imageToImageMethod`: Usually `"frameImages"` for video models
- `outputFormat`: Usually `"MP4"` for video

### 1.2 Capabilities (`capabilitiesMap` dictionary)

Add capabilities in the `// MARK: CAPABILITIES PILLS` section:

```swift
"Model Name": ["Text to Video", "Image to Video", "Audio"]
```

**Common capabilities:**

- `"Text to Video"` - Always included
- `"Image to Video"` - If model supports image-to-video
- `"Audio"` - If model supports native audio generation

### 1.3 Descriptions (`modelDescriptions` dictionary)

Add a description in the `// MARK: DESCRIPTIONS` section:

```swift
"Model Name": "A detailed description of the model's capabilities, strengths, and use cases. Keep it informative and user-friendly."
```

### 1.4 Image Names (`modelImageNames` dictionary)

Add the image asset name in the `// MARK: IMAGE NAMES` section:

```swift
"Model Name": "modelimagename"  // Lowercase, no spaces, no special chars except hyphens
```

**Note:** Make sure the corresponding image asset exists in your Assets catalog.

### 1.5 Durations (`allowedDurationsMap` dictionary)

Add supported durations in the `// MARK: DURATIONS` section:

```swift
"Model Name": [
    DurationOption(id: "5", label: "5 seconds", duration: 5.0, description: "Standard duration"),
    DurationOption(id: "10", label: "10 seconds", duration: 10.0, description: "Extended duration"),
    DurationOption(id: "15", label: "15 seconds", duration: 15.0, description: "Maximum duration")
]
```

**Important:** Check the model's documentation for supported durations. Common values: 4, 5, 8, 10, 12, 15 seconds.

### 1.6 Aspect Ratios (`allowedAspectRatiosMap` dictionary)

Add supported aspect ratios in the `// MARK: ALLOWED SIZES` section:

```swift
"Model Name": [
    AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
    AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
    AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"])
]
```

**Common aspect ratios:**

- `9:16` - Vertical/Portrait (TikTok, Reels)
- `16:9` - Horizontal/Landscape (YouTube)
- `1:1` - Square (Instagram)
- `3:4` - Portrait (some models)
- `4:3` - Landscape (some models)
- `17:13` / `13:17` - Custom ratios (check model docs)

**⚠️ Critical:** Only include aspect ratios that the model actually supports according to its documentation. Don't include unsupported ratios (e.g., don't add 3:4 or 4:3 if the model doesn't support them).

### 1.7 Resolutions (`allowedResolutionsMap` dictionary)

Add supported resolutions in the `// MARK: ALLOWED RESOLUTIONS` section:

```swift
"Model Name": [
    ResolutionOption(id: "480p", label: "480p", description: "Standard quality"),
    ResolutionOption(id: "720p", label: "720p", description: "High quality"),
    ResolutionOption(id: "1080p", label: "1080p", description: "Full HD")
]
```

**Common resolutions:**

- `480p` - Standard quality
- `720p` - High quality
- `1080p` - Full HD

**Note:** Not all models support all resolutions. Check the documentation.

---

## Step 2: PricingManager.swift

Add pricing configuration in **2 sections**:

### 2.1 Default Video Configs (`defaultVideoConfigs` dictionary)

Add default configuration for display pricing:

```swift
"Model Name": ("9:16", "720p", 5.0)  // (aspectRatio, resolution, duration)
```

This is used to show the "starting from" price in the UI.

### 2.2 Variable Video Pricing (`variableVideoPricing` dictionary)

Add pricing configuration in the `// MARK: VIDEO PRICES` section:

```swift
"Model Name": VideoPricingConfiguration(
    pricing: [
        "16:9": [
            "720p": [5.0: 0.5, 10.0: 1.0, 15.0: 1.5],
            "1080p": [5.0: 0.75, 10.0: 1.5, 15.0: 2.25]
        ],
        "9:16": [
            "720p": [5.0: 0.5, 10.0: 1.0, 15.0: 1.5],
            "1080p": [5.0: 0.75, 10.0: 1.5, 15.0: 2.25]
        ],
        "1:1": [
            "720p": [5.0: 0.5, 10.0: 1.0, 15.0: 1.5],
            "1080p": [5.0: 0.75, 10.0: 1.5, 15.0: 2.25]
        ]
    ]
)
```

**Structure:** `[aspectRatio: [resolution: [duration: price]]]`

**Important:**

- Include all supported aspect ratios
- Include all supported resolutions
- Include all supported durations
- Prices are in `Decimal` type (e.g., `0.5` for $0.50)
- Get pricing from Runware pricing page: https://runware.ai/pricing

**Note:** If the model has fixed pricing (not variable), add it to the `prices` dictionary instead (in the `// MARK: IMAGE PRICES` section).

---

## Step 3: VideoModelData.json

Add the model entry to the JSON array:

```json
{
  "display": {
    "title": "Model Name",
    "imageName": "modelimagename",
    "modelName": "Model Name"
  }
}
```

**Fields:**

- `title`: Display name (can include version numbers, e.g., "Wan2.6")
- `imageName`: Must match the `modelImageNames` entry in ModelConfigurationManager.swift
- `modelName`: Must match the key used in ModelConfigurationManager.swift dictionaries

**Important:** The `modelName` must be **exactly** the same string used as keys in ModelConfigurationManager.swift.

---

## Step 4: RunwareAPI.swift (Provider Settings)

If the model requires provider-specific settings (e.g., Alibaba, Google, KlingAI), add handling in **2 places**:

### 4.1 Polling Mode (around line 595-635)

Add provider settings handling before the `// MARK: - Wrap task in authentication array` comment:

```swift
// MARK: - Provider-specific settings for ProviderName models

// Model Name supports parameter1, parameter2 parameters
if model.lowercased().contains("provider:model@") {
    var providerSettings = task["providerSettings"] as? [String: Any] ?? [:]
    var providerSettings: [String: Any] = [:]

    // Set default values
    providerSettings["parameter1"] = true
    providerSettings["parameter2"] = generateAudio ?? true

    providerSettings["provider"] = providerSettings
    task["providerSettings"] = providerSettings
    print("[Runware] Added ProviderName provider settings - parameter1: true, parameter2: \(providerSettings["parameter2"] ?? true)")
}
```

### 4.2 Webhook Mode (around line 1095-1110)

Add the same provider settings handling in the webhook section (before the `let requestBody` line):

```swift
// Provider settings (same as polling mode)
if model.lowercased().contains("provider:model@") {
    // Same code as polling mode
}
```

**Common provider settings:**

- **Alibaba (Wan models):** `promptExtend`, `audio`, `shotType`
- **Google (Veo models):** `generateAudio`
- **KlingAI:** `sound`
- **ByteDance (Seedance):** `cameraFixed`

**Important:** Check the model's API documentation for exact parameter names and requirements.

---

## Example: Adding Wan2.6 Model

Here's a complete example of adding the Wan2.6 model:

### ModelConfigurationManager.swift

```swift
// 1. API Configuration
"Wan2.6": APIConfiguration(
    provider: .runware,
    endpoint: "https://api.runware.ai/v1",
    runwareModel: "alibaba:wan@2.6",
    // ... rest of config
),

// 2. Capabilities
"Wan2.6": ["Text to Video", "Image to Video", "Audio"],

// 3. Description
"Wan2.6": "Alibaba's Wan2.6 model delivers multimodal video generation with native audio support and multi-shot sequencing capabilities...",

// 4. Image Name
"Wan2.6": "wan26",

// 5. Durations
"Wan2.6": [
    DurationOption(id: "5", label: "5 seconds", duration: 5.0, description: "Standard duration"),
    DurationOption(id: "10", label: "10 seconds", duration: 10.0, description: "Extended duration"),
    DurationOption(id: "15", label: "15 seconds", duration: 15.0, description: "Maximum duration")
],

// 6. Aspect Ratios
"Wan2.6": [
    AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
    AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
    AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"])
],

// 7. Resolutions
"Wan2.6": [
    ResolutionOption(id: "720p", label: "720p", description: "High quality"),
    ResolutionOption(id: "1080p", label: "1080p", description: "Full HD")
]
```

### PricingManager.swift

```swift
// Default config
"Wan2.6": ("9:16", "720p", 5.0),

// Pricing
"Wan2.6": VideoPricingConfiguration(
    pricing: [
        "16:9": [
            "720p": [5.0: 0.5, 10.0: 1.0, 15.0: 1.5],
            "1080p": [5.0: 0.75, 10.0: 1.5, 15.0: 2.25]
        ],
        "9:16": [
            "720p": [5.0: 0.5, 10.0: 1.0, 15.0: 1.5],
            "1080p": [5.0: 0.75, 10.0: 1.5, 15.0: 2.25]
        ],
        "1:1": [
            "720p": [5.0: 0.5, 10.0: 1.0, 15.0: 1.5],
            "1080p": [5.0: 0.75, 10.0: 1.5, 15.0: 2.25]
        ]
    ]
)
```

### VideoModelData.json

```json
{
  "display": {
    "title": "Wan2.6",
    "imageName": "wan26",
    "modelName": "Wan2.6"
  }
}
```

### RunwareAPI.swift

```swift
// Alibaba provider settings
if model.lowercased().contains("alibaba:wan@") {
    var providerSettings = task["providerSettings"] as? [String: Any] ?? [:]
    var alibabaSettings: [String: Any] = [:]

    alibabaSettings["promptExtend"] = true
    alibabaSettings["audio"] = generateAudio ?? true

    if model.lowercased().contains("alibaba:wan@2.6") {
        alibabaSettings["shotType"] = "single"
    }

    providerSettings["alibaba"] = alibabaSettings
    task["providerSettings"] = providerSettings
}
```

---

## Checklist

When adding a new video model, verify:

- [ ] API configuration added to `ModelConfigurationManager.swift`
- [ ] Capabilities added to `capabilitiesMap`
- [ ] Description added to `modelDescriptions`
- [ ] Image name added to `modelImageNames` (and image asset exists)
- [ ] Durations added to `allowedDurationsMap` (matches model docs)
- [ ] Aspect ratios added to `allowedAspectRatiosMap` (only supported ones!)
- [ ] Resolutions added to `allowedResolutionsMap` (matches model docs)
- [ ] Default config added to `PricingManager.swift`
- [ ] Pricing configuration added (all combinations)
- [ ] Model entry added to `VideoModelData.json`
- [ ] Provider settings added to `RunwareAPI.swift` (if needed)
- [ ] All model names are **exactly** the same across all files
- [ ] Tested in the app to verify UI displays correctly

---

## Important Notes

1. **Model Name Consistency:** The model name string must be **exactly identical** across all files. Use the same capitalization, spacing, and special characters.

2. **Aspect Ratios:** Only include aspect ratios that the model actually supports. Don't assume all models support the same ratios. Check the documentation carefully.

3. **Pricing:** Get pricing from https://runware.ai/pricing. Include all supported combinations of aspect ratio, resolution, and duration.

4. **Provider Settings:** Not all models need provider settings. Only add them if the model's API documentation specifies provider-specific parameters.

5. **Image Assets:** Make sure the image asset referenced in `modelImageNames` actually exists in your Assets catalog.

6. **Testing:** After adding a model, test it in the app to ensure:
   - The model appears in the video models list
   - The correct aspect ratios are shown
   - The correct durations are available
   - Pricing displays correctly
   - Video generation works

---

## Resources

- Runware API Documentation: https://runware.ai/docs
- Runware Pricing: https://runware.ai/pricing
- Alibaba Video Models: https://runware.ai/docs/en/providers/alibaba#video-models

---

## Quick Reference: File Locations

```
Creator AI Studio/
├── TaskManager/
│   ├── ModelConfigurationManager.swift  (7 sections to update)
│   └── PricingManager.swift             (2 sections to update)
├── Pages/4 Video/
│   └── Data/
│       └── VideoModelData.json          (1 entry to add)
└── API/Runware/
    └── RunwareAPI.swift                 (2 sections if provider settings needed)
```

---

**Last Updated:** Based on adding Wan2.5-Preview and Wan2.6 models
**Version:** 1.0
