import UIKit
import Vision

public struct FaceSegResult {
    /// Image with drawn paths around the detected faces
    public let debugImage: UIImage?
    
    /// Image with the segmented faces on a transparent background. The location/scale of the faces is preserved
    public let facesImage: UIImage?
    
    /// Original image with transparent holes instead of the detected faces
    public let cutoutFacesImage: UIImage?
    
    
   // let segmentedFacesImages: [UIImage?]
}

public protocol FaceSegDelegate: AnyObject {
    func didFinishProcessing(_ result: FaceSegResult)
    func didFinishWithError(_ errorString: String)
}

public class FaceSeg {
    
    typealias FacePointArray = [CGPoint]
    
    public weak var delegate: FaceSegDelegate?
    
    public init() {}
    
    // MARK: - Public
    
    public func process(_ image: UIImage) {
        getObservations(from: image) { observations in
            let facesData = self.getFaceLandmarkPoints(faces: observations, image: image)
            let paths = self.createCurves(from: facesData)
            
            let debugImage = self.drawPaths(paths, on: image)
            let onlyFacesImage = self.drawOnlyFaces(facePaths: paths, image: image)
            let cutoutFacesImage = self.drawImageWithoutFaces(facePaths: paths, image: image)
            
            let result = FaceSegResult(debugImage: debugImage,
                                       facesImage: onlyFacesImage,
                                       cutoutFacesImage: cutoutFacesImage)
            
            self.delegate?.didFinishProcessing(result)
        }
    }
    
    // MARK: -  Private

    private func getObservations(from image: UIImage, completion: @escaping (([VNFaceObservation]) -> Void)) {
        guard let cgImage = image.cgImage else { fatalError() }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage,
                                                   orientation: getCGImageOrientation(from: image.imageOrientation),
                                                   options: [:])
        
        let request = VNDetectFaceLandmarksRequest { request, error in
            if let observations = request.results as? [VNFaceObservation] {
                completion(observations)
            } else {
                self.delegate?.didFinishWithError("Can't get VNFaceObservation array")
            }
        }
        
        #if targetEnvironment(simulator)
            print("SIM")
            request.usesCPUOnly = true
        #endif
        
