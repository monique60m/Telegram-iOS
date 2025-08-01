import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import MultilineTextComponent

public protocol SparseItemGridLayer: CALayer {
    func update(size: CGSize, insets: UIEdgeInsets, displayItem: SparseItemGridDisplayItem, binding: SparseItemGridBinding, item: SparseItemGrid.Item?)
    func needsShimmer() -> Bool
    
    func getContents() -> Any?
    func setContents(_ contents: Any?)
}

public protocol SparseItemGridView: UIView {
    func update(size: CGSize, insets: UIEdgeInsets)
    func needsShimmer() -> Bool
}

public protocol SparseItemGridDisplayItem: AnyObject {
    var layer: SparseItemGridLayer? { get }
    var view: SparseItemGridView? { get }
    var blurLayer: SimpleLayer? { get }
}

public protocol SparseItemGridShimmerLayer: CALayer {
    func update(size: CGSize)
}

public protocol SparseItemGridBinding: AnyObject {
    func createLayer(item: SparseItemGrid.Item) -> SparseItemGridLayer?
    func createView() -> SparseItemGridView?
    func createShimmerLayer() -> SparseItemGridShimmerLayer?
    func bindLayers(items: [SparseItemGrid.Item], layers: [SparseItemGridDisplayItem], size: CGSize, insets: UIEdgeInsets, synchronous: SparseItemGrid.Synchronous)
    func unbindLayer(layer: SparseItemGridLayer)
    func scrollerTextForTag(tag: Int32) -> String?
    func loadHole(anchor: SparseItemGrid.HoleAnchor, at location: SparseItemGrid.HoleLocation) -> Signal<Never, NoError>
    func reorderIfPossible(item: SparseItemGrid.Item, toIndex: Int)
    func onTap(item: SparseItemGrid.Item, itemLayer: CALayer, point: CGPoint)
    func onTagTap()
    func didScroll()
    func coveringInsetOffsetUpdated(transition: ContainedViewLayoutTransition)
    func scrollingOffsetUpdated(transition: ContainedViewLayoutTransition)
    func onBeginFastScrolling()
    func getShimmerColors() -> SparseItemGrid.ShimmerColors
}

private func binarySearch(_ inputArr: [SparseItemGrid.Item], searchItem: Int) -> (index: Int?, lowerBound: Int?, upperBound: Int?) {
    var lowerIndex = 0
    var upperIndex = inputArr.count - 1

    if lowerIndex > upperIndex {
        return (nil, nil, nil)
    }

    while true {
        let currentIndex = (lowerIndex + upperIndex) / 2
        let value = inputArr[currentIndex].index

        if value == searchItem {
            return (currentIndex, nil, nil)
        } else if lowerIndex > upperIndex {
            return (nil, upperIndex >= 0 ? upperIndex : nil, lowerIndex < inputArr.count ? lowerIndex : nil)
        } else {
            if (value > searchItem) {
                upperIndex = currentIndex - 1
            } else {
                lowerIndex = currentIndex + 1
            }
        }
    }
}

private func binarySearch(_ inputArr: [SparseItemGrid.HoleAnchor], searchItem: Int) -> (index: Int?, lowerBound: Int?, upperBound: Int?) {
    var lowerIndex = 0
    var upperIndex = inputArr.count - 1

    if lowerIndex > upperIndex {
        return (nil, nil, nil)
    }

    while true {
        let currentIndex = (lowerIndex + upperIndex) / 2
        let value = inputArr[currentIndex].index

        if value == searchItem {
            return (currentIndex, nil, nil)
        } else if lowerIndex > upperIndex {
            return (nil, upperIndex >= 0 ? upperIndex : nil, lowerIndex < inputArr.count ? lowerIndex : nil)
        } else {
            if (value > searchItem) {
                upperIndex = currentIndex - 1
            } else {
                lowerIndex = currentIndex + 1
            }
        }
    }
}

private final class Shimmer {
    private var image: UIImage?
    private var colors: SparseItemGrid.ShimmerColors = SparseItemGrid.ShimmerColors(background: 0, foreground: 0)

    func update(colors: SparseItemGrid.ShimmerColors, layer: CALayer, containerSize: CGSize, frame: CGRect) {
        if self.colors != colors {
            self.colors = colors

            self.image = generateImage(CGSize(width: 1.0, height: 320.0), opaque: false, scale: 1.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(UIColor(rgb: colors.background).cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))

                context.clip(to: CGRect(origin: CGPoint(), size: size))

                let transparentColor = UIColor(argb: colors.foreground).withAlphaComponent(0.0).cgColor
                let peakColor = UIColor(argb: colors.foreground).cgColor

                var locations: [CGFloat] = [0.0, 0.5, 1.0]
                let colors: [CGColor] = [transparentColor, peakColor, transparentColor]

                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!

                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            })
        }

        if let image = self.image {
            layer.contents = image.cgImage

            let shiftedContentsRect = CGRect(origin: CGPoint(x: 0.0, y: frame.minY / containerSize.height), size: CGSize(width: 1.0, height: frame.height / containerSize.height))
            layer.contentsRect = shiftedContentsRect

            if layer.animation(forKey: "shimmer") == nil {
                let animation = CABasicAnimation(keyPath: "contentsRect.origin.y")
                animation.fromValue = 1.0 as NSNumber
                animation.toValue = -1.0 as NSNumber
                animation.isAdditive = true
                animation.repeatCount = .infinity
                animation.duration = 0.8
                animation.beginTime = layer.convertTime(1.0, from: nil)
                layer.add(animation, forKey: "shimmer")
            }
        }
    }

    final class Layer: CALayer, SparseItemGridShimmerLayer {
        override func action(forKey event: String) -> CAAction? {
            return nullAction
        }

        func update(size: CGSize) {
        }
    }
}

public final class SparseItemGrid: ASDisplayNode {
    public struct ShimmerColors: Equatable {
        public var background: UInt32
        public var foreground: UInt32

        public init(background: UInt32, foreground: UInt32) {
            self.background = background
            self.foreground = foreground
        }
    }

    public enum Synchronous {
        case semi
        case full
        case none
    }

    open class Item {
        open var id: AnyHashable {
            preconditionFailure()
        }

        open var index: Int {
            preconditionFailure()
        }

        open var tag: Int32 {
            preconditionFailure()
        }

        open var holeAnchor: HoleAnchor {
            preconditionFailure()
        }
        
        open var isReorderable: Bool {
            return false
        }

        public init() {
        }
    }

    public enum HoleLocation {
        case around
        case toLower
        case toUpper
    }

    open class HoleAnchor {
        open var id: AnyHashable {
            preconditionFailure()
        }

        open var index: Int {
            preconditionFailure()
        }

        open var tag: Int32 {
            preconditionFailure()
        }

        public init() {
        }
    }

    public final class Items {
        public let items: [Item]
        public let holeAnchors: [HoleAnchor]
        public let count: Int
        public let itemBinding: SparseItemGridBinding
        public let headerText: String?
        public let snapTopInset: Bool

        public init(items: [Item], holeAnchors: [HoleAnchor], count: Int, itemBinding: SparseItemGridBinding, headerText: String?, snapTopInset: Bool) {
            self.items = items
            self.holeAnchors = holeAnchors
            self.count = count
            self.itemBinding = itemBinding
            self.headerText = headerText
            self.snapTopInset = snapTopInset
        }

        func item(at index: Int) -> Item? {
            if let itemIndex = binarySearch(self.items, searchItem: index).index {
                return self.items[itemIndex]
            }
            return nil
        }

        func itemOrLower(at index: Int) -> Item? {
            let searchResult = binarySearch(self.items, searchItem: index)
            if let itemIndex = searchResult.index {
                return self.items[itemIndex]
            } else if let lowerBound = searchResult.lowerBound {
                return self.items[lowerBound]
            } else {
                return nil
            }
        }

        func tag(atIndexOrLower index: Int) -> Int32? {
            var item: Item?
            let itemsResult = binarySearch(self.items, searchItem: index)
            if let itemIndex = itemsResult.index {
                item = self.items[itemIndex]
            } else if let lowerBound = itemsResult.lowerBound {
                item = self.items[lowerBound]
            }

            var holeAnchor: HoleAnchor?
            let holeResult = binarySearch(self.holeAnchors, searchItem: index)
            if let itemIndex = holeResult.index {
                holeAnchor = self.holeAnchors[itemIndex]
            } else if let lowerBound = holeResult.lowerBound {
                holeAnchor = self.holeAnchors[lowerBound]
            }

            if let item = item, let holeAnchor = holeAnchor {
                if abs(index - item.index) < abs(index - holeAnchor.index) {
                    return item.tag
                } else {
                    return holeAnchor.tag
                }
            } else if let item = item {
                return item.tag
            } else if let holeAnchor = holeAnchor {
                return holeAnchor.tag
            } else {
                return nil
            }
        }

        func closestItem(at index: Int) -> Item? {
            let searchResult = binarySearch(self.items, searchItem: index)
            if let itemIndex = searchResult.index {
                return self.items[itemIndex]
            } else if let lowerBound = searchResult.lowerBound, let upperBound = searchResult.upperBound {
                let lowerBoundIndex = self.items[lowerBound].index
                let upperBoundIndex = self.items[upperBound].index
                if abs(index - lowerBoundIndex) < abs(index - upperBoundIndex) {
                    return self.items[lowerBound]
                } else {
                    return self.items[upperBound]
                }
            } else if let lowerBound = searchResult.lowerBound {
                return self.items[lowerBound]
            } else if let upperBound = searchResult.upperBound {
                return self.items[upperBound]
            } else {
                return nil
            }
        }

        func closestHole(to index: Int) -> HoleAnchor? {
            let searchResult = binarySearch(self.holeAnchors, searchItem: index)
            if let itemIndex = searchResult.index {
                return self.holeAnchors[itemIndex]
            } else if let lowerBound = searchResult.lowerBound, let upperBound = searchResult.upperBound {
                let lowerBoundIndex = self.holeAnchors[lowerBound].index
                let upperBoundIndex = self.holeAnchors[upperBound].index
                if abs(index - lowerBoundIndex) < abs(index - upperBoundIndex) {
                    return self.holeAnchors[lowerBound]
                } else {
                    return self.holeAnchors[upperBound]
                }
            } else if let lowerBound = searchResult.lowerBound {
                return self.holeAnchors[lowerBound]
            } else if let upperBound = searchResult.upperBound {
                return self.holeAnchors[upperBound]
            } else {
                return nil
            }
        }
    }

