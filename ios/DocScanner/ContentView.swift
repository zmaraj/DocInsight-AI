import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

// MARK: - History Item
struct ScanHistoryItem: Identifiable, Codable {
    let id: UUID
    let date: Date
    let outputType: String
    let summary: String
    let imageData: Data?

    init(id: UUID = UUID(), date: Date = Date(),
         outputType: String, summary: String, imageData: Data? = nil) {
        self.id = id; self.date = date
        self.outputType = outputType; self.summary = summary
        self.imageData = imageData
    }
}

// MARK: - History Store
class HistoryStore: ObservableObject {
    @Published var items: [ScanHistoryItem] = []
    init() { load() }
    func add(_ item: ScanHistoryItem) {
        items.insert(item, at: 0)
        if items.count > 20 { items = Array(items.prefix(20)) }
        save()
    }
    func clear() { items = []; save() }
    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "scan_history")
        }
    }
    private func load() {
        if let data = UserDefaults.standard.data(forKey: "scan_history"),
           let saved = try? JSONDecoder().decode([ScanHistoryItem].self, from: data) {
            self.items = saved
        }
    }
}

// MARK: - Colors
extension Color {
    static let brand1       = Color(red: 0.52, green: 0.08, blue: 0.14)
    static let brand2       = Color(red: 0.70, green: 0.15, blue: 0.22)
    static let bgBase       = Color(red: 0.95, green: 0.92, blue: 0.87)
    static let bgSurface    = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let bgElevated   = Color(red: 0.89, green: 0.85, blue: 0.79)
    static let borderSubtle = Color(red: 0.52, green: 0.08, blue: 0.14).opacity(0.12)
    static let textHigh     = Color(red: 0.12, green: 0.08, blue: 0.08)
    static let textMed      = Color(red: 0.38, green: 0.28, blue: 0.28)
    static let textLow      = Color(red: 0.55, green: 0.46, blue: 0.44)
}

// MARK: - Surface Card
struct SurfaceCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .stroke(Color.borderSubtle, lineWidth: 0.5))
    }
}

// MARK: - Animated Row (press feedback)
struct AnimatedRow<Content: View>: View {
    let content: Content
    let action: () -> Void
    @State private var pressed = false

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(pressed ? 0.97 : 1.0)
            .opacity(pressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { pressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressed = false }
                    action()
                }
            }
    }
}

// MARK: - Background
struct AppBackground: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            Color.bgBase
            Circle()
                .fill(Color.brand1.opacity(0.08))
                .frame(width: 350, height: 350).blur(radius: 100)
                .offset(x: animate ? -40 : 40, y: animate ? -100 : -50)
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate)
            Circle()
                .fill(Color.brand2.opacity(0.05))
                .frame(width: 300, height: 300).blur(radius: 90)
                .offset(x: animate ? 60 : -30, y: animate ? 200 : 140)
                .animation(.easeInOut(duration: 13).repeatForever(autoreverses: true), value: animate)
        }
        .ignoresSafeArea()
        .onAppear { animate = true }
    }
}

// MARK: - Bullet Summary
struct BulletSummaryView: View {
    let text: String
    @State private var appeared = false

    var bullets: [String] {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        for line in lines {
            let cleaned = line.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "^[-•*]\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
            if !cleaned.isEmpty { result.append(cleaned) }
        }
        if result.count <= 1 {
            result = text.components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { $0.hasSuffix(".") ? $0 : $0 + "." }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(bullets.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.brand1)
                        .frame(width: 5, height: 5)
                        .padding(.top, 9)
                    Text(point)
                        .font(.system(size: 16, design: .serif))
                        .foregroundColor(.textHigh)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : -12)
                .animation(
                    .spring(response: 0.45, dampingFraction: 0.8)
                    .delay(Double(index) * 0.06),
                    value: appeared
                )
            }
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}

