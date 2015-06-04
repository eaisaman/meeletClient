//
//  QRCodeViewController.m
//  MeeletClient
//
//  Created by jill on 15/5/27.
//
//

#import "QRCodeViewController.h"
#import "QRCodeOutlineBox.h"

@interface QRCodeViewController ()

@end

@implementation QRCodeViewController {
    ZBarReaderView* readerView;
    QRCodeOutlineBox *boundingBox;
    UIView *laserView;
}

@synthesize resultBlock;

-(CGRect)getScanCrop:(CGRect)rect readerViewBounds:(CGRect)readerViewBounds
{
    CGFloat x,y,width,height;
    
    x = rect.origin.x / readerViewBounds.size.width;
    y = rect.origin.y / readerViewBounds.size.height;
    width = rect.size.width / readerViewBounds.size.width;
    height = rect.size.height / readerViewBounds.size.height;
    
    return CGRectMake(x, y, width, height);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    readerView = [ZBarReaderView new];
    readerView.readerDelegate = self;
    readerView.allowsPinchZoom = NO;
    readerView.frame = self.view.bounds;
    
    [readerView.scanner setSymbology:ZBAR_QRCODE config:ZBAR_CFG_ENABLE to:1];
    
    CGRect scanMaskRect = CGRectMake(self.view.bounds.size.width / 2 - 175, self.view.bounds.size.height / 2 - 175, 350, 350);
    readerView.scanCrop = [self getScanCrop:scanMaskRect readerViewBounds:readerView.bounds];
    
    [self.view addSubview:readerView];
    
    boundingBox = [[QRCodeOutlineBox alloc] initWithFrame:scanMaskRect];
    boundingBox.alpha = 0.0;
    [self.view insertSubview:boundingBox aboveSubview:readerView];

    boundingBox.corners = @[[NSValue valueWithCGPoint:CGPointMake(0, 0)], [NSValue valueWithCGPoint:CGPointMake(0, boundingBox.bounds.size.height)], [NSValue valueWithCGPoint:CGPointMake(boundingBox.bounds.size.width, boundingBox.bounds.size.height)], [NSValue valueWithCGPoint:CGPointMake(boundingBox.bounds.size.width, 0)]];
    
    laserView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, boundingBox.frame.size.width, 2)];
    laserView.backgroundColor = [UIColor colorWithRed:46.0/255.0 green:204.0/255.0 blue:113.0/255.0 alpha:1];
    laserView.layer.shadowColor = [UIColor redColor].CGColor;
    laserView.layer.shadowOffset = CGSizeMake(0.5, 0.5);
    laserView.layer.shadowOpacity = 0.6;
    laserView.layer.shadowRadius = 1.5;
    
    [boundingBox addSubview:laserView];
    
    // Add the line
    [UIView animateWithDuration:0.2 animations:^{
        boundingBox.alpha = 1.0;
    }];
    
    [UIView animateWithDuration:4.0 delay:0.0 options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut animations:^{
        laserView.frame = CGRectMake(0, boundingBox.frame.size.height, boundingBox.frame.size.width, 2);
    } completion:nil];

    [readerView willRotateToInterfaceOrientation: self.interfaceOrientation
                                        duration: 0];
    [readerView performSelector: @selector(start)
                     withObject: nil
                     afterDelay: .001];
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark ZBarReaderViewDelegate implementation
#pragma GCC diagnostic ignored "-Wshadow-ivar"
-(void) readerView:(ZBarReaderView *)readerView didReadSymbols:(ZBarSymbolSet *)symbols fromImage:(UIImage *)image
{
    NSString* projectId = nil;
    
    for (ZBarSymbol *symbol in symbols) {
        ALog(@"%@", symbol.data);
        projectId = symbol.data;
        break;
    }
    
    if (projectId && self.resultBlock) {
        self.resultBlock(projectId);
    }
    
    [readerView stop];
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void) readerView:(ZBarReaderView *)readerView didStopWithError:(NSError *)error
{
    [readerView stop];
    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