    public struct ZoomLevel: Equatable, Comparable {
        public var rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static func <(lhs: ZoomLevel, rhs: ZoomLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    private final class Viewport: ASDisplayNode, ASScrollViewDelegate {
        final class VisibleItem: SparseItemGridDisplayItem {
            let layer: SparseItemGridLayer?
            let view: SparseItemGridView?
            var shimmerLayer: SparseItemGridShimmerLayer?
            var blurLayer: SimpleLayer?

            init(layer: SparseItemGridLayer?, view: SparseItemGridView?) {
                self.layer = layer
                self.view = view
            }

            var displayLayer: CALayer {
                if let layer = self.layer {
                    return layer
                } else if let view = self.view {
                    return view.layer
                } else {
                    preconditionFailure()
                }
            }

            var frame: CGRect {
                get {
                    return self.displayLayer.frame
                } set(value) {
                    if let layer = self.layer {
                        layer.bounds = CGRect(origin: CGPoint(), size: value.size)
                        layer.position = value.center
                    } else if let view = self.view {
                        view.bounds = CGRect(origin: CGPoint(), size: value.size)
                        view.center = value.center
                    } else {
                        preconditionFailure()
                    }
                }
            }
            
            var position: CGPoint {
                get {
                    return self.displayLayer.position
                } set(value) {
                    if let layer = self.layer {
                        layer.position = value
                    } else if let view = self.view {
                        view.center = value
                    } else {
                        preconditionFailure()
                    }
                }
            }
            
            var bounds: CGRect {
                get {
                    return self.displayLayer.bounds
                } set(value) {
                    if let layer = self.layer {
                        layer.bounds = value
                    } else if let view = self.view {
                        view.bounds = value
                    } else {
                        preconditionFailure()
                    }
                }
            }
            
            var transform: CATransform3D {
                get {
                    return self.displayLayer.transform
                } set(value) {
                    if let layer = self.layer {
                        layer.transform = value
                    } else if let view = self.view {
                        view.layer.transform = value
                    } else {
                        preconditionFailure()
                    }
                }
            }

            var needsShimmer: Bool {
                if let layer = self.layer {
                    return layer.needsShimmer()
                } else if let view = self.view {
                    return view.needsShimmer()
                } else {
                    preconditionFailure()
                }
            }
        }

        final class Layout {
            let containerLayout: ContainerLayout
            let itemSize: CGSize
            let itemSpacing: CGFloat
            let lastItemSize: CGFloat
            let itemsPerRow: Int
            let centerItems: Bool

            init(containerLayout: ContainerLayout, zoomLevel: ZoomLevel, itemCount: Int) {
                self.containerLayout = containerLayout
                let width: CGFloat
                if containerLayout.useSideInsets {
                    width = containerLayout.size.width - containerLayout.insets.left - containerLayout.insets.right
                } else {
                    width = containerLayout.size.width
                }
                var centerItems = false
                if let fixedItemHeight = containerLayout.fixedItemHeight {
                    self.itemsPerRow = 1
                    self.itemSize = CGSize(width: width, height: fixedItemHeight)
                    self.lastItemSize = width
                    self.itemSpacing = 0.0
                    self.centerItems = false
                } else {
                    self.itemSpacing = 1.0

                    let itemsPerRow: CGFloat
                    if containerLayout.fixedItemAspect != nil && itemCount <= 2 && containerLayout.adjustForSmallCount {
                        itemsPerRow = 2.0
                        centerItems = itemCount == 1
                    } else {
                        itemsPerRow = CGFloat(zoomLevel.rawValue)
                    }
                    self.itemsPerRow = Int(itemsPerRow)
                    let itemSize = floorToScreenPixels((width - (self.itemSpacing * CGFloat(self.itemsPerRow - 1))) / itemsPerRow)
                    if let fixedItemAspect = containerLayout.fixedItemAspect {
                        self.itemSize = CGSize(width: itemSize, height: floor(itemSize / fixedItemAspect))
                    } else {
                        self.itemSize = CGSize(width: itemSize, height: itemSize)
                    }

                    if centerItems {
                        self.lastItemSize = self.itemSize.width
                    } else {
                        self.lastItemSize = width - (self.itemSize.width + self.itemSpacing) * CGFloat(self.itemsPerRow - 1)
                    }
                    self.centerItems = centerItems
                }
            }

            func frame(at index: Int) -> CGRect {
                let row = index / self.itemsPerRow
                let column = index % self.itemsPerRow
                
                var frame = CGRect(origin: CGPoint(x: (self.containerLayout.useSideInsets ? self.containerLayout.insets.left : 0.0) + CGFloat(column) * (self.itemSize.width + self.itemSpacing), y: self.containerLayout.insets.top + CGFloat(row) * (self.itemSize.height + self.itemSpacing)), size: CGSize(width: column == (self.itemsPerRow - 1) ? self.lastItemSize : itemSize.width, height: itemSize.height))
                if self.centerItems {
                    frame.origin.x = floor((self.containerLayout.size.width - frame.width) * 0.5)
                }
                return frame
            }

            func contentHeight(count: Int) -> CGFloat {
                return self.frame(at: count - 1).maxY
            }

            func visibleItemRange(for rect: CGRect, count: Int) -> (minIndex: Int, maxIndex: Int) {
                let offsetRect = rect.offsetBy(dx: 0.0, dy: -self.containerLayout.insets.top)
                var minVisibleRow = Int(floor((offsetRect.minY - self.itemSpacing) / (self.itemSize.height + self.itemSpacing)))
                minVisibleRow = max(0, minVisibleRow)
                let maxVisibleRow = Int(ceil((offsetRect.maxY - self.itemSpacing) / (self.itemSize.height + itemSpacing)))

                let minVisibleIndex = minVisibleRow * self.itemsPerRow
                let maxVisibleIndex = min(count - 1, (maxVisibleRow + 1) * self.itemsPerRow - 1)

                return (minVisibleIndex, maxVisibleIndex)
            }
        }

        let zoomLevel: ZoomLevel
        
        class ScrollView: UIScrollView {
            var forceDecelerating = false
            
            override var isDecelerating: Bool {
                return self.forceDecelerating || super.isDecelerating
            }
        }

        let scrollView: ScrollView
        private let shimmer: Shimmer

        var theme: PresentationTheme

        var layout: Layout?
        var items: Items?
        var visibleItems: [AnyHashable: VisibleItem] = [:]
        var visiblePlaceholders: [SparseItemGridShimmerLayer] = []
        
        private var reorderingItem: (id: AnyHashable, initialPosition: CGPoint, position: CGPoint)?

        private var scrollingArea: SparseItemGridScrollingArea?
        private var currentScrollingTag: Int32?
        private let maybeLoadHoleAnchor: (HoleAnchor, HoleLocation) -> Void

        private var ignoreScrolling: Bool = false
        private var isFastScrolling: Bool = false
        
        private var isReordering: Bool = false

        private var previousScrollOffset: CGFloat = 0.0
        var coveringInsetOffset: CGFloat = 0.0
        
        var offset: CGFloat {
            return self.scrollView.contentOffset.y
        }
        
        var contentBottomOffset: CGFloat {
            let bottomInset = self.layout?.containerLayout.insets.bottom ?? 0.0
            return -self.scrollView.contentOffset.y + self.scrollView.contentSize.height - bottomInset
        }

        let coveringOffsetUpdated: (Viewport, ContainedViewLayoutTransition) -> Void
        let offsetUpdated: (Viewport, ContainedViewLayoutTransition) -> Void

        private var decelerationAnimator: ConstantDisplayLinkAnimator?

        init(theme: PresentationTheme, zoomLevel: ZoomLevel, maybeLoadHoleAnchor: @escaping (HoleAnchor, HoleLocation) -> Void, coveringOffsetUpdated: @escaping (Viewport, ContainedViewLayoutTransition) -> Void, offsetUpdated: @escaping (Viewport, ContainedViewLayoutTransition) -> Void) {
            self.theme = theme
            self.zoomLevel = zoomLevel
            self.maybeLoadHoleAnchor = maybeLoadHoleAnchor
            self.coveringOffsetUpdated = coveringOffsetUpdated
            self.offsetUpdated = offsetUpdated

            self.scrollView = ScrollView()
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            self.scrollView.scrollsToTop = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.clipsToBounds = false

            self.shimmer = Shimmer()

            super.init()

            self.anchorPoint = CGPoint()

            self.scrollView.delegate = self.wrappedScrollViewDelegate
            self.view.addSubview(self.scrollView)
        }

        func update(containerLayout: ContainerLayout, items: Items, restoreScrollPosition: (y: CGFloat, index: Int)?, synchronous: SparseItemGrid.Synchronous, transition: ComponentTransition) {
            if self.layout?.containerLayout != containerLayout || self.items !== items {
                self.layout = Layout(containerLayout: containerLayout, zoomLevel: self.zoomLevel, itemCount: items.count)
                self.items = items

                self.updateVisibleItems(resetScrolling: true, synchronous: synchronous, restoreScrollPosition: restoreScrollPosition, transition: transition)

                self.snapCoveringInsetOffset(animated: false)
            }
        }
        
        func setReordering(isReordering: Bool) {
            if self.isReordering != isReordering {
                self.isReordering = isReordering
                
                self.updateVisibleItems(resetScrolling: true, synchronous: .semi, restoreScrollPosition: nil, transition: .spring(duration: 0.4))
            }
        }
        
        func setReorderingItem(item: SparseItemGridDisplayItem?) {
            var mappedItem: (AnyHashable, VisibleItem)?
            if let item, let itemLayer = item.layer {
                for (id, visibleItem) in self.visibleItems {
                    if visibleItem.layer === itemLayer {
                        mappedItem = (id, visibleItem)
                        break
                    }
                }
            }
            
            if self.reorderingItem?.id != mappedItem?.0 {
                if let (id, visibleItem) = mappedItem, let itemLayer = visibleItem.layer {
                    self.scrollView.layer.addSublayer(itemLayer)
                    self.reorderingItem = (id, itemLayer.position, itemLayer.position)
                } else {
                    self.reorderingItem = nil
                }
                self.updateVisibleItems(resetScrolling: true, synchronous: .semi, restoreScrollPosition: nil, transition: .spring(duration: 0.4))
            }
        }
        
        func moveReorderingItem(distance: CGPoint) {
            if let (id, initialPosition, _) = self.reorderingItem {
                let targetPosition = CGPoint(x: initialPosition.x + distance.x, y: initialPosition.y + distance.y)
                self.reorderingItem = (id, initialPosition, targetPosition)
                self.updateVisibleItems(resetScrolling: true, synchronous: .semi, restoreScrollPosition: nil, transition: .immediate)
                
                if let items = self.items, let visibleReorderingItem = self.visibleItems[id] {
                    for (visibleId, visibleItem) in self.visibleItems {
                        if visibleItem === visibleReorderingItem {
                            continue
                        }
                        if visibleItem.frame.contains(targetPosition) {
                            if let item = items.items.first(where: { $0.id == id }), let targetItem = items.items.first(where: { $0.id == visibleId }) {
                                items.itemBinding.reorderIfPossible(item: item, toIndex: targetItem.index)
                            }
                            break
                        }
                    }
                }
            }
        }

        @objc func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.items?.itemBinding.didScroll()
            if let decelerationAnimator = self.decelerationAnimator {
                self.scrollView.forceDecelerating = false
                self.decelerationAnimator = nil
                decelerationAnimator.invalidate()
            }
        }

        @objc func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateVisibleItems(resetScrolling: false, synchronous: .full, restoreScrollPosition: nil, transition: .immediate)

                if let layout = self.layout, let _ = self.items {
                    let offset = scrollView.contentOffset.y
                    
                    self.offsetUpdated(self, .immediate)
                    
                    let delta = offset - self.previousScrollOffset
                    self.previousScrollOffset = offset

                    if self.isFastScrolling {
                        if offset <= layout.containerLayout.insets.top {
                            var coveringInsetOffset = self.coveringInsetOffset + delta
                            if coveringInsetOffset < 0.0 {
                                coveringInsetOffset = 0.0
                            }
                            if coveringInsetOffset > layout.containerLayout.insets.top {
                                coveringInsetOffset = layout.containerLayout.insets.top
                            }
                            if offset <= 0.0 {
                                coveringInsetOffset = 0.0
                            }
                            if coveringInsetOffset < self.coveringInsetOffset {
                                self.coveringInsetOffset = coveringInsetOffset
                                self.coveringOffsetUpdated(self, .immediate)
                            }
                        }
                    } else {
                        var coveringInsetOffset = self.coveringInsetOffset + delta
                        if coveringInsetOffset < 0.0 {
                            coveringInsetOffset = 0.0
                        }
                        if coveringInsetOffset > layout.containerLayout.insets.top {
                            coveringInsetOffset = layout.containerLayout.insets.top
                        }
                        if offset <= 0.0 {
                            coveringInsetOffset = 0.0
                        }
                        if coveringInsetOffset != self.coveringInsetOffset {
                            self.coveringInsetOffset = coveringInsetOffset
                            self.coveringOffsetUpdated(self, .immediate)
                        }
                    }
                }
            }
        }

