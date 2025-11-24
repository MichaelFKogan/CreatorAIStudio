let videoModelData = [
    // ---------------------------------------------------------
    // MARK: - Sora 2

    // ---------------------------------------------------------
    InfoPacket(
        display: DisplayInfo(
            title: "Sora 2",
            imageName: "sora2",
            imageNameOriginal: "yourphoto",
            description: "",
            modelName: "Sora 2",
            modelDescription: "Sora 2 is designed for cinematic-quality video generation with extremely stable motion, improved physics accuracy, expressive character animation, and rich scene detail. Perfect for storytelling, ads, and high-impact creative content.",
            modelImageName: "sora2",
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
        cost: 0.80,
        type: "AI Video Model",
        capabilities: ["Text to Video", "Image to Video", "Audio"]
    ),

    // ---------------------------------------------------------
    // MARK: - Google Veo 3

    // ---------------------------------------------------------
    InfoPacket(
        display: DisplayInfo(
            title: "Google Veo 3",
            imageName: "veo3",
            imageNameOriginal: "yourphoto",
            description: "",
            modelName: "Google Veo 3",
            modelDescription: "Veo 3 focuses on clarity, smooth motion, and natural lighting. It excels at dynamic environments, realistic textures, and clean camera transitions—ideal for lifestyle clips, outdoor scenes, product demos, and fast-paced creative content.",
            modelImageName: "veo3",
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
        cost: 1.20,
        type: "AI Video Model",
        capabilities: ["Text to Video", "Image to Video", "Audio"]
    ),

    // ---------------------------------------------------------
    // MARK: - Kling AI

    // ---------------------------------------------------------
    InfoPacket(
        display: DisplayInfo(
            title: "Kling AI",
            imageName: "klingai",
            imageNameOriginal: "yourphoto",
            description: "",
            modelName: "Kling AI",
            modelDescription: "Kling AI specializes in hyper-realistic motion and high-speed action scenes. With sharp detail and stable, precise frame-to-frame movement, it's a strong choice for sports, sci-fi shots, fast motion, and large sweeping environments.",
            modelImageName: "klingai",
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
        cost: 0.80,
        type: "AI Video Model",
        capabilities: ["Text to Video", "Image to Video"]
    ),

    // ---------------------------------------------------------
    // MARK: - Wan 2.5

    // ---------------------------------------------------------
    InfoPacket(
        display: DisplayInfo(
            title: "Wan 2.5",
            imageName: "wan25",
            imageNameOriginal: "yourphoto",
            description: "",
            modelName: "Wan 2.5",
            modelDescription: "Wan 2.5 delivers dramatic cinematic visuals, advanced character performance, atmospheric effects, and stylized world-building. It shines in fantasy, anime, surreal scenes, and richly creative storytelling.",
            modelImageName: "wan",
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
        cost: 1.00,
        type: "AI Video Model",
        capabilities: ["Text to Video", "Image to Video", "Audio"]
    ),
]
