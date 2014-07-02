//
//  ViewController.m
//  GLCanvas
//
//  Created by Cortex on 11/5/13.
//  Copyright (c) 2013 LightScaled Solutions. All rights reserved.
//

#import "ViewController.h"
#import "GLCanvas.h"

@interface ViewController ()

@end

@implementation ViewController

 

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(IBAction) sliderChanged:(UISlider *) slider
{
    if(slider == _xSlider) {
        _canvas.xRotation = slider.value;
    }
    
    if(slider == _ySlider) {
        _canvas.yRotation = slider.value;

    }
    
    if(slider == _zSlider) {
        _canvas.zRotation = slider.value;
    }
}

@end
