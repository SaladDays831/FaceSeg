import SwiftUI

struct HorizontalImageGrid: View {
    let images: [UIImage]
    var action: ((Int) -> Void)
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(images.enumerated()), id: \.element) { i, image in
                    Image(uiImage: image)
                        .resizable()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.white)
                        )
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .clipped()
                        .onTapGesture {
                            action(i)
                        }
                }
            }
            .padding()
        }
    }
}
