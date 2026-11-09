import RealityKit
import SwiftUI
import UIKit

/// A reusable RealityKit dollhouse view. Add a USDZ named for the pet, for example
/// SheepAngel.usdz, to the app bundle to replace the explicitly-labeled room-test stand-in.
struct RealityPetRoom: View {
    let petName: String
    let modelResourceName: String

    @Environment(\.dismiss) private var dismiss
    @State private var petEntity: Entity?
    @State private var usingPlaceholder = true
    @State private var interactionMessage = "Drag your angel to turn it. Tap it for a little hello."

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text(petName)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.34, green: 0.29, blue: 0.34))
                    Text("A tiny room for a very special friend")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Color(red: 0.60, green: 0.55, blue: 0.60))
                }
                .padding(.top, 8)

                RealityView { content in
                    let room = DollhouseScene.makeRoom()
                    let loadedPet = AngelModelLibrary.load(modelNamed: modelResourceName)
                    loadedPet.entity.name = "AngelPet"
                    loadedPet.entity.position = SIMD3<Float>(0, 0.08, 0.35)
                    loadedPet.entity.components.set(InputTargetComponent())
                    loadedPet.entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.65)]))
                    room.addChild(loadedPet.entity)
                    content.add(room)
                    petEntity = loadedPet.entity
                    usingPlaceholder = loadedPet.isPlaceholder
                }
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .targetedToAnyEntity()
                        .onChanged { event in
                            guard event.entity.name == "AngelPet" else { return }
                            let yaw = Float(event.translation.width) * 0.012
                            let pitch = Float(event.translation.height) * 0.008
                            event.entity.transform.rotation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
                                * simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .targetedToAnyEntity()
                        .onEnded { event in
                            guard event.entity.name == "AngelPet" else { return }
                            interactWithPet()
                        }
                )
                .frame(height: 470)
                .overlay(alignment: .top) {
                    if usingPlaceholder {
                        Text("TEMP 3D PET PLACEHOLDER · USDZ MODEL NOT ADDED")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color(red: 0.48, green: 0.39, blue: 0.59).opacity(0.92), in: Capsule())
                            .padding(.top, 12)
                            .allowsHitTesting(false)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal, 16)
                .accessibilityLabel("3D pastel dollhouse room")

                Text(interactionMessage)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.47, green: 0.40, blue: 0.49))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                if usingPlaceholder {
                    Text("The existing SheepAngel, CowAngel, and MouseAngel images remain available in the app. They are 2D references and are not being presented as 3D models.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color(red: 0.60, green: 0.55, blue: 0.60))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                Spacer(minLength: 8)
            }
            .background(Color(red: 0.99, green: 0.96, blue: 0.91).ignoresSafeArea())
            .navigationTitle("3D Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(red: 0.78, green: 0.45, blue: 0.57))
                }
            }
        }
    }

    private func interactWithPet() {
        interactionMessage = "\(petName) notices you and gives a tiny hello!"
        guard let petEntity else { return }
        let originalScale = petEntity.transform.scale
        petEntity.transform.scale = originalScale * SIMD3<Float>(repeating: 1.08)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            petEntity.transform.scale = originalScale
        }
    }
}

private struct LoadedAngelModel {
    let entity: Entity
    let isPlaceholder: Bool
}

/// Loads real, separately authored USDZ models when present. The PNG image sets are
/// deliberately not used as textures or treated as three-dimensional models.
private enum AngelModelLibrary {
    static func load(modelNamed name: String) -> LoadedAngelModel {
        if let url = Bundle.main.url(forResource: name, withExtension: "usdz"),
           let entity = try? Entity.load(contentsOf: url) {
            return LoadedAngelModel(entity: entity, isPlaceholder: false)
        }

        let standIn = ModelEntity(
            mesh: .generateSphere(radius: 0.38),
            materials: [SimpleMaterial(color: UIColor(red: 0.78, green: 0.70, blue: 0.91, alpha: 1), isMetallic: false)]
        )
        standIn.scale = SIMD3<Float>(0.9, 1.5, 0.9)
        return LoadedAngelModel(entity: standIn, isPlaceholder: true)
    }
}