        @objc func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.snapCoveringInsetOffset(animated: true)
            }
        }

        @objc func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !self.ignoreScrolling {
                if !decelerate {
                    self.snapCoveringInsetOffset(animated: true)
                }
            }
        }

        @objc func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.snapCoveringInsetOffset(animated: true)
            }
        }

        private func snapCoveringInsetOffset(animated: Bool) {
            if let layout = self.layout, let items = self.items, items.snapTopInset {
                let offset = self.scrollView.contentOffset.y
                if offset < layout.containerLayout.insets.top {
                    if offset <= layout.containerLayout.insets.top / 2.0 {
                        self.scrollView.setContentOffset(CGPoint(), animated: true)
                    } else {
                        self.scrollView.setContentOffset(CGPoint(x: 0.0, y: layout.containerLayout.insets.top), animated: true)
                    }
                } else {
                    var coveringInsetOffset = self.coveringInsetOffset
                    if coveringInsetOffset > layout.containerLayout.insets.top / 2.0 {
                        coveringInsetOffset = layout.containerLayout.insets.top
                    } else {
                        coveringInsetOffset = 0.0
                    }
                    if offset <= 0.0 {
                        coveringInsetOffset = 0.0
                    }

                    if coveringInsetOffset != self.coveringInsetOffset {
                        self.coveringInsetOffset = coveringInsetOffset
                        self.coveringOffsetUpdated(self, animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate)
                    }
                }
            }
        }

        func visualItem(at point: CGPoint) -> SparseItemGridDisplayItem? {
            guard let items = self.items, !items.items.isEmpty else {
                return nil
            }

            let localPoint = self.scrollView.convert(point, from: self.view)

            for (_, visibleItem) in self.visibleItems {
                if visibleItem.frame.contains(localPoint) {
                    return visibleItem
                }
            }

            return nil
        }

        func visualItem(at index: Int) -> SparseItemGridDisplayItem? {
            guard let items = self.items, !items.items.isEmpty else {
                return nil
            }

            guard let item = items.item(at: index) else {
                return nil
            }
            for (id, visibleItem) in self.visibleItems {
                if id == item.id {
                    return visibleItem
                }
            }

            return nil
        }

        func item(at point: CGPoint) -> Item? {
            guard let items = self.items, !items.items.isEmpty else {
                return nil
            }

            let localPoint = self.scrollView.convert(point, from: self.view)

            for (id, visibleItem) in self.visibleItems {
                if visibleItem.frame.contains(localPoint) {
                    for item in items.items {
                        if item.id == id {
                            return item
                        }
                    }
                    return nil
                }
            }

            return nil
        }
        
        func itemHitTest(at point: CGPoint) -> (Item, CALayer, CGPoint)? {
            guard let items = self.items, !items.items.isEmpty else {
                return nil
            }

            let localPoint = self.scrollView.convert(point, from: self.view)

            for (id, visibleItem) in self.visibleItems {
                if visibleItem.frame.contains(localPoint) {
                    for item in items.items {
                        if item.id == id {
                            return (item, visibleItem.displayLayer, self.view.layer.convert(point, to: visibleItem.displayLayer))
                        }
                    }
                    return nil
                }
            }

            return nil
        }

        func anchorItem(at point: CGPoint, orLower: Bool = false) -> (Item, Int)? {
            guard let items = self.items, !items.items.isEmpty, let layout = self.layout else {
                return nil
            }

            if layout.containerLayout.lockScrollingAtTop {
                if let item = items.item(at: 0) {
                    return (item, 0)
                }
            }

            let localPoint = self.scrollView.convert(point, from: self.view)

            var closestItem: (CGFloat, Int, AnyHashable)?
            for (id, visibleItem) in self.visibleItems {
                let itemCenter = visibleItem.frame.center
                if visibleItem.frame.minY >= localPoint.y || visibleItem.frame.maxY < localPoint.y {
                    continue
                }
                let columnIndex = Int(floor(visibleItem.frame.minX / layout.itemSize.width))
                let distanceX = itemCenter.x - localPoint.x
                if orLower {
                    if distanceX > 0.0 {
                        continue
                    }
                }
                let distanceY = itemCenter.y - localPoint.y
                let distance2 = distanceX * distanceX + distanceY * distanceY

                if let (currentDistance2, _, _) = closestItem {
                    if distance2 < currentDistance2 {
                        closestItem = (distance2, columnIndex, id)
                    }
                } else {
                    closestItem = (distance2, columnIndex, id)
                }
            }

            if closestItem == nil {
                for (id, visibleItem) in self.visibleItems {
                    let itemCenter = visibleItem.frame.center
                    let columnIndex = Int(floor(visibleItem.frame.minX / layout.itemSize.width))
                    let distanceX = itemCenter.x - localPoint.x
                    let distanceY = itemCenter.y - localPoint.y
                    let distance2 = distanceX * distanceX + distanceY * distanceY

                    if let (currentDistance2, _, _) = closestItem {
                        if distance2 < currentDistance2 {
                            closestItem = (distance2, columnIndex, id)
                        }
                    } else {
                        closestItem = (distance2, columnIndex, id)
                    }
                }
            }

            if let (_, columnIndex, id) = closestItem {
                for item in items.items {
                    if item.id == id {
                        return (item, columnIndex)
                    }
                }
                return nil
            } else {
                return nil
            }
        }

        func frameForItem(at index: Int) -> CGRect? {
            guard let layout = self.layout else {
                return nil
            }
            return self.scrollView.convert(layout.frame(at: index), to: self.view)
        }

        func frameForItem(layer: SparseItemGridLayer) -> CGRect {
            return self.scrollView.convert(layer.frame, to: self.view)
        }

        func scrollToItem(at index: Int) {
            guard let layout = self.layout, let _ = self.items else {
                return
            }
            if layout.containerLayout.lockScrollingAtTop {
                return
            }
            let itemFrame = layout.frame(at: index)
            var contentOffset = itemFrame.minY
            if contentOffset > self.scrollView.contentSize.height - self.scrollView.bounds.height {
                contentOffset = self.scrollView.contentSize.height - self.scrollView.bounds.height
            }
            if contentOffset < 0.0 {
                contentOffset = 0.0
            }
            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: contentOffset), animated: false)
        }

        func ensureItemVisible(index: Int, anyAmount: Bool) {
            guard let layout = self.layout, let _ = self.items else {
                return
            }
            if layout.containerLayout.lockScrollingAtTop {
                return
            }

            let itemFrame = layout.frame(at: index)
            let visibleBounds = self.scrollView.bounds
            if anyAmount {
                if itemFrame.intersects(visibleBounds) {
                    return
                }
            } else {
                if visibleBounds.contains(itemFrame) {
                    return
                }
            }

            var contentOffset: CGFloat
            if itemFrame.midY >= visibleBounds.maxY {
                contentOffset = itemFrame.maxY - self.scrollView.bounds.height + layout.containerLayout.insets.bottom
            } else {
                contentOffset = itemFrame.minY - layout.containerLayout.insets.top
            }

            if contentOffset > self.scrollView.contentSize.height - self.scrollView.bounds.height {
                contentOffset = self.scrollView.contentSize.height - self.scrollView.bounds.height
            }
            if contentOffset < 0.0 {
                contentOffset = 0.0
            }
            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: contentOffset), animated: false)
        }

        func scrollToTop() -> Bool {
            if self.scrollView.contentOffset.y > 0.0 {
                self.scrollView.setContentOffset(CGPoint(), animated: true)
                return true
            } else {
                return false
            }
        }

        func stopScrolling() {
            self.scrollView.setContentOffset(self.scrollView.contentOffset, animated: false)
        }

        func transferVelocity(_ velocity: CGFloat) {
            if velocity <= 0.0 {
                return
            }
            self.decelerationAnimator?.isPaused = true
            let startTime = CACurrentMediaTime()
            var currentOffset = self.scrollView.contentOffset
            let decelerationRate: CGFloat = 0.998
            self.scrollView.forceDecelerating = true
            self.scrollViewDidEndDragging(self.scrollView, willDecelerate: true)
            self.decelerationAnimator = ConstantDisplayLinkAnimator(update: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let t = CACurrentMediaTime() - startTime
                var currentVelocity = velocity * 15.0 * CGFloat(pow(Double(decelerationRate), 1000.0 * t))
                currentOffset.y += currentVelocity
                let maxOffset = strongSelf.scrollView.contentSize.height - strongSelf.scrollView.bounds.height
                if currentOffset.y >= maxOffset {
                    currentOffset.y = maxOffset
                    currentVelocity = 0.0
                }
                if currentOffset.y < 0.0 {
                    currentOffset.y = 0.0
                    currentVelocity = 0.0
                }

                var didEnd = false
                if abs(currentVelocity) < 0.1 {
                    strongSelf.decelerationAnimator?.isPaused = true
                    strongSelf.decelerationAnimator = nil
                    didEnd = true
                }
                var contentOffset = strongSelf.scrollView.contentOffset
                contentOffset.y = floorToScreenPixels(currentOffset.y)
                strongSelf.scrollView.setContentOffset(contentOffset, animated: false)
                strongSelf.scrollViewDidScroll(strongSelf.scrollView)
                if didEnd {
                    strongSelf.scrollViewDidEndDecelerating(strongSelf.scrollView)
                    strongSelf.scrollView.forceDecelerating = false
                }
            })
            self.decelerationAnimator?.isPaused = false
        }

        func updateShimmerColors() {
            self.updateVisibleItems(resetScrolling: false, synchronous: .none, restoreScrollPosition: nil, transition: .immediate)
        }

        private func updateVisibleItems(resetScrolling: Bool, synchronous: SparseItemGrid.Synchronous, restoreScrollPosition: (y: CGFloat, index: Int)?, transition: ComponentTransition) {
            guard let layout = self.layout, let items = self.items else {
                return
            }

            let contentHeight: CGFloat
            if items.items.isEmpty {
                contentHeight = 0.0
            } else {
                contentHeight = layout.contentHeight(count: items.count)
            }
            let shimmerColors = items.itemBinding.getShimmerColors()

            if resetScrolling {
                if !self.scrollView.bounds.isEmpty {
                    //get anchor item id
                }

                self.ignoreScrolling = true
                self.scrollView.frame = CGRect(origin: CGPoint(), size: layout.containerLayout.size)
                self.scrollView.contentSize = CGSize(width: layout.containerLayout.size.width, height: contentHeight + layout.containerLayout.insets.bottom)
                self.ignoreScrolling = false
            }

            if layout.containerLayout.lockScrollingAtTop {
                self.scrollView.isScrollEnabled = false

                self.ignoreScrolling = true
                self.scrollView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: false)
                self.ignoreScrolling = false
            } else {
                self.scrollView.isScrollEnabled = true
                if let (y, index) = restoreScrollPosition {
                    let itemFrame = layout.frame(at: index)
                    var contentOffset = itemFrame.minY - y
                    if contentOffset > self.scrollView.contentSize.height - self.scrollView.bounds.height {
                        contentOffset = self.scrollView.contentSize.height - self.scrollView.bounds.height
                    }
                    if contentOffset < 0.0 {
                        contentOffset = 0.0
                    }

                    self.ignoreScrolling = true
                    self.scrollView.setContentOffset(CGPoint(x: 0.0, y: contentOffset), animated: false)
                    self.ignoreScrolling = false
                }
            }

            let visibleBounds = self.scrollView.bounds

            var validIds = Set<AnyHashable>()
            var usedPlaceholderCount = 0
            
            var bindItems: [Item] = []
            var bindLayers: [SparseItemGridDisplayItem] = []
            var updateLayers: [(SparseItemGridDisplayItem, Int)] = []
            
            let addBlur = layout.centerItems

            let visibleRange = layout.visibleItemRange(for: visibleBounds, count: items.count)
            if visibleRange.maxIndex >= visibleRange.minIndex {
                let processItemAtIndex: (Int) -> Void = { index in
                    if let item = items.item(at: index) {
                        var itemFrame = layout.frame(at: index)
                        
                        let itemLayer: VisibleItem
                        var isNewlyAdded = false
                        if let current = self.visibleItems[item.id] {
                            itemLayer = current
                            updateLayers.append((itemLayer, index))
                        } else {
                            isNewlyAdded = true
                            itemLayer = VisibleItem(layer: items.itemBinding.createLayer(item: item), view: items.itemBinding.createView())
                            
                            itemLayer.layer?.masksToBounds = true
                            
                            self.visibleItems[item.id] = itemLayer
                            
                            bindItems.append(item)
                            bindLayers.append(itemLayer)
                            
                            if let layer = itemLayer.layer {
                                if let reorderingItem = self.reorderingItem, let visibleReorderingItem = self.visibleItems[reorderingItem.id] {
                                    self.scrollView.layer.insertSublayer(layer, below: visibleReorderingItem.layer)
                                } else {
                                    self.scrollView.layer.addSublayer(layer)
                                }
                            } else if let view = itemLayer.view {
                                self.scrollView.addSubview(view)
                            }
                        }
                        
                        if addBlur {
                            let blurLayer: SimpleLayer
                            if let current = itemLayer.blurLayer {
                                blurLayer = current
                            } else {
                                blurLayer = SimpleLayer()
                                blurLayer.masksToBounds = true
                                blurLayer.zPosition = -1.0
                                self.scrollView.layer.addSublayer(blurLayer)
                                itemLayer.blurLayer = blurLayer
                            }
                        } else if let blurLayer = itemLayer.blurLayer {
                            itemLayer.blurLayer = nil
                            blurLayer.removeFromSuperlayer()
                        }
                        
                        if itemLayer.needsShimmer {
                            let placeholderLayer: SparseItemGridShimmerLayer
                            if let current = itemLayer.shimmerLayer {
                                placeholderLayer = current
                            } else {
                                placeholderLayer = items.itemBinding.createShimmerLayer() ?? Shimmer.Layer()
                                self.scrollView.layer.insertSublayer(placeholderLayer, at: 0)
                                itemLayer.shimmerLayer = placeholderLayer
                            }
                            
                            placeholderLayer.frame = itemFrame
                            self.shimmer.update(colors: shimmerColors, layer: placeholderLayer, containerSize: layout.containerLayout.size, frame: itemFrame.offsetBy(dx: 0.0, dy: -visibleBounds.minY))
                            placeholderLayer.update(size: itemFrame.size)
                        } else if let placeholderLayer = itemLayer.shimmerLayer {
                            itemLayer.shimmerLayer = nil
                            placeholderLayer.removeFromSuperlayer()
                        }
                        
                        validIds.insert(item.id)
                        
                        var itemScale: CGFloat
                        let itemCornerRadius: CGFloat
                        if self.isReordering && item.isReorderable {
                            itemScale = (itemFrame.height - 6.0 * 2.0) / itemFrame.height
                            itemCornerRadius = 10.0
                        } else {
                            itemScale = 1.0
                            itemCornerRadius = 0.0
                        }
                        
                        let itemAlpha: CGFloat
                        if let reorderingItem = self.reorderingItem, item.id == reorderingItem.id {
                            itemAlpha = 0.8
                            itemScale = 0.9
                            itemFrame = itemFrame.size.centered(around: reorderingItem.position)
                        } else {
                            itemAlpha = 1.0
                        }
                        
                        if transition.animation.isImmediate || isNewlyAdded {
                            itemLayer.position = itemFrame.center
                            itemLayer.bounds = CGRect(origin: CGPoint(), size: itemFrame.size)
                            itemLayer.transform = CATransform3DMakeScale(itemScale, itemScale, 1.0)
                            itemLayer.layer?.cornerRadius = itemCornerRadius
                            itemLayer.layer?.opacity = Float(itemAlpha)
                            if let blurLayer = itemLayer.blurLayer {
                                blurLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: itemFrame.minY), size: CGSize(width: layout.containerLayout.size.width, height: itemFrame.height))
                            }
                        } else {
                            if let itemLayerValue = itemLayer.layer {
                                transition.setPosition(layer: itemLayerValue, position: itemFrame.center)
                                transition.setBounds(layer: itemLayerValue, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                                transition.setTransform(layer: itemLayerValue, transform: CATransform3DMakeScale(itemScale, itemScale, 1.0))
                                transition.setCornerRadius(layer: itemLayerValue, cornerRadius: itemCornerRadius)
                                transition.setAlpha(layer: itemLayerValue, alpha: itemAlpha)
                                
                                if let blurLayer = itemLayer.blurLayer {
                                    blurLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: itemFrame.minY), size: CGSize(width: layout.containerLayout.size.width, height: itemFrame.height))
                                }
                            } else {
                                itemLayer.position = itemFrame.center
                                itemLayer.bounds = CGRect(origin: CGPoint(), size: itemFrame.size)
                                itemLayer.transform = CATransform3DMakeScale(itemScale, itemScale, 1.0)
                                itemLayer.layer?.cornerRadius = itemCornerRadius
                                itemLayer.layer?.opacity = Float(itemAlpha)
                                if let blurLayer = itemLayer.blurLayer {
                                    blurLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: itemFrame.minY), size: CGSize(width: layout.containerLayout.size.width, height: itemFrame.height))
                                }
                            }
                        }
                    } else {
                        let placeholderLayer: SparseItemGridShimmerLayer
                        if self.visiblePlaceholders.count > usedPlaceholderCount {
                            placeholderLayer = self.visiblePlaceholders[usedPlaceholderCount]
                        } else {
                            placeholderLayer = items.itemBinding.createShimmerLayer() ?? Shimmer.Layer()
                            self.scrollView.layer.addSublayer(placeholderLayer)
                            self.visiblePlaceholders.append(placeholderLayer)
                        }
                        let itemFrame = layout.frame(at: index)
                        placeholderLayer.frame = itemFrame
                        self.shimmer.update(colors: shimmerColors, layer: placeholderLayer, containerSize: layout.containerLayout.size, frame: itemFrame.offsetBy(dx: 0.0, dy: -visibleBounds.minY))
                        placeholderLayer.update(size: itemFrame.size)
                        usedPlaceholderCount += 1
                    }
                }
                for index in visibleRange.minIndex ... visibleRange.maxIndex {
                    processItemAtIndex(index)
                }
                if let reorderingItem = self.reorderingItem, let items = self.items {
                    var reorderingItemIndex: Int?
                    for item in items.items {
                        if item.id == reorderingItem.id {
                            reorderingItemIndex = item.index
                            break
                        }
                    }
                    
                    if let reorderingItemIndex, !(visibleRange.minIndex ... visibleRange.maxIndex).contains(reorderingItemIndex) {
                        processItemAtIndex(reorderingItemIndex)
                    }
                }
            }

            if !bindItems.isEmpty {
                items.itemBinding.bindLayers(items: bindItems, layers: bindLayers, size: layout.containerLayout.size, insets: layout.containerLayout.insets, synchronous: synchronous)
            }

            for (item, index) in updateLayers {
                let item = item as! VisibleItem
                let contentItem = items.item(at: index)
                if let layer = item.layer {
                    layer.update(size: layer.bounds.size, insets: layout.containerLayout.insets, displayItem: item, binding: items.itemBinding, item: contentItem)
                    
                    if self.isReordering, let contentItem, contentItem.isReorderable {
                        if layer.animation(forKey: "shaking_position") == nil {
                            layer.addReorderingShaking()
                        }
                    } else {
                        if layer.animation(forKey: "shaking_position") != nil {
                            layer.removeAnimation(forKey: "shaking_position")
                            layer.removeAnimation(forKey: "shaking_rotation")
                        }
                    }
                } else if let view = item.view {
                    view.update(size: view.layer.bounds.size, insets: layout.containerLayout.insets)
                }
            }

            var removeIds: [AnyHashable] = []
            for (id, _) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                }
            }
            for id in removeIds {
                if let item = self.visibleItems.removeValue(forKey: id) {
                    if let blurLayer = item.blurLayer {
                        item.blurLayer = nil
                        blurLayer.removeFromSuperlayer()
                    }
                    if let layer = item.layer {
                        items.itemBinding.unbindLayer(layer: layer)
                        layer.removeFromSuperlayer()
                    } else if let view = item.view {
                        view.removeFromSuperview()
                    }
                    item.shimmerLayer?.removeFromSuperlayer()
                }
            }

            if self.visiblePlaceholders.count > usedPlaceholderCount {
                for i in usedPlaceholderCount ..< self.visiblePlaceholders.count {
                    self.visiblePlaceholders[i].removeFromSuperlayer()
                }
                self.visiblePlaceholders.removeSubrange(usedPlaceholderCount...)
            }

            self.updateScrollingArea()
            self.updateHoleToLoad()
        }

        func updateHoleToLoad() {
            guard let layout = self.layout, let items = self.items else {
                return
            }

            if !items.items.isEmpty {
                let visibleBounds = self.scrollView.bounds
                let visibleRange = layout.visibleItemRange(for: visibleBounds, count: items.count)
                for index in visibleRange.minIndex ... visibleRange.maxIndex {
                    if items.item(at: index) == nil {
                        //let closestItem = items.closestItem(at: index)
                        let closestHole = items.closestHole(to: index)

                        var closestAnchor: HoleAnchor?
                        /*if let closestItem = closestItem, let closestHole = closestHole {
                            if abs(closestItem.index - index) < abs(closestHole.index - index) {
                                closestAnchor = closestItem.holeAnchor
                            } else {
                                closestAnchor = closestHole
                            }
                        } else if let closestItem = closestItem {
                            closestAnchor = closestItem.holeAnchor
                        } else if let closestHole = closestHole {*/
                            closestAnchor = closestHole
                        //}

                        if let closestAnchor = closestAnchor {
                            self.maybeLoadHoleAnchor(closestAnchor, .toLower)
                        }
                        break
                    }
                }
            }
        }

        func setScrollingArea(scrollingArea: SparseItemGridScrollingArea?) {
            if self.scrollingArea === scrollingArea {
                return
            }
            self.scrollingArea = scrollingArea

            if let scrollingArea = self.scrollingArea {
                scrollingArea.beginScrolling = { [weak self] in
                    guard let strongSelf = self else {
                        return nil
                    }
                    if let decelerationAnimator = strongSelf.decelerationAnimator {
                        strongSelf.scrollView.forceDecelerating = false
                        strongSelf.decelerationAnimator = nil
                        decelerationAnimator.invalidate()
                    }
                    strongSelf.items?.itemBinding.onBeginFastScrolling()
                    return strongSelf.scrollView
                }
                scrollingArea.setContentOffset = { [weak self] offset in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.isFastScrolling = true
                    strongSelf.scrollView.setContentOffset(offset, animated: false)
                    strongSelf.isFastScrolling = false
                }
                self.updateScrollingArea()
            }
        }

        private var previousScrollingUpdate: (timestamp: Double, date: String?, tag: Int32?)?
        
        private func updateScrollingArea() {
            guard let layout = self.layout, let items = self.items, !items.items.isEmpty else {
                return
            }

            let contentHeight = layout.contentHeight(count: items.count)

            var tag: Int32?
            let visibleBounds = self.scrollView.bounds
            let visibleRange = layout.visibleItemRange(for: visibleBounds, count: items.count)
            for index in visibleRange.minIndex ... visibleRange.maxIndex {
                if let tagValue = items.tag(atIndexOrLower: index) {
                    tag = tagValue
                    break
                }
            }

            if let scrollingArea = self.scrollingArea {
                let dateString = tag.flatMap { items.itemBinding.scrollerTextForTag(tag: $0) }
                if self.currentScrollingTag != tag {
                    self.currentScrollingTag = tag
                    if scrollingArea.isDragging {
                        scrollingArea.feedbackTap()
                    }
                }
                
                let currentTimestamp = CACurrentMediaTime()
                let update: (String?, Int32?) -> Void = { dateString, tag in
                    scrollingArea.update(
                        containerSize: layout.containerLayout.size,
                        containerInsets: layout.containerLayout.insets,
                        contentHeight: contentHeight,
                        contentOffset: self.scrollView.bounds.minY,
                        isScrolling: self.scrollView.isDragging || self.scrollView.isDecelerating || self.decelerationAnimator != nil,
                        date: (dateString ?? "", tag ?? 0),
                        theme: self.theme,
                        transition: .immediate
                    )
                }
                if let (timestamp, previousDateString, previousTag) = self.previousScrollingUpdate {
                    let delta = currentTimestamp - timestamp
                    let delay = 0.1
                    if delta < delay {
                        update(previousDateString, previousTag)
                        Queue.mainQueue().after(max(0.0, min(delay, timestamp + delay - currentTimestamp)), {
                            if self.currentScrollingTag == tag {
                                self.previousScrollingUpdate = (CACurrentMediaTime(), dateString, tag)
                                update(dateString, tag)
                            }
                        })
                    } else {
                        self.previousScrollingUpdate = (currentTimestamp, dateString, tag)
                        update(dateString, tag)
                    }
                } else {
                    self.previousScrollingUpdate = (currentTimestamp, dateString, tag)
                    update(dateString, tag)
                }
            }
        }
    }

    private final class ViewportTransition: ASDisplayNode {
        struct InteractiveState {
            var anchorLocation: CGPoint
            var initialScale: CGFloat
            var targetScale: CGFloat
        }

        let interactiveState: InteractiveState?
        let layout: ContainerLayout
        let anchorItemIndex: Int
        let transitionAnchorPoint: CGPoint
        let fromViewport: Viewport
        let toViewport: Viewport

        var currentProgress: CGFloat = 0.0

        var coveringInsetOffset: CGFloat {
            return self.fromViewport.coveringInsetOffset * (1.0 - self.currentProgress) + self.toViewport.coveringInsetOffset * self.currentProgress
        }
        
        var contentBottomOffset: CGFloat {
            return self.fromViewport.contentBottomOffset * (1.0 - self.currentProgress) + self.toViewport.contentBottomOffset * self.currentProgress
        }
        
        var offset: CGFloat {
            return self.fromViewport.offset * (1.0 - self.currentProgress) + self.toViewport.offset * self.currentProgress
        }

        let coveringOffsetUpdated: (ContainedViewLayoutTransition) -> Void
        let offsetUpdated: (ContainedViewLayoutTransition) -> Void

        init(interactiveState: InteractiveState?, layout: ContainerLayout, anchorItemIndex: Int, transitionAnchorPoint: CGPoint, from fromViewport: Viewport, to toViewport: Viewport, coveringOffsetUpdated: @escaping (ContainedViewLayoutTransition) -> Void, offsetUpdated: @escaping (ContainedViewLayoutTransition) -> Void) {
            self.interactiveState = interactiveState
            self.layout = layout
            self.anchorItemIndex = anchorItemIndex
            self.transitionAnchorPoint = transitionAnchorPoint
            self.fromViewport = fromViewport
            self.toViewport = toViewport
            self.coveringOffsetUpdated = coveringOffsetUpdated
            self.offsetUpdated = offsetUpdated

            super.init()
            
            self.fromViewport.allowsGroupOpacity = true
            self.toViewport.allowsGroupOpacity = true

            self.addSubnode(fromViewport)
            self.addSubnode(toViewport)
        }
        
        deinit {
            self.fromViewport.allowsGroupOpacity = false
            self.toViewport.allowsGroupOpacity = false
        }

        func update(progress: CGFloat, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
            guard var fromAnchorFrame = self.fromViewport.frameForItem(at: self.anchorItemIndex) else {
                return
            }
            guard var toAnchorFrame = self.toViewport.frameForItem(at: self.anchorItemIndex) else {
                return
            }

            let previousProgress = self.currentProgress
            self.currentProgress = progress

            var fromAnchorPoint = CGPoint()
            var toAnchorPoint = CGPoint()
            var fromDeltaOffset = CGPoint()
            var fromScale: CGFloat = 1.0
            var toScale: CGFloat = 1.0

            var searchOffset: CGFloat = 0.0

            while true {
                //let fixedAnchorPoint = CGPoint(x: fromAnchorFrame.midX, y: fromAnchorFrame.midY)
                var fixedAnchorPoint = self.transitionAnchorPoint
                if fixedAnchorPoint.x < self.layout.size.width / 2.0 {
                    fixedAnchorPoint.x = 0.0
                } else {
                    fixedAnchorPoint.x = self.layout.size.width
                }

                if let fromItem = self.fromViewport.anchorItem(at: fixedAnchorPoint), let fromFrame = self.fromViewport.frameForItem(at: fromItem.0.index) {
                    print("fromColumn: \(fromItem.1)")
                    fromAnchorFrame = fromFrame

                    fromAnchorFrame.origin.y = fromFrame.midY
                    fromAnchorFrame.origin.x = fromFrame.midX
                    fromAnchorFrame.size.width = 0.0
                } else {
                    print("find item1")
                }

                if let toItem = self.toViewport.anchorItem(at: fixedAnchorPoint.offsetBy(dx: searchOffset, dy: 0.0)), let toFrame = self.toViewport.frameForItem(at: toItem.0.index) {
                    toAnchorFrame = toFrame
                    print("toColumn: \(toItem.1)")

                    toAnchorFrame.origin.y = toFrame.midY
                    toAnchorFrame.origin.x = toFrame.midX
                    toAnchorFrame.size.width = 0.0
                } else {
                    print("find item2")
                }

                fromAnchorPoint = CGPoint(x: fromAnchorFrame.midX, y: fromAnchorFrame.midY)
                toAnchorPoint = CGPoint(x: toAnchorFrame.midX, y: toAnchorFrame.midY)

                let initialFromViewportScale: CGFloat = 1.0
                let targetFromViewportScale: CGFloat = toAnchorFrame.height / fromAnchorFrame.height

                let initialToViewportScale: CGFloat = fromAnchorFrame.height / toAnchorFrame.height
                let targetToViewportScale: CGFloat = 1.0

                fromScale = initialFromViewportScale * (1.0 - progress) + targetFromViewportScale * progress
                toScale = initialToViewportScale * (1.0 - progress) + targetToViewportScale * progress

                fromDeltaOffset = CGPoint(x: toAnchorPoint.x - fromAnchorPoint.x, y: toAnchorPoint.y - fromAnchorPoint.y)

                if fromDeltaOffset.x > 0.0 && abs(searchOffset) < 1000.0 {
                    searchOffset += -4.0
                    //continue
                    break
                } else {
                    if fromDeltaOffset.x <= 0.0 {
                        print("fail")
                    }
                    break
                }
            }

            let toDeltaOffset = CGPoint(x: -fromDeltaOffset.x, y: -fromDeltaOffset.y)

            print("direction: \(fromDeltaOffset.x < 0.0)")

            let fromOffset = CGPoint(x: 0.0 * (1.0 - progress) + fromDeltaOffset.x * progress, y: 0.0 * (1.0 - progress) + fromDeltaOffset.y * progress)
            let toOffset = CGPoint(x: toDeltaOffset.x * (1.0 - progress) + 0.0 * progress, y: toDeltaOffset.y * (1.0 - progress) + 0.0 * progress)

            var fromTransform = CGAffineTransform.identity
            fromTransform = fromTransform.translatedBy(x: fromAnchorPoint.x, y: fromAnchorPoint.y)
            fromTransform = fromTransform.translatedBy(x: fromOffset.x, y: fromOffset.y)
            fromTransform = fromTransform.scaledBy(x: fromScale, y: fromScale)
            fromTransform = fromTransform.translatedBy(x: -fromAnchorPoint.x, y: -fromAnchorPoint.y)


            var toTransform = CGAffineTransform.identity
            toTransform = toTransform.translatedBy(x: toAnchorPoint.x, y: toAnchorPoint.y)
            toTransform = toTransform.translatedBy(x: toOffset.x, y: toOffset.y)
            toTransform = toTransform.scaledBy(x: toScale, y: toScale)
            toTransform = toTransform.translatedBy(x: -toAnchorPoint.x, y: -toAnchorPoint.y)

            transition.updateTransform(node: self.fromViewport, transform: fromTransform)
            transition.updateTransform(node: self.toViewport, transform: toTransform)
            
            transition.updateAlpha(node: self.toViewport, alpha: progress, completion: { _ in
                completion()
            })

            let fromAlphaStartProgress: CGFloat = 0.7
            let fromAlphaEndProgress: CGFloat = 1.0
            let fromAlphaProgress = max(0.0, progress - fromAlphaStartProgress) / (fromAlphaEndProgress - fromAlphaStartProgress)

            if previousProgress < fromAlphaStartProgress, progress == 1.0, case let .animated(duration, _) = transition {
                transition.updateAlpha(node: self.fromViewport, alpha: 1.0 - fromAlphaProgress, delay: duration * 0.5)
            } else {
                transition.updateAlpha(node: self.fromViewport, alpha: 1.0 - fromAlphaProgress)
            }

            self.coveringOffsetUpdated(transition)
            self.offsetUpdated(transition)
        }
    }

    private struct ContainerLayout: Equatable {
        var size: CGSize
        var insets: UIEdgeInsets
        var useSideInsets: Bool
        var scrollIndicatorInsets: UIEdgeInsets
        var lockScrollingAtTop: Bool
        var fixedItemHeight: CGFloat?
        var fixedItemAspect: CGFloat?
        var adjustForSmallCount: Bool
    }

    private var tapRecognizer: UITapGestureRecognizer?
    private var pinchRecognizer: UIPinchGestureRecognizer?
    
    private var isReordering: Bool = false
    private var reorderRecognizer: ReorderGestureRecognizer?

    private var theme: PresentationTheme
    private var containerLayout: ContainerLayout?
    private var items: Items?

    private var currentViewport: Viewport?
    private var currentViewportTransition: ViewportTransition?
    private let scrollingArea: SparseItemGridScrollingArea
    
    private var headerText: ComponentView<Empty>?

    private var initialZoomLevel: ZoomLevel?

    private var isLoadingHole: Bool = false
    private let loadingHoleDisposable = MetaDisposable()

    public var coveringInsetOffset: CGFloat {
        if let currentViewportTransition = self.currentViewportTransition {
            return currentViewportTransition.coveringInsetOffset
        } else if let currentViewport = self.currentViewport {
            return currentViewport.coveringInsetOffset
        } else {
            return 0.0
        }
    }
    
    public var contentBottomOffset: CGFloat {
        if let currentViewportTransition = self.currentViewportTransition {
            return currentViewportTransition.contentBottomOffset
        } else if let currentViewport = self.currentViewport {
            return currentViewport.contentBottomOffset
        } else {
            return 0.0
        }
    }
    
    public var scrollingOffset: CGFloat {
        if let currentViewportTransition = self.currentViewportTransition {
            return currentViewportTransition.offset
        } else if let currentViewport = self.currentViewport {
            return currentViewport.offset
        } else {
            return 0.0
        }
    }

    public var cancelExternalContentGestures: (() -> Void)?
    public var zoomLevelUpdated: ((ZoomLevel) -> Void)?

    public var pinchEnabled: Bool = true {
        didSet {
            self.pinchRecognizer?.isEnabled = self.pinchEnabled
        }
    }
    
    public var isScrollEnabled: Bool = true {
        didSet {
            self.currentViewport?.scrollView.isScrollEnabled = self.isScrollEnabled
        }
    }
    
    public func scrollWithDelta(_ delta: CGFloat) {
        if let scrollView = self.currentViewport?.scrollView {
            scrollView.setContentOffset(CGPoint(x: 0.0, y: scrollView.contentOffset.y + delta), animated: false)
        }
    }

    public init(theme: PresentationTheme, initialZoomLevel: ZoomLevel? = nil) {
        self.theme = theme
        self.initialZoomLevel = initialZoomLevel

        self.scrollingArea = SparseItemGridScrollingArea()

        super.init()

        self.clipsToBounds = true

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.tapRecognizer = tapRecognizer
        self.view.addGestureRecognizer(tapRecognizer)

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.pinchGesture(_:)))
        self.pinchRecognizer = pinchRecognizer
        self.view.addGestureRecognizer(pinchRecognizer)
        
        let reorderRecognizer = ReorderGestureRecognizer(
            shouldBegin: { [weak self] point in
                guard let self, let item = self.item(at: point) else {
                    return (allowed: false, requiresLongPress: false, item: nil)
                }
                
                return (allowed: true, requiresLongPress: false, item: item)
            },
            willBegin: { point in
            },
            began: { [weak self] item in
                guard let self, let currentViewport = self.currentViewport else {
                    return
                }
                currentViewport.setReorderingItem(item: item)
            },
            ended: { [weak self] in
                guard let self, let currentViewport = self.currentViewport else {
                    return
                }
                currentViewport.setReorderingItem(item: nil)
            },
            moved: { [weak self] distance in
                guard let self, let currentViewport = self.currentViewport else {
                    return
                }
                currentViewport.moveReorderingItem(distance: distance)
            },
            isActiveUpdated: { _ in
            }
        )
        self.reorderRecognizer = reorderRecognizer
        self.view.addGestureRecognizer(reorderRecognizer)
        reorderRecognizer.isEnabled = false

        self.addSubnode(self.scrollingArea)
        self.scrollingArea.openCurrentDate = { [weak self] in
            guard let strongSelf = self, let items = strongSelf.items else {
                return
            }
            items.itemBinding.onTagTap()
        }
        self.scrollingArea.isDecelerating = { [weak self] in
            guard let self else {
                return false
            }
            guard let currentViewport = self.currentViewport else {
                return false
            }
            return currentViewport.scrollView.isDecelerating
        }
    }

    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        guard let currentViewport = self.currentViewport, let items = self.items else {
            return
        }
        if self.currentViewportTransition != nil {
            return
        }
        if case .ended = recognizer.state {
            let location = recognizer.location(in: self.view)
            if let (item, itemLayer, point) = currentViewport.itemHitTest(at: self.view.convert(location, to: currentViewport.view)) {
                items.itemBinding.onTap(item: item, itemLayer: itemLayer, point: point)
            }
        }
    }

    @objc private func pinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        guard let containerLayout = self.containerLayout, let items = self.items else {
            return
        }

        switch recognizer.state {
        case .began:
            self.cancelExternalContentGestures?()
        case .changed:
            let scale = recognizer.scale
            if let currentViewportTransition = self.currentViewportTransition, let interactiveState = currentViewportTransition.interactiveState {

                let progress = (scale - interactiveState.initialScale) / (interactiveState.targetScale - interactiveState.initialScale)
                var replacedTransition = false

                if progress < 0.0 || progress > 1.0 {
                    let boundaryViewport = progress > 1.0 ? currentViewportTransition.toViewport : currentViewportTransition.fromViewport
                    let zoomLevels = self.availableZoomLevels(width: containerLayout.size.width, startingAt: boundaryViewport.zoomLevel)

                    let isZoomingIn = interactiveState.targetScale > interactiveState.initialScale
                    var nextZoomLevel: ZoomLevel?
                    let startScale = progress > 1.0 ? interactiveState.targetScale : interactiveState.initialScale
                    let nextScale: CGFloat
                    if isZoomingIn {
                        if progress > 1.0 {
                            nextZoomLevel = zoomLevels.increment
                            nextScale = startScale * 1.25
                        } else {
                            nextZoomLevel = zoomLevels.decrement
                            nextScale = startScale * 0.75
                        }
                    } else {
                        if progress > 1.0 {
                            nextZoomLevel = zoomLevels.decrement
                            nextScale = startScale * 0.75
                        } else {
                            nextZoomLevel = zoomLevels.increment
                            nextScale = startScale * 1.25
                        }
                    }

                    let anchorLocation = interactiveState.anchorLocation

                    let nextAnchorItemIndex: Int
                    if let anchorItem = boundaryViewport.anchorItem(at: anchorLocation) {
                        nextAnchorItemIndex = anchorItem.0.index
                    } else {
                        nextAnchorItemIndex = currentViewportTransition.anchorItemIndex
                    }

                    if let nextZoomLevel = nextZoomLevel, let anchorItemFrame = boundaryViewport.frameForItem(at: nextAnchorItemIndex) {
                        replacedTransition = true

                        let restoreScrollPosition: (y: CGFloat, index: Int)? = (anchorItemFrame.minY, nextAnchorItemIndex)

                        let nextViewport = Viewport(theme: self.theme, zoomLevel: nextZoomLevel, maybeLoadHoleAnchor: { [weak self] holeAnchor, location in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.maybeLoadHoleAnchor(holeAnchor: holeAnchor, location: location)
                        }, coveringOffsetUpdated: { [weak self] viewport, transition in
                            self?.coveringOffsetUpdated(viewport: viewport, transition: transition)
                        }, offsetUpdated: { [weak self] viewport, transition in
                            self?.offsetUpdated(viewport: viewport, transition: transition)
                        })

                        nextViewport.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
                        nextViewport.update(containerLayout: containerLayout, items: items, restoreScrollPosition: restoreScrollPosition, synchronous: .semi, transition: .immediate)

                        self.currentViewportTransition?.removeFromSupernode()

                        let nextInteractiveState = ViewportTransition.InteractiveState(anchorLocation: anchorLocation, initialScale: startScale, targetScale: nextScale)
                        let currentViewportTransition = ViewportTransition(interactiveState: nextInteractiveState, layout: containerLayout, anchorItemIndex: currentViewportTransition.anchorItemIndex, transitionAnchorPoint: currentViewportTransition.transitionAnchorPoint, from: boundaryViewport, to: nextViewport, coveringOffsetUpdated: { [weak self] transition in
                            self?.transitionCoveringOffsetUpdated(transition: transition)
                        }, offsetUpdated: { [weak self] transition in
                            self?.transitionOffsetUpdated(transition: transition)
                        })
                        currentViewportTransition.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
                        self.insertSubnode(currentViewportTransition, belowSubnode: self.scrollingArea)
                        self.currentViewportTransition = currentViewportTransition

                        let nextProgress = (scale - nextInteractiveState.initialScale) / (nextInteractiveState.targetScale - nextInteractiveState.initialScale)
                        currentViewportTransition.update(progress: nextProgress, transition: .immediate, completion: {})
                    }
                }

                if !replacedTransition {
                    currentViewportTransition.update(progress: min(1.0, max(0.0, progress)), transition: .immediate, completion: {})
                }
            } else if scale != 1.0 {
                let zoomLevels = self.availableZoomLevels()
                var nextZoomLevel: ZoomLevel?
                if scale > 1.0 {
                    nextZoomLevel = zoomLevels.increment
                } else {
                    nextZoomLevel = zoomLevels.decrement
                }
                if let previousViewport = self.currentViewport, let nextZoomLevel = nextZoomLevel {
                    let anchorLocation = recognizer.location(in: self.view)

                    let interactiveState = ViewportTransition.InteractiveState(anchorLocation: anchorLocation, initialScale: 1.0, targetScale: scale > 1.0 ? scale * 1.25 : scale * 0.75)

                    var progress = (scale - interactiveState.initialScale) / (interactiveState.targetScale - interactiveState.initialScale)
                    progress = max(0.0, min(1.0, progress))

                    if let anchorItem = previousViewport.anchorItem(at: anchorLocation), let anchorItemFrame = previousViewport.frameForItem(at: anchorItem.0.index) {
                        let restoreScrollPosition: (y: CGFloat, index: Int)? = (anchorItemFrame.minY, anchorItem.0.index)
                        let anchorItemIndex = anchorItem.0.index

                        let nextViewport = Viewport(theme: self.theme, zoomLevel: nextZoomLevel, maybeLoadHoleAnchor: { [weak self] holeAnchor, location in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.maybeLoadHoleAnchor(holeAnchor: holeAnchor, location: location)
                        }, coveringOffsetUpdated: { [weak self] viewport, transition in
                            self?.coveringOffsetUpdated(viewport: viewport, transition: transition)
                        }, offsetUpdated: { [weak self] viewport, transition in
                            self?.offsetUpdated(viewport: viewport, transition: transition)
                        })

                        nextViewport.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
                        nextViewport.update(containerLayout: containerLayout, items: items, restoreScrollPosition: restoreScrollPosition, synchronous: .semi, transition: .immediate)

                        let currentViewportTransition = ViewportTransition(interactiveState: interactiveState, layout: containerLayout, anchorItemIndex: anchorItemIndex, transitionAnchorPoint: anchorLocation, from: previousViewport, to: nextViewport, coveringOffsetUpdated: { [weak self] transition in
                            self?.transitionCoveringOffsetUpdated(transition: transition)
                        }, offsetUpdated: { [weak self] transition in
                            self?.transitionOffsetUpdated(transition: transition)
                        })
                        currentViewportTransition.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
                        self.insertSubnode(currentViewportTransition, belowSubnode: self.scrollingArea)
                        self.currentViewportTransition = currentViewportTransition
                        currentViewportTransition.update(progress: progress, transition: .immediate, completion: {})
                    }
                }
            }
        case .ended, .cancelled:
            if let currentViewportTransition = self.currentViewportTransition, let interactiveState = currentViewportTransition.interactiveState {
                let scale = recognizer.scale
                var currentProgress = (scale - interactiveState.initialScale) / (interactiveState.targetScale - interactiveState.initialScale)
                currentProgress = max(0.0, min(1.0, currentProgress))
                let progress = currentProgress < 0.3 ? 0.0 : 1.0

                currentViewportTransition.update(progress: progress, transition: .animated(duration: 0.2, curve: .easeInOut), completion: { [weak self, weak currentViewportTransition] in
                    guard let strongSelf = self, let currentViewportTransition = currentViewportTransition else {
                        return
                    }

                    let previousViewport = strongSelf.currentViewport

                    let updatedViewport = progress < 0.5 ? currentViewportTransition.fromViewport : currentViewportTransition.toViewport
                    strongSelf.currentViewport = updatedViewport
                    strongSelf.zoomLevelUpdated?(updatedViewport.zoomLevel)

                    if let previousViewport = previousViewport, previousViewport !== strongSelf.currentViewport {
                        previousViewport.removeFromSupernode()
                    }

                    if let containerLayout = strongSelf.containerLayout, let currentViewport = strongSelf.currentViewport, let items = strongSelf.items {
                        strongSelf.insertSubnode(currentViewport, belowSubnode: strongSelf.scrollingArea)
                        strongSelf.scrollingArea.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
                        currentViewport.setScrollingArea(scrollingArea: strongSelf.scrollingArea)
                        currentViewport.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
                        currentViewport.update(containerLayout: containerLayout, items: items, restoreScrollPosition: nil, synchronous: .semi, transition: .immediate)
                    }

                    strongSelf.currentViewportTransition = nil
                    currentViewportTransition.removeFromSupernode()
                })
            }
        default:
            break
        }
    }

    public func update(size: CGSize, insets: UIEdgeInsets, useSideInsets: Bool, scrollIndicatorInsets: UIEdgeInsets, lockScrollingAtTop: Bool, fixedItemHeight: CGFloat?, fixedItemAspect: CGFloat?, adjustForSmallCount: Bool = true, items: Items, theme: PresentationTheme, synchronous: SparseItemGrid.Synchronous, transition: ComponentTransition = .immediate) {
        self.theme = theme
        
        var headerInset: CGFloat = 0.0
        if let headerTextValue = items.headerText {
            let headerText: ComponentView<Empty>
            if let current = self.headerText {
                headerText = current
            } else {
                headerText = ComponentView()
                self.headerText = headerText
            }
            let headerTextSize = headerText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: headerTextValue, font: Font.regular(15.0), textColor: theme.list.itemSecondaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: size.width - 16.0 * 2.0, height: 400.0)
            )
            let headerTextFrame = CGRect(origin: CGPoint(x: floor((size.width - headerTextSize.width) * 0.5), y: insets.top + 18.0), size: headerTextSize)
            if let headerTextView = headerText.view {
                if headerTextView.superview == nil {
                    headerTextView.layer.anchorPoint = CGPoint()
                    self.view.insertSubview(headerTextView, at: 0)
                }
                headerTextView.center = headerTextFrame.origin
                headerTextView.bounds = CGRect(origin: CGPoint(), size: headerTextFrame.size)
            }
            
            headerInset += 18.0 + headerTextSize.height + 18.0
        } else if let headerText = self.headerText {
            self.headerText = nil
            headerText.view?.removeFromSuperview()
        }
        
        var insets = insets
        insets.top += headerInset
        
        let containerLayout = ContainerLayout(size: size, insets: insets, useSideInsets: useSideInsets, scrollIndicatorInsets: scrollIndicatorInsets, lockScrollingAtTop: lockScrollingAtTop, fixedItemHeight: fixedItemHeight, fixedItemAspect: fixedItemAspect, adjustForSmallCount: adjustForSmallCount)
        self.containerLayout = containerLayout
        self.items = items
        self.scrollingArea.isHidden = lockScrollingAtTop

        if self.isReordering {
            self.tapRecognizer?.isEnabled = false
            self.pinchRecognizer?.isEnabled = false
            self.reorderRecognizer?.isEnabled = true
        } else {
            self.tapRecognizer?.isEnabled = fixedItemHeight == nil
            self.pinchRecognizer?.isEnabled = fixedItemHeight == nil
            self.reorderRecognizer?.isEnabled = false
        }

        if self.currentViewport == nil {
            let currentViewport = Viewport(theme: self.theme, zoomLevel: self.initialZoomLevel ?? ZoomLevel(rawValue: 3), maybeLoadHoleAnchor: { [weak self] holeAnchor, location in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.maybeLoadHoleAnchor(holeAnchor: holeAnchor, location: location)
            }, coveringOffsetUpdated: { [weak self] viewport, transition in
                self?.coveringOffsetUpdated(viewport: viewport, transition: transition)
            }, offsetUpdated: { [weak self] viewport, transition in
                self?.offsetUpdated(viewport: viewport, transition: transition)
            })
            self.currentViewport = currentViewport
            self.insertSubnode(currentViewport, belowSubnode: self.scrollingArea)

            currentViewport.setScrollingArea(scrollingArea: self.scrollingArea)
        }

        if let _ = self.currentViewportTransition {
        } else if let currentViewport = self.currentViewport {
            self.scrollingArea.frame = CGRect(origin: CGPoint(), size: size)
            currentViewport.frame = CGRect(origin: CGPoint(), size: size)
            currentViewport.update(containerLayout: containerLayout, items: items, restoreScrollPosition: nil, synchronous: synchronous, transition: transition)
        }
    }

    private func maybeLoadHoleAnchor(holeAnchor: HoleAnchor, location: HoleLocation) {
        if self.isLoadingHole {
            return
        }
        guard let items = self.items else {
            return
        }

        self.isLoadingHole = true
        self.loadingHoleDisposable.set((items.itemBinding.loadHole(anchor: holeAnchor, at: location)
        |> deliverOnMainQueue).start(completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isLoadingHole = false
            if let currentViewport = strongSelf.currentViewport {
                currentViewport.updateHoleToLoad()
            }
        }))
    }

    public func availableZoomLevels() -> (decrement: ZoomLevel?, increment: ZoomLevel?) {
        guard let currentViewport = self.currentViewport else {
            return (nil, nil)
        }
        guard let containerLayout = self.containerLayout else {
            return (nil, nil)
        }
        return self.availableZoomLevels(width: containerLayout.size.width, startingAt: currentViewport.zoomLevel)
    }

    private func availableZoomLevels(width: CGFloat, startingAt zoomLevel: ZoomLevel) -> (decrement: ZoomLevel?, increment: ZoomLevel?) {
        var zoomLevels: [ZoomLevel] = []
        for i in (2 ... 12).reversed() {
            zoomLevels.append(ZoomLevel(rawValue: i))
        }
        if let index = zoomLevels.firstIndex(of: zoomLevel) {
            return (index == 0 ? nil : zoomLevels[index - 1], index == (zoomLevels.count - 1) ? nil : zoomLevels[index + 1])
        } else {
            return (nil, nil)
        }
    }

    public func setZoomLevel(level: ZoomLevel) {
        guard let previousViewport = self.currentViewport else {
            self.initialZoomLevel = level
            return
        }
        if self.currentViewportTransition != nil {
            return
        }
        self.currentViewport = nil
        previousViewport.removeFromSupernode()

        let currentViewport = Viewport(theme: self.theme, zoomLevel: level, maybeLoadHoleAnchor: { [weak self] holeAnchor, location in
            guard let strongSelf = self else {
                return
            }
            strongSelf.maybeLoadHoleAnchor(holeAnchor: holeAnchor, location: location)
        }, coveringOffsetUpdated: { [weak self] viewport, transition in
            self?.coveringOffsetUpdated(viewport: viewport, transition: transition)
        }, offsetUpdated: { [weak self] viewport, transition in
            self?.offsetUpdated(viewport: viewport, transition: transition)
        })
        self.currentViewport = currentViewport
        self.insertSubnode(currentViewport, belowSubnode: self.scrollingArea)

        if let containerLayout = self.containerLayout, let items = self.items {
            let anchorLocation = CGPoint(x: 0.0, y: 10.0)
            if let anchorItem = previousViewport.anchorItem(at: anchorLocation), let anchorItemFrame = previousViewport.frameForItem(at: anchorItem.0.index) {
                let restoreScrollPosition: (y: CGFloat, index: Int)? = (anchorItemFrame.minY, anchorItem.0.index)
                let anchorItemIndex = anchorItem.0.index

                self.scrollingArea.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
                currentViewport.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
                currentViewport.update(containerLayout: containerLayout, items: items, restoreScrollPosition: restoreScrollPosition, synchronous: .semi, transition: .immediate)

                let currentViewportTransition = ViewportTransition(interactiveState: nil, layout: containerLayout, anchorItemIndex: anchorItemIndex, transitionAnchorPoint: anchorLocation, from: previousViewport, to: currentViewport, coveringOffsetUpdated: { [weak self] transition in
                    self?.transitionCoveringOffsetUpdated(transition: transition)
                }, offsetUpdated: { [weak self] transition in
                    self?.transitionOffsetUpdated(transition: transition)
                })
                currentViewportTransition.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
                self.insertSubnode(currentViewportTransition, belowSubnode: self.scrollingArea)
                self.currentViewportTransition = currentViewportTransition
                currentViewportTransition.update(progress: 0.0, transition: .immediate, completion: {})
                currentViewportTransition.update(progress: 1.0, transition: .animated(duration: 0.25, curve: .easeInOut), completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }

                    if let containerLayout = strongSelf.containerLayout, let currentViewport = strongSelf.currentViewport, let items = strongSelf.items {
                        strongSelf.insertSubnode(currentViewport, belowSubnode: strongSelf.scrollingArea)
                        strongSelf.scrollingArea.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
                        currentViewport.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
                        currentViewport.update(containerLayout: containerLayout, items: items, restoreScrollPosition: nil, synchronous: .semi, transition: .immediate)
                    }

                    strongSelf.currentViewport?.setScrollingArea(scrollingArea: strongSelf.scrollingArea)

                    if let currentViewportTransition = strongSelf.currentViewportTransition {
                        strongSelf.currentViewportTransition = nil
                        currentViewportTransition.removeFromSupernode()
                    }
                })
            }
        }
    }
    
    public func setReordering(isReordering: Bool) {
        self.isReordering = isReordering
        
        if let currentViewport = self.currentViewport {
            currentViewport.setReordering(isReordering: isReordering)
        }
        
        if self.isReordering {
            self.tapRecognizer?.isEnabled = false
            self.pinchRecognizer?.isEnabled = false
            self.reorderRecognizer?.isEnabled = true
        } else {
            self.tapRecognizer?.isEnabled = self.containerLayout?.fixedItemHeight == nil
            self.pinchRecognizer?.isEnabled = self.containerLayout?.fixedItemHeight == nil
            self.reorderRecognizer?.isEnabled = false
        }
    }

    private func coveringOffsetUpdated(viewport: Viewport, transition: ContainedViewLayoutTransition) {
        guard let items = self.items else {
            return
        }
        if self.currentViewportTransition != nil {
            return
        }
        items.itemBinding.coveringInsetOffsetUpdated(transition: transition)
    }

    private func transitionCoveringOffsetUpdated(transition: ContainedViewLayoutTransition) {
        guard let items = self.items else {
            return
        }
        items.itemBinding.coveringInsetOffsetUpdated(transition: transition)
        
        if let headerTextView = self.headerText?.view {
            headerTextView.layer.transform = CATransform3DMakeTranslation(0.0, -self.coveringInsetOffset, 0.0)
        }
    }
    
    private func offsetUpdated(viewport: Viewport, transition: ContainedViewLayoutTransition) {
        guard let items = self.items else {
            return
        }
        
        if self.currentViewportTransition != nil {
            return
        }
        
        items.itemBinding.scrollingOffsetUpdated(transition: transition)
        
        if let headerTextView = self.headerText?.view {
            headerTextView.layer.transform = CATransform3DMakeTranslation(0.0, -viewport.offset, 0.0)
        }
    }

    private func transitionOffsetUpdated(transition: ContainedViewLayoutTransition) {
        guard let items = self.items else {
            return
        }
        
        guard let currentViewportTransition = self.currentViewportTransition else {
            return
        }
        
        items.itemBinding.scrollingOffsetUpdated(transition: transition)
        
        if let headerTextView = self.headerText?.view {
            headerTextView.layer.transform = CATransform3DMakeTranslation(0.0, -currentViewportTransition.offset, 0.0)
        }
    }

    public func forEachVisibleItem(_ f: (SparseItemGridDisplayItem) -> Void) {
        guard let currentViewport = self.currentViewport else {
            return
        }
        for (_, itemLayer) in currentViewport.visibleItems {
            f(itemLayer)
        }
    }

    public func frameForItem(layer: SparseItemGridLayer) -> CGRect {
        guard let currentViewport = self.currentViewport else {
            return layer.bounds
        }
        return self.view.convert(currentViewport.frameForItem(layer: layer), from: currentViewport.view)
    }

    public func item(at point: CGPoint) -> SparseItemGridDisplayItem? {
        guard let currentViewport = self.currentViewport else {
            return nil
        }
        return currentViewport.visualItem(at: point)
    }

    public func item(at index: Int) -> SparseItemGridDisplayItem? {
        guard let currentViewport = self.currentViewport else {
            return nil
        }
        return currentViewport.visualItem(at: index)
    }

    public func scrollToItem(at index: Int) {
        guard let currentViewport = self.currentViewport else {
            return
        }
        currentViewport.scrollToItem(at: index)
    }

    public func ensureItemVisible(index: Int, anyAmount: Bool = true) {
        guard let currentViewport = self.currentViewport else {
            return
        }
        currentViewport.ensureItemVisible(index: index, anyAmount: anyAmount)
    }

    public func scrollToTop() -> Bool {
        guard let currentViewport = self.currentViewport else {
            return false
        }
        return currentViewport.scrollToTop()
    }

    public func addToTransitionSurface(view: UIView) {
        self.view.insertSubview(view, belowSubview: self.scrollingArea.view)
    }

    public func updateScrollingAreaTooltip(tooltip: SparseItemGridScrollingArea.DisplayTooltip) {
        self.scrollingArea.displayTooltip = tooltip
    }

    public func cancelGestures() {
        self.tapRecognizer?.state = .cancelled
        self.pinchRecognizer?.state = .cancelled
    }

    public func hideScrollingArea() {
        self.currentViewport?.stopScrolling()

        self.scrollingArea.hideScroller()
    }

    public func updateShimmerLayers(item: SparseItemGridDisplayItem) {
        guard let item = item as? Viewport.VisibleItem else {
            return
        }
        if let itemShimmerLayer = item.shimmerLayer, !item.needsShimmer {
            item.shimmerLayer = nil
            itemShimmerLayer.removeFromSuperlayer()
        }
    }

    public func hitTestResultForScrolling() -> UIView? {
        if let _ = self.currentViewportTransition {
            return nil
        } else if let currentViewport = self.currentViewport {
            return currentViewport.scrollView
        } else {
            return nil
        }
    }

    private var brieflyDisabledTouchActions = false

    public func brieflyDisableTouchActions() {
        if self.brieflyDisabledTouchActions {
            return
        }
        self.brieflyDisabledTouchActions = true

        let tapEnabled = self.tapRecognizer?.isEnabled ?? true
        self.tapRecognizer?.isEnabled = false
        let pinchEnabled = self.pinchRecognizer?.isEnabled ?? true
        self.pinchRecognizer?.isEnabled = false

        DispatchQueue.main.async { [weak self] in
            self?.tapRecognizer?.isEnabled = tapEnabled
            self?.pinchRecognizer?.isEnabled = pinchEnabled
            self?.brieflyDisabledTouchActions = false
        }
    }

    public func transferVelocity(_ velocity: CGFloat) {
        self.currentViewport?.transferVelocity(velocity)
    }

    public func updatePresentationData(theme: PresentationTheme) {
        self.theme = theme

        if let currentViewport = self.currentViewport {
            currentViewport.updateShimmerColors()
        }
    }
}

