# Performance Analysis & Optimization Recommendations

## Executive Summary

After analyzing the files in the `Pages/` folder, I've identified several critical performance bottlenecks that are likely causing slow build times on your device. The main issues are:

1. **Profile.swift (3,360 lines)** - The largest file, containing multiple complex views
2. **Large hardcoded arrays** - Multiple files initialize large arrays at compile time
3. **Synchronous JSON loading** - JSON files loaded synchronously during initialization
4. **Complex view hierarchies** - Deeply nested views with many state variables
5. **Heavy computed properties** - Properties recalculated frequently

---

## 🔴 Critical Issues (Highest Priority)

### 1. Profile.swift - 3,360 Lines (MAJOR BOTTLENECK)

**Location:** `Pages/5 Profile/Profile.swift`

**Issues:**
- **Largest single file** in the Pages folder (3,360 lines)
- Contains **multiple large view structs** in a single file:
  - `Profile` (main view)
  - `ProfileViewContent` (complex state management)
  - `ImageGridView` (large grid implementation)
  - `PlaceholderImageCard` (complex animations)
  - `GalleryTabPill`, `ModelFilterChip`
  - `EmptyGalleryView`
  - `ImageModelsSheet`, `VideoModelsSheet`
  - `PlaceholderGrid`, `UnsignedInPlaceholderCard`
  - `SignInOverlay` (200+ lines of sign-in UI)
- **79 state variables** (`@State`, `@StateObject`, `@ObservedObject`)
- Complex computed properties that recalculate frequently
- Heavy view hierarchies with many nested components

**Impact:** This file is likely the **primary cause** of slow build times. Swift's type checker struggles with large files, especially those with many views and state variables.

**Recommendations:**
1. **Split into separate files:**
   - `ProfileMainView.swift` - Main Profile view
   - `ProfileViewContent.swift` - Content view
   - `ImageGridView.swift` - Grid implementation
   - `PlaceholderImageCard.swift` - Placeholder card
   - `ProfileSheets.swift` - ImageModelsSheet, VideoModelsSheet
   - `SignInOverlay.swift` - Sign-in UI
   - `ProfileComponents.swift` - Small reusable components

2. **Extract view models:**
   - Move complex state management to separate ViewModels
   - Reduce `@State` variables by grouping related state

3. **Use lazy loading:**
   - Load heavy components only when needed
   - Use `@ViewBuilder` more strategically

**Estimated Impact:** **50-70% build time reduction** for this file

---

### 2. Large Hardcoded Arrays at Compile Time

**Locations:**
- `VideoModelDetailPage.swift` (lines 153-184): `examplePrompts` - 30 items
- `VideoModelDetailPage.swift` (lines 186-212): `transformPrompts` - 25 items
- `ImageModelDetailPage.swift` (lines 79-110): `examplePrompts` - 30 items
- `ImageModelDetailPage.swift` (lines 112-138): `transformPrompts` - 25 items

**Issues:**
- Arrays initialized at compile time, increasing binary size
- Duplicated across multiple files
- Type checker must process all elements during compilation

**Recommendations:**
1. **Move to JSON files:**
   - Create `ExamplePrompts.json` and `TransformPrompts.json`
   - Load asynchronously when needed

2. **Create a shared service:**
   ```swift
   class PromptExamplesService {
       static let shared = PromptExamplesService()
       private var cachedExamples: [String]?
       
       func loadExamplePrompts() async -> [String] {
           if let cached = cachedExamples { return cached }
           // Load from JSON
           cachedExamples = await loadFromJSON()
           return cachedExamples ?? []
       }
   }
   ```

3. **Use lazy initialization:**
   ```swift
   private lazy var examplePrompts: [String] = {
       // Load from JSON or use defaults
   }()
   ```

**Estimated Impact:** **10-15% build time reduction**

---

### 3. Synchronous JSON Loading During Initialization

**Locations:**
- `ImageModelsPage.swift` (line 85): `ImageModelsViewModel.loadImageModels()`
- `VideoModelsPage.swift`: Similar pattern
- `PhotoFilters.swift`: Multiple JSON files loaded

**Issues:**
- JSON files loaded synchronously in `init()` methods
- Blocks main thread during view initialization
- Increases app startup time

