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
@end
NS_ASSUME_NONNULL_END
