//
//  ImageCropView.m
//  ImageCropper
//
//  Created by mo shanping on 2018/2/6.
//  Copyright © 2018年 oeasy. All rights reserved.
//

#import "ImageCropView.h"
#import "RSKTouchView.h"
#import "RSKImageScrollView.h"
#import "RSKInternalUtility.h"
#import "UIImage+RSKImageCropper.h"
#import "CGGeometry+RSKImageCropper.h"
#import "UIApplication+RSKImageCropper.h"
#import "UIImage+Resize.h"


static const CGFloat kResetAnimationDuration = 0.4;
static const CGFloat kLayoutImageScrollViewAnimationDuration = 0.25;

// K is a constant such that the accumulated error of our floating-point computations is definitely bounded by K units in the last place.
#ifdef CGFLOAT_IS_DOUBLE
static const CGFloat kK = 9;
#else
static const CGFloat kK = 0;
#endif

@interface ImageCropView ()<UIGestureRecognizerDelegate>
@property (assign, nonatomic) BOOL originalNavigationControllerNavigationBarHidden;
@property (strong, nonatomic) UIImage *originalNavigationControllerNavigationBarShadowImage;
@property (copy, nonatomic) UIColor *originalNavigationControllerViewBackgroundColor;
@property (assign, nonatomic) BOOL originalStatusBarHidden;

@property (strong, nonatomic) RSKImageScrollView *imageScrollView;
@property (strong, nonatomic) RSKTouchView *overlayView;
@property (strong, nonatomic) CAShapeLayer *maskLayer;

@property (assign, nonatomic) CGRect maskRect;
@property (copy, nonatomic) UIBezierPath *maskPath;

@property (readonly, nonatomic) CGRect rectForMaskPath;
@property (readonly, nonatomic) CGRect rectForClipPath;

@property (strong, nonatomic) UILabel *moveAndScaleLabel;
@property (strong, nonatomic) UIButton *firstButton;
@property (strong, nonatomic) UIButton *secondButton;
@property (strong, nonatomic) UIButton *thirdButton;

@property (strong, nonatomic) UITapGestureRecognizer *doubleTapGestureRecognizer;
@property (strong, nonatomic) UIRotationGestureRecognizer *rotationGestureRecognizer;

@property (assign, nonatomic) BOOL didSetupConstraints;
@property (strong, nonatomic) NSLayoutConstraint *moveAndScaleLabelTopConstraint;
@property (strong, nonatomic) NSLayoutConstraint *firstButtonBottomConstraint;
@property (strong, nonatomic) NSLayoutConstraint *firstButtonLeadingConstraint;
@property (strong, nonatomic) NSLayoutConstraint *secondButtonBottomConstraint;
@property (strong, nonatomic) NSLayoutConstraint *secondButtonLeadingConstraint;
@property (strong, nonatomic) NSLayoutConstraint *thirdButtonBottomConstraint;
@property (strong, nonatomic) NSLayoutConstraint *thirdButtonTrailingConstraint;
@end

@implementation ImageCropView

