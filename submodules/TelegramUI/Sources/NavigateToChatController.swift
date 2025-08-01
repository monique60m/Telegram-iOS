import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import AccountContext
import GalleryUI
import InstantPageUI
import ChatListUI
import PeerAvatarGalleryUI
import SettingsUI
import ChatPresentationInterfaceState
import AttachmentUI
import ForumCreateTopicScreen
import LegacyInstantVideoController
import StoryContainerScreen
import MediaEditorScreen
import ChatControllerInteraction
import SavedMessagesScreen
import WallpaperGalleryScreen
import ChatMessageNotificationItem
import FaceScanScreen

public func navigateToChatControllerImpl(_ params: NavigateToChatControllerParams) {
    if case let .peer(peer) = params.chatLocation {
        let _ = params.context.engine.peers.ensurePeerIsLocallyAvailable(peer: peer).startStandalone()
    }
    
    var requiresAgeVerification: Signal<Bool, NoError> = .single(false)
    if !params.skipAgeVerification, case let .peer(peer) = params.chatLocation {
        requiresAgeVerification = requireAgeVerification(context: params.context, peer: peer)
    }
    
    var viewForumAsMessages: Signal<Bool, NoError> = .single(false)
    if case let .peer(peer) = params.chatLocation, case let .channel(channel) = peer, channel.flags.contains(.isMonoforum) {
        if let linkedMonoforumId = channel.linkedMonoforumId {
            viewForumAsMessages = params.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: linkedMonoforumId)
            )
            |> map { peer -> Bool in
                guard case let .channel(channel) = peer else {
                    return false
                }
                return channel.adminRights == nil
            }
        } else {
            viewForumAsMessages = .single(false)
        }
    } else if case let .peer(peer) = params.chatLocation, case let .channel(channel) = peer, channel.flags.contains(.isForum) {
        if channel.flags.contains(.displayForumAsTabs) {
            viewForumAsMessages = .single(true)
        } else {
            viewForumAsMessages = params.context.account.postbox.combinedView(keys: [.cachedPeerData(peerId: peer.id)])
            |> take(1)
            |> map { combinedView in
                guard let cachedDataView = combinedView.views[.cachedPeerData(peerId: peer.id)] as? CachedPeerDataView else {
                    return false
                }
                if let cachedData = cachedDataView.cachedPeerData as? CachedChannelData, case let .known(viewForumAsMessages) = cachedData.viewForumAsMessages, viewForumAsMessages {
                    return true
                } else {
                    return false
                }
            }
        }
    } else if case let .peer(peer) = params.chatLocation, peer.id == params.context.account.peerId {
        viewForumAsMessages = params.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.DisplaySavedChatsAsTopics()
        )
        |> map { value in
            return !value
        }
    }
    
    let _ = combineLatest(
        queue: Queue.mainQueue(),
        viewForumAsMessages |> take(1),
        requiresAgeVerification
    ).start(next: { viewForumAsMessages, requiresAgeVerification in
        if requiresAgeVerification, let parentController = params.navigationController.viewControllers.last as? ViewController {
            presentAgeVerification(context: params.context, parentController: parentController, completion: {
                navigateToChatControllerImpl(params.withSkipAgeVerification(true))
            })
            return
        }
        
        if case let .peer(peer) = params.chatLocation, case let .channel(channel) = peer, channel.flags.contains(.isForum), !viewForumAsMessages {
            for controller in params.navigationController.viewControllers.reversed() {
                var chatListController: ChatListControllerImpl?
                if let controller = controller as? ChatListControllerImpl {
                    chatListController = controller
                } else if let controller = controller as? TabBarController {
                    chatListController = controller.currentController as? ChatListControllerImpl
                }
                
                if let chatListController = chatListController {
                    var matches = false
                    if case let .forum(peerId) = chatListController.location, peer.id == peerId {
                        matches = true
                    } else if case let .savedMessagesChats(peerId) = chatListController.location, peer.id == peerId {
                        matches = true
                    } else if case let .forum(peerId) = chatListController.effectiveLocation, peer.id == peerId {
                        matches = true
                    }
                    
                    if matches {
                        let _ = params.navigationController.popToViewController(controller, animated: params.animated)
                        if let activateMessageSearch = params.activateMessageSearch {
                            chatListController.activateSearch(query: activateMessageSearch.1)
                        }
                        return
                    }
                }
            }
            
            let chatListLocation: ChatListControllerLocation
            if case let .peer(peer) = params.chatLocation, case let .channel(channel) = peer, channel.flags.contains(.isMonoforum) {
                chatListLocation = .savedMessagesChats(peerId: peer.id)
            } else {
                chatListLocation = .forum(peerId: peer.id)
            }
            
            let controller = ChatListControllerImpl(context: params.context, location: chatListLocation, controlsHistoryPreload: false, enableDebugActions: false)
            
            let activateMessageSearch = params.activateMessageSearch
            let chatListCompletion = params.chatListCompletion
            params.navigationController.pushViewController(controller, completion: { [weak controller] in
                guard let controller else {
                    return
                }
                if let activateMessageSearch {
                    controller.activateSearch(query: activateMessageSearch.1)
                }
                
                chatListCompletion(controller)
            })
            
            return
        }
        
        if !params.forceOpenChat, !viewForumAsMessages, params.subject == nil, case let .peer(peer) = params.chatLocation, peer.id == params.context.account.peerId {
            if let controller = params.context.sharedContext.makePeerInfoController(context: params.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                params.navigationController.pushViewController(controller, animated: params.animated, completion: {
                })
                return
            }
        }
        
        var found = false
        var isFirst = true
        if params.useExisting {
            for controller in params.navigationController.viewControllers.reversed() {
                guard let controller = controller as? ChatControllerImpl else {
                    isFirst = false
                    continue
                }
                
                var canMatchThread = controller.chatLocation.threadId == params.chatLocation.asChatLocation.threadId
                var switchToThread = false
                if !canMatchThread && controller.chatLocation.peerId == params.chatLocation.asChatLocation.peerId && controller.subject == nil {
                    canMatchThread = true
                    switchToThread = true
                }
                if case .replyThread = params.chatLocation {
                    if case let .replyThread(replyThread) = params.chatLocation, (replyThread.isForumPost || replyThread.isMonoforumPost) {
                    } else {
                        canMatchThread = false
                        switchToThread = false
                    }
                }
                
                if controller.chatLocation.peerId == params.chatLocation.asChatLocation.peerId && canMatchThread && (controller.subject != .scheduledMessages || controller.subject == params.subject) {
                    if let updateTextInputState = params.updateTextInputState {
                        controller.updateTextInputState(updateTextInputState)
                    }
                    var popAndComplete = true
                    if let subject = params.subject, case let .message(messageSubject, highlight, timecode, setupReply) = subject {
                        if case let .id(messageId) = messageSubject {
                            let navigationController = params.navigationController
                            let animated = params.animated
                            controller.navigateToMessage(messageLocation: .id(messageId, NavigateToMessageParams(timestamp: timecode, quote: (highlight?.quote).flatMap { quote in NavigateToMessageParams.Quote(string: quote.string, offset: quote.offset) }, setupReply: setupReply)), animated: isFirst || params.forceAnimatedScroll, completion: { [weak navigationController, weak controller] in
                                if let navigationController = navigationController, let controller = controller {
                                    let _ = navigationController.popToViewController(controller, animated: animated)
                                }
                            }, customPresentProgress: { [weak navigationController] c, a in
                                (navigationController?.viewControllers.last as? ViewController)?.present(c, in: .window(.root), with: a)
                            })
                        }
                        popAndComplete = false
                    } else if params.scrollToEndIfExists && isFirst {
                        controller.scrollToEndOfHistory()
                    } else if let search = params.activateMessageSearch {
                        controller.activateSearch(domain: search.0, query: search.1)
                    } else if let reportReason = params.reportReason {
                        controller.beginReportSelection(reason: reportReason)
                    }
                    
                    if switchToThread {
                        controller.updateChatLocationThread(threadId: params.chatLocation.threadId, animationDirection: nil)
                    }
                    
                    if popAndComplete {
                        if let _ = params.navigationController.viewControllers.last as? AttachmentController, let controller = params.navigationController.viewControllers[params.navigationController.viewControllers.count - 2] as? ChatControllerImpl, controller.chatLocation == params.chatLocation.asChatLocation {
                            
                        } else {
                            let _ = params.navigationController.popToViewController(controller, animated: params.animated)
                        }
                        params.completion(controller)
                    }
                    
                    controller.purposefulAction = params.purposefulAction
                    if let activateInput = params.activateInput {
                        if case let .replyThread(replyThread) = params.chatLocation, (replyThread.isForumPost || replyThread.isMonoforumPost) {
                        } else {
                            controller.activateInput(type: activateInput)
                        }
                    }
                    if params.changeColors {
                        controller.presentThemeSelection()
                    }
                    if let botStart = params.botStart {
                        controller.startBot(botStart.payload)
                    }
                    if let attachBotStart = params.attachBotStart {
                        controller.presentAttachmentBot(botId: attachBotStart.botId, payload: attachBotStart.payload, justInstalled: attachBotStart.justInstalled)
                    }
                    if let botAppStart = params.botAppStart, case let .peer(peer) = params.chatLocation {
                        controller.presentBotApp(botApp: botAppStart.botApp, botPeer: peer, payload: botAppStart.payload, mode: botAppStart.mode)
                    }
                    params.setupController(controller)
                    found = true
                    break
                }
                isFirst = false
            }
        }
        if !found {
            let controller: ChatControllerImpl
            if let chatController = params.chatController as? ChatControllerImpl {
                controller = chatController
                if let botStart = params.botStart {
                    controller.updateChatPresentationInterfaceState(interactive: false, { state -> ChatPresentationInterfaceState in
                        return state.updatedBotStartPayload(botStart.payload)
                    })
                }
                if let attachBotStart = params.attachBotStart {
                    controller.presentAttachmentBot(botId: attachBotStart.botId, payload: attachBotStart.payload, justInstalled: attachBotStart.justInstalled)
                }
                if let botAppStart = params.botAppStart, case let .peer(peer) = params.chatLocation {
                    Queue.mainQueue().after(0.1) {
                        controller.presentBotApp(botApp: botAppStart.botApp, botPeer: peer, payload: botAppStart.payload, mode: botAppStart.mode)
                    }
                }
            } else {
                controller = ChatControllerImpl(context: params.context, chatLocation: params.chatLocation.asChatLocation, chatLocationContextHolder: params.chatLocationContextHolder, subject: params.subject, botStart: params.botStart, attachBotStart: params.attachBotStart, botAppStart: params.botAppStart, peekData: params.peekData, peerNearbyData: params.peerNearbyData, chatListFilter: params.chatListFilter, chatNavigationStack: params.chatNavigationStack, customChatNavigationStack: params.customChatNavigationStack)
                
                if let botAppStart = params.botAppStart, case let .peer(peer) = params.chatLocation {
                    Queue.mainQueue().after(0.1) {
                        controller.presentBotApp(botApp: botAppStart.botApp, botPeer: peer, payload: botAppStart.payload, mode: botAppStart.mode)
                    }
                }
            }
            
            if controller.chatLocation.peerId == params.chatLocation.asChatLocation.peerId && controller.chatLocation.threadId == params.chatLocation.asChatLocation.threadId && (controller.subject != .scheduledMessages || controller.subject == params.subject) {
                if let updateTextInputState = params.updateTextInputState {
                    Queue.mainQueue().after(0.1) {
                        controller.updateTextInputState(updateTextInputState)
                    }
                }
            }
            
            controller.purposefulAction = params.purposefulAction
            if let search = params.activateMessageSearch {
                controller.activateSearch(domain: search.0, query: search.1)
            }
            let resolvedKeepStack: Bool
            switch params.keepStack {
            case .default:
                if params.navigationController.viewControllers.contains(where: { $0 is StoryContainerScreen }) {
                    resolvedKeepStack = true
                } else {
                    resolvedKeepStack = params.context.sharedContext.immediateExperimentalUISettings.keepChatNavigationStack
                }
            case .always:
                resolvedKeepStack = true
            case .never:
                resolvedKeepStack = false
            }
            if resolvedKeepStack {
                if let pushController = params.pushController {
                    pushController(controller, params.animated, {
                        params.completion(controller)
                    })
                } else {
                    params.navigationController.pushViewController(controller, animated: params.animated, completion: {
                        params.completion(controller)
                    })
                }
            } else {
                let viewControllers = params.navigationController.viewControllers.filter({ controller in
                    if controller is ForumCreateTopicScreen {
                        return false
                    }
                    if controller is ChatListController {
                        if let parentGroupId = params.parentGroupId {
                            return parentGroupId != .root
                        } else {
                            return true
                        }
                    } else if controller is TabBarController {
                        return true
                    } else {
                        return false
                    }
                })
                if viewControllers.isEmpty {
                    params.navigationController.replaceAllButRootController(controller, animated: params.animated, animationOptions: params.options, completion: {
                        params.completion(controller)
                    })
                } else {
                    if params.useBackAnimation {
                        params.navigationController.viewControllers = [controller] + params.navigationController.viewControllers
                        params.navigationController.replaceControllers(controllers: viewControllers + [controller], animated: params.animated, options: params.options, completion: {
                            params.completion(controller)
                        })
                    } else {
                        params.navigationController.replaceControllersAndPush(controllers: viewControllers, controller: controller, animated: params.animated, options: params.options, completion: {
                            params.completion(controller)
                        })
                    }
                }
            }
            if let activateInput = params.activateInput {
                controller.activateInput(type: activateInput)
            }
            if params.changeColors {
                Queue.mainQueue().after(0.1) {
                    controller.presentThemeSelection()
                }
            }
        }
        
        params.navigationController.currentWindow?.forEachController { controller in
            if let controller = controller as? NotificationContainerController {
                controller.removeItems { item in
                    if let item = item as? ChatMessageNotificationItem {
                        for message in item.messages {
                            switch params.chatLocation {
                            case let .peer(peer):
                                if message.id.peerId == peer.id {
                                    return true
                                }
                            case let .replyThread(replyThreadMessage):
                                if message.id.peerId == replyThreadMessage.peerId {
                                    return true
                                }
                            }
                        }
                    }
                    return false
                }
            }
        }
    })
}

