import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import AccountContext
import ChatInterfaceState

func preloadedChatHistoryViewForLocation(_ location: ChatHistoryLocationInput, context: AccountContext, chatLocation: ChatLocation, subject: ChatControllerSubject?, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, fixedCombinedReadStates: MessageHistoryViewReadState?, tag: HistoryViewInputTag?, additionalData: [AdditionalMessageHistoryViewData], orderStatistics: MessageHistoryViewOrderStatistics = []) -> Signal<ChatHistoryViewUpdate, NoError> {
    var isScheduled = false
    if case .scheduledMessages = subject {
        isScheduled = true
    }
    
    var tag = tag
    if case .pinnedMessages = subject {
        tag = .tag(.pinned)
    }
    
    return (chatHistoryViewForLocation(location, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), context: context, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder, scheduled: isScheduled, fixedCombinedReadStates: fixedCombinedReadStates, tag: tag, appendMessagesFromTheSameGroup: false, additionalData: additionalData, orderStatistics: orderStatistics)
    |> castError(Bool.self)
    |> mapToSignal { update -> Signal<ChatHistoryViewUpdate, Bool> in
        switch update {
            case let .Loading(_, type):
                if case .Generic(.FillHole) = type {
                    return .fail(true)
                }
            case let .HistoryView(_, type, _, _, _, _, _):
                if case .Generic(.FillHole) = type {
                    return .fail(true)
                }
        }
        return .single(update)
    })
    |> restartIfError
}

