//
//  ViewController.m
//  OpenGLES01-环境搭建
//
//  Created by qinmin on 2017/2/9.
//  Copyright © 2017年 qinmin. All rights reserved.
//

#import "ViewController.h"
#import "OpenGLESView.h"
#import "DisplayImageController.h"

@interface ViewController ()
{
    OpenGLESView *glView;
}
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if(!glView) {
        [self.view layoutIfNeeded];
        glView = [[OpenGLESView alloc] initWithFrame:self.containerView.bounds];
        [self.containerView addSubview:glView];
        glView.frame = (CGRect){ 0,0,glView.bounds.size};
    }
}


- (IBAction)buttonClicked:(id)sender 
{
    
    UIImage *image = [glView readPixel];
    self.imageView.image = image;
    
//    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
//    DisplayImageController *vc = [sb instantiateViewControllerWithIdentifier:@"DisplayImageController"];
//    [vc setImage:image];
//    [self presentViewController:vc animated:YES completion:nil];
}

@end
