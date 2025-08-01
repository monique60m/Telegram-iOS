import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import TextFormat
import UrlEscaping
import SwiftSignalKit
import AccountContext
import AvatarNode
import TelegramPresentationData
import ChatMessageBackground
import ChatMessageDateAndStatusNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import PollBubbleTimerNode
import MergedAvatarsNode
import TextNodeWithEntities
import ShimmeringLinkNode

private final class ChatMessagePollOptionRadioNodeParameters: NSObject {
    let timestamp: Double
    let staticColor: UIColor
    let animatedColor: UIColor
    let fillColor: UIColor
    let foregroundColor: UIColor
    let offset: Double?
    let isChecked: Bool?
    let checkTransition: ChatMessagePollOptionRadioNodeCheckTransition?
    
    init(timestamp: Double, staticColor: UIColor, animatedColor: UIColor, fillColor: UIColor, foregroundColor: UIColor, offset: Double?, isChecked: Bool?, checkTransition: ChatMessagePollOptionRadioNodeCheckTransition?) {
        self.timestamp = timestamp
        self.staticColor = staticColor
        self.animatedColor = animatedColor
        self.fillColor = fillColor
        self.foregroundColor = foregroundColor
        self.offset = offset
        self.isChecked = isChecked
        self.checkTransition = checkTransition
        
        super.init()
    }
}

private final class ChatMessagePollOptionRadioNodeCheckTransition {
    let startTime: Double
    let duration: Double
    let previousValue: Bool
    let updatedValue: Bool
    
    init(startTime: Double, duration: Double, previousValue: Bool, updatedValue: Bool) {
        self.startTime = startTime
        self.duration = duration
        self.previousValue = previousValue
        self.updatedValue = updatedValue
    }
}

private final class ChatMessagePollOptionRadioNode: ASDisplayNode {
    private(set) var staticColor: UIColor?
    private(set) var animatedColor: UIColor?
    private(set) var fillColor: UIColor?
    private(set) var foregroundColor: UIColor?
    private var isInHierarchyValue: Bool = false
    private(set) var isAnimating: Bool = false
    private var startTime: Double?
    private var checkTransition: ChatMessagePollOptionRadioNodeCheckTransition?
    private(set) var isChecked: Bool?
    
    private var displayLink: ConstantDisplayLinkAnimator?
    
    private var shouldBeAnimating: Bool {
        return self.isInHierarchyValue && (self.isAnimating || self.checkTransition != nil)
    }
    
    func updateIsChecked(_ value: Bool, animated: Bool) {
        if let previousValue = self.isChecked, previousValue != value {
            self.checkTransition = ChatMessagePollOptionRadioNodeCheckTransition(startTime: CACurrentMediaTime(), duration: 0.15, previousValue: previousValue, updatedValue: value)
            self.isChecked = value
            self.updateAnimating()
            self.setNeedsDisplay()
        }
    }
    
    override init() {
        super.init()
        
        self.isUserInteractionEnabled = false
        self.isOpaque = false
    }
    
    deinit {
        self.displayLink?.isPaused = true
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        let previous = self.shouldBeAnimating
        self.isInHierarchyValue = true
        let updated = self.shouldBeAnimating
        if previous != updated {
            self.updateAnimating()
        }
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        let previous = self.shouldBeAnimating
        self.isInHierarchyValue = false
        let updated = self.shouldBeAnimating
        if previous != updated {
            self.updateAnimating()
        }
    }
    
    func update(staticColor: UIColor, animatedColor: UIColor, fillColor: UIColor, foregroundColor: UIColor, isSelectable: Bool, isAnimating: Bool) {
        var updated = false
        let shouldHaveBeenAnimating = self.shouldBeAnimating
        if !staticColor.isEqual(self.staticColor) {
            self.staticColor = staticColor
            updated = true
        }
        if !animatedColor.isEqual(self.animatedColor) {
            self.animatedColor = animatedColor
            updated = true
        }
        if !fillColor.isEqual(self.fillColor) {
            self.fillColor = fillColor
            updated = true
        }
        if !foregroundColor.isEqual(self.foregroundColor) {
            self.foregroundColor = foregroundColor
            updated = true
        }
        if isSelectable != (self.isChecked != nil) {
            if isSelectable {
                self.isChecked = false
            } else {
                self.isChecked = nil
                self.checkTransition = nil
            }
            updated = true
        }
        if isAnimating != self.isAnimating {
            self.isAnimating = isAnimating
            let updated = self.shouldBeAnimating
            if shouldHaveBeenAnimating != updated {
                self.updateAnimating()
            }
        }
        if updated {
            self.setNeedsDisplay()
        }
    }
    
    private func updateAnimating() {
        let timestamp = CACurrentMediaTime()
        if let checkTransition = self.checkTransition {
            if checkTransition.startTime + checkTransition.duration <= timestamp {
                self.checkTransition = nil
            }
        }
        
        if self.shouldBeAnimating {
            if self.isAnimating && self.startTime == nil {
                self.startTime = timestamp
            }
            if self.displayLink == nil {
                self.displayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
                    self?.updateAnimating()
                    self?.setNeedsDisplay()
                })
                self.displayLink?.isPaused = false
                self.setNeedsDisplay()
            }
        } else if let displayLink = self.displayLink {
            self.startTime = nil
            displayLink.invalidate()
            self.displayLink = nil
            self.setNeedsDisplay()
        }
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        if let staticColor = self.staticColor, let animatedColor = self.animatedColor, let fillColor = self.fillColor, let foregroundColor = self.foregroundColor {
            let timestamp = CACurrentMediaTime()
            var offset: Double?
            if let startTime = self.startTime {
                offset = CACurrentMediaTime() - startTime
            }
            return ChatMessagePollOptionRadioNodeParameters(timestamp: timestamp, staticColor: staticColor, animatedColor: animatedColor, fillColor: fillColor, foregroundColor: foregroundColor, offset: offset, isChecked: self.isChecked, checkTransition: self.checkTransition)
        } else {
            return nil
        }
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        if isCancelled() {
            return
        }
        
        guard let parameters = parameters as? ChatMessagePollOptionRadioNodeParameters else {
            return
        }
        
        let context = UIGraphicsGetCurrentContext()!
        
        if let offset = parameters.offset {
            let t = max(0.0, offset)
            let colorFadeInDuration = 0.2
            let color: UIColor
            if t < colorFadeInDuration {
                color = parameters.staticColor.mixedWith(parameters.animatedColor, alpha: CGFloat(t / colorFadeInDuration))
            } else {
                color = parameters.animatedColor
            }
            context.setStrokeColor(color.cgColor)
            
            let rotationDuration = 1.15
            let rotationProgress = CGFloat(offset.truncatingRemainder(dividingBy: rotationDuration) / rotationDuration)
            context.translateBy(x: bounds.midX, y: bounds.midY)
            context.rotate(by: rotationProgress * 2.0 * CGFloat.pi)
            context.translateBy(x: -bounds.midX, y: -bounds.midY)
            
            let fillDuration = 1.0
            if offset < fillDuration {
                let fillT = CGFloat(offset.truncatingRemainder(dividingBy: fillDuration) / fillDuration)
                let startAngle = fillT * 2.0 * CGFloat.pi - CGFloat.pi / 2.0
                let endAngle = -CGFloat.pi / 2.0
                
                let path = UIBezierPath(arcCenter: CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0), radius: (bounds.size.width - 1.0) / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                path.lineWidth = 1.0
                path.lineCapStyle = .round
                path.stroke()
            } else {
                let halfProgress: CGFloat = 0.7
                let fillPhase = 0.6
                let keepPhase = 0.0
                let finishPhase = 0.6
                let totalDuration = fillPhase + keepPhase + finishPhase
                let localOffset = (offset - fillDuration).truncatingRemainder(dividingBy: totalDuration)
                
                let angleOffsetT: CGFloat = -CGFloat(floor((offset - fillDuration) / totalDuration))
                let angleOffset = (angleOffsetT * (1.0 - halfProgress) * 2.0 * CGFloat.pi).truncatingRemainder(dividingBy: 2.0 * CGFloat.pi)
                context.translateBy(x: bounds.midX, y: bounds.midY)
                context.rotate(by: angleOffset)
                context.translateBy(x: -bounds.midX, y: -bounds.midY)
                
                if localOffset < fillPhase + keepPhase {
                    let fillT = CGFloat(min(1.0, localOffset / fillPhase))
                    let startAngle = -CGFloat.pi / 2.0
                    let endAngle = (fillT * halfProgress) * 2.0 * CGFloat.pi - CGFloat.pi / 2.0
                    
                    let path = UIBezierPath(arcCenter: CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0), radius: (bounds.size.width - 1.0) / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                    path.lineWidth = 1.0
                    path.lineCapStyle = .round
                    path.stroke()
                } else {
                    let finishT = CGFloat((localOffset - (fillPhase + keepPhase)) / finishPhase)
                    let endAngle = halfProgress * 2.0 * CGFloat.pi - CGFloat.pi / 2.0
                    let startAngle = -CGFloat.pi / 2.0 * (1.0 - finishT) + endAngle * finishT
                    
                    let path = UIBezierPath(arcCenter: CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0), radius: (bounds.size.width - 1.0) / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                    path.lineWidth = 1.0
                    path.lineCapStyle = .round
                    path.stroke()
                }
            }
        } else {
            if let isChecked = parameters.isChecked {
                let checkedT: CGFloat
                let fromValue: CGFloat
                let toValue: CGFloat
                let fromAlpha: CGFloat
                let toAlpha: CGFloat
                if let checkTransition = parameters.checkTransition {
                    checkedT = CGFloat(max(0.0, min(1.0, (parameters.timestamp - checkTransition.startTime) / checkTransition.duration)))
                    fromValue = checkTransition.previousValue ? bounds.width : 0.0
                    fromAlpha = checkTransition.previousValue ? 1.0 : 0.0
                    toValue = checkTransition.updatedValue ? bounds.width : 0.0
                    toAlpha = checkTransition.updatedValue ? 1.0 : 0.0
                } else {
                    checkedT = 1.0
                    fromValue = isChecked ? bounds.width : 0.0
                    fromAlpha = isChecked ? 1.0 : 0.0
                    toValue = isChecked ? bounds.width : 0.0
                    toAlpha = isChecked ? 1.0 : 0.0
                }
                
                let diameter = fromValue * (1.0 - checkedT) + toValue * checkedT
                let alpha = fromAlpha * (1.0 - checkedT) + toAlpha * checkedT
                
                if abs(diameter - 1.0) > CGFloat.ulpOfOne {
                    context.setStrokeColor(parameters.staticColor.cgColor)
                    context.strokeEllipse(in: CGRect(origin: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: bounds.width - 1.0, height: bounds.height - 1.0)))
                }
                
                if !diameter.isZero {
                    context.setFillColor(parameters.fillColor.withAlphaComponent(alpha).cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: (bounds.width - diameter) / 2.0, y: (bounds.width - diameter) / 2.0), size: CGSize(width: diameter, height: diameter)))
                    
                    context.setLineWidth(1.5)
                    context.setLineJoin(.round)
                    context.setLineCap(.round)
                    
                    context.setStrokeColor(parameters.foregroundColor.withAlphaComponent(alpha).cgColor)
                    if parameters.foregroundColor.alpha.isZero {
                        context.setBlendMode(.clear)
                    }
                    let startPoint = CGPoint(x: 6.0, y: 12.13)
                    let centerPoint = CGPoint(x: 9.28, y: 15.37)
                    let endPoint = CGPoint(x: 16.0, y: 8.0)
                    
                    let pathStartT: CGFloat = 0.15
                    let pathT = max(0.0, (alpha - pathStartT) / (1.0 - pathStartT))
                    let pathMiddleT: CGFloat = 0.4
                    
                    context.move(to: startPoint)
                    if pathT >= pathMiddleT {
                        context.addLine(to: centerPoint)
                        
                        let pathEndT = (pathT - pathMiddleT) / (1.0 - pathMiddleT)
                        if pathEndT >= 1.0 {
                            context.addLine(to: endPoint)
                        } else {
                            context.addLine(to: CGPoint(x: (1.0 - pathEndT) * centerPoint.x + pathEndT * endPoint.x, y: (1.0 - pathEndT) * centerPoint.y + pathEndT * endPoint.y))
                        }
                    } else {
                        context.addLine(to: CGPoint(x: (1.0 - pathT) * startPoint.x + pathT * centerPoint.x, y: (1.0 - pathT) * startPoint.y + pathT * centerPoint.y))
                    }
                    context.strokePath()
                    context.setBlendMode(.normal)
                }
            } else {
                context.setStrokeColor(parameters.staticColor.cgColor)
                context.strokeEllipse(in: CGRect(origin: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: bounds.width - 1.0, height: bounds.height - 1.0)))
            }
        }
    }
}

