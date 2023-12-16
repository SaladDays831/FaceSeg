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
            
            Image(uiImage: viewModel.modifiedImage ?? viewModel.originalImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 400)
                .background(Color.gray)
                .padding()
            
            VStack(alignment: .leading) {
                HStack {
                    CoolButton(title: "Debug") {
                        viewModel.requestDebugImage()
                    }
                    Text("Draw lines and bounding boxes on the original image")
                        .font(.footnote)
                }
                HStack {
                    CoolButton(title: "Segment") {
                        viewModel.requestSegmentedFacesImage()
                    }
                    Text("Segment the faces and composite on a transparent background (preserve the locations/scales)")
                        .font(.footnote)
                }
                HStack {
                    CoolButton(title: "Segment + scale") {
                        viewModel.requestSeparateSegmentedFaceImages()
                    }
                    Text("Segment the faces and return a separate image for each face")
                        .font(.footnote)
                }
            }
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
