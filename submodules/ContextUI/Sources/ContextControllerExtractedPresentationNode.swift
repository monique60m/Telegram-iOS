import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextSelectionNode
import TelegramCore
import SwiftSignalKit
import ReactionSelectionNode
import UndoUI
import AccountContext

private extension ContextControllerTakeViewInfo.ContainingItem {
    var contentRect: CGRect {
        switch self {
        case let .node(containingNode):
            return containingNode.contentRect
        case let .view(containingView):
            return containingView.contentRect
        }
    }
    
    var customHitTest: ((CGPoint) -> UIView?)? {
        switch self {
        case let .node(containingNode):
            return containingNode.contentNode.customHitTest
        case let .view(containingView):
            return containingView.contentView.customHitTest
        }
    }
    
    var view: UIView {
        switch self {
        case let .node(containingNode):
            return containingNode.view
        case let .view(containingView):
            return containingView
        }
    }
    
    var contentView: UIView {
        switch self {
        case let .node(containingNode):
            return containingNode.contentNode.view
        case let .view(containingView):
            return containingView.contentView
        }
    }
    
    func contentHitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        switch self {
        case let .node(containingNode):
            return containingNode.contentNode.hitTest(point, with: event)
        case let .view(containingView):
            return containingView.contentView.hitTest(point, with: event)
        }
    }
    
    var isExtractedToContextPreview: Bool {
        get {
            switch self {
            case let .node(containingNode):
                return containingNode.isExtractedToContextPreview
            case let .view(containingView):
                return containingView.isExtractedToContextPreview
            }
        } set(value) {
            switch self {
            case let .node(containingNode):
                containingNode.isExtractedToContextPreview = value
            case let .view(containingView):
                containingView.isExtractedToContextPreview = value
            }
        }
    }
    
    var willUpdateIsExtractedToContextPreview: ((Bool, ContainedViewLayoutTransition) -> Void)? {
        switch self {
        case let .node(containingNode):
            return containingNode.willUpdateIsExtractedToContextPreview
        case let .view(containingView):
            return containingView.willUpdateIsExtractedToContextPreview
        }
    }
    
    var isExtractedToContextPreviewUpdated: ((Bool) -> Void)? {
        switch self {
        case let .node(containingNode):
            return containingNode.isExtractedToContextPreviewUpdated
        case let .view(containingView):
            return containingView.isExtractedToContextPreviewUpdated
        }
    }
    
    var onDismiss: (() -> Void)? {
        switch self {
        case let .node(containingNode):
            return containingNode.onDismiss
        case let .view(containingView):
            return containingView.onDismiss
        }
    }
    
    var layoutUpdated: ((CGSize, ListViewItemUpdateAnimation) -> Void)? {
        get {
            switch self {
            case let .node(containingNode):
                return containingNode.layoutUpdated
            case let .view(containingView):
                return containingView.layoutUpdated
            }
        } set(value) {
            switch self {
            case let .node(containingNode):
                containingNode.layoutUpdated = value
            case let .view(containingView):
                containingView.layoutUpdated = value
            }
        }
    }
}

final class ContextControllerExtractedPresentationNode: ASDisplayNode, ContextControllerPresentationNode, ASScrollViewDelegate {
    enum ContentSource {
        case location(ContextLocationContentSource)
        case reference(ContextReferenceContentSource)
        case extracted(ContextExtractedContentSource)
        case controller(ContextControllerContentSource)
    }
    
    private final class ItemContentNode: ASDisplayNode {
        let offsetContainerNode: ASDisplayNode
        var containingItem: ContextControllerTakeViewInfo.ContainingItem
        
        var animateClippingFromContentAreaInScreenSpace: CGRect?
        var storedGlobalFrame: CGRect?
        var storedGlobalBoundsFrame: CGRect?
        
        init(containingItem: ContextControllerTakeViewInfo.ContainingItem) {
            self.offsetContainerNode = ASDisplayNode()
            self.containingItem = containingItem
            
            super.init()
            
            self.addSubnode(self.offsetContainerNode)
        }
        
        func update(presentationData: PresentationData, size: CGSize, transition: ContainedViewLayoutTransition) {
        }
        
        func takeContainingNode() {
            switch self.containingItem {
            case let .node(containingNode):
                if containingNode.contentNode.supernode !== self.offsetContainerNode {
                    self.offsetContainerNode.addSubnode(containingNode.contentNode)
                }
            case let .view(containingView):
                if containingView.contentView.superview !== self.offsetContainerNode.view {
                    self.offsetContainerNode.view.addSubview(containingView.contentView)
                }
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.containingItem.contentRect.contains(point) {
                return nil
            }
            return self.view
        }
    }
    
    private final class ControllerContentNode: ASDisplayNode {
        let controller: ViewController
        let passthroughTouches: Bool
        var storedContentHeight: CGFloat?
        
        init(controller: ViewController, passthroughTouches: Bool) {
            self.controller = controller
            self.passthroughTouches = passthroughTouches
            
            super.init()
            
            self.clipsToBounds = true
            self.cornerRadius = 14.0
            
            self.addSubnode(self.controller.displayNode)
        }
        
        func update(presentationData: PresentationData, parentLayout: ContainerViewLayout, size: CGSize, transition: ContainedViewLayoutTransition) {
            transition.updateFrame(node: self.controller.displayNode, frame: CGRect(origin: CGPoint(), size: size))
            guard self.controller.navigationController == nil else {
                return
            }
            self.controller.containerLayoutUpdated(
                ContainerViewLayout(
                    size: size,
                    metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil),
                    deviceMetrics: parentLayout.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(),
                    safeInsets: UIEdgeInsets(),
                    additionalInsets: UIEdgeInsets(),
                    statusBarHeight: nil,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                ),
                transition: transition
            )
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if self.passthroughTouches {
                let controllerPoint = self.view.convert(point, to: self.controller.view)
                if let result = self.controller.view.hitTest(controllerPoint, with: event) {
                    return result
                }
            }
            return self.view
        }
    }
    
    private final class AnimatingOutState {
        var currentContentScreenFrame: CGRect
        
        init(
            currentContentScreenFrame: CGRect
        ) {
            self.currentContentScreenFrame = currentContentScreenFrame
        }
    }
    
    private let _ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var ready: Signal<Bool, NoError> {
        return self._ready.get()
    }
    
    private let context: AccountContext?
    private let getController: () -> ContextControllerProtocol?
    private let requestUpdate: (ContainedViewLayoutTransition) -> Void
    private let requestUpdateOverlayWantsToBeBelowKeyboard: (ContainedViewLayoutTransition) -> Void
    private let requestDismiss: (ContextMenuActionResult) -> Void
    private let requestAnimateOut: (ContextMenuActionResult, @escaping () -> Void) -> Void
    private let source: ContentSource
    
    private let dismissTapNode: ASDisplayNode
    private let dismissAccessibilityArea: AccessibilityAreaNode
    private let clippingNode: ASDisplayNode
    private let scroller: UIScrollView
    private let scrollNode: ASDisplayNode
    
    private var reactionContextNode: ReactionContextNode?
    private var reactionPreviewView: ReactionPreviewView?
    private var reactionContextNodeIsAnimatingOut: Bool = false
    
    private var itemContentNode: ItemContentNode?
    private var controllerContentNode: ControllerContentNode?
    private let contentRectDebugNode: ASDisplayNode
    
    private var actionsContainerNode: ASDisplayNode
    private let actionsStackNode: ContextControllerActionsStackNode
    private let additionalActionsStackNode: ContextControllerActionsStackNode
    
    private var validLayout: ContainerViewLayout?
    private var animatingOutState: AnimatingOutState?
    
    private var strings: PresentationStrings?
    
    private enum OverscrollMode {
        case unrestricted
        case topOnly
        case disabled
    }
    
    private var overscrollMode: OverscrollMode = .unrestricted
    
    private weak var currentUndoController: ViewController?
    
    init(
        context: AccountContext?,
        getController: @escaping () -> ContextControllerProtocol?,
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
        requestUpdateOverlayWantsToBeBelowKeyboard: @escaping (ContainedViewLayoutTransition) -> Void,
        requestDismiss: @escaping (ContextMenuActionResult) -> Void,
        requestAnimateOut: @escaping (ContextMenuActionResult, @escaping () -> Void) -> Void,
        source: ContentSource
    ) {
        self.context = context
        self.getController = getController
        self.requestUpdate = requestUpdate
        self.requestUpdateOverlayWantsToBeBelowKeyboard = requestUpdateOverlayWantsToBeBelowKeyboard
        self.requestDismiss = requestDismiss
        self.requestAnimateOut = requestAnimateOut
        self.source = source
        
        self.dismissTapNode = ASDisplayNode()
        
        self.dismissAccessibilityArea = AccessibilityAreaNode()
        self.dismissAccessibilityArea.accessibilityTraits = .button
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        
        self.scroller = UIScrollView()
        self.scroller.canCancelContentTouches = true
        self.scroller.delaysContentTouches = false
        self.scroller.showsVerticalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.scroller.contentInsetAdjustmentBehavior = .never
        }
        self.scroller.alwaysBounceVertical = true
        
