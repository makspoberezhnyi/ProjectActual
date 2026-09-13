import SwiftUI
import SpriteKit

// MARK: - The "Pet" / Core Gem Object
struct CoreObjectView: View {
    var calibrationScore: Double
    var isRunning: Bool
    
    @State private var phase: CGFloat = 0
    @State private var rotationZ: Double = 0
    @State private var rotationY: Double = 0
    @State private var floatOffset: CGFloat = 0
    
    var body: some View {
        let primaryColor = calibrationScore >= 0.8 ? Theme.brandMint : (calibrationScore >= 0.6 ? Color.orange : Theme.brandCoral)
        let secondaryColor = calibrationScore >= 0.8 ? Color.cyan : (calibrationScore >= 0.6 ? Theme.brandCoral : Color.purple)
        
        ZStack {
            // Ambient Aura (large diffused glow)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [primaryColor.opacity(0.35), secondaryColor.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .scaleEffect(isRunning ? 1.15 : 1.0 + sin(phase) * 0.06)
                .blur(radius: 20)
            
            // Outer Orbital Glass Rings (Rotating in 3D)
            Group {
                Ellipse()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), primaryColor.opacity(0.7), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 170, height: 75)
                    .rotationEffect(.degrees(rotationZ))
                    .rotation3DEffect(.degrees(65), axis: (x: 1, y: 0.3, z: 0))
                
                Ellipse()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), secondaryColor.opacity(0.6), .clear],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        ),
                        lineWidth: 1.0
                    )
                    .frame(width: 150, height: 60)
                    .rotationEffect(.degrees(-rotationZ * 0.8))
                    .rotation3DEffect(.degrees(55), axis: (x: -0.4, y: 1, z: 0.2))
            }
            
            // Core Geometric Crystal / Prism
            ZStack {
                // Background Depth Facet
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [primaryColor.opacity(0.8), secondaryColor.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 105, height: 105)
                    .rotationEffect(.degrees(45 + rotationY * 0.2))
                    .blur(radius: 4)
                
                // Foreground Glass Prism
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                primaryColor,
                                secondaryColor.opacity(0.85),
                                primaryColor.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 95, height: 95)
                    .rotationEffect(.degrees(45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.9), .white.opacity(0.2), primaryColor.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.0
                            )
                    )
                    .shadow(color: primaryColor.opacity(0.5), radius: 24, x: 0, y: 0)
                
                // Inner Glowing Nucleus
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .blur(radius: 6)
                    .offset(x: -12, y: -12)
                
                // Subtle Facet Lines for Crystal Feel
                Path { path in
                    path.move(to: CGPoint(x: 10, y: 47))
                    path.addLine(to: CGPoint(x: 47, y: 10))
                    path.addLine(to: CGPoint(x: 85, y: 47))
                    path.addLine(to: CGPoint(x: 47, y: 85))
                    path.closeSubpath()
                }
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                .frame(width: 95, height: 95)
            }
            .scaleEffect(1.0 + cos(phase * 1.5) * 0.04)
        }
        .offset(y: floatOffset)
        .onAppear {
            withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
                rotationZ = 360
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatOffset = -14
                rotationY = 20
            }
        }
    }
}

// MARK: - SpriteKit Physics Scene (Elegant Glass Beads)

class SandScene: SKScene {
    var isPouring: Bool = false {
        didSet {
            if isPouring { startPouring() }
            else { stopPouring() }
        }
    }
    
    private var emitTimer: Timer?
    private var isInitialized = false
    
    override func didMove(to view: SKView) {
        guard !isInitialized else { return }
        isInitialized = true
        
        self.backgroundColor = .clear
        self.physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        
        let floor = SKShapeNode(rectOf: CGSize(width: size.width, height: 40))
        floor.position = CGPoint(x: size.width / 2, y: -20)
        floor.fillColor = .clear
        floor.strokeColor = .clear
        floor.physicsBody = SKPhysicsBody(rectangleOf: floor.frame.size)
        floor.physicsBody?.isDynamic = false
        addChild(floor)
        
        let leftWall = SKShapeNode(rectOf: CGSize(width: 40, height: size.height))
        leftWall.position = CGPoint(x: -20, y: size.height / 2)
        leftWall.physicsBody = SKPhysicsBody(rectangleOf: leftWall.frame.size)
        leftWall.physicsBody?.isDynamic = false
        leftWall.fillColor = .clear
        leftWall.strokeColor = .clear
        addChild(leftWall)
        
        let rightWall = SKShapeNode(rectOf: CGSize(width: 40, height: size.height))
        rightWall.position = CGPoint(x: size.width + 20, y: size.height / 2)
        rightWall.physicsBody = SKPhysicsBody(rectangleOf: rightWall.frame.size)
        rightWall.physicsBody?.isDynamic = false
        rightWall.fillColor = .clear
        rightWall.strokeColor = .clear
        addChild(rightWall)
    }
    
    func startPouring() {
        emitTimer?.invalidate()
        emitTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.spawnSand()
        }
    }
    
    func stopPouring() {
        emitTimer?.invalidate()
        emitTimer = nil
    }
    
    func clearSand() {
        let sandNodes = children.filter { $0.name == "sand" }
        for node in sandNodes {
            node.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 1.0),
                SKAction.removeFromParent()
            ]))
        }
    }
    
    func spawnSand() {
        let currentSand = children.filter { $0.name == "sand" }
        if currentSand.count > 400 {
            currentSand.first?.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.removeFromParent()
            ]))
        }
        
        let node = SKShapeNode(circleOfRadius: 2.5)
        node.name = "sand"
        node.fillColor = UIColor(white: 1.0, alpha: 0.7)
        node.strokeColor = .clear
        
        node.position = CGPoint(x: size.width / 2 + CGFloat.random(in: -10...10), y: size.height + 10)
        
        node.physicsBody = SKPhysicsBody(circleOfRadius: 2.5)
        node.physicsBody?.restitution = 0.2
        node.physicsBody?.friction = 0.6
        node.physicsBody?.density = 1.0
        
        addChild(node)
    }
}

struct SandPhysicsView: View {
    var isRunning: Bool
    var calibrationScore: Double
    
    @State private var scene: SandScene = {
        let scene = SandScene()
        scene.scaleMode = .resizeFill
        return scene
    }()
    
    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
            .onChange(of: isRunning) { _, running in
                scene.isPouring = running
                if !running {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        scene.clearSand()
                    }
                }
            }
    }
}
