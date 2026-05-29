// LINKS APP
// VERSION 3.20
// Light font, full-row hover hit area, icon brightness on hover
// 2026-05-28

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct LinkItem: Identifiable, Codable, Equatable {

    var id = UUID()
    var title: String
    var icon: String
    var url: String

    var isGroup: Bool = false
    var isExpanded: Bool = true

    var children: [LinkItem] = []
}

struct AppShortcut: Identifiable, Codable, Equatable {

    var id = UUID()
    var title: String
    var icon: String
    var url: String
}

struct VisibleLinkItem: Identifiable {

    let id: UUID
    let item: LinkItem
    let level: Int
}

enum LinkEditorMode: Identifiable {

    case addRoot
    case edit(LinkItem)
    case addChild(UUID)

    var id: String {

        switch self {

        case .addRoot:
            return "addRoot"

        case .edit(let item):
            return "edit-\(item.id)"

        case .addChild(let id):
            return "child-\(id)"
        }
    }
}

private let defaultZoomStep = 5

struct ContentView: View {

    @State private var links: [LinkItem] = []
    @State private var shortcuts: [AppShortcut] = []

    @State private var selectedShortcut: AppShortcut?

    @State private var linkEditorMode: LinkEditorMode?

    @State private var showingAddShortcutSheet = false

    @State private var draggedShortcut: AppShortcut?
    @State private var draggedLinkID: UUID?

    @State private var hoveringAddShortcut = false
    @State private var hoveringAddLink = false

    @State private var hoveringIconMinus = false
    @State private var hoveringIconPlus = false
    @State private var hoveringLinkMinus = false
    @State private var hoveringLinkPlus = false

    @State private var linkSaveTask: DispatchWorkItem?
    @State private var shortcutSaveTask: DispatchWorkItem?
    @AppStorage("iconZoomStep") private var iconZoomStep: Int = defaultZoomStep
    @AppStorage("linkZoomStep") private var linkZoomStep: Int = defaultZoomStep

    let zoomSteps: [CGFloat] = [0.40, 0.55, 0.70, 0.82, 0.91, 1.00, 1.12, 1.25, 1.40, 1.60, 1.85, 2.20]

    var iconZoomFactor: CGFloat {
        zoomSteps[max(0, min(iconZoomStep, zoomSteps.count - 1))]
    }

    var linkZoomFactor: CGFloat {
        zoomSteps[max(0, min(linkZoomStep, zoomSteps.count - 1))]
    }

    let borderColor = Color.gray.opacity(0.28)
    let hoverBorderColor = Color.white.opacity(1.0)
    let panelFill = Color.white.opacity(0.025)
    var shortcutIconSize: CGFloat { 69 * iconZoomFactor }
    var shortcutIconSpacing: CGFloat { 10 * iconZoomFactor }
    let frameCornerRadius: CGFloat = 10
    let innerFrameInset: CGFloat = 24

