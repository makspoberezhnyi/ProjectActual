import SwiftUI

// MARK: - REAL APPLE APP ICONS (Used by Integrations & Calendar Chips)

struct RealCalendarAppIcon: View {
    var size: CGFloat = 24
    
    private var weekdayString: String {
        TempoFormatters.calendarMonthFormatter.string(from: Date()).uppercased()
    }
    
    private var dayString: String {
        TempoFormatters.calendarDayNumberFormatter.string(from: Date())
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1)
            
            VStack(spacing: 0) {
                ZStack {
                    UnevenRoundedRectangle(
                        topLeadingRadius: size * 0.22,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: size * 0.22,
                        style: .continuous
                    )
                    .fill(Color(red: 0.95, green: 0.23, blue: 0.23))
                    
                    Text(weekdayString)
                        .font(.system(size: max(6, size * 0.28), weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(height: size * 0.38)
                
                Text(dayString)
                    .font(.system(size: max(8, size * 0.44), weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.black.opacity(0.85))
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: size, height: size)
    }
}

struct RealRemindersAppIcon: View {
    var size: CGFloat = 24
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: size * 0.09) {
                HStack(spacing: size * 0.08) {
                    Circle().fill(Color(red: 0.98, green: 0.55, blue: 0.14)).frame(width: size * 0.17, height: size * 0.17)
                    Capsule().fill(Color(red: 0.82, green: 0.82, blue: 0.85)).frame(width: size * 0.44, height: size * 0.07)
                }
                HStack(spacing: size * 0.08) {
                    Circle().fill(Color(red: 0.18, green: 0.56, blue: 0.98)).frame(width: size * 0.17, height: size * 0.17)
                    Capsule().fill(Color(red: 0.82, green: 0.82, blue: 0.85)).frame(width: size * 0.44, height: size * 0.07)
                }
                HStack(spacing: size * 0.08) {
                    Circle().fill(Color(red: 0.38, green: 0.82, blue: 0.38)).frame(width: size * 0.17, height: size * 0.17)
                    Capsule().fill(Color(red: 0.82, green: 0.82, blue: 0.85)).frame(width: size * 0.32, height: size * 0.07)
                }
            }
            .padding(.horizontal, size * 0.13)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        )
    }
}

struct RealUnifiedIntegrationIcon: View {
    var size: CGFloat = 24
    
    var body: some View {
        HStack(spacing: -size * 0.28) {
            RealCalendarAppIcon(size: size * 0.88)
            RealRemindersAppIcon(size: size * 0.88)
        }
    }
}

extension Notification.Name {
    static let checkScheduleNotification = Notification.Name("checkScheduleNotification")
    static let syncWidgetSessionsNotification = Notification.Name("syncWidgetSessionsNotification")
}
