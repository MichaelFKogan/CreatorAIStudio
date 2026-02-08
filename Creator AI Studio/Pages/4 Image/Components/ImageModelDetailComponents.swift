//
//  ImageModelDetailComponents.swift
//  Creator AI Studio
//
//  Extracted from ImageModelDetailPage.swift to reduce compilation unit size
//  and type-checker load.
//

import Kingfisher
import SwiftUI

// MARK: INPUT MODE CARD (Reusable container)

/// Card container for Input mode: header with icon, chip picker, and description in a styled box.
struct InputModeCard<ControlContent: View, DescriptionContent: View>: View {
    let color: Color
    @ViewBuilder let control: () -> ControlContent
    @ViewBuilder let description: () -> DescriptionContent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text("Input mode")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            control()

            InputModeDescriptionBox(color: color) {
                description()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: INPUT MODE DESCRIPTION BOX

/// Wraps description content in a subtle inset with left accent border.
struct InputModeDescriptionBox<Content: View>: View {
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.leading, 22)
            .padding(.trailing, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.06))
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.5))
                    .frame(width: 3)
                    .padding(.vertical, 10)
                    .padding(.leading, 12)
            }
    }
}

// MARK: CHIP OPTION PICKER

/// Horizontal row of selectable chips (label + icon). Selected chip uses filled gradient; unselected uses outline.
struct ChipOptionPicker: View {
    let options: [(label: String, icon: String)]
    @Binding var selection: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isSelected = selection == index
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = index
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(option.label)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(isSelected
                                ? LinearGradient(
                                    colors: [color.opacity(0.85), color.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [Color.clear, Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .foregroundColor(isSelected ? .white : .primary)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.clear : color.opacity(0.35), lineWidth: 1.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: IMAGE TEXT IMAGE MODE DESCRIPTION BLOCK

struct ImageTextImageModeDescriptionBlock: View {
    let mode: ImageTextInputMode
    let color: Color

    private var title: String {
        switch mode {
        case .textToImage: return "Text To Image"
        case .imageToImage: return "Image To Image"
        }
    }

    private var iconName: String {
        switch mode {
        case .textToImage: return "doc.text"
        case .imageToImage: return "photo"
        }
    }

    private var instructions: String {
        switch mode {
        case .textToImage: return "Describe your image with a prompt. No reference images are used."
        case .imageToImage: return "Upload one or more reference images to guide the style and content."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text(instructions)
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
}

// MARK: BANNER SECTION

struct BannerSection: View {
    let item: InfoPacket
    let costString: String
    /// When set (e.g. GPT Image 1.5 with selected quality/aspect), used instead of item.resolvedCost for the banner price.
    var displayPrice: Decimal? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Model identity card: image + title + pill + price + description
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    Image(item.resolvedModelImageName ?? "")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.display.title)
                            .font(.title2).fontWeight(.bold).foregroundColor(
                                .primary
                            )
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle").font(
                                .caption)
                            Text("Image Generation Model").font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.blue.opacity(0.8)))

                        HStack(spacing: 4) {
                            PriceDisplayView(
                                price: displayPrice ?? item.resolvedCost ?? 0,
                                showUnit: true,
                                font: .title3,
                                fontWeight: .bold,
                                foregroundColor: .white
                            )
                            Text("per image").font(.caption).foregroundColor(
                                .secondary)
                        }

                        if let capabilities = ModelConfigurationManager.shared
                            .capabilities(for: item),
                            !capabilities.isEmpty
                        {
                            Text(capabilities.joined(separator: " • "))
                                .font(
                                    .system(
                                        size: 12, weight: .medium, design: .rounded
                                    )
                                )
                                .foregroundColor(.blue)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 120)
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Model description at bottom of card
                if let description = item.resolvedModelDescription,
                    !description.isEmpty
                {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                } else {
                    Color.clear.frame(height: 16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
}

// MARK: PROMPT SECTION

struct PromptSection: View {
    @Binding var prompt: String
    @FocusState.Binding var isFocused: Bool
    @Binding var isExamplePromptsPresented: Bool
    let examplePrompts: [String]
    let examplePromptsTransform: [String]
    let onCameraTap: () -> Void
    let onExpandTap: () -> Void
    @Binding var isProcessingOCR: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft").foregroundColor(.blue)
                Text("Prompt").font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onExpandTap) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }

            TextEditor(text: $prompt)
                .font(.system(size: 15))
                .opacity(0.9)
                .frame(height: 140)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isFocused
                                ? Color.blue.opacity(0.5)
                                : Color.gray.opacity(0.3),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .overlay(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text("Describe the image you want to generate...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                .focused($isFocused)

            HStack {
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Take a photo of a prompt")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                        Text("to add it to the box above")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    Button(action: onCameraTap) {
                        Group {
                            if isProcessingOCR {
                                ProgressView()
                                    .progressViewStyle(
                                        CircularProgressViewStyle(tint: .blue)
                                    )
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "viewfinder")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Button(action: { isExamplePromptsPresented = true }) {
                HStack {
                    Image(systemName: "lightbulb.fill").foregroundColor(.blue)
                        .font(.caption)
                    Text("Example Prompts").font(.caption).fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(
                        Color.blue.opacity(0.3), lineWidth: 1
                    ))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
    }
}

// MARK: FULL PROMPT SHEET (shared with VideoModelDetailPage)

struct FullPromptSheet: View {
    @Binding var prompt: String
    @Binding var isPresented: Bool
    let placeholder: String
    let accentColor: Color
    @FocusState private var isFocused: Bool

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $prompt)
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .padding()
                .background(Color.black)
                .overlay(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 17))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                            .allowsHitTesting(false)
                    }
                }
                .focused($isFocused)
            .navigationTitle("Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismissKeyboard()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
                }
            }
        }
        .background(Color.black)
    }
}