    var body: some View {

        VStack(alignment: .leading, spacing: 10) {

            shortcutRow

            linkList
                .padding(.trailing, -22)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .preferredColorScheme(.dark)
        .overlay(alignment: .topTrailing) {
            iconScaleStepper
                .padding(.trailing, 22)
                .offset(y: -21)
        }
        .overlay(alignment: .bottomTrailing) {
            linkScaleStepper
                .padding(.trailing, 22)
                .padding(.bottom, 22)
        }
        .sheet(item: $linkEditorMode) { mode in

            switch mode {

            case .addRoot:

                LinkEditorView(
                    item: LinkItem(
                        title: "",
                        icon: "link",
                        url: ""
                    )
                ) { item in

                    links.append(item)
                    scheduleSaveLinks()
                }

            case .edit(let item):

                LinkEditorView(item: item) { updatedItem in

                    updateItem(updatedItem, in: &links)
                    scheduleSaveLinks()
                }

            case .addChild(let parentID):

                LinkEditorView(
                    item: LinkItem(
                        title: "",
                        icon: "link",
                        url: ""
                    )
                ) { item in

                    addChild(item, to: parentID, in: &links)
                    scheduleSaveLinks()
                }
            }
        }
        .sheet(isPresented: $showingAddShortcutSheet) {

            ShortcutEditorView(
                title: "",
                icon: "app",
                url: ""
            ) { title, icon, url in

                shortcuts.append(
                    AppShortcut(
                        title: title,
                        icon: icon,
                        url: url
                    )
                )

                scheduleSaveShortcuts()
            }
        }
        .sheet(item: $selectedShortcut) { shortcut in

            ShortcutEditorView(
                title: shortcut.title,
                icon: shortcut.icon,
                url: shortcut.url
            ) { title, icon, url in

                if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {

                    shortcuts[index].title = title
                    shortcuts[index].icon = icon
                    shortcuts[index].url = url

                    scheduleSaveShortcuts()
                }
            }
        }
        .onAppear {

            loadLinks()
            loadShortcuts()

            // Configure the window after SwiftUI has finished building it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard let window = NSApplication.shared.windows.first else { return }
                // Allow dragging from anywhere in the window body
                window.isMovableByWindowBackground = true
                // Normal managed window — no forced snapping to screen edges
                window.collectionBehavior = [.managed, .participatesInCycle]
                // Disable frame autosave so previous positions don't override
                window.setFrameAutosaveName("")
                // Cap resize at the usable screen area
                if let screen = NSScreen.main {
                    window.maxSize = screen.visibleFrame.size
                }
                // Transparent title bar + clear window background lets SwiftUI fill everything
                window.titlebarAppearsTransparent = true
                window.backgroundColor = .clear
            }
        }
    }

    var background: some View {

        Color(NSColor.windowBackgroundColor)
            .ignoresSafeArea()
    }

    var topBar: some View {

        HStack {

            Spacer()
        }
        .frame(height: 24)
        .background(Color.black.opacity(0.26))
    }

    var sideBorder: some View {

        Rectangle()
            .fill(Color.black.opacity(0.24))
            .frame(width: 24)
    }

