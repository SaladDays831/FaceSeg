import SwiftUI


struct HorizontalImageGrid: View {
    let images: [UIImage]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(images, id: \.self) { image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: UIScreen.main.bounds.width - 10, height: 400)
                        .clipped()
                }
            }
            .padding(10)
            .background(Color.gray)
        }
    }
}

struct DemoView: View {
    
    @ObservedObject var viewModel = DemoViewModel()
    
    var body: some View {
        VStack {
            HStack {
                CoolButton(title: "Select Image") {
                    self.viewModel.sourceType = .photoLibrary
                    self.viewModel.showingImagePicker = true
                }

                CoolButton(title: "Open Camera") {
                    self.viewModel.sourceType = .camera
                    self.viewModel.showingImagePicker = true
                }
            }
            
            Spacer()
            
            HorizontalImageGrid(images: viewModel.processedImages ?? [viewModel.originalImage])
//            Image(uiImage: viewModel.modifiedImage ?? viewModel.originalImage)
//                .resizable()
//                .scaledToFit()
//                .frame(maxWidth: .infinity, maxHeight: 400)
//                .background(Color.gray)
//                .padding()
            
            Spacer()
            
            CoolButton(title: "Process", action: {
                self.viewModel.processImage()
            })
            .padding()
            
            CoolButton(title: "Reset") {
                self.viewModel.modifiedImage = nil
            }
            .opacity(viewModel.modifiedImage == nil ? 0 : 1)
        }
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePicker(image: $viewModel.originalImage, sourceType: self.viewModel.sourceType)
        }
    }
}

#Preview {
    DemoView()
}
