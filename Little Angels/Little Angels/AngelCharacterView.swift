import SwiftUI
import Combine

enum PetAnimationMode: Equatable {
    case idle
    case eating
    case playing
    case bathing
    case sleeping
}

struct PetHomeScreen: View {
    @ObservedObject var viewModel: PetViewModel
    @State private var mode: PetAnimationMode
    @State private var reaction = "Your little angel is happy to see you"
    @State private var dragOffset: CGSize = .zero
    @State private var actionID = 0
    @State private var animationCycle = 0
    @State private var showingRoomEditor = false
    private let statDecay = Timer.publish(every: PetStatTuning.updateCheckInterval, on: .main, in: .common).autoconnect()
    private var room: GameSave { viewModel.save }

    init(viewModel: PetViewModel) {
        self.viewModel = viewModel
        _mode = State(initialValue: viewModel.save.isSleeping ? .sleeping : .idle)
    }

    var body: some View {
        ZStack {
            AngelPalette.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    CozyBedroomView(room: viewModel.save, mode: mode, animationCycle: animationCycle, dragOffset: $dragOffset) {
                        reaction = "\(viewModel.save.petName) gives you a tiny happy wiggle!"
                        start(.playing, updateStats: false)
                    }
                    .frame(height: 352)
                    .shadow(color: AngelPalette.lavender.opacity(0.18), radius: 22, y: 12)

                    Text(reaction)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AngelPalette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button { showingRoomEditor = true } label: {
                        Label("Personalize your room", systemImage: "paintpalette.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AngelPalette.ink)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
                    }

                    stats

                    HStack(spacing: 9) {
                        CareActionButton(title: "Feed", subtitle: "+ fullness", symbol: "takeoutbag.and.cup.and.straw.fill", color: AngelPalette.peach) {
                            reaction = "Yum! \(viewModel.save.petName) loved that."
                            start(.eating)
                        }
                        CareActionButton(title: "Play", subtitle: "+ happiness", symbol: "sparkles", color: AngelPalette.sky) {
                            reaction = "That was so much fun!"
                            start(.playing)
                        }
                        CareActionButton(title: "Bath", subtitle: "fresh & clean", symbol: "drop.fill", color: AngelPalette.blue) {
                            reaction = "All fresh and fluffy!"
                            start(.bathing)
                        }
                        CareActionButton(title: mode == .sleeping ? "Wake" : "Sleep", subtitle: mode == .sleeping ? "Good morning" : "+ energy", symbol: mode == .sleeping ? "sun.max.fill" : "moon.zzz.fill", color: AngelPalette.lavender) {
                            if mode == .sleeping {
                                reaction = "Good morning, \(viewModel.save.petName)!"
                                start(.idle, updateStats: false)
                            } else {
                                reaction = "Sweet dreams, little angel."
                                start(.sleeping)
                            }
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.icloud.fill")
                        Text("Your little friend’s progress is saved on this device")
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AngelPalette.muted.opacity(0.82))
                    .padding(.top, 1)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showingRoomEditor) {
            RoomCustomizationView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onReceive(statDecay) { _ in
            viewModel.applyElapsedStatChanges(at: Date())
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LITTLE ANGELS")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(AngelPalette.muted)
                Text("A cozy day with \(viewModel.save.petName)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AngelPalette.ink)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(.white.opacity(0.88)).frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AngelPalette.gold)
            }
            .shadow(color: AngelPalette.lavender.opacity(0.12), radius: 8, y: 4)
        }
        .padding(.horizontal, 3)
    }

    private var stats: some View {
        HStack(spacing: 9) {
            PetStatCard(title: "Fullness", value: viewModel.save.hunger, symbol: "fork.knife", tint: AngelPalette.peach)
            PetStatCard(title: "Happiness", value: viewModel.save.happiness, symbol: "heart.fill", tint: AngelPalette.pink)
            PetStatCard(title: "Energy", value: viewModel.save.energy, symbol: "bolt.fill", tint: AngelPalette.sky)
        }
    }

    private func start(_ nextMode: PetAnimationMode, updateStats: Bool = true) {
        actionID += 1
        animationCycle += 1
        let currentID = actionID
        if nextMode != .sleeping && mode == .sleeping {
            viewModel.wake()
        }
        if updateStats {
            switch nextMode {
            case .eating: viewModel.feed()
            case .playing: viewModel.play()
            case .bathing: viewModel.bathe()
            case .sleeping: viewModel.beginSleeping()
            case .idle: break
            }
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { mode = nextMode }
        guard nextMode == .eating || nextMode == .playing || nextMode == .bathing else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: nextMode == .eating ? 1_500_000_000 : nextMode == .bathing ? 1_400_000_000 : 1_250_000_000)
            guard actionID == currentID, mode == nextMode else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { mode = .idle }
        }
    }
}

private enum AngelPalette {
    static let canvas = Color(red: 0.99, green: 0.97, blue: 0.95)
    static let ink = Color(red: 0.34, green: 0.28, blue: 0.37)
    static let muted = Color(red: 0.58, green: 0.52, blue: 0.62)
    static let pink = Color(red: 0.91, green: 0.62, blue: 0.73)
    static let lavender = Color(red: 0.72, green: 0.65, blue: 0.84)
    static let peach = Color(red: 0.94, green: 0.68, blue: 0.59)
    static let sky = Color(red: 0.58, green: 0.75, blue: 0.84)
    static let blue = Color(red: 0.56, green: 0.70, blue: 0.88)
    static let gold = Color(red: 0.88, green: 0.68, blue: 0.34)
}

private struct RoomWallpaper: Identifiable {
    let id: String
    let name: String
    let wall: Color
    let accent: Color
    let symbol: String

    static let all = [
        RoomWallpaper(id: "blush", name: "Blush Garden", wall: Color(red: 0.91, green: 0.85, blue: 0.94), accent: AngelPalette.pink, symbol: "heart.fill"),
        RoomWallpaper(id: "lavender", name: "Lavender Sky", wall: Color(red: 0.82, green: 0.81, blue: 0.94), accent: AngelPalette.lavender, symbol: "sparkle"),
        RoomWallpaper(id: "cream", name: "Vanilla Cloud", wall: Color(red: 0.98, green: 0.92, blue: 0.82), accent: AngelPalette.gold, symbol: "cloud.fill")
    ]

    static func option(id: String?) -> RoomWallpaper? { all.first { $0.id == id } ?? all.first }
}

private struct RoomFloor: Identifiable {
    let id: String
    let name: String
    let color: Color
    let rugColor: Color

    static let all = [
        RoomFloor(id: "creamWood", name: "Cream Wood", color: Color(red: 0.98, green: 0.89, blue: 0.83), rugColor: Color(red: 0.85, green: 0.72, blue: 0.84).opacity(0.55)),
        RoomFloor(id: "rose", name: "Rosewood", color: Color(red: 0.91, green: 0.75, blue: 0.77), rugColor: Color(red: 0.75, green: 0.80, blue: 0.92).opacity(0.7)),
        RoomFloor(id: "honey", name: "Honey Oak", color: Color(red: 0.93, green: 0.82, blue: 0.68), rugColor: Color(red: 0.91, green: 0.70, blue: 0.75).opacity(0.65))
    ]

    static func option(id: String?) -> RoomFloor? { all.first { $0.id == id } ?? all.first }
}

private struct RoomCustomizationView: View {
    @ObservedObject var viewModel: PetViewModel
    @Environment(\.dismiss) private var dismiss

    private let defaults = UserDefaults.standard
    @State private var wallpaper = UserDefaults.standard.string(forKey: "littleAngels.roomWallpaper") ?? "blush"
    @State private var floor = UserDefaults.standard.string(forKey: "littleAngels.roomFloor") ?? "creamWood"
    @State private var bed = UserDefaults.standard.string(forKey: "littleAngels.roomBed") ?? "roseBed"
    @State private var rug = UserDefaults.standard.string(forKey: "littleAngels.roomRug") ?? "lilacRug"
    @State private var decorations = Set(UserDefaults.standard.stringArray(forKey: "littleAngels.roomDecorations") ?? ["plant", "lamp", "toy"])

    init(viewModel: PetViewModel) {
        self.viewModel = viewModel
        _wallpaper = State(initialValue: viewModel.save.roomWallpaper)
        _floor = State(initialValue: viewModel.save.roomFloor)
        _bed = State(initialValue: viewModel.save.roomBed)
        _rug = State(initialValue: viewModel.save.roomRug)
        _decorations = State(initialValue: viewModel.save.roomDecorations)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Make a cozy little home for \(viewModel.save.petName).")
                        .font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(AngelPalette.muted)
                    optionSection("Wallpaper & theme") {
                        ForEach(RoomWallpaper.all) { item in
                            ChoiceChip(title: item.name, color: item.wall, selected: wallpaper == item.id) { wallpaper = item.id }
                        }
                    }
                    optionSection("Floor") {
                        ForEach(RoomFloor.all) { item in
                            ChoiceChip(title: item.name, color: item.color, selected: floor == item.id) { floor = item.id }
                        }
                    }
                    optionSection("Bed") {
                        ChoiceChip(title: "Rose Canopy", color: AngelPalette.pink, selected: bed == "roseBed") { bed = "roseBed" }
                        ChoiceChip(title: "Lilac Cloud", color: AngelPalette.lavender, selected: bed == "lilacBed") { bed = "lilacBed" }
                    }
                    optionSection("Rug") {
                        ChoiceChip(title: "Lilac Round", color: AngelPalette.lavender, selected: rug == "lilacRug") { rug = "lilacRug" }
                        ChoiceChip(title: "Blush Oval", color: AngelPalette.pink, selected: rug == "blushRug") { rug = "blushRug" }
                    }
                    optionSection("Decorations") {
                        decorationToggle("plant", title: "Plant", symbol: "leaf.fill", tint: Color(red: 0.48, green: 0.66, blue: 0.52))
                        decorationToggle("lamp", title: "Lamp", symbol: "lamp.table.fill", tint: AngelPalette.gold)
                        decorationToggle("shelf", title: "Shelf", symbol: "books.vertical.fill", tint: AngelPalette.lavender)
                        decorationToggle("toy", title: "Teddy Toy", symbol: "teddybear.fill", tint: AngelPalette.peach)
                    }
                    Button(action: saveAndClose) {
                        Text("Save my room").font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(AngelPalette.lavender.gradient, in: Capsule())
                    }
                    .padding(.top, 5)
                }
                .padding(20)
            }
            .background(AngelPalette.canvas.ignoresSafeArea())
            .navigationTitle("Room Makeover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done", action: saveAndClose).tint(AngelPalette.ink) } }
        }
    }

    private func optionSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(AngelPalette.ink)
            ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8, content: content) }
        }
    }

    private func decorationToggle(_ id: String, title: String, symbol: String, tint: Color) -> some View {
        let active = decorations.contains(id)
        return Button {
            if active { decorations.remove(id) } else { decorations.insert(id) }
        } label: {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
                Text(title).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(AngelPalette.ink)
                Image(systemName: active ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14)).foregroundStyle(active ? AngelPalette.pink : AngelPalette.muted.opacity(0.5))
            }
            .frame(width: 76, height: 78).background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(active ? AngelPalette.pink.opacity(0.6) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func saveAndClose() {
        defaults.set(wallpaper, forKey: "littleAngels.roomWallpaper")
        defaults.set(floor, forKey: "littleAngels.roomFloor")
        defaults.set(bed, forKey: "littleAngels.roomBed")
        defaults.set(rug, forKey: "littleAngels.roomRug")
        defaults.set(Array(decorations), forKey: "littleAngels.roomDecorations")
        // Room choices join the existing versioned save while the separate defaults keep old builds readable.
        viewModel.save.roomWallpaper = wallpaper
        viewModel.save.roomFloor = floor
        viewModel.save.roomBed = bed
        viewModel.save.roomRug = rug
        viewModel.save.roomDecorations = decorations
        dismiss()
    }
}