        self.scrollNode = ASDisplayNode()
        self.scrollNode.view.addGestureRecognizer(self.scroller.panGestureRecognizer)
        
        self.contentRectDebugNode = ASDisplayNode()
        self.contentRectDebugNode.isUserInteractionEnabled = false
        self.contentRectDebugNode.backgroundColor = UIColor.red.withAlphaComponent(0.2)
        
        self.actionsContainerNode = ASDisplayNode()
        self.actionsStackNode = ContextControllerActionsStackNode(
            context: self.context,
            getController: getController,
            requestDismiss: { result in
                requestDismiss(result)
            },
            requestUpdate: requestUpdate
        )
        
        self.additionalActionsStackNode = ContextControllerActionsStackNode(
            context: self.context,
            getController: getController,
            requestDismiss: { result in
                requestDismiss(result)
            },
            requestUpdate: requestUpdate
        )
        
        super.init()
        
        self.view.addSubview(self.scroller)
        self.scroller.isHidden = true
        
        self.addSubnode(self.clippingNode)
        self.clippingNode.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.dismissTapNode)
        self.scrollNode.addSubnode(self.dismissAccessibilityArea)
        self.scrollNode.addSubnode(self.actionsContainerNode)
        self.actionsContainerNode.addSubnode(self.additionalActionsStackNode)
        self.actionsContainerNode.addSubnode(self.actionsStackNode)
        
        #if DEBUG
        //self.addSubnode(self.contentRectDebugNode)
        #endif

        self.scroller.delegate = self.wrappedScrollViewDelegate
        
        self.dismissTapNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dismissTapGesture(_:))))
        
        self.dismissAccessibilityArea.activate = { [weak self] in
            self?.requestDismiss(.default)
            
            return true
        }
    }
    
    @objc func dismissTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.requestDismiss(.default)
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            if let reactionContextNode = self.reactionContextNode {
                if let result = reactionContextNode.hitTest(self.view.convert(point, to: reactionContextNode.view), with: event) {
                    return result
                }
            }
            
            if case let .extracted(source) = self.source, !source.ignoreContentTouches, let contentNode = self.itemContentNode {
                let contentPoint = self.view.convert(point, to: contentNode.containingItem.contentView)
                if let result = contentNode.containingItem.customHitTest?(contentPoint) {
                    return result
                } else if let result = contentNode.containingItem.contentHitTest(contentPoint, with: event) {
                    if source.keepDefaultContentTouches {
                        return result
                    } else if result is TextSelectionNodeView {
                        return result
                    } else if contentNode.containingItem.contentRect.contains(contentPoint) {
                        return contentNode.containingItem.contentView
                    }
                }
            } else if case .controller = self.source, let contentNode = self.controllerContentNode {
                let contentPoint = self.view.convert(point, to: contentNode.view)
                let _ = contentPoint
                //TODO:
            }
            
            if let result = self.scrollNode.hitTest(self.view.convert(point, to: self.scrollNode.view), with: event) {
                if let reactionContextNode = self.reactionContextNode, reactionContextNode.isExpanded {
                    if result === self.actionsContainerNode.view {
                        return self.dismissTapNode.view
                    }
                }
                return result
            }
            
            return nil
        } else {
            return nil
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if let reactionContextNode = self.reactionContextNode, (reactionContextNode.isExpanded || !reactionContextNode.canBeExpanded) {
            self.overscrollMode = .disabled
            self.scroller.alwaysBounceVertical = false
        } else {
            if scrollView.contentSize.height > scrollView.bounds.height {
                self.overscrollMode = .unrestricted
                self.scroller.alwaysBounceVertical = true
            } else {
                if self.reactionContextNode != nil {
                    self.overscrollMode = .topOnly
                    self.scroller.alwaysBounceVertical = true
                } else {
                    self.overscrollMode = .disabled
                    self.scroller.alwaysBounceVertical = false
                }
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var adjustedBounds = scrollView.bounds
        var topOverscroll: CGFloat = 0.0
        
        switch self.overscrollMode {
        case .unrestricted:
            if adjustedBounds.origin.y < 0.0 {
                topOverscroll = -adjustedBounds.origin.y
            }
        case .disabled:
            break
        case .topOnly:
            if scrollView.contentSize.height <= scrollView.bounds.height {
                if adjustedBounds.origin.y > 0.0 {
                    adjustedBounds.origin.y = 0.0
                } else {
                    adjustedBounds.origin.y = floorToScreenPixels(adjustedBounds.origin.y * 0.35)
                    topOverscroll = -adjustedBounds.origin.y
                }
            } else {
                if adjustedBounds.origin.y < 0.0 {
                    adjustedBounds.origin.y = floorToScreenPixels(adjustedBounds.origin.y * 0.35)
                    topOverscroll = -adjustedBounds.origin.y
                } else if adjustedBounds.origin.y + adjustedBounds.height > scrollView.contentSize.height {
                    adjustedBounds.origin.y = scrollView.contentSize.height - adjustedBounds.height
                }
            }
        }
        self.scrollNode.bounds = adjustedBounds
        
        if let reactionContextNode = self.reactionContextNode {
            let isIntersectingContent = adjustedBounds.minY >= 10.0
            reactionContextNode.updateIsIntersectingContent(isIntersectingContent: isIntersectingContent, transition: .animated(duration: 0.25, curve: .easeInOut))
            
            if !reactionContextNode.isExpanded && reactionContextNode.canBeExpanded {
                if topOverscroll > 30.0 && self.scroller.isTracking {
                    self.scroller.panGestureRecognizer.state = .cancelled
                    reactionContextNode.expand()
                } else {
                    reactionContextNode.updateExtension(distance: topOverscroll)
                }
            }
        }
    }
    
    func highlightGestureMoved(location: CGPoint, hover: Bool) {
        self.actionsStackNode.highlightGestureMoved(location: self.view.convert(location, to: self.actionsStackNode.view))
        
        if let reactionContextNode = self.reactionContextNode {
            reactionContextNode.highlightGestureMoved(location: self.view.convert(location, to: reactionContextNode.view), hover: hover)
        }
    }
    
    func highlightGestureFinished(performAction: Bool) {
        self.actionsStackNode.highlightGestureFinished(performAction: performAction)
        
        if let reactionContextNode = self.reactionContextNode {
            reactionContextNode.highlightGestureFinished(performAction: performAction)
        }
    }
    
    func decreaseHighlightedIndex() {
        self.actionsStackNode.decreaseHighlightedIndex()
    }
    
    func increaseHighlightedIndex() {
        self.actionsStackNode.increaseHighlightedIndex()
    }
    
    func wantsDisplayBelowKeyboard() -> Bool {
        if let reactionContextNode = self.reactionContextNode {
            return reactionContextNode.wantsDisplayBelowKeyboard()
        } else if case let .reference(source) = self.source {
            return source.forceDisplayBelowKeyboard
        } else {
            return false
        }
    }
    
    func replaceItems(items: ContextController.Items, animated: Bool?) {
        if case .twoLists = items.content {
            let stackItems = makeContextControllerActionsStackItem(items: items)
            self.actionsStackNode.replace(item: stackItems.first!, animated: animated)
            self.additionalActionsStackNode.replace(item: stackItems.last!, animated: animated)
        } else {
            self.actionsStackNode.replace(item: makeContextControllerActionsStackItem(items: items).first!, animated: animated)
        }
    }
    
    func pushItems(items: ContextController.Items) {
        let currentScrollingState = self.getCurrentScrollingState()
        var positionLock: CGFloat?
        if !items.disablePositionLock {
            positionLock = self.getActionsStackPositionLock()
        }
        if self.actionsStackNode.topPositionLock == nil {
            if let contentNode = self.controllerContentNode, contentNode.bounds.height != 0.0 {
                contentNode.storedContentHeight = contentNode.bounds.height
            }
        }
        self.actionsStackNode.push(item: makeContextControllerActionsStackItem(items: items).first!, currentScrollingState: currentScrollingState, positionLock: positionLock, animated: true)
    }
    
    func popItems() {
        self.actionsStackNode.pop()
        if self.actionsStackNode.topPositionLock == nil {
            if let contentNode = self.controllerContentNode {
                contentNode.storedContentHeight = nil
            }
        }
    }
    
    private func getCurrentScrollingState() -> CGFloat {
        return self.scrollNode.bounds.minY
    }
    
    private func getActionsStackPositionLock() -> CGFloat? {
        switch self.source {
        case .location, .reference:
            return nil
        case .extracted, .controller:
            return self.actionsStackNode.view.convert(CGPoint(), to: self.view).y
        }
    }
    
    private var proposedReactionsPositionLock: CGFloat?
    private var currentReactionsPositionLock: CGFloat?
    
    private func setCurrentReactionsPositionLock() {
        self.currentReactionsPositionLock = self.proposedReactionsPositionLock
    }
    
    private func getCurrentReactionsPositionLock() -> CGFloat? {
        return self.currentReactionsPositionLock
    }
    
    func update(
        presentationData: PresentationData,
        layout: ContainerViewLayout,
        transition: ContainedViewLayoutTransition,
        stateTransition: ContextControllerPresentationNodeStateTransition?
    ) {
        self.validLayout = layout
        
        var contentActionsSpacing: CGFloat = 7.0
        let actionsEdgeInset: CGFloat
        let actionsSideInset: CGFloat
        let topInset: CGFloat = layout.insets(options: .statusBar).top + 8.0
        let bottomInset: CGFloat = 10.0
        
        let itemContentNode: ItemContentNode?
        let controllerContentNode: ControllerContentNode?
        var contentTransition = transition
        
        if self.strings !== presentationData.strings {
            self.strings = presentationData.strings
            
            self.dismissAccessibilityArea.accessibilityLabel = presentationData.strings.VoiceOver_DismissContextMenu
        }
        
        switch self.source {
        case .location, .reference:
            actionsEdgeInset = 16.0
            actionsSideInset = 6.0
        case .extracted:
            actionsEdgeInset = 12.0
            actionsSideInset = 6.0
        case .controller:
            actionsEdgeInset = 12.0
            actionsSideInset = -2.0
            contentActionsSpacing += 3.0
        }
        
        transition.updateFrame(node: self.clippingNode, frame: CGRect(origin: CGPoint(), size: layout.size), beginWithCurrentState: true)
        if self.scrollNode.frame != CGRect(origin: CGPoint(), size: layout.size) {
            transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size), beginWithCurrentState: true)
            transition.updateFrame(view: self.scroller, frame: CGRect(origin: CGPoint(), size: layout.size), beginWithCurrentState: true)
        }
        
        if let current = self.itemContentNode {
            itemContentNode = current
        } else {
            switch self.source {
            case .location, .reference, .controller:
                itemContentNode = nil
            case let .extracted(source):
                guard let takeInfo = source.takeView() else {
                    return
                }
                let contentNodeValue = ItemContentNode(containingItem: takeInfo.containingItem)
                contentNodeValue.animateClippingFromContentAreaInScreenSpace = takeInfo.contentAreaInScreenSpace
                self.scrollNode.insertSubnode(contentNodeValue, aboveSubnode: self.actionsContainerNode)
                self.itemContentNode = contentNodeValue
                itemContentNode = contentNodeValue
                contentTransition = .immediate
            }
        }
        
        if let current = self.controllerContentNode {
            controllerContentNode = current
        } else {
            switch self.source {
            case let .controller(source):
                let controllerContentNodeValue = ControllerContentNode(controller: source.controller, passthroughTouches: source.passthroughTouches)
                
                //source.controller.viewWillAppear(false)
                //source.controller.setIgnoreAppearanceMethodInvocations(true)
                
                self.scrollNode.insertSubnode(controllerContentNodeValue, aboveSubnode: self.actionsContainerNode)
                self.controllerContentNode = controllerContentNodeValue
                controllerContentNode = controllerContentNodeValue
                contentTransition = .immediate
                
                //source.controller.setIgnoreAppearanceMethodInvocations(false)
                //source.controller.viewDidAppear(false)
            case .location, .reference, .extracted:
                controllerContentNode = nil
            }
        }
        
        var animateReactionsIn = false
        var contentTopInset: CGFloat = topInset
        var removedReactionContextNode: ReactionContextNode?
        
        if let reactionItems = self.actionsStackNode.topReactionItems, !reactionItems.reactionItems.isEmpty, let controller = self.getController() as? ContextController {
            let reactionContextNode: ReactionContextNode
            if let current = self.reactionContextNode {
                reactionContextNode = current
            } else {
                reactionContextNode = ReactionContextNode(
                    context: reactionItems.context,
                    animationCache: reactionItems.animationCache,
                    presentationData: presentationData,
                    items: reactionItems.reactionItems,
                    selectedItems: reactionItems.selectedReactionItems,
                    title: reactionItems.reactionsTitle,
                    reactionsLocked: reactionItems.reactionsLocked,
                    alwaysAllowPremiumReactions: reactionItems.alwaysAllowPremiumReactions,
                    allPresetReactionsAreAvailable: reactionItems.allPresetReactionsAreAvailable,
                    getEmojiContent: reactionItems.getEmojiContent,
                    isExpandedUpdated: { [weak self] transition in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.setCurrentReactionsPositionLock()
                        strongSelf.requestUpdate(transition)
                    },
                    requestLayout: { [weak self] transition in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.requestUpdate(transition)
                    },
                    requestUpdateOverlayWantsToBeBelowKeyboard: { [weak self] transition in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.requestUpdateOverlayWantsToBeBelowKeyboard(transition)
                    }
                )
                reactionContextNode.displayTail = !controller.hideReactionPanelTail
                self.reactionContextNode = reactionContextNode
                self.addSubnode(reactionContextNode)
                
                if transition.isAnimated {
                    animateReactionsIn = true
                }
                
                reactionContextNode.reactionSelected = { [weak self] reaction, isLarge in
                    guard let strongSelf = self, let controller = strongSelf.getController() as? ContextController else {
                        return
                    }
                    controller.reactionSelected?(reaction, isLarge)
                }
                let context = reactionItems.context
                reactionContextNode.premiumReactionsSelected = { [weak self] file in
                    guard let strongSelf = self, let validLayout = strongSelf.validLayout, let controller = strongSelf.getController() as? ContextController else {
                        return
                    }
                    
                    if let reactionItems = strongSelf.actionsStackNode.topReactionItems, !reactionItems.reactionItems.isEmpty {
                        if reactionItems.allPresetReactionsAreAvailable {
                            controller.premiumReactionsSelected?()
                            return
                        }
                    }
                    
                    if let file = file, let reactionContextNode = strongSelf.reactionContextNode {
                        let position: UndoOverlayController.Position
                        let insets = validLayout.insets(options: .statusBar)
                        if reactionContextNode.hasSpaceInTheBottom(insets: insets, height: 100.0) {
                            position = .bottom
                        } else {
                            position = .top
                        }
                        
                        var animateInAsReplacement = false
                        if let currentUndoController = strongSelf.currentUndoController {
                            currentUndoController.dismiss()
                            animateInAsReplacement = true
                        }
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let undoController = UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, loop: true, title: nil, text: presentationData.strings.Chat_PremiumReactionToastTitle, undoText: presentationData.strings.Chat_PremiumReactionToastAction, customAction: { [weak controller] in
                            controller?.premiumReactionsSelected?()
                        }), elevatedLayout: false, position: position, animateInAsReplacement: animateInAsReplacement, action: { _ in true })
                        strongSelf.currentUndoController = undoController
                        controller.present(undoController, in: .current)
                    } else {
                        controller.premiumReactionsSelected?()
                    }
                }
                
                reactionContextNode.updateLayout(size: layout.size, insets: UIEdgeInsets(top: topInset, left: layout.safeInsets.left, bottom: 0.0, right: layout.safeInsets.right), anchorRect: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: CGSize(width: 1.0, height: 1.0)), isCoveredByInput: false, isAnimatingOut: false, transition: .immediate)
            }
            contentTopInset += reactionContextNode.contentHeight + 18.0
        } else if let reactionContextNode = self.reactionContextNode {
            self.reactionContextNode = nil
            removedReactionContextNode = reactionContextNode
        }
        
        let reactionPreviewSize = CGSize(width: 100.0, height: 100.0)
        let reactionPreviewInset: CGFloat = 7.0
        var removedReactionPreviewView: ReactionPreviewView?
        if self.reactionContextNode == nil, let previewReaction = self.actionsStackNode.topPreviewReaction {
            let reactionPreviewView: ReactionPreviewView
            if let current = self.reactionPreviewView {
                reactionPreviewView = current
            } else {
                reactionPreviewView = ReactionPreviewView(context: previewReaction.context, file: previewReaction.file)
                self.reactionPreviewView = reactionPreviewView
                self.view.addSubview(reactionPreviewView)
            }
            
            contentTopInset += reactionPreviewSize.height + reactionPreviewInset
        } else {
            removedReactionPreviewView = self.reactionPreviewView
            self.reactionPreviewView = nil
        }
        
        if let contentNode = itemContentNode {
            switch stateTransition {
            case .animateIn, .animateOut:
                contentNode.storedGlobalFrame = convertFrame(contentNode.containingItem.contentRect, from: contentNode.containingItem.view, to: self.view)
                
                var rect = convertFrame(contentNode.containingItem.view.bounds, from: contentNode.containingItem.view, to: self.view)
                if rect.origin.x < 0.0 {
                    rect.origin.x += layout.size.width
                }
                contentNode.storedGlobalBoundsFrame = rect
            case .none:
                if contentNode.storedGlobalFrame == nil {
                    contentNode.storedGlobalFrame = convertFrame(contentNode.containingItem.contentRect, from: contentNode.containingItem.view, to: self.view)
                }
            }
        }
        
        var contentParentGlobalFrame: CGRect
        var contentRect: CGRect
        var isContentResizeableVertically: Bool = false
        let _ = isContentResizeableVertically
        
        switch self.source {
        case let .location(location):
            if let transitionInfo = location.transitionInfo() {
                contentRect = CGRect(origin: transitionInfo.location, size: CGSize(width: 1.0, height: 1.0))
                contentParentGlobalFrame = CGRect(origin: CGPoint(x: 0.0, y: contentRect.minY), size: CGSize(width: layout.size.width, height: contentRect.height))
            } else {
                return
            }
        case let .reference(reference):
            if let transitionInfo = reference.transitionInfo() {
                contentRect = convertFrame(transitionInfo.referenceView.bounds.inset(by: transitionInfo.insets), from: transitionInfo.referenceView, to: self.view).insetBy(dx: -2.0, dy: 0.0)
                contentRect.size.width += 5.0
                contentParentGlobalFrame = CGRect(origin: CGPoint(x: 0.0, y: contentRect.minY), size: CGSize(width: layout.size.width, height: contentRect.height))
            } else {
                return
            }
        case .extracted:
            if let contentNode = itemContentNode {
                contentParentGlobalFrame = convertFrame(contentNode.containingItem.view.bounds, from: contentNode.containingItem.view, to: self.view)
                if let frame = contentNode.storedGlobalBoundsFrame {
                    contentParentGlobalFrame.origin.x = frame.minX
                }
                let contentRectGlobalFrame = CGRect(origin: CGPoint(x: contentNode.containingItem.contentRect.minX, y: (contentNode.storedGlobalFrame?.maxY ?? 0.0) - contentNode.containingItem.contentRect.height), size: contentNode.containingItem.contentRect.size)
                contentRect = CGRect(origin: CGPoint(x: contentRectGlobalFrame.minX, y: contentRectGlobalFrame.maxY - contentNode.containingItem.contentRect.size.height), size: contentNode.containingItem.contentRect.size)
                if case .animateOut = stateTransition {
                    contentRect.origin.y = self.contentRectDebugNode.frame.maxY - contentRect.size.height
                }
            } else {
                return
            }
        case let .controller(source):
            if let contentNode = controllerContentNode {
                var defaultContentSize = CGSize(width: layout.size.width - 12.0 * 2.0, height: layout.size.height - 12.0 * 2.0 - contentTopInset - layout.safeInsets.bottom)
                if case .regular = layout.metrics.widthClass {
                    defaultContentSize.width = min(defaultContentSize.width, 400.0)
                }
                defaultContentSize.height = min(defaultContentSize.height, 460.0)
                
                let contentSize: CGSize
                if let preferredSize = contentNode.controller.preferredContentSizeForLayout(ContainerViewLayout(size: defaultContentSize, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false)) {
                    contentSize = preferredSize
                } else if let storedContentHeight = contentNode.storedContentHeight {
                    contentSize = CGSize(width: defaultContentSize.width, height: storedContentHeight)
                } else {
                    contentSize = defaultContentSize
                    isContentResizeableVertically = true
                }
                
                if case .regular = layout.metrics.widthClass {
                    if let transitionInfo = source.transitionInfo(), let (sourceView, sourceRect) = transitionInfo.sourceNode() {
                        let sourcePoint = sourceView.convert(sourceRect.center, to: self.view)
                        
                        contentRect = CGRect(origin: CGPoint(x: sourcePoint.x - floor(contentSize.width * 0.5), y: sourcePoint.y - floor(contentSize.height * 0.5)), size: contentSize)
                        if contentRect.origin.x < 0.0 {
                            contentRect.origin.x = 0.0
                        }
                        if contentRect.origin.y < 0.0 {
                            contentRect.origin.y = 0.0
                        }
                        if contentRect.origin.x + contentRect.width > layout.size.width {
                            contentRect.origin.x = layout.size.width - contentRect.width
                        }
                        if contentRect.origin.y + contentRect.height > layout.size.height {
                            contentRect.origin.y = layout.size.height - contentRect.height
                        }
                    } else {
                        contentRect = CGRect(origin: CGPoint(x: floor((layout.size.width - contentSize.width) * 0.5), y: floor((layout.size.height - contentSize.height) * 0.5)), size: contentSize)
                    }
                } else {
                    contentRect = CGRect(origin: CGPoint(x: floor((layout.size.width - contentSize.width) * 0.5), y: floor((layout.size.height - contentSize.height) * 0.5)), size: contentSize)
                }
                
                contentParentGlobalFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: layout.size.height))
            } else {
                return
            }
        }
        
        var contentParentGlobalFrameOffsetX: CGFloat = 0.0
        if case let .extracted(extracted) = self.source, extracted.adjustContentForSideInset {
            let contentSideInset: CGFloat = actionsSideInset + 6.0
            
            var updatedFrame = contentParentGlobalFrame
            if updatedFrame.origin.x + updatedFrame.width > layout.size.width - contentSideInset {
                updatedFrame.origin.x = layout.size.width - contentSideInset - updatedFrame.width
            }
            if updatedFrame.origin.x < contentSideInset {
                updatedFrame.origin.x = contentSideInset
            }
            
            contentParentGlobalFrameOffsetX = updatedFrame.minX - contentParentGlobalFrame.minX
            contentParentGlobalFrame = updatedFrame
        }
        
        let keepInPlace: Bool
        let actionsHorizontalAlignment: ContextActionsHorizontalAlignment
        switch self.source {
        case .location, .reference:
            keepInPlace = true
            actionsHorizontalAlignment = .default
        case let .extracted(source):
            keepInPlace = source.keepInPlace
            actionsHorizontalAlignment = source.actionsHorizontalAlignment
        case .controller:
            //TODO:
            keepInPlace = false
            actionsHorizontalAlignment = .default
        }
        
        var defaultScrollY: CGFloat = 0.0
        if self.animatingOutState == nil {
            if let contentNode = itemContentNode {
                contentNode.update(
                    presentationData: presentationData,
                    size: contentNode.containingItem.view.bounds.size,
                    transition: contentTransition
                )
            }
            
            let actionsConstrainedHeight: CGFloat
            if let actionsPositionLock = self.actionsStackNode.topPositionLock {
                actionsConstrainedHeight = layout.size.height - bottomInset - layout.intrinsicInsets.bottom - actionsPositionLock
            } else {
                if case let .reference(reference) = self.source, reference.keepInPlace {
                    actionsConstrainedHeight = layout.size.height - contentRect.maxY - contentActionsSpacing - bottomInset - layout.intrinsicInsets.bottom
                } else {
                    actionsConstrainedHeight = layout.size.height - contentTopInset - contentRect.height - contentActionsSpacing - bottomInset - layout.intrinsicInsets.bottom
                }
            }
            
            let actionsStackPresentation: ContextControllerActionsStackNode.Presentation
            switch self.source {
            case .location, .reference, .controller:
                actionsStackPresentation = .inline
            case .extracted:
                actionsStackPresentation = .modal
            }
            
            let additionalActionsSize = self.additionalActionsStackNode.update(
                presentationData: presentationData,
                constrainedSize: CGSize(width: layout.size.width, height: actionsConstrainedHeight),
                presentation: .additional,
                transition: transition
            )
            self.additionalActionsStackNode.isHidden = additionalActionsSize.height.isZero
            
            let actionsSize = self.actionsStackNode.update(
                presentationData: presentationData,
                constrainedSize: CGSize(width: layout.size.width, height: actionsConstrainedHeight),
                presentation: actionsStackPresentation,
                transition: transition
            )
            
            if isContentResizeableVertically && self.actionsStackNode.topPositionLock == nil {
                var contentHeight = layout.size.height - contentTopInset - contentActionsSpacing - bottomInset - layout.intrinsicInsets.bottom - actionsSize.height
                contentHeight = min(contentHeight, contentRect.height)
                contentHeight = max(contentHeight, 200.0)
                
                if case .regular = layout.metrics.widthClass {
                } else {
                    contentRect = CGRect(origin: CGPoint(x: contentRect.minX, y: floor(contentRect.midY - contentHeight * 0.5)), size: CGSize(width: contentRect.width, height: contentHeight))
                }
            }
            
            var isAnimatingOut = false
            if case .animateOut = stateTransition {
                isAnimatingOut = true
            } else {
                if let currentReactionsPositionLock = self.currentReactionsPositionLock, let reactionContextNode = self.reactionContextNode {
                    contentRect.origin.y = currentReactionsPositionLock + reactionContextNode.contentHeight + 18.0 + reactionContextNode.visibleExtensionDistance
                } else if let topPositionLock = self.actionsStackNode.topPositionLock {
                    contentRect.origin.y = topPositionLock - contentActionsSpacing - contentRect.height
                } else if keepInPlace {
                } else {
                    if contentRect.minY < contentTopInset {
                        contentRect.origin.y = contentTopInset
                    }
                    var combinedBounds = CGRect(origin: CGPoint(x: 0.0, y: contentRect.minY), size: CGSize(width: layout.size.width, height: contentRect.height + contentActionsSpacing + actionsSize.height))
                    if combinedBounds.maxY > layout.size.height - bottomInset - layout.intrinsicInsets.bottom {
                        combinedBounds.origin.y = layout.size.height - bottomInset - layout.intrinsicInsets.bottom - combinedBounds.height
                    }
                    if combinedBounds.minY < contentTopInset {
                        combinedBounds.origin.y = contentTopInset
                    }
                    
                    contentRect.origin.y = combinedBounds.minY
                }
            }
            
            if let reactionContextNode = self.reactionContextNode {
                var reactionContextNodeTransition = transition
                if reactionContextNode.frame.isEmpty {
                    reactionContextNodeTransition = .immediate
                }
                reactionContextNodeTransition.updateFrame(node: reactionContextNode, frame: CGRect(origin: CGPoint(), size: layout.size), beginWithCurrentState: true)
                
                var reactionAnchorRect = contentRect.offsetBy(dx: contentParentGlobalFrame.minX, dy: 0.0)
                
                let bottomInset = layout.insets(options: [.input]).bottom
                var isCoveredByInput = false
                if reactionAnchorRect.minY > layout.size.height - bottomInset {
                    reactionAnchorRect.origin.y = layout.size.height - bottomInset
                    isCoveredByInput = true
                }
                
                reactionContextNode.updateLayout(size: layout.size, insets: UIEdgeInsets(top: topInset, left: layout.safeInsets.left, bottom: 0.0, right: layout.safeInsets.right), anchorRect: reactionAnchorRect, isCoveredByInput: isCoveredByInput, isAnimatingOut: isAnimatingOut, transition: reactionContextNodeTransition)
                
                if reactionContextNode.alwaysAllowPremiumReactions {
                    self.proposedReactionsPositionLock = contentRect.minY - 18.0 - reactionContextNode.contentHeight
                } else {
                    self.proposedReactionsPositionLock = contentRect.minY - 18.0 - reactionContextNode.contentHeight - (46.0 + 54.0 - 4.0)
                }
            } else {
                self.proposedReactionsPositionLock = nil
            }
            
            if let reactionPreviewView = self.reactionPreviewView {
                let anchorRect = contentRect.offsetBy(dx: contentParentGlobalFrame.minX, dy: 0.0)
                
                let reactionPreviewFrame = CGRect(origin: CGPoint(x: floor((anchorRect.midX - reactionPreviewSize.width * 0.5)), y: anchorRect.minY - reactionPreviewInset - reactionPreviewSize.height), size: reactionPreviewSize)
                transition.updateFrame(view: reactionPreviewView, frame: reactionPreviewFrame)
                reactionPreviewView.update(size: reactionPreviewFrame.size)
            }
            
            if let _ = self.currentReactionsPositionLock {
                transition.updateAlpha(node: self.actionsStackNode, alpha: 0.0)
            } else {
                transition.updateAlpha(node: self.actionsStackNode, alpha: 1.0)
            }
            
            if let removedReactionContextNode = removedReactionContextNode {
                removedReactionContextNode.animateOut(to: contentRect, animatingOutToReaction: false)
                transition.updateAlpha(node: removedReactionContextNode, alpha: 0.0, completion: { [weak removedReactionContextNode] _ in
                    removedReactionContextNode?.removeFromSupernode()
                })
            }
            
            if let removedReactionPreviewView {
                transition.updateAlpha(layer: removedReactionPreviewView.layer, alpha: 0.0, completion: { [weak removedReactionPreviewView] _ in
                    removedReactionPreviewView?.removeFromSuperview()
                })
            }
            
            transition.updateFrame(node: self.contentRectDebugNode, frame: contentRect, beginWithCurrentState: true)
            
            var actionsFrame: CGRect
            if case let .reference(source) = self.source, let actionsPosition = source.transitionInfo()?.actionsPosition, case .top = actionsPosition {
                actionsFrame = CGRect(origin: CGPoint(x: actionsSideInset, y: contentRect.minY - contentActionsSpacing - actionsSize.height), size: actionsSize)
            } else {
                actionsFrame = CGRect(origin: CGPoint(x: actionsSideInset, y: contentRect.maxY + contentActionsSpacing), size: actionsSize)
            }
            var contentVerticalOffset: CGFloat = 0.0
                        
            if keepInPlace, case .extracted = self.source {
                actionsFrame.origin.y = contentRect.minY - contentActionsSpacing - actionsFrame.height
                let statusBarHeight = (layout.statusBarHeight ?? 0.0)
                if actionsFrame.origin.y < statusBarHeight {
                    let updatedActionsOriginY = statusBarHeight + contentActionsSpacing
                    let delta = updatedActionsOriginY - actionsFrame.origin.y
                    actionsFrame.origin.y = updatedActionsOriginY
                    contentVerticalOffset = delta
                }
            }
            var additionalVisibleOffsetY: CGFloat = 0.0
            if let reactionContextNode = self.reactionContextNode {
                additionalVisibleOffsetY += reactionContextNode.visibleExtensionDistance
            }
            if case .center = actionsHorizontalAlignment {
                actionsFrame.origin.x = floor(contentParentGlobalFrame.minX + contentRect.midX - actionsFrame.width / 2.0)
                if actionsFrame.maxX > layout.size.width - actionsEdgeInset {
                    actionsFrame.origin.x = layout.size.width - actionsEdgeInset - actionsFrame.width
                }
                if actionsFrame.minX < actionsEdgeInset {
                    actionsFrame.origin.x = actionsEdgeInset
                }
            } else {
                if case .location = self.source {
                    actionsFrame.origin.x = contentParentGlobalFrame.minX + contentRect.minX + actionsSideInset - 4.0
                } else if case .right = actionsHorizontalAlignment {
                    actionsFrame.origin.x = contentParentGlobalFrame.minX + contentRect.maxX - actionsSideInset - actionsSize.width - 1.0
                } else {
                    if contentRect.midX < layout.size.width / 2.0 {
                        actionsFrame.origin.x = contentParentGlobalFrame.minX + contentRect.minX + actionsSideInset - 4.0
                    } else {
                        switch self.source {
                        case .location, .reference:
                            actionsFrame.origin.x = floor(contentParentGlobalFrame.minX + contentRect.midX - actionsFrame.width / 2.0)
                            if actionsFrame.maxX > layout.size.width - actionsEdgeInset {
                                actionsFrame.origin.x = layout.size.width - actionsEdgeInset - actionsFrame.width
                            }
                            if actionsFrame.minX < actionsEdgeInset {
                                actionsFrame.origin.x = actionsEdgeInset
                            }
                        case .extracted:
                            actionsFrame.origin.x = contentParentGlobalFrame.minX + contentRect.maxX - actionsSideInset - actionsSize.width - 1.0
                        case .controller:
                            //TODO:
                            actionsFrame.origin.x = contentParentGlobalFrame.minX + contentRect.maxX - actionsSideInset - actionsSize.width - 1.0
                        }
                    }
                }
                if actionsFrame.maxX > layout.size.width - actionsEdgeInset {
                    actionsFrame.origin.x = layout.size.width - actionsEdgeInset - actionsFrame.width
                }
                if actionsFrame.minX < actionsEdgeInset {
                    actionsFrame.origin.x = actionsEdgeInset
                }
            }
            
            if case let .reference(reference) = self.source, let transitionInfo = reference.transitionInfo(), let customPosition = transitionInfo.customPosition {
                actionsFrame = actionsFrame.offsetBy(dx: customPosition.x, dy: customPosition.y)
            }
            
            var additionalActionsFrame: CGRect
            let combinedActionsFrame: CGRect
            if additionalActionsSize.height > 0.0 {
                additionalActionsFrame = CGRect(origin: actionsFrame.origin, size: additionalActionsSize)
                actionsFrame = actionsFrame.offsetBy(dx: 0.0, dy: additionalActionsSize.height + 10.0)
                combinedActionsFrame = actionsFrame.union(additionalActionsFrame)
            } else {
                additionalActionsFrame = .zero
                combinedActionsFrame = actionsFrame
            }
        
            transition.updateFrame(node: self.actionsContainerNode, frame: combinedActionsFrame.offsetBy(dx: 0.0, dy: additionalVisibleOffsetY))
            transition.updateFrame(node: self.actionsStackNode, frame: CGRect(origin: CGPoint(x: 0.0, y: combinedActionsFrame.height - actionsSize.height), size: actionsSize), beginWithCurrentState: true)
            transition.updateFrame(node: self.additionalActionsStackNode, frame: CGRect(origin: .zero, size: additionalActionsSize), beginWithCurrentState: true)
            
            if let contentNode = itemContentNode {
                var contentFrame = CGRect(origin: CGPoint(x: contentParentGlobalFrame.minX + contentRect.minX - contentNode.containingItem.contentRect.minX, y: contentRect.minY - contentNode.containingItem.contentRect.minY + contentVerticalOffset + additionalVisibleOffsetY), size: contentNode.containingItem.view.bounds.size)
                if case let .extracted(extracted) = self.source {
                    if extracted.adjustContentHorizontally {
                        contentFrame.origin.x = combinedActionsFrame.minX
                        if contentFrame.maxX > layout.size.width {
                            contentFrame.origin.x = layout.size.width - contentFrame.width - actionsEdgeInset
                        }
                    }
                    if extracted.centerVertically {
                        if combinedActionsFrame.height.isZero {
                            contentFrame.origin.y = floorToScreenPixels((layout.size.height -  contentFrame.height) / 2.0)
                        } else if contentFrame.midX > layout.size.width / 2.0 {
                            contentFrame.origin.x = layout.size.width - contentFrame.maxX
                        }
                    }
                }
                contentTransition.updateFrame(node: contentNode, frame: contentFrame, beginWithCurrentState: true)
            }
            if let contentNode = controllerContentNode {
                //TODO:
                var contentFrame = CGRect(origin: CGPoint(x: contentRect.minX, y: contentRect.minY + contentVerticalOffset + additionalVisibleOffsetY), size: contentRect.size)
                if case let .extracted(extracted) = self.source, extracted.centerVertically {
                    if combinedActionsFrame.height.isZero {
                        contentFrame.origin.y = floorToScreenPixels((layout.size.height -  contentFrame.height) / 2.0)
                    } else if contentFrame.midX > layout.size.width / 2.0 {
                        contentFrame.origin.x = layout.size.width - contentFrame.maxX
                    }
                }
                contentTransition.updateFrame(node: contentNode, frame: contentFrame, beginWithCurrentState: true)
                
                contentNode.update(
                    presentationData: presentationData,
                    parentLayout: layout,
                    size: contentFrame.size,
                    transition: contentTransition
                )
            }
            
            let contentHeight: CGFloat
            if self.actionsStackNode.topPositionLock != nil || self.currentReactionsPositionLock != nil {
                contentHeight = layout.size.height
            } else {
                if keepInPlace, case .extracted = self.source {
                    contentHeight = (layout.statusBarHeight ?? 0.0) + actionsFrame.height + abs(actionsFrame.minY) + bottomInset + layout.intrinsicInsets.bottom
                } else {
                    contentHeight = actionsFrame.maxY + bottomInset + layout.intrinsicInsets.bottom
                }
            }
            let contentSize = CGSize(width: layout.size.width, height: contentHeight)
            
            if self.scroller.contentSize != contentSize {
                let previousContentOffset = self.scroller.contentOffset
                self.scroller.contentSize = contentSize
                if let storedScrollingState = self.actionsStackNode.storedScrollingState {
                    self.actionsStackNode.clearStoredScrollingState()
                    
                    self.scroller.contentOffset = CGPoint(x: 0.0, y: storedScrollingState)
                }
                if case .none = stateTransition, transition.isAnimated {
                    let contentOffset = self.scroller.contentOffset
                    transition.animateOffsetAdditive(layer: self.scrollNode.layer, offset: previousContentOffset.y - contentOffset.y)
                }
            }
            
            self.actionsStackNode.updatePanSelection(isEnabled: contentSize.height <= layout.size.height)
            
            defaultScrollY = contentSize.height - layout.size.height
            if defaultScrollY < 0.0 {
                defaultScrollY = 0.0
            }
            
            self.dismissTapNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: contentSize.width, height: max(contentSize.height, layout.size.height)))
            self.dismissAccessibilityArea.frame = CGRect(origin: CGPoint(), size: CGSize(width: contentSize.width, height: max(contentSize.height, layout.size.height)))
        }
        
        switch stateTransition {
        case .animateIn:
            let actionsSize = self.actionsContainerNode.bounds.size
            
            if let contentNode = itemContentNode {
                contentNode.takeContainingNode()
            }
            
            let duration: Double = 0.42
            let springDamping: CGFloat = 104.0
            
            self.scroller.contentOffset = CGPoint(x: 0.0, y: defaultScrollY)
            
            var animationInContentYDistance: CGFloat
            let currentContentScreenFrame: CGRect
            if let contentNode = itemContentNode {
                if let animateClippingFromContentAreaInScreenSpace = contentNode.animateClippingFromContentAreaInScreenSpace {
                    self.clippingNode.layer.animateFrame(from: CGRect(origin: CGPoint(x: 0.0, y: animateClippingFromContentAreaInScreenSpace.minY), size: CGSize(width: layout.size.width, height: animateClippingFromContentAreaInScreenSpace.height)), to: CGRect(origin: CGPoint(), size: layout.size), duration: 0.2)
                    self.clippingNode.layer.animateBoundsOriginYAdditive(from: animateClippingFromContentAreaInScreenSpace.minY, to: 0.0, duration: 0.2)
                }
                                
                currentContentScreenFrame = convertFrame(contentNode.containingItem.contentRect, from: contentNode.containingItem.view, to: self.view)
                let currentContentLocalFrame = convertFrame(contentRect, from: self.scrollNode.view, to: self.view)
                animationInContentYDistance = currentContentLocalFrame.maxY - currentContentScreenFrame.maxY

                var animationInContentXDistance: CGFloat = 0.0
                let contentX = contentParentGlobalFrame.minX + contentRect.minX - contentNode.containingItem.contentRect.minX
                let contentWidth = contentNode.containingItem.view.bounds.size.width
                let contentHeight = contentNode.containingItem.view.bounds.size.height
                if case let .extracted(extracted) = self.source, extracted.adjustContentHorizontally {
                    let fixedContentX = self.actionsContainerNode.frame.minX
                    animationInContentXDistance = fixedContentX - contentX
                } else if case let .extracted(extracted) = self.source, extracted.centerVertically {
                    if actionsSize.height.isZero {
                        var initialContentRect = contentRect
                        initialContentRect.origin.y += extracted.initialAppearanceOffset.y
                        
                        let fixedContentY = floorToScreenPixels((layout.size.height - contentHeight) / 2.0)
                        animationInContentYDistance = fixedContentY - initialContentRect.minY
                    } else if contentX + contentWidth > layout.size.width / 2.0, actionsSize.height > 0.0 {
                        let fixedContentX = layout.size.width - (contentX + contentWidth)
                        animationInContentXDistance = fixedContentX - contentX
                    }
                } else {
                    animationInContentXDistance = contentParentGlobalFrameOffsetX
                }
                
                if animationInContentXDistance != 0.0 {
                    contentNode.layer.animateSpring(
                        from: -animationInContentXDistance as NSNumber, to: 0.0 as NSNumber,
                        keyPath: "position.x",
                        duration: duration,
                        delay: 0.0,
                        initialVelocity: 0.0,
                        damping: springDamping,
                        additive: true
                    )
                }
                
                contentNode.layer.animateSpring(
                    from: -animationInContentYDistance as NSNumber, to: 0.0 as NSNumber,
                    keyPath: "position.y",
                    duration: duration,
                    delay: 0.0,
                    initialVelocity: 0.0,
                    damping: springDamping,
                    additive: true
                )
                
                if let reactionPreviewView = self.reactionPreviewView {
                    reactionPreviewView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    reactionPreviewView.layer.animateSpring(
                        from: -animationInContentYDistance as NSNumber, to: 0.0 as NSNumber,
                        keyPath: "position.y",
                        duration: duration,
                        delay: 0.0,
                        initialVelocity: 0.0,
                        damping: springDamping,
                        additive: true
                    )
                    reactionPreviewView.layer.animateSpring(
                        from: 0.01 as NSNumber,
                        to: 1.0 as NSNumber,
                        keyPath: "transform.scale",
                        duration: duration,
                        delay: 0.0,
                        initialVelocity: 0.0,
                        damping: springDamping,
                        additive: false
                    )
                }
            } else if let contentNode = controllerContentNode {
                if case let .controller(source) = self.source, let transitionInfo = source.transitionInfo(), let (sourceView, sourceRect) = transitionInfo.sourceNode() {
                    let sourcePoint = sourceView.convert(sourceRect.center, to: self.view)
                    animationInContentYDistance = contentRect.midY - sourcePoint.y
                } else {
                    animationInContentYDistance = 0.0
                }
                currentContentScreenFrame = contentRect
                
                contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                contentNode.layer.animateSpring(
                    from: -animationInContentYDistance as NSNumber, to: 0.0 as NSNumber,
                    keyPath: "position.y",
                    duration: duration,
                    delay: 0.0,
                    initialVelocity: 0.0,
                    damping: springDamping,
                    additive: true
                )
                contentNode.layer.animateSpring(
                    from: 0.01 as NSNumber, to: 1.0 as NSNumber,
                    keyPath: "transform.scale",
                    duration: duration,
                    delay: 0.0,
                    initialVelocity: 0.0,
                    damping: springDamping,
                    additive: false
                )
            } else {
                animationInContentYDistance = 0.0
                currentContentScreenFrame = contentRect
            }
            
            self.actionsContainerNode.layer.animateAlpha(from: 0.0, to: self.actionsContainerNode.alpha, duration: 0.05)
            self.actionsContainerNode.layer.animateSpring(
                from: 0.01 as NSNumber,
                to: 1.0 as NSNumber,
                keyPath: "transform.scale",
                duration: duration,
                delay: 0.0,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: false
            )
                        
            var actionsPositionDeltaXDistance: CGFloat = 0.0
            if case .center = actionsHorizontalAlignment {
                actionsPositionDeltaXDistance = currentContentScreenFrame.midX - self.actionsContainerNode.frame.midX
            }
            
            if case .reference = self.source {
                actionsPositionDeltaXDistance = currentContentScreenFrame.midX - self.actionsContainerNode.frame.midX
            }
            
            let actionsVerticalTransitionDirection: CGFloat
            if let contentNode = itemContentNode {
                if contentNode.frame.minY < self.actionsContainerNode.frame.minY {
                    actionsVerticalTransitionDirection = -1.0
                } else {
                    actionsVerticalTransitionDirection = 1.0
                }
            } else {
                if contentRect.minY < self.actionsContainerNode.frame.minY {
                    actionsVerticalTransitionDirection = -1.0
                } else {
                    actionsVerticalTransitionDirection = 1.0
                }
            }
            let actionsPositionDeltaYDistance = -animationInContentYDistance + actionsVerticalTransitionDirection * actionsSize.height / 2.0 - contentActionsSpacing
            self.actionsContainerNode.layer.animateSpring(
                from: NSValue(cgPoint: CGPoint(x: actionsPositionDeltaXDistance, y: actionsPositionDeltaYDistance)),
                to: NSValue(cgPoint: CGPoint()),
                keyPath: "position",
                duration: duration,
                delay: 0.0,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            if let reactionContextNode = self.reactionContextNode {
                let reactionsPositionDeltaYDistance = -animationInContentYDistance
                reactionContextNode.layer.animateSpring(
                    from: NSValue(cgPoint: CGPoint(x: 0.0, y: reactionsPositionDeltaYDistance)),
                    to: NSValue(cgPoint: CGPoint()),
                    keyPath: "position",
                    duration: duration,
                    delay: 0.0,
                    initialVelocity: 0.0,
                    damping: springDamping,
                    additive: true
                )
                reactionContextNode.animateIn(from: currentContentScreenFrame)
            }
            
            self.actionsStackNode.animateIn()
            
            if let contentNode = itemContentNode {
                contentNode.containingItem.isExtractedToContextPreview = true
                contentNode.containingItem.isExtractedToContextPreviewUpdated?(true)
                contentNode.containingItem.willUpdateIsExtractedToContextPreview?(true, transition)
                
                contentNode.containingItem.layoutUpdated = { [weak self] _, animation in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if let _ = strongSelf.animatingOutState {
                    } else {
                        strongSelf.requestUpdate(animation.transition)
                    }
                }
            }
            
            if let overlayViews = self.getController()?.getOverlayViews?(), !overlayViews.isEmpty {
                for view in overlayViews {
                    if let snapshotView = view.snapshotView(afterScreenUpdates: false) {
                        snapshotView.frame = view.convert(view.bounds, to: nil)
                        self.view.addSubview(snapshotView)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                }
            }
        case let .animateOut(result, completion):
            let actionsSize = self.actionsContainerNode.bounds.size
            
            let duration: Double
            let timingFunction: String
            switch result {
            case .default, .dismissWithoutContent:
                duration = self.reactionContextNodeIsAnimatingOut ? 0.25 : 0.2
                timingFunction = CAMediaTimingFunctionName.easeInEaseOut.rawValue
            case let .custom(customTransition):
                switch customTransition {
                case let .animated(customDuration, curve):
                    duration = customDuration
                    timingFunction = curve.timingFunction
                case .immediate:
                    duration = self.reactionContextNodeIsAnimatingOut ? 0.25 : 0.2
                    timingFunction = CAMediaTimingFunctionName.easeInEaseOut.rawValue
                }
            }
            
            let currentContentScreenFrame: CGRect
                        
            switch self.source {
            case let .location(location):
                if let putBackInfo = location.transitionInfo() {
                    self.clippingNode.layer.animateFrame(from: CGRect(origin: CGPoint(), size: layout.size), to: CGRect(origin: CGPoint(x: 0.0, y: putBackInfo.contentAreaInScreenSpace.minY), size: CGSize(width: layout.size.width, height: putBackInfo.contentAreaInScreenSpace.height)), duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
                    self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: putBackInfo.contentAreaInScreenSpace.minY, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
                    
                    currentContentScreenFrame = CGRect(origin: putBackInfo.location, size: CGSize(width: 1.0, height: 1.0))
                } else {
                    return
                }
            case let .reference(source):
                if let putBackInfo = source.transitionInfo() {
                    self.clippingNode.layer.animateFrame(from: CGRect(origin: CGPoint(), size: layout.size), to: CGRect(origin: CGPoint(x: 0.0, y: putBackInfo.contentAreaInScreenSpace.minY), size: CGSize(width: layout.size.width, height: putBackInfo.contentAreaInScreenSpace.height)), duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
                    self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: putBackInfo.contentAreaInScreenSpace.minY, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
                    
                    currentContentScreenFrame = convertFrame(putBackInfo.referenceView.bounds.inset(by: putBackInfo.insets), from: putBackInfo.referenceView, to: self.view)
                } else {
                    return
                }
            case let .extracted(source):
                let putBackInfo = source.putBack()
                
                if let putBackInfo = putBackInfo {
                    self.clippingNode.layer.animateFrame(from: CGRect(origin: CGPoint(), size: layout.size), to: CGRect(origin: CGPoint(x: 0.0, y: putBackInfo.contentAreaInScreenSpace.minY), size: CGSize(width: layout.size.width, height: putBackInfo.contentAreaInScreenSpace.height)), duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
                    self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: putBackInfo.contentAreaInScreenSpace.minY, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
                }
                
                if let contentNode = itemContentNode {
                    currentContentScreenFrame = convertFrame(contentNode.containingItem.contentRect, from: contentNode.containingItem.view, to: self.view)
                    if currentContentScreenFrame.origin.x < 0.0 {
                        contentParentGlobalFrameOffsetX = layout.size.width
                    }
                } else {
                    return
                }
            case let .controller(source):
                if let putBackInfo = source.transitionInfo() {
                    let _ = putBackInfo
                    /*self.clippingNode.layer.animateFrame(from: CGRect(origin: CGPoint(), size: layout.size), to: CGRect(origin: CGPoint(x: 0.0, y: putBackInfo.contentAreaInScreenSpace.minY), size: CGSize(width: layout.size.width, height: putBackInfo.contentAreaInScreenSpace.height)), duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
                    self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: putBackInfo.contentAreaInScreenSpace.minY, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)*/
                    
                    //TODO:
                    currentContentScreenFrame = CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: 1.0))
                } else {
                    return
                }
            }
            
            self.animatingOutState = AnimatingOutState(
                currentContentScreenFrame: currentContentScreenFrame
            )
            
            let currentContentLocalFrame = convertFrame(contentRect, from: self.scrollNode.view, to: self.view)
            
            var animationInContentYDistance: CGFloat
            
            switch result {
            case .default, .custom:
                animationInContentYDistance = currentContentLocalFrame.minY - currentContentScreenFrame.minY
            case .dismissWithoutContent:
                animationInContentYDistance = 0.0
                if let contentNode = itemContentNode {
                    contentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
                }
            }
            
            let actionsVerticalTransitionDirection: CGFloat
            if let contentNode = itemContentNode {
                if contentNode.frame.minY < self.actionsContainerNode.frame.minY {
                    actionsVerticalTransitionDirection = -1.0
                } else {
                    actionsVerticalTransitionDirection = 1.0
                }
            } else {
                if contentRect.minY < self.actionsContainerNode.frame.minY {
                    actionsVerticalTransitionDirection = -1.0
                } else {
                    actionsVerticalTransitionDirection = 1.0
                }
            }
            
            var restoreOverlayViews: [() -> Void] = []
            if let overlayViews = self.getController()?.getOverlayViews?(), !overlayViews.isEmpty, let itemContentNode, let contentNodeSupernode = itemContentNode.supernode {
                for view in overlayViews {
                    let originalFrame = view.frame
                    let originalSuperview = view.superview
                    let originalIndex = view.superview?.subviews.firstIndex(of: view)
                    let originalGroupOpacity = view.layer.allowsGroupOpacity
                    
                    contentNodeSupernode.view.insertSubview(view, aboveSubview: itemContentNode.view)
                    view.frame = view.convert(view.bounds, to: contentNodeSupernode.view)
                    view.layer.allowsGroupOpacity = true
                    view.layer.animateAlpha(from: 0.0, to: view.alpha, duration: 0.2)
                    
                    restoreOverlayViews.append({
                        view.frame = originalFrame
                        view.layer.allowsGroupOpacity = originalGroupOpacity
                        if let originalIndex {
                            originalSuperview?.insertSubview(view, at: originalIndex)
                        } else {
                            originalSuperview?.addSubview(view)
                        }
                    })
                }
            }
            
            let completeWithActionStack = itemContentNode == nil && controllerContentNode == nil
            if let contentNode = itemContentNode {
                contentNode.containingItem.willUpdateIsExtractedToContextPreview?(false, transition)
                
                var animationInContentXDistance: CGFloat = 0.0
                let contentX = contentParentGlobalFrame.minX + contentRect.minX - contentNode.containingItem.contentRect.minX
                let contentWidth = contentNode.containingItem.view.bounds.size.width
                if case let .extracted(extracted) = self.source, extracted.adjustContentHorizontally {
                    let fixedContentX = self.actionsContainerNode.frame.minX
                    animationInContentXDistance = contentX - fixedContentX
                } else if case let .extracted(extracted) = self.source, extracted.centerVertically {
                    if actionsSize.height.isZero {
//                        let fixedContentY = floorToScreenPixels((layout.size.height - contentHeight) / 2.0)
                        animationInContentYDistance = 0.0 //contentY - fixedContentY
                    } else if contentX + contentWidth > layout.size.width / 2.0{
                        let fixedContentX = layout.size.width - (contentX + contentWidth)
                        animationInContentXDistance = contentX - fixedContentX
                    }
                } else {
                    animationInContentXDistance = -contentParentGlobalFrameOffsetX
                }
                
                if animationInContentXDistance != 0.0 {
                    contentNode.offsetContainerNode.layer.animate(
                        from: -animationInContentXDistance as NSNumber,
                        to: 0.0 as NSNumber,
                        keyPath: "position.x",
                        timingFunction: timingFunction,
                        duration: duration,
                        delay: 0.0,
                        additive: true
                    )
                }
                
                contentNode.offsetContainerNode.position = contentNode.offsetContainerNode.position.offsetBy(dx: animationInContentXDistance, dy: -animationInContentYDistance)
                let reactionContextNodeIsAnimatingOut = self.reactionContextNodeIsAnimatingOut
                contentNode.offsetContainerNode.layer.animate(
                    from: animationInContentYDistance as NSNumber,
                    to: 0.0 as NSNumber,
                    keyPath: "position.y",
                    timingFunction: timingFunction,
                    duration: duration,
                    delay: 0.0,
                    additive: true,
                    completion: { [weak self] _ in
                        Queue.mainQueue().after(reactionContextNodeIsAnimatingOut ? 0.2 * UIView.animationDurationFactor() : 0.0, {
                            if let strongSelf = self, let contentNode = strongSelf.itemContentNode {
                                switch contentNode.containingItem {
                                case let .node(containingNode):
                                    containingNode.addSubnode(containingNode.contentNode)
                                case let .view(containingView):
                                    containingView.addSubview(containingView.contentView)
                                }
                            }
                            
                            contentNode.containingItem.isExtractedToContextPreview = false
                            contentNode.containingItem.isExtractedToContextPreviewUpdated?(false)
                            contentNode.containingItem.onDismiss?()
                            
                            restoreOverlayViews.forEach({ $0() })
                            completion()
                        })
                    }
                )
                
                if let reactionPreviewView = self.reactionPreviewView {
                    reactionPreviewView.layer.animate(
                        from: 0.0 as NSNumber,
                        to: -animationInContentYDistance as NSNumber,
                        keyPath: "position.y",
                        timingFunction: timingFunction,
                        duration: duration,
                        delay: 0.0,
                        removeOnCompletion: true,
                        additive: true,
                        completion: { _ in
                        }
                    )
                    reactionPreviewView.layer.animate(
                        from: 1.0 as NSNumber,
                        to: 0.01 as NSNumber,
                        keyPath: "transform.scale",
                        timingFunction: timingFunction,
                        duration: duration,
                        delay: 0.0,
                        removeOnCompletion: false,
                        additive: false
                    )
                    reactionPreviewView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in })
                }
            }
            if let contentNode = controllerContentNode {
                if case let .controller(source) = self.source, let transitionInfo = source.transitionInfo(), let (sourceView, sourceRect) = transitionInfo.sourceNode() {
                    let sourcePoint = sourceView.convert(sourceRect.center, to: self.view)
                    animationInContentYDistance = contentRect.midY - sourcePoint.y
                } else {
                    animationInContentYDistance = 0.0
                }
                
                contentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.8, removeOnCompletion: false, completion: { _ in
                    restoreOverlayViews.forEach({ $0() })
                    completion()
                })
                contentNode.layer.animate(
                    from: 0.0 as NSNumber,
                    to: -animationInContentYDistance as NSNumber,
                    keyPath: "position.y",
                    timingFunction: timingFunction,
                    duration: duration,
                    delay: 0.0,
                    removeOnCompletion: false,
                    additive: true
                )
                contentNode.layer.animate(
                    from: 1.0 as NSNumber,
                    to: 0.01 as NSNumber,
                    keyPath: "transform.scale",
                    timingFunction: timingFunction,
                    duration: duration,
                    delay: 0.0,
                    removeOnCompletion: false,
                    additive: false
                )
            }
            
            self.actionsContainerNode.layer.animateAlpha(from: self.actionsContainerNode.alpha, to: 0.0, duration: duration, removeOnCompletion: false)
            self.actionsContainerNode.layer.animate(
                from: 1.0 as NSNumber,
                to: 0.01 as NSNumber,
                keyPath: "transform.scale",
                timingFunction: timingFunction,
                duration: duration,
                delay: 0.0,
                removeOnCompletion: false,
                completion: { _ in
                    if completeWithActionStack {
                        restoreOverlayViews.forEach({ $0() })
                        completion()
                    }
                }
            )
                        
            var actionsPositionDeltaXDistance: CGFloat = 0.0
            if case .center = actionsHorizontalAlignment {
                actionsPositionDeltaXDistance = currentContentScreenFrame.midX - self.actionsContainerNode.frame.midX
            }
            if case .reference = self.source {
                actionsPositionDeltaXDistance = currentContentScreenFrame.midX - self.actionsContainerNode.frame.midX
            }
            let actionsPositionDeltaYDistance = -animationInContentYDistance + actionsVerticalTransitionDirection * actionsSize.height / 2.0 - contentActionsSpacing
            self.actionsContainerNode.layer.animate(
                from: NSValue(cgPoint: CGPoint()),
                to: NSValue(cgPoint: CGPoint(x: actionsPositionDeltaXDistance, y: actionsPositionDeltaYDistance)),
                keyPath: "position",
                timingFunction: timingFunction,
                duration: duration,
                delay: 0.0,
                removeOnCompletion: false,
                additive: true
            )
            
            if let reactionContextNode = self.reactionContextNode {
                reactionContextNode.animateOut(to: currentContentScreenFrame, animatingOutToReaction: self.reactionContextNodeIsAnimatingOut)
            }
        case .none:
            if animateReactionsIn, let reactionContextNode = self.reactionContextNode {
                reactionContextNode.animateIn(from: contentRect)
            }
        }
    }
    
    func animateOutToReaction(value: MessageReaction.Reaction, targetView: UIView, hideNode: Bool, animateTargetContainer: UIView?, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, reducedCurve: Bool, onHit: (() -> Void)?, completion: @escaping () -> Void) {
        guard let reactionContextNode = self.reactionContextNode else {
            self.requestAnimateOut(.default, completion)
            return
        }

        var contentCompleted = false
        var reactionCompleted = false
        let intermediateCompletion: () -> Void = {
            if contentCompleted && reactionCompleted {
                completion()
            }
        }
        
        self.reactionContextNodeIsAnimatingOut = true
        reactionContextNode.willAnimateOutToReaction(value: value)
        
        let result: ContextMenuActionResult
        if reducedCurve {
            result = .custom(.animated(duration: 0.5, curve: .spring))
        } else {
            result = .default
        }
        
        self.requestAnimateOut(result, {
            contentCompleted = true
            intermediateCompletion()
        })
        
        reactionContextNode.animateOutToReaction(value: value, targetView: targetView, hideNode: hideNode, animateTargetContainer: animateTargetContainer, addStandaloneReactionAnimation: addStandaloneReactionAnimation, onHit: onHit, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.reactionContextNode?.removeFromSupernode()
            strongSelf.reactionContextNode = nil
            reactionCompleted = true
            intermediateCompletion()
        })
    }
    
    func cancelReactionAnimation() {
        self.reactionContextNode?.cancelReactionAnimation()
    }
    
    func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
        if self.reactionContextNodeIsAnimatingOut, let reactionContextNode = self.reactionContextNode {
            reactionContextNode.bounds = reactionContextNode.bounds.offsetBy(dx: 0.0, dy: offset.y)
            transition.animateOffsetAdditive(node: reactionContextNode, offset: -offset.y)
            
            if let itemContentNode = self.itemContentNode {
                itemContentNode.bounds = itemContentNode.bounds.offsetBy(dx: 0.0, dy: offset.y)
                transition.animateOffsetAdditive(node: itemContentNode, offset: -offset.y)
            }
        }
    }
}