// MARK: QUALITY (GPT Image 1.5)

/// Button that shows current quality and opens a sheet to pick Low / Medium / High (like Size).
struct QualitySection: View {
    @Binding var selectedQualityIndex: Int
    let qualityOptions: [String]
    @Binding var showSheet: Bool

    private var selectedLabel: String {
        let idx = min(selectedQualityIndex, qualityOptions.count - 1)
        guard idx >= 0 else { return "Medium" }
        switch qualityOptions[idx] {
        case "low": return "Low"
        case "medium": return "Medium"
        case "high": return "High"
        default: return qualityOptions[idx].capitalized
        }
    }

    var body: some View {
        Button(action: { showSheet = true }) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(selectedLabel)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Text("Quality")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

/// Sheet listing Quality options (Low, Medium, High). Row layout matches ResolutionSelectorSheet.
struct QualitySelectorSheet: View {
    @Binding var selectedIndex: Int
    let optionLabels: [String]
    let color: Color
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(optionLabels.indices, id: \.self) { idx in
                        let label = optionLabels[idx]
                        let isSelected = idx == selectedIndex
                        Button {
                            selectedIndex = idx
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.08))
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 16))
                                        .foregroundColor(isSelected ? color : Color.gray.opacity(0.5))
                                }
                                .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(label)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(color)
                                        }
                                    }
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? color : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Select Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: ASPECT RATIO

struct AspectRatioSection: View {
    let options: [AspectRatioOption]
    @Binding var selectedIndex: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AspectRatioSelector(
                options: options, selectedIndex: $selectedIndex, color: .blue
            )
        }
        .padding(.horizontal)
    }
}

// MARK: RESOLUTION (Nano Banana Pro: 1K, 2K, 4K)

/// Tab row that shows selected resolution and opens a sheet to pick 1K / 2K / 4K (same style as Size tab).
struct ResolutionSection: View {
    let options: [ResolutionOption]
    @Binding var selectedIndex: Int
    @Binding var showSheet: Bool

    private var selectedOption: ResolutionOption {
        let idx = min(selectedIndex, options.count - 1)
        guard idx >= 0, idx < options.count else { return options[0] }
        return options[idx]
    }

    var body: some View {
        Button(action: { showSheet = true }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedOption.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    if let description = selectedOption.description {
                        Text(description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text("Resolution")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

// MARK: PRICING TABLE (Image models with variable pricing: GPT Image 1.5, Nano Banana Pro)

struct PricingTableSectionImage: View {
    let modelName: String
    @State private var showPricingSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { showPricingSheet = true }) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "tablecells")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        Text("Pricing Table")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("View")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 32)
        .sheet(isPresented: $showPricingSheet) {
            ImagePricingTableSheetView(modelName: modelName)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct ImagePricingTableSheetView: View {
    let modelName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if modelName == "GPT Image 1.5" {
                        GPTImage15PricingTable()
                    } else if modelName == "Nano Banana Pro" {
                        NanoBananaProPricingTable()
                    }
                }
                .padding()
            }
            .navigationTitle("Pricing Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GPTImage15PricingTable: View {
    private let aspectRatios = ["1:1", "2:3", "3:2"]
    private let qualities = ["Low", "Medium", "High"]
    private let qualityIds = ["low", "medium", "high"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                Text("By size & quality")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.blue.opacity(0.12)))

            HStack(spacing: 0) {
                Text("Size")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 44, alignment: .leading)
                ForEach(qualities, id: \.self) { q in
                    Text(q)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            VStack(spacing: 0) {
                ForEach(Array(aspectRatios.enumerated()), id: \.element) { index, aspect in
                    HStack(spacing: 0) {
                        Text(aspect)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 44, alignment: .leading)
                        ForEach(qualityIds, id: \.self) { qualityId in
                            let price = PricingManager.shared.priceForImageModel("GPT Image 1.5", aspectRatio: aspect, quality: qualityId)
                            let text = price.map { "\(PricingManager.formatCredits(Decimal($0))) credits" } ?? "–"
                            Text(text)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(index % 2 == 0 ? Color.clear : Color.blue.opacity(0.03))
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.04)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.15), lineWidth: 1))
        }
    }
}

