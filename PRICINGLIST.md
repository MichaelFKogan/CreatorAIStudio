# Pricing List

This document lists all pricing for image and video models in Creator AI Studio.

**Note:** All prices are in USD ($). The app can display prices in dollars or credits (1 credit = $0.01, 100 credits = $1.00).

---

## Image Models (Fixed Pricing)

Image models have fixed pricing per generation, regardless of size or other parameters.

| Model Name | Price per Image |
|------------|-----------------|
| **Z-Image-Turbo** | $0.005 |
| **Wavespeed Ghibli** | $0.005 |
| **FLUX.2 [dev]** | $0.0122 |
| **Wan2.5-Preview Image** | $0.027 |
| **Seedream 4.0** | $0.03 |
| **GPT Image 1.5** | $0.034 |
| **Google Gemini Flash 2.5 (Nano Banana)** | $0.039 |
| **Seedream 4.5** | $0.04 |
| **FLUX.1 Kontext [pro]** | $0.04 |
| **FLUX.1 Kontext [max]** | $0.08 |

**Total Image Models:** 10

---

## Video Models (Variable Pricing)

Video models have variable pricing based on aspect ratio, resolution, and duration. Prices shown are in USD.

### Sora 2

**Supported Aspect Ratios:** 16:9, 9:16  
**Supported Resolution:** 720p only  
**Supported Durations:** 4s, 8s, 12s

| Aspect Ratio | Resolution | Duration | Price |
|--------------|------------|----------|-------|
| 16:9 | 720p | 4s | $0.40 |
| 16:9 | 720p | 8s | $0.80 |
| 16:9 | 720p | 12s | $1.20 |
| 9:16 | 720p | 4s | $0.40 |
| 9:16 | 720p | 8s | $0.80 |
| 9:16 | 720p | 12s | $1.20 |

**Default Configuration:** 9:16, 720p, 8s → **$0.80**

---

### Google Veo 3.1 Fast

**Supported Aspect Ratios:** 16:9, 9:16  
**Supported Resolution:** 1080p only  
**Supported Duration:** 8s only  
**Audio Support:** Yes (affects pricing)

| Aspect Ratio | Resolution | Duration | With Audio | Without Audio |
|--------------|------------|----------|------------|---------------|
| 16:9 | 1080p | 8s | $1.20 | $0.80 |
| 9:16 | 1080p | 8s | $1.20 | $0.80 |

**Default Configuration:** 9:16, 1080p, 8s (with audio) → **$1.20**  
**Audio Addon:** -$0.40 when audio is turned OFF

---

### Seedance 1.0 Pro Fast

**Supported Aspect Ratios:** 3:4, 9:16, 1:1, 4:3, 16:9  
**Supported Resolutions:** 480p, 720p, 1080p  
**Supported Durations:** 5s, 10s

| Aspect Ratio | Resolution | 5s | 10s |
|--------------|------------|----|-----|
| **3:4** | 480p | $0.0304 | $0.0609 |
| **3:4** | 720p | $0.0709 | $0.1417 |
| **3:4** | 1080p | $0.1579 | $0.3159 |
| **9:16** | 480p | $0.0315 | $0.0629 |
| **9:16** | 720p | $0.0668 | $0.1336 |
| **9:16** | 1080p | $0.1589 | $0.3177 |
| **1:1** | 480p | $0.0311 | $0.0623 |
| **1:1** | 720p | $0.0701 | $0.1402 |
| **1:1** | 1080p | $0.1577 | $0.3154 |
| **4:3** | 480p | $0.0304 | $0.0609 |
| **4:3** | 720p | $0.0709 | $0.1417 |
| **4:3** | 1080p | $0.1579 | $0.3159 |
| **16:9** | 480p | $0.0315 | $0.0629 |
| **16:9** | 720p | $0.0668 | $0.1336 |
| **16:9** | 1080p | $0.1589 | $0.3177 |