- (instancetype)init
{
    self = [super init];
    if (self) {
        _avoidEmptySpaceAroundImage = NO;
        _alwaysBounceVertical = NO;
        _alwaysBounceHorizontal = NO;
        _applyMaskToCroppedImage = NO;
        _maskLayerLineWidth = 1.0;
        _rotationEnabled = NO;
        _cropMode = RSKImageCropModeCircle;
        
        _portraitCircleMaskRectInnerEdgeInset = 15.0f;
        _portraitSquareMaskRectInnerEdgeInset = 20.0f;
        _portraitMoveAndScaleLabelTopAndCropViewTopVerticalSpace = 64.0f;
        _portraitCropViewBottomAndCancelButtonBottomVerticalSpace = 21.0f;
        _portraitCropViewBottomAndChooseButtonBottomVerticalSpace = 21.0f;
        _portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace = 13.0f;
        _portraitCropViewTrailingAndChooseButtonTrailingHorizontalSpace = 13.0;
        
        _landscapeCircleMaskRectInnerEdgeInset = 45.0f;
        _landscapeSquareMaskRectInnerEdgeInset = 45.0f;
        _landscapeMoveAndScaleLabelTopAndCropViewTopVerticalSpace = 12.0f;
        _landscapeCropViewBottomAndCancelButtonBottomVerticalSpace = 12.0f;
        _landscapeCropViewBottomAndChooseButtonBottomVerticalSpace = 12.0f;
        _landscapeCancelButtonLeadingAndCropViewLeadingHorizontalSpace = 13.0;
        _landscapeCropViewTrailingAndChooseButtonTrailingHorizontalSpace = 13.0;
        self.backgroundColor = [UIColor redColor];
        
        //默认配置
        self.options = @{
                         @"multiple": @NO,
                         @"cropping": @NO,
                         @"cropperCircleOverlay": @NO,
                         @"includeBase64": @NO,
                         @"includeExif": @NO,
                         @"compressVideo": @YES,
                         @"minFiles": @1,
                         @"maxFiles": @5,
                         @"width": @200,
                         @"waitAnimationEnd": @YES,
                         @"height": @200,
                         @"useFrontCamera": @NO,
                         @"compressImageQuality": @1,
                         @"compressVideoPreset": @"MediumQuality",
                         @"loadingLabelText": @"正在处理...",
                         @"mediaType": @"any",
                         @"showsSelectedCount": @YES
                         };
        
        self.compression = [[Compression alloc] init];
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)originalImage
{
    self = [self init];
    if (self) {
        _originalImage = originalImage;
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)originalImage cropMode:(RSKImageCropMode)cropMode
{
    self = [self initWithImage:originalImage];
    if (self) {
        _cropMode = cropMode;
    }
    return self;
}

- (void)setUp
{
    
    self.backgroundColor = [UIColor blackColor];
    self.clipsToBounds = YES;
    
    [self addSubview:self.imageScrollView];
    [self addSubview:self.overlayView];
    //    [self addSubview:self.moveAndScaleLabel];
    [self addSubview:self.firstButton];
    [self addSubview:self.secondButton];
    [self addSubview:self.thirdButton];
    
    [self addGestureRecognizer:self.doubleTapGestureRecognizer];
    [self addGestureRecognizer:self.rotationGestureRecognizer];
    
    [self setUpSubviews];
    
    [self displayImage];
}



- (void)setUpSubviews
{
    [self updateMaskRect];
    [self layoutImageScrollView];
    [self layoutOverlayView];
    [self updateMaskPath];
    [self updateViewConstraints];
}



- (void)updateViewConstraints
{
    
    float fontSize = 18;
    float imageWidth = 20;
    UIFont * font = [UIFont fontWithName:@"Times New Roman" size:fontSize];
    CGSize firstTitleSize = [@"设为封面" sizeWithFont:font constrainedToSize:CGSizeMake(MAXFLOAT, fontSize)];
    CGSize otherTitleSize = [@"删除" sizeWithFont:font constrainedToSize:CGSizeMake(MAXFLOAT, fontSize)];
    
    
    float viewHeight = self.frame.size.height;
    float viewWidth = self.frame.size.width;
    float btnHeight = imageWidth;
    float vBottomSpace = 80;
    float intelval = 10;
    float firstBtnWidth = imageWidth + firstTitleSize.width + intelval;
    float secondBtnWidth = imageWidth + otherTitleSize.width + intelval;
    float thirdBtnWIdth = imageWidth + otherTitleSize.width + intelval;
    float edgeSpace = 30;
    float hSpace = (viewWidth - (firstBtnWidth + secondBtnWidth + thirdBtnWIdth) - 2 * edgeSpace) / 2 ;
    float y = viewHeight - btnHeight - vBottomSpace;
    
    self.firstButton.titleLabel.font=[UIFont systemFontOfSize:fontSize];
    self.secondButton.titleLabel.font=[UIFont systemFontOfSize:fontSize];
    self.thirdButton.titleLabel.font=[UIFont systemFontOfSize:fontSize];
    
    
    self.firstButton.imageEdgeInsets = UIEdgeInsetsMake(0,0, 0, firstTitleSize.width + intelval);
    self.firstButton.titleEdgeInsets = UIEdgeInsetsMake(0, -(imageWidth+15), 0, 0);
    
    self.secondButton.imageEdgeInsets = UIEdgeInsetsMake(0,0, 0, otherTitleSize.width + intelval);
    self.secondButton.titleEdgeInsets = UIEdgeInsetsMake(0, -(imageWidth+15), 0, 0);
    
    self.thirdButton.imageEdgeInsets = UIEdgeInsetsMake(0,0, 0, otherTitleSize.width + intelval);
    self.thirdButton.titleEdgeInsets = UIEdgeInsetsMake(0, -(imageWidth+15), 0, 0);
    
    [self.thirdButton setTitle:@"裁剪" forState:UIControlStateNormal];
    [self.thirdButton setImage:[UIImage imageNamed:@"delete"] forState:UIControlStateNormal];
    
    if(false) {
        
        [self.firstButton setTitle:@"设为封面" forState:UIControlStateNormal];
        [self.firstButton setImage:[UIImage imageNamed:@"delete"] forState:UIControlStateNormal];
        [self.secondButton setTitle:@"删除" forState:UIControlStateNormal];
        [self.secondButton setImage:[UIImage imageNamed:@"delete"] forState:UIControlStateNormal];
        
        self.firstButton.frame =  CGRectMake(edgeSpace, y, firstBtnWidth, btnHeight);
        self.secondButton.frame =  CGRectMake(self.firstButton.frame.origin.x + firstBtnWidth + hSpace, y, secondBtnWidth, btnHeight);
        self.thirdButton.frame =  CGRectMake(self.secondButton.frame.origin.x + secondBtnWidth + hSpace, y, thirdBtnWIdth, btnHeight);
        
    } else {
        
        [self.firstButton removeFromSuperview];
        
        [self.secondButton setTitle:@"取消" forState:UIControlStateNormal];
        [self.secondButton setImage:[UIImage imageNamed:@"delete"] forState:UIControlStateNormal];
        
        self.secondButton.frame =  CGRectMake(edgeSpace, y, secondBtnWidth, btnHeight);
        self.thirdButton.frame =  CGRectMake(viewWidth - edgeSpace - thirdBtnWIdth, y, thirdBtnWIdth, btnHeight);
    }
    
    
    
    //    if (!self.didSetupConstraints) {
    //
    //
    //        // --------------------
    //        // The button "first".
    //        // --------------------
    //
    //         CGFloat  constant = self.portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace;
    //        self.firstButtonLeadingConstraint = [NSLayoutConstraint constraintWithItem:self.firstButton attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual
    //                                                                             toItem:self attribute:NSLayoutAttributeLeading multiplier:1.0f
    //                                                                           constant:constant];
    //        [self addConstraint:self.firstButtonLeadingConstraint];
    //
    //        constant = self.portraitCropViewBottomAndCancelButtonBottomVerticalSpace;
    //        self.firstButtonBottomConstraint = [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
    //                                                                            toItem:self.firstButton attribute:NSLayoutAttributeBottom multiplier:1.0f
    //                                                                          constant:constant];
    //        [self addConstraint:self.firstButtonBottomConstraint];
    //
    //        // --------------------
    //        // The button "second".
    //        // --------------------
    //
    //        constant = self.portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace;
    //        self.secondButtonLeadingConstraint = [NSLayoutConstraint constraintWithItem:self.secondButton attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual
    //                                                                            toItem:self attribute:NSLayoutAttributeLeading multiplier:1.0f
    //                                                                          constant:constant];
    //        [self addConstraint:self.secondButtonLeadingConstraint];
    //
    //        constant = self.portraitCropViewBottomAndCancelButtonBottomVerticalSpace;
    //        self.secondButtonBottomConstraint = [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
    //                                                                           toItem:self.firstButton attribute:NSLayoutAttributeBottom multiplier:1.0f
    //                                                                         constant:constant];
    //        [self addConstraint:self.secondButtonBottomConstraint];
    //
    //        // --------------------
    //        // The button "third".
    //        // --------------------
    //
    //        constant = self.portraitCropViewTrailingAndChooseButtonTrailingHorizontalSpace;
    //        self.thirdButtonTrailingConstraint = [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual
    //                                                                              toItem:self.thirdButton attribute:NSLayoutAttributeTrailing multiplier:1.0f
    //                                                                            constant:constant];
    //        [self addConstraint:self.thirdButtonTrailingConstraint];
    //
    //        constant = self.portraitCropViewBottomAndChooseButtonBottomVerticalSpace;
    //        self.thirdButtonBottomConstraint = [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
    //                                                                            toItem:self.thirdButton attribute:NSLayoutAttributeBottom multiplier:1.0f
    //                                                                          constant:constant];
    //        [self addConstraint:self.thirdButtonBottomConstraint];
    //
    //        self.didSetupConstraints = YES;
    //    } else {
    //        if ([self isPortraitInterfaceOrientation]) {
    ////            self.moveAndScaleLabelTopConstraint.constant = self.portraitMoveAndScaleLabelTopAndCropViewTopVerticalSpace;
    //            self.firstButtonBottomConstraint.constant = self.portraitCropViewBottomAndCancelButtonBottomVerticalSpace;
    //            self.firstButtonLeadingConstraint.constant = self.portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace;
    //            self.thirdButtonBottomConstraint.constant = self.portraitCropViewBottomAndChooseButtonBottomVerticalSpace;
    //            self.thirdButtonTrailingConstraint.constant = self.portraitCropViewTrailingAndChooseButtonTrailingHorizontalSpace;
    //        } else {
    ////            self.moveAndScaleLabelTopConstraint.constant = self.landscapeMoveAndScaleLabelTopAndCropViewTopVerticalSpace;
    //            self.firstButtonBottomConstraint.constant = self.landscapeCropViewBottomAndCancelButtonBottomVerticalSpace;
    //            self.firstButtonLeadingConstraint.constant = self.landscapeCancelButtonLeadingAndCropViewLeadingHorizontalSpace;
    //            self.thirdButtonBottomConstraint.constant = self.landscapeCropViewBottomAndChooseButtonBottomVerticalSpace;
    //            self.thirdButtonTrailingConstraint.constant = self.landscapeCropViewTrailingAndChooseButtonTrailingHorizontalSpace;
    //        }
    //    }
}

#pragma mark - Custom Accessors

- (RSKImageScrollView *)imageScrollView
{
    if (!_imageScrollView) {
        _imageScrollView = [[RSKImageScrollView alloc] init];
        _imageScrollView.clipsToBounds = NO;
        _imageScrollView.aspectFill = self.avoidEmptySpaceAroundImage;
        _imageScrollView.alwaysBounceHorizontal = self.alwaysBounceHorizontal;
        _imageScrollView.alwaysBounceVertical = self.alwaysBounceVertical;
    }
    return _imageScrollView;
}

- (RSKTouchView *)overlayView
{
    if (!_overlayView) {
        _overlayView = [[RSKTouchView alloc] init];
        _overlayView.receiver = self.imageScrollView;
        [_overlayView.layer addSublayer:self.maskLayer];
    }
    return _overlayView;
}

- (CAShapeLayer *)maskLayer
{
    if (!_maskLayer) {
        _maskLayer = [CAShapeLayer layer];
        _maskLayer.fillRule = kCAFillRuleEvenOdd;
        _maskLayer.fillColor = self.maskLayerColor.CGColor;
        _maskLayer.lineWidth = self.maskLayerLineWidth;
        _maskLayer.strokeColor = self.maskLayerStrokeColor.CGColor;
    }
    return _maskLayer;
}

- (UIColor *)maskLayerColor
{
    if (!_maskLayerColor) {
        _maskLayerColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.7f];
    }
    return _maskLayerColor;
}

- (UILabel *)moveAndScaleLabel
{
    if (!_moveAndScaleLabel) {
        _moveAndScaleLabel = [[UILabel alloc] init];
        _moveAndScaleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _moveAndScaleLabel.backgroundColor = [UIColor clearColor];
        _moveAndScaleLabel.text = RSKLocalizedString(@"Move and Scale", @"Move and Scale label");
        _moveAndScaleLabel.textColor = [UIColor whiteColor];
        _moveAndScaleLabel.opaque = NO;
    }
    return _moveAndScaleLabel;
}

- (UIButton *)firstButton
{
    if (!_firstButton) {
        _firstButton = [[UIButton alloc] init];
        [_firstButton setTitle:RSKLocalizedString(@"Cancel", @"Cancel button") forState:UIControlStateNormal];
        [_firstButton addTarget:self action:@selector(onFirstButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        _firstButton.opaque = NO;
    }
    return _firstButton;
}

- (UIButton *)secondButton
{
    if (!_secondButton) {
        _secondButton = [[UIButton alloc] init];
        [_secondButton setTitle:RSKLocalizedString(@"Cancel", @"Cancel button") forState:UIControlStateNormal];
        [_secondButton addTarget:self action:@selector(onSecondButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        _secondButton.opaque = NO;
    }
    return _secondButton;
}

- (UIButton *)thirdButton
{
    if (!_thirdButton) {
        _thirdButton = [[UIButton alloc] init];
        [_thirdButton setTitle:RSKLocalizedString(@"Choose", @"Choose button") forState:UIControlStateNormal];
        [_thirdButton addTarget:self action:@selector(onThirdButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        _thirdButton.opaque = NO;
    }
    return _thirdButton;
}

- (UITapGestureRecognizer *)doubleTapGestureRecognizer
{
    if (!_doubleTapGestureRecognizer) {
        _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
        _doubleTapGestureRecognizer.delaysTouchesEnded = NO;
        _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
        _doubleTapGestureRecognizer.delegate = self;
    }
    return _doubleTapGestureRecognizer;
}

- (UIRotationGestureRecognizer *)rotationGestureRecognizer
{
    if (!_rotationGestureRecognizer) {
        _rotationGestureRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotation:)];
        _rotationGestureRecognizer.delaysTouchesEnded = NO;
        _rotationGestureRecognizer.delegate = self;
        _rotationGestureRecognizer.enabled = self.isRotationEnabled;
    }
    return _rotationGestureRecognizer;
}

- (CGRect)cropRect
{
    CGRect cropRect = CGRectZero;
    float zoomScale = 1.0 / self.imageScrollView.zoomScale;
    
    cropRect.origin.x = floor(self.imageScrollView.contentOffset.x * zoomScale);
    cropRect.origin.y = floor(self.imageScrollView.contentOffset.y * zoomScale);
    cropRect.size.width = CGRectGetWidth(self.imageScrollView.bounds) * zoomScale;
    cropRect.size.height = CGRectGetHeight(self.imageScrollView.bounds) * zoomScale;
    
    CGFloat width = CGRectGetWidth(cropRect);
    CGFloat height = CGRectGetHeight(cropRect);
    CGFloat ceilWidth = ceil(width);
    CGFloat ceilHeight = ceil(height);
    
    if (fabs(ceilWidth - width) < pow(10, kK) * RSK_EPSILON * fabs(ceilWidth + width) || fabs(ceilWidth - width) < RSK_MIN ||
        fabs(ceilHeight - height) < pow(10, kK) * RSK_EPSILON * fabs(ceilHeight + height) || fabs(ceilHeight - height) < RSK_MIN) {
        
        cropRect.size.width = ceilWidth;
        cropRect.size.height = ceilHeight;
    } else {
        cropRect.size.width = floor(width);
        cropRect.size.height = floor(height);
    }
    
    return cropRect;
}

- (CGRect)rectForClipPath
{
    if (!self.maskLayerStrokeColor) {
        return self.overlayView.frame;
    } else {
        CGFloat maskLayerLineHalfWidth = self.maskLayerLineWidth / 2.0;
        return CGRectInset(self.overlayView.frame, -maskLayerLineHalfWidth, -maskLayerLineHalfWidth);
    }
}

- (CGRect)rectForMaskPath
{
    if (!self.maskLayerStrokeColor) {
        return self.maskRect;
    } else {
        CGFloat maskLayerLineHalfWidth = self.maskLayerLineWidth / 2.0;
        return CGRectInset(self.maskRect, maskLayerLineHalfWidth, maskLayerLineHalfWidth);
    }
}

- (CGFloat)rotationAngle
{
    CGAffineTransform transform = self.imageScrollView.transform;
    CGFloat rotationAngle = atan2(transform.b, transform.a);
    return rotationAngle;
}

- (CGFloat)zoomScale
{
    return self.imageScrollView.zoomScale;
}

- (void)setAvoidEmptySpaceAroundImage:(BOOL)avoidEmptySpaceAroundImage
{
    if (_avoidEmptySpaceAroundImage != avoidEmptySpaceAroundImage) {
        _avoidEmptySpaceAroundImage = avoidEmptySpaceAroundImage;
        
        self.imageScrollView.aspectFill = avoidEmptySpaceAroundImage;
    }
}

- (void)setAlwaysBounceVertical:(BOOL)alwaysBounceVertical
{
    if (_alwaysBounceVertical != alwaysBounceVertical) {
        _alwaysBounceVertical = alwaysBounceVertical;
        
        self.imageScrollView.alwaysBounceVertical = alwaysBounceVertical;
    }
}

- (void)setAlwaysBounceHorizontal:(BOOL)alwaysBounceHorizontal
{
    if (_alwaysBounceHorizontal != alwaysBounceHorizontal) {
        _alwaysBounceHorizontal = alwaysBounceHorizontal;
        
        self.imageScrollView.alwaysBounceHorizontal = alwaysBounceHorizontal;
    }
}

- (void)setCropMode:(RSKImageCropMode)cropMode
{
    if (_cropMode != cropMode) {
        _cropMode = cropMode;
        
        if (self.imageScrollView.zoomView) {
            [self reset:NO];
        }
    }
}

- (void)setOriginalImage:(UIImage *)originalImage
{
    if (![_originalImage isEqual:originalImage]) {
        _originalImage = originalImage;
        
        [self displayImage];
        
    }
}

- (void)setMaskPath:(UIBezierPath *)maskPath
{
    if (![_maskPath isEqual:maskPath]) {
        _maskPath = maskPath;
        
        UIBezierPath *clipPath = [UIBezierPath bezierPathWithRect:self.rectForClipPath];
        [clipPath appendPath:maskPath];
        clipPath.usesEvenOddFillRule = YES;
        
        CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
        pathAnimation.duration = [CATransaction animationDuration];
        pathAnimation.timingFunction = [CATransaction animationTimingFunction];
        [self.maskLayer addAnimation:pathAnimation forKey:@"path"];
        
        self.maskLayer.path = [clipPath CGPath];
    }
}

- (void)setRotationAngle:(CGFloat)rotationAngle
{
    if (self.rotationAngle != rotationAngle) {
        CGFloat rotation = (rotationAngle - self.rotationAngle);
        CGAffineTransform transform = CGAffineTransformRotate(self.imageScrollView.transform, rotation);
        self.imageScrollView.transform = transform;
    }
}

- (void)setRotationEnabled:(BOOL)rotationEnabled
{
    if (_rotationEnabled != rotationEnabled) {
        _rotationEnabled = rotationEnabled;
        
        self.rotationGestureRecognizer.enabled = rotationEnabled;
    }
}

- (void)setZoomScale:(CGFloat)zoomScale
{
    self.imageScrollView.zoomScale = zoomScale;
}

#pragma mark - Action handling

- (void)onFirstButtonTouch:(UIBarButtonItem *)sender
{
    [self cancelCrop];
}

- (void)onSecondButtonTouch:(UIBarButtonItem *)sender
{
    
}

- (void)onThirdButtonTouch:(UIBarButtonItem *)sender
{
    [self cropImage];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    [self reset:YES];
}

- (void)handleRotation:(UIRotationGestureRecognizer *)gestureRecognizer
{
    [self setRotationAngle:(self.rotationAngle + gestureRecognizer.rotation)];
    gestureRecognizer.rotation = 0;
    
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [UIView animateWithDuration:kLayoutImageScrollViewAnimationDuration
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             [self layoutImageScrollView];
                         }
                         completion:nil];
    }
}

#pragma mark - Public

- (BOOL)isPortraitInterfaceOrientation
{
    return CGRectGetHeight(self.bounds) > CGRectGetWidth(self.bounds);
}

#pragma mark - Private

- (void)reset:(BOOL)animated
{
    if (animated) {
        [UIView beginAnimations:@"rsk_reset" context:NULL];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
        [UIView setAnimationDuration:kResetAnimationDuration];
        [UIView setAnimationBeginsFromCurrentState:YES];
    }
    
    [self resetRotation];
    [self resetFrame];
    [self resetZoomScale];
    [self resetContentOffset];
    
    if (animated) {
        [UIView commitAnimations];
    }
}

- (void)resetContentOffset
{
    CGSize boundsSize = self.imageScrollView.bounds.size;
    CGRect frameToCenter = self.imageScrollView.zoomView.frame;
    
    CGPoint contentOffset;
    if (CGRectGetWidth(frameToCenter) > boundsSize.width) {
        contentOffset.x = (CGRectGetWidth(frameToCenter) - boundsSize.width) * 0.5f;
    } else {
        contentOffset.x = 0;
    }
    if (CGRectGetHeight(frameToCenter) > boundsSize.height) {
        contentOffset.y = (CGRectGetHeight(frameToCenter) - boundsSize.height) * 0.5f;
    } else {
        contentOffset.y = 0;
    }
    
    self.imageScrollView.contentOffset = contentOffset;
}

- (void)resetFrame
{
    [self layoutImageScrollView];
}

- (void)resetRotation
{
    [self setRotationAngle:0.0];
}

- (void)resetZoomScale
{
    CGFloat zoomScale;
    if (CGRectGetWidth(self.bounds) > CGRectGetHeight(self.bounds)) {
        zoomScale = CGRectGetHeight(self.bounds) / self.originalImage.size.height;
    } else {
        zoomScale = CGRectGetWidth(self.bounds) / self.originalImage.size.width;
    }
    self.imageScrollView.zoomScale = zoomScale;
}

- (NSArray *)intersectionPointsOfLineSegment:(RSKLineSegment)lineSegment withRect:(CGRect)rect
{
    RSKLineSegment top = RSKLineSegmentMake(CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)),
                                            CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)));
    
    RSKLineSegment right = RSKLineSegmentMake(CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)),
                                              CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)));
    
    RSKLineSegment bottom = RSKLineSegmentMake(CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)),
                                               CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)));
    
    RSKLineSegment left = RSKLineSegmentMake(CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)),
                                             CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)));
    
    CGPoint p0 = RSKLineSegmentIntersection(top, lineSegment);
    CGPoint p1 = RSKLineSegmentIntersection(right, lineSegment);
    CGPoint p2 = RSKLineSegmentIntersection(bottom, lineSegment);
    CGPoint p3 = RSKLineSegmentIntersection(left, lineSegment);
    
    NSMutableArray *intersectionPoints = [@[] mutableCopy];
    if (!RSKPointIsNull(p0)) {
        [intersectionPoints addObject:[NSValue valueWithCGPoint:p0]];
    }
    if (!RSKPointIsNull(p1)) {
        [intersectionPoints addObject:[NSValue valueWithCGPoint:p1]];
    }
    if (!RSKPointIsNull(p2)) {
        [intersectionPoints addObject:[NSValue valueWithCGPoint:p2]];
    }
    if (!RSKPointIsNull(p3)) {
        [intersectionPoints addObject:[NSValue valueWithCGPoint:p3]];
    }
    
    return [intersectionPoints copy];
}

