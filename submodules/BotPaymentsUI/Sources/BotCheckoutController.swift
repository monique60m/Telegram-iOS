import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext

public final class BotCheckoutController: ViewController {
    public final class InputData {
        public enum FetchError {
            case generic
            case disallowedStarGifts
            case starGiftsUserLimit
        }

        public let form: BotPaymentForm
        public let validatedFormInfo: BotPaymentValidatedFormInfo?
        public let botPeer: EnginePeer?

        public init(
            form: BotPaymentForm,
            validatedFormInfo: BotPaymentValidatedFormInfo?,
            botPeer: EnginePeer?
        ) {
            self.form = form
            self.validatedFormInfo = validatedFormInfo
            self.botPeer = botPeer
        }

        public static func fetch(context: AccountContext, source: BotPaymentInvoiceSource) -> Signal<InputData, FetchError> {
            let theme = context.sharedContext.currentPresentationData.with { $0 }.theme
            let themeParams: [String: Any]?
            switch source {
            case .starGift, .starGiftUpgrade:
                themeParams = nil
            default:
                themeParams = [
                    "bg_color": Int32(bitPattern: theme.list.plainBackgroundColor.rgb),
                    "secondary_bg_color": Int32(bitPattern: theme.list.blocksBackgroundColor.rgb),
                    "text_color": Int32(bitPattern: theme.list.itemPrimaryTextColor.rgb),
                    "hint_color": Int32(bitPattern: theme.list.itemSecondaryTextColor.rgb),
                    "link_color": Int32(bitPattern: theme.list.itemAccentColor.rgb),
                    "button_color": Int32(bitPattern: theme.list.itemCheckColors.fillColor.rgb),
                    "button_text_color": Int32(bitPattern: theme.list.itemCheckColors.foregroundColor.rgb),
                    "header_bg_color": Int32(bitPattern: theme.rootController.navigationBar.opaqueBackgroundColor.rgb),
                    "accent_text_color": Int32(bitPattern: theme.list.itemAccentColor.rgb),
                    "section_bg_color": Int32(bitPattern: theme.list.itemBlocksBackgroundColor.rgb),
                    "section_header_text_color": Int32(bitPattern: theme.list.freeTextColor.rgb),
                    "subtitle_text_color": Int32(bitPattern: theme.list.itemSecondaryTextColor.rgb),
                    "destructive_text_color": Int32(bitPattern: theme.list.itemDestructiveColor.rgb),
                    "section_separator_color": Int32(bitPattern: theme.list.itemBlocksSeparatorColor.rgb)
                ]
            }

            return context.engine.payments.fetchBotPaymentForm(source: source, themeParams: themeParams)
            |> mapError { error -> FetchError in
                switch error {
                case .disallowedStarGift:
                    return .disallowedStarGifts
                case .starGiftUserLimit:
                    return .starGiftsUserLimit
                default:
                    return .generic
                }
            }
            |> mapToSignal { paymentForm -> Signal<InputData, FetchError> in
                let botPeer: Signal<EnginePeer?, FetchError>
                if let paymentBotId = paymentForm.paymentBotId {
                    botPeer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: paymentBotId))
                    |> castError(FetchError.self)
                } else {
                    botPeer = .single(nil)
                }
                return botPeer
                |> mapToSignal { botPeer -> Signal<InputData, FetchError> in
                    if let current = paymentForm.savedInfo {
                        return context.engine.payments.validateBotPaymentForm(saveInfo: true, source: source, formInfo: current)
                        |> mapError { _ -> FetchError in
                            return .generic
                        }
                        |> map { result -> InputData in
                            return InputData(
                                form: paymentForm,
                                validatedFormInfo: result,
                                botPeer: botPeer
                            )
                        }
                        |> `catch` { _ -> Signal<InputData, FetchError> in
                            return .single(InputData(
                                form: paymentForm,
                                validatedFormInfo: nil,
                                botPeer: botPeer
                            ))
                        }
                    } else {
                        return .single(InputData(
                            form: paymentForm,
                            validatedFormInfo: nil,
                            botPeer: botPeer
                        ))
                    }
                }
            }
        }
    }

    private var controllerNode: BotCheckoutControllerNode {
        return self.displayNode as! BotCheckoutControllerNode
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let context: AccountContext
    private let invoice: TelegramMediaInvoice
    private let source: BotPaymentInvoiceSource
    private let completed: (String, EngineMessage.Id?) -> Void
    private let pending: () -> Void
    private let cancelled: () -> Void
    private let failed: () -> Void
    
    private var presentationData: PresentationData
    
    private var didPlayPresentationAnimation = false

    private let inputData: Promise<BotCheckoutController.InputData?>
    
    public init(context: AccountContext, invoice: TelegramMediaInvoice, source: BotPaymentInvoiceSource, inputData: Promise<BotCheckoutController.InputData?>, completed: @escaping (String, EngineMessage.Id?) -> Void, pending: @escaping () -> Void = {}, cancelled: @escaping () -> Void = {}, failed: @escaping () -> Void = {}) {
        self.context = context
        self.invoice = invoice
        self.source = source
        self.inputData = inputData
        self.completed = completed
        self.pending = pending
        self.cancelled = cancelled
        self.failed = failed
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        var title = self.presentationData.strings.Checkout_Title
        if invoice.flags.contains(.isTest) {
            title += " (Test)"
        }
        self.title = title
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        let displayNode = BotCheckoutControllerNode(controller: self, navigationBar: self.navigationBar!, context: self.context, invoice: self.invoice, source: self.source, inputData: self.inputData, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, dismissAnimated: { [weak self] in
            self?.dismiss()
        }, completed: { [weak self] currencyValue, receiptMessageId in
            self?.complete(currencyValue: currencyValue, receiptMessageId: receiptMessageId)
        })
        
        displayNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        displayNode.pending = { [weak self] in
            self?.setPending()
        }
        displayNode.failed = { [weak self] in
            self?.fail()
        }
        
        self.displayNode = displayNode
        super.displayNodeDidLoad()
        self._ready.set(displayNode.ready)
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.cancel()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.controllerNode.animateIn()
            }
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition, additionalInsets: UIEdgeInsets())
    }
    
    private var didCancel = false
    private func cancel() {
        guard !self.didCancel && !self.didFail && !self.didComplete else {
            return
        }
        self.didCancel = true
        self.cancelled()
    }
    
    private var didFail = false
    private func fail() {
        guard !self.didCancel && !self.didFail && !self.didComplete else {
            return
        }
        self.didFail = true
        self.failed()
    }
    
    private var didComplete = false
    private func complete(currencyValue: String, receiptMessageId: EngineMessage.Id?) {
        guard !self.didCancel && !self.didFail && !self.didComplete else {
            return
        }
        self.didComplete = true
        self.completed(currencyValue, receiptMessageId)
    }
    
    private var isPending = false
    private func setPending() {
        guard !self.isPending && !self.didCancel && !self.didFail && !self.didComplete else {
            return
        }
        self.pending()
    }
    
    @objc private func cancelPressed() {
        self.cancel()
        self.dismiss()
    }
}
