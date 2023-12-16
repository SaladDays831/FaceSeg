import SwiftUI

struct CoolButton: View {
    var title: String
    var action: (() -> Void)
    
    var body: some View {
        Button(title) {
            action()
        }
        .frame(width: 140, height: 40)
        .background(Color.purple)
        .foregroundStyle(.black)
        .font(.system(size: 15, weight: .semibold))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
