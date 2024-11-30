import ComposableArchitecture
import SwiftUI

public protocol PageTransitionKey {
    associatedtype Value: Equatable & Sendable
    static var defaultValue: Value { get }
}

@ObservableState
public struct PageTransitionValues: Equatable, Sendable {
    @ObservationStateIgnored
    var dict: [ObjectIdentifier: AnyEquatable] = [:]

    private subscript(key: ObjectIdentifier) -> AnyEquatable? {
        get {
            _$observationRegistrar.access(self, keyPath: \.[key])
            return dict[key]
        }
        set {
            _$observationRegistrar.mutate(self, keyPath: \.[key], &dict[key], newValue) {
                $0 == $1
            }
        }
    }

    public subscript<K: PageTransitionKey>(type: K.Type) -> K.Value {
        get {
            guard let value = self[ObjectIdentifier(type)] else { return K.defaultValue }
            return value.base as! K.Value
        }
        set {
            if newValue == K.defaultValue {
                self[ObjectIdentifier(type)] = nil
            } else {
                self[ObjectIdentifier(type)] = AnyEquatable(base: newValue)
            }
        }
    }

    mutating func merge(_ other: Self) {
        for (key, value) in other.dict {
            self[key] = value
        }
    }

    mutating func reset() {
        for key in dict.keys {
            self[key] = nil
        }
    }
}

@MainActor
@propertyWrapper
public struct PageTransition<Value>: DynamicProperty {
    @Environment(PageHostingStore.self)
    private var store

    private var keyPath: KeyPath<PageTransitionValues, Value>

    public var wrappedValue: Value {
        store.transitionValues[keyPath: keyPath]
    }

    public init(_ keyPath: KeyPath<PageTransitionValues, Value>) {
        self.keyPath = keyPath
    }
}

extension View {
    public func pageTransition<Value>(_ keyPath: WritableKeyPath<PageTransitionValues, Value>, _ value: Value) -> some View {
        let parent: WritableKeyPath<ContainerValues, PageTransitionValues> = \ContainerValues.transitionValues
        let child = parent.appending(path: keyPath)
        return containerValue(child, value)
    }
}