- (void)displayImage
{
    if (self.originalImage) {
        [self.imageScrollView displayImage:self.originalImage];
        [self reset:NO];
    }
}

- (void)layoutImageScrollView
{
    CGRect frame = CGRectZero;
    
    // The bounds of the image scroll view should always fill the mask area.
    switch (self.cropMode) {
        case RSKImageCropModeSquare: {
            if (self.rotationAngle == 0.0) {
                frame = self.maskRect;
            } else {
                // Step 1: Rotate the left edge of the initial rect of the image scroll view clockwise around the center by `rotationAngle`.
                CGRect initialRect = self.maskRect;
                CGFloat rotationAngle = self.rotationAngle;
                
                CGPoint leftTopPoint = CGPointMake(initialRect.origin.x, initialRect.origin.y);
                CGPoint leftBottomPoint = CGPointMake(initialRect.origin.x, initialRect.origin.y + initialRect.size.height);
                RSKLineSegment leftLineSegment = RSKLineSegmentMake(leftTopPoint, leftBottomPoint);
                
                CGPoint pivot = RSKRectCenterPoint(initialRect);
                
                CGFloat alpha = fabs(rotationAngle);
                RSKLineSegment rotatedLeftLineSegment = RSKLineSegmentRotateAroundPoint(leftLineSegment, pivot, alpha);
                
                // Step 2: Find the points of intersection of the rotated edge with the initial rect.
                NSArray *points = [self intersectionPointsOfLineSegment:rotatedLeftLineSegment withRect:initialRect];
                
                // Step 3: If the number of intersection points more than one
                // then the bounds of the rotated image scroll view does not completely fill the mask area.
                // Therefore, we need to update the frame of the image scroll view.
                // Otherwise, we can use the initial rect.
                if (points.count > 1) {
                    // We have a right triangle.
                    
                    // Step 4: Calculate the altitude of the right triangle.
                    if ((alpha > M_PI_2) && (alpha < M_PI)) {
                        alpha = alpha - M_PI_2;
                    } else if ((alpha > (M_PI + M_PI_2)) && (alpha < (M_PI + M_PI))) {
                        alpha = alpha - (M_PI + M_PI_2);
                    }
                    CGFloat sinAlpha = sin(alpha);
                    CGFloat cosAlpha = cos(alpha);
                    CGFloat hypotenuse = RSKPointDistance([points[0] CGPointValue], [points[1] CGPointValue]);
                    CGFloat altitude = hypotenuse * sinAlpha * cosAlpha;
                    
                    // Step 5: Calculate the target width.
                    CGFloat initialWidth = CGRectGetWidth(initialRect);
                    CGFloat targetWidth = initialWidth + altitude * 2;
                    
                    // Step 6: Calculate the target frame.
                    CGFloat scale = targetWidth / initialWidth;
                    CGPoint center = RSKRectCenterPoint(initialRect);
                    frame = RSKRectScaleAroundPoint(initialRect, center, scale, scale);
                    
                    // Step 7: Avoid floats.
                    frame.origin.x = floor(CGRectGetMinX(frame));
                    frame.origin.y = floor(CGRectGetMinY(frame));
                    frame = CGRectIntegral(frame);
                } else {
                    // Step 4: Use the initial rect.
                    frame = initialRect;
                }
            }
            break;
        }
        case RSKImageCropModeCircle: {
            frame = self.maskRect;
            break;
        }
        case RSKImageCropModeCustom: {
            frame = self.maskRect;
            break;
        }
    }
    
    CGAffineTransform transform = self.imageScrollView.transform;
    self.imageScrollView.transform = CGAffineTransformIdentity;
    self.imageScrollView.frame = frame;
    self.imageScrollView.transform = transform;
    
    if(self.cropMode != RSKImageCropModeCircle) {
        [self addGrid:self frame:frame];
    }
}

