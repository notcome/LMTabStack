import SwiftUI

extension View {
    func onChangeWithTransaction<T: Equatable>(
        of value: T,
        action: @escaping (T, Transaction) -> Void
    ) -> some View {
        modifier(_OnChangeWithTransaction(value: value, action: action))
    }
}

private struct _OnChangeWithTransaction<T: Equatable>: ViewModifier {
    var value: T
    var action: (T, Transaction) -> Void

    @MainActor
    struct _TransactionReader {
        var value: T
        var action: (T, Transaction) -> Void

        func updateModel(transaction: Transaction) {
            DispatchQueue.main.async {
                action(value, transaction)
            }
        }
    }

    struct _Equatable: Equatable {
        var value: T
        var action: (T, Transaction) -> Void

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.value == rhs.value
        }
    }

    func body(content: Content) -> some View {
        content
            .background {
                _Equatable(value: value, action: action)
                    .equatable()
            }
    }
}

extension _OnChangeWithTransaction._Equatable: View {
    var body: some View {
        _OnChangeWithTransaction._TransactionReader(
            value: value,
            action: action)
    }
}

#if os(macOS) && !targetEnvironment(macCatalyst)
extension _OnChangeWithTransaction._TransactionReader: NSViewRepresentable {
    fileprivate func makeNSView(context: Context) -> NSView {
        .init()
    }

    fileprivate func updateNSView(_: NSView, context: Context) {
        updateModel(transaction: context.transaction)
    }
}
#endif

#if os(iOS) || targetEnvironment(macCatalyst)
extension _OnChangeWithTransaction._TransactionReader: UIViewRepresentable {
    fileprivate func makeUIView(context: Context) -> UIView {
        .init()
    }

    fileprivate func updateUIView(_: UIView, context: Context) {
        updateModel(transaction: context.transaction)
    }
}
#endif