private let percentageFont = Font.bold(14.5)
private let percentageSmallFont = Font.bold(12.5)

private func generatePercentageImage(presentationData: ChatPresentationData, incoming: Bool, value: Int, targetValue: Int) -> UIImage {
    return generateImage(CGSize(width: 42.0, height: 20.0), rotatedContext: { size, context in
        UIGraphicsPushContext(context)
        context.clear(CGRect(origin: CGPoint(), size: size))
        let font: UIFont
        if targetValue == 100 {
            font = percentageSmallFont
        } else {
            font = percentageFont
        }
        let string = NSAttributedString(string: "\(value)%", font: font, textColor: incoming ? presentationData.theme.theme.chat.message.incoming.primaryTextColor : presentationData.theme.theme.chat.message.outgoing.primaryTextColor, paragraphAlignment: .right)
        string.draw(in: CGRect(origin: CGPoint(x: 0.0, y: targetValue == 100 ? 3.0 : 2.0), size: size))
        UIGraphicsPopContext()
    })!
}

private func generatePercentageAnimationImages(presentationData: ChatPresentationData, incoming: Bool, from fromValue: Int, to toValue: Int, duration: Double) -> [UIImage] {
    let minimumFrameDuration = 1.0 / 40.0
    let numberOfFrames = max(1, Int(duration / minimumFrameDuration))
    var images: [UIImage] = []
    for i in 0 ..< numberOfFrames {
        let t = CGFloat(i) / CGFloat(numberOfFrames)
        images.append(generatePercentageImage(presentationData: presentationData, incoming: incoming, value: Int((1.0 - t) * CGFloat(fromValue) + t * CGFloat(toValue)), targetValue: toValue))
    }
    return images
}

private struct ChatMessagePollOptionResult: Equatable {
    let normalized: CGFloat
    let percent: Int
    let count: Int32
}

private struct ChatMessagePollOptionSelection: Equatable {
    var isSelected: Bool
    var isCorrect: Bool
}

private final class ChatMessagePollOptionNode: ASDisplayNode {
    private let highlightedBackgroundNode: ASDisplayNode
    private(set) var radioNode: ChatMessagePollOptionRadioNode?
    private let percentageNode: ASDisplayNode
    private var percentageImage: UIImage?
    fileprivate var titleNode: TextNodeWithEntities?
    private let buttonNode: HighlightTrackingButtonNode
    let separatorNode: ASDisplayNode
    private let resultBarNode: ASImageNode
    private let resultBarIconNode: ASImageNode
    var option: TelegramMediaPollOption?
    private(set) var currentResult: ChatMessagePollOptionResult?
    private(set) var currentSelection: ChatMessagePollOptionSelection?
    var pressed: (() -> Void)?
    var selectionUpdated: (() -> Void)?
    private var theme: PresentationTheme?
    
    weak var previousOptionNode: ChatMessagePollOptionNode?
    
    var visibilityRect: CGRect? {
        didSet {
            if self.visibilityRect != oldValue {
                if let titleNode = self.titleNode {
                    if let visibilityRect = self.visibilityRect {
                        titleNode.visibilityRect = visibilityRect.offsetBy(dx: 0.0, dy: titleNode.textNode.frame.minY)
                    } else {
                        titleNode.visibilityRect = nil
                    }
                }
            }
        }
    }
    