private final class ReorderGestureRecognizer: UIGestureRecognizer {
    private let shouldBegin: (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, item: SparseItemGridDisplayItem?)
    private let willBegin: (CGPoint) -> Void
    private let began: (SparseItemGridDisplayItem) -> Void
    private let ended: () -> Void
    private let moved: (CGPoint) -> Void
    private let isActiveUpdated: (Bool) -> Void
    
    private var initialLocation: CGPoint?
    private var longTapTimer: SwiftSignalKit.Timer?
    private var longPressTimer: SwiftSignalKit.Timer?
    
    private var itemView: SparseItemGridDisplayItem?
    
    public init(shouldBegin: @escaping (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, item: SparseItemGridDisplayItem?), willBegin: @escaping (CGPoint) -> Void, began: @escaping (SparseItemGridDisplayItem) -> Void, ended: @escaping () -> Void, moved: @escaping (CGPoint) -> Void, isActiveUpdated: @escaping (Bool) -> Void) {
        self.shouldBegin = shouldBegin
        self.willBegin = willBegin
        self.began = began
        self.ended = ended
        self.moved = moved
        self.isActiveUpdated = isActiveUpdated
        
        super.init(target: nil, action: nil)
    }
    
    deinit {
        self.longTapTimer?.invalidate()
        self.longPressTimer?.invalidate()
    }
    
