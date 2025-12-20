# Add New Video Model - Prompt Template

Use this template when asking Cursor to add a new video model. Fill in all the details below and reference the guide.

**Reference Guide:** See `VIDEO_MODEL_ADDITION_GUIDE.md` for detailed instructions.

---

## Model Information

**Model Name:** [e.g., "Wan2.7"]

**Runware Model ID:** [e.g., "alibaba:wan@2.7"]

**Documentation URL:** [Link to Runware API docs for this model]

**Pricing URL:** [Link to pricing page, usually https://runware.ai/pricing]

---

## Model Capabilities

- [ ] Text to Video
- [ ] Image to Video
- [ ] Audio Generation
- [ ] Other: [specify]

---

## Technical Specifications

**Supported Durations:** [e.g., 5, 10, 15 seconds]

**Supported Resolutions:** [e.g., 720p, 1080p]

**Supported Aspect Ratios:** [List all supported ratios, e.g., 16:9, 9:16, 1:1]

**Important:** Only include aspect ratios that are explicitly supported. Check documentation carefully.

---

## Pricing Information

**Pricing Structure:** [Fixed or Variable?]

If **Variable**, provide pricing for all combinations:

```
Aspect Ratio | Resolution | Duration | Price
-------------|------------|----------|-------
16:9         | 720p       | 5s       | $0.50
16:9         | 720p       | 10s      | $1.00
16:9         | 1080p      | 5s       | $0.75
...          | ...        | ...      | ...
```

If **Fixed**, provide single price: $[amount]

---

## Provider Settings (if applicable)

Does this model require provider-specific settings? [Yes/No]

If **Yes**, provide:

- **Provider Name:** [e.g., "alibaba", "google", "klingai"]
- **Parameters:**
  - `parameter1`: [type, default value, description]
  - `parameter2`: [type, default value, description]
  - ...

**Example:**

```
Provider: alibaba
Parameters:
  - promptExtend: boolean, default: true
  - audio: boolean, default: true
  - shotType: "single" | "multi", default: "single"
```

---

## Model Description

**Short Description:** [1-2 sentences about what makes this model unique]

**Full Description:** [Detailed description for the app UI]

---

## Image Asset

**Image Name:** [e.g., "wan27"] - Must be lowercase, no spaces

**Note:** Make sure the image asset exists in Assets catalog before adding the model.

---

## Example Prompt

Copy and paste this template when ready:

```
I need to add a new video model to the app. Please follow the guide in VIDEO_MODEL_ADDITION_GUIDE.md.

Model Name: [fill in]
Runware Model ID: [fill in]
Documentation: [link]
Pricing: [link]

Capabilities: [list]
Durations: [list]
Resolutions: [list]
Aspect Ratios: [list - be careful to only include supported ones]

Pricing: [paste pricing table or fixed price]

Provider Settings: [if applicable, provide details]

Description: [paste description]

Image Name: [fill in]
```

---

## Quick Checklist

Before submitting, verify:

- [ ] All technical specs match the official documentation
- [ ] Pricing information is accurate and complete
- [ ] Only supported aspect ratios are listed
- [ ] Image asset name is provided
- [ ] Model description is written
- [ ] Provider settings are documented (if applicable)
