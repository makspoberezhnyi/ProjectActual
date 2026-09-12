import SwiftUI
import PhotosUI

/// Name and photo, the two things that make the app feel like it's actually yours
/// rather than the seed's placeholder person. Both bind straight to `@AppStorage`
/// and apply live — the same "no separate save step" pattern the appearance picker
/// already uses — since there's nothing here that benefits from a confirm step.
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("displayName") private var displayName = "Marta"
    @AppStorage("profilePhotoData") private var profilePhotoData: Data?

    @State private var pickerItem: PhotosPickerItem?
    @State private var isProcessingPhoto = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                VStack(spacing: 28) {
                    photoPicker

                    VStack(alignment: .leading, spacing: 8) {
                        Caption("Your name", size: 12.5)
                        TextField(
                            "",
                            text: $displayName,
                            prompt: Text("Your name").foregroundStyle(Theme.inkFaint)
                        )
                        .font(Typeface.title(22))
                        .foregroundStyle(Theme.ink)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        Hairline()
                    }

                    // This is the same name a shared reminder link carries as its
                    // "from" — changing it here changes what the next reminder says.
                    Text("Used on your reminder links, and in Home's greeting. Nothing here leaves the device on its own.")
                        .font(Typeface.body(12.5))
                        .foregroundStyle(Theme.inkFaint)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Padding.focused)
                .padding(.top, 36)

                Spacer()
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            isProcessingPhoto = true
            Task {
                defer { isProcessingPhoto = false }
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let processed = ProfilePhoto.processed(image)
                else { return }
                profilePhotoData = processed
            }
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Spacer()
            Caption("Edit profile")
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    private var photoPicker: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    avatar
                        .frame(width: 96, height: 96)
                        .opacity(isProcessingPhoto ? 0.5 : 1)

                    if isProcessingPhoto {
                        ProgressView()
                            .frame(width: 96, height: 96)
                    } else {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Theme.ink, Theme.card)
                            .background(Theme.bg, in: .circle)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change photo")

            if profilePhotoData != nil {
                Button("Remove photo") {
                    profilePhotoData = nil
                    pickerItem = nil
                }
                .font(Typeface.body(13))
                .foregroundStyle(Theme.inkFaint)
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var avatar: some View {
        Group {
            if let profilePhotoData, let uiImage = UIImage(data: profilePhotoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(.circle)
            } else {
                Text(ProfilePhoto.initial(for: displayName))
                    .font(Typeface.title(32))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 96, height: 96)
                    .background(Theme.card, in: .circle)
            }
        }
        .overlay { Circle().strokeBorder(Theme.line, lineWidth: 1) }
    }
}

/// Kept free of any one view: `ProfileView`'s header needs the same initial-letter
/// fallback and the same resize-and-compress step belongs wherever a photo is read
/// back in, not duplicated at each call site.
enum ProfilePhoto {
    static func initial(for name: String) -> String {
        guard let first = name.trimmingCharacters(in: .whitespaces).first else { return "?" }
        return String(first).uppercased()
    }

    /// Square-cropped and compressed before it ever reaches `UserDefaults` — a
    /// straight-from-the-library photo can run several megabytes, and nothing here
    /// needs more than a small avatar's worth of detail.
    static func processed(_ image: UIImage) -> Data? {
        let side: CGFloat = 240
        let target = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            let scale = max(side / image.size.width, side / image.size.height)
            let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (side - scaledSize.width) / 2, y: (side - scaledSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
