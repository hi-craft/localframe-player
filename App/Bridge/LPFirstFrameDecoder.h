#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@interface LPFrameCancellation : NSObject
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
- (void)cancel;
@end

@interface LPFirstFrameDecoder : NSObject
/// Blocking, bounded background operation. Captures the first decoded frame, without seeking.
+ (nullable UIImage *)imageAtFileURL:(NSURL *)url cancellation:(LPFrameCancellation *)cancellation
    NS_SWIFT_NAME(image(fileURL:cancellation:));
/// Larger first-frame image for the featured cover, capped at 960 x 540 pixels.
+ (nullable UIImage *)imageAtFileURL:(NSURL *)url cancellation:(LPFrameCancellation *)cancellation
                       maximumSize:(CGSize)maximumSize
    NS_SWIFT_NAME(image(fileURL:cancellation:maximumSize:));
/// Separate silent decoder for timeline previews; never seeks the playback instance.
+ (nullable UIImage *)imageAtFileURL:(NSURL *)url seconds:(double)seconds
                      cancellation:(LPFrameCancellation *)cancellation maximumSize:(CGSize)maximumSize
    NS_SWIFT_NAME(image(fileURL:seconds:cancellation:maximumSize:));
@end
NS_ASSUME_NONNULL_END
