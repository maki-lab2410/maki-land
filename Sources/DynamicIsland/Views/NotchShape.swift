import SwiftUI

public struct NotchShape: Shape {
    public var bottomRadius: CGFloat = 18
    public var earRadius: CGFloat = 8
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomRadius, earRadius) }
        set {
            bottomRadius = newValue.first
            earRadius = newValue.second
        }
    }
    
    public init(bottomRadius: CGFloat = 18, earRadius: CGFloat = 8) {
        self.bottomRadius = bottomRadius
        self.earRadius = earRadius
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let bRad = min(bottomRadius, rect.height / 2)
        let eRad = min(earRadius, (rect.width - bRad * 2) / 4)
        
        let leftEarCenterX = rect.minX
        let leftEarCenterY = rect.minY + eRad
        let rightEarCenterX = rect.maxX
        let rightEarCenterY = rect.minY + eRad
        
        // Start top-left ear origin (at screen top edge)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Left concave ear (from 270 to 360 deg)
        path.addArc(
            center: CGPoint(x: leftEarCenterX, y: leftEarCenterY),
            radius: eRad,
            startAngle: Angle(degrees: 270),
            endAngle: Angle(degrees: 360),
            clockwise: false
        )
        
        // Left straight wall
        path.addLine(to: CGPoint(x: rect.minX + eRad, y: rect.maxY - bRad))
        
        // Bottom-left convex corner
        path.addArc(
            center: CGPoint(x: rect.minX + eRad + bRad, y: rect.maxY - bRad),
            radius: bRad,
            startAngle: Angle(degrees: 180),
            endAngle: Angle(degrees: 90),
            clockwise: true
        )
        
        // Bottom flat edge
        path.addLine(to: CGPoint(x: rect.maxX - eRad - bRad, y: rect.maxY))
        
        // Bottom-right convex corner
        path.addArc(
            center: CGPoint(x: rect.maxX - eRad - bRad, y: rect.maxY - bRad),
            radius: bRad,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 0),
            clockwise: true
        )
        
        // Right straight wall
        path.addLine(to: CGPoint(x: rect.maxX - eRad, y: rect.minY + eRad))
        
        // Right concave ear
        path.addArc(
            center: CGPoint(x: rightEarCenterX, y: rightEarCenterY),
            radius: eRad,
            startAngle: Angle(degrees: 180),
            endAngle: Angle(degrees: 270),
            clockwise: false
        )
        
        // Close across the top edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