    var shortcutRow: some View {

        VStack(alignment: .leading, spacing: 18) {

            LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: shortcutIconSize,
                        maximum: shortcutIconSize
                    ),
                    spacing: shortcutIconSpacing,
                    alignment: .leading
                )
            ],
            alignment: .leading,
            spacing: shortcutIconSpacing
        ) {

            ForEach(shortcuts) { shortcut in

                Button {

                    openURL(shortcut.url)

                } label: {

                    shortcutIcon(shortcut)
                }
                .buttonStyle(.plain)
                .onDrag {

                    draggedShortcut = shortcut

                    return NSItemProvider(
                        object: shortcut.id.uuidString as NSString
                    )
                }
                .onDrop(
                    of: [.text],
                    delegate: ShortcutDropDelegate(
                        targetShortcut: shortcut,
                        shortcuts: $shortcuts,
                        draggedShortcut: $draggedShortcut,
                        saveAction: scheduleSaveShortcuts
                    )
                )
                .contextMenu {

                    Button("Edit Software Icon") {

                        selectedShortcut = shortcut
                    }

                    Button(
                        "Delete Software Icon",
                        role: .destructive
                    ) {

                        shortcuts.removeAll {
                            $0.id == shortcut.id
                        }

                        scheduleSaveShortcuts()
                    }
                }
            }

            addShortcutButton
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )

        }
        .padding(.bottom, 2)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    var addShortcutButton: some View {

        Button {

            showingAddShortcutSheet = true

        } label: {

            ZStack {

                Image(systemName: "plus")
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(hoveringAddShortcut ? 0.70 : 0.28)
                    )
            }
            .frame(width: shortcutIconSize * 0.7, height: shortcutIconSize * 0.7)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(hoveringAddShortcut ? hoverBorderColor : borderColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in

            withAnimation(.easeOut(duration: 0.12)) {

                hoveringAddShortcut = hovering
            }
        }
    }

    func shortcutIcon(_ shortcut: AppShortcut) -> some View {
        HoverShortcutIcon(
            shortcut: shortcut,
            borderColor: borderColor,
            hoverBorderColor: hoverBorderColor,
            iconSize: shortcutIconSize
        )
    }

    var linkList: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 12
            ) {

                ForEach(visibleLinks) { visible in

                    HoverLinkRow(
                        link: visible.item,
                        level: visible.level,
                        borderColor: borderColor,
                        hoverBorderColor: hoverBorderColor,
                        zoomFactor: linkZoomFactor
                    ) {

                        if visible.item.isGroup {

                            toggleExpanded(
                                visible.item.id,
                                in: &links
                            )

                            scheduleSaveLinks()

                        } else {

                            openURL(visible.item.url)
                        }
                    }
                    .onDrag {

                        draggedLinkID = visible.item.id

                        return NSItemProvider(
                            object: visible.item.id.uuidString as NSString
                        )
                    }
                    .onDrop(
                        of: [.text],
                        delegate: LinkReorderDropDelegate(
                            targetID: visible.item.id,
                            links: $links,
                            draggedLinkID: $draggedLinkID,
                            saveAction: scheduleSaveLinks
                        )
                    )
                    .contextMenu {

                        Button("Edit") {

                            linkEditorMode = .edit(
                                visible.item
                            )
                        }

                        if visible.item.isGroup {

                            Button("Add Link To Group") {

                                linkEditorMode = .addChild(
                                    visible.item.id
                                )
                            }
                        }

                        Button(
                            "Delete",
                            role: .destructive
                        ) {

                            deleteItem(
                                visible.item.id,
                                from: &links
                            )

                            scheduleSaveLinks()
                        }
                    }
                }

                addLinkRow
            }
            .padding(.bottom, 18)
            .padding(.trailing, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ScrollbarCustomizer())
    }


    var visibleLinks: [VisibleLinkItem] {

        flattenLinks(
            links,
            level: 0
        )
    }

    func flattenLinks(
        _ items: [LinkItem],
        level: Int
    ) -> [VisibleLinkItem] {

        var result: [VisibleLinkItem] = []

        for item in items {

            result.append(
                VisibleLinkItem(
                    id: item.id,
                    item: item,
                    level: level
                )
            )

            if item.isGroup &&
                item.isExpanded {

                result.append(
                    contentsOf: flattenLinks(
                        item.children,
                        level: level + 1
                    )
                )
            }
        }

        return result
    }

    var addLinkRow: some View {

        Button {

            linkEditorMode = .addRoot

        } label: {

            HStack(spacing: 14) {

                ZStack {

                    RoundedRectangle(cornerRadius: 7)
                        .stroke(
                            hoveringAddLink
                            ? hoverBorderColor
                            : borderColor,
                            lineWidth: 0.5
                        )

                    Image(systemName: "plus")
                        .font(
                            .system(
                                size: 11 * linkZoomFactor,
                                weight: .regular
                            )
                        )
                        .foregroundStyle(
                            .white.opacity(hoveringAddLink ? 0.70 : 0.28)
                        )
                }
                .frame(width: 24 * linkZoomFactor, height: 24 * linkZoomFactor)

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 37 * linkZoomFactor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        hoveringAddLink ? hoverBorderColor : borderColor,
                        lineWidth: 0.5
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in

            withAnimation(.easeOut(duration: 0.12)) {

                hoveringAddLink = hovering
            }
        }
    }

    var iconScaleStepper: some View {

        HStack(spacing: 0) {

            Button { zoomIconOut() } label: {

                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(hoveringIconMinus ? 0.70 : 0.28))
                    .frame(width: 30, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hoveringIconMinus = h } }

            Divider()
                .frame(height: 10)

            Button { zoomIconIn() } label: {

                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(hoveringIconPlus ? 0.70 : 0.28))
                    .frame(width: 30, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hoveringIconPlus = h } }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke((hoveringIconMinus || hoveringIconPlus) ? hoverBorderColor : borderColor, lineWidth: 0.5)
        )
    }

    var linkScaleStepper: some View {

        HStack(spacing: 0) {

            Button { zoomLinkOut() } label: {

                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(hoveringLinkMinus ? 0.70 : 0.28))
                    .frame(width: 30, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hoveringLinkMinus = h } }

            Divider()
                .frame(height: 10)

            Button { zoomLinkIn() } label: {

                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(hoveringLinkPlus ? 0.70 : 0.28))
                    .frame(width: 30, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hoveringLinkPlus = h } }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke((hoveringLinkMinus || hoveringLinkPlus) ? hoverBorderColor : borderColor, lineWidth: 0.5)
        )
    }

    var bottomBar: some View {

        Rectangle()
            .fill(Color.black.opacity(0.22))
            .frame(height: 24)
    }

    // Per-section scale controls
    func zoomIconIn() {
        guard iconZoomStep < zoomSteps.count - 1 else { return }
        withAnimation(.easeOut(duration: 0.15)) { iconZoomStep += 1 }
    }

    func zoomIconOut() {
        guard iconZoomStep > 0 else { return }
        withAnimation(.easeOut(duration: 0.15)) { iconZoomStep -= 1 }
    }

    func zoomLinkIn() {
        guard linkZoomStep < zoomSteps.count - 1 else { return }
        withAnimation(.easeOut(duration: 0.15)) { linkZoomStep += 1 }
    }

    func zoomLinkOut() {
        guard linkZoomStep > 0 else { return }
        withAnimation(.easeOut(duration: 0.15)) { linkZoomStep -= 1 }
    }

    func openURL(_ target: String) {

        if target.hasPrefix("/") ||
            target.hasSuffix(".app") {

            let fileURL = URL(
                fileURLWithPath: target
            )

            NSWorkspace.shared.open(fileURL)

            return
        }

        if let url = URL(string: target) {

            NSWorkspace.shared.open(url)
        }
    }
    func scheduleSaveLinks() {

        linkSaveTask?.cancel()

        let snapshot = links

        let task = DispatchWorkItem {

            if let data = try? JSONEncoder().encode(snapshot) {

                UserDefaults.standard.set(
                    data,
                    forKey: "SavedLinkItemsV2"
                )
            }
        }

        linkSaveTask = task

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.35,
            execute: task
        )
    }

    func loadLinks() {

        if let data = UserDefaults.standard.data(
            forKey: "SavedLinkItemsV2"
        ),
           let saved = try? JSONDecoder()
            .decode([LinkItem].self, from: data) {

            links = saved

        } else {

            links = [

                LinkItem(
                    title: "Client Tools",
                    icon: "folder",
                    url: "",
                    isGroup: true,
                    isExpanded: true,
                    children: [

                        LinkItem(
                            title: "ShotGrid",
                            icon: "cube.transparent.fill",
                            url: "https://shotgrid.autodesk.com"
                        ),

                        LinkItem(
                            title: "Frame.io",
                            icon: "eye.fill",
                            url: "https://frame.io"
                        )
                    ]
                ),

                LinkItem(
                    title: "Atomic Bid Planner",
                    icon: "plus",
                    url: "https://docs.google.com"
                ),

                LinkItem(
                    title: "VFX Tracking",
                    icon: "waveform.path.ecg",
                    url: "https://docs.google.com"
                )
            ]
        }
    }
    func scheduleSaveShortcuts() {

        shortcutSaveTask?.cancel()

        let snapshot = shortcuts

        let task = DispatchWorkItem {

            if let data = try? JSONEncoder().encode(snapshot) {

                UserDefaults.standard.set(
                    data,
                    forKey: "SavedShortcuts"
                )
            }
        }

        shortcutSaveTask = task

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.35,
            execute: task
        )
    }

    func loadShortcuts() {

        if let data = UserDefaults.standard.data(
            forKey: "SavedShortcuts"
        ),
           let saved = try? JSONDecoder()
            .decode([AppShortcut].self, from: data) {

            shortcuts = saved

        } else {

            shortcuts = [

                AppShortcut(
                    title: "Firefox",
                    icon: "globe",
                    url: "/Applications/Firefox.app"
                ),

                AppShortcut(
                    title: "VS Code",
                    icon: "chevron.left.forwardslash.chevron.right",
                    url: "/Applications/Visual Studio Code.app"
                ),

                AppShortcut(
                    title: "YouTube",
                    icon: "play.rectangle.fill",
                    url: "https://youtube.com"
                )
            ]
        }
    }

    func toggleExpanded(
        _ id: UUID,
        in items: inout [LinkItem]
    ) {

        for index in items.indices {

            if items[index].id == id {

                items[index].isExpanded.toggle()
                return
            }

            toggleExpanded(
                id,
                in: &items[index].children
            )
        }
    }

    func addChild(
        _ child: LinkItem,
        to parentID: UUID,
        in items: inout [LinkItem]
    ) {

        for index in items.indices {

            if items[index].id == parentID {

                items[index].children.append(child)
                items[index].isGroup = true
                items[index].isExpanded = true

                return
            }

            addChild(
                child,
                to: parentID,
                in: &items[index].children
            )
        }
    }

    func updateItem(
        _ updated: LinkItem,
        in items: inout [LinkItem]
    ) {

        for index in items.indices {

            if items[index].id == updated.id {

                let existingChildren =
                    items[index].children

                items[index].title =
                    updated.title

                items[index].icon =
                    updated.icon

                items[index].url =
                    updated.isGroup
                    ? ""
                    : updated.url

                items[index].isGroup =
                    updated.isGroup

                items[index].isExpanded =
                    updated.isExpanded

                items[index].children =
                    existingChildren

                return
            }

            updateItem(
                updated,
                in: &items[index].children
            )
        }
    }

    func deleteItem(
        _ id: UUID,
        from items: inout [LinkItem]
    ) {

        items.removeAll {

            $0.id == id
        }

        for index in items.indices {

            deleteItem(
                id,
                from: &items[index].children
            )
        }
    }
}

