//
//  QRCodeOutlineBox.h
//  MeeletClient
//
//  Created by jill on 15/5/27.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/// Draws the outline of the scanned barcode
@interface QRCodeOutlineBox : UIView

/// The corners of the scanned barcode
@property (nonatomic, strong) NSArray *corners;

@end
