import SwiftUI
import Combine

private struct Angel: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let imageName: String
    let colorName: String
    let price: Int

    static let all: [Angel] = [
        Angel(id: "lumi", name: "Sheep Angel", subtitle: "Soft and woolly", imageName: "SheepAngel", colorName: "lavender", price: 0),
        Angel(id: "poppy", name: "Cow Angel", subtitle: "Sweet little moo", imageName: "CowAngel", colorName: "butter", price: 30),
        Angel(id: "bubbles", name: "Mouse Angel", subtitle: "Tiny and dreamy", imageName: "MouseAngel", colorName: "blue", price: 45)
    ]

    var color: Color {
        switch colorName {
        case "lavender": return Color(red: 0.78, green: 0.70, blue: 0.91)
        case "butter": return Color(red: 0.98, green: 0.82, blue: 0.43)
        default: return Color(red: 0.61, green: 0.80, blue: 0.91)
        }
    }
}

private struct GameSave: Codable {
    var selectedAngelID: String?
    var petName = ""
    var hunger = 74.0
    var happiness = 78.0
    var energy = 82.0
    var coins = 50
    var unlockedIDs: Set<String> = []
}

@MainActor
private final class PetViewModel: ObservableObject {
    @Published var save: GameSave { didSet { persist() } }
    private let saveKey = "littleAngels.save.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: "littleAngels.save.v1"),
           let loaded = try? JSONDecoder().decode(GameSave.self, from: data) {
            save = loaded
        } else {
            save = GameSave()
        }
    }

    var selectedAngel: Angel? { Angel.all.first { $0.id == save.selectedAngelID } }
    var unlockedAngels: [Angel] { Angel.all.filter { save.unlockedIDs.contains($0.id) } }

    func adopt(_ angel: Angel, name: String) {
        save.selectedAngelID = angel.id
        save.petName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? angel.name : name
        save.unlockedIDs.insert(angel.id)
    }

    func feed() { save.hunger = min(100, save.hunger + 24); save.happiness = min(100, save.happiness + 5) }
    func play() { save.happiness = min(100, save.happiness + 20); save.energy = max(0, save.energy - 13); save.hunger = max(0, save.hunger - 5) }
    func sleep() { save.energy = min(100, save.energy + 28) }
    func unlock(_ angel: Angel) {
        guard save.coins >= angel.price, !save.unlockedIDs.contains(angel.id) else { return }
        save.coins -= angel.price
        save.unlockedIDs.insert(angel.id)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(save) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }
}

private enum Palette {
    static let cream = Color(red: 0.99, green: 0.96, blue: 0.91)
    static let ink = Color(red: 0.34, green: 0.29, blue: 0.34)
    static let pink = Color(red: 0.91, green: 0.62, blue: 0.70)
    static let muted = Color(red: 0.60, green: 0.55, blue: 0.60)
}

struct ContentView: View {
    @StateObject private var model = PetViewModel()
    @State private var selection = 0
    @State private var reaction: String?
    @State private var petAction: PetAction = .idle
    @State private var actionID = 0
    @State private var showing3DRoom = false

