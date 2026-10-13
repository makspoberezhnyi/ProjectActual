import SwiftUI

struct LogbookInstrumentView: View {
    var sessions: [Session]
    var calibrationScore: Double
    private let store = TimeOSStore.shared

    enum Section: String, CaseIterable, Identifiable {
        case insights = "Insights"
        case history = "History"
        case settings = "Settings"
        var id: String { rawValue }
    }

    @State private var section: Section = .insights
    @State private var showMascotStudio = false

    init(sessions: [Session] = [], calibrationScore: Double = 0.78) {
        self.sessions = sessions
        self.calibrationScore = calibrationScore
    }

    var body: some View {
        NavigationStack {
            Group {
                switch section {
                case .insights:
                    InsightsTabView(sessions: sessions, calibrationScore: calibrationScore)
                case .history:
                    HistoryTabView(sessions: sessions)
                case .settings:
                    ProfileTabView(sessions: sessions, calibrationScore: calibrationScore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SharedBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Section", selection: $section) {
                        ForEach(Section.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mascot studio", systemImage: "face.smiling") { showMascotStudio = true }
                        .tint(Color.tempoAccent)
                }
            }
            .sheet(isPresented: $showMascotStudio) {
                NavigationStack {
                    MascotRegimeStudioView(store: store)
                        .background(SharedBackground())
                        .navigationTitle("Mascot Studio")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
}

#Preview("Logbook") {
    LogbookInstrumentView()
}

#Preview("Logbook · Dark") {
    LogbookInstrumentView()
        .preferredColorScheme(.dark)
}