struct NanoBananaProPricingTable: View {
    private let resolutions = [("1k", "1K"), ("2k", "2K"), ("4k", "4K")]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                Text("By resolution")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.blue.opacity(0.12)))

            HStack(spacing: 0) {
                Text("Resolution")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Credits")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            VStack(spacing: 0) {
                ForEach(Array(resolutions.enumerated()), id: \.element.0) { index, res in
                    let price = PricingManager.shared.priceForImageModel("Nano Banana Pro", resolution: res.0)
                    let text = price.map { "\(PricingManager.formatCredits(Decimal($0))) credits" } ?? "–"
                    HStack(spacing: 0) {
                        Text(res.1)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(text)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(index % 2 == 0 ? Color.clear : Color.blue.opacity(0.03))
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.04)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.15), lineWidth: 1))
        }
    }
}

// MARK: COST CARD

struct CostCardSection: View {
    let costString: String
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Generation Cost").font(.caption).foregroundColor(
                    .secondary)
                HStack(spacing: 4) {
                    Text("1 image").font(.subheadline).foregroundColor(.primary)
                    Text("×").font(.caption).foregroundColor(.secondary)
                    Text(costString).font(.subheadline).fontWeight(
                        .semibold
                    ).foregroundColor(.blue)
                }
            }
            Spacer()
            Text(costString).font(.title3).fontWeight(.bold)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(
                Color.blue.opacity(0.2), lineWidth: 1
            )
        )
        .padding(.horizontal)
    }
}

// MARK: GENERATE BUTTON

struct GenerateButton: View {
    let prompt: String
    @Binding var isGenerating: Bool
    @Binding var keyboardHeight: CGFloat
    let costString: String
    let isLoggedIn: Bool
    let hasCredits: Bool
    let isConnected: Bool
    let onSignInTap: () -> Void
    let action: () -> Void

    private var canGenerate: Bool {
        isLoggedIn && hasCredits && isConnected
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                if !isLoggedIn {
                    onSignInTap()
                } else {
                    action()
                }
            }) {
                HStack {
                    if isGenerating {
                        ProgressView().progressViewStyle(
                            CircularProgressViewStyle(tint: .white)
                        ).scaleEffect(0.8)
                    } else {
                        // Image(systemName: "photo.on.rectangle")
                    }
                    if isGenerating {
                        Text("Generating...")
                            .fontWeight(.semibold)
                    } else {
                        Text("Generate")
                            .fontWeight(.semibold)
                        Image(systemName: "sparkle")
                            .font(.system(size: 14))
                        Text(costString)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    isGenerating || !canGenerate
                        ? LinearGradient(
                            colors: [Color.gray, Color.gray],
                            startPoint: .leading, endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.cyan],
                            startPoint: .leading, endPoint: .trailing
                        )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(
                    color: (isGenerating || !canGenerate)
                        ? Color.clear : Color.blue.opacity(0.4),
                    radius: 8, x: 0, y: 4
                )
            }
            .scaleEffect(isGenerating ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isGenerating)
            .disabled(isGenerating || !canGenerate)
            .opacity(canGenerate ? 1.0 : 0.6)
            .padding(.horizontal)
            // .padding(.bottom, keyboardHeight > 0 ? 24 : 80)
            .background(Color(UIColor.systemBackground))
        }
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
    }
}

// MARK: MODEL GALLERY