    private enum PetAction: String, Equatable {
        case idle, eating, playing, sleeping
    }

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()
            if model.selectedAngel == nil {
                AdoptionView { angel, name in model.adopt(angel, name: name) }
            } else {
                TabView(selection: $selection) {
                    home.tag(0).tabItem { Label("Home", systemImage: "house.fill") }
                    collection.tag(1).tabItem { Label("Collection", systemImage: "sparkles") }
                    shop.tag(2).tabItem { Label("Shop", systemImage: "basket.fill") }
                }
                .tint(Palette.pink)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showing3DRoom) {
            if let angel = model.selectedAngel {
                RealityPetRoom(petName: model.save.petName, modelResourceName: angel.imageName)
            }
        }
    }

    private var home: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("LITTLE ANGELS").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(Palette.muted)
                    Text("A little day together").font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                }
                Spacer()
                Label("\(model.save.coins)", systemImage: "circle.hexagongrid.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 13).padding(.vertical, 9).background(.white.opacity(0.75), in: Capsule())
            }.padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 18)

            bedroom
                .frame(height: 330)
                .padding(.horizontal, 18)
            Text(model.save.petName).font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink).padding(.top, 12)
            Text(reaction ?? moodDescription).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(Palette.muted).padding(.top, 3)

            VStack(spacing: 12) {
                StatRow(title: "Fullness", value: model.save.hunger, icon: "fork.knife", tint: Color(red: 0.94, green: 0.66, blue: 0.61))
                StatRow(title: "Joy", value: model.save.happiness, icon: "heart.fill", tint: Palette.pink)
                StatRow(title: "Energy", value: model.save.energy, icon: "sparkle", tint: Color(red: 0.57, green: 0.75, blue: 0.84))
            }.padding(16).background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22)).padding(.horizontal, 22).padding(.top, 18)

            HStack(spacing: 12) {
                CareButton(title: "Feed", icon: "takeoutbag.and.cup.and.straw.fill", tint: Color(red: 0.94, green: 0.68, blue: 0.66)) {
                    model.feed(); startPetAction(.eating); show("Yum! So good ✨")
                }
                CareButton(title: "Play", icon: "paperplane.fill", tint: Color(red: 0.67, green: 0.79, blue: 0.87)) {
                    model.play(); startPetAction(.playing); show("That was fun! ♡")
                }
                CareButton(title: petAction == .sleeping ? "Wake" : "Sleep", icon: petAction == .sleeping ? "sun.max.fill" : "moon.zzz.fill", tint: Color(red: 0.75, green: 0.70, blue: 0.85)) {
                    if petAction == .sleeping {
                        startPetAction(.idle); show("Good morning! ☀️")
                    } else {
                        model.sleep(); startPetAction(.sleeping); show("Sweet dreams ☾")
                    }
                }
            }.padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 12)
        }
    }

    private var bedroom: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                RoundedRectangle(cornerRadius: 30).fill(Color(red: 0.94, green: 0.86, blue: 0.84))
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        Color(red: 0.91, green: 0.84, blue: 0.86)
                        HStack(spacing: 0) {
                            Color(red: 0.70, green: 0.81, blue: 0.85)
                            Color(red: 0.76, green: 0.85, blue: 0.87)
                            Color(red: 0.70, green: 0.81, blue: 0.85)
                        }.frame(width: width * 0.36, height: 116).clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(alignment: .center) { Rectangle().fill(.white.opacity(0.65)).frame(width: 3) }
                            .overlay { RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.9), lineWidth: 6) }
                            .padding(.top, 27)
                    }.frame(height: 168)
                    Color(red: 0.97, green: 0.90, blue: 0.84).overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.65)).frame(height: 3) }
                }.clipShape(RoundedRectangle(cornerRadius: 30))
                VStack {
                    HStack {
                        Image(systemName: "cloud.fill").font(.system(size: 21)).foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text("✦").font(.system(size: 22)).foregroundStyle(Color(red: 0.97, green: 0.84, blue: 0.54))
                    }.padding(.horizontal, 28).padding(.top, 23)
                    Spacer()
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.96, green: 0.76, blue: 0.78)).frame(height: 91).padding(.horizontal, 14)
                        RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.99, green: 0.91, blue: 0.88)).frame(height: 58).padding(.horizontal, 14)
                        HStack { Circle().fill(.white.opacity(0.85)).frame(width: 39, height: 28); Spacer() }.padding(.horizontal, 30).padding(.bottom, 42)
                    }.frame(height: 101).padding(.bottom, 3)
                }
                if let angel = model.selectedAngel {
                    AnimatedAngelView(angel: angel, action: AnimatedAngelView.Action(rawValue: petAction.rawValue) ?? .idle)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .animation(.spring(response: 0.35, dampingFraction: 0.62), value: currentExpression)
                }
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "leaf.fill").foregroundStyle(Color(red: 0.55, green: 0.69, blue: 0.54))
                        Spacer()
                        Image(systemName: "heart.fill").foregroundStyle(.white.opacity(0.7))
                    }.font(.system(size: 20)).padding(.horizontal, 30).padding(.bottom, 94)
                }
                VStack {
                    HStack {
                        Spacer()
                        Button { showing3DRoom = true } label: {
                            Label("3D Room", systemImage: "cube.transparent")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 11).padding(.vertical, 9)
                                .background(.white.opacity(0.82), in: Capsule())
                        }
                    }
                    Spacer()
                }
                .padding(14)
            }.clipShape(RoundedRectangle(cornerRadius: 30))
        }
    }

    private var currentExpression: String {
        if model.save.energy < 25 { return "sleepy" }
        if model.save.hunger < 25 { return "hungry" }
        if model.save.happiness > 75 { return "happy" }
        return "calm"
    }

    private var moodDescription: String {
        switch currentExpression {
        case "sleepy": return "A little yawn is coming…"
        case "hungry": return "A tiny tummy is rumbling"
        case "happy": return "Your angel feels loved"
        default: return "Having a lovely little day"
        }
    }

    private var collection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeading(kicker: "YOUR LITTLE SHELF", title: "My collection", subtitle: "Every angel has a little story.")
                ForEach(model.unlockedAngels) { angel in AngelCard(angel: angel, selected: model.save.selectedAngelID == angel.id, action: { model.save.selectedAngelID = angel.id; model.save.petName = angel.name }) }
                if model.unlockedAngels.isEmpty { Text("Your shelf is waiting for its first angel.").foregroundStyle(Palette.muted) }
            }.padding(22)
        }.background(Palette.cream).safeAreaInset(edge: .top) { Color.clear.frame(height: 1) }
    }

    private var shop: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeading(kicker: "ANGEL MARKET", title: "Meet a new friend", subtitle: "A little pocket change, a lot of love.")
                HStack { Image(systemName: "circle.hexagongrid.fill").foregroundStyle(Palette.pink); Text("You have \(model.save.coins) coins").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink); Spacer() }.padding(16).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 18))
                ForEach(Angel.all) { angel in
                    AngelCard(angel: angel, selected: false, action: { model.unlock(angel) }, buttonTitle: model.save.unlockedIDs.contains(angel.id) ? "Adopted" : (angel.price == 0 ? "Free" : "\(angel.price) coins"), disabled: model.save.unlockedIDs.contains(angel.id) || model.save.coins < angel.price)
                }
            }.padding(22)
        }.background(Palette.cream)
    }

    private func show(_ message: String) {
        withAnimation(.spring()) { reaction = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { withAnimation { reaction = nil } }
    }

    private func startPetAction(_ action: PetAction) {
        actionID += 1
        let currentActionID = actionID
        withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) { petAction = action }
        guard action == .eating || action == .playing else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: action == .eating ? 1_450_000_000 : 1_250_000_000)
            guard petAction == action, actionID == currentActionID else { return }
            withAnimation(.spring(response: 0.48, dampingFraction: 0.76)) { petAction = .idle }
        }
    }
}

