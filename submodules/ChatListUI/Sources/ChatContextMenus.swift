import Foundation
import UIKit
import SwiftSignalKit
import ContextUI
import AccountContext
import Postbox
import TelegramCore
import Display
import TelegramUIPreferences
import OverlayStatusController
import AlertUI
import PresentationDataUtils
import UndoUI
import PremiumUI
import TelegramPresentationData
import TelegramStringFormatting
import ChatTimerScreen
import NotificationPeerExceptionController

func archiveContextMenuItems(context: AccountContext, groupId: PeerGroupId, chatListController: ChatListControllerImpl?) -> Signal<[ContextMenuItem], NoError> {
    let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
    let strings = presentationData.strings
    return combineLatest(
        context.engine.messages.unreadChatListPeerIds(groupId: EngineChatList.Group(groupId), filterPredicate: nil),
        context.engine.data.get(
            TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.chatArchiveSettings)
        )
    )
    |> map { [weak chatListController] unreadChatListPeerIds, chatArchiveSettingsPreference -> [ContextMenuItem] in
        var items: [ContextMenuItem] = []
        
        if !unreadChatListPeerIds.isEmpty {
            items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_MarkAllAsRead, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsRead"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                let _ = (context.engine.messages.markAllChatsAsReadInteractively(items: [(groupId: EngineChatList.Group(groupId), filterPredicate: nil)])
                |> deliverOnMainQueue).startStandalone(completed: {
                    f(.default)
                })
            })))
        }
        
        let settings = chatArchiveSettingsPreference?.get(ChatArchiveSettings.self) ?? ChatArchiveSettings.default
        let isPinned = !settings.isHiddenByDefault
        items.append(.action(ContextMenuActionItem(text: isPinned ? strings.ChatList_Context_HideArchive : strings.ChatList_Context_UnhideArchive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: isPinned ? "Chat/Context Menu/Unpin": "Chat/Context Menu/Pin"), color: theme.contextMenu.primaryColor) }, action: { [weak chatListController] _, f in
            chatListController?.toggleArchivedFolderHiddenByDefault()
            f(.default)
        })))
        
        return items
    }
}

enum ChatContextMenuSource {
    case chatList(filter: ChatListFilter?)
    case search(ChatListSearchContextActionSource)
}

