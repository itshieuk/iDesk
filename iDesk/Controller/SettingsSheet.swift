import SwiftUI
import PhotosUI

/// Pointer / scroll speed, stored in UserDefaults (read by the trackpad on every use).
enum InputSettings {
    static let pointerKey = "iDesk.pointerSpeed"
    static let scrollKey = "iDesk.scrollSpeed"
    static let naturalScrollingKey = "iDesk.naturalScrolling"
    static let defaultPointer = 1.6
    static let defaultScroll = 3.4

    static var pointerSpeed: CGFloat {
        CGFloat(UserDefaults.standard.object(forKey: pointerKey) as? Double ?? defaultPointer)
    }
    static var scrollSpeed: CGFloat {
        CGFloat(UserDefaults.standard.object(forKey: scrollKey) as? Double ?? defaultScroll)
    }

    /// Natural scrolling (as on a Mac or iPhone: the content follows the fingers / the wheel), or traditional
    /// (as on Windows: the other way round). For the trackpad, the mouse wheel and AssistiveTouch's wheel.
    static var naturalScrolling: Bool {
        get { UserDefaults.standard.object(forKey: naturalScrollingKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: naturalScrollingKey) }
    }

    /// Multiplies every scroll: 1 for natural scrolling, -1 for traditional.
    static var scrollDirection: CGFloat { naturalScrolling ? 1 : -1 }
}

/// Settings on the iPhone (used when no display is connected; with one, Settings opens on the desktop). (No volume: over HDMI/DisplayPort iOS sends audio at full
/// level and the display or TV sets the volume.)
struct SettingsSheet: View {
    @ObservedObject var model: DesktopModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(InputSettings.pointerKey) private var pointerSpeed = InputSettings.defaultPointer
    @AppStorage(InputSettings.scrollKey) private var scrollSpeed = InputSettings.defaultScroll
    @AppStorage(InputSettings.naturalScrollingKey) private var naturalScrolling = true
    @State private var photo: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            List {
                // The external display's brightness (an overlay iDesk draws): only with a display connected.
                if model.isExternalConnected {
                    Section("Brightness") {
                        labeled("External display", systemImage: "display") {
                            Slider(value: $model.externalBrightness, in: 0.2...1)
                        }
                    }
                }

                Section("Wallpaper") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(0..<Wallpapers.count, id: \.self) { i in
                                wallpaperTile(index: i)
                            }
                            if model.customWallpaper != nil {
                                wallpaperTile(index: -1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label("Choose a photo…", systemImage: "photo")
                    }
                    .onChange(of: photo) { _, item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                await MainActor.run { model.setCustomWallpaper(data) }
                            }
                            await MainActor.run { photo = nil }
                        }
                    }
                }

                Section {
                    Toggle(isOn: $model.autoHideTaskbar) {
                        Label("Auto-hide the taskbar", systemImage: "dock.arrow.down.rectangle")
                    }
                    Picker(selection: $model.maxWindows) {
                        Text("Automatic").tag(-1)
                        ForEach([2, 3, 4, 6, 8], id: \.self) { n in Text("\(n) windows").tag(n) }
                        Text("No limit").tag(0)
                    } label: {
                        Label("Open at most", systemImage: "macwindow.on.rectangle")
                    }
                } header: {
                    Text("Windows")
                } footer: {
                    Text("Every app runs inside iDesk, so many open windows make everything slower. Automatic lets you open windows while memory lasts and stops before iOS would close iDesk.")
                }

                Section {
                    labeled("Pointer", systemImage: "cursorarrow.motionlines") {
                        Slider(value: $pointerSpeed, in: 0.6...4)
                    }
                    labeled("Scrolling", systemImage: "arrow.up.and.down") {
                        Slider(value: $scrollSpeed, in: 0.8...5)
                    }
                    Picker(selection: $naturalScrolling) {
                        Text("Natural (Mac)").tag(true)
                        Text("Traditional (Windows)").tag(false)
                    } label: {
                        Label("Scroll direction", systemImage: "arrow.up.arrow.down")
                    }
                    Button("Reset to defaults") {
                        pointerSpeed = InputSettings.defaultPointer
                        scrollSpeed = InputSettings.defaultScroll
                    }
                } header: {
                    Text("Trackpad speed")
                } footer: {
                    Text("Applies to finger swipes on the trackpad and to GameController mice.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func labeled<Content: View>(_ title: LocalizedStringKey, systemImage: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage).font(.subheadline)
            content()
        }
        .padding(.vertical, 2)
    }

    private func wallpaperTile(index: Int) -> some View {
        let selected = model.wallpaper == index
        return Button {
            model.wallpaper = index
        } label: {
            WallpaperView(index: index, image: model.customWallpaper, watermark: false)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? Color.accentColor : Color.white.opacity(0.15), lineWidth: selected ? 3 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(index < 0 ? "Chosen photo" : "Wallpaper \(index + 1)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