func chatHistoryViewForLocation(
    _ location: ChatHistoryLocationInput,
    ignoreMessagesInTimestampRange: ClosedRange<Int32>?,
    ignoreMessageIds: Set<EngineMessage.Id>,
    context: AccountContext,
    chatLocation: ChatLocation,
    chatLocationContextHolder: Atomic<ChatLocationContextHolder?>,
    scheduled: Bool,
    fixedCombinedReadStates: MessageHistoryViewReadState?,
    tag: HistoryViewInputTag?,
    appendMessagesFromTheSameGroup: Bool,
    additionalData: [AdditionalMessageHistoryViewData],
    orderStatistics: MessageHistoryViewOrderStatistics = [],
    useRootInterfaceStateForThread: Bool = false
) -> Signal<ChatHistoryViewUpdate, NoError> {
    let account = context.account
    if scheduled {
        var first = true
        var chatScrollPosition: ChatHistoryViewScrollPosition?
        if case let .Scroll(subject, _, sourceIndex, position, animated, highlight, setupReply) = location.content {
            let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > subject.index ? .Down : .Up
            chatScrollPosition = .index(subject: subject, position: position, directionHint: directionHint, animated: animated, highlight: highlight, displayLink: false, setupReply: setupReply)
        }
        return account.viewTracker.scheduledMessagesViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), additionalData: additionalData)
        |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
            
            let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)
            
            if view.isLoading {
                return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
            }

            let type: ChatHistoryViewUpdateType
            let scrollPosition: ChatHistoryViewScrollPosition? = first ? chatScrollPosition : nil
            if first {
                first = false
                if chatScrollPosition == nil {
                    type = .Initial(fadeIn: false)
                } else {
                    type = .Generic(type: .UpdateVisible)
                }
            } else {
                type = .Generic(type: .Generic)
            }
            return .HistoryView(view: view, type: type, scrollPosition: scrollPosition, flashIndicators: false, originalScrollPosition: chatScrollPosition, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData), id: location.id)
        }
    } else {
        let ignoreRelatedChats: Bool
        if let tag = tag, case .tag(.pinned) = tag {
            ignoreRelatedChats = true
        } else {
            ignoreRelatedChats = false
        }
        
        let trackHoles = true
        
        switch location.content {
            case let .Initial(count):
                var preloaded = false
                var fadeIn = false
                let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
            
                var requestAroundId = false
                var preFixedReadState: MessageHistoryViewReadState?
                if tag != nil {
                    requestAroundId = true
                }
                if case let .replyThread(message) = chatLocation, (message.peerId == context.account.peerId) {
                    preFixedReadState = .peer([:])
                }
            
                if requestAroundId {
                    signal = account.viewTracker.aroundMessageHistoryViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, ignoreMessageIds: ignoreMessageIds, index: .upperBound, anchorIndex: .upperBound, count: count, trackHoles: trackHoles, ignoreRelatedChats: ignoreRelatedChats, fixedCombinedReadStates: preFixedReadState, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, orderStatistics: orderStatistics, useRootInterfaceStateForThread: useRootInterfaceStateForThread)
                } else {
                    signal = account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, ignoreMessageIds: ignoreMessageIds, count: count, trackHoles: trackHoles, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, orderStatistics: orderStatistics, additionalData: additionalData, useRootInterfaceStateForThread: useRootInterfaceStateForThread)
                }
            
                let isPossibleIntroLoaded: Signal<Bool, NoError>
                if case let .peer(id) = chatLocation, id.namespace == Namespaces.Peer.CloudUser {
                    isPossibleIntroLoaded = context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Peer.BusinessIntro(id: id)
                    )
                    |> map { result -> Bool in
                        switch result {
                        case .known:
                            return true
                        case .unknown:
                            return false
                        }
                    }
                    |> distinctUntilChanged
                } else {
                    isPossibleIntroLoaded = .single(true)
                }
            
                return combineLatest(signal, isPossibleIntroLoaded)
                |> map { viewData, isPossibleIntroLoaded -> ChatHistoryViewUpdate in
                    let (view, updateType, initialData) = viewData
                    
                    let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
                    
                    let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)
                    
                    if !isPossibleIntroLoaded {
                        return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                    }
                    
                    if preloaded {
                        return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, flashIndicators: false, originalScrollPosition: nil, initialData: combinedInitialData, id: location.id)
                    } else {
                        if view.isLoading {
                            return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                        }
                        var scrollPosition: ChatHistoryViewScrollPosition?
                        
                        let canScrollToRead: Bool
                        if case let .replyThread(message) = chatLocation, !message.isForumPost, !message.isMonoforumPost {
                            if message.peerId == context.account.peerId {
                                canScrollToRead = false
                            } else {
                                canScrollToRead = true
                            }
                        } else if case let .replyThread(message) = chatLocation, message.isMonoforumPost {
                            canScrollToRead = true
                        } else if view.isAddedToChatList {
                            canScrollToRead = true
                        } else {
                            canScrollToRead = false
                        }
                        
                        if tag == nil, case let .replyThread(message) = chatLocation, message.isForumPost, view.maxReadIndex == nil {
                            if case let .message(index) = view.anchorIndex {
                                scrollPosition = .index(subject: MessageHistoryScrollToSubject(index: .message(index), quote: nil), position: .bottom(0.0), directionHint: .Up, animated: false, highlight: false, displayLink: false, setupReply: false)
                            }
                        }
                        
                        if let maxReadIndex = view.maxReadIndex, tag == nil, canScrollToRead {
                            let aroundIndex = maxReadIndex
                            scrollPosition = .unread(index: maxReadIndex)
                            
                            if let _ = chatLocation.peerId {
                                var targetIndex = 0
                                for i in 0 ..< view.entries.count {
                                    if view.entries[i].index >= aroundIndex {
                                        targetIndex = i
                                        break
                                    }
                                }
                                
                                let maxIndex = targetIndex + 40
                                let minIndex = targetIndex - 40
                                if minIndex <= 0 && view.holeEarlier {
                                    fadeIn = true
                                    return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                                }
                                if maxIndex >= view.entries.count {
                                    if view.holeLater {
                                        fadeIn = true
                                        return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                                    }
                                    if view.holeEarlier {
                                        var incomingCount: Int32 = 0
                                        inner: for entry in view.entries.reversed() {
                                            if !entry.message.flags.intersection(.IsIncomingMask).isEmpty {
                                                incomingCount += 1
                                            }
                                        }
                                        if case let .peer(peerId) = chatLocation, let combinedReadStates = view.fixedReadStates, case let .peer(readStates) = combinedReadStates, let readState = readStates[peerId], readState.count == incomingCount {
                                        } else {
                                            fadeIn = true
                                            return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                                        }
                                    }
                                }
                            }
                        } else if view.isAddedToChatList, tag == nil, let historyScrollState = (initialData?.storedInterfaceState).flatMap(_internal_decodeStoredChatInterfaceState).flatMap(ChatInterfaceState.parse)?.historyScrollState {
                            scrollPosition = .positionRestoration(index: historyScrollState.messageIndex, relativeOffset: CGFloat(historyScrollState.relativeOffset))
                        } else {
                            if let _ = chatLocation.peerId, !view.isAddedToChatList {
                                if view.holeEarlier && view.entries.count <= 2 {
                                    fadeIn = true
                                    return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                                }
                            }
                            if view.entries.isEmpty && (view.holeEarlier || view.holeLater) {
                                fadeIn = true
                                return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                            }
                        }
                        
                        preloaded = true
                        return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: scrollPosition, flashIndicators: false, originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData), id: location.id)
                    }
                }
            case let .InitialSearch(searchLocationSubject, count, highlight, setupReply):
                var preloaded = false
                var fadeIn = false
                
                let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
                switch searchLocationSubject.location {
                case let .index(index):
                    signal = account.viewTracker.aroundMessageHistoryViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, ignoreMessageIds: ignoreMessageIds, index: .message(index), anchorIndex: .message(index), count: count, trackHoles: trackHoles, ignoreRelatedChats: ignoreRelatedChats, fixedCombinedReadStates: nil, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, orderStatistics: orderStatistics, additionalData: additionalData, useRootInterfaceStateForThread: useRootInterfaceStateForThread)
                case let .id(id):
                    signal = account.viewTracker.aroundIdMessageHistoryViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, ignoreMessageIds: ignoreMessageIds, count: count, trackHoles: trackHoles, ignoreRelatedChats: ignoreRelatedChats, messageId: id, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, orderStatistics: orderStatistics, additionalData: additionalData, useRootInterfaceStateForThread: useRootInterfaceStateForThread)
                }
                
                return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                    let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
                    
                    let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)
                    
                    if preloaded {
                        return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, flashIndicators: false, originalScrollPosition: nil, initialData: combinedInitialData, id: location.id)
                    } else {
                        let anchorIndex = view.anchorIndex
                        
                        var targetIndex = 0
                        for i in 0 ..< view.entries.count {
                            if anchorIndex.isLessOrEqual(to: view.entries[i].index) {
                                targetIndex = i
                                break
                            }
                        }
                        
                        if !view.entries.isEmpty {
                            let minIndex = max(0, targetIndex - count / 2)
                            let maxIndex = min(view.entries.count, targetIndex + count / 2)
                            if minIndex == 0 && view.holeEarlier {
                                fadeIn = true
                                return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                            }
                            if maxIndex == view.entries.count && view.holeLater {
                                fadeIn = true
                                return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                            }
                        } else if view.holeEarlier || view.holeLater {
                            fadeIn = true
                            return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                        }
                        
                        var reportUpdateType: ChatHistoryViewUpdateType = .Initial(fadeIn: fadeIn)
                        if case .FillHole = updateType {
                            reportUpdateType = .Generic(type: updateType)
                        }
                        
                        preloaded = true
                        
                        return .HistoryView(view: view, type: reportUpdateType, scrollPosition: .index(subject: MessageHistoryScrollToSubject(index: anchorIndex, quote: searchLocationSubject.quote.flatMap { quote in MessageHistoryScrollToSubject.Quote(string: quote.string, offset: quote.offset) }, todoTaskId: searchLocationSubject.todoTaskId, setupReply: setupReply), position: .center(.bottom), directionHint: .Down, animated: false, highlight: highlight, displayLink: false, setupReply: setupReply), flashIndicators: false, originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData), id: location.id)
                    }
                }
            case let .Navigation(index, anchorIndex, count, _):
                var first = true
                return account.viewTracker.aroundMessageHistoryViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, ignoreMessageIds: ignoreMessageIds, index: index, anchorIndex: anchorIndex, count: count, trackHoles: trackHoles, ignoreRelatedChats: ignoreRelatedChats, fixedCombinedReadStates: fixedCombinedReadStates, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, orderStatistics: orderStatistics, additionalData: additionalData, useRootInterfaceStateForThread: useRootInterfaceStateForThread) |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                    let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
                    
                    let genericType: ViewUpdateType
                    if first {
                        first = false
                        genericType = ViewUpdateType.UpdateVisible
                    } else {
                        genericType = updateType
                    }
                    return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: nil, flashIndicators: false, originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData), id: location.id)
                }
            case let .Scroll(subject, anchorIndex, sourceIndex, scrollPosition, animated, highlight, setupReply):
                let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > subject.index ? .Down : .Up
                let chatScrollPosition = ChatHistoryViewScrollPosition.index(subject: subject, position: scrollPosition, directionHint: directionHint, animated: animated, highlight: highlight, displayLink: false, setupReply: setupReply)
                var first = true
                return account.viewTracker.aroundMessageHistoryViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, ignoreMessageIds: ignoreMessageIds, index: subject.index, anchorIndex: anchorIndex, count: 128, ignoreRelatedChats: ignoreRelatedChats, fixedCombinedReadStates: fixedCombinedReadStates, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, orderStatistics: orderStatistics, additionalData: additionalData, useRootInterfaceStateForThread: useRootInterfaceStateForThread)
                |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                    let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
                    
                    let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)
                    
                    if view.isLoading {
                        return ChatHistoryViewUpdate.Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                    }
                    
                    let genericType: ViewUpdateType
                    let scrollPosition: ChatHistoryViewScrollPosition? = first ? chatScrollPosition : nil
                    if first {
                        first = false
                        genericType = ViewUpdateType.UpdateVisible
                    } else {
                        genericType = updateType
                    }
                    return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: scrollPosition, flashIndicators: animated, originalScrollPosition: chatScrollPosition, initialData: combinedInitialData, id: location.id)
                }
        }
    }
}

