import SwiftUI
import FaceSeg

class DemoViewModel: ObservableObject {
    
    private let faceSeg = FaceSeg()
    
    @Published var originalImage = UIImage(resource: .demoImg) {
        didSet {
            modifiedImage = nil
        }
    }
    @Published var modifiedImage: UIImage?
    
    @Published var showingImagePicker = false
    @Published var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    init() {
        faceSeg.delegate = self
    }
    
    
    func requestDebugImage() {
        // faceSeg.debugImage(from: originalImage)
        faceSeg.process(originalImage)
    }
    
    func requestSegmentedFacesImage() {
       // faceSeg.segmentedFacesImage(from: originalImage)
    }
    
    func requestSeparateSegmentedFaceImages() {
        // faceSeg.segmentedFacesSeparateImages(from: originalImage)
    }

}

extension DemoViewModel: FaceSegDelegate {
    func didFinishProcessing(_ result: FaceSegResult) {
        modifiedImage = result.debugImage
    }
    
    func didFinishWithError(_ errorString: String) {
        print(errorString)
    }
}