struct HoverShortcutIcon: View {

    let shortcut: AppShortcut
    let borderColor: Color
    let hoverBorderColor: Color
    let iconSize: CGFloat

    @State private var hovering = false

    var body: some View {

        ZStack {

            if isImagePath(shortcut.icon),
               let customIcon = NSImage(contentsOfFile: shortcut.icon) {

                Image(nsImage: customIcon)
                    .resizable()
                    .scaledToFill()
                    .frame(width: iconSize * 1.22, height: iconSize * 1.22)

            } else if isApplicationPath(shortcut.url) {

                Image(nsImage: NSWorkspace.shared.icon(forFile: shortcut.url))
                    .resizable()
                    .scaledToFill()
                    .frame(width: iconSize * 1.22, height: iconSize * 1.22)

            } else {

                Image(systemName: shortcut.icon)
                    .font(
                        .system(
                            size: 27 * (iconSize / 69),
                            weight: .bold
                        )
                    )
                    .foregroundStyle(iconColor)
            }
        }
        .frame(width: iconSize, height: iconSize)
        .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.27, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: iconSize * 0.27, style: .continuous)
                .inset(by: 1.0)
                .stroke(hovering ? hoverBorderColor : borderColor, lineWidth: 0.5)
        )
        .opacity(hovering ? 1.0 : 0.72)
        .onHover { hover in

            withAnimation(.easeOut(duration: 0.12)) {

                hovering = hover
            }
        }
    }

    var iconColor: Color {
        if shortcut.title.lowercased() == "youtube" && hovering {
            return .red
        }
        return .white.opacity(0.82)
    }
}

