//
//  ImageResult.h
//  ImageCropper
//
//  Created by mo shanping on 2018/2/6.
//  Copyright © 2018年 oeasy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ImageResult : NSObject

@property NSData *data;
@property NSNumber *width;
@property NSNumber *height;
@property NSString *mime;
@property UIImage *image;

@end