    private func startLongTapTimer() {
        self.longTapTimer?.invalidate()
        let longTapTimer = SwiftSignalKit.Timer(timeout: 0.25, repeat: false, completion: { [weak self] in
            self?.longTapTimerFired()
        }, queue: Queue.mainQueue())
        self.longTapTimer = longTapTimer
        longTapTimer.start()
    }
    
    private func stopLongTapTimer() {
        self.itemView = nil
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
    }
    
    private func startLongPressTimer() {
        self.longPressTimer?.invalidate()
        let longPressTimer = SwiftSignalKit.Timer(timeout: 0.6, repeat: false, completion: { [weak self] in
            self?.longPressTimerFired()
        }, queue: Queue.mainQueue())
        self.longPressTimer = longPressTimer
        longPressTimer.start()
    }
    
    private func stopLongPressTimer() {
        self.itemView = nil
        self.longPressTimer?.invalidate()
        self.longPressTimer = nil
    }
    
    override public func reset() {
        super.reset()
        
        self.itemView = nil
        self.stopLongTapTimer()
        self.stopLongPressTimer()
        self.initialLocation = nil
        
        self.isActiveUpdated(false)
    }
    
    private func longTapTimerFired() {
        guard let location = self.initialLocation else {
            return
        }
        
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
        
        self.willBegin(location)
    }
    
