import AVKit
import Defaults
import Siesta
import SwiftUI

struct VideoPlayerView: View {
    static let defaultAspectRatio = 16 / 9.0
    static var defaultMinimumHeightLeft: Double {
        #if os(macOS)
            300
        #else
            200
        #endif
    }

    @State private var playerSize: CGSize = .zero
    @State private var fullScreenDetails = false

    @Environment(\.colorScheme) private var colorScheme

    #if os(iOS)
        @Environment(\.presentationMode) private var presentationMode
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @Environment(\.verticalSizeClass) private var verticalSizeClass
    #endif

    @EnvironmentObject<PlayerModel> private var player

    var body: some View {
        #if os(macOS)
            HSplitView {
                content
            }
            .onOpenURL(perform: handleOpenedURL)
            .frame(minWidth: 950, minHeight: 700)
        #else
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    content
                }
                .onAppear {
                    self.playerSize = geometry.size
                }
                .onChange(of: geometry.size) { size in
                    self.playerSize = size
                }
            }
            .navigationBarHidden(true)
        #endif
    }

    var content: some View {
        Group {
            Group {
                #if os(tvOS)
                    player.playerView
                #else
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            #if os(iOS)
                                if verticalSizeClass == .regular {
                                    PlaybackBar()
                                }
                            #elseif os(macOS)
                                PlaybackBar()
                            #endif

                            if player.currentItem.isNil {
                                playerPlaceholder(geometry: geometry)
                            } else if player.playingInPictureInPicture {
                                pictureInPicturePlaceholder(geometry: geometry)
                            } else {
                                player.playerView
                                    .modifier(
                                        VideoPlayerSizeModifier(
                                            geometry: geometry,
                                            aspectRatio: player.controller?.aspectRatio
                                        )
                                    )
                            }
                        }
                        #if os(iOS)
                        .onSwipeGesture(
                            up: {
                                withAnimation {
                                    fullScreen = true
                                }
                            },
                            down: { presentationMode.wrappedValue.dismiss() }
                        )
                        #endif

                        .background(Color.black)

                        Group {
                            #if os(iOS)
                                if verticalSizeClass == .regular {
                                    VideoDetails(sidebarQueue: sidebarQueueBinding, fullScreen: $fullScreenDetails)
                                }

                            #else
                                VideoDetails(sidebarQueue: sidebarQueueBinding, fullScreen: $fullScreenDetails)
                            #endif
                        }
                        .background(colorScheme == .dark ? Color.black : Color.white)
                        .modifier(VideoDetailsPaddingModifier(geometry: geometry, aspectRatio: player.controller?.aspectRatio, fullScreen: fullScreenDetails))
                    }
                #endif
            }
            .background(colorScheme == .dark ? Color.black : Color.white)
            #if os(macOS)
                .frame(minWidth: 650)
            #endif
            #if os(iOS)
                if sidebarQueue {
                    PlayerQueueView(sidebarQueue: .constant(true), fullScreen: $fullScreenDetails)
                        .frame(maxWidth: 350)
                }
            #elseif os(macOS)
                if Defaults[.playerSidebar] != .never {
                    PlayerQueueView(sidebarQueue: sidebarQueueBinding, fullScreen: $fullScreenDetails)
                        .frame(minWidth: 300)
                }
            #endif
        }
    }

    func playerPlaceholder(geometry: GeometryProxy) -> some View {
        HStack {
            Spacer()
            VStack {
                Spacer()
                VStack(spacing: 10) {
                    #if !os(tvOS)
                        Image(systemName: "ticket")
                            .font(.system(size: 120))
                    #endif
                }
                Spacer()
            }
            .foregroundColor(.gray)
            Spacer()
        }
        .contentShape(Rectangle())
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: geometry.size.width / VideoPlayerView.defaultAspectRatio)
    }

    func pictureInPicturePlaceholder(geometry: GeometryProxy) -> some View {
        HStack {
            Spacer()
            VStack {
                Spacer()
                VStack(spacing: 10) {
                    #if !os(tvOS)
                        Image(systemName: "pip")
                            .font(.system(size: 120))
                    #endif

                    Text("Playing in Picture in Picture")
                }
                Spacer()
            }
            .foregroundColor(.gray)
            Spacer()
        }
        .contextMenu {
            Button {
                player.closePiP()
            } label: {
                Label("Exit Picture in Picture", systemImage: "pip.exit")
            }
        }
        .contentShape(Rectangle())
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: geometry.size.width / VideoPlayerView.defaultAspectRatio)
    }

    var sidebarQueue: Bool {
        switch Defaults[.playerSidebar] {
        case .never:
            return false
        case .always:
            return true
        case .whenFits:
            return playerSize.width > 900
        }
    }

    var sidebarQueueBinding: Binding<Bool> {
        Binding(
            get: { sidebarQueue },
            set: { _ in }
        )
    }

    #if !os(tvOS)
        func handleOpenedURL(_ url: URL) {
            guard !player.accounts.current.isNil else {
                return
            }

            let parser = VideoURLParser(url: url)

            guard let id = parser.id else {
                return
            }

            player.accounts.api.video(id).load().onSuccess { response in
                if let video: Video = response.typedContent() {
                    self.player.playNow(video, at: parser.time)
                    self.player.show()
                }
            }
        }
    #endif
}

struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerView()
            .injectFixtureEnvironmentObjects()
    }
}
