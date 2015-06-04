//
//  ProjectViewController.m
//  MeeletClient
//
//  Created by jill on 15/6/3.
//
//

#import "ProjectViewController.h"

@interface ProjectViewController () {
    UIPinchGestureRecognizer *pinchGestureRecognizer;
}

- (void)closeProject:(UIGestureRecognizer *)sender;

@end

@implementation ProjectViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(closeProject:)];
    [pinchGestureRecognizer setDelegate:self];

    [self.view addGestureRecognizer:pinchGestureRecognizer];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)closeProject:(UIGestureRecognizer *)sender
{
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
