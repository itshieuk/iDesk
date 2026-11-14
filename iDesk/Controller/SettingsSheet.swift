import SwiftUI
import PhotosUI

/// Pointer / scroll speed, stored in UserDefaults (read by the trackpad on every use).
enum InputSettings {
    static let pointerKey = "iDesk.pointerSpeed"
    static let scrollKey = "iDesk.scrollSpeed"
    static let defaultPointer = 1.6
    static let defaultScroll = 2.2

    static var pointerSpeed: CGFloat {
        CGFloat(UserDefaults.standard.object(forKey: pointerKey) as? Double ?? defaultPointer)
    }
    static var scrollSpeed: CGFloat {
        CGFloat(UserDefaults.standard.object(forKey: scrollKey) as? Double ?? defaultScroll)
    }
}

/// Quick settings: brightness, wallpaper, pointer speed. (No volume: over HDMI/DisplayPort iOS sends audio at full
/// level and the display or TV sets the volume.)
struct SettingsSheet: View {
    @ObservedObject var model: DesktopModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(InputSettings.pointerKey) private var pointerSpeed = InputSettings.defaultPointer
    @AppStorage(InputSettings.scrollKey) private var scrollSpeed = InputSettings.defaultScroll
    @State private var phoneBrightness = Double(UIScreen.main.brightness)
    @State private var photo: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            List {
                Section("Brightness") {
                    labeled("External display", systemImage: "display") {
                        Slider(value: $model.externalBrightness, in: 0.2...1)
                    }
                    labeled("iPhone", systemImage: "iphone") {
                        Slider(value: $phoneBrightness, in: 0...1)
                            .onChange(of: phoneBrightness) { _, v in UIScreen.main.brightness = CGFloat(v) }
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
                    labeled("Pointer", systemImage: "cursorarrow.motionlines") {
                        Slider(value: $pointerSpeed, in: 0.6...4)
                    }
                    labeled("Scrolling", systemImage: "arrow.up.and.down") {
                        Slider(value: $scrollSpeed, in: 0.8...5)
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
        .onAppear { phoneBrightness = Double(UIScreen.main.brightness) }
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