func isApplicationPath(_ path: String) -> Bool {
    path.hasSuffix(".app") && FileManager.default.fileExists(atPath: path)
}

func faviconURL(for urlString: String) -> URL? {
    guard let url = URL(string: urlString),
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          let host = url.host,
          !host.isEmpty else {
        return nil
    }
    return URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(host)")
}

func copyIconToAppSupport(_ sourceURL: URL) -> URL? {

    let supportFolder = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    )[0]

    let iconFolder = supportFolder.appendingPathComponent(
        "LinksApp/Icons",
        isDirectory: true
    )

    try? FileManager.default.createDirectory(
        at: iconFolder,
        withIntermediateDirectories: true
    )

    let destinationURL = iconFolder.appendingPathComponent(
        UUID().uuidString + "-" + sourceURL.lastPathComponent
    )

    do {

        try FileManager.default.copyItem(
            at: sourceURL,
            to: destinationURL
        )

        return destinationURL

    } catch {

        print("Could not copy icon:", error)
        return nil
    }
}

func isImagePath(_ path: String) -> Bool {
    let lowercasedPath = path.lowercased()
    return FileManager.default.fileExists(atPath: path) &&
        (
            lowercasedPath.hasSuffix(".png") ||
            lowercasedPath.hasSuffix(".jpg") ||
            lowercasedPath.hasSuffix(".jpeg") ||
            lowercasedPath.hasSuffix(".icns") ||
            lowercasedPath.hasSuffix(".tiff") ||
            lowercasedPath.hasSuffix(".webp")
        )
}

