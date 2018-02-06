//
//  Compression.h
//  imageCropPicker
//
//  Created by Ivan Pusic on 12/24/16.
//  Copyright © 2016 Ivan Pusic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "ImageResult.h"



@interface VideoResult : NSObject

@end

@interface Compression : NSObject

- (ImageResult*) compressImage:(UIImage*)image withOptions:(NSDictionary*)options;
- (void)compressVideo:(NSURL*)inputURL
            outputURL:(NSURL*)outputURL
          withOptions:(NSDictionary*)options
              handler:(void (^)(AVAssetExportSession*))handler;

@property NSDictionary *exportPresets;

@end
