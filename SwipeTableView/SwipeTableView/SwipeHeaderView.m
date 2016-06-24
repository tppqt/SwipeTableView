//
//  SwipeHeaderView.m
//  SwipeTableView
//
//  Created by Roy lee on 16/6/24.
//  Copyright © 2016年 Roy lee. All rights reserved.
//

#import "SwipeHeaderView.h"
#import "SwipeTableView.h"

static CGFloat rubberBandDistance(CGFloat offset, CGFloat dimension) {
    
    const CGFloat constant = 0.55f;
    CGFloat result = (constant * fabs(offset) * dimension) / (dimension + constant * fabs(offset));
    // The algorithm expects a positive offset, so we have to negate the result if the offset was negative.
    return offset < 0.0f ? -result : result;
}

@interface STDynamicItem : NSObject <UIDynamicItem>

@property (nonatomic, readwrite) CGPoint center;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readwrite) CGAffineTransform transform;

@end

@implementation STDynamicItem

- (instancetype)init {
    self = [super init];
    if (self) {
        // Sets non-zero `bounds`, because otherwise Dynamics throws an exception.
        _bounds = CGRectMake(0, 0, 1, 1);
    }
    return self;
}

@end




@interface SwipeHeaderView ()

@property (nonatomic, strong) UIPanGestureRecognizer * panGestureRecognizer;
@property (nonatomic, strong) UIDynamicAnimator * animator;
@property (nonatomic, strong) UIDynamicItemBehavior * decelerationBehavior;
@property (nonatomic, strong) UIAttachmentBehavior * springBehavior;
@property (nonatomic, strong) STDynamicItem *dynamicItem;
@property (nonatomic, assign) CGPoint orginFrameOrgin;

@end

@implementation SwipeHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // pan gesture
        self.panGestureRecognizer = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(handlePanGesture:)];
        [self addGestureRecognizer:_panGestureRecognizer];
        // animator
        self.animator = [[UIDynamicAnimator alloc]initWithReferenceView:self];
        self.dynamicItem = [[STDynamicItem alloc]init];
    }
    return self;
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)panGestureRecognizer {
    
    switch (panGestureRecognizer.state) {
        // remove animator
        case UIGestureRecognizerStateBegan:
        {
            [self.animator removeAllBehaviors];
            self.decelerationBehavior = nil;
            self.springBehavior = nil;
            self.orginFrameOrgin = self.frame.origin;
        }
        // change offset and add RubberBanding effect
        case UIGestureRecognizerStateChanged:
        {
            CGPoint translation = [panGestureRecognizer translationInView:self.superview];
            CGFloat newFrameOrginY = _orginFrameOrgin.y + translation.y;
            CGPoint minFrameOrgin = [self minFrameOrgin];
            CGPoint maxFrameOrgin = [self maxFrameOrgin];
            
            CGFloat minFrameOrginY = minFrameOrgin.y;
            CGFloat maxFrameOrginY = maxFrameOrgin.y;
            CGFloat constrainedOrignY = fmax(minFrameOrginY, fmin(newFrameOrginY, maxFrameOrginY));
            CGFloat rubberBandedY = rubberBandDistance(newFrameOrginY - constrainedOrignY, CGRectGetHeight(UIScreen.mainScreen.bounds));
            
            CGRect frame = self.frame;
            frame.origin = CGPointMake(_orginFrameOrgin.x, constrainedOrignY + rubberBandedY);
            self.frame   = frame;
        }
            break;
        case UIGestureRecognizerStateEnded:
        {
            CGPoint velocity = [panGestureRecognizer velocityInView:self];
            // only support vertical
            velocity.x = 0;
            
            self.dynamicItem.center = self.frame.origin;
            self.decelerationBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.dynamicItem]];
            [_decelerationBehavior addLinearVelocity:velocity forItem:self.dynamicItem];
            _decelerationBehavior.resistance = 2;
            
            __weak typeof(self) weakSelf = self;
            _decelerationBehavior.action = ^{
                CGPoint center = weakSelf.dynamicItem.center;
                center.x = weakSelf.orginFrameOrgin.x;
                CGRect frame = weakSelf.frame;
                frame.origin = center;
                weakSelf.frame   = frame;
            };
            
            [self.animator addBehavior:_decelerationBehavior];
        }
            break;
            
        default:
            break;
    }
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    CGPoint minFrameOrgin = [self minFrameOrgin];
    CGPoint maxFrameOrgin = [self maxFrameOrgin];
    
    BOOL outsideFrameMinimum = frame.origin.y < minFrameOrgin.y;
    BOOL outsideFrameMaximum = frame.origin.y > maxFrameOrgin.y;
    
    if ((outsideFrameMinimum || outsideFrameMaximum) &&
        (_decelerationBehavior && !_springBehavior)) {
        
        CGPoint target = frame.origin;
        if (outsideFrameMinimum) {
            target.x = fmax(target.x, minFrameOrgin.x);
            target.y = fmax(target.y, minFrameOrgin.y);
        } else if (outsideFrameMaximum) {
            target.x = fmin(target.x, maxFrameOrgin.x);
            target.y = fmin(target.y, maxFrameOrgin.y);
        }
        
        self.springBehavior = [[UIAttachmentBehavior alloc] initWithItem:self.dynamicItem attachedToAnchor:target];
        // Has to be equal to zero, because otherwise the frame wouldn't exactly match the target's position.
        _springBehavior.length = 0;
        // These two values were chosen by trial and error.
        _springBehavior.damping = 1;
        _springBehavior.frequency = 2;
        
        [self.animator addBehavior:_springBehavior];
    }
    
    if (_delegate && [_delegate respondsToSelector:@selector(swipeHeaderViewDidFrameChanged:)]) {
        [_delegate swipeHeaderViewDidFrameChanged:self];
    }
}

- (CGPoint)minFrameOrgin {
    CGPoint orgin = CGPointMake(0, 0);
    if (_delegate && [_delegate respondsToSelector:@selector(minSwipeHeaderViewFrameOrgin)]) {
        orgin = [_delegate minSwipeHeaderViewFrameOrgin];
    }
    return orgin;
}

- (CGPoint)maxFrameOrgin {
    CGPoint orgin = CGPointMake(0, 0);
    if (_delegate && [_delegate respondsToSelector:@selector(maxSwipeHeaderViewFrameOrgin)]) {
        orgin = [_delegate maxSwipeHeaderViewFrameOrgin];
    }
    return orgin;
}

- (void)endDecelerating {
    [self.animator removeAllBehaviors];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView * view = [super hitTest:point withEvent:event];
    // tap outside of the header view
    if (nil == view) {
        [self endDecelerating];
    }
    return view;
}

@end