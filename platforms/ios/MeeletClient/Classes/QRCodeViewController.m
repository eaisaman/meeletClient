//
//  QRCodeViewController.m
//  MeeletClient
//
//  Created by jill on 15/5/27.
//
//

#import "QRCodeViewController.h"

@interface QRCodeViewController ()

@end

@implementation QRCodeViewController {
    ZBarReaderView* readerView;
}

@synthesize resultBlock;

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [readerView start];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    readerView = [ZBarReaderView new];
    readerView.readerDelegate = self;
    readerView.allowsPinchZoom = NO;
    [readerView.scanner setSymbology:ZBAR_QRCODE config:ZBAR_CFG_ENABLE to:1];

    [self.view addSubview:readerView];
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
        DLog(@"%@", symbol.data);
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
