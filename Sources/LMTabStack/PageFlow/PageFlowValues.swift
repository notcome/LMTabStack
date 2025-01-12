import SwiftUI

public protocol PageFlowValueKey {
    associatedtype Value: Equatable & Sendable
    static var defaultValue: Value { get }
}

public struct PageFlowValues: Equatable {
    private var storage: [ObjectIdentifier: AnySendableEquatable] = [:]

    public subscript<K: PageFlowValueKey>(type: K.Type) -> K.Value {
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

extension ContainerValues {
    @Entry
    public var pageFlowValues: PageFlowValues = .init()
}

extension View {
    public func pageFlow<Value>(_ keyPath: WritableKeyPath<PageFlowValues, Value>, _ value: Value) -> some View {
        let parent: WritableKeyPath<ContainerValues, PageFlowValues> = \ContainerValues.pageFlowValues
        let child = parent.appending(path: keyPath)
        return containerValue(child, value)
    }
}

