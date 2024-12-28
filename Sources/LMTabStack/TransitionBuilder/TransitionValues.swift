import ComposableArchitecture
import SwiftUI

public protocol TransitionKey {
    associatedtype Value: Equatable & Sendable
    static var defaultValue: Value { get }
}

@ObservableState
public struct TransitionValues: Equatable, Sendable, CustomStringConvertible {
    @ObservationStateIgnored
    var dict: [ObjectIdentifier: AnySendableEquatable] = [:]

    // An easy trick make it observable.
    private(set) var isEmpty: Bool = false

    public var description: String {
        dict.description
    }

    private subscript(key: ObjectIdentifier) -> AnySendableEquatable? {
        get {
            _$observationRegistrar.access(self, keyPath: \.[key])
            return dict[key]
        }
        set {
            _$observationRegistrar.mutate(self, keyPath: \.[key], &dict[key], newValue) {
                $0 == $1
            }
            isEmpty = dict.isEmpty
        }
    }

    public subscript<K: TransitionKey>(type: K.Type) -> K.Value {
        get {
            guard let value = self[ObjectIdentifier(type)] else { return K.defaultValue }
            return value.base as! K.Value
        }
        set {
            self[ObjectIdentifier(type)] = AnySendableEquatable(base: newValue)
        }
    }

    mutating func merge(_ other: Self) {
        for (key, value) in other.dict {
            self[key] = value
        }
    }
}

// MARK: - Common Transition Properties

struct CommonTransitionProperties {
    var opacity: Double?
    var offsetX: Double?
    var offsetY: Double?
    var scaleX: Double?
    var scaleY: Double?

    var offset: CGSize {
        .init(width: offsetX ?? 0, height: offsetY ?? 0)
    }

    var scale: CGSize {
        .init(width: scaleX ?? 1, height: scaleY ?? 1)
    }
}

extension TransitionValues {
    var commonTransitionProperties: CommonTransitionProperties {
        .init(
            opacity: opacity,
            offsetX: offsetX,
            offsetY: offsetY,
            scaleX: scaleX,
            scaleY: scaleY)
    }
}

private enum ScaleXKey: TransitionKey {
    static var defaultValue: Double? { nil }
}

private enum ScaleYKey: TransitionKey {
    static var defaultValue: Double? { nil }
}

private enum OffsetXKey: TransitionKey {
    static var defaultValue: Double? { nil }
}

private enum OffsetYKey: TransitionKey {
    static var defaultValue: Double? { nil }
}

private enum OpacityKey: TransitionKey {
    static var defaultValue: Double? { nil }
}

private enum BlurRadiusKey: TransitionKey {
    static var defaultValue: Double? { nil }
}

extension TransitionValues {
    public var scaleX: Double? {
        get { self[ScaleXKey.self] }
        set { self[ScaleXKey.self] = newValue }
    }
    
    public var scaleY: Double? {
        get { self[ScaleYKey.self] }
        set { self[ScaleYKey.self] = newValue }
    }
    
    public var offsetX: Double? {
        get { self[OffsetXKey.self] }
        set { self[OffsetXKey.self] = newValue }
    }
    
    public var offsetY: Double? {
        get { self[OffsetYKey.self] }
        set { self[OffsetYKey.self] = newValue }
    }
    
    public var opacity: Double? {
        get { self[OpacityKey.self] }
        set { self[OpacityKey.self] = newValue }
    }
    
    public var blurRadius: Double? {
        get { self[BlurRadiusKey.self] }
        set { self[BlurRadiusKey.self] = newValue }
    }
}

extension TransitionValues: CustomDebugStringConvertible {
    public var debugDescription: String {
        var props: [String: String] = [:]
        for (key, value) in dict {
            let type = unsafeBitCast(key, to: Any.Type.self)
            let label = if type == ScaleXKey.self {
                "sx"
            } else if type == ScaleYKey.self {
                "sy"
            } else if type == OffsetXKey.self {
                "dx"
            } else if type == OffsetYKey.self {
                "dy"
            } else if type == OpacityKey.self {
                "alpha"
            } else if type == BlurRadiusKey.self {
                "blurRadius"
            } else {
                "\(type)"
            }
            props[label] = "\(value.base)"
        }

        let sortedProps = props.sorted(by: { $0.key < $1.key }).map { "\($0.key): \($0.value)" }
        return "TransitionValues(\(sortedProps.joined(separator: ", ")))"
    }
}
