import UIKit
import Vision

public protocol FaceSegDelegate: AnyObject {
    func didFinishProcessing(_ result: FaceSegResult)
    func didFinishWithError(_ error: FaceSegError)
}

public class FaceSeg {
        
    public var configuration = FaceSegConfiguration()
    
    public weak var delegate: FaceSegDelegate?
    
    public init() {}
    
    // MARK: - Public
    
    public func process(_ image: UIImage) {
        getObservations(from: image) { observations in
            let landmarks = self.getFaceLandmarkPoints(faces: observations, image: image)
            let paths = self.createCurves(from: landmarks)
            let boundingBoxes = observations.map({ self.convertBoundingBoxToImageCoordinates($0.boundingBox, image: image) })
            
            let metadata = FaceSegMetadata(faceCount: observations.count,
                                           boundingBoxes: boundingBoxes,
                                           landmarks: landmarks,
                                           facePaths: paths)
            
            var debugImage: UIImage?
            if self.configuration.drawDebugImage {
                debugImage = self.drawDebugImage(boxes: boundingBoxes, paths: paths, landmarks: landmarks, image: image)
            }
            
            var onlyFacesImage: UIImage?
            if self.configuration.drawFacesImage {
                onlyFacesImage = self.drawOnlyFaces(facePaths: paths, image: image)
            }
            
            var cutoutFacesImage: UIImage?
            if self.configuration.drawCutoutFacesImage {
                cutoutFacesImage = self.drawImageWithoutFaces(facePaths: paths, image: image)
            }
            
            var facesInBoxes: [UIImage]?
            if self.configuration.drawFacesInBoundingBoxes {
                facesInBoxes = self.drawFacesInBoundingBoxes(observations: observations, facePaths: paths, image: image)
            }
            
            let result = FaceSegResult(metadata: metadata,
                                       debugImage: debugImage,
                                       facesImage: onlyFacesImage,
                                       cutoutFacesImage: cutoutFacesImage,
                                       facesInBoundingBoxes: facesInBoxes)
            
            self.delegate?.didFinishProcessing(result)
        }
    }
    
    // MARK: -  Private

    private func getObservations(from image: UIImage, completion: @escaping (([VNFaceObservation]) -> Void)) {
        guard let cgImage = image.cgImage else {
            delegate?.didFinishWithError(.imageConversionFailed)
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage,
                                                   orientation: getCGImageOrientation(from: image.imageOrientation),
                                                   options: [:])
        
        let request = VNDetectFaceLandmarksRequest { request, error in
            guard let observations = request.results as? [VNFaceObservation] else {
                self.delegate?.didFinishWithError(.visionRequestFailed(visionErrorDescription: error?.localizedDescription ?? "Unknown"))
                return
            }
            guard !observations.isEmpty else {
                self.delegate?.didFinishProcessing(FaceSegResult.noFaces())
                return
            }
            completion(observations)
        }
        
        
        #if targetEnvironment(simulator)
            print("""
                Running on simulator, this will cause incorrect results.
                Please refer to this forum post:
                https://developer.apple.com/forums/thread/690605
            """)
            request.usesCPUOnly = true
        #endif
        
        do {
            try requestHandler.perform([request])
        } catch {
            self.delegate?.didFinishWithError(.visionRequestFailed(visionErrorDescription: error.localizedDescription))
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
    private func getFaceLandmarkPoints(faces: [VNFaceObservation], image: UIImage) -> [[CGPoint]] {
        var resultFaceData: [[CGPoint]] = []
                
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
                delegate?.didFinishWithError(.observationMissingData)
                return []
            }
            
            let lastFacePoint = convertFacePointToImageCoordinates(lastFacePointRaw, face: face, image: image)
            let firstFacePoint = convertFacePointToImageCoordinates(firstFacePointRaw, face: face, image: image)
            
            let leftEyebrowEdgePointRaised = pointAlongLine(pointA: lastFacePointRaw, pointB: leftEyebrowEdgePointRaw)
            let rightEyebrowEdgePointRaised = pointAlongLine(pointA: firstFacePointRaw, pointB: rightEyebrowEdgePointRaw)
            
            let leftEyebrowControlPoint = convertFacePointToImageCoordinates(leftEyebrowEdgePointRaised, face: face, image: image)
            let rightEyebrowControlPoint = convertFacePointToImageCoordinates(rightEyebrowEdgePointRaised, face: face, image: image)
            
            // TODO: Add a point in the middle of the forehead. Between the eyebrows + raised. Not sure I need this, tilted faces will have problems
            
            let topFacePartPoints = [leftEyebrowControlPoint, rightEyebrowControlPoint, firstFacePoint]
            points.append(contentsOf: topFacePartPoints)
            
            resultFaceData.append(points)
        }
        
        return resultFaceData
    }
    