func chatContextMenuItems(context: AccountContext, peerId: PeerId, promoInfo: ChatListNodeEntryPromoInfo?, source: ChatContextMenuSource, chatListController: ChatListControllerImpl?, joined: Bool) -> Signal<[ContextMenuItem], NoError> {
    let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
    let strings = presentationData.strings

    return combineLatest(
        context.engine.data.get(TelegramEngine.EngineData.Item.Messages.ChatListGroup(id: peerId)),
        context.engine.peers.recentlySearchedPeers() |> take(1),
        context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
        )
    )
    |> mapToSignal { peerGroup, recentlySearchedPeers, limitsData -> Signal<[ContextMenuItem], NoError> in
        let location: TogglePeerChatPinnedLocation
        var chatListFilter: ChatListFilter?
        if case let .chatList(filter) = source, let chatFilter = filter {
            chatListFilter = chatFilter
            location = .filter(chatFilter.id)
        } else {
            if let peerGroup = peerGroup {
                location = .group(peerGroup._asGroup())
            } else {
                location = .group(.root)
            }
        }

        return combineLatest(
            context.engine.peers.updatedChatListFilters()
            |> take(1),
            context.engine.peers.getPinnedItemIds(location: location)
        )
        |> mapToSignal { filters, pinnedItemIds -> Signal<[ContextMenuItem], NoError> in
            let isPinned = pinnedItemIds.contains(.peer(peerId))
            
            let renderedPeer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.RenderedPeer(id: peerId))
            
            return renderedPeer
            |> mapToSignal { renderedPeer -> Signal<[ContextMenuItem], NoError> in
                guard let renderedPeer = renderedPeer else {
                    return .single([])
                }
                guard let peer = renderedPeer.chatMainPeer else {
                    return .single([])
                }
                
                return context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.IsContact(id: peer.id),
                    TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peer.id),
                    TelegramEngine.EngineData.Item.NotificationSettings.Global(),
                    TelegramEngine.EngineData.Item.Messages.PeerReadCounters(id: peer.id)
                )
                |> map { [weak chatListController] isContact, notificationSettings, globalNotificationSettings, readCounters -> [ContextMenuItem] in
                    if promoInfo != nil {
                        return []
                    }

                    var items: [ContextMenuItem] = []

                    if case let .search(search) = source {
                        switch search {
                        case .recentPeers:
                            break
                        case .recentSearch:
                            items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_RemoveFromRecents, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                                let _ = (context.engine.peers.removeRecentlySearchedPeer(peerId: peerId)
                                |> deliverOnMainQueue).startStandalone(completed: {
                                    f(.default)
                                })
                            })))
                            items.append(.separator)
                        case .search:
                            if recentlySearchedPeers.contains(where: { $0.peer.peerId == peerId }) {
                                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_RemoveFromRecents, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                                    let _ = (context.engine.peers.removeRecentlySearchedPeer(peerId: peerId)
                                    |> deliverOnMainQueue).startStandalone(completed: {
                                        f(.default)
                                    })
                                })))
                                items.append(.separator)
                            }
                        case .recentApps:
                            items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_RemoveFromRecents, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                                let _ = (context.engine.peers.removeRecentlyUsedApp(peerId: peerId)
                                |> deliverOnMainQueue).startStandalone(completed: {
                                    f(.default)
                                })
                            })))
                            items.append(.separator)
                        case .popularApps:
                            break
                        }
                    }

                    if case .search(.recentApps) = source {
                    } else if case .search(.popularApps) = source {
                    } else {
                        let isSavedMessages = peerId == context.account.peerId
                        
                        if !isSavedMessages, case let .user(peer) = peer, !peer.flags.contains(.isSupport), peer.botInfo == nil && !peer.isDeleted {
                            if !isContact {
                                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_AddToContacts, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                    context.sharedContext.openAddPersonContact(context: context, peerId: peerId, pushController: { controller in
                                        if let navigationController = chatListController?.navigationController as? NavigationController {
                                            navigationController.pushViewController(controller)
                                        }
                                    }, present: { c, a in
                                        if let chatListController = chatListController {
                                            chatListController.present(c, in: .window(.root), with: a)
                                        }
                                    })
                                    f(.default)
                                })))
                                items.append(.separator)
                            }
                        }
                        
                        var isMuted = false
                        if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                            isMuted = true
                        } else if case .default = notificationSettings.muteState {
                            if case .user = peer {
                                isMuted = !globalNotificationSettings.privateChats.enabled
                            } else if case .legacyGroup = peer {
                                isMuted = !globalNotificationSettings.groupChats.enabled
                            } else if case let .channel(channel) = peer {
                                switch channel.info {
                                case .group:
                                    isMuted = !globalNotificationSettings.groupChats.enabled
                                case .broadcast:
                                    isMuted = !globalNotificationSettings.channels.enabled
                                }
                            }
                        }
                        
                        var isUnread = false
                        if readCounters.isUnread {
                            isUnread = true
                        }
                        
                        var isForum = false
                        if case let .channel(channel) = peer, channel.isForumOrMonoForum {
                            isForum = true
                        }
                        
                        var hasRemoveFromFolder = false
                        if case let .chatList(currentFilter) = source {
                            if let currentFilter = currentFilter, case let .filter(id, title, emoticon, data) = currentFilter {
                                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_RemoveFromFolder, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/RemoveFromFolder"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                                    let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
                                        var filters = filters
                                        for i in 0 ..< filters.count {
                                            if filters[i].id == currentFilter.id {
                                                var updatedData = data
                                                let _ = updatedData.addExcludePeer(peerId: peer.id)
                                                filters[i] = .filter(id: id, title: title, emoticon: emoticon, data: updatedData)
                                                break
                                            }
                                        }
                                        return filters
                                    }
                                    |> deliverOnMainQueue).startStandalone(completed: {
                                        c?.dismiss(completion: {
                                            chatListController?.present(UndoOverlayController(presentationData: presentationData, content: .chatRemovedFromFolder(context: context, chatTitle: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), folderTitle: title.rawAttributedString), elevatedLayout: false, animateInAsReplacement: true, action: { _ in
                                                return false
                                            }), in: .current)
                                        })
                                    })
                                })))
                                hasRemoveFromFolder = true
                            }
                        }
                        
                        if !hasRemoveFromFolder && peerGroup != nil {
                            var hasFolders = false
                            
                            for case let .filter(_, _, _, data) in filters {
                                let predicate = chatListFilterPredicate(filter: data, accountPeerId: context.account.peerId)
                                if predicate.includes(peer: peer._asPeer(), groupId: .root, isRemovedFromTotalUnreadCount: isMuted, isUnread: isUnread, isContact: isContact, messageTagSummaryResult: false) {
                                    continue
                                }
                                
                                var data = data
                                if data.addIncludePeer(peerId: peer.id) {
                                    hasFolders = true
                                    break
                                }
                            }
                            
                            if hasFolders {
                                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_AddToFolder, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Folder"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                                    var updatedItems: [ContextMenuItem] = []
                                    
                                    updatedItems.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_Back, icon: { theme in
                                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                                    }, iconPosition: .left, action: { c, _ in
                                        c?.setItems(chatContextMenuItems(context: context, peerId: peerId, promoInfo: promoInfo, source: source, chatListController: chatListController, joined: joined) |> map { ContextController.Items(content: .list($0)) }, minHeight: nil, animated: true)
                                    })))
                                    updatedItems.append(.separator)
                                    
                                    for filter in filters {
                                        if case let .filter(_, title, _, data) = filter {
                                            let predicate = chatListFilterPredicate(filter: data, accountPeerId: context.account.peerId)
                                            if predicate.includes(peer: peer._asPeer(), groupId: .root, isRemovedFromTotalUnreadCount: isMuted, isUnread: isUnread, isContact: isContact, messageTagSummaryResult: false) {
                                                continue
                                            }
                                            
                                            var data = data
                                            if !data.addIncludePeer(peerId: peer.id) {
                                                continue
                                            }
                                            
                                            let filterType = chatListFilterType(data)
                                            updatedItems.append(.action(ContextMenuActionItem(text: title.text, entities: title.entities, enableEntityAnimations: title.enableAnimations, icon: { theme in
                                                let imageName: String
                                                switch filterType {
                                                case .generic:
                                                    imageName = "Chat/Context Menu/List"
                                                case .unmuted:
                                                    imageName = "Chat/Context Menu/Unmute"
                                                case .unread:
                                                    imageName = "Chat/Context Menu/MarkAsUnread"
                                                case .channels:
                                                    imageName = "Chat/Context Menu/Channels"
                                                case .groups:
                                                    imageName = "Chat/Context Menu/Groups"
                                                case .bots:
                                                    imageName = "Chat/Context Menu/Bots"
                                                case .contacts:
                                                    imageName = "Chat/Context Menu/User"
                                                case .nonContacts:
                                                    imageName = "Chat/Context Menu/UnknownUser"
                                                }
                                                return generateTintedImage(image: UIImage(bundleImageName: imageName), color: theme.contextMenu.primaryColor)
                                            }, action: { c, f in
                                                c?.dismiss(completion: {
                                                    let isPremium = limitsData.0?.isPremium ?? false
                                                    let (_, limits, premiumLimits) = limitsData
                                                    
                                                    let limit = limits.maxFolderChatsCount
                                                    let premiumLimit = premiumLimits.maxFolderChatsCount
                                                    
                                                    let count = data.includePeers.peers.count - 1
                                                    if count >= premiumLimit {
                                                        let controller = PremiumLimitScreen(context: context, subject: .chatsPerFolder, count: Int32(count), action: {
                                                            return true
                                                        })
                                                        chatListController?.push(controller)
                                                        return
                                                    } else if count >= limit && !isPremium {
                                                        var replaceImpl: ((ViewController) -> Void)?
                                                        let controller = PremiumLimitScreen(context: context, subject: .chatsPerFolder, count: Int32(count), action: {
                                                            let controller = PremiumIntroScreen(context: context, source: .chatsPerFolder)
                                                            replaceImpl?(controller)
                                                            return true
                                                        })
                                                        replaceImpl = { [weak controller] c in
                                                            controller?.replace(with: c)
                                                        }
                                                        chatListController?.push(controller)
                                                        return
                                                    }
                                                    
                                                    let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
                                                        var filters = filters
                                                        for i in 0 ..< filters.count {
                                                            if filters[i].id == filter.id {
                                                                if case let .filter(id, title, emoticon, data) = filter {
                                                                    var updatedData = data
                                                                    let _ = updatedData.addIncludePeer(peerId: peer.id)
                                                                    filters[i] = .filter(id: id, title: title, emoticon: emoticon, data: updatedData)
                                                                }
                                                                break
                                                            }
                                                        }
                                                        return filters
                                                    }).startStandalone()
                                                    chatListController?.present(UndoOverlayController( presentationData: presentationData, content: .chatAddedToFolder(context: context, chatTitle: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), folderTitle: title.rawAttributedString), elevatedLayout: false, animateInAsReplacement: true, action: { _ in
                                                        return false
                                                    }), in: .current)
                                                })
                                            })))
                                        }
                                    }
                                                                        
                                    c?.setItems(.single(ContextController.Items(content: .list(updatedItems), context: context)), minHeight: nil, animated: true)
                                })))
                                items.append(.separator)
                            }
                        }
                        
                        if isUnread {
                            items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_MarkAsRead, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsRead"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                let _ = context.engine.messages.togglePeersUnreadMarkInteractively(peerIds: [peerId], setToValue: nil).startStandalone()
                                f(.default)
                            })))
                        } else if !isForum {
                            var canMarkAsUnread = true
                            if peerId.namespace == Namespaces.Peer.CloudChannel && !joined {
                                canMarkAsUnread = false
                            }
                            if canMarkAsUnread {
                                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_MarkAsUnread, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsUnread"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                    let _ = context.engine.messages.togglePeersUnreadMarkInteractively(peerIds: [peerId], setToValue: nil).startStandalone()
                                    f(.default)
                                })))
                            }
                        }
                        
                        let archiveEnabled = !isSavedMessages && peerId != PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000)) && peerId == context.account.peerId
                        if let group = peerGroup {
                            if archiveEnabled {
                                let isArchived = group == .archive
                                items.append(.action(ContextMenuActionItem(text: isArchived ? strings.ChatList_Context_Unarchive : strings.ChatList_Context_Archive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: isArchived ? "Chat/Context Menu/Unarchive" : "Chat/Context Menu/Archive"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                    if isArchived {
                                        let _ = (context.engine.peers.updatePeersGroupIdInteractively(peerIds: [peerId], groupId: .root)
                                                 |> deliverOnMainQueue).startStandalone(completed: {
                                            f(.default)
                                        })
                                    } else {
                                        if let chatListController = chatListController {
                                            chatListController.archiveChats(peerIds: [peerId])
                                            f(.default)
                                        } else {
                                            let _ = (context.engine.peers.updatePeersGroupIdInteractively(peerIds: [peerId], groupId: .archive)
                                                     |> deliverOnMainQueue).startStandalone(completed: {
                                                f(.default)
                                            })
                                        }
                                    }
                                })))
                            }
                            
                            if isPinned || chatListFilter == nil || peerId.namespace != Namespaces.Peer.SecretChat {
                                items.append(.action(ContextMenuActionItem(text: isPinned ? strings.ChatList_Context_Unpin : strings.ChatList_Context_Pin, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: isPinned ? "Chat/Context Menu/Unpin" : "Chat/Context Menu/Pin"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                                    let _ = (context.engine.peers.toggleItemPinned(location: location, itemId: .peer(peerId))
                                             |> deliverOnMainQueue).startStandalone(next: { result in
                                        switch result {
                                        case .done:
                                            f(.default)
                                        case let .limitExceeded(count, _):
                                            f(.default)
                                            
                                            let isPremium = limitsData.0?.isPremium ?? false
                                            if isPremium {
                                                if case .filter = location {
                                                    let controller = PremiumLimitScreen(context: context, subject: .chatsPerFolder, count: Int32(count), action: {
                                                        return true
                                                    })
                                                    chatListController?.push(controller)
                                                } else {
                                                    let controller = PremiumLimitScreen(context: context, subject: .pins, count: Int32(count), action: {
                                                        return true
                                                    })
                                                    chatListController?.push(controller)
                                                }
                                            } else {
                                                if case .filter = location {
                                                    var replaceImpl: ((ViewController) -> Void)?
                                                    let controller = PremiumLimitScreen(context: context, subject: .chatsPerFolder, count: Int32(count), action: {
                                                        let premiumScreen = PremiumIntroScreen(context: context, source: .pinnedChats)
                                                        replaceImpl?(premiumScreen)
                                                        return true
                                                    })
                                                    chatListController?.push(controller)
                                                    replaceImpl = { [weak controller] c in
                                                        controller?.replace(with: c)
                                                    }
                                                } else {
                                                    var replaceImpl: ((ViewController) -> Void)?
                                                    let controller = PremiumLimitScreen(context: context, subject: .pins, count: Int32(count), action: {
                                                        let premiumScreen = PremiumIntroScreen(context: context, source: .pinnedChats)
                                                        replaceImpl?(premiumScreen)
                                                        return true
                                                    })
                                                    chatListController?.push(controller)
                                                    replaceImpl = { [weak controller] c in
                                                        controller?.replace(with: c)
                                                    }
                                                }
                                            }
                                        }
                                    })
                                })))
                            }
                            
                            if !isSavedMessages {
                                var isMuted = false
                                if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                    isMuted = true
                                } else if case .default = notificationSettings.muteState {
                                    if case .user = peer {
                                        isMuted = !globalNotificationSettings.privateChats.enabled
                                    } else if case .legacyGroup = peer {
                                        isMuted = !globalNotificationSettings.groupChats.enabled
                                    } else if case let .channel(channel) = peer {
                                        switch channel.info {
                                        case .group:
                                            isMuted = !globalNotificationSettings.groupChats.enabled
                                        case .broadcast:
                                            isMuted = !globalNotificationSettings.channels.enabled
                                        }
                                    }
                                }
                                items.append(.action(ContextMenuActionItem(text: isMuted ? strings.ChatList_Context_Unmute : strings.ChatList_Context_Mute, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: isMuted ? "Chat/Context Menu/Unmute" : "Chat/Context Menu/Muted"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                    let _ = (context.engine.peers.togglePeerMuted(peerId: peerId, threadId: nil)
                                             |> deliverOnMainQueue).startStandalone(completed: {
                                        f(.default)
                                    })
                                })))
                            }
                        } else {
                            if case .search = source {
                                if case let .channel(peer) = peer {
                                    let text: String
                                    if case .broadcast = peer.info {
                                        text = strings.ChatList_Context_JoinChannel
                                    } else {
                                        text = strings.ChatList_Context_JoinChat
                                    }
                                    items.append(.action(ContextMenuActionItem(text: text, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                        var createSignal = context.peerChannelMemberCategoriesContextsManager.join(engine: context.engine, peerId: peerId, hash: nil)
                                        var cancelImpl: (() -> Void)?
                                        let progressSignal = Signal<Never, NoError> { subscriber in
                                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                                cancelImpl?()
                                            }))
                                            chatListController?.present(controller, in: .window(.root))
                                            return ActionDisposable { [weak controller] in
                                                Queue.mainQueue().async() {
                                                    controller?.dismiss()
                                                }
                                            }
                                        }
                                        |> runOn(Queue.mainQueue())
                                        |> delay(0.15, queue: Queue.mainQueue())
                                        let progressDisposable = progressSignal.start()
                                        
                                        createSignal = createSignal
                                        |> afterDisposed {
                                            Queue.mainQueue().async {
                                                progressDisposable.dispose()
                                            }
                                        }
                                        let joinChannelDisposable = MetaDisposable()
                                        cancelImpl = {
                                            joinChannelDisposable.set(nil)
                                        }
                                        
                                        joinChannelDisposable.set((createSignal
                                                                   |> deliverOnMainQueue).start(next: { _ in
                                        }, error: { _ in
                                            if let chatListController = chatListController {
                                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                                chatListController.present(textAlertController(context: context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                            }
                                        }, completed: {
                                            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                                                     |> deliverOnMainQueue).startStandalone(next: { peer in
                                                guard let peer = peer else {
                                                    return
                                                }
                                                if let navigationController = (chatListController?.navigationController as? NavigationController) {
                                                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
                                                }
                                            })
                                        }))
                                        f(.default)
                                    })))
                                }
                            }
                        }
                        
                        if case .chatList = source, peerGroup != nil {
                            items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_Delete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                                if let chatListController = chatListController {
                                    chatListController.deletePeerChat(peerId: peerId, joined: joined)
                                }
                                f(.default)
                            })))
                        } else if case let .search(search) = source {
                            switch search {
                            case .recentPeers, .search:
                                var addedSeparator = false
                                if case let .recentPeers(isTopPeer) = search {
                                    if isTopPeer {
                                        if !items.isEmpty {
                                            if !addedSeparator {
                                                items.append(.separator)
                                                addedSeparator = true
                                            }
                                        }
                                        items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_RemoveFromRecents, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                                            let _ = (context.engine.peers.removeRecentPeer(peerId: peerId)
                                            |> deliverOnMainQueue).startStandalone(completed: {
                                                f(.default)
                                            })
                                        })))
                                    }
                                }
                                
                                if peerGroup != nil {
                                    if !items.isEmpty {
                                        if !addedSeparator {
                                            items.append(.separator)
                                            addedSeparator = true
                                        }
                                    }
                                    items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_Delete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                                        if let chatListController = chatListController {
                                            chatListController.deletePeerChat(peerId: peerId, joined: joined)
                                        }
                                        f(.default)
                                    })))
                                }
                            default:
                                 break
                            }
                        }
                    }

                    if let item = items.last, case .separator = item {
                        items.removeLast()
                    }

                    return items
                }
            }
        }
    }
}

