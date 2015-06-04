//
//  QRCodeOutlineBox.m
//  MeeletClient
//
//  Created by jill on 15/5/27.
//
//

#import "QRCodeOutlineBox.h"

@interface QRCodeOutlineBox ()
@property (nonatomic, strong) CAShapeLayer *outline;
@end

@implementation QRCodeOutlineBox

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        _outline = [CAShapeLayer new];
        _outline.strokeColor = [[UIColor colorWithRed:46.0/255.0 green:204.0/255.0 blue:113.0/255.0 alpha:.8] CGColor];
        _outline.lineWidth = 2.5;
        _outline.fillColor = [[UIColor clearColor] CGColor];
        [self.layer addSublayer:_outline];
    }
    return self;
}

- (void)setCorners:(NSArray *)corners {
    if (corners != _corners) {
        _corners = corners;
        _outline.path = [[self createOutlineFromCorners:corners] CGPath];
    }
}

- (UIBezierPath *)createOutlineFromCorners:(NSArray *)points {
    // Create a new bezier path
    UIBezierPath *path = [UIBezierPath new];
    
    // AVFoundation provides points in an array, ordered counterclockwise
    [path moveToPoint:[[points firstObject] CGPointValue]];
    
    // Draw lines around the corners
    for (NSUInteger i = 1; i < [points count]; i++) {
        [path addLineToPoint:[points[i] CGPointValue]];
    }
    
    // Close up the line to the first corner - complete the path
    [path addLineToPoint:[[points firstObject] CGPointValue]];
    
    return path;
}

@end