private func findOpaqueLayer(rootLayer: CALayer, layer: CALayer) -> Bool {
    if layer.isHidden || layer.opacity < 0.8 {
        return false
    }
    
    if !layer.isHidden, let backgroundColor = layer.backgroundColor, backgroundColor.alpha > 0.8 {
        let coveringRect = layer.convert(layer.bounds, to: rootLayer)
        let intersection = coveringRect.intersection(rootLayer.bounds)
        let intersectionArea = intersection.width * intersection.height
        let rootArea = rootLayer.bounds.width * rootLayer.bounds.height
        if !rootArea.isZero && intersectionArea / rootArea > 0.8 {
            return true
        }
    }
    
    if let sublayers = layer.sublayers {
        for sublayer in sublayers {
            if findOpaqueLayer(rootLayer: rootLayer, layer: sublayer) {
                return true
            }
        }
    }
    return false
}

public func isInlineControllerForChatNotificationOverlayPresentation(_ controller: ViewController) -> Bool {
    if controller is InstantPageController || controller is MediaEditorScreen || controller is CameraScreen {
        return true
    }
    return false
}

public func isOverlayControllerForChatNotificationOverlayPresentation(_ controller: ContainableController) -> Bool {
    if controller is GalleryController || controller is AvatarGalleryController || controller is WallpaperGalleryController || controller is InstantPageGalleryController || controller is InstantVideoController || controller is NavigationController {
        return true
    }
    
    if controller.isViewLoaded {
        if let backgroundColor = controller.view.backgroundColor, !backgroundColor.isEqual(UIColor.clear) {
            return true
        }
        
        if findOpaqueLayer(rootLayer: controller.view.layer, layer: controller.view.layer) {
            return true
        }
    }
    
    return false
}

