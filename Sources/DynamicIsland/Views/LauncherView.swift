import SwiftUI
import UniformTypeIdentifiers

public struct LauncherView: View {
    @ObservedObject var launcherService = LauncherService.shared
    @State private var showingWebForm = false
    @State private var isEditMode = false
    @State private var renamingItem: LauncherItem? = nil
    @State private var renameText = ""
    @State private var newName = ""
    @State private var newUrl = ""
    @State private var isDropTargeted = false

    public init() {}

    public var body: some View {
        VStack(spacing: 6) {
            // Top Action Header
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.cyan)
                    Text(isEditMode ? "Mode Atur Pintasan" : "Quick Launch")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                // Primary Button: Pick App from Finder (/Applications)
                Button {
                    launcherService.pickApplicationsFromFinder()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.app.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Pilih Aplikasi")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.blue.opacity(0.28))
                    .foregroundColor(.cyan)
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.35), lineWidth: 0.5))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Add Web Link Button
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        renamingItem = nil
                        showingWebForm.toggle()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "globe")
                            .font(.system(size: 9.5, weight: .semibold))
                        Text("+ Web")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(showingWebForm ? Color.white.opacity(0.22) : Color.white.opacity(0.09))
                    .foregroundColor(.white.opacity(0.85))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Edit / Arrange Toggle
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        isEditMode.toggle()
                        showingWebForm = false
                        renamingItem = nil
                    }
                } label: {
                    Text(isEditMode ? "Selesai" : "Atur")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(isEditMode ? Color.orange : Color.white.opacity(0.09))
                        .foregroundColor(isEditMode ? .black : .white.opacity(0.75))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if let itemToRename = renamingItem {
                // Inline Rename Bar
                HStack(spacing: 8) {
                    Text("Nama baru:")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))

                    TextField("Nama pintasan", text: $renameText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.10))
                        .cornerRadius(6)
                        .onSubmit {
                            launcherService.rename(id: itemToRename.id, newName: renameText)
                            renamingItem = nil
                        }

                    Button {
                        launcherService.rename(id: itemToRename.id, newName: renameText)
                        renamingItem = nil
                    } label: {
                        Text("Simpan")
                            .font(.system(size: 10.5, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        renamingItem = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            } else if showingWebForm {
                // Inline Add Web / Path Shortcut Form
                HStack(spacing: 8) {
                    TextField("Nama (mis: Notion)", text: $newName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.09))
                        .cornerRadius(6)
                        .frame(width: 135)

                    TextField("URL atau Path (https://...)", text: $newUrl)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.09))
                        .cornerRadius(6)
                        .onSubmit { submitWebShortcut() }

                    Button {
                        submitWebShortcut()
                    } label: {
                        Text("Simpan")
                            .font(.system(size: 10.5, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || newUrl.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button {
                        showingWebForm = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            } else {
                // Shortcuts Horizontal Grid
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 11) {
                        ForEach(launcherService.items) { item in
                            launcherItemCell(item)
                        }

                        // Quick Add App Tile at end of list
                        Button {
                            launcherService.pickApplicationsFromFinder()
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .stroke(
                                            isDropTargeted ? Color.cyan : Color.white.opacity(0.22),
                                            style: StrokeStyle(lineWidth: 1.2, dash: [4])
                                        )
                                        .frame(width: 44, height: 44)

                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(isDropTargeted ? .cyan : .white.opacity(0.55))
                                }

                                Text("Aplikasi")
                                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(.vertical, 3)
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            launcherService.addFromFileURLs([url])
                        }
                    }
                }
            }
            return true
        }
    }

    private func submitWebShortcut() {
        launcherService.addWebOrPath(name: newName, urlOrPath: newUrl)
        newName = ""
        newUrl = ""
        showingWebForm = false
    }

    @ViewBuilder
    private func launcherItemCell(_ item: LauncherItem) -> some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                Button {
                    if isEditMode {
                        launcherService.pickApplicationsFromFinder(replacingId: item.id)
                    } else {
                        launcherService.launch(item)
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.white.opacity(item.isWeb ? 0.12 : 0.08))
                            .frame(width: 44, height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(isEditMode ? Color.orange.opacity(0.55) : Color.white.opacity(0.14), lineWidth: 0.7)
                            )

                        if let nsIcon = launcherService.nativeIcon(for: item) {
                            Image(nsImage: nsIcon)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 34, height: 34)
                        } else {
                            Image(systemName: item.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                if isEditMode {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            launcherService.delete(id: item.id)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white, .red)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                }
            }

            if isEditMode {
                HStack(spacing: 6) {
                    Button {
                        withAnimation { launcherService.move(id: item.id, offset: -1) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)

                    Text(item.name)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                        .frame(maxWidth: 36)

                    Button {
                        withAnimation { launcherService.move(id: item.id, offset: 1) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(item.name)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.88))
                    .lineLimit(1)
                    .frame(maxWidth: 54)
            }
        }
        .contextMenu {
            Button("Buka \(item.name)") {
                launcherService.launch(item)
            }
            Button("Ganti dengan Aplikasi di Finder...") {
                launcherService.pickApplicationsFromFinder(replacingId: item.id)
            }
            Button("Ubah Nama...") {
                renameText = item.name
                renamingItem = item
            }
            Divider()
            Button("Geser ke Kiri") {
                launcherService.move(id: item.id, offset: -1)
            }
            Button("Geser ke Kanan") {
                launcherService.move(id: item.id, offset: 1)
            }
            if !item.isWeb {
                Button("Tampilkan di Finder") {
                    launcherService.revealInFinder(item)
                }
            }
            Divider()
            Button(role: .destructive) {
                launcherService.delete(id: item.id)
            } label: {
                Label("Hapus Pintasan", systemImage: "trash")
            }
        }
    }
}
