import AppKit
import Combine
import SwiftUI

private final class EdgePanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

private final class EdgeTriggerView: NSView {
    var onMouseEntered: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private let indicatorLength: CGFloat = 44

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func draw(_ dirtyRect: NSRect) {
        let indicatorRect: NSRect
        if bounds.width >= bounds.height {
            indicatorRect = NSRect(
                x: bounds.midX - indicatorLength / 2,
                y: bounds.minY,
                width: indicatorLength,
                height: bounds.height
            )
        } else {
            indicatorRect = NSRect(
                x: bounds.minX,
                y: bounds.midY - indicatorLength / 2,
                width: bounds.width,
                height: indicatorLength
            )
        }

        NSColor.labelColor.withAlphaComponent(0.14).setFill()
        NSBezierPath(
            roundedRect: indicatorRect.insetBy(dx: 1, dy: 1),
            xRadius: 2,
            yRadius: 2
        ).fill()
    }
}

@MainActor
final class EdgePanelController {
    private let panel: EdgePanel
    private let triggerPanel: EdgePanel
    private let store: UsageStore
    private let settings: AppSettings
    private var isExpanded = false
    private var isHovered = false
    private var isPinned = false
    private var isDragging = false
    private var isSettlingAfterDrag = false
    private var isApplyingDragEdge = false
    private var dragStartFrame: NSRect?
    private var dragStartMouseLocation: NSPoint?
    private var edgePosition: CGFloat?
    private var collapseTask: Task<Void, Never>?
    private var animationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private let cardSize = NSSize(width: 292, height: 154)
    private let triggerThickness: CGFloat = 5
    private let transitionDuration: Double = 0.15
    private let transitionFramesPerSecond: Double = 120

    init(store: UsageStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
        panel = EdgePanel(
            contentRect: NSRect(origin: .zero, size: cardSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        triggerPanel = EdgePanel(
            contentRect: NSRect(x: 0, y: 0, width: triggerThickness, height: cardSize.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel()
        configureTriggerPanel()
        updateContent()
        observeSettings()
    }

    func start() {
        reposition(animated: false)
    }

    func reveal() {
        collapseTask?.cancel()
        Task { [weak self] in
            await self?.store.refreshIfNeeded()
        }
        guard !isExpanded else { return }
        isExpanded = true
        triggerPanel.orderOut(nil)
        reposition(animated: true)
    }

    func collapse() {
        guard !isPinned, !isDragging else { return }
        isExpanded = false
        reposition(animated: true)
    }

    private func configurePanel() {
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.animationBehavior = .none
    }

    private func configureTriggerPanel() {
        triggerPanel.level = .floating
        triggerPanel.isOpaque = false
        triggerPanel.backgroundColor = .clear
        triggerPanel.hasShadow = false
        triggerPanel.hidesOnDeactivate = false
        triggerPanel.isMovable = false
        triggerPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        triggerPanel.animationBehavior = .none

        let triggerView = EdgeTriggerView(frame: .zero)
        triggerView.onMouseEntered = { [weak self] in self?.reveal() }
        triggerPanel.contentView = triggerView
    }

    private func updateContent() {
        let view = UsageCardView(
            store: store,
            edge: settings.edge,
            isPinned: isPinned,
            isDarkMode: settings.isDarkMode,
            onHoverChanged: { [weak self] hovering in self?.hoverChanged(hovering) },
            onPinToggle: { [weak self] in self?.togglePin() },
            onThemeToggle: { [weak self] in self?.toggleTheme() },
            onDragChanged: { [weak self] in self?.dragChanged() },
            onDragEnded: { [weak self] in self?.dragEnded() }
        )
        panel.contentView = NSHostingView(rootView: view)
    }

    private func hoverChanged(_ hovering: Bool) {
        guard !isDragging, !isSettlingAfterDrag else { return }
        isHovered = hovering
        collapseTask?.cancel()
        if hovering {
            reveal()
        } else if !isPinned {
            scheduleCollapse(after: settings.hideDelay)
        }
    }

    private func togglePin() {
        isSettlingAfterDrag = false
        collapseTask?.cancel()
        isPinned.toggle()
        if isPinned { reveal() }
        updateContent()
    }

    private func toggleTheme() {
        settings.isDarkMode.toggle()
        updateContent()
    }

    private func dragChanged() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        if dragStartFrame == nil {
            animationTask?.cancel()
            animationTask = nil
            triggerPanel.orderOut(nil)
            dragStartFrame = panel.frame
            dragStartMouseLocation = NSEvent.mouseLocation
            isDragging = true
            isSettlingAfterDrag = false
            isExpanded = true
            collapseTask?.cancel()
        }
        guard let startFrame = dragStartFrame,
              let startMouseLocation = dragStartMouseLocation
        else { return }

        let visible = screen.visibleFrame
        let currentMouseLocation = NSEvent.mouseLocation
        let targetX = startFrame.origin.x + currentMouseLocation.x - startMouseLocation.x
        let targetY = startFrame.origin.y + currentMouseLocation.y - startMouseLocation.y
        let clampedX = min(max(targetX, visible.minX), visible.maxX - cardSize.width)
        let clampedY = min(max(targetY, visible.minY), visible.maxY - cardSize.height)
        panel.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
    }

    private func dragEnded() {
        dragStartFrame = nil
        dragStartMouseLocation = nil
        isDragging = false
        guard let screen = panel.screen ?? NSScreen.main else { return }

        let visible = screen.visibleFrame
        let frame = panel.frame
        let distances: [(AppSettings.ScreenEdge, CGFloat)] = [
            (.left, abs(frame.minX - visible.minX)),
            (.right, abs(visible.maxX - frame.maxX)),
            (.top, abs(visible.maxY - frame.maxY)),
        ]
        guard let nearest = distances.min(by: { $0.1 < $1.1 })?.0 else { return }

        switch nearest {
        case .left, .right:
            edgePosition = min(max(frame.origin.y, visible.minY), visible.maxY - cardSize.height)
        case .top:
            edgePosition = min(max(frame.origin.x, visible.minX), visible.maxX - cardSize.width)
        }

        isSettlingAfterDrag = true
        if settings.edge != nearest {
            isApplyingDragEdge = true
            settings.edge = nearest
            isApplyingDragEdge = false
        }
        isExpanded = true
        updateContent()
        reposition(animated: true)
        scheduleCollapse(after: max(0.35, settings.hideDelay))
    }

    private func scheduleCollapse(after delay: Double) {
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.isSettlingAfterDrag = false
            self.collapse()
        }
    }

    private func observeSettings() {
        settings.$edge
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, !self.isApplyingDragEdge else { return }
                Task { @MainActor [weak self] in
                    await Task.yield()
                    self?.updateContent()
                    self?.reposition(animated: true)
                }
            }
            .store(in: &cancellables)
        settings.$showsOnAllSpaces
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self else { return }
                self.panel.collectionBehavior = enabled
                    ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
                    : [.moveToActiveSpace]
                self.triggerPanel.collectionBehavior = enabled
                    ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
                    : [.moveToActiveSpace]
            }
            .store(in: &cancellables)
    }

