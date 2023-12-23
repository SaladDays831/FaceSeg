import UIKit

public struct FaceSegMetadata {
    /// Number of detected faces
    public let faceCount: Int
    
    /// Array of CGRects around the detected faces
    public let boundingBoxes: [CGRect]
    
    /// Array containing the landmark point coordinates for each detected face
    public let landmarks: [[CGPoint]]
    
    /// Array of UIBezierPaths used to draw/segment the faces
    public let facePaths: [UIBezierPath]
}