// MARK: - History Detail
struct HistoryDetailView: View {
    let item: ScanHistoryItem
    @Environment(\.dismiss) var dismiss
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button { dismiss() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 15, weight: .medium, design: .serif))
                            }
                            .foregroundColor(.brand1)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Color.bgElevated)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.borderSubtle, lineWidth: 0.5))
                        }
                        Spacer()
                        Text(item.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(.textLow)
                    }
                    .padding(.horizontal, 20).padding(.top, 56).padding(.bottom, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -10)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05), value: appeared)

                    HStack(spacing: 6) {
                        Image(systemName: iconFor(item.outputType)).font(.system(size: 11))
                        Text(labelFor(item.outputType))
                            .font(.system(size: 12, weight: .medium, design: .serif))
                    }
                    .foregroundColor(.brand2)
                    .padding(.horizontal, 20).padding(.bottom, 12)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1), value: appeared)

                    SurfaceCard {
                        if item.outputType == "audio" {
                            BulletSummaryView(text: item.summary).padding(20)
                        } else {
                            Text(item.summary)
                                .font(.system(size: 16, design: .serif))
                                .foregroundColor(.textHigh)
                                .lineSpacing(6)
                                .padding(20)
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 16)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.15), value: appeared)

                    if let imgData = item.imageData, let img = UIImage(data: imgData) {
                        SurfaceCard {
                            Image(uiImage: img).resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12)).padding(12)
                        }
                        .padding(.horizontal, 20).padding(.bottom, 24)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.2), value: appeared)
                    }
                }
            }
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    private func iconFor(_ t: String) -> String {
        switch t {
        case "chart": return "chart.bar.fill"
        case "table": return "tablecells.fill"
        case "flowchart": return "arrow.triangle.branch"
        case "audio": return "mic.fill"
        default: return "text.alignleft"
        }
    }
    private func labelFor(_ t: String) -> String {
        switch t {
        case "audio": return "Voice Summary"
        case "chart": return "Chart"
        case "table": return "Table"
        case "flowchart": return "Flowchart"
        default: return "Summary"
        }
    }
}

// MARK: - History Card
struct HistoryCard: View {
    let item: ScanHistoryItem
    @State private var showDetail = false
    @State private var pressed = false

    var body: some View {
        Button { showDetail = true } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.brand1.opacity(0.10))
                        .frame(width: 42, height: 42)
                    Image(systemName: iconFor(item.outputType))
                        .font(.system(size: 16))
                        .foregroundColor(.brand1)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(labelFor(item.outputType))
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundColor(.brand1)
                    Text(item.summary)
                        .font(.system(size: 14, design: .serif))
                        .foregroundColor(.textMed)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(.textLow)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.textLow)
                    .padding(.top, 4)
            }
            .padding(14)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderSubtle, lineWidth: 0.5))
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .sheet(isPresented: $showDetail) { HistoryDetailView(item: item) }
    }

    private func iconFor(_ t: String) -> String {
        switch t {
        case "chart": return "chart.bar.fill"
        case "table": return "tablecells.fill"
        case "flowchart": return "arrow.triangle.branch"
        case "audio": return "mic.fill"
        default: return "text.alignleft"
        }
    }
    private func labelFor(_ t: String) -> String {
        switch t {
        case "audio": return "Voice Summary"
        case "chart": return "Chart"
        case "table": return "Table"
        case "flowchart": return "Flowchart"
        default: return "Summary"
        }
    }
}