**Default Configuration:** 3:4, 480p, 5s → **$0.0304** (cheapest option)

---

### Kling VIDEO 2.6 Pro

**Supported Aspect Ratios:** 16:9, 9:16, 1:1  
**Supported Resolution:** 1080p only  
**Supported Durations:** 5s, 10s  
**Audio Support:** Yes (affects pricing)

| Aspect Ratio | Resolution | Duration | With Audio | Without Audio |
|--------------|------------|----------|------------|---------------|
| 16:9 | 1080p | 5s | $0.70 | $0.35 |
| 16:9 | 1080p | 10s | $1.40 | $0.70 |
| 9:16 | 1080p | 5s | $0.70 | $0.35 |
| 9:16 | 1080p | 10s | $1.40 | $0.70 |
| 1:1 | 1080p | 5s | $0.70 | $0.35 |
| 1:1 | 1080p | 10s | $1.40 | $0.70 |

**Default Configuration:** 9:16, 1080p, 5s (with audio) → **$0.70**  
**Audio Addon:** -$0.07 per second when audio is turned OFF (e.g., -$0.35 for 5s, -$0.70 for 10s)

---

### Wan2.6

**Supported Aspect Ratios:** 16:9, 9:16, 1:1  
**Supported Resolutions:** 720p, 1080p  
**Supported Durations:** 5s, 10s, 15s

| Aspect Ratio | Resolution | 5s | 10s | 15s |
|--------------|------------|----|-----|-----|
| 16:9 | 720p | $0.50 | $1.00 | $1.50 |
| 16:9 | 1080p | $0.75 | $1.50 | $2.25 |
| 9:16 | 720p | $0.50 | $1.00 | $1.50 |
| 9:16 | 1080p | $0.75 | $1.50 | $2.25 |
| 1:1 | 720p | $0.50 | $1.00 | $1.50 |
| 1:1 | 1080p | $0.75 | $1.50 | $2.25 |

**Default Configuration:** 9:16, 720p, 5s → **$0.50**

---

### KlingAI 2.5 Turbo Pro

**Supported Aspect Ratios:** 16:9, 9:16, 1:1  
**Supported Resolution:** 1080p only  
**Supported Durations:** 5s, 10s

| Aspect Ratio | Resolution | 5s | 10s |
|--------------|------------|----|-----|
| 16:9 | 1080p | $0.35 | $0.70 |
| 9:16 | 1080p | $0.35 | $0.70 |
| 1:1 | 1080p | $0.35 | $0.70 |

**Default Configuration:** 9:16, 1080p, 5s → **$0.35**

---

## Audio Pricing

Some video models support audio generation, which affects pricing:

| Model | Audio Pricing |
|-------|---------------|
| **Google Veo 3.1 Fast** | Base price includes audio ($1.20). Audio OFF: -$0.40 (price becomes $0.80) |
| **Kling VIDEO 2.6 Pro** | Base price includes audio ($0.14/s). Audio OFF: -$0.07/s (e.g., 5s: $0.70 → $0.35) |

**Note:** Base prices shown in the tables above include audio when applicable. The audio addon is subtracted when audio is turned OFF.

---

## Price Range Summary

### Image Models
- **Cheapest:** $0.005 (Z-Image-Turbo, Wavespeed Ghibli)
- **Most Expensive:** $0.08 (FLUX.1 Kontext [max])

### Video Models
- **Cheapest Option:** $0.0304 (Seedance 1.0 Pro Fast - 3:4, 480p, 5s)
- **Most Expensive Option:** $2.25 (Wan2.6 - 1080p, 15s)

---

## Credits Conversion

- **1 credit = $0.01**
- **100 credits = $1.00**

To convert any price to credits, multiply by 100. For example:
- $0.50 = 50 credits
- $1.20 = 120 credits
- $0.005 = 0.5 credits (rounded to 1 credit in practice)

---

*Last updated: January 22, 2026*