struct ModelGallerySection: View {
    let modelName: String?
    let userId: String?

    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var modelImages: [UserImage] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasLoaded = false
    @State private var selectedUserImage: UserImage? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.secondary)
                    .font(.headline)
                Text("Your Creations With This Model")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if modelImages.isEmpty && hasLoaded {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No images yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Create your first image with this model!")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
            } else if !modelImages.isEmpty {
                ModelGalleryGridView(
                    userImages: modelImages,
                    isLoadingMore: isLoadingMore,
                    hasMorePages: viewModel.hasMoreModelPages(
                        modelName: modelName ?? ""),
                    onSelect: { userImage in
                        selectedUserImage = userImage
                    },
                    onLoadMore: {
                        guard let modelName = modelName, !modelName.isEmpty
                        else { return }
                        guard !isLoadingMore else { return }
                        isLoadingMore = true
                        Task {
                            let newImages = await viewModel.loadMoreModelImages(
                                modelName: modelName)
                            await MainActor.run {
                                modelImages.append(contentsOf: newImages)
                                isLoadingMore = false
                            }
                        }
                    }
                )
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadModelImages()
        }
        .sheet(item: $selectedUserImage) { userImage in
            FullScreenImageView(
                userImage: userImage,
                isPresented: Binding(
                    get: { selectedUserImage != nil },
                    set: { if !$0 { selectedUserImage = nil } }
                )
            )
            .environmentObject(authViewModel)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .ignoresSafeArea()
        }
    }

    private func loadModelImages() {
        guard let modelName = modelName, !modelName.isEmpty,
            let userId = userId, !userId.isEmpty,
            !hasLoaded
        else {
            // If no model name or user ID, mark as loaded to prevent retries
            hasLoaded = true
            return
        }

        hasLoaded = true
        viewModel.userId = userId
        isLoading = true

        Task {
            let images = await viewModel.fetchModelImages(
                modelName: modelName,
                forceRefresh: false
            )

            await MainActor.run {
                modelImages = images
                isLoading = false
            }
        }
    }
}

// MARK: GRID VIEW

struct ModelGalleryGridView: View {
    let userImages: [UserImage]
    let isLoadingMore: Bool
    let hasMorePages: Bool
    var onSelect: (UserImage) -> Void
    var onLoadMore: () -> Void

    private let spacing: CGFloat = 2
    private let gridColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 3
    )

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 16
            let totalHorizontalSpacing = spacing * 2  // 2 gaps between 3 columns
            let availableWidth =
                proxy.size.width - (horizontalPadding * 2)
                - totalHorizontalSpacing
            let itemWidth = max(44, availableWidth / 3)
            let itemHeight = itemWidth * 1.4

            let scale = UIScreen.main.scale
            let targetSize = CGSize(
                width: itemWidth * scale,
                height: itemHeight * scale
            )

            LazyVGrid(columns: gridColumns, spacing: spacing) {
                ForEach(userImages) { userImage in
                    if let displayUrl = userImage.isVideo
                        ? userImage.thumbnail_url : userImage.image_url,
                        let url = URL(string: displayUrl)
                    {
                        Button {
                            onSelect(userImage)
                        } label: {
                            ZStack {
                                KFImage(url)
                                    .setProcessor(
                                        DownsamplingImageProcessor(
                                            size: targetSize)
                                    )
                                    .cacheMemoryOnly()
                                    .fade(duration: 0.2)
                                    .placeholder {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(ProgressView())
                                    }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: itemWidth, height: itemHeight)
                                    .clipped()
                                    .cornerRadius(0)

                                // Video play icon overlay
                                if userImage.isVideo {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 32, height: 32)

                                        Image(systemName: "play.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            // Trigger loading more when we're 10 items from the end
                            if let index = userImages.firstIndex(where: {
                                $0.id == userImage.id
                            }),
                                index >= userImages.count - 10,
                                hasMorePages,
                                !isLoadingMore
                            {
                                onLoadMore()
                            }
                        }
                    } else if let url = URL(string: userImage.image_url) {
                        // Fallback for videos without thumbnails
                        Button {
                            onSelect(userImage)
                        } label: {
                            ZStack {
                                KFImage(url)
                                    .setProcessor(
                                        DownsamplingImageProcessor(
                                            size: targetSize)
                                    )
                                    .cacheMemoryOnly()
                                    .fade(duration: 0.2)
                                    .placeholder {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(
                                                Image(systemName: "video.fill")
                                                    .font(.title3)
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: itemWidth, height: itemHeight)
                                    .clipped()
                                    .cornerRadius(0)

                                if userImage.isVideo {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 32, height: 32)

                                        Image(systemName: "play.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            // Trigger loading more when we're 10 items from the end
                            if let index = userImages.firstIndex(where: {
                                $0.id == userImage.id
                            }),
                                index >= userImages.count - 10,
                                hasMorePages,
                                !isLoadingMore
                            {
                                onLoadMore()
                            }
                        }
                    }
                }

                // Loading indicator at the bottom when loading more
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                    .gridCellColumns(3)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(
            height: calculateHeight(
                for: userImages.count, isLoadingMore: isLoadingMore))
    }

    private func calculateHeight(for count: Int, isLoadingMore: Bool) -> CGFloat
    {
        let rows = ceil(Double(count) / 3.0)
        let horizontalPadding: CGFloat = 16
        let totalHorizontalSpacing = spacing * 2
        let availableWidth =
            UIScreen.main.bounds.width - (horizontalPadding * 2)
            - totalHorizontalSpacing
        let itemWidth = availableWidth / 3
        let baseHeight = CGFloat(rows) * (itemWidth * 1.4 + spacing)
        // Add extra height for loading indicator if loading more
        return baseHeight + (isLoadingMore ? 60 : 0)
    }
}
