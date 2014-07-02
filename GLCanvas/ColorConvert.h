//
//  ColorConvert.h
//  GLGraph
//
//  Created by Zaheer Naby on 8/22/13.
//  Copyright (c) 2013 Zaheer Naby. All rights reserved.
//

#ifndef GLGraph_ColorConvert_h
#define GLGraph_ColorConvert_h

#include "Colors.h"

extern void RGB2HSV(RGBColor_t * rgbColor, HSVColor_t * hsvColor);
extern void HSV2RGB(HSVColor_t * hsvColor, RGBColor_t * rgbColor);

extern void RGBInterpolate(RGBColor_t * startColor, RGBColor_t * endColor, float percent, RGBColor_t * outColor);
extern void HSVInterpolate(HSVColor_t * startColor, HSVColor_t * endColor, float percent, HSVColor_t * outColor);

#endif
