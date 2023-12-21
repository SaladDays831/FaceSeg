import SwiftUI
import FaceSeg

class DemoViewModel: ObservableObject {
    
    private let faceSeg = FaceSeg()
    
    @Published var processedImages: [UIImage]?
    @Published var originalImage = UIImage(resource: .face) {
        didSet {
            processedImages = nil
        }
    }
    
    @Published var showingImagePicker = false
    @Published var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    init() {
        let configuration = FaceSegConfiguration()
        configuration.drawDebugImage = true
        configuration.drawFacesImage = true
        configuration.drawCutoutFacesImage = true
        configuration.drawFacesInBoundingBoxes = true
        
        
        faceSeg.delegate = self
    }
    
    func processImage() {
        faceSeg.process(originalImage)
    }

}

extension DemoViewModel: FaceSegDelegate {
    func didFinishProcessing(_ result: FaceSegResult) {
        var images = [result.debugImage, result.facesImage, result.cutoutFacesImage].compactMap({$0})
        images.append(contentsOf: result.facesInBoundingBoxes ?? [])
        
        processedImages = images
    }
    
    func didFinishWithError(_ errorString: String) {
        print(errorString)
    }
}