private struct AdoptionView: View {
    let adopt: (Angel, String) -> Void
    @State private var picked = Angel.all[0]
    @State private var name = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("✦  LITTLE ANGELS  ✦").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(2.2).foregroundStyle(Palette.muted).padding(.top, 28)
                Text("A tiny friend,\na whole lot of love.").font(.system(size: 34, weight: .bold, design: .rounded)).multilineTextAlignment(.center).foregroundStyle(Palette.ink)
                Text("Choose your first angel and give them a name.").font(.system(size: 15, design: .rounded)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                AngelFigure(angel: picked, expression: "happy").frame(width: 205, height: 300).padding(.vertical, 5)
                HStack(spacing: 9) {
                    ForEach(Angel.all) { angel in
                        Button { withAnimation(.spring()) { picked = angel } } label: {
                            VStack(spacing: 9) {
                                AngelFigure(angel: angel, expression: "calm").frame(height: 92)
                                Text(angel.name).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                                Text(angel.subtitle).font(.system(size: 10, design: .rounded)).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.8)
                            }.frame(maxWidth: .infinity).padding(11).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 19)).overlay(RoundedRectangle(cornerRadius: 19).stroke(picked == angel ? Palette.pink : .clear, lineWidth: 2))
                        }.buttonStyle(.plain)
                    }
                }
                TextField("Your angel's name", text: $name).font(.system(size: 16, design: .rounded)).padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16)).textInputAutocapitalization(.words)
                Button { adopt(picked, name) } label: {
                    HStack { Text("Welcome home"); Image(systemName: "heart.fill") }.font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(17).background(Palette.pink, in: Capsule())
                }
            }.padding(.horizontal, 22).padding(.bottom, 24)
        }.background(Palette.cream).scrollDismissesKeyboard(.interactively)
    }
}

private struct AngelFigure: View {
    let angel: Angel
    let expression: String

    var body: some View {
        Image(angel.imageName)
            .resizable()
            .scaledToFit()
            .accessibilityLabel(angel.name)
    }
}

private struct AnimatedAngelView: View {
    enum Action: String, Equatable { case idle, eating, playing, sleeping }