    private func longPressTimerFired() {
        guard let _ = self.initialLocation else {
            return
        }
        
        self.isActiveUpdated(true)
        self.state = .began
        self.longPressTimer?.invalidate()
        self.longPressTimer = nil
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
        if let itemView = self.itemView {
            self.began(itemView)
        }
        self.isActiveUpdated(true)
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.numberOfTouches > 1 {
            self.isActiveUpdated(false)
            self.state = .failed
            self.ended()
            return
        }
        
        if self.state == .possible {
            if let location = touches.first?.location(in: self.view) {
                let (allowed, requiresLongPress, itemView) = self.shouldBegin(location)
                if allowed {
                    self.isActiveUpdated(true)
                    
                    self.itemView = itemView
                    self.initialLocation = location
                    if requiresLongPress {
                        self.startLongTapTimer()
                        self.startLongPressTimer()
                    } else {
                        self.state = .began
                        if let itemView = self.itemView {
                            self.began(itemView)
                        }
                    }
                } else {
                    self.isActiveUpdated(false)
                    self.state = .failed
                }
            } else {
                self.isActiveUpdated(false)
                self.state = .failed
            }
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.initialLocation = nil
        
        self.stopLongTapTimer()
        if self.longPressTimer != nil {
            self.stopLongPressTimer()
            self.isActiveUpdated(false)
            self.state = .failed
        }
        if self.state == .began || self.state == .changed {
            self.isActiveUpdated(false)
            self.ended()
            self.state = .failed
        }
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.initialLocation = nil
        
        self.stopLongTapTimer()
        if self.longPressTimer != nil {
            self.isActiveUpdated(false)
            self.stopLongPressTimer()
            self.state = .failed
        }
        if self.state == .began || self.state == .changed {
            self.isActiveUpdated(false)
            self.ended()
            self.state = .failed
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if (self.state == .began || self.state == .changed), let initialLocation = self.initialLocation, let location = touches.first?.location(in: self.view) {
            self.state = .changed
            let offset = CGPoint(x: location.x - initialLocation.x, y: location.y - initialLocation.y)
            self.moved(offset)
        } else if let touch = touches.first, let initialTapLocation = self.initialLocation, self.longPressTimer != nil {
            let touchLocation = touch.location(in: self.view)
            let dX = touchLocation.x - initialTapLocation.x
            let dY = touchLocation.y - initialTapLocation.y
            
            if dX * dX + dY * dY > 3.0 * 3.0 {
                self.stopLongTapTimer()
                self.stopLongPressTimer()
                self.initialLocation = nil
                self.isActiveUpdated(false)
                self.state = .failed
            }
        }
    }
}
