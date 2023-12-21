import SwiftUI

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
            .padding()
            
            Spacer()
            
            Image(uiImage: viewModel.originalImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 400)
                .background(Color.secondary)
                .padding()
            
            if let images = viewModel.processedImages {
                HorizontalImageGrid(images: images)
            }
            
            Spacer()
            
            CoolButton(title: "Process", action: {
                self.viewModel.processImage()
            })
            .padding()
            
            CoolButton(title: "Reset") {
                self.viewModel.processedImages = nil
            }
            .opacity(viewModel.processedImages == nil ? 0 : 1)
        }
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePicker(image: $viewModel.originalImage, sourceType: self.viewModel.sourceType)
        }
    }
}

#Preview {
    DemoView()
}