    override init() {
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.alpha = 0.0
        self.highlightedBackgroundNode.isUserInteractionEnabled = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.resultBarNode = ASImageNode()
        self.resultBarNode.isLayerBacked = true
        self.resultBarNode.alpha = 0.0
        
        self.resultBarIconNode = ASImageNode()
        self.resultBarIconNode.isLayerBacked = true
        
        self.percentageNode = ASDisplayNode()
        self.percentageNode.alpha = 0.0
        self.percentageNode.isLayerBacked = true
        
        super.init()
                
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.resultBarNode)
        self.addSubnode(self.resultBarIconNode)
        self.addSubnode(self.percentageNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    if let theme = strongSelf.theme, theme.overallDarkAppearance, let contentNode = strongSelf.supernode as? ChatMessagePollBubbleContentNode, let backdropNode = contentNode.bubbleBackgroundNode?.backdropNode {
                        strongSelf.highlightedBackgroundNode.layer.compositingFilter = "overlayBlendMode"
                        strongSelf.highlightedBackgroundNode.frame = strongSelf.view.convert(strongSelf.highlightedBackgroundNode.frame, to: backdropNode.view)
                        backdropNode.addSubnode(strongSelf.highlightedBackgroundNode)
                    } else {
                        strongSelf.insertSubnode(strongSelf.highlightedBackgroundNode, at: 0)
                    }
                    
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                    
                    strongSelf.separatorNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.separatorNode.alpha = 0.0
                    
                    strongSelf.previousOptionNode?.separatorNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.previousOptionNode?.separatorNode.alpha = 0.0
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, completion: { finished in
                        if finished && strongSelf.highlightedBackgroundNode.supernode != strongSelf {
                            strongSelf.highlightedBackgroundNode.layer.compositingFilter = nil
                            strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: strongSelf.highlightedBackgroundNode.frame.size)
                            strongSelf.insertSubnode(strongSelf.highlightedBackgroundNode, at: 0)
                        }
                    })
                    
                    strongSelf.separatorNode.alpha = 1.0
                    strongSelf.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    
                    strongSelf.previousOptionNode?.separatorNode.alpha = 1.0
                    strongSelf.previousOptionNode?.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                }
            }
        }
    }
    
    @objc private func buttonPressed() {
        if let radioNode = self.radioNode, let isChecked = radioNode.isChecked {
            radioNode.updateIsChecked(!isChecked, animated: true)
            self.selectionUpdated?()
        } else {
            self.pressed?()
        }
    }
    
    static func asyncLayout(_ maybeNode: ChatMessagePollOptionNode?) -> (_ context: AccountContext, _ presentationData: ChatPresentationData, _ message: Message, _ poll: TelegramMediaPoll, _ option: TelegramMediaPollOption, _ translation: TranslationMessageAttribute.Additional?, _ optionResult: ChatMessagePollOptionResult?, _ constrainedWidth: CGFloat) -> (minimumWidth: CGFloat, layout: ((CGFloat) -> (CGSize, (Bool, Bool, Bool) -> ChatMessagePollOptionNode))) {
        let makeTitleLayout = TextNodeWithEntities.asyncLayout(maybeNode?.titleNode)
        let currentResult = maybeNode?.currentResult
        let currentSelection = maybeNode?.currentSelection
        let currentTheme = maybeNode?.theme
        
        return { context, presentationData, message, poll, option, translation, optionResult, constrainedWidth in
            let leftInset: CGFloat = 50.0
            let rightInset: CGFloat = 12.0
            
            let incoming = message.effectivelyIncoming(context.account.peerId)
            
            var optionText = option.text
            var optionEntities = option.entities
            if let translation {
                optionText = translation.text
                optionEntities = translation.entities
            }
            
            let optionTextColor: UIColor = incoming ? presentationData.theme.theme.chat.message.incoming.primaryTextColor : presentationData.theme.theme.chat.message.outgoing.primaryTextColor
            let optionAttributedText = stringWithAppliedEntities(
                optionText,
                entities: optionEntities,
                baseColor: optionTextColor,
                linkColor: optionTextColor,
                baseFont: presentationData.messageFont,
                linkFont: presentationData.messageFont,
                boldFont: presentationData.messageFont,
                italicFont: presentationData.messageFont,
                boldItalicFont: presentationData.messageFont,
                fixedFont: presentationData.messageFont,
                blockQuoteFont: presentationData.messageFont,
                message: message
            )
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: optionAttributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: max(1.0, constrainedWidth - leftInset - rightInset), height: CGFloat.greatestFiniteMagnitude), alignment: .left, cutout: nil, insets: UIEdgeInsets(top: 1.0, left: 0.0, bottom: 1.0, right: 0.0)))
            
            let contentHeight: CGFloat = max(46.0, titleLayout.size.height + 22.0)
            
            let shouldHaveRadioNode = optionResult == nil
            let isSelectable: Bool
            if shouldHaveRadioNode, case .poll(multipleAnswers: true) = poll.kind, !Namespaces.Message.allNonRegular.contains(message.id.namespace) {
                isSelectable = true
            } else {
                isSelectable = false
            }
            
            let themeUpdated = presentationData.theme.theme !== currentTheme
            
            var updatedPercentageImage: UIImage?
            if currentResult != optionResult || themeUpdated {
                let value = optionResult?.percent ?? 0
                updatedPercentageImage = generatePercentageImage(presentationData: presentationData, incoming: incoming, value: value, targetValue: value)
            }
            
            var resultIcon: UIImage?
            var updatedResultIcon = false
            
            var selection: ChatMessagePollOptionSelection?
            if optionResult != nil {
                if let voters = poll.results.voters {
                    for voter in voters {
                        if voter.opaqueIdentifier == option.opaqueIdentifier {
                            if voter.selected || voter.isCorrect {
                                selection = ChatMessagePollOptionSelection(isSelected: voter.selected, isCorrect: voter.isCorrect)
                            }
                            break
                        }
                    }
                }
            }
            if selection != currentSelection || themeUpdated {
                updatedResultIcon = true
                if let selection = selection {
                    var isQuiz = false
                    if case .quiz = poll.kind {
                        isQuiz = true
                    }
                    resultIcon = generateImage(CGSize(width: 16.0, height: 16.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        var isIncorrect = false
                        let fillColor: UIColor
                        if selection.isSelected {
                            if isQuiz {
                                if selection.isCorrect {
                                    fillColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.barPositive : presentationData.theme.theme.chat.message.outgoing.polls.barPositive
                                } else {
                                    fillColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.barNegative : presentationData.theme.theme.chat.message.outgoing.polls.barNegative
                                    isIncorrect = true
                                }
                            } else {
                                fillColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.bar : presentationData.theme.theme.chat.message.outgoing.polls.bar
                            }
                        } else if isQuiz && selection.isCorrect {
                            fillColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.bar : presentationData.theme.theme.chat.message.outgoing.polls.bar
                        } else {
                            fillColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.bar : presentationData.theme.theme.chat.message.outgoing.polls.bar
                        }
                        context.setFillColor(fillColor.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                        
                        let strokeColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.barIconForeground : presentationData.theme.theme.chat.message.outgoing.polls.barIconForeground
                        if strokeColor.alpha.isZero {
                            context.setBlendMode(.copy)
                        }
                        context.setStrokeColor(strokeColor.cgColor)
                        context.setLineWidth(1.5)
                        context.setLineJoin(.round)
                        context.setLineCap(.round)
                        if isIncorrect {
                            context.translateBy(x: 5.0, y: 5.0)
                            context.move(to: CGPoint(x: 0.0, y: 6.0))
                            context.addLine(to: CGPoint(x: 6.0, y: 0.0))
                            context.strokePath()
                            context.move(to: CGPoint(x: 0.0, y: 0.0))
                            context.addLine(to: CGPoint(x: 6.0, y: 6.0))
                            context.strokePath()
                        } else {
                            let _ = try? drawSvgPath(context, path: "M4,8.5 L6.44778395,10.9477839 C6.47662208,10.9766221 6.52452135,10.9754786 6.54754782,10.9524522 L12,5.5 S ")
                        }
                    })
                }
            }
            
            return (titleLayout.size.width + leftInset + rightInset, { width in
                return (CGSize(width: width, height: contentHeight), { animated, inProgress, attemptSynchronous in
                    let node: ChatMessagePollOptionNode
                    if let maybeNode = maybeNode {
                        node = maybeNode
                    } else {
                        node = ChatMessagePollOptionNode()
                    }
                    
                    node.option = option
                    let previousResult = node.currentResult
                    node.currentResult = optionResult
                    node.currentSelection = selection
                    node.theme = presentationData.theme.theme
                    
                    node.highlightedBackgroundNode.backgroundColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.highlight : presentationData.theme.theme.chat.message.outgoing.polls.highlight
                    
                    node.buttonNode.accessibilityLabel = option.text
                    
                    if animated {
                        if let titleNode = node.titleNode, let cachedLayout = titleNode.textNode.cachedLayout {
                            if !cachedLayout.areLinesEqual(to: titleLayout) {
                                if let textContents = titleNode.textNode.contents {
                                    let fadeNode = ASDisplayNode()
                                    fadeNode.displaysAsynchronously = false
                                    fadeNode.contents = textContents
                                    fadeNode.frame = titleNode.textNode.frame
                                    fadeNode.isLayerBacked = true
                                    node.addSubnode(fadeNode)
                                    fadeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak fadeNode] _ in
                                        fadeNode?.removeFromSupernode()
                                    })
                                    titleNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                }
                            }
                        }
                    }
                    
                    let titleNode = titleApply(TextNodeWithEntities.Arguments(
                        context: context,
                        cache: context.animationCache,
                        renderer: context.animationRenderer,
                        placeholderColor: incoming ? presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor : presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor,
                        attemptSynchronous: attemptSynchronous
                    ))
                    let titleNodeFrame: CGRect
                    if titleLayout.hasRTL {
                        titleNodeFrame = CGRect(origin: CGPoint(x: width - rightInset - titleLayout.size.width, y: 11.0), size: titleLayout.size)
                    } else {
                        titleNodeFrame = CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: titleLayout.size)
                    }
                    if node.titleNode !== titleNode {
                        node.titleNode = titleNode
                        node.addSubnode(titleNode.textNode)
                        titleNode.textNode.isUserInteractionEnabled = false
                        
                        if let visibilityRect = node.visibilityRect {
                            titleNode.visibilityRect = visibilityRect.offsetBy(dx: 0.0, dy: titleNodeFrame.minY)
                        }
                    }
                    titleNode.textNode.frame = titleNodeFrame
                    
                    if shouldHaveRadioNode {
                        let radioNode: ChatMessagePollOptionRadioNode
                        if let current = node.radioNode {
                            radioNode = current
                        } else {
                            radioNode = ChatMessagePollOptionRadioNode()
                            node.addSubnode(radioNode)
                            node.radioNode = radioNode
                            if animated {
                                radioNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            }
                        }
                        let radioSize: CGFloat = 22.0
                        radioNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 12.0), size: CGSize(width: radioSize, height: radioSize))
                        radioNode.update(staticColor: incoming ? presentationData.theme.theme.chat.message.incoming.polls.radioButton : presentationData.theme.theme.chat.message.outgoing.polls.radioButton, animatedColor: incoming ? presentationData.theme.theme.chat.message.incoming.polls.radioProgress : presentationData.theme.theme.chat.message.outgoing.polls.radioProgress, fillColor: incoming ? presentationData.theme.theme.chat.message.incoming.polls.bar : presentationData.theme.theme.chat.message.outgoing.polls.bar, foregroundColor: incoming ? presentationData.theme.theme.chat.message.incoming.polls.barIconForeground : presentationData.theme.theme.chat.message.outgoing.polls.barIconForeground, isSelectable: isSelectable, isAnimating: inProgress)
                    } else if let radioNode = node.radioNode {
                        node.radioNode = nil
                        if animated {
                            radioNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak radioNode] _ in
                                radioNode?.removeFromSupernode()
                            })
                        } else {
                            radioNode.removeFromSupernode()
                        }
                    }
                    
                    if let updatedPercentageImage = updatedPercentageImage {
                        node.percentageNode.contents = updatedPercentageImage.cgImage
                        node.percentageImage = updatedPercentageImage
                    }
                    if let image = node.percentageImage {
                        node.percentageNode.frame = CGRect(origin: CGPoint(x: leftInset - 7.0 - image.size.width, y: 12.0), size: image.size)
                        if animated && previousResult?.percent != optionResult?.percent {
                            let percentageDuration = 0.27
                            let images = generatePercentageAnimationImages(presentationData: presentationData, incoming: incoming, from: previousResult?.percent ?? 0, to: optionResult?.percent ?? 0, duration: percentageDuration)
                            if !images.isEmpty {
                                let animation = CAKeyframeAnimation(keyPath: "contents")
                                animation.values = images.map { $0.cgImage! }
                                animation.duration = percentageDuration * UIView.animationDurationFactor()
                                animation.calculationMode = .discrete
                                node.percentageNode.layer.add(animation, forKey: "image")
                            }
                        }
                    }
                    
                    node.buttonNode.frame = CGRect(origin: CGPoint(x: 1.0, y: 0.0), size: CGSize(width: width - 2.0, height: contentHeight))
                    if node.highlightedBackgroundNode.supernode == node {
                        node.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: contentHeight + UIScreenPixel))
                    }
                    node.separatorNode.backgroundColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.separator : presentationData.theme.theme.chat.message.outgoing.polls.separator
                    node.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentHeight - UIScreenPixel), size: CGSize(width: width - leftInset, height: UIScreenPixel))
                    
                    if node.resultBarNode.image == nil || updatedResultIcon {
                        var isQuiz = false
                        if case .quiz = poll.kind {
                            isQuiz = true
                        }
                        let fillColor: UIColor
                        if let selection = selection {
                            if selection.isSelected {
                                if isQuiz {
                                    if selection.isCorrect {
                                        fillColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.barPositive : presentationData.theme.theme.chat.message.outgoing.polls.barPositive
                                    } else {
                                        fillColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.barNegative : presentationData.theme.theme.chat.message.outgoing.polls.barNegative
                                    }
                                } else {
                                    fillColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.bar : presentationData.theme.theme.chat.message.outgoing.polls.bar
                                }
                            } else if isQuiz && selection.isCorrect {
                                fillColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.bar : presentationData.theme.theme.chat.message.outgoing.polls.bar
                            } else {
                                fillColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.bar : presentationData.theme.theme.chat.message.outgoing.polls.bar
                            }
                        } else {
                            fillColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.bar : presentationData.theme.theme.chat.message.outgoing.polls.bar
                        }
                        
                        node.resultBarNode.image = generateStretchableFilledCircleImage(diameter: 6.0, color: fillColor)
                    }
                    
                    if updatedResultIcon {
                        node.resultBarIconNode.image = resultIcon
                    }
                    
                    let minBarWidth: CGFloat = 6.0
                    let resultBarWidth = minBarWidth + floor((width - leftInset - rightInset - minBarWidth) * (optionResult?.normalized ?? 0.0))
                    let barFrame = CGRect(origin: CGPoint(x: leftInset, y: contentHeight - 6.0 - 1.0), size: CGSize(width: resultBarWidth, height: 6.0))
                    node.resultBarNode.frame = barFrame
                    node.resultBarIconNode.frame = CGRect(origin: CGPoint(x: barFrame.minX - 6.0 - 16.0, y: barFrame.minY + floor((barFrame.height - 16.0) / 2.0)), size: CGSize(width: 16.0, height: 16.0))
                    node.resultBarNode.alpha = optionResult != nil ? 1.0 : 0.0
                    node.percentageNode.alpha = optionResult != nil ? 1.0 : 0.0
                    node.separatorNode.alpha = optionResult == nil ? 1.0 : 0.0
                    node.resultBarIconNode.alpha = optionResult != nil ? 1.0 : 0.0
                    if animated, currentResult != optionResult {
                        if (currentResult != nil) != (optionResult != nil) {
                            if optionResult != nil {
                                node.resultBarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                                node.percentageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                node.separatorNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.08)
                                node.resultBarIconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            } else {
                                node.resultBarNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.4)
                                node.percentageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                                node.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                node.resultBarIconNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                            }
                        }
                        
                        node.buttonNode.isAccessibilityElement = shouldHaveRadioNode
                        
                        let previousResultBarWidth = minBarWidth + floor((width - leftInset - rightInset - minBarWidth) * (currentResult?.normalized ?? 0.0))
                        let previousFrame = CGRect(origin: CGPoint(x: leftInset, y: contentHeight - 6.0 - 1.0), size: CGSize(width: previousResultBarWidth, height: 6.0))
                        
                        node.resultBarNode.layer.animateSpring(from: NSValue(cgPoint: previousFrame.center), to: NSValue(cgPoint: node.resultBarNode.frame.center), keyPath: "position", duration: 0.6, damping: 110.0)
                        node.resultBarNode.layer.animateSpring(from: NSValue(cgRect: CGRect(origin: CGPoint(), size: previousFrame.size)), to: NSValue(cgRect: CGRect(origin: CGPoint(), size: node.resultBarNode.frame.size)), keyPath: "bounds", duration: 0.6, damping: 110.0)
                    }
                    
                    return node
                })
            })
        }
    }
}

