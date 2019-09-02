//
//  DisplayImageController.m
//  BlurShaderDemo
//
//  Created by GevinChen on 2019/7/14.
//  Copyright © 2019 GevinChen. All rights reserved.
//

#import "DisplayImageController.h"

@interface DisplayImageController ()
{
    UIImage *_image;
}

@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation DisplayImageController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)setImage:(UIImage*) image {
    _image = image;
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
