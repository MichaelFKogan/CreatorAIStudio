import SwiftUI

// MARK: - IMAGE MODELS SHEET

struct ImageModelsSheet: View {
    let models: [(model: String, count: Int, imageName: String)]
    @Binding var selectedModel: String?
    @Binding var selectedVideoModel: String?
    @Binding var selectedTab: ProfileViewContent.GalleryTab
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(models, id: \.model) { modelData in
                        Button {
                            selectedTab = .imageModels
                            selectedModel = modelData.model
                            selectedVideoModel = nil  // Clear video model selection
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                // Model image with fallback
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 65, height: 65)

                                    Image(modelData.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 65, height: 65)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 8))
                                }
                                .frame(width: 65, height: 65)

                                // Model name and count
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(modelData.model)
                                        .font(
                                            .system(
                                                size: 15, weight: .bold,
                                                design: .rounded)
                                        )
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)

                                    Text(
                                        "\(modelData.count) image\(modelData.count == 1 ? "" : "s")"
                                    )
                                    .font(
                                        .system(
                                            size: 12, weight: .medium,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.blue)
                                }

                                Spacer()

                                // Checkmark if selected
                                if selectedTab == .imageModels
                                    && selectedModel == modelData.model
                                {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(12)
                            .background(
                                selectedTab == .imageModels
                                    && selectedModel == modelData.model
                                    ? Color.blue.opacity(0.08)
                                    : Color.gray.opacity(0.06)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedTab == .imageModels
                                            && selectedModel == modelData.model
                                            ? Color.blue.opacity(0.3)
                                            : Color.gray.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Image Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - VIDEO MODELS SHEET

struct VideoModelsSheet: View {
    let models: [(model: String, count: Int, imageName: String)]
    @Binding var selectedModel: String?
    @Binding var selectedVideoModel: String?
    @Binding var selectedTab: ProfileViewContent.GalleryTab
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(models, id: \.model) { modelData in
                        Button {
                            selectedTab = .videoModels
                            selectedVideoModel = modelData.model
                            selectedModel = nil  // Clear image model selection
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                // Model image with fallback
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 65, height: 65)

                                    Image(modelData.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 65, height: 65)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 8))
                                }
                                .frame(width: 65, height: 65)

                                // Model name and count
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(modelData.model)
                                        .font(
                                            .system(
                                                size: 15, weight: .bold,
                                                design: .rounded)
                                        )
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)

                                    Text(
                                        "\(modelData.count) video\(modelData.count == 1 ? "" : "s")"
                                    )
                                    .font(
                                        .system(
                                            size: 12, weight: .medium,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.purple)
                                }

                                Spacer()

                                // Checkmark if selected
                                if selectedTab == .videoModels
                                    && selectedVideoModel == modelData.model
                                {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.purple)
                                }
                            }
                            .padding(12)
                            .background(
                                selectedTab == .videoModels
                                    && selectedVideoModel == modelData.model
                                    ? Color.purple.opacity(0.08)
                                    : Color.gray.opacity(0.06)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedTab == .videoModels
                                            && selectedVideoModel
                                                == modelData.model
                                            ? Color.purple.opacity(0.3)
                                            : Color.gray.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Video Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - PLAYLISTS SHEET

struct PlaylistsSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var selectedPlaylist: Playlist?
    @Binding var selectedModel: String?
    @Binding var selectedVideoModel: String?
    @Binding var selectedTab: ProfileViewContent.GalleryTab
    @Binding var isPresented: Bool
    
    @State private var showCreatePlaylist = false
    @State private var newPlaylistName = ""
    @State private var showRenameAlert = false
    @State private var playlistToRename: Playlist?
    @State private var renameText = ""
    @State private var showDeleteAlert = false
    @State private var playlistToDelete: Playlist?
    @FocusState private var isNameFieldFocused: Bool
    
    private let accentColor = Color.teal
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Create new playlist button
                    createPlaylistSection
                    
                    if viewModel.playlists.isEmpty && !viewModel.isLoadingPlaylists {
                        emptyStateView
                    } else {
                        playlistsList
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchPlaylists()
            }
        }
        .alert("Rename Playlist", isPresented: $showRenameAlert) {
            TextField("Playlist name", text: $renameText)
            Button("Cancel", role: .cancel) {
                renameText = ""
                playlistToRename = nil
            }
            Button("Rename") {
                if let playlist = playlistToRename {
                    Task {
                        await viewModel.renamePlaylist(playlistId: playlist.id, newName: renameText)
                    }
                }
                renameText = ""
                playlistToRename = nil
            }
        } message: {
            Text("Enter a new name for this collection")
        }
        .alert("Delete Playlist?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                playlistToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let playlist = playlistToDelete {
                    Task {
                        await viewModel.deletePlaylist(playlistId: playlist.id)
                        // Clear selection if deleted playlist was selected
                        if selectedPlaylist?.id == playlist.id {
                            selectedPlaylist = nil
                        }
                    }
                }
                playlistToDelete = nil
            }
        } message: {
            if let playlist = playlistToDelete {
                Text("Are you sure you want to delete '\(playlist.name)'? This cannot be undone.")
            }
        }
    }
    
    // MARK: - Create Playlist Section
    
    @ViewBuilder
    private var createPlaylistSection: some View {
        VStack(spacing: 12) {
            if showCreatePlaylist {
                HStack(spacing: 12) {
                    TextField("Collection name", text: $newPlaylistName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            createPlaylist()
                        }
                    
                    Button {
                        createPlaylist()
                    } label: {
                        Text("Create")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button {
                        withAnimation {
                            showCreatePlaylist = false
                            newPlaylistName = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .onAppear {
                    isNameFieldFocused = true
                }
            } else {
                Button {
                    withAnimation {
                        showCreatePlaylist = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(accentColor.opacity(0.15))
                                .frame(width: 65, height: 65)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(accentColor)
                        }
                        
                        Text("Create New Collection")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(accentColor)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(accentColor.opacity(0.6))
                    }
                    .padding(12)
                    .background(accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accentColor.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Collections Yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Create playlists to organize your photos into custom collections.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Playlists List
    
    @ViewBuilder
    private var playlistsList: some View {
        ForEach(viewModel.playlists) { playlist in
            playlistRow(playlist: playlist)
        }
    }
    
    @ViewBuilder
    private func playlistRow(playlist: Playlist) -> some View {
        let count = viewModel.playlistItemCounts[playlist.id] ?? 0
        let isSelected = selectedTab == .playlists && selectedPlaylist?.id == playlist.id
        
        Button {
            selectedTab = .playlists
            selectedPlaylist = playlist
            selectedModel = nil
            selectedVideoModel = nil
            isPresented = false
            
            // Fetch playlist images
            Task {
                await viewModel.fetchPlaylistImages(playlistId: playlist.id)
            }
        } label: {
            HStack(spacing: 12) {
                // Playlist icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 65, height: 65)
                    
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 24))
                        .foregroundColor(accentColor)
                }
                .frame(width: 65, height: 65)
                
                // Playlist name and count
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    Text("\(count) item\(count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(accentColor)
                }
                
                Spacer()
                
                // Checkmark if selected
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(accentColor)
                }
            }
            .padding(12)
            .background(isSelected ? accentColor.opacity(0.08) : Color.gray.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? accentColor.opacity(0.3) : Color.gray.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contextMenu {
            Button {
                playlistToRename = playlist
                renameText = playlist.name
                showRenameAlert = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                playlistToDelete = playlist
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createPlaylist() {
        let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        Task {
            await viewModel.createPlaylist(name: name)
            await MainActor.run {
                newPlaylistName = ""
                showCreatePlaylist = false
            }
        }
    }
}

// MARK: - ADD TO PLAYLIST SHEET

struct AddToPlaylistSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    let imageIds: [String]
    @Binding var isPresented: Bool
    var onComplete: (() -> Void)?
    
    @State private var selectedPlaylistIds: Set<String> = []
    @State private var showCreatePlaylist = false
    @State private var newPlaylistName = ""
    @State private var isAdding = false
    @FocusState private var isNameFieldFocused: Bool
    
    private let accentColor = Color.teal
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Create new playlist inline
                    createPlaylistSection
                    
                    if viewModel.playlists.isEmpty && !viewModel.isLoadingPlaylists {
                        emptyStateView
                    } else {
                        playlistSelectionList
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Add to Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        addToSelectedPlaylists()
                    } label: {
                        if isAdding {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Add")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(selectedPlaylistIds.isEmpty || isAdding)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchPlaylists()
                // Pre-select playlists that already contain the image(s)
                if imageIds.count == 1, let imageId = imageIds.first {
                    let existingPlaylists = await viewModel.getPlaylistsForImage(imageId: imageId)
                    await MainActor.run {
                        selectedPlaylistIds = Set(existingPlaylists)
                    }
                }
            }
        }
    }
    
    // MARK: - Create Playlist Section
    
    @ViewBuilder
    private var createPlaylistSection: some View {
        VStack(spacing: 12) {
            if showCreatePlaylist {
                HStack(spacing: 12) {
                    TextField("Playlist name", text: $newPlaylistName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            createPlaylistAndSelect()
                        }
                    
                    Button {
                        createPlaylistAndSelect()
                    } label: {
                        Text("Create")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button {
                        withAnimation {
                            showCreatePlaylist = false
                            newPlaylistName = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .onAppear {
                    isNameFieldFocused = true
                }
            } else {
                Button {
                    withAnimation {
                        showCreatePlaylist = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(accentColor.opacity(0.15))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(accentColor)
                        }
                        
                        Text("Create New Collection")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(accentColor)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accentColor.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Collections Yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Create a collection first to add this item.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Playlist Selection List
    
    @ViewBuilder
    private var playlistSelectionList: some View {
        ForEach(viewModel.playlists) { playlist in
            playlistSelectionRow(playlist: playlist)
        }
    }
    
    @ViewBuilder
    private func playlistSelectionRow(playlist: Playlist) -> some View {
        let count = viewModel.playlistItemCounts[playlist.id] ?? 0
        let isSelected = selectedPlaylistIds.contains(playlist.id)
        
        Button {
            if isSelected {
                selectedPlaylistIds.remove(playlist.id)
            } else {
                selectedPlaylistIds.insert(playlist.id)
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? accentColor : .gray.opacity(0.4))
                
                // Playlist icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 20))
                        .foregroundColor(accentColor)
                }
                
                // Playlist name and count
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(count) item\(count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(12)
            .background(isSelected ? accentColor.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Methods
    
    private func createPlaylistAndSelect() {
        let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        Task {
            if let newPlaylist = await viewModel.createPlaylist(name: name) {
                await MainActor.run {
                    selectedPlaylistIds.insert(newPlaylist.id)
                    newPlaylistName = ""
                    showCreatePlaylist = false
                }
            }
        }
    }
    
    private func addToSelectedPlaylists() {
        guard !selectedPlaylistIds.isEmpty else { return }
        
        isAdding = true
        
        Task {
            for playlistId in selectedPlaylistIds {
                await viewModel.addToPlaylist(playlistId: playlistId, imageIds: imageIds)
            }
            
            await MainActor.run {
                isAdding = false
                isPresented = false
                onComplete?()
            }
        }
    }
}