private struct ChoiceChip: View {
    let title: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 14, height: 14)
                Text(title).font(.system(size: 12, weight: .semibold, design: .rounded))
                if selected { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
            }
            .foregroundStyle(AngelPalette.ink).padding(.horizontal, 11).padding(.vertical, 9)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(selected ? AngelPalette.pink : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

private struct CozyBedroomView: View {
    let room: GameSave
    let mode: PetAnimationMode
    let animationCycle: Int
    @Binding var dragOffset: CGSize
    let petTapped: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(LinearGradient(colors: [RoomWallpaper.option(id: room.roomWallpaper)?.wall ?? Color(red: 0.91, green: 0.85, blue: 0.94), RoomWallpaper.option(id: room.roomWallpaper)?.wall.opacity(0.72) ?? Color(red: 0.99, green: 0.89, blue: 0.86)], startPoint: .top, endPoint: .bottom))

                window
                    .frame(width: 138, height: 98)
                    .position(x: size.width * 0.5, y: 74)

                VStack(spacing: 0) {
                    Spacer()
                    Rectangle().fill(RoomFloor.option(id: room.roomFloor)?.color ?? Color(red: 0.98, green: 0.89, blue: 0.83)).frame(height: size.height * 0.32)
                }
                .clipShape(RoundedRectangle(cornerRadius: 32))

                Rectangle()
                    .fill(.white.opacity(0.72))
                    .frame(height: 3)
                    .position(x: size.width / 2, y: size.height * 0.68)

                Ellipse()
                    .fill(rugColor.opacity(0.58))
                    .frame(width: size.width * 0.72, height: 43)
                    .position(x: size.width / 2, y: size.height * 0.88)

                bed
                    .frame(width: room.roomBed == "lilacBed" ? 168 : 155, height: 103)
                    .position(x: size.width * 0.23, y: size.height * 0.79)

            bedsideTable
                    .frame(width: 68, height: 86)
                    .position(x: size.width * 0.83, y: size.height * 0.79)

                roomWallpaperDetails(in: size)
                roomRug(in: size)
                roomDecorations(in: size)

                AngelCharacterView(mode: mode, animationCycle: animationCycle, dragOffset: $dragOffset, petTapped: petTapped)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 1)

                Text(mode == .sleeping ? "Resting softly…" : mode == .eating ? "A little snack!" : mode == .playing ? "Best friends!" : mode == .bathing ? "Fresh and fluffy!" : "")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AngelPalette.ink.opacity(0.78))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.white.opacity(0.82), in: Capsule())
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 12)
                    .opacity(mode == .idle ? 0 : 1)
                    .allowsHitTesting(false)

                Image(systemName: "sparkle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .position(x: size.width * 0.78, y: 43)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .overlay(RoundedRectangle(cornerRadius: 32).stroke(.white.opacity(0.8), lineWidth: 1.5))
        }
    }

    private var rugColor: Color {
        if room.roomRug == "blushRug" { return AngelPalette.pink }
        return RoomFloor.option(id: room.roomFloor)?.rugColor ?? AngelPalette.lavender
    }

    private func roomWallpaperDetails(in size: CGSize) -> some View {
        Group {
            if let theme = RoomWallpaper.option(id: room.roomWallpaper) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: theme.symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.accent.opacity(0.45))
                        .position(x: size.width * (0.13 + Double(index % 3) * 0.35), y: 25 + CGFloat(index / 3) * 42)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func roomRug(in size: CGSize) -> some View {
        Ellipse()
            .fill(rugColor.opacity(0.5))
            .frame(width: size.width * 0.70, height: 39)
            .position(x: size.width / 2, y: size.height * 0.90)
            .allowsHitTesting(false)
    }

    private func roomDecorations(in size: CGSize) -> some View {
        let decorations = room.roomDecorations
        return Group {
            if decorations.contains("plant") {
                Image(systemName: "leaf.fill").font(.system(size: 19)).foregroundStyle(Color(red: 0.48, green: 0.66, blue: 0.52)).position(x: size.width * 0.10, y: size.height * 0.72)
            }
            if decorations.contains("lamp") {
                Image(systemName: "lamp.table.fill").font(.system(size: 20)).foregroundStyle(AngelPalette.gold).position(x: size.width * 0.90, y: size.height * 0.65)
            }
            if decorations.contains("toy") {
                Image(systemName: "teddybear.fill").font(.system(size: 20)).foregroundStyle(AngelPalette.peach).position(x: size.width * 0.74, y: size.height * 0.88)
            }
            if decorations.contains("shelf") {
                Image(systemName: "books.vertical.fill").font(.system(size: 20)).foregroundStyle(AngelPalette.lavender).position(x: size.width * 0.13, y: size.height * 0.34)
            }
        }
        .allowsHitTesting(false)
    }

    private var window: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25).fill(Color(red: 0.76, green: 0.82, blue: 0.91))
            RoundedRectangle(cornerRadius: 19).fill(Color(red: 0.91, green: 0.91, blue: 0.95)).padding(7)
            HStack(spacing: 3) {
                Color(red: 0.78, green: 0.85, blue: 0.92)
                Color(red: 0.83, green: 0.88, blue: 0.94)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(11)
            Rectangle().fill(.white.opacity(0.75)).frame(width: 3)
            Rectangle().fill(.white.opacity(0.75)).frame(height: 3)
            HStack(spacing: 0) {
                Capsule().fill(Color(red: 0.96, green: 0.79, blue: 0.83)).frame(width: 21)
                Spacer()
                Capsule().fill(Color(red: 0.96, green: 0.79, blue: 0.83)).frame(width: 21)
            }
            .padding(.horizontal, -7)
        }
        .shadow(color: AngelPalette.lavender.opacity(0.2), radius: 12, y: 6)
    }

    private var bed: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 22).fill(room.roomBed == "lilacBed" ? AngelPalette.lavender : Color(red: 0.77, green: 0.61, blue: 0.70)).frame(height: 57)
            RoundedRectangle(cornerRadius: 19).fill(Color(red: 1.0, green: 0.95, blue: 0.89)).frame(height: 55).padding(.bottom, 16)
            RoundedRectangle(cornerRadius: 18).fill(room.roomBed == "lilacBed" ? Color(red: 0.81, green: 0.77, blue: 0.92) : Color(red: 0.94, green: 0.70, blue: 0.78)).frame(height: 31).padding(.horizontal, 7).padding(.bottom, 12)
            RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.82, green: 0.78, blue: 0.91)).frame(width: 46, height: 24).offset(x: -34, y: -49)
        }
        .shadow(color: AngelPalette.ink.opacity(0.1), radius: 8, y: 5)
    }

    private var bedsideTable: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 9).fill(Color(red: 0.80, green: 0.65, blue: 0.55)).frame(height: 14)
            HStack(spacing: 23) {
                RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.74, green: 0.58, blue: 0.50)).frame(width: 7, height: 50)
                RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.74, green: 0.58, blue: 0.50)).frame(width: 7, height: 50)
            }
            if room.roomDecorations.contains("lamp") {
                ZStack {
                    Ellipse().fill(Color(red: 0.72, green: 0.63, blue: 0.83)).frame(width: 27, height: 11)
                    Circle().fill(Color(red: 0.95, green: 0.77, blue: 0.58)).frame(width: 12, height: 12).offset(y: -7)
                }
                .offset(y: -55)
            }
        }
        .shadow(color: AngelPalette.ink.opacity(0.08), radius: 6, y: 4)
    }
}