    let angel: Angel
    let action: Action
    @State private var motionPhase = false
    @State private var dragOffset: CGSize = .zero
    @State private var foodMoved = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AngelFigure(angel: angel, expression: action == .sleeping ? "sleepy" : "calm")
                        .frame(width: min(235, geometry.size.width), height: min(300, geometry.size.height))
                    .rotationEffect(.degrees(rotation))
                    .offset(x: dragOffset.width, y: verticalMotion + dragOffset.height)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(in: geometry.size))

                if action == .eating {
                    FoodBite()
                        .scaleEffect(motionPhase ? 0.95 : 1.05)
                        .offset(x: foodMoved ? 31 : 72, y: foodMoved ? -18 : -8)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
                if action == .playing {
                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Color(red: 0.97, green: 0.79, blue: 0.42))
                        .offset(x: motionPhase ? 72 : 84, y: motionPhase ? -102 : -82)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
                if action == .sleeping {
                    SleepEyes()
                        .offset(y: -35)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                    Text("Zzz")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.muted.opacity(0.8))
                        .offset(x: 76, y: motionPhase ? -112 : -128)
                        .opacity(motionPhase ? 0.75 : 1)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) { motionPhase = true }
            }
            .onChange(of: action) { _, newAction in
                if newAction == .eating {
                    foodMoved = false
                    withAnimation(.easeInOut(duration: 0.72)) { foodMoved = true }
                } else {
                    foodMoved = false
                }
            }
        }
    }

    private var rotation: Double {
        switch action {
        case .idle: return motionPhase ? 1.8 : -1.8
        case .eating: return motionPhase ? 0.6 : -0.6
        case .playing: return motionPhase ? 4 : -4
        case .sleeping: return 0
        }
    }

    private var verticalMotion: CGFloat {
        switch action {
        case .idle: return motionPhase ? -5 : 2
        case .eating: return motionPhase ? -4 : 4
        case .playing: return motionPhase ? -8 : 3
        case .sleeping: return motionPhase ? -3 : 3
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let horizontalLimit = max(0, (size.width - 235) / 2)
                let verticalLimit = max(0, (size.height - 300) / 2 - 5)
                dragOffset = CGSize(
                    width: min(horizontalLimit, max(-horizontalLimit, value.translation.width)),
                    height: min(verticalLimit, max(-verticalLimit, value.translation.height))
                )
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.48, dampingFraction: 0.68)) { dragOffset = .zero }
            }
    }
}

private struct SleepEyes: View {
    var body: some View {
        HStack(spacing: 29) {
            Capsule().fill(Palette.ink).frame(width: 12, height: 2.5).rotationEffect(.degrees(-8))
            Capsule().fill(Palette.ink).frame(width: 12, height: 2.5).rotationEffect(.degrees(8))
        }
    }
}

private struct FoodBite: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.98, green: 0.66, blue: 0.53)).frame(width: 18, height: 18)
            Ellipse().fill(Color(red: 0.51, green: 0.72, blue: 0.48))
                .frame(width: 9, height: 5).rotationEffect(.degrees(-35)).offset(x: 7, y: -9)
        }
        .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
    }
}

private struct StatRow: View {
    let title: String
    let value: Double
    let icon: String
    let tint: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(tint).frame(width: 19)
            Text(title).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink).frame(width: 67, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.18))
                    Capsule().fill(tint).frame(width: geometry.size.width * max(0, min(1, value / 100)))
                }
            }.frame(height: 9)
            Text("\(Int(value))").font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit()).foregroundStyle(Palette.muted).frame(width: 28, alignment: .trailing)
        }.frame(height: 14)
    }
}

private struct CareButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.system(size: 13, weight: .bold, design: .rounded))
            }.foregroundStyle(Palette.ink).frame(maxWidth: .infinity).padding(.vertical, 12).background(tint.opacity(0.28), in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}

private struct PageHeading: View {
    let kicker: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(kicker).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.8).foregroundStyle(Palette.muted)
            Text(title).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
            Text(subtitle).font(.system(size: 14, design: .rounded)).foregroundStyle(Palette.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
    }
}

private struct AngelCard: View {
    let angel: Angel
    let selected: Bool
    let action: () -> Void
    var buttonTitle = "Make my angel"
    var disabled = false
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 17).fill(angel.color.opacity(0.26)).frame(width: 78, height: 90)
                AngelFigure(angel: angel, expression: "happy").frame(width: 66, height: 84)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(angel.name).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                Text(angel.subtitle).font(.system(size: 12, design: .rounded)).foregroundStyle(Palette.muted)
                if selected { Text("YOUR CURRENT FRIEND").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(Palette.pink).padding(.top, 3) }
            }
            Spacer(minLength: 2)
            Button(action: action) {
                Text(selected ? "Here" : buttonTitle).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(disabled ? Palette.muted : .white).padding(.horizontal, 12).padding(.vertical, 10).background(disabled ? Color.black.opacity(0.06) : Palette.pink, in: Capsule())
            }.buttonStyle(.plain).disabled(disabled)
        }.padding(13).background(.white.opacity(0.83), in: RoundedRectangle(cornerRadius: 22))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