// MARK: - History View
struct HistoryView: View {
    @ObservedObject var store: HistoryStore
    @Environment(\.dismiss) var dismiss
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DOCSCAN")
                            .font(.system(size: 11, weight: .semibold, design: .serif))
                            .foregroundColor(.textLow)
                            .kerning(3)
                        Text("History")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundColor(.brand1)
                    }
                    Spacer()
                    HStack(spacing: 14) {
                        if !store.items.isEmpty {
                            Button("Clear") { store.clear() }
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(.textLow)
                        }
                        Button { dismiss() } label: {
                            ZStack {
                                Circle().fill(Color.bgElevated).frame(width: 36, height: 36)
                                    .overlay(Circle().stroke(Color.borderSubtle, lineWidth: 0.5))
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.textMed)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -12)
                .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.05), value: appeared)

                if store.items.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 30))
                            .foregroundColor(.textLow)
                        Text("No history yet")
                            .font(.system(size: 15, design: .serif))
                            .foregroundColor(.textLow)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                                HistoryCard(item: item)
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 20)
                                    .animation(
                                        .spring(response: 0.45, dampingFraction: 0.8)
                                        .delay(0.1 + Double(index) * 0.05),
                                        value: appeared
                                    )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}

// MARK: - Cover State
enum CoverState: Identifiable {
    case camera, crop(UIImage)
    var id: String {
        switch self { case .camera: return "camera"; case .crop: return "crop" }
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var history = HistoryStore()
    @State private var selectedItem: PhotosPickerItem?
    @State private var coverState: CoverState?
    @State private var showHistory = false
    @State private var appState: AppState = .home
    @State private var resultText = ""
    @State private var resultImage: UIImage?
    @State private var outputType = ""
    @State private var animateIn = false
    @State private var loadingPhase = 0
    @State private var isAudioResult = false
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var recordingTime: Int = 0
    @State private var recordingTimer: Timer?
    @State private var pulseRecording = false

    let baseURL = "https://ceroplastic-stylish-gianni.ngrok-free.dev"
    enum AppState { case home, loading, result }

    var body: some View {
        ZStack {
            AppBackground()
            switch appState {
            case .home:
                homeScreen.transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.97)),
                    removal: .opacity.combined(with: .scale(scale: 1.03))))
            case .loading:
                loadingScreen.transition(.opacity)
            case .result:
                resultScreen.transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: appState)
        .fullScreenCover(item: $coverState) { state in
            switch state {
            case .camera:
                DocumentScannerView { image in
                    coverState = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        coverState = .crop(image)
                    }
                }
            case .crop(let image):
                FreehandCropEditorView(
                    image: image,
                    onCancel: { coverState = nil },
                    onUseSelection: { cropped in
                        coverState = nil
                        Task { await uploadImage(cropped) }
                    }
                )
            }
        }
        .sheet(isPresented: $showHistory) { HistoryView(store: history) }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { coverState = .crop(image) }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { animateIn = true }
        }
    }

    // MARK: - Home
    private var homeScreen: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DOCSCAN")
                            .font(.system(size: 11, weight: .semibold, design: .serif))
                            .foregroundColor(.textLow)
                            .kerning(3)
                        Text("Simplify\nAnything.")
                            .font(.system(size: 40, weight: .bold, design: .serif))
                            .foregroundColor(.textHigh)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 16)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showHistory = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.bgElevated)
                                .frame(width: 44, height: 44)
                                .overlay(Circle().stroke(Color.borderSubtle, lineWidth: 0.5))
                            Image(systemName: "clock")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.brand1)
                        }
                    }
                }
                .padding(.leading, 24)
                .padding(.trailing, 24)
                .padding(.top, geo.safeAreaInsets.top + 28)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : -20)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.05), value: animateIn)

                Spacer()

                // Action card — rows animate in staggered
                VStack(spacing: 0) {
                    AnimatedRow(action: { coverState = .camera }) {
                        actionRow(icon: "camera.fill", title: "Use Camera",
                                  subtitle: "Take a photo to scan")
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(x: animateIn ? 0 : -20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.18), value: animateIn)

                    separator

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        actionRow(icon: "photo.on.rectangle", title: "Choose Photo",
                                  subtitle: "Pick from your library")
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(x: animateIn ? 0 : -20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.24), value: animateIn)

                    separator

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if isRecording { stopRecording() } else { startRecording() }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.brand1.opacity(isRecording ? 0.18 : 0.08))
                                    .frame(width: 46, height: 46)
                                    .scaleEffect(isRecording && pulseRecording ? 1.06 : 1.0)
                                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulseRecording)
                                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 19, weight: .medium))
                                    .foregroundColor(.brand1)
                                    .scaleEffect(isRecording ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(isRecording ? "Recording  \(recordingTime)s" : "Record Audio")
                                    .font(.system(size: 16, weight: .semibold, design: .serif))
                                    .foregroundColor(.textHigh)
                                    .animation(.none, value: recordingTime)
                                Text(isRecording ? "Tap to stop and summarize" : "Meetings, lectures, voice notes")
                                    .font(.system(size: 13, design: .serif))
                                    .foregroundColor(.textLow)
                            }
                            Spacer()
                            if isRecording {
                                Circle().fill(Color.brand1).frame(width: 8, height: 8)
                                    .opacity(pulseRecording ? 1 : 0.2)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseRecording)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.textLow)
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 18)
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(x: animateIn ? 0 : -20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.30), value: animateIn)
                }
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.borderSubtle, lineWidth: 0.5))
                .shadow(color: Color.brand1.opacity(0.07), radius: 16, y: 4)
                .padding(.horizontal, 20)
                .padding(.bottom, geo.safeAreaInsets.bottom + 44)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 30)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.12), value: animateIn)
            }
        }
    }

    private func actionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brand1.opacity(0.08))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(.brand1)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(.textHigh)
                Text(subtitle)
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(.textLow)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.textLow)
        }
        .padding(.horizontal, 18).padding(.vertical, 18)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(height: 0.5)
            .padding(.horizontal, 18)
    }

    // MARK: - Loading
    private var loadingScreen: some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.brand1.opacity(Double(3 - i) * 0.15), lineWidth: 1.5)
                        .frame(width: CGFloat(56 + i * 26), height: CGFloat(56 + i * 26))
                        .rotationEffect(.degrees(loadingPhase == 1 ? 360 : 0))
                        .animation(.linear(duration: Double(2 + i)).repeatForever(autoreverses: false), value: loadingPhase)
                }
                Image(systemName: isAudioResult ? "waveform" : "doc.text.magnifyingglass")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.brand1)
                    .scaleEffect(loadingPhase == 1 ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: loadingPhase)
            }
            .onAppear { loadingPhase = 1 }

            VStack(spacing: 8) {
                Text(isAudioResult ? "Analyzing voice..." : "Analyzing document...")
                    .font(.system(size: 21, weight: .semibold, design: .serif))
                    .foregroundColor(.textHigh)
                Text(isAudioResult
                     ? "Transcribing and summarizing your recording"
                     : "Reading, simplifying, and generating output")
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(.textLow)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Result
    private var resultScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        resetHome()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                        }
                        .foregroundColor(.brand1)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Color.bgElevated)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.borderSubtle, lineWidth: 0.5))
                    }
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        shareResult()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Share")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                        }
                        .foregroundColor(.brand1)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Color.bgElevated)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.borderSubtle, lineWidth: 0.5))
                    }
                }
                .padding(.horizontal, 20).padding(.top, 56).padding(.bottom, 24)

                if !outputType.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: iconFor(outputType)).font(.system(size: 11))
                        Text(labelFor(outputType))
                            .font(.system(size: 12, weight: .medium, design: .serif))
                    }
                    .foregroundColor(.brand2)
                    .padding(.horizontal, 20).padding(.bottom, 10)
                }

                if !resultText.isEmpty {
                    SurfaceCard {
                        if outputType == "audio" {
                            BulletSummaryView(text: resultText).padding(20)
                        } else {
                            Text(resultText)
                                .font(.system(size: 16, design: .serif))
                                .foregroundColor(.textHigh)
                                .lineSpacing(6)
                                .padding(20)
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 14)
                }

                if let img = resultImage {
                    SurfaceCard {
                        Image(uiImage: img).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12)).padding(12)
                    }
                    .padding(.horizontal, 20).padding(.bottom, 24)
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    resetHome()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Text(isAudioResult ? "Record Again" : "Scan Another")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                    }
                    .foregroundColor(Color.bgSurface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.brand1)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.brand1.opacity(0.25), radius: 10, y: 4)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Helpers
    private func resetHome() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            appState = .home; resultText = ""; resultImage = nil
            outputType = ""; selectedItem = nil; animateIn = false; isAudioResult = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { animateIn = true }
        }
    }

    private func iconFor(_ t: String) -> String {
        switch t {
        case "chart": return "chart.bar.fill"
        case "table": return "tablecells.fill"
        case "flowchart": return "arrow.triangle.branch"
        case "audio": return "mic.fill"
        default: return "text.alignleft"
        }
    }
    private func labelFor(_ t: String) -> String {
        switch t {
        case "audio": return "Voice Summary"
        case "chart": return "Chart"
        case "table": return "Table"
        case "flowchart": return "Flowchart"
        default: return "Summary"
        }
    }

    private func shareResult() {
        var items: [Any] = []
        if !resultText.isEmpty { items.append(resultText) }
        if let img = resultImage { items.append(img) }
        guard !items.isEmpty else { return }
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    // MARK: - Audio
    func startRecording() {
        AVAudioApplication.requestRecordPermission { granted in
            guard granted else { return }
            DispatchQueue.main.async {
                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.record, mode: .default)
                try? session.setActive(true)
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                do {
                    audioRecorder = try AVAudioRecorder(url: url, settings: settings)
                    audioRecorder?.record()
                    recordingURL = url; isRecording = true; recordingTime = 0; pulseRecording = true
                    recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                        recordingTime += 1
                    }
                } catch { print("Recording failed: \(error)") }
            }
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        pulseRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        if let url = recordingURL { Task { await uploadAudio(url: url) } }
    }

    func uploadAudio(url: URL) async {
        await MainActor.run { isAudioResult = true; withAnimation { appState = .loading } }
        guard let audioData = try? Data(contentsOf: url) else {
            await MainActor.run { withAnimation { appState = .home } }; return
        }
        let uploadURL = URL(string: "\(baseURL)/upload-audio")!
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"; request.timeoutInterval = 300
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)
            let code = (response as? HTTPURLResponse)?.statusCode
            if code == 200, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let summary = json["summary"] as? String ?? ""
                history.add(ScanHistoryItem(outputType: "audio", summary: summary))
                await MainActor.run {
                    outputType = "audio"; resultText = summary; resultImage = nil
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { appState = .result }
                }
            } else {
                await MainActor.run { isAudioResult = false; withAnimation { appState = .home } }
            }
        } catch {
            await MainActor.run { isAudioResult = false; withAnimation { appState = .home } }
        }
    }

    func uploadImage(_ image: UIImage) async {
        await MainActor.run { isAudioResult = false; withAnimation { appState = .loading } }
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            await MainActor.run { withAnimation { appState = .home } }; return
        }
        let url = URL(string: "\(baseURL)/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"; request.timeoutInterval = 120
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"document\"; filename=\"upload.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)
            let code = (response as? HTTPURLResponse)?.statusCode
            if code == 200, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let type = json["output_type"] as? String ?? "text"
                let summary = json["summary"] as? String ?? ""
                let imageB64 = json["image"] as? String
                var visual: UIImage?
                if let b64 = imageB64, let imgData = Data(base64Encoded: b64) {
                    visual = UIImage(data: imgData)
                }
                history.add(ScanHistoryItem(outputType: type, summary: summary, imageData: visual?.pngData()))
                await MainActor.run {
                    outputType = type; resultText = summary; resultImage = visual
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { appState = .result }
                }
            } else {
                await MainActor.run { withAnimation { appState = .home } }
            }
        } catch {
            await MainActor.run { withAnimation { appState = .home } }
        }
    }
}
