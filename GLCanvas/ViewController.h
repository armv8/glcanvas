//
//  ViewController.h
//  GLCanvas
//
//  Created by Cortex on 11/5/13.
//  Copyright (c) 2013 LightScaled Solutions. All rights reserved.
//

#import <UIKit/UIKit.h>


@class GLCanvas;
@interface ViewController : UIViewController

@property (nonatomic,weak) IBOutlet GLCanvas * canvas;


@property (nonatomic,weak) IBOutlet UISlider * xSlider;
@property (nonatomic,weak) IBOutlet UISlider * ySlider;
@property (nonatomic,weak) IBOutlet UISlider * zSlider;

-(IBAction) sliderChanged:(UISlider *) slider;


@end