- (void)layoutOverlayView
{
    CGRect frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds) * 2, CGRectGetHeight(self.bounds) * 2);
    self.overlayView.frame = frame;
}

- (void)addGrid:(UIView *)view frame:(CGRect)frame {
    
    if(self.cropMode == RSKImageCropModeCustom && frame.size.width == view.frame.size.width){
        return;
    }
    
    void (^addLineWidthRect)(CGRect rect) = ^(CGRect rect) {
        CALayer *layer = [[CALayer alloc] init];
        [view.layer addSublayer:layer];
        layer.frame = rect;
        layer.backgroundColor = [[UIColor whiteColor] CGColor];
    };
    
    CGFloat viewWidth = frame.size.width;
    CGFloat viewHeight = frame.size.height;
    
    if(self.cropMode == RSKImageCropModeCustom) {
        
        
        CGFloat vSize = viewWidth / 3;
        CGFloat hSize = viewHeight / 2;
        
        
        
        //坚线
        for (int i= frame.origin.x; i<viewWidth; i+=vSize) {
            addLineWidthRect(CGRectMake(i, frame.origin.y, 1, viewHeight));
        }
        
        addLineWidthRect(CGRectMake(frame.origin.x + frame.size.width - 1, frame.origin.y, 1, viewHeight));
        
        //横线
        for (int i=frame.origin.y; i<frame.origin.y + viewHeight - 20; i+=hSize) {
            addLineWidthRect(CGRectMake(frame.origin.x, i, viewWidth, 1));
        }
        
        addLineWidthRect(CGRectMake(frame.origin.x, frame.origin.y + viewHeight - 1, viewWidth, 1));
        
    } else {
        
        CGFloat size = viewWidth / 3;
        
        
        //坚线
        for (int i= frame.origin.x; i<viewWidth; i+=size) {
            addLineWidthRect(CGRectMake(i, frame.origin.y, 1, viewHeight));
        }
        
        addLineWidthRect(CGRectMake(frame.origin.x + frame.size.width - 1, frame.origin.y, 1, viewHeight));
        
        //横线
        for (int i=frame.origin.y; i<frame.origin.y + viewHeight - 20; i+=size) {
            addLineWidthRect(CGRectMake(frame.origin.x, i, viewWidth, 1));
        }
        
        addLineWidthRect(CGRectMake(frame.origin.x, frame.origin.y + viewHeight - 1, viewWidth, 1));
    }
}

