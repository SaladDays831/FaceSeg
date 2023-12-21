import SwiftUI
import FaceSeg

class DemoViewModel: ObservableObject {
    
    private let faceSeg = FaceSeg()
    
    @Published var processedImages: [UIImage]?
    @Published var originalImage = UIImage(resource: .demoImg) {
        didSet {
            processedImages = nil
        }
    }
    
    @Published var showingImagePicker = false
    @Published var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    init() {
        faceSeg.delegate = self
    }
    
    func processImage() {
        faceSeg.process(originalImage)
    }

}

extension DemoViewModel: FaceSegDelegate {
    func didFinishProcessing(_ result: FaceSegResult) {
        //var images = [result.debugImage, result.facesImage, result.cutoutFacesImage].compactMap({$0})
       //images.append(contentsOf: result.facesInBoundingBoxes ?? [])
        
        var images = result.facesInBoundingBoxes
        processedImages = images
    }
    
    func didFinishWithError(_ errorString: String) {
        print(errorString)
    }
}
