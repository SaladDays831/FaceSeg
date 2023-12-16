import UIKit
import Vision

struct FaceSegmentationResult {
    /// Original image with a line drawn around the face. Use for debugging
    let contourImage: UIImage?

    /// Segmented face on a transparent background
    let faceImage: UIImage?

    /// Original background, transparent face
    let backgroundImage: UIImage?

    /// Black background, white circles at face landmark coordinates
    let openPoseFaceImage: UIImage?

    /// Array of cut-out faces in their bounding boxes, scaled to 512x512 (to use with face restoration)
    let facesInBoxes: [UIImage]?
}

protocol FaceSegmentationDelegate: AnyObject {
    func didFinish(_ result: FaceSegmentationResult)
}

final class FaceSegmentation: NSObject {

    weak var delegate: FaceSegmentationDelegate?

    func process(_ image: UIImage) {
        guard let cgImage = image.cgImage else { fatalError() }

        let faceLandmarksRequest = VNDetectFaceLandmarksRequest { request, error in
            guard let observations = request.results as? [VNFaceObservation] else {
                fatalError("Unexpected face observation result type")
            }

            let paths = self.getFaceShapes(faces: observations, image: image)

            let openPoseImage = self.drawOpenPoseImage(faces: observations, image: image)

            let facesInBoxes = self.drawFacesInBoundingBoxes(observations: observations, facePaths: paths, image: image)

            let result = FaceSegmentationResult(contourImage: self.drawContourImage(faceShapes: paths, image: image),
                                                faceImage: self.drawFaceImage(faceShapes: paths, image: image),
                                                backgroundImage: self.drawBackgroundImage(faceShapes: paths, image: image),
                                                openPoseFaceImage: openPoseImage,
                                                facesInBoxes: facesInBoxes)


            self.delegate?.didFinish(result)
        }
        
        #if targetEnvironment(simulator)
            print("SIM")
            faceLandmarksRequest.usesCPUOnly = true
        #endif

        let requestHandler = VNImageRequestHandler(cgImage: cgImage,
                                                   orientation: getCGImageOrientation(from: image.imageOrientation),
                                                   options: [:])
        do {
            try requestHandler.perform([faceLandmarksRequest])
        } catch {
            print(error)
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

    /// Returns an array of `UIBezierPath`'s that correspond to detected faces on the image
    private func getFaceShapes(faces: [VNFaceObservation], image: UIImage) -> [UIBezierPath] {
        var faceShapes: [UIBezierPath] = []

        for face in faces {
            let faceShapePath = UIBezierPath()

            let w = face.boundingBox.size.width * image.size.width
            let h = face.boundingBox.size.height * image.size.height
            let x = face.boundingBox.origin.x * image.size.width
            let y = face.boundingBox.origin.y * image.size.height

            // Draw the face contour
            if let landmark = face.landmarks?.faceContour {
                for i in 0..<landmark.pointCount { // last point is 0,0
                    let point = landmark.normalizedPoints[i]
                    let pointOnImage = CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h)
                    if i == 0 {
                        faceShapePath.move(to: pointOnImage)
                    } else {
                        faceShapePath.addLine(to: pointOnImage)
                    }
                }
            }

            guard
                let lastFacePoint = face.landmarks?.faceContour?.normalizedPoints.last,
                let firstFacePoint = face.landmarks?.faceContour?.normalizedPoints.first
            else {
                fatalError()
            }

            // Face contour -> left eyebrow
            if let landmark = face.landmarks?.leftEyebrow {
                let edgePoint = landmark.normalizedPoints[0]
                let offsetEdgePoint = pointAlongLine(pointA: lastFacePoint, pointB: edgePoint)
                let edgePointOnImage = CGPoint(x: x + CGFloat(offsetEdgePoint.x) * w, y: y + CGFloat(offsetEdgePoint.y) * h)

                faceShapePath.addLine(to: edgePointOnImage)
            }

            // Left eyebrow -> right eyebrow
            if let landmark = face.landmarks?.rightEyebrow {
                let edgePoint = landmark.normalizedPoints[0]
                let offsetEdgePoint = pointAlongLine(pointA: firstFacePoint, pointB: edgePoint)
                let edgePointOnImage = CGPoint(x: x + CGFloat(offsetEdgePoint.x) * w, y: y + CGFloat(offsetEdgePoint.y) * h)

                faceShapePath.addLine(to: edgePointOnImage)
            }

            // Right eyebrow -> face contour
            faceShapePath.close()

            faceShapes.append(faceShapePath)
        }

        return faceShapes
    }

    private func drawOpenPoseImage(faces: [VNFaceObservation], image: UIImage) -> UIImage? {

        var pointsToDraw: [CGPoint] = []

        for face in faces {
            let w = face.boundingBox.size.width * image.size.width
            let h = face.boundingBox.size.height * image.size.height
            let x = face.boundingBox.origin.x * image.size.width
            let y = face.boundingBox.origin.y * image.size.height

            let allLandmarks: [VNFaceLandmarkRegion2D?] = [
                face.landmarks?.faceContour,
                face.landmarks?.noseCrest,
                face.landmarks?.innerLips,
                face.landmarks?.outerLips,
                face.landmarks?.leftEyebrow,
                face.landmarks?.leftEye,
                face.landmarks?.leftPupil,
                face.landmarks?.rightEyebrow,
                face.landmarks?.rightEye,
                face.landmarks?.rightPupil
            ]

            for landmark in allLandmarks {
                if let points = landmark?.normalizedPoints {
                    let pointsOnImage = points.map({ CGPoint(x: x + CGFloat($0.x) * w, y: y + CGFloat($0.y) * h) })
                    pointsToDraw.append(contentsOf: pointsOnImage)
                }
            }
        }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { fatalError() }

        let bgImage = UIImage() //UIColor.black.image()
        bgImage.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))

        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        let circleColor = UIColor.white
        circleColor.setFill()