//裁剪框frame
- (void)updateMaskRect
{
    switch (self.cropMode) {
        case RSKImageCropModeCircle: {
            CGFloat viewWidth = CGRectGetWidth(self.frame);
            CGFloat viewHeight = CGRectGetHeight(self.frame);
            
            CGFloat diameter;
            if ([self isPortraitInterfaceOrientation]) {
                diameter = MIN(viewWidth, viewHeight) - self.portraitCircleMaskRectInnerEdgeInset * 2;
            } else {
                diameter = MIN(viewWidth, viewHeight) - self.landscapeCircleMaskRectInnerEdgeInset * 2;
            }
            
            CGSize maskSize = CGSizeMake(diameter, diameter);
            
            self.maskRect = CGRectMake((viewWidth - maskSize.width) * 0.5f,
                                       (viewHeight - maskSize.height) * 0.5f,
                                       maskSize.width,
                                       maskSize.height);
            break;
        }
            
        case RSKImageCropModeSquare: {
            CGFloat viewWidth = CGRectGetWidth(self.bounds);
            CGFloat viewHeight = CGRectGetHeight(self.bounds);
            
            CGFloat length;
            if ([self isPortraitInterfaceOrientation]) {
                length = MIN(viewWidth, viewHeight) - self.portraitSquareMaskRectInnerEdgeInset * 2;
            } else {
                length = MIN(viewWidth, viewHeight) - self.landscapeSquareMaskRectInnerEdgeInset * 2;
            }
            
            CGSize maskSize = CGSizeMake(length, length);
            
            self.maskRect = CGRectMake((viewWidth - maskSize.width) * 0.5f,
                                       (viewHeight - maskSize.height) * 0.5f,
                                       maskSize.width,
                                       maskSize.height);
            break;
        }
        case RSKImageCropModeCustom: {
            
            //宽高参数要传进来
            CGFloat viewWidth = 350;
            CGFloat viewHeight = 175;
            CGFloat windowWidth = self.frame.size.width;
            CGFloat windowHeight = self.frame.size.height;
            
            self.maskRect = CGRectMake((windowWidth - viewWidth)/2,(windowHeight - viewHeight)/2,viewWidth,viewHeight);
            break;
        }
    }
}

