import UIKit

public struct FaceSegResult {
    public let metadata: FaceSegMetadata
    
    /// Image with drawn paths around the detected faces
    public let debugImage: UIImage?
    
    /// Image with the segmented faces on a transparent background. The location/scale of the faces is preserved
    public let facesImage: UIImage?
    
    /// Original image with transparent holes instead of the detected faces
    public let cutoutFacesImage: UIImage?
    
    /// An array of detected faces as separate images
    public let facesInBoundingBoxes: [UIImage]?
}

extension FaceSegResult {
    static func noFaces() -> FaceSegResult {
        let metadata = FaceSegMetadata(faceCount: 0, boundingBoxes: [], landmarks: [], facePaths: [])
        return .init(metadata: metadata,
                     debugImage: nil,
                     facesImage: nil,
                     cutoutFacesImage: nil,
                     facesInBoundingBoxes: nil)
    }
}