        for point in pointsToDraw {
            let circlePath = UIBezierPath(arcCenter: point, radius: 5.0, startAngle: 0.0, endAngle: CGFloat.pi * 2.0, clockwise: true)
            circlePath.fill()
        }

        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return finalImage
    }

    private func drawContourImage(faceShapes: [UIBezierPath], image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, true, 0.0)

        guard let context = UIGraphicsGetCurrentContext() else { fatalError() }
        context.saveGState()

        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))

        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        for faceShape in faceShapes {
            context.addPath(faceShape.cgPath)
            context.setStrokeColor(UIColor.yellow.cgColor)
            context.setLineWidth(8.0)
            context.drawPath(using: .stroke)
        }

        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        context.restoreGState()

        return finalImage
    }

    private func drawBackgroundImage(faceShapes: [UIBezierPath], image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)

        guard let context = UIGraphicsGetCurrentContext() else { fatalError() }
        context.saveGState()

        image.draw(at: CGPoint.zero)

        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)

        for path in faceShapes {
            context.addPath(path.cgPath)
            context.fillPath()
        }

        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        context.restoreGState()

        return finalImage
    }

    private func drawFaceImage(faceShapes: [UIBezierPath], image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)

        guard let context = UIGraphicsGetCurrentContext() else { fatalError() }
        context.saveGState()

        image.draw(at: CGPoint.zero)

        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)

        context.addRect(CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        for path in faceShapes {
            context.addPath(path.cgPath)
        }
        context.drawPath(using: .eoFill)

        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        context.restoreGState()

        return finalImage
    }

    private func drawFacesInBoundingBoxes(observations: [VNFaceObservation], facePaths: [UIBezierPath], image: UIImage) -> [UIImage] {
        guard observations.count == facePaths.count else {
            fatalError("Observation count doesn't match facePaths count")
        }

        guard let onlyFacesImage = drawFaceImage(faceShapes: facePaths, image: image) else { fatalError() }

        var faceImages: [UIImage] = []

        observations.enumerated().forEach { i, obs in
            var box = obs.boundingBox

            // Convert from normalized to pixel coordinates
            box.origin.x *= image.size.width
            box.origin.y *= image.size.height
            box.size.width *= image.size.width
            box.size.height *= image.size.height

            // Adjust the y-coordinate for the CGImage's coordinate space
            box.origin.y = image.size.height - box.origin.y - box.height

            guard let croppedCGImage = onlyFacesImage.cgImage?.cropping(to: box) else {
                fatalError()
            }

            UIGraphicsBeginImageContextWithOptions(CGSize(width: 512, height: 512), false, image.scale)

            UIImage(cgImage: croppedCGImage).draw(in: CGRect(x: 0, y: 0, width: 512, height: 512))

            if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                faceImages.append(resizedImage)
            }

            UIGraphicsEndImageContext()
        }

        return faceImages
    }

    /// Returns a new point by moving pointB away from pointA by their distance along the line connecting the two points
    func pointAlongLine(pointA: CGPoint, pointB: CGPoint) -> CGPoint {
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

}
