import UIKit

class SmoothBezierPathBuilder {
    
    var contractionFactor: CGFloat = 0.7
    
    func buildPath(through points: [CGPoint]) -> UIBezierPath {
        assert(!points.isEmpty, "Can't draw a path with no CGPoints")
        assert(contractionFactor >= 0, "Please provide a positive contractionFactor")
        
        let path = UIBezierPath()
        path.move(to: points[0])
        
        if points.count < 3 {
            switch points.count {
            case 1:
                path.addLine(to: points[0])
            case 2:
                path.addLine(to: points[1])
            default:
                break
            }
            return path
        }
        
        var previousPoint = CGPoint.zero
        var previousCenterPoint = CGPoint.zero
        var centerPoint = CGPoint.zero
        var centerPointDistance = CGFloat()
        
        var obliqueAngle = CGFloat()
        
        var previousControlPoint1 = CGPoint.zero
        var previousControlPoint2 = CGPoint.zero
        var controlPoint1 = CGPoint.zero
        
        for i in 0..<points.count {
            
            let pointI = points[i]
            
            if i > 0 {
                previousCenterPoint = centerPointOf(point1: path.currentPoint, point2: previousPoint)
                centerPoint = centerPointOf(point1: previousPoint, point2: pointI)
                
                centerPointDistance = distanceBetween(point1: previousCenterPoint, point2: centerPoint)
                
                obliqueAngle = obliqueAngleOfStraightLineThrough(point1:centerPoint, point2:previousCenterPoint)
                
                previousControlPoint2 = CGPoint(x: previousPoint.x - 0.5 * contractionFactor * centerPointDistance * cos(obliqueAngle), y: previousPoint.y - 0.5 * contractionFactor * centerPointDistance * sin(obliqueAngle))
                controlPoint1 = CGPoint(x: previousPoint.x + 0.5 * contractionFactor * centerPointDistance * cos(obliqueAngle), y: previousPoint.y + 0.5 * contractionFactor * centerPointDistance * sin(obliqueAngle))
            }
            
            switch i {
            case 1 :
                path.addQuadCurve(to: previousPoint, controlPoint: previousControlPoint2)
            case 2 ..< points.count - 1 :
                path.addCurve(to: previousPoint, controlPoint1: previousControlPoint1, controlPoint2: previousControlPoint2)
            case points.count - 1 :
                path.addCurve(to: previousPoint, controlPoint1: previousControlPoint1, controlPoint2: previousControlPoint2)
                path.addQuadCurve(to: pointI, controlPoint: controlPoint1)
            default:
                break
            }
            
            previousControlPoint1 = controlPoint1
            previousPoint = pointI
        }
        
        return path
    }
    
    private func obliqueAngleOfStraightLineThrough(point1: CGPoint, point2: CGPoint) -> CGFloat {
        var obliqueRatio: CGFloat = 0
        var obliqueAngle: CGFloat = 0
        
        if (point1.x > point2.x) {
            obliqueRatio = (point2.y - point1.y) / (point2.x - point1.x)
            obliqueAngle = atan(obliqueRatio)
        }
        else if (point1.x < point2.x) {
            obliqueRatio = (point2.y - point1.y) / (point2.x - point1.x)
            obliqueAngle = CGFloat(Double.pi) + atan(obliqueRatio)
        }
        else if (point2.y - point1.y >= 0) {
            obliqueAngle = CGFloat(Double.pi)/2
        }
        else {
            obliqueAngle = -CGFloat(Double.pi)/2
        }
        
        return obliqueAngle
    }
    
    private func quadraticBezierControlPoint(point1: CGPoint, point2: CGPoint, point3: CGPoint) -> CGPoint {
        return CGPoint(x: (2 * point2.x - (point1.x + point3.x) / 2), y: (2 * point2.y - (point1.y + point3.y) / 2));
    }
    
    private func distanceBetween(point1: CGPoint, point2: CGPoint) -> CGFloat {
        return sqrt((point1.x - point2.x) * (point1.x - point2.x) + (point1.y - point2.y) * (point1.y - point2.y))
    }
    
    private func centerPointOf(point1: CGPoint, point2: CGPoint) -> CGPoint {
        return CGPoint(x: (point1.x + point2.x) / 2, y: (point1.y + point2.y) / 2)
    }
}