private let labelsFont = Font.regular(14.0)

private final class SolutionButtonNode: HighlightableButtonNode {
    private let pressed: () -> Void
    let iconNode: ASImageNode
    
    private var theme: PresentationTheme?
    private var incoming: Bool?
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.iconNode)
        
        self.addTarget(self, action: #selector(self.pressedEvent), forControlEvents: .touchUpInside)
    }
    
    @objc private func pressedEvent() {
        self.pressed()
    }
    
    func update(size: CGSize, theme: PresentationTheme, incoming: Bool) {
        if self.theme !== theme || self.incoming != incoming {
            self.theme = theme
            self.incoming = incoming
            self.iconNode.image = PresentationResourcesChat.chatBubbleLamp(theme, incoming: incoming)
        }
        
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
        }
    }
}

public class ChatMessagePollBubbleContentNode: ChatMessageBubbleContentNode {
    private let textNode: TextNodeWithEntities
    private let typeNode: TextNode
    private var timerNode: PollBubbleTimerNode?
    private let solutionButtonNode: SolutionButtonNode
    private let avatarsNode: MergedAvatarsNode
    private let votersNode: TextNode
    private let buttonSubmitInactiveTextNode: TextNode
    private let buttonSubmitActiveTextNode: TextNode
    private let buttonViewResultsTextNode: TextNode
    private let buttonNode: HighlightableButtonNode
    private let statusNode: ChatMessageDateAndStatusNode
    private var optionNodes: [ChatMessagePollOptionNode] = []
    private var shimmeringNodes: [ShimmeringLinkNode] = []
    
    private var poll: TelegramMediaPoll?
    
