load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TooltipUI",
    module_name = "TooltipUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AppBundle:AppBundle",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TextFormat:TextFormat",
        "//submodules/UrlEscaping:UrlEscaping",
        "//submodules/AccountContext:AccountContext",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/ComponentFlow",
        "//submodules/Markdown",
        "//submodules/TelegramUI/Components/Stories/AvatarStoryIndicatorComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/Components/MultilineTextWithEntitiesComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/ShimmerEffect",
        "//submodules/UIKitRuntimeUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
