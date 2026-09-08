import WidgetKit
import SwiftUI

@main
struct ActualWidgetBundle: WidgetBundle {
    var body: some Widget {
        SessionWidget()
        SessionLiveActivity()
    }
}