private enum DollhouseScene {
    static func makeRoom() -> AnchorEntity {
        let anchor = AnchorEntity(world: .zero)

        addBox(to: anchor, name: "Cream floor", size: SIMD3<Float>(4.2, 0.12, 4.1), position: SIMD3<Float>(0, -0.08, 0), color: UIColor(red: 0.97, green: 0.90, blue: 0.82, alpha: 1))
        addBox(to: anchor, name: "Pink back wall", size: SIMD3<Float>(4.2, 2.8, 0.12), position: SIMD3<Float>(0, 1.32, -2.0), color: UIColor(red: 0.91, green: 0.79, blue: 0.84, alpha: 1))
        addBox(to: anchor, name: "Lavender side wall", size: SIMD3<Float>(0.12, 2.8, 4.0), position: SIMD3<Float>(-2.05, 1.32, 0), color: UIColor(red: 0.78, green: 0.73, blue: 0.86, alpha: 1))

        let rug = ModelEntity(mesh: .generateCylinder(height: 0.035, radius: 0.92), materials: [material(UIColor(red: 0.88, green: 0.75, blue: 0.82, alpha: 1))])
        rug.name = "Round pastel rug"
        rug.position = SIMD3<Float>(0, 0.0, 0.48)
        anchor.addChild(rug)

        addBed(to: anchor)
        addTable(to: anchor)
        addFoodBowl(to: anchor)
        addPlant(to: anchor)
        addWallDecor(to: anchor)
        addSoftLight(to: anchor)

        let camera = PerspectiveCamera()
        camera.position = SIMD3<Float>(0, 2.25, 6.0)
        camera.look(at: SIMD3<Float>(0, 0.9, 0), from: camera.position, relativeTo: anchor)
        anchor.addChild(camera)
        return anchor
    }

    private static func addBed(to anchor: Entity) {
        addBox(to: anchor, name: "Bed frame", size: SIMD3<Float>(1.55, 0.30, 1.12), position: SIMD3<Float>(-1.0, 0.22, -1.02), color: UIColor(red: 0.76, green: 0.54, blue: 0.62, alpha: 1))
        addBox(to: anchor, name: "Cream mattress", size: SIMD3<Float>(1.46, 0.18, 1.02), position: SIMD3<Float>(-1.0, 0.43, -1.02), color: UIColor(red: 1.0, green: 0.94, blue: 0.86, alpha: 1))
        addBox(to: anchor, name: "Pink blanket", size: SIMD3<Float>(1.18, 0.08, 0.68), position: SIMD3<Float>(-1.0, 0.56, -0.80), color: UIColor(red: 0.95, green: 0.70, blue: 0.77, alpha: 1))
        addBox(to: anchor, name: "Bed pillow", size: SIMD3<Float>(0.56, 0.13, 0.36), position: SIMD3<Float>(-1.0, 0.57, -1.34), color: UIColor(red: 0.83, green: 0.79, blue: 0.91, alpha: 1))
    }

    private static func addTable(to anchor: Entity) {
        let wood = UIColor(red: 0.75, green: 0.57, blue: 0.45, alpha: 1)
        addBox(to: anchor, name: "Side table top", size: SIMD3<Float>(0.82, 0.13, 0.64), position: SIMD3<Float>(1.30, 0.68, -0.82), color: wood)
        for x: Float in [1.0, 1.60] {
            for z: Float in [-1.04, -0.60] {
                addBox(to: anchor, name: "Side table leg", size: SIMD3<Float>(0.08, 0.62, 0.08), position: SIMD3<Float>(x, 0.34, z), color: wood)
            }
        }
        addBox(to: anchor, name: "Tiny book", size: SIMD3<Float>(0.28, 0.06, 0.20), position: SIMD3<Float>(1.28, 0.78, -0.82), color: UIColor(red: 0.88, green: 0.70, blue: 0.77, alpha: 1))
    }