- (void)updateMaskPath
{
    switch (self.cropMode) {
        case RSKImageCropModeCircle: {
            self.maskPath = [UIBezierPath bezierPathWithOvalInRect:self.rectForMaskPath];
            break;
        }
        case RSKImageCropModeSquare: {
            self.maskPath = [UIBezierPath bezierPathWithRect:self.rectForMaskPath];
            break;
        }
        case RSKImageCropModeCustom: {
            self.maskPath = [UIBezierPath bezierPathWithRect:self.rectForMaskPath];
            break;
        }
    }
}

- (UIImage *)croppedImage:(UIImage *)image cropRect:(CGRect)cropRect scale:(CGFloat)imageScale orientation:(UIImageOrientation)imageOrientation
{
    if (!image.images) {
        CGImageRef croppedCGImage = CGImageCreateWithImageInRect(image.CGImage, cropRect);
        UIImage *croppedImage = [UIImage imageWithCGImage:croppedCGImage scale:imageScale orientation:imageOrientation];
        CGImageRelease(croppedCGImage);
        return croppedImage;
    } else {
        UIImage *animatedImage = image;
        NSMutableArray *croppedImages = [NSMutableArray array];
        for (UIImage *image in animatedImage.images) {
            UIImage *croppedImage = [self croppedImage:image cropRect:cropRect scale:imageScale orientation:imageOrientation];
            [croppedImages addObject:croppedImage];
        }
        return [UIImage animatedImageWithImages:croppedImages duration:image.duration];
    }
}