**Recommendations:**
1. **Load asynchronously:**
   ```swift
   @Published private(set) var models: [InfoPacket] = []
   
   init() {
       Task {
           await loadModels()
       }
   }
   
   private func loadModels() async {
       let loaded = await ImageModelsViewModel.loadImageModels()
       await MainActor.run {
           models = loaded
       }
   }
   ```

2. **Cache at app level:**
   - Load once at app startup
   - Share across views

**Estimated Impact:** **5-10% startup time improvement**

---

## 🟡 Medium Priority Issues

### 4. Complex View Hierarchies

**Locations:**
- `VideoModelDetailPage.swift` (1,618 lines)
- `ImageModelDetailPage.swift` (1,168 lines)
- `PhotoFilterDetailView.swift` (1,064 lines)
- `PhotoConfirmationView.swift` (843 lines)

**Issues:**
- Deeply nested view hierarchies
- Many `LazyView` wrappers (which may not be necessary)
- Complex conditional rendering

**Recommendations:**
1. **Extract subviews:**
   - Break large views into smaller, focused components
   - Move to separate files

2. **Simplify conditionals:**
   - Use `@ViewBuilder` more effectively
   - Consider using enums for view states

3. **Remove unnecessary LazyView:**
   - `LazyView` adds overhead; only use when truly needed
   - SwiftUI's lazy loading is often sufficient

**Estimated Impact:** **10-20% build time reduction per file**

---

### 5. Heavy Computed Properties

**Locations:**
- `Profile.swift`: `computeModelsWithMetadata()`, `computeVideoModelsWithMetadata()`
- `VideoModelDetailPage.swift`: `currentPrice` (complex calculations)
- Multiple files with expensive computed properties

**Issues:**
- Computed properties recalculated on every view update
- Complex calculations in view body

**Recommendations:**
1. **Cache results:**
   ```swift
   @State private var cachedMetadata: [(model: String, count: Int, imageName: String)]?
   
   private var modelsWithMetadata: [(model: String, count: Int, imageName: String)] {
       if let cached = cachedMetadata { return cached }
       let computed = computeModelsWithMetadata()
       cachedMetadata = computed
       return computed
   }
   ```

2. **Move to ViewModel:**
   - Perform calculations in ViewModels
   - Update views only when results change

**Estimated Impact:** **5-10% runtime performance improvement**

---

## 🟢 Low Priority (Nice to Have)

### 6. Duplicate Code

**Locations:**
- `examplePrompts` and `transformPrompts` duplicated in multiple files
- Similar view structures across Image/Video detail pages

**Recommendations:**
- Create shared components
- Use protocols for common functionality

---

## 📊 File Size Breakdown

| File | Lines | Priority | Estimated Build Impact |
|------|-------|----------|----------------------|
| `Profile.swift` | 3,360 | 🔴 Critical | 50-70% of build time |
| `VideoModelDetailPage.swift` | 1,618 | 🟡 Medium | 10-15% |
| `ImageModelDetailPage.swift` | 1,168 | 🟡 Medium | 8-12% |
| `PhotoFilterDetailView.swift` | 1,064 | 🟡 Medium | 5-8% |
| `PhotoConfirmationView.swift` | 843 | 🟡 Medium | 3-5% |

---

## 🎯 Recommended Action Plan

### Phase 1: Immediate (Highest Impact)
1. **Split Profile.swift** into 6-8 smaller files
2. **Move hardcoded arrays** to JSON files
3. **Make JSON loading async**

### Phase 2: Short-term
4. **Extract subviews** from large detail pages
5. **Cache computed properties**
6. **Simplify view hierarchies**

### Phase 3: Long-term
7. **Refactor duplicate code**
8. **Optimize ViewModels**
9. **Add performance monitoring**

---

## 💡 Quick Wins

1. **Remove unnecessary `LazyView` wrappers** - They add overhead
2. **Use `@ViewBuilder`** more strategically
3. **Group related `@State` variables** into structs
4. **Lazy load heavy components** only when visible

---

## 📝 Notes

- Build times are primarily affected by:
  - **File size** (larger files = slower compilation)
  - **Type complexity** (many views/state = slower type checking)
  - **Compile-time initialization** (arrays, JSON loading)

- Runtime performance is affected by:
  - **View hierarchy depth**
  - **Computed property recalculation**
  - **Synchronous operations**

The **Profile.swift** file is almost certainly your biggest bottleneck. Splitting it should provide the most immediate improvement.