    private static func addFoodBowl(to anchor: Entity) {
        let bowl = ModelEntity(mesh: .generateCylinder(height: 0.15, radius: 0.30), materials: [material(UIColor(red: 0.78, green: 0.66, blue: 0.86, alpha: 1))])
        bowl.name = "Food bowl"
        bowl.position = SIMD3<Float>(1.22, 0.08, 0.95)
        anchor.addChild(bowl)
        let food = ModelEntity(mesh: .generateSphere(radius: 0.10), materials: [material(UIColor(red: 0.94, green: 0.66, blue: 0.50, alpha: 1))])
        food.position = SIMD3<Float>(1.22, 0.19, 0.95)
        anchor.addChild(food)
    }

    private static func addPlant(to anchor: Entity) {
        let pot = ModelEntity(mesh: .generateCylinder(height: 0.28, radius: 0.20), materials: [material(UIColor(red: 0.91, green: 0.72, blue: 0.61, alpha: 1))])
        pot.position = SIMD3<Float>(1.56, 0.14, -1.55)
        anchor.addChild(pot)
        for position in [SIMD3<Float>(1.48, 0.47, -1.55), SIMD3<Float>(1.65, 0.52, -1.55), SIMD3<Float>(1.56, 0.62, -1.55)] {
            let leaf = ModelEntity(mesh: .generateSphere(radius: 0.16), materials: [material(UIColor(red: 0.55, green: 0.72, blue: 0.55, alpha: 1))])
            leaf.position = position
            leaf.scale = SIMD3<Float>(0.75, 1.2, 0.75)
            anchor.addChild(leaf)
        }
    }

    private static func addWallDecor(to anchor: Entity) {
        addBox(to: anchor, name: "Picture frame", size: SIMD3<Float>(0.72, 0.62, 0.06), position: SIMD3<Float>(0.55, 1.72, -1.88), color: UIColor(red: 0.98, green: 0.90, blue: 0.79, alpha: 1))
        addBox(to: anchor, name: "Picture art", size: SIMD3<Float>(0.50, 0.40, 0.025), position: SIMD3<Float>(0.55, 1.72, -1.83), color: UIColor(red: 0.75, green: 0.81, blue: 0.89, alpha: 1))
        let star = ModelEntity(mesh: .generateSphere(radius: 0.10), materials: [material(UIColor(red: 0.98, green: 0.82, blue: 0.48, alpha: 1))])
        star.position = SIMD3<Float>(0.55, 1.72, -1.79)
        anchor.addChild(star)
    }

    private static func addSoftLight(to anchor: Entity) {
        let keyLight = DirectionalLight()
        keyLight.light.intensity = 900
        keyLight.shadow = DirectionalLightComponent.Shadow(maximumDistance: 6, depthBias: 1)
        keyLight.look(at: SIMD3<Float>(0, 0.5, 0), from: SIMD3<Float>(-2, 4, 3), relativeTo: anchor)
        anchor.addChild(keyLight)

        let light = PointLight()
        light.light = PointLightComponent(color: .white, intensity: 1100, attenuationRadius: 7)
        light.position = SIMD3<Float>(0, 2.5, 1.2)
        anchor.addChild(light)
    }

    private static func addBox(to anchor: Entity, name: String, size: SIMD3<Float>, position: SIMD3<Float>, color: UIColor) {
        let entity = ModelEntity(mesh: .generateBox(size: size), materials: [material(color)])
        entity.name = name
        entity.position = position
        anchor.addChild(entity)
    }

    private static func material(_ color: UIColor) -> SimpleMaterial {
        SimpleMaterial(color: color, isMetallic: false)
    }
}
