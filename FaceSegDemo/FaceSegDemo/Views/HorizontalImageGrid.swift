import SwiftUI

struct HorizontalImageGrid: View {
    let images: [UIImage]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(images, id: \.self) { image in
                    Image(uiImage: image)
                        .resizable()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.black)
                        )
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .clipped()
                }
            }
            .padding()
        }
    }
}
