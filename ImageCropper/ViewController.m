//
//  ViewController.m
//  ImageCropper
//
//  Created by mo shanping on 2018/2/6.
//  Copyright © 2018年 oeasy. All rights reserved.
//

#import "ViewController.h"
//#import "RSKImageCropViewController.h"
#import "ImageCropView.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    RSKImageCropViewController * vc = [[RSKImageCropViewController alloc] initWithImage:[UIImage imageNamed:@"test.png"]];
//    [vc setCropMode:RSKImageCropModeSquare];
//    [self.view addSubview:vc.view];
    
    
    ImageCropView * cropView = [[ImageCropView alloc] initWithImage:[UIImage imageNamed:@"test.png"]];
    [cropView setCropMode:RSKImageCropModeCustom];
    cropView.frame = self.view.frame;
    [cropView setUp];
    [self.view addSubview:cropView];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
