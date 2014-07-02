//
//  ColorConvert.c
//  GLGraph
//
//  Created by Zaheer Naby on 8/22/13.
//  Copyright (c) 2013 Zaheer Naby. All rights reserved.
//

#include <stdio.h>
#include <math.h>
#include "ColorConvert.h"

#define MIN3(x,y,z)  ((y) <= (z) ? ((x) <= (y) ? (x) : (y)) : ((x) <= (z) ? (x) : (z)))
#define MAX3(x,y,z)  ((y) >= (z) ? ((x) >= (y) ? (x) : (y)) : ((x) >= (z) ? (x) : (z)))

/**
 *
 *
 */
void RGB2HSV(RGBColor_t * rgbColor, HSVColor_t * hsvColor)
{
    float r = rgbColor->R / 255.0f;
    float g = rgbColor->G / 255.0f;
    float b = rgbColor->B / 255.0f;
    
    float minValue = MIN3(r, g, b);
    float maxValue = MAX3(r, g, b);
    float deltaValue = maxValue - minValue;
    
    hsvColor->V = maxValue;
    
    if(deltaValue == 0) {
        hsvColor->H = 0;
        hsvColor->S = 0;
    }
    else {
        
        hsvColor->S = deltaValue / maxValue;
        
        float del_R = (((maxValue - r) / 6.0f) + (deltaValue / 2.0f)) / deltaValue;
        float del_G = (((maxValue - g) / 6.0f) + (deltaValue / 2.0f)) / deltaValue;
        float del_B = (((maxValue - b) / 6.0f) + (deltaValue / 2.0f)) / deltaValue;
        
        if (r == maxValue)
        {
            hsvColor->H = del_B - del_G;
        }
        else if (g == maxValue)
        {
            hsvColor->H= (1.0f / 3.0f) + del_R - del_B;
        }
        else if (b == maxValue)
        {
            hsvColor->H = (2.0f / 3.0f) + del_G - del_R;
        }
        
        if (hsvColor->H < 0) {
            hsvColor->H += 1;
        }
        
        if (hsvColor->H > 1) {
            hsvColor->H -= 1;
        }
    }
    
    hsvColor->H *= 360.0f;
    hsvColor->S *= 100.0f;
    hsvColor->V *= 100.0f;
}

/**
 *
 *
 */
void HSV2RGB(HSVColor_t * hsvColor, RGBColor_t * rgbColor)
{
    float h  =  hsvColor->H / 360.0f;
    float s  =  hsvColor->S / 100.0f;
    float v  =  hsvColor->V / 100.0f;
    
    if(s == 0) {
        rgbColor->R =  v *  255;
        rgbColor->G =  v * 255;
        rgbColor->B =  v * 255;
    }
    else {
        
        float vH = h * 6;
		int vI = floor(vH);
		float v1 = v * (1 - s);
		float v2 = v * (1 - s * (vH - vI));
		float v3 = v * (1 - s * (1 - (vH - vI)));
        
        float vR, vG, vB;
        
        switch (vI) {
            case 0:
                vR = v;
                vG = v3;
                vB = v1;
                break;
            case 1:
                vR = v2;
                vG = v;
                vB = v1;
                break;
            case 2:
                vR = v1;
                vG = v;
                vB = v3;
                break;
            case 3:
                vR = v1;
                vG = v2;
                vB = v;
                break;
            case 4:
                vR = v3;
                vG = v1;
                vB = v;
                break;
            default:
                vR = v;
                vG = v1;
                vB = v2;
                break;
        }
        
        rgbColor->R = vR * 255;
        rgbColor->G = vG * 255;
        rgbColor->B = vB * 255;
    }
}


void RGBInterpolate(RGBColor_t * start, RGBColor_t * end, float percent, RGBColor_t * out)
{
    out->R = (1-percent)*start->R + percent*end->R;
    out->G = (1-percent)*start->G+ percent*end->G;
    out->B = (1-percent)*start->B + percent*end->B;
    out->A = (1-percent)*start->A + percent*end->A;

}

void HSVInterpolate(HSVColor_t * start, HSVColor_t * end, float percent, HSVColor_t * out)
{
    //Perform interpolation on S & V components.
    out->S = (1-percent)*start->S + percent*end->S;
    out->V = (1-percent)*start->V + percent*end->V;
    out->A = (1-percent)*start->A + percent*end->A;
    
    
    float distanceCW = 0;
    float distanceCCW = 0;
    
    if(start->H <= end->H) {
     
        distanceCW =   end->H - start->H;
        distanceCCW =  (360 + start->H) - end->H;
        
        //out->H =  (1-percent)*start->H + percent*end->H;
        
        if(distanceCW < distanceCCW) {
            out->H = start->H + distanceCW*percent;
            
            if(out->H > 360)
                out->H -= 360;
        }
        else {
            out->H = start->H - distanceCCW*percent;
            if(out->H < 0)
                out->H += 360;
        }
        
        
    }
    else
    {
        // ClockWise
        distanceCW =  (360 + end->H) - start->H;
        distanceCCW = start->H - end->H;
        
        //out->H =  start->H + distanceCW*percent;

        if(distanceCW < distanceCCW) {
            out->H =  start->H + distanceCW*percent;
        }
        else {
            out->H =  start->H - distanceCCW*percent;
        }
    }
    
    
}