public func navigateToForumThreadImpl(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64, messageId: EngineMessage.Id?, navigationController: NavigationController, activateInput: ChatControllerActivateInput?, scrollToEndIfExists: Bool, keepStack: NavigateToChatKeepStack, animated: Bool) -> Signal<Never, NoError> {
    return fetchAndPreloadReplyThreadInfo(context: context, subject: .groupMessage(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId))), atMessageId: messageId, preload: false)
    |> deliverOnMainQueue
    |> beforeNext { [weak context, weak navigationController] result in
        guard let context = context, let navigationController = navigationController else {
            return
        }
        
        var actualActivateInput: ChatControllerActivateInput? = result.isEmpty ? .text : nil
        if let activateInput = activateInput {
            actualActivateInput = activateInput
        }
        
        context.sharedContext.navigateToChatController(
            NavigateToChatControllerParams(
                navigationController: navigationController,
                context: context,
                chatLocation: .replyThread(result.message),
                chatLocationContextHolder: result.contextHolder,
                subject: messageId.flatMap { .message(id: .id($0), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false) },
                activateInput: actualActivateInput,
                keepStack: keepStack,
                scrollToEndIfExists: scrollToEndIfExists,
                animated: !scrollToEndIfExists && animated
            )
        )
    }
    |> ignoreValues
    |> `catch` { _ -> Signal<Never, NoError> in
        return .complete()
    }
}