private func extractAdditionalData(view: MessageHistoryView, chatLocation: ChatLocation) -> (
    cachedData: CachedPeerData?,
    cachedDataMessages: [MessageId: Message]?,
    readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?
) {
    var cachedData: CachedPeerData?
    var cachedDataMessages: [MessageId: Message] = [:]
    var readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData] = [:]
    var notificationSettings: PeerNotificationSettings?
        
    loop: for data in view.additionalData {
        switch data {
            case let .peerNotificationSettings(value):
                notificationSettings = value
            default:
                break
        }
    }
        
    for data in view.additionalData {
        switch data {
            case let .peerNotificationSettings(value):
                notificationSettings = value
            case let .cachedPeerData(peerIdValue, value):
                if chatLocation.peerId == peerIdValue {
                    cachedData = value
                }
            case let .cachedPeerDataMessages(peerIdValue, value):
                if case .peer(peerIdValue) = chatLocation {
                    if let value = value {
                        for (_, message) in value {
                            cachedDataMessages[message.id] = message
                        }
                    }
                }
            case let .message(_, messages):
                for message in messages {
                    cachedDataMessages[message.id] = message
                }
            case let .totalUnreadState(totalUnreadState):
            switch chatLocation {
            case let .peer(peerId):
                if let combinedReadStates = view.fixedReadStates {
                    if case let .peer(readStates) = combinedReadStates, let readState = readStates[peerId] {
                        readStateData[peerId] = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalState: totalUnreadState, notificationSettings: notificationSettings)
                    }
                }
            case .replyThread, .customChatContents:
                break
                }
            default:
                break
        }
    }
        
    return (cachedData, cachedDataMessages, readStateData)
}

