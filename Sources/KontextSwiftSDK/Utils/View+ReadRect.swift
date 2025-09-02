import SwiftUI

private struct RectPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect { .zero }
    static func reduce(value _: inout CGRect, nextValue _: () -> CGRect) {}
}

public extension View {
    func readRect(
        coordinateSpace: CoordinateSpace = .global,
        onChange: @escaping (CGRect) -> Void
    ) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(
                        key: RectPreferenceKey.self,
                        value: geometryProxy.frame(in: coordinateSpace)
                    )
            }
        )
        .onPreferenceChange(RectPreferenceKey.self, perform: onChange)
    }
}
