import SwiftUI
import FaceSeg

class DemoViewModel: ObservableObject {
    
    private let faceSeg = FaceSeg()
    
    @Published var processedImages: [UIImage]?
    @Published var originalImage = UIImage(resource: .noFaces) {
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
                
        faceSeg.configuration = configuration
        faceSeg.delegate = self
    }
    
    func processImage() {
        faceSeg.process(originalImage)
    }

}

extension DemoViewModel: FaceSegDelegate {
    func didFinishProcessing(_ result: FaceSegResult) {
        print("Finished processing image. Metadata: \(result.metadata)")
        
        var images = [result.debugImage, result.facesImage, result.cutoutFacesImage].compactMap({$0})
        images.append(contentsOf: result.facesInBoundingBoxes ?? [])
        
        processedImages = images
    }
    
    func didFinishWithError(_ errorString: String) {
        print(errorString)
    }
}
