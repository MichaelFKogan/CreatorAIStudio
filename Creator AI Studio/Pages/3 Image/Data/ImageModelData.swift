
let imageModelData = [
    // ---------------------------------------------------------
    // MARK: - Google Nano Banana (Gemini Flash 2.5)

    // ---------------------------------------------------------
    InfoPacket(
        display: DisplayInfo(
            title: "Google Gemini Flash 2.5 (Nano Banana)",
//            title: "Google Gemini Flash 2.5 (Nano Banana)",
            imageName: "geminiflashimage25",
            imageNameOriginal: "yourphoto",
            description: "",
            modelName: "Google Gemini Flash 2.5 (Nano Banana)",
            modelDescription: "A fast, lightweight model built for clean enhancements, realistic textures, and quick image edits. Ideal for portraits, product shots, and everyday transformations.",
            modelImageName: "geminiflashimage25",
            exampleImages: []
        ),
        apiConfig: APIConfiguration(
            endpoint: "https://api.wavespeed.ai/api/v3/google/nano-banana/edit",
            outputFormat: "jpeg",
            enableSyncMode: false,
            enableBase64Output: false,
            aspectRatio: nil
        ),
        prompt: "",
        cost: 0.04,
        type: "Image Model",
        capabilities: ["Text to Image", "Image to Image"]
    ),

    // ---------------------------------------------------------
    // MARK: - GPT Image 1

    // ---------------------------------------------------------
    InfoPacket(
        display: DisplayInfo(
            title: "GPT Image 1",
            imageName: "gptimage1",
            imageNameOriginal: "yourphoto",
            description: "",
            modelName: "GPT Image 1",
            modelDescription: "A creative-focused model that excels at stylized visuals, artistic reimagining, and expressive compositions. Great for fantasy, concept art, and cinematic stills.",
            modelImageName: "gptimage1",
            exampleImages: []
        ),
        apiConfig: APIConfiguration(
            endpoint: "https://api.wavespeed.ai/api/v3/openai/gpt-image-1",
            outputFormat: "jpeg",
            enableSyncMode: false,
            enableBase64Output: false,
            aspectRatio: nil
        ),
        prompt: "",
        cost: 0.04,
        type: "Image Model",
        capabilities: ["Text to Image", "Image to Image"]
    ),

    // ---------------------------------------------------------
    // MARK: - Seedream 4.0

    // ---------------------------------------------------------
    InfoPacket(
        display: DisplayInfo(
            title: "Seedream 4.0",
            imageName: "seedream40",
            imageNameOriginal: "yourphoto",
            description: "",
            modelName: "Seedream 4.0",
            modelDescription: "Known for soft lighting, vivid color gradients, and dreamy realism. Ideal for lifestyle images, outdoor scenes, illustrations, and aesthetic-focused designs.",
            modelImageName: "seedream40",
            exampleImages: []
        ),
        apiConfig: APIConfiguration(
            endpoint: "https://api.wavespeed.ai/api/v3/bytedance/seedream-v4/edit",
            outputFormat: "jpeg",
            enableSyncMode: false,
            enableBase64Output: false,
            aspectRatio: nil
        ),
        prompt: "",
        cost: 0.027,
        type: "Image Model",
        capabilities: ["Text to Image", "Image to Image"]
    ),

    // ---------------------------------------------------------
    // MARK: - FLUX.1 Kontext [dev]

    // ---------------------------------------------------------
    InfoPacket(
        display: DisplayInfo(
            title: "FLUX.1 Kontext [dev]",
            imageName: "fluxkontextdev",
            imageNameOriginal: "yourphoto",
            description: "",
            modelName: "FLUX.1 Kontext [dev]",
            modelDescription: "An experimental model focused on structure, clarity, and accurate scene composition. Best for previews, drafts, and rapid creative exploration.",
            modelImageName: "fluxkontextdev",
            exampleImages: []
        ),
        apiConfig: APIConfiguration(
            endpoint: "https://api.wavespeed.ai/api/v3/wavespeed-ai/flux-kontext-dev",
            outputFormat: "jpeg",
            enableSyncMode: false,
            enableBase64Output: false,
            aspectRatio: nil
        ),
        prompt: "",
        cost: 0.025,
        type: "Image Model",
        capabilities: ["Text to Image", "Image to Image"]
    ),

    // ---------------------------------------------------------
    // MARK: - FLUX.1 Kontext [pro]

    // ---------------------------------------------------------
    InfoPacket(
        display: DisplayInfo(
            title: "FLUX.1 Kontext [pro]",
            imageName: "fluxkontextpro",
            imageNameOriginal: "yourphoto",
            description: "",
            modelName: "FLUX.1 Kontext [pro]",
            modelDescription: "A high-quality image generator with refined detail, clean edges, and strong lighting control. Excellent for portraits, branding work, and polished professional visuals.",
            modelImageName: "fluxkontextpro",
            exampleImages: []
        ),
        apiConfig: APIConfiguration(
            endpoint: "https://api.wavespeed.ai/api/v3/wavespeed-ai/flux-kontext-pro",
            outputFormat: "jpeg",
            enableSyncMode: false,
            enableBase64Output: false,
            aspectRatio: nil
        ),
        prompt: "",
        cost: 0.04,
        type: "Image Model",
        capabilities: ["Text to Image", "Image to Image"]
    ),

    // ---------------------------------------------------------
    // MARK: - FLUX.1 Kontext [max]

    // ---------------------------------------------------------
    InfoPacket(
        display: DisplayInfo(
            title: "FLUX.1 Kontext [max]",
            imageName: "fluxkontextmax",
            imageNameOriginal: "yourphoto",
            description: "",
            modelName: "FLUX.1 Kontext [max]",
            modelDescription: "The most advanced version of the FLUX line—built for large scenes, deep texture detail, complex lighting, and ultra-realistic rendering. Perfect for high-impact creative work.",
            modelImageName: "fluxkontextmax",
            exampleImages: []
        ),
        apiConfig: APIConfiguration(
            endpoint: "https://api.wavespeed.ai/api/v3/wavespeed-ai/flux-kontext-max",
            outputFormat: "jpeg",
            enableSyncMode: false,
            enableBase64Output: false,
            aspectRatio: nil
        ),
        prompt: "",
        cost: 0.08,
        type: "Image Model",
        capabilities: ["Text to Image", "Image to Image"]
    ),
]
