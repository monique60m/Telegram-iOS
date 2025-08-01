import Foundation
import UIKit
import Display
import TelegramPresentationData
import TelegramCore
import AccountContext
import ComponentFlow
import AnimatedTextComponent

public enum UndoOverlayContent {
    case removedChat(context: AccountContext, title: NSAttributedString, text: String?)
    case archivedChat(peerId: Int64, title: String, text: String, undo: Bool)
    case hidArchive(title: String, text: String, undo: Bool)
    case revealedArchive(title: String, text: String, undo: Bool)
    case succeed(text: String, timeout: Double?, customUndoText: String?)
    case info(title: String?, text: String, timeout: Double?, customUndoText: String?)
    case emoji(name: String, text: String)
    case swipeToReply(title: String, text: String)
    case actionSucceeded(title: String?, text: String, cancel: String?, destructive: Bool)
    case stickersModified(title: String, text: String, undo: Bool, info: StickerPackCollectionInfo, topItem: StickerPackItem?, context: AccountContext)
    case dice(dice: TelegramMediaDice, context: AccountContext, text: String, action: String?)
    case chatAddedToFolder(context: AccountContext, chatTitle: String, folderTitle: NSAttributedString)
    case chatRemovedFromFolder(context: AccountContext, chatTitle: String, folderTitle: NSAttributedString)
    case messagesUnpinned(title: String, text: String, undo: Bool, isHidden: Bool)
    case setProximityAlert(title: String, text: String, cancelled: Bool)
    case invitedToVoiceChat(context: AccountContext, peer: EnginePeer, title: String?, text: String, action: String?, duration: Double)
    case linkCopied(title: String?, text: String)
    case banned(text: String)
    case importedMessage(text: String)
    case audioRate(rate: CGFloat, text: String)
    case forward(savedMessages: Bool, text: String)
    case autoDelete(isOn: Bool, title: String?, text: String, customUndoText: String?)
    case gigagroupConversion(text: String)
    case linkRevoked(text: String)
    case voiceChatRecording(text: String)
    case voiceChatFlag(text: String)
    case voiceChatCanSpeak(text: String)
    case sticker(context: AccountContext, file: TelegramMediaFile, loop: Bool, title: String?, text: String, undoText: String?, customAction: (() -> Void)?)
    case customEmoji(context: AccountContext, file: TelegramMediaFile, loop: Bool, title: String?, text: String, undoText: String?, customAction: (() -> Void)?)
    case copy(text: String)
    case mediaSaved(text: String)
    case paymentSent(currencyValue: String, itemTitle: String)
    case starsSent(context: AccountContext, title: String, text: [AnimatedTextComponent.Item], hasUndo: Bool)
    case inviteRequestSent(title: String, text: String)
    case image(image: UIImage, title: String?, text: String, round: Bool, undoText: String?)
    case notificationSoundAdded(title: String, text: String, action: (() -> Void)?)
    case universal(animation: String, scale: CGFloat, colors: [String: UIColor], title: String?, text: String, customUndoText: String?, timeout: Double?)
    case universalWithEntities(context: AccountContext, animation: String, scale: CGFloat, colors: [String: UIColor], title: NSAttributedString?, text: NSAttributedString, animateEntities: Bool, customUndoText: String?, timeout: Double?)
    case universalImage(image: UIImage, size: CGSize?, title: String?, text: String, customUndoText: String?, timeout: Double?)
    case premiumPaywall(title: String?, text: String, customUndoText: String?, timeout: Double?, linkAction: ((String) -> Void)?)
    case peers(context: AccountContext, peers: [EnginePeer], title: String?, text: String, customUndoText: String?)
    case messageTagged(context: AccountContext, isSingleMessage: Bool, customEmoji: TelegramMediaFile, isBuiltinReaction: Bool, customUndoText: String?)
    case media(context: AccountContext, file: FileMediaReference, title: String?, text: String, undoText: String?, customAction: (() -> Void)?)
    case progress(progress: CGFloat, title: String, text: String, undoText: String?)
}

public enum UndoOverlayAction {
    case info
    case undo
    case commit
}

public final class UndoOverlayControllerAdditionalViewInteraction {
    public let disableTimeout: () -> Void
    public let dismiss: () -> Void
    
    public init(disableTimeout: @escaping () -> Void, dismiss: @escaping () -> Void) {
        self.disableTimeout = disableTimeout
        self.dismiss = dismiss
    }
}

public protocol UndoOverlayControllerAdditionalView: UIView {
    var interaction: UndoOverlayControllerAdditionalViewInteraction? { get set }
    
    func update(size: CGSize, transition: ContainedViewLayoutTransition)
}

public final class UndoOverlayController: ViewController {
    public enum Position {
        case top
        case bottom
    }
    
    public struct Appearance {
        public var isBlurred: Bool?
        public var sideInset: CGFloat?
        public var bottomInset: CGFloat?
        
        public init(isBlurred: Bool? = nil, sideInset: CGFloat? = nil, bottomInset: CGFloat? = nil) {
            self.isBlurred = isBlurred
            self.sideInset = sideInset
            self.bottomInset = bottomInset
        }
    }
    
    private let presentationData: PresentationData
    public var content: UndoOverlayContent {
        didSet {
            (self.displayNode as! UndoOverlayControllerNode).updateContent(self.content)
        }
    }
    private let elevatedLayout: Bool
    private let position: Position
    private let animateInAsReplacement: Bool
    private var action: (UndoOverlayAction) -> Bool
    private let additionalView: (() -> UndoOverlayControllerAdditionalView?)?
    
    private let appearance: Appearance?
    private var didPlayPresentationAnimation = false
    private var dismissed = false
    
    public var keepOnParentDismissal = false
    
    public var tag: Any?
    
    public init(presentationData: PresentationData, content: UndoOverlayContent, elevatedLayout: Bool = false, position: Position = .bottom, animateInAsReplacement: Bool = false, appearance: Appearance? = nil, action: @escaping (UndoOverlayAction) -> Bool, additionalView: (() -> UndoOverlayControllerAdditionalView?)? = nil) {
        self.presentationData = presentationData
        self.content = content
        self.elevatedLayout = elevatedLayout
        self.position = position
        self.animateInAsReplacement = animateInAsReplacement
        self.appearance = appearance
        self.action = action
        self.additionalView = additionalView
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = UndoOverlayControllerNode(presentationData: self.presentationData, content: self.content, elevatedLayout: self.elevatedLayout, placementPosition: self.position, appearance: self.appearance, additionalView: self.additionalView, action: { [weak self] value in
            return self?.action(value) ?? false
        }, dismiss: { [weak self] in
            self?.dismiss()
        })
        self.displayNodeDidLoad()
    }
    
    public func dismissWithCommitAction() {
        let _ = self.action(.commit)
        self.dismiss()
    }
    
    public func dismissWithCommitActionAndReplacementAnimation() {
        let _ = self.action(.commit)
        (self.displayNode as! UndoOverlayControllerNode).animateOutWithReplacement(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            (self.displayNode as! UndoOverlayControllerNode).animateIn(asReplacement: self.animateInAsReplacement)
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! UndoOverlayControllerNode).containerLayoutUpdated(layout: layout, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        guard !self.dismissed else {
            return
        }
        self.dismissed = true
        (self.displayNode as! UndoOverlayControllerNode).animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
}
