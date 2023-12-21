import UIKit
import Vision

public struct FaceSegResult {
    /// Image with drawn paths around the detected faces
    public let debugImage: UIImage?
    
    /// Image with the segmented faces on a transparent background. The location/scale of the faces is preserved
    public let facesImage: UIImage?
    
    /// Original image with transparent holes instead of the detected faces
    public let cutoutFacesImage: UIImage?
    
    /// An array of detected faces as separate images
    public let facesInBoundingBoxes: [UIImage]?
}

public protocol FaceSegDelegate: AnyObject {
    func didFinishProcessing(_ result: FaceSegResult)
    func didFinishWithError(_ errorString: String)
}

public class FaceSegConfiguration {
    var drawDebugImage = true
    var drawFacesImage = true
    var drawCutoutFacesImage = true
    var drawFacesInBoundingBoxes = true
    var faceInBoundingBoxImageHeight: CGFloat = 512
}

public class FaceSeg {
    
    typealias FacePointArray = [CGPoint]
    
    public var configuration = FaceSegConfiguration()
    
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
            let facesInBoxes = self.drawFacesInBoundingBoxes(observations: observations, facePaths: paths, image: image)
            
            let result = FaceSegResult(debugImage: debugImage,
                                       facesImage: onlyFacesImage,
                                       cutoutFacesImage: cutoutFacesImage,
                                       facesInBoundingBoxes: facesInBoxes)
            
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
                // TODO: Throw error if observations.isEmpty
                completion(observations)
            } else {
                // TODO: Check if I need to call completion in else
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
            
            // Face contour
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
            
            // TODO: Add a point in the middle of the forehead. Between the eyebrows + raised. An idea is to use the top point of the bounding box
            
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
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        let finalImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            
            context.cgContext.translateBy(x: 0, y: image.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            for path in paths {
                context.cgContext.addPath(path.cgPath)
                context.cgContext.setStrokeColor(UIColor.yellow.cgColor)
                context.cgContext.setLineWidth(8.0) // TODO: line width based on image size
                context.cgContext.drawPath(using: .stroke)
            }
        }
        
        return finalImage
    }
    
    private func drawDots(_ dots: [CGPoint], on image: UIImage) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        let finalImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            
            context.cgContext.translateBy(x: 0, y: image.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            let radius: CGFloat = 8.0
            
            for dot in dots {
                context.cgContext.setFillColor(UIColor.systemPink.cgColor)
                context.cgContext.addEllipse(in: CGRect(x: dot.x - radius, y: dot.y - radius, width: radius * 2, height: radius * 2))
                context.cgContext.drawPath(using: .fill)
            }
        }
        
        return finalImage
    }
    
    private func drawOnlyFaces(facePaths: [UIBezierPath], image: UIImage) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        
        let finalImage = renderer.image { context in
            image.draw(at: .zero)
                    
            context.cgContext.translateBy(x: 0, y: image.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            context.cgContext.setBlendMode(.clear)
            context.cgContext.setFillColor(UIColor.clear.cgColor)
            
            context.cgContext.addRect(CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
            for path in facePaths {
                context.cgContext.addPath(path.cgPath)
            }
            context.cgContext.drawPath(using: .eoFill)
        }
        
        return finalImage
    }
    
    private func drawImageWithoutFaces(facePaths: [UIBezierPath], image: UIImage) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        let finalImage = renderer.image { context in
            image.draw(at: .zero)
            
            context.cgContext.translateBy(x: 0, y: image.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            context.cgContext.setBlendMode(.clear)
            context.cgContext.setFillColor(UIColor.clear.cgColor)
            
            for path in facePaths {
                context.cgContext.addPath(path.cgPath)
                context.cgContext.fillPath()
            }
        }
        
        return finalImage
    }
    
    private func drawFacesInBoundingBoxes(observations: [VNFaceObservation], facePaths: [UIBezierPath], image: UIImage) -> [UIImage] {
        guard observations.count == facePaths.count else {
            delegate?.didFinishWithError("drawFacesInBoundingBoxes error: Observation count doesn't match facePath count")
            return []
        }

        guard let onlyFacesImage = drawOnlyFaces(facePaths: facePaths, image: image) else {
            delegate?.didFinishWithError("drawFacesInBoundingBoxes error: Can't draw segmented faces image")
            return []
        }

        var faceImages: [UIImage] = []
            
        faceImages.append(onlyFacesImage)

        observations.enumerated().forEach { i, obs in
            var box = obs.boundingBox

            // Convert from normalized to pixel coordinates
            box.origin.x *= image.size.width
            box.origin.y *= image.size.height
            box.size.width *= image.size.width
            box.size.height *= image.size.height

            // Adjust the y-coordinate for the CGImage's coordinate space
            box.origin.y = image.size.height - box.origin.y - box.height
            
            let targetSize = CGSize(width: configuration.faceInBoundingBoxImageHeight,
                                    height: configuration.faceInBoundingBoxImageHeight)
            
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let finalImage = renderer.image { context in
                context.cgContext.translateBy(x: 0, y: targetSize.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                
                if let croppedImage = onlyFacesImage.cgImage?.cropping(to: box) {
                    context.cgContext.draw(croppedImage, in: CGRect(origin: .zero, size: targetSize))
                } else {
                    delegate?.didFinishWithError("drawFacesInBoundingBoxes error: Failed to crop segmented image to bounding box")
                }
            }
            faceImages.append(finalImage)
        }

        return faceImages
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