        do {
            try requestHandler.perform([request])
        } catch {
            self.delegate?.didFinishWithError("VNDetectFaceLandmarksRequest error: \(error.localizedDescription)")
        }
    }
    
    private func getCGImageOrientation(from imageOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        /*
         let kCGImagePropertyOrientationUp: UInt32 = 1
         let kCGImagePropertyOrientationUpMirrored: UInt32 = 2
         let kCGImagePropertyOrientationDown: UInt32 = 3
         let kCGImagePropertyOrientationDownMirrored: UInt32 = 4
         let kCGImagePropertyOrientationLeft: UInt32 = 5
         let kCGImagePropertyOrientationLeftMirrored: UInt32 = 6
         let kCGImagePropertyOrientationRight: UInt32 = 7
         let kCGImagePropertyOrientationRightMirrored: UInt32 = 8
         */
        
        var orientation: Int32 = 0
        switch imageOrientation {
        case .up:
            orientation = 1
        case .right:
            orientation = 6
        case .down:
            orientation = 3
        case .left:
            orientation = 8
        default:
            orientation = 1
        }
        
        return CGImagePropertyOrientation(rawValue: CGImagePropertyOrientation.RawValue(orientation)) ?? .up
    }
    
    /// Returns an array of `FacePointArray`'s  (`[CGPoint]`)  that correspond to detected faces on the image
    private func getFaceLandmarkPoints(faces: [VNFaceObservation], image: UIImage) -> [FacePointArray] {
        var resultFaceData: [FacePointArray] = []
                
        for face in faces {
            var points: [CGPoint] = []
            
            // Add the face contour
            if let landmark = face.landmarks?.faceContour {
                for i in 0..<landmark.pointCount { // last point is 0,0
                    let point = convertFacePointToImageCoordinates(landmark.normalizedPoints[i], face: face, image: image)
                    points.append(point)
                }
            }

            guard
                let lastFacePointRaw = face.landmarks?.faceContour?.normalizedPoints.last,
                let firstFacePointRaw = face.landmarks?.faceContour?.normalizedPoints.first,
                let leftEyebrowEdgePointRaw = face.landmarks?.leftEyebrow?.normalizedPoints[0],
                let rightEyebrowEdgePointRaw = face.landmarks?.rightEyebrow?.normalizedPoints[0]
            else {
                fatalError()
            }
            
            let lastFacePoint = convertFacePointToImageCoordinates(lastFacePointRaw, face: face, image: image)
            let firstFacePoint = convertFacePointToImageCoordinates(firstFacePointRaw, face: face, image: image)
            
            let leftEyebrowEdgePointRaised = pointAlongLine(pointA: lastFacePointRaw, pointB: leftEyebrowEdgePointRaw)
            let rightEyebrowEdgePointRaised = pointAlongLine(pointA: firstFacePointRaw, pointB: rightEyebrowEdgePointRaw)
            
            let leftEyebrowControlPoint = convertFacePointToImageCoordinates(leftEyebrowEdgePointRaised, face: face, image: image)
            let rightEyebrowControlPoint = convertFacePointToImageCoordinates(rightEyebrowEdgePointRaised, face: face, image: image)
            
            // TODO: Add a point in the middle of the forehead. Between the eyebrows + raised
            
            let topFacePartPoints = [leftEyebrowControlPoint, rightEyebrowControlPoint, firstFacePoint]
            points.append(contentsOf: topFacePartPoints)
            
            resultFaceData.append(points)
        }
        
        return resultFaceData
    }
    
    /// Builds a smooth `UIBezierPath` using `addQuadCurve`/`addCurve` for each entry in the `data` array
    private func createCurves(from data: [FacePointArray]) -> [UIBezierPath] {
        var paths: [UIBezierPath] = []
        
        for facePoints in data {
            let pathBuilder = SmoothBezierPathBuilder()
            pathBuilder.contractionFactor = 0.5
            let path = pathBuilder.buildPath(through: facePoints)
            paths.append(path)
        }
        
        return paths
    }
    
    // MARK: - Drawing
    
    private func drawPaths(_ paths: [UIBezierPath], on image: UIImage) -> UIImage? {
//        let renderer = UIGraphicsImageRenderer(size: image.size)
//        
//        let finalImage = renderer.image { context in
//            // Draw the original image
//            image.draw(in: CGRect(origin: .zero, size: image.size))
//            
//            // Set up for drawing paths
//            context.cgContext.translateBy(x: 0, y: image.size.height)
//            context.cgContext.scaleBy(x: 1.0, y: -1.0)
//            
//            // Draw each path
//            for path in paths {
//                context.cgContext.addPath(path.cgPath)
//                context.cgContext.setStrokeColor(UIColor.yellow.cgColor)
//                context.cgContext.setLineWidth(8.0)
//                context.cgContext.drawPath(using: .stroke)
//            }
//        }
//        
//        return finalImage
        
        UIGraphicsBeginImageContextWithOptions(image.size, true, 0.0)
        
        guard let context = UIGraphicsGetCurrentContext() else { fatalError() }
        context.saveGState()
        
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        for path in paths {
            context.addPath(path.cgPath)
            context.setStrokeColor(UIColor.yellow.cgColor)
            context.setLineWidth(8.0)
            context.drawPath(using: .stroke)
        }
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        context.restoreGState()
        
        return finalImage
    }
    
    private func drawDots(_ dots: [CGPoint], on image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, true, 0.0)
        
        guard let context = UIGraphicsGetCurrentContext() else { fatalError() }
        context.saveGState()
        
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        for dot in dots {
            let radius: CGFloat = 8.0
            context.setFillColor(UIColor.systemPink.cgColor)
            context.addEllipse(in: CGRect(x: dot.x - radius, y: dot.y - radius, width: radius * 2, height: radius * 2))
            context.drawPath(using: .fill)
        }
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        context.restoreGState()
        
        return finalImage
    }
    
    private func drawOnlyFaces(facePaths: [UIBezierPath], image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale) // TODO: Figure this out (it's different in all funcs)
        
        guard let context = UIGraphicsGetCurrentContext() else { fatalError() }
        context.saveGState()
        
        image.draw(at: CGPoint.zero)
        
        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
        
        context.addRect(CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        for path in facePaths {
            context.addPath(path.cgPath)
        }
        context.drawPath(using: .eoFill)
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        context.restoreGState()
        
        return finalImage
    }
    
    private func drawImageWithoutFaces(facePaths: [UIBezierPath], image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        
        guard let context = UIGraphicsGetCurrentContext() else { fatalError() }
        context.saveGState()
        
        image.draw(at: CGPoint.zero)
        
        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
        
        for path in facePaths {
            context.addPath(path.cgPath)
            context.fillPath()
        }
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        context.restoreGState()
        
        return finalImage
    }
    
    // MARK: - Utility
    
    /// Returns a new point by moving pointB away from pointA by their distance along the line connecting the two points
    private func pointAlongLine(pointA: CGPoint, pointB: CGPoint) -> CGPoint {
        let dx = pointA.x - pointB.x
        let dy = pointA.y - pointB.y

        // distance between points A and B
        let distance = sqrt(dx * dx + dy * dy)

        // Normalize the direction vector
        let normalizedDx = dx / distance
        let normalizedDy = dy / distance

        let newX = pointB.x - normalizedDx * distance
        let newY = pointB.y - normalizedDy * distance

        return CGPoint(x: newX, y: newY)
    }
    
    /// Converts a given point from the coordinates of the faces' boundingBox to the coordinates on the image
    private func convertFacePointToImageCoordinates(_ point: CGPoint, face: VNFaceObservation, image: UIImage) -> CGPoint {
        let w = face.boundingBox.size.width * image.size.width
        let h = face.boundingBox.size.height * image.size.height
        let x = face.boundingBox.origin.x * image.size.width
        let y = face.boundingBox.origin.y * image.size.height
        
        return CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h)
    }
}
