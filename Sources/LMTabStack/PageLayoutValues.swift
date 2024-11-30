import SwiftUI

public protocol PageLayoutValueKey {
    associatedtype Value: Equatable & Sendable
    static var defaultValue: Value { get }
}

public struct PageLayoutValues: Equatable {
    private var storage: [ObjectIdentifier: AnyEquatable] = [:]

    subscript<K: PageLayoutValueKey>(type: K.Type) -> K.Value {
        get {
            let key = ObjectIdentifier(type)
            guard let value = storage[key] else { return K.defaultValue }
            return value.base as! K.Value
        }
        set {
            let key = ObjectIdentifier(type)
            storage[key] = .init(base: newValue)
        }
    }
}

extension PageLayoutValues {
    private enum PreferredZIndexKey: PageLayoutValueKey {
        static var defaultValue: Double? { nil }
    }

    public var preferredZIndex: Double? {
        get { self[PreferredZIndexKey.self] }
        set { self[PreferredZIndexKey.self] = newValue }
    }
}

extension ContainerValues {
    @Entry
    var pageLayoutValues: PageLayoutValues = .init()

    @Entry
    var tabStackPreferredZIndex: Double? = nil
}

extension View {
    public func tabStackPreferredZIndex(_ value: Double) -> some View {
        containerValue(\.tabStackPreferredZIndex, value)
    }

    public func pageLayout<Value>(_ keyPath: WritableKeyPath<PageLayoutValues, Value>, _ value: Value) -> some View {
        let parent: WritableKeyPath<ContainerValues, PageLayoutValues> = \ContainerValues.pageLayoutValues
        let child = parent.appending(path: keyPath)
        return containerValue(child, value)
    }

    public func pagePreferredZIndex(_ value: Double) -> some View {
        pageLayout(\.preferredZIndex, value)
    }
}

