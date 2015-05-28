//
//  QRCodeViewController.h
//  MeeletClient
//
//  Created by jill on 15/5/27.
//
//

#import <UIKit/UIKit.h>
#import <Pods/ZBarSDK/ZBarSDK.h>

typedef void (^ScanQRCodeResultBlock)(NSString* resultCode);

@interface QRCodeViewController : UIViewController<ZBarReaderViewDelegate>

@property(nonatomic, copy) ScanQRCodeResultBlock resultBlock;

@end