public func chatForumTopicMenuItems(context: AccountContext, peerId: PeerId, threadId: Int64, isPinned: Bool?, isClosed: Bool?, chatListController: ViewController?, joined: Bool, canSelect: Bool, customEdit: ((ContextController) -> Void)? = nil, customPinUnpin: ((ContextController) -> Void)? = nil, reorder: (() -> Void)? = nil) -> Signal<[ContextMenuItem], NoError> {
    let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
    let strings = presentationData.strings

    return context.engine.data.get(
        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
        TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId),
        TelegramEngine.EngineData.Item.Peer.ThreadData(id: peerId, threadId: threadId),
        TelegramEngine.EngineData.Item.NotificationSettings.Global()
    )
    |> mapToSignal { peer, peerNotificationSettings, threadData, globalNotificationSettings -> Signal<[ContextMenuItem], NoError> in
        guard case let .channel(channel) = peer else {
            return .single([])
        }
        guard let threadData = threadData else {
            return .single([])
        }
        
        var items: [ContextMenuItem] = []
        
        if let isClosed = isClosed, isClosed && threadId != 1 {
        } else {
            if let isPinned, channel.hasPermission(.manageTopics) {
                items.append(.action(ContextMenuActionItem(text: isPinned ? presentationData.strings.ChatList_Context_Unpin : presentationData.strings.ChatList_Context_Pin, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: isPinned ? "Chat/Context Menu/Unpin": "Chat/Context Menu/Pin"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                    if let customPinUnpin {
                        if let c = c as? ContextController {
                            customPinUnpin(c)
                        } else {
                            f(.default)
                        }
                        return
                    }
                    
                    f(.default)
                    
                    let _ = (context.engine.peers.toggleForumChannelTopicPinned(id: peerId, threadId: threadId)
                    |> deliverOnMainQueue).startStandalone(error: { error in
                        switch error {
                        case let .limitReached(count):
                            if let chatListController = chatListController {
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                let text = presentationData.strings.ChatList_MaxThreadPinsFinalText(Int32(count))
                                chatListController.present(textAlertController(context: context, title: presentationData.strings.Premium_LimitReached, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})], parseMarkdown: true), in: .window(.root))
                            }
                        default:
                            break
                        }
                    })
                })))
                
                if isPinned, let reorder {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.Chat_InlineTopicMenu_Reorder, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReorderItems"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c?.dismiss(completion: {
                        })
                        reorder()
                    })))
                }
            }
        }
        
        var isUnread = false
        if threadData.incomingUnreadCount != 0 {
            isUnread = true
        }
        
        if isUnread {
            items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_MarkAsRead, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsRead"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                let _ = context.engine.messages.markForumThreadAsRead(peerId: peerId, threadId: threadId).startStandalone()
                f(.default)
            })))
        }
        
        var canOpenClose = false
        if channel.flags.contains(.isCreator) {
            canOpenClose = true
        } else if channel.hasPermission(.manageTopics) {
            canOpenClose = true
        } else if threadData.isOwnedByMe {
            canOpenClose = true
        }
        
        if threadId != 1, canOpenClose, let customEdit {
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Chat_InlineTopicMenu_Edit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                if let c = c as? ContextController {
                    customEdit(c)
                } else {
                    f(.default)
                }
                return
            })))
        }
        
        var isMuted = false
        switch threadData.notificationSettings.muteState {
        case .muted:
            isMuted = true
        case .unmuted:
            isMuted = false
        case .default:
            var peerIsMuted = false
            if case let .muted(until) = peerNotificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                peerIsMuted = true
            } else if case .default = peerNotificationSettings.muteState {
                if case let .channel(channel) = peer, case .group = channel.info {
                    peerIsMuted = !globalNotificationSettings.groupChats.enabled
                }
            }
            isMuted = peerIsMuted
        }
        items.append(.action(ContextMenuActionItem(text: isMuted ? strings.ChatList_Context_Unmute : strings.ChatList_Context_Mute, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: isMuted ? "Chat/Context Menu/Unmute" : "Chat/Context Menu/Muted"), color: theme.contextMenu.primaryColor) }, action: { [weak chatListController] c, f in
            if isMuted {
                let _ = (context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: 0)
                |> deliverOnMainQueue).startStandalone(completed: {
                    f(.default)
                })
            } else {
                var items: [ContextMenuItem] = []
                
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_MuteFor, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Mute2d"), color: theme.contextMenu.primaryColor)
                }, action: { c, _ in
                    var subItems: [ContextMenuItem] = []
                    
                    /*subItems.append(.action(ContextMenuActionItem(text: presentationData.strings.Common_Back, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                    }, action: { c, _ in
                        c?.popItems()
                    })))
                    subItems.append(.separator)*/
                    
                    let presetValues: [Int32] = [
                        1 * 60 * 60,
                        8 * 60 * 60,
                        1 * 24 * 60 * 60,
                        7 * 24 * 60 * 60
                    ]
                    
                    for value in presetValues {
                        subItems.append(.action(ContextMenuActionItem(text: muteForIntervalString(strings: presentationData.strings, value: value), icon: { _ in
                            return nil
                        }, action: { _, f in
                            f(.default)
                            
                            let _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: value).startStandalone()
                            
                            chatListController?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_mute_for", scale: 0.066, colors: [:], title: nil, text: presentationData.strings.PeerInfo_TooltipMutedFor(mutedForTimeIntervalString(strings: presentationData.strings, value: value)).string, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                        })))
                    }
                    
                    subItems.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_MuteForCustom, icon: { _ in
                        return nil
                    }, action: { _, f in
                        f(.default)
                        
                        if let chatListController = chatListController {
                            openCustomMute(context: context, peerId: peerId, threadId: threadId, baseController: chatListController)
                        }
                    })))
                    
                    c?.setItems(.single(ContextController.Items(content: .list(subItems))), minHeight: nil, animated: true)
                })))
                
                items.append(.separator)
                
                var isSoundEnabled = true
                switch threadData.notificationSettings.messageSound {
                case .none:
                    isSoundEnabled = false
                default:
                    break
                }
                
                if case .muted = threadData.notificationSettings.muteState {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_ButtonUnmute, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SoundOn"), color: theme.contextMenu.primaryColor)
                    }, action: { _, f in
                        f(.default)
                        
                        let _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: nil).startStandalone()
                        
                        let iconColor: UIColor = .white
                        chatListController?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_profileunmute", scale: 0.075, colors: [
                                "Middle.Group 1.Fill 1": iconColor,
                                "Top.Group 1.Fill 1": iconColor,
                                "Bottom.Group 1.Fill 1": iconColor,
                                "EXAMPLE.Group 1.Fill 1": iconColor,
                                "Line.Group 1.Stroke 1": iconColor
                        ], title: nil, text: presentationData.strings.PeerInfo_TooltipUnmuted, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                    })))
                } else if !isSoundEnabled {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_EnableSound, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SoundOn"), color: theme.contextMenu.primaryColor)
                    }, action: { _, f in
                        f(.default)
                        
                        let _ = context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: threadId, sound: .default).startStandalone()
                        
                        chatListController?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_sound_on", scale: 0.056, colors: [:], title: nil, text: presentationData.strings.PeerInfo_TooltipSoundEnabled, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                    })))
                } else {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_DisableSound, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SoundOff"), color: theme.contextMenu.primaryColor)
                    }, action: { _, f in
                        f(.default)
                        
                        let _ = context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: threadId, sound: .none).startStandalone()
                        
                        chatListController?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_sound_off", scale: 0.056, colors: [:], title: nil, text: presentationData.strings.PeerInfo_TooltipSoundDisabled, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                    })))
                }
                
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_NotificationsCustomize, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Customize"), color: theme.contextMenu.primaryColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    let _ = (context.engine.data.get(
                        TelegramEngine.EngineData.Item.NotificationSettings.Global()
                    )
                    |> deliverOnMainQueue).startStandalone(next: { globalSettings in
                        let updatePeerSound: (PeerId, PeerMessageSound) -> Signal<Void, NoError> = { peerId, sound in
                            return context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: threadId, sound: sound) |> deliverOnMainQueue
                        }
                        
                        let updatePeerNotificationInterval: (PeerId, Int32?) -> Signal<Void, NoError> = { peerId, muteInterval in
                            return context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: muteInterval) |> deliverOnMainQueue
                        }
                        
                        let updatePeerDisplayPreviews: (PeerId, PeerNotificationDisplayPreviews) -> Signal<Void, NoError> = {
                            peerId, displayPreviews in
                            return context.engine.peers.updatePeerDisplayPreviewsSetting(peerId: peerId, threadId: threadId, displayPreviews: displayPreviews) |> deliverOnMainQueue
                        }
                        
                        let updatePeerStoriesMuted: (PeerId, PeerStoryNotificationSettings.Mute) -> Signal<Void, NoError> = {
                            peerId, mute in
                            return context.engine.peers.updatePeerStoriesMutedSetting(peerId: peerId, mute: mute) |> deliverOnMainQueue
                        }
                        
                        let updatePeerStoriesHideSender: (PeerId, PeerStoryNotificationSettings.HideSender) -> Signal<Void, NoError> = {
                            peerId, hideSender in
                            return context.engine.peers.updatePeerStoriesHideSenderSetting(peerId: peerId, hideSender: hideSender) |> deliverOnMainQueue
                        }
                        
                        let updatePeerStorySound: (PeerId, PeerMessageSound) -> Signal<Void, NoError> = { peerId, sound in
                            return context.engine.peers.updatePeerStorySoundInteractive(peerId: peerId, sound: sound) |> deliverOnMainQueue
                        }
                        
                        let defaultSound: PeerMessageSound
                        
                        if case .broadcast = channel.info {
                            defaultSound = globalSettings.channels.sound._asMessageSound()
                        } else {
                            defaultSound = globalSettings.groupChats.sound._asMessageSound()
                        }
                        
                        let canRemove = false
                        
                        let exceptionController = notificationPeerExceptionController(context: context, updatedPresentationData: nil, peer: .channel(channel), threadId: threadId, isStories: nil, canRemove: canRemove, defaultSound: defaultSound, defaultStoriesSound: defaultSound, edit: true, updatePeerSound: { peerId, sound in
                            let _ = (updatePeerSound(peerId, sound)
                            |> deliverOnMainQueue).startStandalone(next: { _ in
                            })
                        }, updatePeerNotificationInterval: { peerId, muteInterval in
                            let _ = (updatePeerNotificationInterval(peerId, muteInterval)
                            |> deliverOnMainQueue).startStandalone(next: { _ in
                                if let muteInterval = muteInterval, muteInterval == Int32.max {
                                    let iconColor: UIColor = .white
                                    chatListController?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_profilemute", scale: 0.075, colors: [
                                        "Middle.Group 1.Fill 1": iconColor,
                                        "Top.Group 1.Fill 1": iconColor,
                                        "Bottom.Group 1.Fill 1": iconColor,
                                        "EXAMPLE.Group 1.Fill 1": iconColor,
                                        "Line.Group 1.Stroke 1": iconColor
                                    ], title: nil, text: presentationData.strings.PeerInfo_TooltipMutedForever, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                                }
                            })
                        }, updatePeerDisplayPreviews: { peerId, displayPreviews in
                            let _ = (updatePeerDisplayPreviews(peerId, displayPreviews)
                            |> deliverOnMainQueue).startStandalone(next: { _ in
                                
                            })
                        }, updatePeerStoriesMuted: { peerId, mute in
                            let _ = (updatePeerStoriesMuted(peerId, mute)
                            |> deliverOnMainQueue).startStandalone()
                        }, updatePeerStoriesHideSender: { peerId, hideSender in
                            let _ = (updatePeerStoriesHideSender(peerId, hideSender)
                            |> deliverOnMainQueue).startStandalone()
                        }, updatePeerStorySound: { peerId, sound in
                            let _ = (updatePeerStorySound(peerId, sound)
                            |> deliverOnMainQueue).startStandalone()
                        }, removePeerFromExceptions: {
                        }, modifiedPeer: {
                        })
                        exceptionController.navigationPresentation = .modal
                        chatListController?.push(exceptionController)
                    })
                })))
                
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_MuteForever, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Muted"), color: theme.contextMenu.destructiveColor)
                }, action: { _, f in
                    f(.default)
                    
                    let _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: Int32.max).startStandalone()
                    
                    let iconColor: UIColor = .white
                    chatListController?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_profilemute", scale: 0.075, colors: [
                        "Middle.Group 1.Fill 1": iconColor,
                        "Top.Group 1.Fill 1": iconColor,
                        "Bottom.Group 1.Fill 1": iconColor,
                        "EXAMPLE.Group 1.Fill 1": iconColor,
                        "Line.Group 1.Stroke 1": iconColor
                ], title: nil, text: presentationData.strings.PeerInfo_TooltipMutedForever, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                })))
                
                c?.setItems(.single(ContextController.Items(content: .list(items))), minHeight: nil, animated: true)
            }
        })))
        
        if threadId != 1 {
            if canOpenClose {
                items.append(.action(ContextMenuActionItem(text: threadData.isClosed ? presentationData.strings.ChatList_Context_ReopenTopic : presentationData.strings.ChatList_Context_CloseTopic, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: threadData.isClosed ? "Chat/Context Menu/Play": "Chat/Context Menu/Pause"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    f(.default)
                    
                    let _ = context.engine.peers.setForumChannelTopicClosed(id: peerId, threadId: threadId, isClosed: !threadData.isClosed).startStandalone()
                })))
            }
            if channel.hasPermission(.deleteAllMessages) {
                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_Delete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak chatListController] _, f in
                    f(.default)
                    
                    if let chatListController = chatListController as? ChatListControllerImpl {
                        chatListController.deletePeerThread(peerId: peerId, threadId: threadId)
                    } else if let chatListController {
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        var items: [ActionSheetItem] = []
                        
                        items.append(ActionSheetTextItem(title: presentationData.strings.ChatList_DeleteTopicConfirmationText, parseMarkdown: true))
                        items.append(ActionSheetButtonItem(title: presentationData.strings.ChatList_DeleteTopicConfirmationAction, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            let _ = context.engine.peers.removeForumChannelThread(id: peerId, threadId: threadId).startStandalone(completed: {
                            })
                        }))
                        
                        actionSheet.setItemGroups([
                            ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])
                        ])
                        chatListController.present(actionSheet, in: .window(.root))
                    }
                })))
            }
        }
        
        if canSelect, let chatListController = chatListController as? ChatListControllerImpl {
            items.append(.separator)
            items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_Select, textColor: .primary, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor) }, action: { [weak chatListController] _, f in
                f(.default)
                chatListController?.selectPeerThread(peerId: peerId, threadId: threadId)
            })))
        }
        
        return .single(items)
    }
}