    /// Builds a smooth `UIBezierPath` using `addQuadCurve`/`addCurve` for each entry in the `data` array
    private func createCurves(from data: [[CGPoint]]) -> [UIBezierPath] {
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
    
    private func drawDebugImage(boxes: [CGRect], paths: [UIBezierPath], landmarks: [[CGPoint]], image: UIImage) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        let finalImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            
            var lineWidths: [CGFloat] = []
            
            // Draw the boxes before applying the context transformation, as the rects are already adjusted
            for box in boxes {
                context.cgContext.addRect(box)
                context.cgContext.setStrokeColor(UIColor.red.cgColor)
                let lineWidth = getStrokeLineWidth(for: box)
                lineWidths.append(lineWidth)
                context.cgContext.setLineWidth(lineWidth)
                context.cgContext.drawPath(using: .stroke)
            }
            
            context.cgContext.translateBy(x: 0, y: image.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            for (i, path) in paths.enumerated() {
                context.cgContext.addPath(path.cgPath)
                context.cgContext.setStrokeColor(UIColor.systemPink.cgColor)
                context.cgContext.setLineWidth(lineWidths[i])
                context.cgContext.drawPath(using: .stroke)
            }
            
            for (i, landmarkArray) in landmarks.enumerated() {
                let radius = lineWidths[i]
                for point in landmarkArray {
                    context.cgContext.setFillColor(UIColor.green.cgColor)
                    context.cgContext.addEllipse(in: CGRect(x: point.x - radius,
                                                            y: point.y - radius,
                                                            width: radius * 2,
                                                            height: radius * 2))
                    context.cgContext.drawPath(using: .fill)
                }
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
            delegate?.didFinishWithError(.drawFacesInBoxesFailed(reason: "Observation count doesn't match facePath count"))
            return []
        }

        guard let onlyFacesImage = drawOnlyFaces(facePaths: facePaths, image: image) else {
            delegate?.didFinishWithError(.drawFacesInBoxesFailed(reason: "Can't draw segmented faces image"))
            return []
        }

        var faceImages: [UIImage] = []
            
        observations.enumerated().forEach { i, obs in
            let box = convertBoundingBoxToImageCoordinates(obs.boundingBox, image: image)
            
            let targetSize = CGSize(width: configuration.faceInBoundingBoxImageHeight,
                                    height: configuration.faceInBoundingBoxImageHeight)
            
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let finalImage = renderer.image { context in
                context.cgContext.translateBy(x: 0, y: targetSize.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                
                if let croppedImage = onlyFacesImage.cgImage?.cropping(to: box) {
                    context.cgContext.draw(croppedImage, in: CGRect(origin: .zero, size: targetSize))
                } else {
                    delegate?.didFinishWithError(.drawFacesInBoxesFailed(reason: "Failed to crop segmented image to bounding box"))
                }
            }
            faceImages.append(finalImage)
        }

        return faceImages
    }
    
    // MARK: - Utility
    
    /// Returns a siutable stroke line width to use with the debug image
    private func getStrokeLineWidth(for box: CGRect) -> CGFloat {
        let refWidth: CGFloat = 530
        let refLineWidth: CGFloat = 10
        return box.height * refLineWidth / refWidth
    }
    
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
    
    private func convertBoundingBoxToImageCoordinates(_ boxRaw: CGRect, image: UIImage) -> CGRect {
        var box = boxRaw
        
        // Convert from normalized to pixel coordinates
        box.origin.x *= image.size.width
        box.origin.y *= image.size.height
        box.size.width *= image.size.width
        box.size.height *= image.size.height

        // Adjust the y-coordinate for the CGImage's coordinate space
        box.origin.y = image.size.height - box.origin.y - box.height
        
        return box
    }
}
