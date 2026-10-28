#import "LPFirstFrameDecoder.h"
#import "LPLibrary.h"
#include <vlc/vlc.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

@implementation LPFrameCancellation {
    atomic_bool _cancelled;
}
- (instancetype)init { self = [super init]; if (self) atomic_init(&_cancelled, false); return self; }
- (BOOL)isCancelled { return atomic_load(&_cancelled); }
- (void)cancel { atomic_store(&_cancelled, true); }
@end

@interface LPFrameContext : NSObject
@property (nonatomic) void *pixels;
@property (nonatomic) unsigned width;
@property (nonatomic) unsigned height;
@property (nonatomic) unsigned pitch;
@property (nonatomic) unsigned capturedWidth;
@property (nonatomic) unsigned capturedHeight;
@property (nonatomic) unsigned capturedPitch;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) dispatch_semaphore_t ready;
@property (nonatomic, strong, nullable) NSData *frame;
@end

@implementation LPFrameContext
- (instancetype)init {
    self = [super init];
    if (self) { _lock = [NSLock new]; _ready = dispatch_semaphore_create(0); }
    return self;
}
- (void)dealloc { free(_pixels); }
@end

static unsigned LPSetup(void **opaque, char *chroma, unsigned *width, unsigned *height,
                        unsigned *pitches, unsigned *lines) {
    LPFrameContext *context = (__bridge LPFrameContext *)(*opaque);
    if (*width == 0 || *height == 0) return 0;
    double scale = fmin(1.0, fmin(320.0 / *width, 180.0 / *height));
    unsigned w = MAX(1, (unsigned)floor(*width * scale));
    unsigned h = MAX(1, (unsigned)floor(*height * scale));
    unsigned pitch = (w * 4 + 31) & ~31U;
    unsigned rows = (h + 31) & ~31U;
    void *buffer = NULL;
    if (posix_memalign(&buffer, 32, pitch * rows) != 0) return 0;
    memset(buffer, 0, pitch * rows);
    [context.lock lock];
    free(context.pixels);
    context.pixels = buffer;
    context.width = w; context.height = h; context.pitch = pitch;
    [context.lock unlock];
    memcpy(chroma, "RV32", 4);
    *width = w; *height = h; pitches[0] = pitch; lines[0] = rows;
    return 1;
}

static void *LPLock(void *opaque, void **planes) {
    LPFrameContext *context = (__bridge LPFrameContext *)opaque;
    [context.lock lock];
    planes[0] = context.pixels;
    return context.pixels;
}

static void LPUnlock(void *opaque, void *picture, void *const *planes) {
    LPFrameContext *context = (__bridge LPFrameContext *)opaque;
    if (!context.frame && context.pixels) {
        context.frame = [NSData dataWithBytes:context.pixels length:context.pitch * context.height];
        context.capturedWidth = context.width;
        context.capturedHeight = context.height;
        context.capturedPitch = context.pitch;
        dispatch_semaphore_signal(context.ready);
    }
    [context.lock unlock];
}

static void LPDisplay(void *opaque, void *picture) {}

@implementation LPFirstFrameDecoder
+ (UIImage *)imageAtFileURL:(NSURL *)url cancellation:(LPFrameCancellation *)cancellation {
    NSAssert(!NSThread.isMainThread, @"Never decode thumbnails on the UI thread");
    if (!url.isFileURL || cancellation.isCancelled) return nil;
    @autoreleasepool {
        libvlc_instance_t *instance = (libvlc_instance_t *)LPLocalLibrary().instance;
        if (!instance) return nil;
        libvlc_media_t *media = libvlc_media_new_path(instance, url.fileSystemRepresentation);
        if (!media) return nil;
        const char *options[] = { ":access=file", ":no-audio", ":no-spu", ":no-sub-autodetect-file",
            ":no-metadata-network-access", ":no-lua", ":avcodec-hw=none", ":file-caching=100" };
        for (unsigned i = 0; i < sizeof(options) / sizeof(options[0]); i++) {
            libvlc_media_add_option(media, options[i]);
        }
        libvlc_media_player_t *player = libvlc_media_player_new_from_media(media);
        libvlc_media_release(media);
        if (!player) return nil;
        LPFrameContext *context = [LPFrameContext new];
        libvlc_video_set_callbacks(player, LPLock, LPUnlock, LPDisplay, (__bridge void *)context);
        libvlc_video_set_format_callbacks(player, LPSetup, NULL);
        if (libvlc_media_player_play(player) == 0) {
            CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + 8.0;
            while (!cancellation.isCancelled && CFAbsoluteTimeGetCurrent() < deadline) {
                if (dispatch_semaphore_wait(context.ready,
                    dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC)) == 0) break;
                libvlc_state_t state = libvlc_media_player_get_state(player);
                if (state == libvlc_Error || state == libvlc_Ended) break;
            }
        }
        // Stop fully before the context or the folder security-scope lease can be released.
        libvlc_media_player_stop(player);
        libvlc_media_player_release(player);
        if (cancellation.isCancelled || !context.frame) return nil;
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)context.frame);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGImageRef image = CGImageCreate(context.capturedWidth, context.capturedHeight, 8, 32,
            context.capturedPitch, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
            provider, NULL, false, kCGRenderingIntentDefault);
        UIImage *result = image ? [UIImage imageWithCGImage:image] : nil;
        if (image) CGImageRelease(image);
        CGColorSpaceRelease(colorSpace);
        CGDataProviderRelease(provider);
        return result;
    }
}
@end