public func savedMessagesPeerMenuItems(context: AccountContext, threadId: Int64, parentController: ViewController, deletePeerChat: @escaping (EnginePeer.Id) -> Void) -> Signal<[ContextMenuItem], NoError> {
    let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
    let strings = presentationData.strings

    return combineLatest(
        context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: PeerId(threadId))
        ),
        context.account.postbox.transaction { transaction -> [Int64] in
            return transaction.getPeerPinnedThreads(peerId: context.account.peerId)
        }
    )
    |> mapToSignal { [weak parentController] peer, pinnedThreadIds -> Signal<[ContextMenuItem], NoError> in
        var items: [ContextMenuItem] = []
        
        let isPinned = pinnedThreadIds.contains(threadId)
        
        items.append(.action(ContextMenuActionItem(text: isPinned ? strings.ChatList_Context_Unpin : strings.ChatList_Context_Pin, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: isPinned ? "Chat/Context Menu/Unpin": "Chat/Context Menu/Pin"), color: theme.contextMenu.primaryColor) }, action: { _, f in
            f(.default)
            
            let _ = (context.engine.peers.toggleForumChannelTopicPinned(id: context.account.peerId, threadId: threadId)
            |> deliverOnMainQueue).startStandalone(error: { error in
                switch error {
                case let .limitReached(count):
                    var replaceImpl: ((ViewController) -> Void)?
                    let controller = PremiumLimitScreen(context: context, subject: .pinnedSavedPeers, count: Int32(count), action: {
                        let controller = PremiumIntroScreen(context: context, source: .pinnedChats)
                        replaceImpl?(controller)
                        return true
                    })
                    replaceImpl = { [weak controller] c in
                        controller?.replace(with: c)
                    }
                    parentController?.push(controller)
                default:
                    break
                }
            })
        })))
        
        items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_Delete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                deletePeerChat(PeerId(threadId))
            f(.default)
        })))
        
        return .single(items)
    }
}

private func openCustomMute(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64, baseController: ViewController) {
    let controller = ChatTimerScreen(context: context, updatedPresentationData: nil, style: .default, mode: .mute, currentTime: nil, dismissByTapOutside: true, completion: { [weak baseController] value in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        if value <= 0 {
            let _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: nil).startStandalone()
        } else {
            let _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: value).startStandalone()
            
            let timeString = stringForPreciseRelativeTimestamp(strings: presentationData.strings, relativeTimestamp: Int32(Date().timeIntervalSince1970) + value, relativeTo: Int32(Date().timeIntervalSince1970), dateTimeFormat: presentationData.dateTimeFormat)
            
            baseController?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_mute_for", scale: 0.056, colors: [:], title: nil, text: presentationData.strings.PeerInfo_TooltipMutedUntil(timeString).string, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
        }
    })
    baseController.view.endEditing(true)
    baseController.present(controller, in: .window(.root))
}
