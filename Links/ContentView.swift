// LINKS APP
// VERSION 1.9 STABLE
// Working full version
// 2026-05-23

import SwiftUI
import UniformTypeIdentifiers

struct LinkItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var icon: String
    var url: String
}

struct AppShortcut: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var icon: String
    var url: String
}

struct ContentView: View {

    @State private var links: [LinkItem] = []
    @State private var shortcuts: [AppShortcut] = []

    @State private var selectedLink: LinkItem?
    @State private var selectedShortcut: AppShortcut?

    @State private var showingAddLinkSheet = false
    @State private var showingAddShortcutSheet = false

    @State private var draggedLink: LinkItem?
    @State private var draggedShortcut: AppShortcut?

    @State private var hoveringAddShortcut = false
    @State private var hoveringAddLink = false

    let borderColor = Color.gray.opacity(0.28)
    let hoverBorderColor = Color.white.opacity(0.55)

    var body: some View {

        VStack(spacing: 0) {

            topBar

            VStack(alignment: .leading, spacing: 10) {

                shortcutRow

                linkList
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
        .background(background)
        .preferredColorScheme(.dark)
        .onAppear {

            loadLinks()
            loadShortcuts()
        }
        .sheet(isPresented: $showingAddLinkSheet) {

            LinkEditorView(title: "", icon: "link", url: "") { title, icon, url in

                links.append(LinkItem(title: title, icon: icon, url: url))

                saveLinks()
            }
        }
        .sheet(isPresented: $showingAddShortcutSheet) {

            ShortcutEditorView(title: "", icon: "app", url: "") { title, icon, url in

                shortcuts.append(AppShortcut(title: title, icon: icon, url: url))

                saveShortcuts()
            }
        }
        .sheet(item: $selectedLink) { link in

            LinkEditorView(title: link.title, icon: link.icon, url: link.url) { title, icon, url in

                if let index = links.firstIndex(where: { $0.id == link.id }) {

                    links[index].title = title
                    links[index].icon = icon
                    links[index].url = url

                    saveLinks()
                }
            }
        }
        .sheet(item: $selectedShortcut) { shortcut in

            ShortcutEditorView(title: shortcut.title, icon: shortcut.icon, url: shortcut.url) { title, icon, url in

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

            Color(red: 0.05, green: 0.05, blue: 0.055)

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

    var shortcutRow: some View {

        HStack(spacing: 12) {

            ForEach(shortcuts) { shortcut in

                Button {

                    openURL(shortcut.url)

                } label: {

                    shortcutIcon(shortcut)
                }
                .buttonStyle(.plain)
                .onDrag {

                    draggedShortcut = shortcut

                    return NSItemProvider(object: shortcut.id.uuidString as NSString)
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

                    Button("Delete Software Icon", role: .destructive) {

                        shortcuts.removeAll { $0.id == shortcut.id }

                        saveShortcuts()
                    }
                }
            }

            addShortcutButton
        }
        .padding(.leading, 18)
        .padding(.top, 18)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var addShortcutButton: some View {

        Button {

            showingAddShortcutSheet = true

        } label: {

            ZStack {

                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        hoveringAddShortcut ? hoverBorderColor : borderColor,
                        lineWidth: 0.5
                    )

                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.14))

                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.16))
            }
            .frame(width: 46, height: 46)
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
            hoverBorderColor: hoverBorderColor
        )
    }

    var linkList: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 8) {

                ForEach(links) { link in

                    row(link)
                        .onDrag {

                            draggedLink = link

                            return NSItemProvider(object: link.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [.text],
                            delegate: LinkDropDelegate(
                                targetLink: link,
                                links: $links,
                                draggedLink: $draggedLink,
                                saveAction: saveLinks
                            )
                        )
                        .contextMenu {

                            Button("Edit Link") {

                                selectedLink = link
                            }

                            Button("Delete Link", role: .destructive) {

                                links.removeAll { $0.id == link.id }

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

    func row(_ link: LinkItem) -> some View {

        HoverLinkRow(
            link: link,
            borderColor: borderColor,
            hoverBorderColor: hoverBorderColor,
            openURL: openURL
        )
    }

    var addLinkRow: some View {

        Button {

            showingAddLinkSheet = true

        } label: {

            HStack(spacing: 14) {

                ZStack {

                    RoundedRectangle(cornerRadius: 7)
                        .stroke(
                            hoveringAddLink ? hoverBorderColor : borderColor,
                            lineWidth: 0.5
                        )

                    RoundedRectangle(cornerRadius: 7)
                        .fill(.black.opacity(0.22))

                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.16))
                }
                .frame(width: 30, height: 30)

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(.white.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        hoveringAddLink ? hoverBorderColor : borderColor,
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

        if target.hasPrefix("/") || target.hasSuffix(".app") {

            let fileURL = URL(fileURLWithPath: target)

            NSWorkspace.shared.open(fileURL)

            return
        }

        if let url = URL(string: target) {

            NSWorkspace.shared.open(url)
        }
    }

    func saveLinks() {

        if let data = try? JSONEncoder().encode(links) {

            UserDefaults.standard.set(data, forKey: "SavedLinks")
        }
    }

    func loadLinks() {

        if let data = UserDefaults.standard.data(forKey: "SavedLinks"),
           let saved = try? JSONDecoder().decode([LinkItem].self, from: data) {

            links = saved

        } else {

            links = [
                LinkItem(title: "Atomic Bid Planner", icon: "plus", url: "https://docs.google.com"),
                LinkItem(title: "VFX Tracking", icon: "waveform.path.ecg", url: "https://docs.google.com"),
                LinkItem(title: "ShotGrid", icon: "cube.transparent.fill", url: "https://shotgrid.autodesk.com")
            ]
        }
    }

    func saveShortcuts() {

        if let data = try? JSONEncoder().encode(shortcuts) {

            UserDefaults.standard.set(data, forKey: "SavedShortcuts")
        }
    }

    func loadShortcuts() {

        if let data = UserDefaults.standard.data(forKey: "SavedShortcuts"),
           let saved = try? JSONDecoder().decode([AppShortcut].self, from: data) {

            shortcuts = saved

        } else {

            shortcuts = [
                AppShortcut(title: "Firefox", icon: "globe", url: "/Applications/Firefox.app"),
                AppShortcut(title: "VS Code", icon: "chevron.left.forwardslash.chevron.right", url: "/Applications/Visual Studio Code.app"),
                AppShortcut(title: "YouTube", icon: "play.rectangle.fill", url: "https://youtube.com")
            ]
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
                    hovering ? hoverBorderColor : borderColor,
                    lineWidth: 0.5
                )

            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.22))

            Image(systemName: shortcut.icon)
                .font(.system(size: 18, weight: .bold))
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

        if shortcut.title.lowercased() == "youtube" && hovering {

            return .red
        }

        return .white.opacity(0.82)
    }
}

struct HoverLinkRow: View {

    let link: LinkItem
    let borderColor: Color
    let hoverBorderColor: Color
    let openURL: (String) -> Void

    @State private var hovering = false

    var body: some View {

        HStack(spacing: 14) {

            ZStack {

                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        hovering ? hoverBorderColor : borderColor,
                        lineWidth: 0.5
                    )

                RoundedRectangle(cornerRadius: 7)
                    .fill(.black.opacity(0.22))

                Image(systemName: link.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(width: 30, height: 30)

            Text(link.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(.white.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    hovering ? hoverBorderColor : borderColor,
                    lineWidth: 0.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {

            openURL(link.url)
        }
        .onHover { hover in

            withAnimation(.easeOut(duration: 0.12)) {

                hovering = hover
            }
        }
    }
}

struct LinkDropDelegate: DropDelegate {

    let targetLink: LinkItem

    @Binding var links: [LinkItem]

    @Binding var draggedLink: LinkItem?

    let saveAction: () -> Void

    func dropEntered(info: DropInfo) {

        guard let draggedLink,
              draggedLink != targetLink,
              let fromIndex = links.firstIndex(of: draggedLink),
              let toIndex = links.firstIndex(of: targetLink)
        else { return }

        withAnimation(.easeInOut(duration: 0.15)) {

            links.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {

        draggedLink = nil

        saveAction()

        return true
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
              let fromIndex = shortcuts.firstIndex(of: draggedShortcut),
              let toIndex = shortcuts.firstIndex(of: targetShortcut)
        else { return }

        withAnimation(.easeInOut(duration: 0.15)) {

            shortcuts.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {

        draggedShortcut = nil

        saveAction()

        return true
    }
}

struct LinkEditorView: View {

    @Environment(\.dismiss) var dismiss

    @State var title: String
    @State var icon: String
    @State var url: String

    let onSave: (String, String, String) -> Void

    var body: some View {

        VStack(alignment: .leading, spacing: 18) {

            Text("Link")
                .font(.system(size: 18, weight: .bold))

            TextField("Name", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("SF Symbol icon", text: $icon)
                .textFieldStyle(.roundedBorder)

            TextField("URL", text: $url)
                .textFieldStyle(.roundedBorder)

            HStack {

                Spacer()

                Button("Cancel") {

                    dismiss()
                }

                Button("Save") {

                    onSave(title, icon, url)

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

    @Environment(\.dismiss) var dismiss

    @State var title: String
    @State var icon: String
    @State var url: String

    let onSave: (String, String, String) -> Void

    var body: some View {

        VStack(alignment: .leading, spacing: 18) {

            Text("Software Icon")
                .font(.system(size: 18, weight: .bold))

            TextField("Name", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("SF Symbol icon", text: $icon)
                .textFieldStyle(.roundedBorder)

            TextField("URL or App Path", text: $url)
                .textFieldStyle(.roundedBorder)

            HStack {

                Spacer()

                Button("Cancel") {

                    dismiss()
                }

                Button("Save") {

                    onSave(title, icon, url)

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