struct ReplyThreadInfo {
    var message: ChatReplyThreadMessage
    var isChannelPost: Bool
    var isEmpty: Bool
    var scrollToLowerBoundMessage: MessageIndex?
    var contextHolder: Atomic<ChatLocationContextHolder?>
}

enum ReplyThreadSubject {
    case channelPost(MessageId)
    case groupMessage(MessageId)
}

func fetchAndPreloadReplyThreadInfo(context: AccountContext, subject: ReplyThreadSubject, atMessageId: MessageId?, preload: Bool) -> Signal<ReplyThreadInfo, FetchChannelReplyThreadMessageError> {
    let message: Signal<ChatReplyThreadMessage, FetchChannelReplyThreadMessageError>
    switch subject {
    case .channelPost(let messageId), .groupMessage(let messageId):
        message = context.engine.messages.fetchChannelReplyThreadMessage(messageId: messageId, atMessageId: atMessageId)
    }
    
    return message
    |> mapToSignal { replyThreadMessage -> Signal<ReplyThreadInfo, FetchChannelReplyThreadMessageError> in
        let chatLocationContextHolder = Atomic<ChatLocationContextHolder?>(value: nil)
        
        let input: ChatHistoryLocationInput
        var scrollToLowerBoundMessage: MessageIndex?
        switch replyThreadMessage.initialAnchor {
        case .automatic:
            if let atMessageId = atMessageId {
                input = ChatHistoryLocationInput(
                    content: .InitialSearch(subject: MessageHistoryInitialSearchSubject(location: .id(atMessageId)), count: 40, highlight: true, setupReply: false),
                    id: 0
                )
            } else {
                input = ChatHistoryLocationInput(
                    content: .Initial(count: 40),
                    id: 0
                )
            }
        case let .lowerBoundMessage(index):
            input = ChatHistoryLocationInput(
                content: .Navigation(index: .message(index), anchorIndex: .message(index), count: 40, highlight: false),
                id: 0
            )
            scrollToLowerBoundMessage = index
        }
        
        if replyThreadMessage.isNotAvailable {
            return .single(ReplyThreadInfo(
                message: replyThreadMessage,
                isChannelPost: replyThreadMessage.isChannelPost,
                isEmpty: false,
                scrollToLowerBoundMessage: nil,
                contextHolder: chatLocationContextHolder
            ))
        }
        
        if preload {
            let preloadSignal = preloadedChatHistoryViewForLocation(
                input,
                context: context,
                chatLocation: .replyThread(message: replyThreadMessage),
                subject: nil,
                chatLocationContextHolder: chatLocationContextHolder,
                fixedCombinedReadStates: nil,
                tag: nil,
                additionalData: []
            )
            return preloadSignal
            |> map { historyView -> Bool? in
                switch historyView {
                case .Loading:
                    return nil
                case let .HistoryView(view, _, _, _, _, _, _):
                    return view.entries.isEmpty
                }
            }
            |> mapToSignal { value -> Signal<Bool, NoError> in
                if let value = value {
                    return .single(value)
                } else {
                    return .complete()
                }
            }
            |> take(1)
            |> map { isEmpty -> ReplyThreadInfo in
                return ReplyThreadInfo(
                    message: replyThreadMessage,
                    isChannelPost: replyThreadMessage.isChannelPost,
                    isEmpty: isEmpty,
                    scrollToLowerBoundMessage: scrollToLowerBoundMessage,
                    contextHolder: chatLocationContextHolder
                )
            }
            |> castError(FetchChannelReplyThreadMessageError.self)
        } else {
            return .single(ReplyThreadInfo(
                message: replyThreadMessage,
                isChannelPost: replyThreadMessage.isChannelPost,
                isEmpty: false,
                scrollToLowerBoundMessage: scrollToLowerBoundMessage,
                contextHolder: chatLocationContextHolder
            ))
        }
    }
}