private struct AngelCharacterView: View {
    let mode: PetAnimationMode
    let animationCycle: Int
    @Binding var dragOffset: CGSize
    let petTapped: () -> Void
    @State private var motionPhase = false
    @State private var foodAtMouth = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(mode == .sleeping ? "LumiAngelSleeping" : "LumiAngel")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(245, geometry.size.width * 0.82), height: min(326, geometry.size.height * 0.94))
                    .shadow(color: AngelPalette.ink.opacity(0.16), radius: 15, x: 0, y: 12)
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(mode == .playing && motionPhase ? 1.025 : 1)
                    .offset(x: dragOffset.width, y: verticalMotion + dragOffset.height)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(in: geometry.size))
                    .onTapGesture(perform: petTapped)

                if mode == .eating {
                    FoodMorsel()
                        .scaleEffect(motionPhase ? 0.95 : 1.05)
                        .offset(x: foodAtMouth ? 28 : 68, y: foodAtMouth ? -24 : -11)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
                if mode == .playing || mode == .bathing {
                    Image(systemName: mode == .bathing ? "drop.fill" : "sparkles")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(mode == .bathing ? AngelPalette.blue : AngelPalette.gold)
                        .offset(x: 78, y: motionPhase ? -92 : -76)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
                if mode == .sleeping {
                    Text("Zzz")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AngelPalette.muted)
                        .offset(x: 72, y: motionPhase ? -122 : -138)
                        .opacity(motionPhase ? 0.72 : 1)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { motionPhase = true }
            }
            .onChange(of: animationCycle) { _, _ in
                if mode == .eating {
                    foodAtMouth = false
                    withAnimation(.easeInOut(duration: 0.7)) { foodAtMouth = true }
                } else {
                    foodAtMouth = false
                }
            }
            .onChange(of: mode) { _, nextMode in
                if nextMode != .eating { foodAtMouth = false }
            }
        }
    }

    private var rotation: Double {
        switch mode {
        case .idle: return motionPhase ? 1.4 : -1.4
        case .eating: return motionPhase ? 0.4 : -0.4
        case .playing, .bathing: return motionPhase ? 3.5 : -3.5
        case .sleeping: return 0
        }
    }

    private var verticalMotion: CGFloat {
        switch mode {
        case .idle: return motionPhase ? -4 : 2
        case .eating: return motionPhase ? -3 : 3
        case .playing: return motionPhase ? -13 : 3
        case .bathing: return motionPhase ? -4 : 3
        case .sleeping: return motionPhase ? -2.5 : 2.5
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let horizontalLimit = max(0, (size.width - 190) / 2)
                let verticalLimit = max(0, (size.height - 290) / 2)
                dragOffset = CGSize(
                    width: min(horizontalLimit, max(-horizontalLimit, value.translation.width)),
                    height: min(verticalLimit, max(-verticalLimit, value.translation.height))
                )
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { dragOffset = .zero }
            }
    }
}

private struct PetStatCard: View {
    let title: String
    let value: Double
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(tint)
                Text(title).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(AngelPalette.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.18))
                    Capsule().fill(tint.gradient).frame(width: geometry.size.width * max(0, min(1, value / 100)))
                }
            }
            .frame(height: 8)
            Text("\(Int(value))%")
                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(AngelPalette.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white, lineWidth: 1))
        .shadow(color: AngelPalette.lavender.opacity(0.08), radius: 9, y: 4)
    }
}

private struct CareActionButton: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.14), in: Circle())
                Text(title).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(AngelPalette.ink)
                Text(subtitle).font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(AngelPalette.muted).lineLimit(1).minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white, lineWidth: 1))
            .shadow(color: color.opacity(0.17), radius: 11, y: 5)
        }
        .buttonStyle(.plain)
    }
}

private struct FoodMorsel: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.98, green: 0.67, blue: 0.51)).frame(width: 18, height: 18)
            Ellipse().fill(Color(red: 0.51, green: 0.72, blue: 0.48)).frame(width: 9, height: 5).rotationEffect(.degrees(-35)).offset(x: 7, y: -9)
        }
        .shadow(color: AngelPalette.ink.opacity(0.12), radius: 3, y: 2)
    }
}
