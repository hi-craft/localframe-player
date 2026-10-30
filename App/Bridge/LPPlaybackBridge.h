#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LPPlaybackBridge : NSObject
@property (nonatomic, readonly) UIView *videoView;
@property (nonatomic, copy, nullable) void (^stateChanged)(NSString *state);
@property (nonatomic, copy, nullable) void (^progressChanged)(double seconds, double duration, BOOL seekable);
- (void)openFileURL:(NSURL *)url NS_SWIFT_NAME(open(fileURL:));
- (void)play;
- (void)pause;
- (void)setPlaybackRate:(float)rate NS_SWIFT_NAME(setRate(_:));
- (void)seekToSeconds:(double)seconds NS_SWIFT_NAME(seek(seconds:));
- (void)stopWithCompletion:(void (^)(void))completion NS_SWIFT_NAME(stop(completion:));
/// Stop and release the audio session on the playback queue; completion returns on main.
- (void)closeWithCompletion:(void (^)(void))completion NS_SWIFT_NAME(close(completion:));
@end

NS_ASSUME_NONNULL_END
