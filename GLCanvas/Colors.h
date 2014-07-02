//
//  Colors.h
//  GLGraph
//
//  Created by Zaheer Naby on 8/30/13.
//  Copyright (c) 2013 Zaheer Naby. All rights reserved.
//

#ifndef GLGraph_Colors_h
#define GLGraph_Colors_h

typedef struct {
    float R;
    float G;
    float B;
    float A;
} RGBColor_t;

typedef struct {
    float H;
    float S;
    float V;
    float A;
} HSVColor_t;


extern RGBColor_t red;
extern RGBColor_t blue;
extern RGBColor_t green;
extern RGBColor_t yellow;
extern RGBColor_t white;
extern RGBColor_t black;


#endif