- (UIImage *)croppedImage:(UIImage *)image cropMode:(RSKImageCropMode)cropMode cropRect:(CGRect)cropRect rotationAngle:(CGFloat)rotationAngle zoomScale:(CGFloat)zoomScale maskPath:(UIBezierPath *)maskPath applyMaskToCroppedImage:(BOOL)applyMaskToCroppedImage
{
    // Step 1: check and correct the crop rect.
    CGSize imageSize = image.size;
    CGFloat x = CGRectGetMinX(cropRect);
    CGFloat y = CGRectGetMinY(cropRect);
    CGFloat width = CGRectGetWidth(cropRect);
    CGFloat height = CGRectGetHeight(cropRect);
    
    UIImageOrientation imageOrientation = image.imageOrientation;
    if (imageOrientation == UIImageOrientationRight || imageOrientation == UIImageOrientationRightMirrored) {
        cropRect.origin.x = y;
        cropRect.origin.y = floor(imageSize.width - CGRectGetWidth(cropRect) - x);
        cropRect.size.width = height;
        cropRect.size.height = width;
    } else if (imageOrientation == UIImageOrientationLeft || imageOrientation == UIImageOrientationLeftMirrored) {
        cropRect.origin.x = floor(imageSize.height - CGRectGetHeight(cropRect) - y);
        cropRect.origin.y = x;
        cropRect.size.width = height;
        cropRect.size.height = width;
    } else if (imageOrientation == UIImageOrientationDown || imageOrientation == UIImageOrientationDownMirrored) {
        cropRect.origin.x = floor(imageSize.width - CGRectGetWidth(cropRect) - x);
        cropRect.origin.y = floor(imageSize.height - CGRectGetHeight(cropRect) - y);
    }
    
    CGFloat imageScale = image.scale;
    cropRect = CGRectApplyAffineTransform(cropRect, CGAffineTransformMakeScale(imageScale, imageScale));
    
    // Step 2: create an image using the data contained within the specified rect.
    UIImage *croppedImage = [self croppedImage:image cropRect:cropRect scale:imageScale orientation:imageOrientation];
    
    // Step 3: fix orientation of the cropped image.
    croppedImage = [croppedImage fixOrientation];
    imageOrientation = croppedImage.imageOrientation;
    
    // Step 4: If current mode is `RSKImageCropModeSquare` and the image is not rotated
    // or mask should not be applied to the image after cropping and the image is not rotated,
    // we can return the cropped image immediately.
    // Otherwise, we must further process the image.
    if ((cropMode == RSKImageCropModeSquare || !applyMaskToCroppedImage) && rotationAngle == 0.0) {
        // Step 5: return the cropped image immediately.
        return croppedImage;
    } else {
        // Step 5: create a new context.
        CGSize contextSize = cropRect.size;
        UIGraphicsBeginImageContextWithOptions(contextSize, NO, imageScale);
        
        // Step 6: apply the mask if needed.
        if (applyMaskToCroppedImage) {
            // 6a: scale the mask to the size of the crop rect.
            UIBezierPath *maskPathCopy = [maskPath copy];
            CGFloat scale = 1.0 / zoomScale;
            [maskPathCopy applyTransform:CGAffineTransformMakeScale(scale, scale)];
            
            // 6b: move the mask to the top-left.
            CGPoint translation = CGPointMake(-CGRectGetMinX(maskPathCopy.bounds),
                                              -CGRectGetMinY(maskPathCopy.bounds));
            [maskPathCopy applyTransform:CGAffineTransformMakeTranslation(translation.x, translation.y)];
            
            // 6c: apply the mask.
            [maskPathCopy addClip];
        }
        
        // Step 7: rotate the cropped image if needed.
        if (rotationAngle != 0) {
            croppedImage = [croppedImage rotateByAngle:rotationAngle];
        }
        
        // Step 8: draw the cropped image.
        CGPoint point = CGPointMake(floor((contextSize.width - croppedImage.size.width) * 0.5f),
                                    floor((contextSize.height - croppedImage.size.height) * 0.5f));
        [croppedImage drawAtPoint:point];
        
        // Step 9: get the cropped image affter processing from the context.
        croppedImage = UIGraphicsGetImageFromCurrentImageContext();
        
        // Step 10: remove the context.
        UIGraphicsEndImageContext();
        
        croppedImage = [UIImage imageWithCGImage:croppedImage.CGImage scale:imageScale orientation:imageOrientation];
        
        // Step 11: return the cropped image affter processing.
        return croppedImage;
    }
}

