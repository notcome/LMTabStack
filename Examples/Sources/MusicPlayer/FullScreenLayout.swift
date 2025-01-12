import ComposableArchitecture
import LMTabStack
import SwiftUI

struct FullScreenPages {
    var home: Subview
    var timer: Subview?
    var info: Subview?
    var addTime: Subview?

    struct Projection: Equatable {
        var hasTimer: Bool
        var hasInfo: Bool
        var hasAddTime: Bool
    }

    var projection: Projection {
        Projection(
            hasTimer: timer != nil,
            hasInfo: info != nil,
            hasAddTime: addTime != nil
        )
    }
}

extension FullScreenPages {
    static func from(sections: SectionCollection) -> Self {
        var views: [String: Subview] = [:]
        for section in sections {
            for view in section.content {
                guard let id = view.containerValues.tag(for: AnyPageID.self),
                      let stringID = id.base as? String
                else { continue }
                views[stringID] = view
            }
        }

        var pages = FullScreenPages(home: views["Home"]!)
        pages.timer = views["Timer"]
        pages.info = views["Info"]
        pages.addTime = views["AddTime"]
        return pages
    }

    var sessionViews: [(String, Subview)]? {
        var list: [(String, Subview)] = []
        if let timer {
            list.append(("Timer", timer))
        }
        if let info {
            list.append(("Info", info))
        }
        return list.isEmpty ? nil : list
    }
}

struct SessionPagesScrollView: View {
    var size: CGSize
    var sessionViews: [(String, Subview)]

    @Bindable
    var store: StoreOf<SessionFeature>

    @State
    private var position: ScrollPosition = .init(idType: String.self)

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(sessionViews, id: \.0) { pair in
                    pair.1
                        .frame(width: size.width, height: size.height)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition($position)
        .onAppear {
            position.scrollTo(id: store.showsTimer ? "Timer" : "Info")
        }
        .onChange(of: store.showsTimer) { _, showsTimer in
            if let viewID = position.viewID(type: String.self) {
                if viewID == "Timer", showsTimer {
                    return
                }
                if viewID == "Info", !showsTimer {
                    return
                }
            }
            withAnimation {
                position.scrollTo(id: showsTimer ? "Timer" : "Info")
            }

        }
        .onChange(of: position) { _, newValue in
            guard let viewID = newValue.viewID(type: String.self) else { return }
            if !store.showsTimer, viewID == "Timer" {
                store.showsTimer = true
            } else if store.showsTimer, viewID == "Info" {
                store.showsTimer = false
            }
        }

        .background {
            HStack(spacing: 0) {
                Rectangle()
                    .foregroundStyle(leadingColor)
                Rectangle()
                    .foregroundStyle(trailingColor)
            }
            .ignoresSafeArea(.all)
        }
        .scrollTargetBehavior(.paging)
    }

    var leadingColor: Color {
        sessionViews.first!.1.containerValues.pageFlowValues.pageBackground
    }
    var trailingColor: Color {
        sessionViews.last!.1.containerValues.pageFlowValues.pageBackground
    }
}

struct FullScreenLayoutView: View {
    var pages: FullScreenPages

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                pages.home
                    .frame(width: proxy.size.width, height: proxy.size.height)

                if let sessionViews = pages.sessionViews {
                    let store = sessionViews.first {
                        $0.0 == "Info"
                    }!.1.containerValues.tag(for: StoreOf<SessionFeature>.self)!

                    SessionPagesScrollView(size: proxy.size, sessionViews: sessionViews, store: store)
                }

                if let addTime = pages.addTime {
                    addTime
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }
    }
}

struct FullScreenLayout: PageFlowLayout {
    @ViewBuilder
    func body(sections: SectionCollection) -> some View {
        let pages = FullScreenPages.from(sections: sections)
        FullScreenLayoutView(pages: pages)
            .onChange(of: pages.projection) { oldValue, newValue in
                print(oldValue, newValue)
            }
    }
}
