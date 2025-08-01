public extension Api {
    enum SavedContact: TypeConstructorDescription {
        case savedPhoneContact(phone: String, firstName: String, lastName: String, date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedPhoneContact(let phone, let firstName, let lastName, let date):
                    if boxed {
                        buffer.appendInt32(289586518)
                    }
                    serializeString(phone, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedPhoneContact(let phone, let firstName, let lastName, let date):
                return ("savedPhoneContact", [("phone", phone as Any), ("firstName", firstName as Any), ("lastName", lastName as Any), ("date", date as Any)])
    }
    }
    
        public static func parse_savedPhoneContact(_ reader: BufferReader) -> SavedContact? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.SavedContact.savedPhoneContact(phone: _1!, firstName: _2!, lastName: _3!, date: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum SavedDialog: TypeConstructorDescription {
        case monoForumDialog(flags: Int32, peer: Api.Peer, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadReactionsCount: Int32, draft: Api.DraftMessage?)
        case savedDialog(flags: Int32, peer: Api.Peer, topMessage: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .monoForumDialog(let flags, let peer, let topMessage, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let unreadReactionsCount, let draft):
                    if boxed {
                        buffer.appendInt32(1681948327)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(topMessage, buffer: buffer, boxed: false)
                    serializeInt32(readInboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(readOutboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(unreadCount, buffer: buffer, boxed: false)
                    serializeInt32(unreadReactionsCount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {draft!.serialize(buffer, true)}
                    break
                case .savedDialog(let flags, let peer, let topMessage):
                    if boxed {
                        buffer.appendInt32(-1115174036)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(topMessage, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .monoForumDialog(let flags, let peer, let topMessage, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let unreadReactionsCount, let draft):
                return ("monoForumDialog", [("flags", flags as Any), ("peer", peer as Any), ("topMessage", topMessage as Any), ("readInboxMaxId", readInboxMaxId as Any), ("readOutboxMaxId", readOutboxMaxId as Any), ("unreadCount", unreadCount as Any), ("unreadReactionsCount", unreadReactionsCount as Any), ("draft", draft as Any)])
                case .savedDialog(let flags, let peer, let topMessage):
                return ("savedDialog", [("flags", flags as Any), ("peer", peer as Any), ("topMessage", topMessage as Any)])
    }
    }
    
        public static func parse_monoForumDialog(_ reader: BufferReader) -> SavedDialog? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Api.DraftMessage?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.DraftMessage
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 1) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.SavedDialog.monoForumDialog(flags: _1!, peer: _2!, topMessage: _3!, readInboxMaxId: _4!, readOutboxMaxId: _5!, unreadCount: _6!, unreadReactionsCount: _7!, draft: _8)
            }
            else {
                return nil
            }
        }
        public static func parse_savedDialog(_ reader: BufferReader) -> SavedDialog? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SavedDialog.savedDialog(flags: _1!, peer: _2!, topMessage: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SavedReactionTag: TypeConstructorDescription {
        case savedReactionTag(flags: Int32, reaction: Api.Reaction, title: String?, count: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedReactionTag(let flags, let reaction, let title, let count):
                    if boxed {
                        buffer.appendInt32(-881854424)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    reaction.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedReactionTag(let flags, let reaction, let title, let count):
                return ("savedReactionTag", [("flags", flags as Any), ("reaction", reaction as Any), ("title", title as Any), ("count", count as Any)])
    }
    }
    
        public static func parse_savedReactionTag(_ reader: BufferReader) -> SavedReactionTag? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Reaction?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.SavedReactionTag.savedReactionTag(flags: _1!, reaction: _2!, title: _3, count: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SavedStarGift: TypeConstructorDescription {
        case savedStarGift(flags: Int32, fromId: Api.Peer?, date: Int32, gift: Api.StarGift, message: Api.TextWithEntities?, msgId: Int32?, savedId: Int64?, convertStars: Int64?, upgradeStars: Int64?, canExportAt: Int32?, transferStars: Int64?, canTransferAt: Int32?, canResellAt: Int32?, collectionId: [Int32]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedStarGift(let flags, let fromId, let date, let gift, let message, let msgId, let savedId, let convertStars, let upgradeStars, let canExportAt, let transferStars, let canTransferAt, let canResellAt, let collectionId):
                    if boxed {
                        buffer.appendInt32(514213599)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {fromId!.serialize(buffer, true)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    gift.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {message!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(msgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt64(savedId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt64(convertStars!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeInt64(upgradeStars!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 7) != 0 {serializeInt32(canExportAt!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeInt64(transferStars!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {serializeInt32(canTransferAt!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 14) != 0 {serializeInt32(canResellAt!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 15) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(collectionId!.count))
                    for item in collectionId! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedStarGift(let flags, let fromId, let date, let gift, let message, let msgId, let savedId, let convertStars, let upgradeStars, let canExportAt, let transferStars, let canTransferAt, let canResellAt, let collectionId):
                return ("savedStarGift", [("flags", flags as Any), ("fromId", fromId as Any), ("date", date as Any), ("gift", gift as Any), ("message", message as Any), ("msgId", msgId as Any), ("savedId", savedId as Any), ("convertStars", convertStars as Any), ("upgradeStars", upgradeStars as Any), ("canExportAt", canExportAt as Any), ("transferStars", transferStars as Any), ("canTransferAt", canTransferAt as Any), ("canResellAt", canResellAt as Any), ("collectionId", collectionId as Any)])
    }
    }
    
        public static func parse_savedStarGift(_ reader: BufferReader) -> SavedStarGift? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.StarGift?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StarGift
            }
            var _5: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            } }
            var _6: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_6 = reader.readInt32() }
            var _7: Int64?
            if Int(_1!) & Int(1 << 11) != 0 {_7 = reader.readInt64() }
            var _8: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {_8 = reader.readInt64() }
            var _9: Int64?
            if Int(_1!) & Int(1 << 6) != 0 {_9 = reader.readInt64() }
            var _10: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {_10 = reader.readInt32() }
            var _11: Int64?
            if Int(_1!) & Int(1 << 8) != 0 {_11 = reader.readInt64() }
            var _12: Int32?
            if Int(_1!) & Int(1 << 13) != 0 {_12 = reader.readInt32() }
            var _13: Int32?
            if Int(_1!) & Int(1 << 14) != 0 {_13 = reader.readInt32() }
            var _14: [Int32]?
            if Int(_1!) & Int(1 << 15) != 0 {if let _ = reader.readInt32() {
                _14 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 11) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 7) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 8) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 13) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 14) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 15) == 0) || _14 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 {
                return Api.SavedStarGift.savedStarGift(flags: _1!, fromId: _2, date: _3!, gift: _4!, message: _5, msgId: _6, savedId: _7, convertStars: _8, upgradeStars: _9, canExportAt: _10, transferStars: _11, canTransferAt: _12, canResellAt: _13, collectionId: _14)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SearchPostsFlood: TypeConstructorDescription {
        case searchPostsFlood(flags: Int32, totalDaily: Int32, remains: Int32, waitTill: Int32?, starsAmount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .searchPostsFlood(let flags, let totalDaily, let remains, let waitTill, let starsAmount):
                    if boxed {
                        buffer.appendInt32(1040931690)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(totalDaily, buffer: buffer, boxed: false)
                    serializeInt32(remains, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(waitTill!, buffer: buffer, boxed: false)}
                    serializeInt64(starsAmount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .searchPostsFlood(let flags, let totalDaily, let remains, let waitTill, let starsAmount):
                return ("searchPostsFlood", [("flags", flags as Any), ("totalDaily", totalDaily as Any), ("remains", remains as Any), ("waitTill", waitTill as Any), ("starsAmount", starsAmount as Any)])
    }
    }
    
        public static func parse_searchPostsFlood(_ reader: BufferReader) -> SearchPostsFlood? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            var _5: Int64?
            _5 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.SearchPostsFlood.searchPostsFlood(flags: _1!, totalDaily: _2!, remains: _3!, waitTill: _4, starsAmount: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SearchResultsCalendarPeriod: TypeConstructorDescription {
        case searchResultsCalendarPeriod(date: Int32, minMsgId: Int32, maxMsgId: Int32, count: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .searchResultsCalendarPeriod(let date, let minMsgId, let maxMsgId, let count):
                    if boxed {
                        buffer.appendInt32(-911191137)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(minMsgId, buffer: buffer, boxed: false)
                    serializeInt32(maxMsgId, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .searchResultsCalendarPeriod(let date, let minMsgId, let maxMsgId, let count):
                return ("searchResultsCalendarPeriod", [("date", date as Any), ("minMsgId", minMsgId as Any), ("maxMsgId", maxMsgId as Any), ("count", count as Any)])
    }
    }
    
        public static func parse_searchResultsCalendarPeriod(_ reader: BufferReader) -> SearchResultsCalendarPeriod? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.SearchResultsCalendarPeriod.searchResultsCalendarPeriod(date: _1!, minMsgId: _2!, maxMsgId: _3!, count: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SearchResultsPosition: TypeConstructorDescription {
        case searchResultPosition(msgId: Int32, date: Int32, offset: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .searchResultPosition(let msgId, let date, let offset):
                    if boxed {
                        buffer.appendInt32(2137295719)
                    }
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .searchResultPosition(let msgId, let date, let offset):
                return ("searchResultPosition", [("msgId", msgId as Any), ("date", date as Any), ("offset", offset as Any)])
    }
    }
    
        public static func parse_searchResultPosition(_ reader: BufferReader) -> SearchResultsPosition? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SearchResultsPosition.searchResultPosition(msgId: _1!, date: _2!, offset: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureCredentialsEncrypted: TypeConstructorDescription {
        case secureCredentialsEncrypted(data: Buffer, hash: Buffer, secret: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureCredentialsEncrypted(let data, let hash, let secret):
                    if boxed {
                        buffer.appendInt32(871426631)
                    }
                    serializeBytes(data, buffer: buffer, boxed: false)
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureCredentialsEncrypted(let data, let hash, let secret):
                return ("secureCredentialsEncrypted", [("data", data as Any), ("hash", hash as Any), ("secret", secret as Any)])
    }
    }
    
        public static func parse_secureCredentialsEncrypted(_ reader: BufferReader) -> SecureCredentialsEncrypted? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureCredentialsEncrypted.secureCredentialsEncrypted(data: _1!, hash: _2!, secret: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureData: TypeConstructorDescription {
        case secureData(data: Buffer, dataHash: Buffer, secret: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureData(let data, let dataHash, let secret):
                    if boxed {
                        buffer.appendInt32(-1964327229)
                    }
                    serializeBytes(data, buffer: buffer, boxed: false)
                    serializeBytes(dataHash, buffer: buffer, boxed: false)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureData(let data, let dataHash, let secret):
                return ("secureData", [("data", data as Any), ("dataHash", dataHash as Any), ("secret", secret as Any)])
    }
    }
    
        public static func parse_secureData(_ reader: BufferReader) -> SecureData? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureData.secureData(data: _1!, dataHash: _2!, secret: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureFile: TypeConstructorDescription {
        case secureFile(id: Int64, accessHash: Int64, size: Int64, dcId: Int32, date: Int32, fileHash: Buffer, secret: Buffer)
        case secureFileEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureFile(let id, let accessHash, let size, let dcId, let date, let fileHash, let secret):
                    if boxed {
                        buffer.appendInt32(2097791614)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt64(size, buffer: buffer, boxed: false)
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    break
                case .secureFileEmpty:
                    if boxed {
                        buffer.appendInt32(1679398724)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureFile(let id, let accessHash, let size, let dcId, let date, let fileHash, let secret):
                return ("secureFile", [("id", id as Any), ("accessHash", accessHash as Any), ("size", size as Any), ("dcId", dcId as Any), ("date", date as Any), ("fileHash", fileHash as Any), ("secret", secret as Any)])
                case .secureFileEmpty:
                return ("secureFileEmpty", [])
    }
    }
    
        public static func parse_secureFile(_ reader: BufferReader) -> SecureFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: Buffer?
            _7 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.SecureFile.secureFile(id: _1!, accessHash: _2!, size: _3!, dcId: _4!, date: _5!, fileHash: _6!, secret: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureFileEmpty(_ reader: BufferReader) -> SecureFile? {
            return Api.SecureFile.secureFileEmpty
        }
    
    }
}
public extension Api {
    enum SecurePasswordKdfAlgo: TypeConstructorDescription {
        case securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(salt: Buffer)
        case securePasswordKdfAlgoSHA512(salt: Buffer)
        case securePasswordKdfAlgoUnknown
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(let salt):
                    if boxed {
                        buffer.appendInt32(-1141711456)
                    }
                    serializeBytes(salt, buffer: buffer, boxed: false)
                    break
                case .securePasswordKdfAlgoSHA512(let salt):
                    if boxed {
                        buffer.appendInt32(-2042159726)
                    }
                    serializeBytes(salt, buffer: buffer, boxed: false)
                    break
                case .securePasswordKdfAlgoUnknown:
                    if boxed {
                        buffer.appendInt32(4883767)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(let salt):
                return ("securePasswordKdfAlgoPBKDF2HMACSHA512iter100000", [("salt", salt as Any)])
                case .securePasswordKdfAlgoSHA512(let salt):
                return ("securePasswordKdfAlgoSHA512", [("salt", salt as Any)])
                case .securePasswordKdfAlgoUnknown:
                return ("securePasswordKdfAlgoUnknown", [])
    }
    }
    
        public static func parse_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePasswordKdfAlgo.securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(salt: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_securePasswordKdfAlgoSHA512(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePasswordKdfAlgo.securePasswordKdfAlgoSHA512(salt: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_securePasswordKdfAlgoUnknown(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            return Api.SecurePasswordKdfAlgo.securePasswordKdfAlgoUnknown
        }
    
    }
}
public extension Api {
    enum SecurePlainData: TypeConstructorDescription {
        case securePlainEmail(email: String)
        case securePlainPhone(phone: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .securePlainEmail(let email):
                    if boxed {
                        buffer.appendInt32(569137759)
                    }
                    serializeString(email, buffer: buffer, boxed: false)
                    break
                case .securePlainPhone(let phone):
                    if boxed {
                        buffer.appendInt32(2103482845)
                    }
                    serializeString(phone, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .securePlainEmail(let email):
                return ("securePlainEmail", [("email", email as Any)])
                case .securePlainPhone(let phone):
                return ("securePlainPhone", [("phone", phone as Any)])
    }
    }
    
        public static func parse_securePlainEmail(_ reader: BufferReader) -> SecurePlainData? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePlainData.securePlainEmail(email: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_securePlainPhone(_ reader: BufferReader) -> SecurePlainData? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePlainData.securePlainPhone(phone: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureRequiredType: TypeConstructorDescription {
        case secureRequiredType(flags: Int32, type: Api.SecureValueType)
        case secureRequiredTypeOneOf(types: [Api.SecureRequiredType])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureRequiredType(let flags, let type):
                    if boxed {
                        buffer.appendInt32(-2103600678)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    type.serialize(buffer, true)
                    break
                case .secureRequiredTypeOneOf(let types):
                    if boxed {
                        buffer.appendInt32(41187252)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(types.count))
                    for item in types {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureRequiredType(let flags, let type):
                return ("secureRequiredType", [("flags", flags as Any), ("type", type as Any)])
                case .secureRequiredTypeOneOf(let types):
                return ("secureRequiredTypeOneOf", [("types", types as Any)])
    }
    }
    
        public static func parse_secureRequiredType(_ reader: BufferReader) -> SecureRequiredType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.SecureRequiredType.secureRequiredType(flags: _1!, type: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureRequiredTypeOneOf(_ reader: BufferReader) -> SecureRequiredType? {
            var _1: [Api.SecureRequiredType]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureRequiredType.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecureRequiredType.secureRequiredTypeOneOf(types: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureSecretSettings: TypeConstructorDescription {
        case secureSecretSettings(secureAlgo: Api.SecurePasswordKdfAlgo, secureSecret: Buffer, secureSecretId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureSecretSettings(let secureAlgo, let secureSecret, let secureSecretId):
                    if boxed {
                        buffer.appendInt32(354925740)
                    }
                    secureAlgo.serialize(buffer, true)
                    serializeBytes(secureSecret, buffer: buffer, boxed: false)
                    serializeInt64(secureSecretId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureSecretSettings(let secureAlgo, let secureSecret, let secureSecretId):
                return ("secureSecretSettings", [("secureAlgo", secureAlgo as Any), ("secureSecret", secureSecret as Any), ("secureSecretId", secureSecretId as Any)])
    }
    }
    
        public static func parse_secureSecretSettings(_ reader: BufferReader) -> SecureSecretSettings? {
            var _1: Api.SecurePasswordKdfAlgo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecurePasswordKdfAlgo
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureSecretSettings.secureSecretSettings(secureAlgo: _1!, secureSecret: _2!, secureSecretId: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureValue: TypeConstructorDescription {
        case secureValue(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.SecureFile?, reverseSide: Api.SecureFile?, selfie: Api.SecureFile?, translation: [Api.SecureFile]?, files: [Api.SecureFile]?, plainData: Api.SecurePlainData?, hash: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureValue(let flags, let type, let data, let frontSide, let reverseSide, let selfie, let translation, let files, let plainData, let hash):
                    if boxed {
                        buffer.appendInt32(411017418)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    type.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {data!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {frontSide!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {reverseSide!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {selfie!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(translation!.count))
                    for item in translation! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(files!.count))
                    for item in files! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 5) != 0 {plainData!.serialize(buffer, true)}
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureValue(let flags, let type, let data, let frontSide, let reverseSide, let selfie, let translation, let files, let plainData, let hash):
                return ("secureValue", [("flags", flags as Any), ("type", type as Any), ("data", data as Any), ("frontSide", frontSide as Any), ("reverseSide", reverseSide as Any), ("selfie", selfie as Any), ("translation", translation as Any), ("files", files as Any), ("plainData", plainData as Any), ("hash", hash as Any)])
    }
    }
    
        public static func parse_secureValue(_ reader: BufferReader) -> SecureValue? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _3: Api.SecureData?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.SecureData
            } }
            var _4: Api.SecureFile?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.SecureFile
            } }
            var _5: Api.SecureFile?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.SecureFile
            } }
            var _6: Api.SecureFile?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.SecureFile
            } }
            var _7: [Api.SecureFile]?
            if Int(_1!) & Int(1 << 6) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureFile.self)
            } }
            var _8: [Api.SecureFile]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureFile.self)
            } }
            var _9: Api.SecurePlainData?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.SecurePlainData
            } }
            var _10: Buffer?
            _10 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 5) == 0) || _9 != nil
            let _c10 = _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.SecureValue.secureValue(flags: _1!, type: _2!, data: _3, frontSide: _4, reverseSide: _5, selfie: _6, translation: _7, files: _8, plainData: _9, hash: _10!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureValueError: TypeConstructorDescription {
        case secureValueError(type: Api.SecureValueType, hash: Buffer, text: String)
        case secureValueErrorData(type: Api.SecureValueType, dataHash: Buffer, field: String, text: String)
        case secureValueErrorFile(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorFiles(type: Api.SecureValueType, fileHash: [Buffer], text: String)
        case secureValueErrorFrontSide(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorReverseSide(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorSelfie(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorTranslationFile(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorTranslationFiles(type: Api.SecureValueType, fileHash: [Buffer], text: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureValueError(let type, let hash, let text):
                    if boxed {
                        buffer.appendInt32(-2036501105)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorData(let type, let dataHash, let field, let text):
                    if boxed {
                        buffer.appendInt32(-391902247)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(dataHash, buffer: buffer, boxed: false)
                    serializeString(field, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorFile(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(2054162547)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorFiles(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(1717706985)
                    }
                    type.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(fileHash.count))
                    for item in fileHash {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorFrontSide(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(12467706)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorReverseSide(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(-2037765467)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorSelfie(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(-449327402)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorTranslationFile(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(-1592506512)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorTranslationFiles(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(878931416)
                    }
                    type.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(fileHash.count))
                    for item in fileHash {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureValueError(let type, let hash, let text):
                return ("secureValueError", [("type", type as Any), ("hash", hash as Any), ("text", text as Any)])
                case .secureValueErrorData(let type, let dataHash, let field, let text):
                return ("secureValueErrorData", [("type", type as Any), ("dataHash", dataHash as Any), ("field", field as Any), ("text", text as Any)])
                case .secureValueErrorFile(let type, let fileHash, let text):
                return ("secureValueErrorFile", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
                case .secureValueErrorFiles(let type, let fileHash, let text):
                return ("secureValueErrorFiles", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
                case .secureValueErrorFrontSide(let type, let fileHash, let text):
                return ("secureValueErrorFrontSide", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
                case .secureValueErrorReverseSide(let type, let fileHash, let text):
                return ("secureValueErrorReverseSide", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
                case .secureValueErrorSelfie(let type, let fileHash, let text):
                return ("secureValueErrorSelfie", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
                case .secureValueErrorTranslationFile(let type, let fileHash, let text):
                return ("secureValueErrorTranslationFile", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
                case .secureValueErrorTranslationFiles(let type, let fileHash, let text):
                return ("secureValueErrorTranslationFiles", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
    }
    }
    
        public static func parse_secureValueError(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueError(type: _1!, hash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorData(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.SecureValueError.secureValueErrorData(type: _1!, dataHash: _2!, field: _3!, text: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorFile(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorFile(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorFiles(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: [Buffer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorFiles(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorFrontSide(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorFrontSide(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorReverseSide(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorReverseSide(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorSelfie(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorSelfie(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorTranslationFile(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorTranslationFile(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorTranslationFiles(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: [Buffer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorTranslationFiles(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureValueHash: TypeConstructorDescription {
        case secureValueHash(type: Api.SecureValueType, hash: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureValueHash(let type, let hash):
                    if boxed {
                        buffer.appendInt32(-316748368)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureValueHash(let type, let hash):
                return ("secureValueHash", [("type", type as Any), ("hash", hash as Any)])
    }
    }
    
        public static func parse_secureValueHash(_ reader: BufferReader) -> SecureValueHash? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.SecureValueHash.secureValueHash(type: _1!, hash: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureValueType: TypeConstructorDescription {
        case secureValueTypeAddress
        case secureValueTypeBankStatement
        case secureValueTypeDriverLicense
        case secureValueTypeEmail
        case secureValueTypeIdentityCard
        case secureValueTypeInternalPassport
        case secureValueTypePassport
        case secureValueTypePassportRegistration
        case secureValueTypePersonalDetails
        case secureValueTypePhone
        case secureValueTypeRentalAgreement
        case secureValueTypeTemporaryRegistration
        case secureValueTypeUtilityBill
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureValueTypeAddress:
                    if boxed {
                        buffer.appendInt32(-874308058)
                    }
                    
                    break
                case .secureValueTypeBankStatement:
                    if boxed {
                        buffer.appendInt32(-1995211763)
                    }
                    
                    break
                case .secureValueTypeDriverLicense:
                    if boxed {
                        buffer.appendInt32(115615172)
                    }
                    
                    break
                case .secureValueTypeEmail:
                    if boxed {
                        buffer.appendInt32(-1908627474)
                    }
                    
                    break
                case .secureValueTypeIdentityCard:
                    if boxed {
                        buffer.appendInt32(-1596951477)
                    }
                    
                    break
                case .secureValueTypeInternalPassport:
                    if boxed {
                        buffer.appendInt32(-1717268701)
                    }
                    
                    break
                case .secureValueTypePassport:
                    if boxed {
                        buffer.appendInt32(1034709504)
                    }
                    
                    break
                case .secureValueTypePassportRegistration:
                    if boxed {
                        buffer.appendInt32(-1713143702)
                    }
                    
                    break
                case .secureValueTypePersonalDetails:
                    if boxed {
                        buffer.appendInt32(-1658158621)
                    }
                    
                    break
                case .secureValueTypePhone:
                    if boxed {
                        buffer.appendInt32(-1289704741)
                    }
                    
                    break
                case .secureValueTypeRentalAgreement:
                    if boxed {
                        buffer.appendInt32(-1954007928)
                    }
                    
                    break
                case .secureValueTypeTemporaryRegistration:
                    if boxed {
                        buffer.appendInt32(-368907213)
                    }
                    
                    break
                case .secureValueTypeUtilityBill:
                    if boxed {
                        buffer.appendInt32(-63531698)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureValueTypeAddress:
                return ("secureValueTypeAddress", [])
                case .secureValueTypeBankStatement:
                return ("secureValueTypeBankStatement", [])
                case .secureValueTypeDriverLicense:
                return ("secureValueTypeDriverLicense", [])
                case .secureValueTypeEmail:
                return ("secureValueTypeEmail", [])
                case .secureValueTypeIdentityCard:
                return ("secureValueTypeIdentityCard", [])
                case .secureValueTypeInternalPassport:
                return ("secureValueTypeInternalPassport", [])
                case .secureValueTypePassport:
                return ("secureValueTypePassport", [])
                case .secureValueTypePassportRegistration:
                return ("secureValueTypePassportRegistration", [])
                case .secureValueTypePersonalDetails:
                return ("secureValueTypePersonalDetails", [])
                case .secureValueTypePhone:
                return ("secureValueTypePhone", [])
                case .secureValueTypeRentalAgreement:
                return ("secureValueTypeRentalAgreement", [])
                case .secureValueTypeTemporaryRegistration:
                return ("secureValueTypeTemporaryRegistration", [])
                case .secureValueTypeUtilityBill:
                return ("secureValueTypeUtilityBill", [])
    }
    }
    
        public static func parse_secureValueTypeAddress(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeAddress
        }
        public static func parse_secureValueTypeBankStatement(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeBankStatement
        }
        public static func parse_secureValueTypeDriverLicense(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeDriverLicense
        }
        public static func parse_secureValueTypeEmail(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeEmail
        }
        public static func parse_secureValueTypeIdentityCard(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeIdentityCard
        }
        public static func parse_secureValueTypeInternalPassport(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeInternalPassport
        }
        public static func parse_secureValueTypePassport(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePassport
        }
        public static func parse_secureValueTypePassportRegistration(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePassportRegistration
        }
        public static func parse_secureValueTypePersonalDetails(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePersonalDetails
        }
        public static func parse_secureValueTypePhone(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePhone
        }
        public static func parse_secureValueTypeRentalAgreement(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeRentalAgreement
        }
        public static func parse_secureValueTypeTemporaryRegistration(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeTemporaryRegistration
        }
        public static func parse_secureValueTypeUtilityBill(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeUtilityBill
        }
    
    }
}
