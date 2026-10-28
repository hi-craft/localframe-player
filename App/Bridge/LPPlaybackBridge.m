#import "LPPlaybackBridge.h"
#import "LPLibrary.h"
#include <math.h>

VLCLibrary *LPLocalLibrary(void) {
    static VLCLibrary *library;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // VLCMedia's public initializer also uses this instance. Media-level options below
        // disable subtitle discovery and metadata networking on every individual input.
        library = [VLCLibrary sharedLibrary];
    });
    return library;
}

@interface LPPlaybackBridge () <VLCMediaPlayerDelegate>
@property (nonatomic, readwrite) UIView *videoView;
@property (atomic, strong, nullable) VLCMediaPlayer *player;
@property (atomic) NSUInteger generation;
@property (atomic) NSUInteger playerGeneration;
@property (atomic) float desiredRate;
@property (atomic) BOOL wantsPlayback;
@property (nonatomic, strong) dispatch_queue_t engineQueue;
@end

@implementation LPPlaybackBridge
- (instancetype)init {
    self = [super init];
    if (self) {
        _videoView = [[UIView alloc] initWithFrame:CGRectZero];
        _videoView.backgroundColor = UIColor.blackColor;
        _videoView.userInteractionEnabled = NO;
        _engineQueue = dispatch_queue_create("com.localframe.playback", DISPATCH_QUEUE_SERIAL);
        _desiredRate = 1.0f;
    }
    return self;
}

- (void)openFileURL:(NSURL *)url {
    NSAssert(NSThread.isMainThread, @"Drive the bridge from the main actor");
    if (!url.isFileURL) {
        if (self.stateChanged) self.stateChanged(@"error");
        return;
    }
    self.generation += 1;
    NSUInteger generation = self.generation;
    self.wantsPlayback = YES;
    dispatch_async(self.engineQueue, ^{
        VLCMediaPlayer *previous = self.player;
        previous.delegate = nil;
        [previous stop];
        if (generation != self.generation) return;
        VLCMediaPlayer *player = [[VLCMediaPlayer alloc] initWithLibrary:LPLocalLibrary()];
        VLCMedia *media = [[VLCMedia alloc] initWithPath:url.path];
        for (NSString *option in @[@":access=file", @":no-spu", @":no-video-title-show", @":no-sub-autodetect-file",
                                   @":no-metadata-network-access", @":no-lua", @":file-caching=300"]) {
            [media addOption:option];
        }
        player.media = media;
        player.delegate = self;
        self.playerGeneration = generation;
        self.player = player;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.generation) return;
            player.drawable = self.videoView;
            dispatch_async(self.engineQueue, ^{
                if (generation != self.generation) return;
                player.rate = self.desiredRate;
                [player play];
            });
        });
    });
}

- (void)play {
    self.wantsPlayback = YES;
    dispatch_async(self.engineQueue, ^{ [self.player play]; });
}

- (void)pause {
    self.wantsPlayback = NO;
    dispatch_async(self.engineQueue, ^{ [self.player pause]; });
}

- (void)setPlaybackRate:(float)rate {
    self.desiredRate = MIN(3.0f, MAX(0.25f, rate));
    dispatch_async(self.engineQueue, ^{ self.player.rate = self.desiredRate; });
}

- (void)seekToSeconds:(double)seconds {
    dispatch_async(self.engineQueue, ^{
        VLCMediaPlayer *player = self.player;
        if (player.isSeekable && isfinite(seconds)) {
            player.time = [[VLCTime alloc] initWithNumber:@(MAX(0, seconds) * 1000.0)];
        }
    });
}

- (void)stopWithCompletion:(void (^)(void))completion {
    self.generation += 1;
    self.wantsPlayback = NO;
    dispatch_async(self.engineQueue, ^{
        VLCMediaPlayer *player = self.player;
        player.delegate = nil;
        [player stop];
        self.player = nil;
        dispatch_async(dispatch_get_main_queue(), completion);
    });
}

- (void)mediaPlayerStateChanged:(NSNotification *)notification {
    VLCMediaPlayer *player = notification.object;
    NSUInteger generation = self.playerGeneration;
    VLCMediaPlayerState state = player.state;
    NSString *name;
    switch (state) {
        case VLCMediaPlayerStateOpening: name = @"opening"; break;
        case VLCMediaPlayerStateBuffering: name = @"buffering"; break;
        case VLCMediaPlayerStatePlaying: name = @"playing"; break;
        case VLCMediaPlayerStatePaused: name = @"paused"; break;
        case VLCMediaPlayerStateEnded: name = @"ended"; break;
        case VLCMediaPlayerStateError: name = @"error"; break;
        case VLCMediaPlayerStateStopped: name = @"stopped"; break;
        default: return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (generation != self.generation || player != self.player) return;
        if (state == VLCMediaPlayerStatePlaying) {
            [self setPlaybackRate:self.desiredRate];
            if (!self.wantsPlayback) { [self pause]; return; }
        }
        if (self.stateChanged) self.stateChanged(name);
    });
}

- (void)mediaPlayerTimeChanged:(NSNotification *)notification {
    VLCMediaPlayer *player = notification.object;
    NSUInteger generation = self.playerGeneration;
    double seconds = player.time.value.doubleValue / 1000.0;
    double duration = player.media.length.value.doubleValue / 1000.0;
    BOOL seekable = player.isSeekable;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (generation != self.generation || player != self.player) return;
        if (self.progressChanged) self.progressChanged(MAX(0, seconds), MAX(0, duration), seekable);
    });
}
@end