    private func reposition(animated: Bool) {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let expandedOrigin: NSPoint
        let offscreenOrigin: NSPoint

        switch settings.edge {
        case .right:
            let y = edgePosition ?? (visible.midY - cardSize.height / 2)
            expandedOrigin = NSPoint(x: visible.maxX - cardSize.width, y: y)
            offscreenOrigin = NSPoint(x: visible.maxX, y: y)
        case .left:
            let y = edgePosition ?? (visible.midY - cardSize.height / 2)
            expandedOrigin = NSPoint(x: visible.minX, y: y)
            offscreenOrigin = NSPoint(x: visible.minX - cardSize.width, y: y)
        case .top:
            let x = edgePosition ?? (visible.midX - cardSize.width / 2)
            expandedOrigin = NSPoint(x: x, y: visible.maxY - cardSize.height)
            offscreenOrigin = NSPoint(x: x, y: visible.maxY)
        }

        let expandedFrame = NSRect(origin: expandedOrigin, size: cardSize)
        let offscreenFrame = NSRect(origin: offscreenOrigin, size: cardSize)

        if isExpanded {
            triggerPanel.orderOut(nil)
            if !panel.isVisible {
                panel.setFrame(offscreenFrame, display: false)
                panel.orderFrontRegardless()
            }
            movePanel(to: expandedFrame, animated: animated)
            return
        }

        triggerPanel.orderOut(nil)
        guard panel.isVisible else {
            showTrigger(on: screen)
            return
        }
        movePanel(to: offscreenFrame, animated: animated) { [weak self] in
            guard let self, !self.isExpanded else { return }
            self.panel.orderOut(nil)
            self.showTrigger(on: screen)
        }
    }

    private func movePanel(
        to target: NSRect,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        animationTask?.cancel()
        animationTask = nil

        guard animated,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              !panel.frame.equalTo(target)
        else {
            panel.setFrame(target, display: true)
            completion?()
            return
        }

        let start = panel.frame
        let frameCount = max(1, Int(transitionDuration * transitionFramesPerSecond))
        let frameDelay = UInt64(1_000_000_000 / transitionFramesPerSecond)

        animationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for frameIndex in 1...frameCount {
                guard !Task.isCancelled else { return }
                let progress = Double(frameIndex) / Double(frameCount)
                let eased = progress * progress * progress
                    * (progress * (progress * 6 - 15) + 10)
                let origin = NSPoint(
                    x: start.origin.x + (target.origin.x - start.origin.x) * eased,
                    y: start.origin.y + (target.origin.y - start.origin.y) * eased
                )
                self.panel.setFrameOrigin(origin)
                if frameIndex < frameCount {
                    try? await Task.sleep(nanoseconds: frameDelay)
                }
            }
            guard !Task.isCancelled else { return }
            self.panel.setFrame(target, display: true)
            self.animationTask = nil
            completion?()
        }
    }

    private func showTrigger(on suppliedScreen: NSScreen? = nil) {
        guard let screen = suppliedScreen ?? panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let frame: NSRect

        switch settings.edge {
        case .right:
            let cardY = edgePosition ?? (visible.midY - cardSize.height / 2)
            frame = NSRect(
                x: visible.maxX - triggerThickness,
                y: cardY,
                width: triggerThickness,
                height: cardSize.height
            )
        case .left:
            let cardY = edgePosition ?? (visible.midY - cardSize.height / 2)
            frame = NSRect(
                x: visible.minX,
                y: cardY,
                width: triggerThickness,
                height: cardSize.height
            )
        case .top:
            let cardX = edgePosition ?? (visible.midX - cardSize.width / 2)
            frame = NSRect(
                x: cardX,
                y: visible.maxY - triggerThickness,
                width: cardSize.width,
                height: triggerThickness
            )
        }

        triggerPanel.setFrame(frame, display: true)
        triggerPanel.orderFrontRegardless()
    }
}