struct HoverLinkRow: View {

    let link: LinkItem
    let level: Int

    let borderColor: Color
    let hoverBorderColor: Color
    let zoomFactor: CGFloat

    let openAction: () -> Void

    @State private var hovering = false

    var body: some View {

        Button {

            openAction()

        } label: {

            HStack(spacing: 14) {

                ZStack {

                    RoundedRectangle(cornerRadius: 7)
                        .stroke(
                            hovering
                            ? hoverBorderColor
                            : borderColor,
                            lineWidth: 0.5
                        )

                    RoundedRectangle(cornerRadius: 7)
                        .fill(.black.opacity(0.22))

                    if isImagePath(link.icon),
                       let customIcon = NSImage(contentsOfFile: link.icon) {

                        Image(nsImage: customIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 21 * zoomFactor, height: 21 * zoomFactor)

                    } else if isApplicationPath(link.url) {

                        Image(nsImage: NSWorkspace.shared.icon(forFile: link.url))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 21 * zoomFactor, height: 21 * zoomFactor)

                    } else if let faviconURL = faviconURL(for: link.url) {

                        AsyncImage(url: faviconURL) { phase in

                            switch phase {

                            case .success(let image):

                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26 * zoomFactor, height: 26 * zoomFactor)

                            default:

                                Image(systemName: link.icon)
                                    .font(
                                        .system(
                                            size: 14 * zoomFactor,
                                            weight: .semibold
                                        )
                                    )
                                    .foregroundStyle(
                                        .white.opacity(hovering ? 0.70 : 0.28)
                                    )
                            }
                        }

                    } else {

                        Image(systemName: link.icon)
                            .font(
                                .system(
                                    size: 14 * zoomFactor,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(
                                .white.opacity(hovering ? 0.70 : 0.28)
                            )
                    }
                }
                .frame(width: 24 * zoomFactor, height: 24 * zoomFactor)

                Text(link.title)
                    .font(
                        .system(
                            size: 13 * zoomFactor,
                            weight: .light
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(hovering ? 0.70 : 0.28)
                    )

                Spacer()

                if link.isGroup {

                    Image(
                        systemName:
                            link.isExpanded
                            ? "chevron.down"
                            : "chevron.right"
                    )
                    .font(
                        .system(
                            size: 11 * zoomFactor,
                            weight: .regular
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(hovering ? 0.70 : 0.28)
                    )
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 37 * zoomFactor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        hovering ? hoverBorderColor : borderColor,
                        lineWidth: 0.5
                    )
            )
            .contentShape(Rectangle())
            .padding(
                .leading,
                CGFloat(level) * 24 * zoomFactor
            )
        }
        .buttonStyle(.plain)
        .onHover { hover in

            withAnimation(.easeOut(duration: 0.12)) {

                hovering = hover
            }
        }
    }
}


struct ShortcutDropDelegate: DropDelegate {

    let targetShortcut: AppShortcut

    @Binding var shortcuts: [AppShortcut]

    @Binding var draggedShortcut: AppShortcut?

    let saveAction: () -> Void

    func dropEntered(info: DropInfo) {

        guard let draggedShortcut,
              draggedShortcut != targetShortcut,
              let fromIndex = shortcuts.firstIndex(
                of: draggedShortcut
              ),
              let toIndex = shortcuts.firstIndex(
                of: targetShortcut
              )
        else { return }

        withAnimation(.easeInOut(duration: 0.15)) {

            shortcuts.move(
                fromOffsets: IndexSet(
                    integer: fromIndex
                ),
                toOffset:
                    toIndex > fromIndex
                    ? toIndex + 1
                    : toIndex
            )
        }
    }

    func performDrop(
        info: DropInfo
    ) -> Bool {

        draggedShortcut = nil

        saveAction()

        return true
    }
}

struct LinkReorderDropDelegate: DropDelegate {

    let targetID: UUID

    @Binding var links: [LinkItem]

    @Binding var draggedLinkID: UUID?

    let saveAction: () -> Void

    func dropEntered(info: DropInfo) {

        guard let draggedLinkID,
              draggedLinkID != targetID,
              let draggedItem = findItem(draggedLinkID, in: links),
              let targetItem = findItem(targetID, in: links)
        else { return }

        if itemContains(draggedItem, id: targetItem.id) {
            return
        }

        withAnimation(.easeInOut(duration: 0.12)) {

            moveItem(
                draggedID: draggedLinkID,
                before: targetID
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {

        draggedLinkID = nil
        saveAction()
        return true
    }

    func moveItem(
        draggedID: UUID,
        before targetID: UUID
    ) {

        guard draggedID != targetID,
              let movedItem = removeItem(draggedID, from: &links)
        else { return }

        if !insertItem(
            movedItem,
            before: targetID,
            in: &links
        ) {

            links.append(movedItem)
        }
    }

    func insertItem(
        _ item: LinkItem,
        before targetID: UUID,
        in items: inout [LinkItem]
    ) -> Bool {

        if let targetIndex = items.firstIndex(where: { $0.id == targetID }) {

            items.insert(item, at: targetIndex)
            return true
        }

        for index in items.indices {

            if insertItem(
                item,
                before: targetID,
                in: &items[index].children
            ) {

                return true
            }
        }

        return false
    }

    func removeItem(
        _ id: UUID,
        from items: inout [LinkItem]
    ) -> LinkItem? {

        if let index = items.firstIndex(where: { $0.id == id }) {

            return items.remove(at: index)
        }

        for index in items.indices {

            if let removed = removeItem(
                id,
                from: &items[index].children
            ) {

                return removed
            }
        }

        return nil
    }

    func findItem(
        _ id: UUID,
        in items: [LinkItem]
    ) -> LinkItem? {

        for item in items {

            if item.id == id {
                return item
            }

            if let found = findItem(id, in: item.children) {
                return found
            }
        }

        return nil
    }

    func itemContains(
        _ container: LinkItem,
        id: UUID
    ) -> Bool {

        if container.id == id {
            return true
        }

        for child in container.children {

            if itemContains(child, id: id) {
                return true
            }
        }

        return false
    }
}

struct LinkEditorView: View {

    @Environment(\.dismiss)
    var dismiss

    @State var item: LinkItem

    let onSave: (LinkItem) -> Void

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 18
        ) {

            Toggle(
                "This is a group",
                isOn: $item.isGroup
            )

            TextField(
                "Name",
                text: $item.title
            )
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {

                TextField(
                    "SF Symbol icon or image path",
                    text: $item.icon
                )
                .textFieldStyle(.roundedBorder)

                Button("Browse Icon") {

                    browseForIconImage()
                }
            }

            if !item.isGroup {

                TextField(
                    "URL",
                    text: $item.url
                )
                .textFieldStyle(.roundedBorder)
            }

            HStack {

                Spacer()

                Button("Cancel") {

                    dismiss()
                }

                Button("Save") {

                    if item.isGroup {

                        item.url = ""
                    }

                    onSave(item)

                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
    func browseForIconImage() {

        let panel = NSOpenPanel()
        panel.title = "Choose Link Icon Image"
        panel.message = "Select an image file to use as this link icon."
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        var iconTypes: [UTType] = [.png, .jpeg, .tiff]
        if let icns = UTType(filenameExtension: "icns") { iconTypes.append(icns) }
        if let webp = UTType(filenameExtension: "webp") { iconTypes.append(webp) }
        panel.allowedContentTypes = iconTypes

        if panel.runModal() == .OK,
           let selectedURL = panel.url {

            if let copiedURL = copyIconToAppSupport(selectedURL) {

                item.icon = copiedURL.path
            }
        }
    }

}

struct ShortcutEditorView: View {

    @Environment(\.dismiss)
    var dismiss

    @State var title: String
    @State var icon: String
    @State var url: String

    let onSave: (
        String,
        String,
        String
    ) -> Void

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 18
        ) {

            Text("Software Icon")
                .font(
                    .system(
                        size: 18,
                        weight: .bold
                    )
                )

            TextField(
                "Name",
                text: $title
            )
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {

                TextField(
                    "SF Symbol icon or image path",
                    text: $icon
                )
                .textFieldStyle(.roundedBorder)

                Button("Browse Icon") {

                    browseForIconImage()
                }
            }

            HStack(spacing: 8) {

                TextField(
                    "URL or App Path",
                    text: $url
                )
                .textFieldStyle(.roundedBorder)

                Button("Browse") {

                    browseForApplication()
                }
            }

            HStack {

                Spacer()

                Button("Cancel") {

                    dismiss()
                }

                Button("Save") {

                    onSave(
                        title,
                        icon,
                        url
                    )

                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    func browseForApplication() {

        let panel = NSOpenPanel()
        panel.title = "Choose Application"
        panel.message = "Select the app this software icon should open."
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK,
           let selectedURL = panel.url {

            url = selectedURL.path

            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                title = selectedURL.deletingPathExtension().lastPathComponent
            }
        }
    }

    func browseForIconImage() {

        let panel = NSOpenPanel()
        panel.title = "Choose Icon Image"
        panel.message = "Select an image file to use as this software icon."
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        var iconTypes: [UTType] = [.png, .jpeg, .tiff]
        if let icns = UTType(filenameExtension: "icns") { iconTypes.append(icns) }
        if let webp = UTType(filenameExtension: "webp") { iconTypes.append(webp) }
        panel.allowedContentTypes = iconTypes

        if panel.runModal() == .OK,
           let selectedURL = panel.url {

            if let copiedURL = copyIconToAppSupport(selectedURL) {

                icon = copiedURL.path
            }
        }
    }

}

struct ScrollbarCustomizer: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {

        let view = NSView()

        DispatchQueue.main.async {

            var parent = view.superview

            while parent != nil {

                if let scrollView = parent as? NSScrollView {
                    scrollView.verticalScroller?.knobStyle = .dark
                    break
                }

                parent = parent?.superview
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

#Preview {
    ContentView()
}