    public var solutionTipSourceNode: ASDisplayNode {
        return self.solutionButtonNode
    }
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            if oldValue != self.visibility {
                switch self.visibility {
                case .none:
                    self.textNode.visibilityRect = nil
                    for optionNode in self.optionNodes {
                        optionNode.visibilityRect = nil
                    }
                case let .visible(_, subRect):
                    var subRect = subRect
                    subRect.origin.x = 0.0
                    subRect.size.width = 10000.0
                    self.textNode.visibilityRect = subRect.offsetBy(dx: 0.0, dy: -self.textNode.textNode.frame.minY)
                    for optionNode in self.optionNodes {
                        optionNode.visibilityRect = subRect.offsetBy(dx: 0.0, dy: -optionNode.frame.minY)
                    }
                }
            }
        }
    }
    
    required public init() {
        self.textNode = TextNodeWithEntities()
        self.textNode.textNode.isUserInteractionEnabled = false
        self.textNode.textNode.contentMode = .topLeft
        self.textNode.textNode.contentsScale = UIScreenScale
        self.textNode.textNode.displaysAsynchronously = false
        
        self.typeNode = TextNode()
        self.typeNode.isUserInteractionEnabled = false
        self.typeNode.contentMode = .topLeft
        self.typeNode.contentsScale = UIScreenScale
        self.typeNode.displaysAsynchronously = false
        
        self.avatarsNode = MergedAvatarsNode()
        
        self.votersNode = TextNode()
        self.votersNode.isUserInteractionEnabled = false
        self.votersNode.contentMode = .topLeft
        self.votersNode.contentsScale = UIScreenScale
        self.votersNode.displaysAsynchronously = false
        self.votersNode.clipsToBounds = true
        
        var displaySolution: (() -> Void)?
        self.solutionButtonNode = SolutionButtonNode(pressed: {
            displaySolution?()
        })
        self.solutionButtonNode.alpha = 0.0
        
        self.buttonSubmitInactiveTextNode = TextNode()
        self.buttonSubmitInactiveTextNode.isUserInteractionEnabled = false
        self.buttonSubmitInactiveTextNode.contentMode = .topLeft
        self.buttonSubmitInactiveTextNode.contentsScale = UIScreenScale
        self.buttonSubmitInactiveTextNode.displaysAsynchronously = false
        
        self.buttonSubmitActiveTextNode = TextNode()
        self.buttonSubmitActiveTextNode.isUserInteractionEnabled = false
        self.buttonSubmitActiveTextNode.contentMode = .topLeft
        self.buttonSubmitActiveTextNode.contentsScale = UIScreenScale
        self.buttonSubmitActiveTextNode.displaysAsynchronously = false
        
        self.buttonViewResultsTextNode = TextNode()
        self.buttonViewResultsTextNode.isUserInteractionEnabled = false
        self.buttonViewResultsTextNode.contentMode = .topLeft
        self.buttonViewResultsTextNode.contentsScale = UIScreenScale
        self.buttonViewResultsTextNode.displaysAsynchronously = false
        
        self.buttonNode = HighlightableButtonNode()
        
        self.statusNode = ChatMessageDateAndStatusNode()
        
        super.init()
        
        self.addSubnode(self.textNode.textNode)
        self.addSubnode(self.typeNode)
        self.addSubnode(self.avatarsNode)
        self.addSubnode(self.votersNode)
        self.addSubnode(self.solutionButtonNode)
        self.addSubnode(self.buttonSubmitInactiveTextNode)
        self.addSubnode(self.buttonSubmitActiveTextNode)
        self.addSubnode(self.buttonViewResultsTextNode)
        self.addSubnode(self.buttonNode)
        
        displaySolution = { [weak self] in
            guard let strongSelf = self, let item = strongSelf.item, let poll = strongSelf.poll, let solution = poll.results.solution else {
                return
            }
            item.controllerInteraction.displayPollSolution(solution, strongSelf.solutionButtonNode)
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonSubmitActiveTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonSubmitActiveTextNode.alpha = 0.6
                    strongSelf.buttonViewResultsTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonViewResultsTextNode.alpha = 0.6
                } else {
                    strongSelf.buttonSubmitActiveTextNode.alpha = 1.0
                    strongSelf.buttonSubmitActiveTextNode.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.3)
                    strongSelf.buttonViewResultsTextNode.alpha = 1.0
                    strongSelf.buttonViewResultsTextNode.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.3)
                }
            }
        }
        
        self.avatarsNode.pressed = { [weak self] in
            self?.buttonPressed()
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func buttonPressed() {
        guard let item = self.item, let poll = self.poll, let pollId = poll.id else {
            return
        }
        
        var hasSelection = false
        var selectedOpaqueIdentifiers: [Data] = []
        for optionNode in self.optionNodes {
            if let option = optionNode.option {
                if let isChecked = optionNode.radioNode?.isChecked {
                    hasSelection = true
                    if isChecked {
                        selectedOpaqueIdentifiers.append(option.opaqueIdentifier)
                    }
                }
            }
        }
        if !hasSelection {
            if !Namespaces.Message.allNonRegular.contains(item.message.id.namespace) {
                item.controllerInteraction.requestOpenMessagePollResults(item.message.id, pollId)
            }
        } else if !selectedOpaqueIdentifiers.isEmpty {
            item.controllerInteraction.requestSelectMessagePollOptions(item.message.id, selectedOpaqueIdentifiers)
        }
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeTextLayout = TextNodeWithEntities.asyncLayout(self.textNode)
        let makeTypeLayout = TextNode.asyncLayout(self.typeNode)
        let makeVotersLayout = TextNode.asyncLayout(self.votersNode)
        let makeSubmitInactiveTextLayout = TextNode.asyncLayout(self.buttonSubmitInactiveTextNode)
        let makeSubmitActiveTextLayout = TextNode.asyncLayout(self.buttonSubmitActiveTextNode)
        let makeViewResultsTextLayout = TextNode.asyncLayout(self.buttonViewResultsTextNode)
        let statusLayout = self.statusNode.asyncLayout()
        
        var previousPoll: TelegramMediaPoll?
        if let item = self.item {
            for media in item.message.media {
                if let media = media as? TelegramMediaPoll {
                    previousPoll = media
                }
            }
        }
        
        var previousOptionNodeLayouts: [Data: (_ contet: AccountContext, _ presentationData: ChatPresentationData, _ message: Message, _ poll: TelegramMediaPoll, _ option: TelegramMediaPollOption, _ translation: TranslationMessageAttribute.Additional?, _ optionResult: ChatMessagePollOptionResult?, _ constrainedWidth: CGFloat) -> (minimumWidth: CGFloat, layout: ((CGFloat) -> (CGSize, (Bool, Bool, Bool) -> ChatMessagePollOptionNode)))] = [:]
        for optionNode in self.optionNodes {
            if let option = optionNode.option {
                previousOptionNodeLayouts[option.opaqueIdentifier] = ChatMessagePollOptionNode.asyncLayout(optionNode)
            }
        }
        
        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let message = item.message
                
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                var isBotChat: Bool = false
                if let peer = item.message.peers[item.message.id.peerId] as? TelegramUser, peer.botInfo != nil {
                    isBotChat = true
                }
                
                let additionalTextRightInset: CGFloat = 24.0
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                let textConstrainedSize = CGSize(width: constrainedSize.width - horizontalInset - additionalTextRightInset, height: constrainedSize.height)
                
                var edited = false
                if item.attributes.updatingMedia != nil {
                    edited = true
                }
                var viewCount: Int?
                var dateReplies = 0
                var starsCount: Int64?
                var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeerId: item.context.account.peerId, accountPeer: item.associatedData.accountPeer, message: item.message)
                if item.message.isRestricted(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) {
                    dateReactionsAndPeers = ([], [])
                }
                for attribute in item.message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                        if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .group = channel.info {
                            dateReplies = Int(attribute.count)
                        }
                    } else if let attribute = attribute as? PaidStarsMessageAttribute, item.message.id.peerId.namespace == Namespaces.Peer.CloudChannel {
                        starsCount = attribute.stars.value
                    }
                }
                
                let dateFormat: MessageTimestampStatusFormat
                if item.presentationData.isPreview {
                    dateFormat = .full
                } else {
                    dateFormat = .regular
                }
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: dateFormat, associatedData: item.associatedData)
                
                let statusType: ChatMessageDateAndStatusType?
                if case .customChatContents = item.associatedData.subject {
                    statusType = nil
                } else {
                    switch position {
                    case .linear(_, .None), .linear(_, .Neighbour(true, _, _)):
                        if incoming {
                            statusType = .BubbleIncoming
                        } else {
                            if message.flags.contains(.Failed) {
                                statusType = .BubbleOutgoing(.Failed)
                            } else if (message.flags.isSending && !message.isSentOrAcknowledged) || item.attributes.updatingMedia != nil {
                                statusType = .BubbleOutgoing(.Sending)
                            } else {
                                statusType = .BubbleOutgoing(.Sent(read: item.read))
                            }
                        }
                    default:
                        statusType = nil
                    }
                }
                    
                var statusSuggestedWidthAndContinue: (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))?
                
                if let statusType = statusType {
                    var isReplyThread = false
                    if case .replyThread = item.chatLocation {
                        isReplyThread = true
                    }
                    
                    statusSuggestedWidthAndContinue = statusLayout(ChatMessageDateAndStatusNode.Arguments(
                        context: item.context,
                        presentationData: item.presentationData,
                        edited: edited,
                        impressionCount: viewCount,
                        dateText: dateText,
                        type: statusType,
                        layoutInput: .trailingContent(contentWidth: 1000.0, reactionSettings: shouldDisplayInlineDateReactions(message: item.message, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions) ? ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: true, preferAdditionalInset: false) : nil),
                        constrainedSize: textConstrainedSize,
                        availableReactions: item.associatedData.availableReactions,
                        savedMessageTags: item.associatedData.savedMessageTags,
                        reactions: dateReactionsAndPeers.reactions,
                        reactionPeers: dateReactionsAndPeers.peers,
                        displayAllReactionPeers: item.message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                        areReactionsTags: item.topMessage.areReactionsTags(accountPeerId: item.context.account.peerId),
                        areStarReactionsEnabled: item.associatedData.areStarReactionsEnabled,
                        messageEffect: item.topMessage.messageEffect(availableMessageEffects: item.associatedData.availableMessageEffects),
                        replyCount: dateReplies,
                        starsCount: starsCount,
                        isPinned: item.message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && !isReplyThread,
                        hasAutoremove: item.message.isSelfExpiring,
                        canViewReactionList: canViewMessageReactionList(message: item.topMessage),
                        animationCache: item.controllerInteraction.presentationContext.animationCache,
                        animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                    ))
                }
                
                var poll: TelegramMediaPoll?
                for media in item.message.media {
                    if let media = media as? TelegramMediaPoll {
                        poll = media
                        break
                    }
                }

                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                
                
                var pollTitleText = poll?.text ?? ""
                var pollTitleEntities = poll?.textEntities ?? []
                var pollOptions: [TranslationMessageAttribute.Additional] = []
                
                var isTranslating = false
                if let poll, let translateToLanguage = item.associatedData.translateToLanguage, !poll.text.isEmpty && incoming {
                    isTranslating = true
                    for attribute in item.message.attributes {
                        if let attribute = attribute as? TranslationMessageAttribute, !attribute.text.isEmpty, attribute.toLang == translateToLanguage {
                            pollTitleText = attribute.text
                            pollTitleEntities = attribute.entities
                            pollOptions = attribute.additional
                            isTranslating = false
                            break
                        }
                    }
                }
                
                let attributedText = stringWithAppliedEntities(
                    pollTitleText,
                    entities: pollTitleEntities,
                    baseColor: messageTheme.primaryTextColor,
                    linkColor: messageTheme.linkTextColor,
                    baseFont: item.presentationData.messageBoldFont,
                    linkFont: item.presentationData.messageBoldFont,
                    boldFont: item.presentationData.messageBoldFont,
                    italicFont: item.presentationData.messageBoldFont,
                    boldItalicFont: item.presentationData.messageBoldFont,
                    fixedFont: item.presentationData.messageBoldFont,
                    blockQuoteFont: item.presentationData.messageBoldFont,
                    message: message
                )
                
                let textInsets = UIEdgeInsets(top: 2.0, left: 0.0, bottom: 5.0, right: 0.0)
                
                let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets))
                let typeText: String
                
                var avatarPeers: [Peer] = []
                if let poll = poll {
                    for peerId in poll.results.recentVoters {
                        if let peer = item.message.peers[peerId] {
                            avatarPeers.append(peer)
                        }
                    }
                }
                
                if let poll = poll, isPollEffectivelyClosed(message: message, poll: poll) {
                    typeText = item.presentationData.strings.MessagePoll_LabelClosed
                } else if let poll = poll {
                    switch poll.kind {
                    case .poll:
                        switch poll.publicity {
                        case .anonymous:
                            typeText = item.presentationData.strings.MessagePoll_LabelAnonymous
                        case .public:
                            typeText = item.presentationData.strings.MessagePoll_LabelPoll
                        }
                    case .quiz:
                        switch poll.publicity {
                        case .anonymous:
                            typeText = item.presentationData.strings.MessagePoll_LabelAnonymousQuiz
                        case .public:
                            typeText = item.presentationData.strings.MessagePoll_LabelQuiz
                        }
                    }
                } else {
                    typeText = item.presentationData.strings.MessagePoll_LabelAnonymous
                }
                let (typeLayout, typeApply) = makeTypeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: typeText, font: labelsFont, textColor: messageTheme.secondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let votersString: String?
                
                if isBotChat {
                    votersString = nil
                } else if let poll = poll, let totalVoters = poll.results.totalVoters {
                    switch poll.kind {
                    case .poll:
                        if totalVoters == 0 {
                            votersString = item.presentationData.strings.MessagePoll_NoVotes
                        } else {
                            votersString = item.presentationData.strings.MessagePoll_VotedCount(totalVoters)
                        }
                    case .quiz:
                        if totalVoters == 0 {
                            votersString = item.presentationData.strings.MessagePoll_QuizNoUsers
                        } else {
                            votersString = item.presentationData.strings.MessagePoll_QuizCount(totalVoters)
                        }
                    }
                } else {
                    votersString = " "
                }
                let (votersLayout, votersApply) = makeVotersLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: votersString ?? "", font: labelsFont, textColor: messageTheme.secondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets))
                
                let (buttonSubmitInactiveTextLayout, buttonSubmitInactiveTextApply) = makeSubmitInactiveTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.MessagePoll_SubmitVote, font: Font.regular(17.0), textColor: messageTheme.accentControlDisabledColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets))
                let (buttonSubmitActiveTextLayout, buttonSubmitActiveTextApply) = makeSubmitActiveTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.MessagePoll_SubmitVote, font: Font.regular(17.0), textColor: messageTheme.polls.bar), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets))
                let (buttonViewResultsTextLayout, buttonViewResultsTextApply) = makeViewResultsTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.MessagePoll_ViewResults, font: Font.regular(17.0), textColor: messageTheme.polls.bar), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets))
                
                var textFrame = CGRect(origin: CGPoint(x: -textInsets.left, y: -textInsets.top), size: textLayout.size)
                var textFrameWithoutInsets = CGRect(origin: CGPoint(x: textFrame.origin.x + textInsets.left, y: textFrame.origin.y + textInsets.top), size: CGSize(width: textFrame.width - textInsets.left - textInsets.right, height: textFrame.height - textInsets.top - textInsets.bottom))
                
                textFrame = textFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                textFrameWithoutInsets = textFrameWithoutInsets.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                
                var boundingSize: CGSize = textFrameWithoutInsets.size
                boundingSize.width += additionalTextRightInset
                boundingSize.width = max(boundingSize.width, typeLayout.size.width)
                boundingSize.width = max(boundingSize.width, votersLayout.size.width + 4.0/* + (statusSize?.width ?? 0.0)*/)
                boundingSize.width = max(boundingSize.width, buttonSubmitInactiveTextLayout.size.width + 4.0/* + (statusSize?.width ?? 0.0)*/)
                boundingSize.width = max(boundingSize.width, buttonViewResultsTextLayout.size.width + 4.0/* + (statusSize?.width ?? 0.0)*/)
                
                if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                    boundingSize.width = max(boundingSize.width, statusSuggestedWidthAndContinue.0)
                }
                
                boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                boundingSize.height += layoutConstants.text.bubbleInsets.top + layoutConstants.text.bubbleInsets.bottom
                
                let isClosed: Bool
                if let poll = poll {
                    isClosed = isPollEffectivelyClosed(message: message, poll: poll)
                } else {
                    isClosed = false
                }
                
                var pollOptionsFinalizeLayouts: [(CGFloat) -> (CGSize, (Bool, Bool, Bool) -> ChatMessagePollOptionNode)] = []
                if let poll = poll {
                    var optionVoterCount: [Int: Int32] = [:]
                    var maxOptionVoterCount: Int32 = 0
                    var totalVoterCount: Int32 = 0
                    let voters: [TelegramMediaPollOptionVoters]?
                    if isClosed {
                        voters = poll.results.voters ?? []
                    } else {
                        voters = poll.results.voters
                    }
                    if let voters = voters, let totalVoters = poll.results.totalVoters {
                        var didVote = false
                        for voter in voters {
                            if voter.selected {
                                didVote = true
                            }
                        }
                        totalVoterCount = totalVoters
                        if didVote || isClosed {
                            for i in 0 ..< poll.options.count {
                                inner: for optionVoters in voters {
                                    if optionVoters.opaqueIdentifier == poll.options[i].opaqueIdentifier {
                                        optionVoterCount[i] = optionVoters.count
                                        maxOptionVoterCount = max(maxOptionVoterCount, optionVoters.count)
                                        break inner
                                    }
                                }
                            }
                        }
                    }
                    
                    var optionVoterCounts: [Int]
                    if totalVoterCount != 0 {
                        optionVoterCounts = countNicePercent(votes: (0 ..< poll.options.count).map({ Int(optionVoterCount[$0] ?? 0) }), total: Int(totalVoterCount))
                    } else {
                        optionVoterCounts = Array(repeating: 0, count: poll.options.count)
                    }
                    
                    for i in 0 ..< poll.options.count {
                        let option = poll.options[i]
                        
                        let makeLayout: (_ context: AccountContext, _ presentationData: ChatPresentationData, _ message: Message, _ poll: TelegramMediaPoll, _ option: TelegramMediaPollOption, _ translation: TranslationMessageAttribute.Additional?, _ optionResult: ChatMessagePollOptionResult?, _ constrainedWidth: CGFloat) -> (minimumWidth: CGFloat, layout: ((CGFloat) -> (CGSize, (Bool, Bool, Bool) -> ChatMessagePollOptionNode)))
                        if let previous = previousOptionNodeLayouts[option.opaqueIdentifier] {
                            makeLayout = previous
                        } else {
                            makeLayout = ChatMessagePollOptionNode.asyncLayout(nil)
                        }
                        var optionResult: ChatMessagePollOptionResult?
                        if let count = optionVoterCount[i] {
                            if maxOptionVoterCount != 0 && totalVoterCount != 0 {
                                optionResult = ChatMessagePollOptionResult(normalized: CGFloat(count) / CGFloat(maxOptionVoterCount), percent: optionVoterCounts[i], count: count)
                            } else if isClosed {
                                optionResult = ChatMessagePollOptionResult(normalized: 0, percent: 0, count: 0)
                            }
                        } else if isClosed {
                            optionResult = ChatMessagePollOptionResult(normalized: 0, percent: 0, count: 0)
                        }
                        
                        var translation: TranslationMessageAttribute.Additional?
                        if !pollOptions.isEmpty && i < pollOptions.count {
                            translation = pollOptions[i]
                        }
                        
                        let result = makeLayout(item.context, item.presentationData, item.message, poll, option, translation, optionResult, constrainedSize.width - layoutConstants.bubble.borderInset * 2.0)
                        boundingSize.width = max(boundingSize.width, result.minimumWidth + layoutConstants.bubble.borderInset * 2.0)
                        pollOptionsFinalizeLayouts.append(result.1)
                    }
                }
                
                boundingSize.width = max(boundingSize.width, min(270.0, constrainedSize.width))
                
                var canVote = false
                if (item.message.id.namespace == Namespaces.Message.Cloud || Namespaces.Message.allNonRegular.contains(item.message.id.namespace)), let poll = poll, poll.pollId.namespace == Namespaces.Media.CloudPoll, !isClosed {
                    var hasVoted = false
                    if let voters = poll.results.voters {
                        for voter in voters {
                            if voter.selected {
                                hasVoted = true
                                break
                            }
                        }
                    }
                    if !hasVoted {
                        canVote = true
                    }
                }
                
                return (boundingSize.width, { boundingWidth in
                    var resultSize = CGSize(width: max(boundingSize.width, boundingWidth), height: boundingSize.height)
                    
                    let titleTypeSpacing: CGFloat = -4.0
                    let typeOptionsSpacing: CGFloat = 3.0
                    resultSize.height += titleTypeSpacing + typeLayout.size.height + typeOptionsSpacing
                    
                    var optionNodesSizesAndApply: [(CGSize, (Bool, Bool, Bool) -> ChatMessagePollOptionNode)] = []
                    for finalizeLayout in pollOptionsFinalizeLayouts {
                        let result = finalizeLayout(boundingWidth - layoutConstants.bubble.borderInset * 2.0)
                        resultSize.width = max(resultSize.width, result.0.width + layoutConstants.bubble.borderInset * 2.0)
                        resultSize.height += result.0.height
                        optionNodesSizesAndApply.append(result)
                    }
                    
                    let optionsVotersSpacing: CGFloat = 11.0
                    let optionsButtonSpacing: CGFloat = 9.0
                    let votersBottomSpacing: CGFloat = 11.0
                    if votersString != nil {
                        resultSize.height += optionsVotersSpacing + votersLayout.size.height + votersBottomSpacing
                    } else {
                        resultSize.height += 26.0
                    }
                    
                    var statusSizeAndApply: (CGSize, (ListViewItemUpdateAnimation) -> Void)?
                    if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                        statusSizeAndApply = statusSuggestedWidthAndContinue.1(boundingWidth)
                    }
                    
                    if let statusSizeAndApply = statusSizeAndApply {
                        resultSize.height += statusSizeAndApply.0.height - 6.0
                    }
                    
                    let buttonSubmitInactiveTextFrame = CGRect(origin: CGPoint(x: floor((resultSize.width - buttonSubmitInactiveTextLayout.size.width) / 2.0), y: optionsButtonSpacing), size: buttonSubmitInactiveTextLayout.size)
                    let buttonSubmitActiveTextFrame = CGRect(origin: CGPoint(x: floor((resultSize.width - buttonSubmitActiveTextLayout.size.width) / 2.0), y: optionsButtonSpacing), size: buttonSubmitActiveTextLayout.size)
                    let buttonViewResultsTextFrame = CGRect(origin: CGPoint(x: floor((resultSize.width - buttonViewResultsTextLayout.size.width) / 2.0), y: optionsButtonSpacing), size: buttonViewResultsTextLayout.size)
                    
                    return (resultSize, { [weak self] animation, synchronousLoad, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.poll = poll
                            
                            let cachedLayout = strongSelf.textNode.textNode.cachedLayout
                            if case .System = animation {
                                if let cachedLayout = cachedLayout {
                                    if !cachedLayout.areLinesEqual(to: textLayout) {
                                        if let textContents = strongSelf.textNode.textNode.contents {
                                            let fadeNode = ASDisplayNode()
                                            fadeNode.displaysAsynchronously = false
                                            fadeNode.contents = textContents
                                            fadeNode.frame = strongSelf.textNode.textNode.frame
                                            fadeNode.isLayerBacked = true
                                            strongSelf.addSubnode(fadeNode)
                                            fadeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak fadeNode] _ in
                                                fadeNode?.removeFromSupernode()
                                            })
                                            strongSelf.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                        }
                                    }
                                }
                            }
                            
                            let _ = textApply(TextNodeWithEntities.Arguments(
                                context: item.context,
                                cache: item.context.animationCache,
                                renderer: item.context.animationRenderer,
                                placeholderColor: incoming ? item.presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor : item.presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor,
                                attemptSynchronous: synchronousLoad)
                            )
                            let _ = typeApply()
                            
                            var verticalOffset = textFrame.maxY + titleTypeSpacing + typeLayout.size.height + typeOptionsSpacing
                            var updatedOptionNodes: [ChatMessagePollOptionNode] = []
                            for i in 0 ..< optionNodesSizesAndApply.count {
                                let (size, apply) = optionNodesSizesAndApply[i]
                                var isRequesting = false
                                if let poll = poll, i < poll.options.count {
                                    if let inProgressOpaqueIds = item.controllerInteraction.pollActionState.pollMessageIdsInProgress[item.message.id] {
                                        isRequesting = inProgressOpaqueIds.contains(poll.options[i].opaqueIdentifier)
                                    }
                                }
                                let optionNode = apply(animation.isAnimated, isRequesting, synchronousLoad)
                                let optionNodeFrame = CGRect(origin: CGPoint(x: layoutConstants.bubble.borderInset, y: verticalOffset), size: size)
                                if optionNode.supernode !== strongSelf {
                                    strongSelf.addSubnode(optionNode)
                                    let option = optionNode.option
                                    optionNode.pressed = {
                                        guard let strongSelf = self, let item = strongSelf.item, let option = option else {
                                            return
                                        }
                                        
                                        item.controllerInteraction.requestSelectMessagePollOptions(item.message.id, [option.opaqueIdentifier])
                                    }
                                    optionNode.selectionUpdated = {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        strongSelf.updateSelection()
                                    }
                                    optionNode.frame = optionNodeFrame
                                } else {
                                    animation.animator.updateFrame(layer: optionNode.layer, frame: optionNodeFrame, completion: nil)
                                }
                                
                                verticalOffset += size.height
                                updatedOptionNodes.append(optionNode)
                                optionNode.isUserInteractionEnabled = canVote && item.controllerInteraction.pollActionState.pollMessageIdsInProgress[item.message.id] == nil
                                
                                if i > 0 {
                                    optionNode.previousOptionNode = updatedOptionNodes[i - 1]
                                }
                            }
                            for optionNode in strongSelf.optionNodes {
                                if !updatedOptionNodes.contains(where: { $0 === optionNode }) {
                                    optionNode.removeFromSupernode()
                                }
                            }
                            strongSelf.optionNodes = updatedOptionNodes
                            
                            if textLayout.hasRTL {
                                strongSelf.textNode.textNode.frame = CGRect(origin: CGPoint(x: resultSize.width - textFrame.size.width - textInsets.left - layoutConstants.text.bubbleInsets.right - additionalTextRightInset, y: textFrame.origin.y), size: textFrame.size)
                            } else {
                                strongSelf.textNode.textNode.frame = textFrame
                            }
                            let typeFrame = CGRect(origin: CGPoint(x: textFrame.minX, y: textFrame.maxY + titleTypeSpacing), size: typeLayout.size)
                            animation.animator.updateFrame(layer: strongSelf.typeNode.layer, frame: typeFrame, completion: nil)
                            
                            let deadlineTimeout = poll?.deadlineTimeout
                            var displayDeadline = true
                            var hasSelected = false
                            
                            if let poll = poll {
                                if let voters = poll.results.voters {
                                    for voter in voters {
                                        if voter.selected {
                                            displayDeadline = false
                                            hasSelected = true
                                            break
                                        }
                                    }
                                }
                            }
                            
                            if let deadlineTimeout = deadlineTimeout, !isClosed {
                                var endDate: Int32?
                                
                                if message.id.namespace == Namespaces.Message.Cloud {
                                    let startDate: Int32
                                    if let forwardInfo = message.forwardInfo {
                                        startDate = forwardInfo.date
                                    } else {
                                        startDate = message.timestamp
                                    }
                                    endDate = startDate + deadlineTimeout
                                }
                                
                                let timerNode: PollBubbleTimerNode
                                if let current = strongSelf.timerNode {
                                    timerNode = current
                                    let timerTransition: ContainedViewLayoutTransition
                                    if animation.isAnimated {
                                        timerTransition = .animated(duration: 0.25, curve: .easeInOut)
                                    } else {
                                        timerTransition = .immediate
                                    }
                                    if displayDeadline {
                                        timerTransition.updateAlpha(node: timerNode, alpha: 1.0)
                                    } else {
                                        timerTransition.updateAlpha(node: timerNode, alpha: 0.0)
                                    }
                                } else {
                                    timerNode = PollBubbleTimerNode()
                                    strongSelf.timerNode = timerNode
                                    strongSelf.addSubnode(timerNode)
                                    timerNode.reachedTimeout = {
                                        guard let strongSelf = self, let _ = strongSelf.item else {
                                            return
                                        }
                                        //item.controllerInteraction.requestMessageUpdate(item.message.id)
                                    }
                                    
                                    let timerTransition: ContainedViewLayoutTransition
                                    if animation.isAnimated {
                                        timerTransition = .animated(duration: 0.25, curve: .easeInOut)
                                    } else {
                                        timerTransition = .immediate
                                    }
                                    if displayDeadline {
                                        timerNode.alpha = 0.0
                                        timerTransition.updateAlpha(node: timerNode, alpha: 1.0)
                                    } else {
                                        timerNode.alpha = 0.0
                                    }
                                }
                                timerNode.update(regularColor: messageTheme.secondaryTextColor, proximityColor: messageTheme.scamColor, timeout: deadlineTimeout, deadlineTimestamp: endDate)
                                timerNode.frame = CGRect(origin: CGPoint(x: resultSize.width - layoutConstants.text.bubbleInsets.right, y: typeFrame.minY), size: CGSize())
                            } else if let timerNode = strongSelf.timerNode {
                                strongSelf.timerNode = nil
                                
                                let timerTransition: ContainedViewLayoutTransition
                                if animation.isAnimated {
                                    timerTransition = .animated(duration: 0.25, curve: .easeInOut)
                                } else {
                                    timerTransition = .immediate
                                }
                                timerTransition.updateAlpha(node: timerNode, alpha: 0.0, completion: { [weak timerNode] _ in
                                    timerNode?.removeFromSupernode()
                                })
                                timerTransition.updateTransformScale(node: timerNode, scale: 0.1)
                            }
                            
                            let solutionButtonSize = CGSize(width: 32.0, height: 32.0)
                            let solutionButtonFrame = CGRect(origin: CGPoint(x: resultSize.width - layoutConstants.text.bubbleInsets.right - solutionButtonSize.width + 5.0, y: typeFrame.minY - 16.0), size: solutionButtonSize)
                            strongSelf.solutionButtonNode.frame = solutionButtonFrame
                            
                            if (strongSelf.timerNode == nil || !displayDeadline), let poll = poll, case .quiz = poll.kind, let _ = poll.results.solution, (isClosed || hasSelected) {
                                if strongSelf.solutionButtonNode.alpha.isZero {
                                    let timerTransition: ContainedViewLayoutTransition
                                    if animation.isAnimated {
                                        timerTransition = .animated(duration: 0.25, curve: .easeInOut)
                                    } else {
                                        timerTransition = .immediate
                                    }
                                    timerTransition.updateAlpha(node: strongSelf.solutionButtonNode, alpha: 1.0)
                                }
                                strongSelf.solutionButtonNode.update(size: solutionButtonSize, theme: item.presentationData.theme.theme, incoming: incoming)
                            } else if !strongSelf.solutionButtonNode.alpha.isZero {
                                let timerTransition: ContainedViewLayoutTransition
                                if animation.isAnimated {
                                    timerTransition = .animated(duration: 0.25, curve: .easeInOut)
                                } else {
                                    timerTransition = .immediate
                                }
                                timerTransition.updateAlpha(node: strongSelf.solutionButtonNode, alpha: 0.0)
                            }
                            
                            let avatarsFrame = CGRect(origin: CGPoint(x: typeFrame.maxX + 6.0, y: typeFrame.minY + floor((typeFrame.height - MergedAvatarsNode.defaultMergedImageSize) / 2.0)), size: CGSize(width: MergedAvatarsNode.defaultMergedImageSize + MergedAvatarsNode.defaultMergedImageSpacing * 2.0, height: MergedAvatarsNode.defaultMergedImageSize))
                            strongSelf.avatarsNode.frame = avatarsFrame
                            strongSelf.avatarsNode.updateLayout(size: avatarsFrame.size)
                            strongSelf.avatarsNode.update(context: item.context, peers: avatarPeers, synchronousLoad: synchronousLoad, imageSize: MergedAvatarsNode.defaultMergedImageSize, imageSpacing: MergedAvatarsNode.defaultMergedImageSpacing, borderWidth: MergedAvatarsNode.defaultBorderWidth)
                            strongSelf.avatarsNode.isHidden = isBotChat
                            let alphaTransition: ContainedViewLayoutTransition
                            if animation.isAnimated {
                                alphaTransition = .animated(duration: 0.25, curve: .easeInOut)
                                alphaTransition.updateAlpha(node: strongSelf.avatarsNode, alpha: avatarPeers.isEmpty ? 0.0 : 1.0)
                            } else {
                                alphaTransition = .immediate
                            }
                            
                            let _ = votersApply()
                            let votersFrame = CGRect(origin: CGPoint(x: floor((resultSize.width - votersLayout.size.width) / 2.0), y: verticalOffset + optionsVotersSpacing), size: votersLayout.size)
                            animation.animator.updateFrame(layer: strongSelf.votersNode.layer, frame: votersFrame, completion: nil)
                            
                            if animation.isAnimated, let previousPoll = previousPoll, let poll = poll {
                                if previousPoll.results.totalVoters == nil && poll.results.totalVoters != nil {
                                    strongSelf.votersNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                                }
                            }
                            
                            if let statusSizeAndApply = statusSizeAndApply {
                                let statusFrame = CGRect(origin: CGPoint(x: resultSize.width - statusSizeAndApply.0.width - layoutConstants.text.bubbleInsets.right, y: votersFrame.maxY), size: statusSizeAndApply.0)
                                
                                if strongSelf.statusNode.supernode == nil {
                                    statusSizeAndApply.1(.None)
                                    strongSelf.statusNode.frame = statusFrame
                                    strongSelf.addSubnode(strongSelf.statusNode)
                                } else {
                                    statusSizeAndApply.1(animation)
                                    animation.animator.updateFrame(layer: strongSelf.statusNode.layer, frame: statusFrame, completion: nil)
                                }
                            } else if strongSelf.statusNode.supernode != nil {
                                strongSelf.statusNode.removeFromSupernode()
                            }
                            
                            let _ = buttonSubmitInactiveTextApply()
                            strongSelf.buttonSubmitInactiveTextNode.frame = buttonSubmitInactiveTextFrame.offsetBy(dx: 0.0, dy: verticalOffset)
                            
                            let _ = buttonSubmitActiveTextApply()
                            strongSelf.buttonSubmitActiveTextNode.frame = buttonSubmitActiveTextFrame.offsetBy(dx: 0.0, dy: verticalOffset)
                            
                            let _ = buttonViewResultsTextApply()
                            strongSelf.buttonViewResultsTextNode.frame = buttonViewResultsTextFrame.offsetBy(dx: 0.0, dy: verticalOffset)
                            
                            strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: CGSize(width: resultSize.width, height: 44.0))
                            
                            strongSelf.updateSelection()
                            strongSelf.updatePollTooltipMessageState(animated: false)
                            
                            strongSelf.updateIsTranslating(isTranslating)
                        }
                    })
                })
            })
        }
    }
    
    private func updateIsTranslating(_ isTranslating: Bool) {
        guard let item = self.item else {
            return
        }
        var rects: [[CGRect]] = []
        let titleRects = (self.textNode.textNode.rangeRects(in: NSRange(location: 0, length: self.textNode.textNode.cachedLayout?.attributedString?.length ?? 0))?.rects ?? []).map { self.textNode.textNode.view.convert($0, to: self.view) }
        rects.append(titleRects)
        
        for optionNode in self.optionNodes {
            if let titleNode = optionNode.titleNode {
                let optionRects = (titleNode.textNode.rangeRects(in: NSRange(location: 0, length: titleNode.textNode.cachedLayout?.attributedString?.length ?? 0))?.rects ?? []).map { titleNode.textNode.view.convert($0, to: self.view) }
                rects.append(optionRects)
            }
        }
        
        if isTranslating, !rects.isEmpty {
            if self.shimmeringNodes.isEmpty {
                for rects in rects {
                    let shimmeringNode = ShimmeringLinkNode(color: item.message.effectivelyIncoming(item.context.account.peerId) ? item.presentationData.theme.theme.chat.message.incoming.secondaryTextColor.withAlphaComponent(0.1) : item.presentationData.theme.theme.chat.message.outgoing.secondaryTextColor.withAlphaComponent(0.1))
                    shimmeringNode.updateRects(rects)
                    shimmeringNode.frame = self.bounds
                    shimmeringNode.updateLayout(self.bounds.size)
                    shimmeringNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.shimmeringNodes.append(shimmeringNode)
                    self.insertSubnode(shimmeringNode, belowSubnode: self.textNode.textNode)
                }
            }
        } else if !self.shimmeringNodes.isEmpty {
            let shimmeringNodes = self.shimmeringNodes
            self.shimmeringNodes = []
            
            for shimmeringNode in shimmeringNodes {
                shimmeringNode.alpha = 0.0
                shimmeringNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak shimmeringNode] _ in
                    shimmeringNode?.removeFromSupernode()
                })
            }
        }
    }
    
    private func updateSelection() {
        guard let item = self.item, let poll = self.poll else {
            return
        }
        
        var isBotChat: Bool = false
        if let peer = item.message.peers[item.message.id.peerId] as? TelegramUser, peer.botInfo != nil {
            isBotChat = true
        }
        
        let disableAllActions = false
        
        var hasSelection = false
        switch poll.kind {
        case .poll(true):
            hasSelection = true
        default:
            break
        }
        
        var hasSelectedOptions = false
        for optionNode in self.optionNodes {
            if let isChecked = optionNode.radioNode?.isChecked {
                if isChecked {
                    hasSelectedOptions = true
                }
            }
        }
        
        let isClosed = isPollEffectivelyClosed(message: item.message, poll: poll)
        
        var hasResults = false
        if isClosed {
            hasResults = true
            hasSelection = false
            if let totalVoters = poll.results.totalVoters, totalVoters == 0 {
                hasResults = false
            }
        } else {
            if let totalVoters = poll.results.totalVoters, totalVoters != 0 {
                if let voters = poll.results.voters {
                    for voter in voters {
                        if voter.selected {
                            hasResults = true
                            break
                        }
                    }
                }
            }
        }
        
        if !disableAllActions && hasSelection && !hasResults && poll.pollId.namespace == Namespaces.Media.CloudPoll {
            self.votersNode.isHidden = true
            self.buttonViewResultsTextNode.isHidden = true
            self.buttonSubmitInactiveTextNode.isHidden = hasSelectedOptions
            self.buttonSubmitActiveTextNode.isHidden = !hasSelectedOptions
            self.buttonNode.isHidden = !hasSelectedOptions
            self.buttonNode.isUserInteractionEnabled = true
        } else {
            if case .public = poll.publicity, hasResults, !disableAllActions {
                self.votersNode.isHidden = true
                
                if isBotChat {
                    self.buttonViewResultsTextNode.isHidden = true
                    self.buttonNode.isHidden = true
                } else {
                    self.buttonViewResultsTextNode.isHidden = false
                    self.buttonNode.isHidden = false
                }
                
                if Namespaces.Message.allNonRegular.contains(item.message.id.namespace) {
                    self.buttonNode.isUserInteractionEnabled = false
                } else {
                    self.buttonNode.isUserInteractionEnabled = true
                }
            } else {
                self.votersNode.isHidden = false
                self.buttonViewResultsTextNode.isHidden = true
                self.buttonNode.isHidden = true
                self.buttonNode.isUserInteractionEnabled = true
            }
            self.buttonSubmitInactiveTextNode.isHidden = true
            self.buttonSubmitActiveTextNode.isHidden = true
        }
        
        self.avatarsNode.isUserInteractionEnabled = !self.buttonViewResultsTextNode.isHidden
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.textNode.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        let textNodeFrame = self.textNode.textNode.frame
        if let (index, attributes) = self.textNode.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = self.textNode.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: url, concealed: concealed)))
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return ChatMessageBubbleContentTapAction(content: .peerMention(peerId: peerMention.peerId, mention: peerMention.mention, openProfile: false))
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return ChatMessageBubbleContentTapAction(content: .textMention(peerName))
            } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return ChatMessageBubbleContentTapAction(content: .botCommand(botCommand))
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return ChatMessageBubbleContentTapAction(content: .hashtag(hashtag.peerName, hashtag.hashtag))
            } else {
                return ChatMessageBubbleContentTapAction(content: .none)
            }
        } else {
            var isBotChat: Bool = false
            if let item = self.item, let peer = item.message.peers[item.message.id.peerId] as? TelegramUser, peer.botInfo != nil {
                isBotChat = true
            }
            
            for optionNode in self.optionNodes {
                if optionNode.frame.contains(point), case .tap = gesture {
                    if optionNode.isUserInteractionEnabled {
                        return ChatMessageBubbleContentTapAction(content: .ignore)
                    } else if let result = optionNode.currentResult, let item = self.item, !Namespaces.Message.allNonRegular.contains(item.message.id.namespace), let poll = self.poll, let option = optionNode.option, !isBotChat {
                        switch poll.publicity {
                        case .anonymous:
                            let string: String
                            switch poll.kind {
                            case .poll:
                                if result.count == 0 {
                                    string = item.presentationData.strings.MessagePoll_NoVotes
                                } else {
                                    string = item.presentationData.strings.MessagePoll_VotedCount(result.count)
                                }
                            case .quiz:
                                if result.count == 0 {
                                    string = item.presentationData.strings.MessagePoll_QuizNoUsers
                                } else {
                                    string = item.presentationData.strings.MessagePoll_QuizCount(result.count)
                                }
                            }
                            return ChatMessageBubbleContentTapAction(content: .tooltip(string, optionNode, optionNode.bounds.offsetBy(dx: 0.0, dy: 10.0)))
                        case .public:
                            var hasNonZeroVoters = false
                            if let voters = poll.results.voters {
                                for voter in voters {
                                    if voter.count != 0 {
                                        hasNonZeroVoters = true
                                        break
                                    }
                                }
                            }
                            if hasNonZeroVoters {
                                if !isEstimating {
                                    return ChatMessageBubbleContentTapAction(content: .openPollResults(option.opaqueIdentifier))
                                }
                                return ChatMessageBubbleContentTapAction(content: .openMessage)
                            }
                        }
                    }
                }
            }
            if self.buttonNode.isUserInteractionEnabled, !self.buttonNode.isHidden, self.buttonNode.frame.contains(point) {
                return ChatMessageBubbleContentTapAction(content: .ignore)
            }
            if self.avatarsNode.isUserInteractionEnabled, !self.avatarsNode.isHidden, self.avatarsNode.frame.contains(point) {
                return ChatMessageBubbleContentTapAction(content: .ignore)
            }
            if self.solutionButtonNode.isUserInteractionEnabled, !self.solutionButtonNode.isHidden, !self.solutionButtonNode.alpha.isZero, self.solutionButtonNode.frame.contains(point) {
                return ChatMessageBubbleContentTapAction(content: .ignore)
            }
            return ChatMessageBubbleContentTapAction(content: .none)
        }
    }
    
    public func updatePollTooltipMessageState(animated: Bool) {
        guard let item = self.item else {
            return
        }
        let displaySolutionButton = item.message.id != item.controllerInteraction.currentPollMessageWithTooltip
        if displaySolutionButton != !self.solutionButtonNode.iconNode.alpha.isZero {
            let transition: ContainedViewLayoutTransition
            if animated {
                transition = .animated(duration: 0.25, curve: .easeInOut)
            } else {
                transition = .immediate
            }
            transition.updateAlpha(node: self.solutionButtonNode.iconNode, alpha: displaySolutionButton ? 1.0 : 0.0)
            transition.updateSublayerTransformScale(node: self.solutionButtonNode, scale: displaySolutionButton ? 1.0 : 0.1)
        }
    }
    
    override public func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if !self.statusNode.isHidden {
            return self.statusNode.reactionView(value: value)
        }
        return nil
    }
    
    override public func messageEffectTargetView() -> UIView? {
        if !self.statusNode.isHidden {
            return self.statusNode.messageEffectTargetView()
        }
        return nil
    }
}
