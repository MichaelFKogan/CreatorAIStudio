//
//  VideoPromptConstants.swift
//  Creator AI Studio
//
//  Extracted to improve build performance by reducing type inference load.
//

import Foundation

/// Centralized prompt constants for video generation pages.
/// Extracted from VideoModelDetailPage to reduce Swift compiler type-checking overhead.
struct VideoPromptConstants {

    /// Example prompts for video generation - describes scenes and styles.
    static let examplePrompts: [String] = [
        "A serene landscape with mountains at sunset, photorealistic, 8k quality",
        "A futuristic cityscape with flying cars and neon lights at night",
        "A cute fluffy kitten playing with yarn, studio lighting, professional photography",
        "An astronaut riding a horse on the moon, cinematic lighting, detailed",
        "A cozy coffee shop interior with warm lighting and plants, architectural photography",
        "A majestic dragon soaring through clouds, fantasy art, highly detailed",
        "A vintage sports car on an empty road, golden hour lighting, 4k",
        "A magical forest with glowing mushrooms and fireflies, fantasy illustration",
        "A modern minimalist living room with large windows, interior design photography",
        "A colorful abstract painting with geometric shapes and vibrant colors",
        "A medieval castle on a cliff overlooking the ocean, dramatic lighting",
        "A cyberpunk street market with holographic signs, neon colors, ultra detailed",
        "A peaceful zen garden with cherry blossoms and koi pond, soft focus",
        "A powerful lion portrait with intense eyes, wildlife photography, 8k",
        "A steampunk airship in the clouds, brass and copper details, concept art",
        "A tropical beach at sunrise with palm trees, paradise scenery, HDR",
        "An enchanted library with floating books and magical lights, fantasy art",
        "A modern luxury yacht on crystal clear water, professional photography",
        "A mysterious alien landscape with purple sky and twin moons, sci-fi art",
        "A rustic farmhouse in autumn with falling leaves, warm colors, cozy atmosphere",
        "A sleek modern kitchen with marble countertops, architectural digest style",
        "A samurai warrior in traditional armor, dramatic pose, cinematic composition",
        "A vibrant coral reef with tropical fish, underwater photography, vivid colors",
        "A gothic cathedral interior with stained glass windows, divine lighting",
        "A bustling Tokyo street at night with neon signs, street photography",
        "A serene mountain lake reflection at dawn, mirror-like water, pristine nature",
        "A futuristic robot with intricate mechanical details, sci-fi concept art",
        "A cozy reading nook by a window on a rainy day, warm lighting",
        "A majestic phoenix rising from flames, mythical creature, vibrant colors",
        "A Victorian mansion in foggy weather, gothic atmosphere, haunting beauty",
    ]

    /// Transform prompts for style conversion.
    static let transformPrompts: [String] = [
        "Transform to anime style",
        "Transform to watercolor painting",
        "Transform to oil painting",
        "Transform to pencil sketch",
        "Transform to cyberpunk style",
        "Transform to vintage photograph",
        "Transform to impressionist painting",
        "Transform to pop art style",
        "Transform to black and white",
        "Transform to steampunk style",
        "Transform to fantasy art style",
        "Transform to minimalist design",
        "Transform to 3D render",
        "Transform to comic book style",
        "Transform to surrealist art",
        "Transform to abstract art",
        "Transform to pixel art",
        "Transform to neon art style",
        "Transform to gothic style",
        "Transform to kawaii style",
        "Transform to retro 80s style",
        "Transform to film noir style",
        "Transform to Van Gogh painting style",
        "Transform to Picasso cubist style",
        "Transform to Monet impressionist style",
    ]
}
