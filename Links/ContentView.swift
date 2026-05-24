// LINKS APP
// VERSION 2.5
// Slightly brighter main content background
// Based on v1.9 stable
// 2026-05-24

import SwiftUI
import UniformTypeIdentifiers

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

struct ContentView: View {

    @State private var links: [LinkItem] = []
    @State private var shortcuts: [AppShortcut] = []

    @State private var selectedShortcut: AppShortcut?

    @State private var linkEditorMode: LinkEditorMode?

    @State private var showingAddShortcutSheet = false

    @State private var draggedShortcut: AppShortcut?

    @State private var hoveringAddShortcut = false
    @State private var hoveringAddLink = false

    let borderColor = Color.gray.opacity(0.28)
    let hoverBorderColor = Color.white.opacity(0.55)
    let frameCornerRadius: CGFloat = 10
    let innerFrameInset: CGFloat = 24
    let shortcutIconSize: CGFloat = 46
    let shortcutIconSpacing: CGFloat = 12

    var body: some View {

        VStack(spacing: 0) {

            topBar

            HStack(spacing: 0) {

                sideBorder

                VStack(alignment: .leading, spacing: 10) {

                    shortcutRow

                    linkList
                }
                .padding(22)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.025))

                sideBorder
            }

            bottomBar
        }
        .background(background)
        .clipShape(
            RoundedRectangle(cornerRadius: frameCornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: frameCornerRadius)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.5)
                .padding(innerFrameInset)
        )
        .preferredColorScheme(.dark)
        .onAppear {

            loadLinks()
            loadShortcuts()
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
                    saveLinks()
                }

            case .edit(let item):

                LinkEditorView(item: item) { updatedItem in

                    updateItem(updatedItem, in: &links)
                    saveLinks()
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
                    saveLinks()
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

                saveShortcuts()
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

                    saveShortcuts()
                }
            }
        }
    }

    var background: some View {

        ZStack {

            Color(
                red: 0.05,
                green: 0.05,
                blue: 0.055
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
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
                        saveAction: saveShortcuts
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

                        saveShortcuts()
                    }
                }
            }

            addShortcutButton
        }
        .padding(.leading, 18)
        .padding(.top, 18)
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

                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        hoveringAddShortcut
                        ? hoverBorderColor
                        : borderColor,
                        lineWidth: 0.5
                    )

                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.14))

                Image(systemName: "plus")
                    .font(
                        .system(
                            size: 18,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.16)
                    )
            }
            .frame(width: shortcutIconSize, height: shortcutIconSize)
        }
        .buttonStyle(.plain)
        .onHover { hovering in

            withAnimation(.easeOut(duration: 0.12)) {

                hoveringAddShortcut = hovering
            }
        }
    }

    func shortcutIcon(
        _ shortcut: AppShortcut
    ) -> some View {

        HoverShortcutIcon(
            shortcut: shortcut,
            borderColor: borderColor,
            hoverBorderColor: hoverBorderColor
        )
    }

    var linkList: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 8
            ) {

                ForEach(visibleLinks) { visible in

                    HoverLinkRow(
                        link: visible.item,
                        level: visible.level,
                        borderColor: borderColor,
                        hoverBorderColor: hoverBorderColor
                    ) {

                        if visible.item.isGroup {

                            toggleExpanded(
                                visible.item.id,
                                in: &links
                            )

                            saveLinks()

                        } else {

                            openURL(visible.item.url)
                        }
                    }
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

                            saveLinks()
                        }
                    }
                }

                addLinkRow
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
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

                    RoundedRectangle(cornerRadius: 7)
                        .fill(.black.opacity(0.22))

                    Image(systemName: "plus")
                        .font(
                            .system(
                                size: 14,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            .white.opacity(0.16)
                        )
                }
                .frame(width: 30, height: 30)

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(.white.opacity(0.025))
            .clipShape(
                RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        hoveringAddLink
                        ? hoverBorderColor
                        : borderColor,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in

            withAnimation(.easeOut(duration: 0.12)) {

                hoveringAddLink = hovering
            }
        }
    }

    var bottomBar: some View {

        Rectangle()
            .fill(Color.black.opacity(0.22))
            .frame(height: 24)
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

    func saveLinks() {

        if let data = try? JSONEncoder().encode(links) {

            UserDefaults.standard.set(
                data,
                forKey: "SavedLinkItemsV2"
            )
        }
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

    func saveShortcuts() {

        if let data = try? JSONEncoder().encode(shortcuts) {

            UserDefaults.standard.set(
                data,
                forKey: "SavedShortcuts"
            )
        }
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

    @State private var hovering = false

    var body: some View {

        ZStack {

            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    hovering
                    ? hoverBorderColor
                    : borderColor,
                    lineWidth: 0.5
                )

            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.22))

            Image(systemName: shortcut.icon)
                .font(
                    .system(
                        size: 18,
                        weight: .bold
                    )
                )
                .foregroundStyle(iconColor)
        }
        .frame(width: 46, height: 46)
        .onHover { hover in

            withAnimation(.easeOut(duration: 0.12)) {

                hovering = hover
            }
        }
    }

    var iconColor: Color {

        if shortcut.title.lowercased() ==
            "youtube" &&
            hovering {

            return .red
        }

        return .white.opacity(0.82)
    }
}

struct HoverLinkRow: View {

    let link: LinkItem
    let level: Int

    let borderColor: Color
    let hoverBorderColor: Color

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

                    Image(systemName: link.icon)
                        .font(
                            .system(
                                size: 14,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(
                            .white.opacity(0.82)
                        )
                }
                .frame(width: 30, height: 30)

                Text(link.title)
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.82)
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
                            size: 11,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.45)
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(
                .leading,
                CGFloat(level) * 24
            )
            .frame(height: 46)
            .background(.white.opacity(0.05))
            .clipShape(
                RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        hovering
                        ? hoverBorderColor
                        : borderColor,
                        lineWidth: 0.5
                    )
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

            TextField(
                "SF Symbol icon",
                text: $item.icon
            )
            .textFieldStyle(.roundedBorder)

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

            TextField(
                "SF Symbol icon",
                text: $icon
            )
            .textFieldStyle(.roundedBorder)

            TextField(
                "URL or App Path",
                text: $url
            )
            .textFieldStyle(.roundedBorder)

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
}

#Preview {

    ContentView()
}
