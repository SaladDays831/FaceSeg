import SwiftUI

struct ImagePreview: View {
    var image: UIImage
    
    var body: some View {
        ZStack {
            Color(.black)
                .ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .border(Color.white)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
}