- (NSString*) persistFile:(NSData*)data {
    // create temp file
    NSString *tmpDirFullPath = [self getTmpDirectory];
    NSString *filePath = [tmpDirFullPath stringByAppendingString:[[NSUUID UUID] UUIDString]];
    filePath = [filePath stringByAppendingString:@".jpg"];
    
    // save cropped file
    BOOL status = [data writeToFile:filePath atomically:YES];
    if (!status) {
        return nil;
    }
    
    return filePath;
}

- (NSString*) getTmpDirectory {
    NSString *TMP_DIRECTORY = @"react-native-image-crop-picker/";
    NSString *tmpFullPath = [NSTemporaryDirectory() stringByAppendingString:TMP_DIRECTORY];
    
    BOOL isDir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:tmpFullPath isDirectory:&isDir];
    if (!exists) {
        [[NSFileManager defaultManager] createDirectoryAtPath: tmpFullPath
                                  withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return tmpFullPath;
}

- (void)cropImage
{
    
    UIImage *originalImage = self.originalImage;
    RSKImageCropMode cropMode = self.cropMode;
    CGRect cropRect = self.cropRect;
    CGFloat rotationAngle = self.rotationAngle;
    CGFloat zoomScale = self.imageScrollView.zoomScale;
    UIBezierPath *maskPath = self.maskPath;
    BOOL applyMaskToCroppedImage = self.applyMaskToCroppedImage;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        UIImage *croppedImage = [self croppedImage:originalImage cropMode:cropMode cropRect:cropRect rotationAngle:rotationAngle zoomScale:zoomScale maskPath:maskPath applyMaskToCroppedImage:applyMaskToCroppedImage];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            CGSize resizedImageSize = CGSizeMake([[[self options] objectForKey:@"width"] intValue], [[[self options] objectForKey:@"height"] intValue]);
            UIImage *resizedImage = [croppedImage resizedImageToFitInSize:resizedImageSize scaleIfSmaller:YES];
            ImageResult *imageResult = [self.compression compressImage:resizedImage withOptions:self.options];
            
            NSString *filePath = [self persistFile:imageResult.data];
            if (filePath == nil) {
                //                [self dismissCropper:controller selectionDone:YES completion:[self waitAnimationEnd:^{
                //                    self.reject(ERROR_CANNOT_SAVE_IMAGE_KEY, ERROR_CANNOT_SAVE_IMAGE_MSG, nil);
                //                }]];
                return;
            }
            
            NSDictionary* exif = nil;
            if([[self.options objectForKey:@"includeExif"] boolValue]) {
                exif = [[CIImage imageWithData:imageResult.data] properties];
            }
            
            //            [self dismissCropper:controller selectionDone:YES completion:[self waitAnimationEnd:^{
            //                self.resolve([self createAttachmentResponse:filePath
            //                                                   withExif: exif
            //                                              withSourceURL: self.croppingFile[@"sourceURL"]
            //                                        withLocalIdentifier: self.croppingFile[@"localIdentifier"]
            //                                               withFilename: self.croppingFile[@"filename"]
            //                                                  withWidth:imageResult.width
            //                                                 withHeight:imageResult.height
            //                                                   withMime:imageResult.mime
            //                                                   withSize:[NSNumber numberWithUnsignedInteger:imageResult.data.length]
            //                                                   withData:[[self.options objectForKey:@"includeBase64"] boolValue] ? [imageResult.data base64EncodedStringWithOptions:0] : nil
            //                                                   withRect:cropRect
            //                                           withCreationDate:self.croppingFile[@"creationDate"]
            //                                       withModificationDate:self.croppingFile[@"modificationDate"]
            //                              ]);
            //            }]];
            
        });
    });
}

- (void)cancelCrop
{
    
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

@end