public func chatControllerForForumThreadImpl(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64) -> Signal<ChatController, NoError> {
    return context.engine.data.get(
        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
    )
    |> deliverOnMainQueue
    |> mapToSignal { peer -> Signal<ChatController, NoError> in
        guard let peer else {
            return .complete()
        }
        
        if case let .channel(channel) = peer, channel.flags.contains(.isMonoforum) {
            return .single(ChatControllerImpl(
                context: context,
                chatLocation: .replyThread(message: ChatReplyThreadMessage(
                    peerId: peer.id,
                    threadId: threadId,
                    channelMessageId: nil,
                    isChannelPost: false,
                    isForumPost: true,
                    isMonoforumPost: channel.flags.contains(.isMonoforum),
                    maxMessage: nil,
                    maxReadIncomingMessageId: nil,
                    maxReadOutgoingMessageId: nil,
                    unreadCount: 0,
                    initialFilledHoles: IndexSet(),
                    initialAnchor: .automatic,
                    isNotAvailable: false
                )),
                chatLocationContextHolder: Atomic(value: nil)
            ))
        } else {
            return fetchAndPreloadReplyThreadInfo(context: context, subject: .groupMessage(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId))), atMessageId: nil, preload: false)
            |> deliverOnMainQueue
            |> `catch` { _ -> Signal<ReplyThreadInfo, NoError> in
                return .complete()
            }
            |> map { result in
                return ChatControllerImpl(
                    context: context,
                    chatLocation: .replyThread(message: result.message),
                    chatLocationContextHolder: result.contextHolder
                )
            }
        }
    }
}

public func navigateToForumChannelImpl(context: AccountContext, peerId: EnginePeer.Id, navigationController: NavigationController) {
    let controller = ChatListControllerImpl(context: context, location: .forum(peerId: peerId), controlsHistoryPreload: false, enableDebugActions: false)
    controller.navigationPresentation = .master
    navigationController.pushViewController(controller)
}
