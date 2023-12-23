import Foundation

public enum FaceSegError {
    case imageConversionFailed
    case visionRequestFailed(visionErrorDescription: String)
    case observationMissingData
    case drawFacesInBoxesFailed(reason: String)
    
    public var errorString: String {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert provided UIImage to CGImage"
        case let .visionRequestFailed(error):
            return "VNRequest failed. Can't get VNFaceObservation array. \(error)"
        case .observationMissingData:
            return "VNFaceObservation is missing the data needed to build a facePath"
        case let .drawFacesInBoxesFailed(reason):
            return "drawFacesInBoundingBoxes() error: \(reason)"
        }
    }
}
