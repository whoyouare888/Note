//
//  ViewController.m
//  ATDecode
//
//  Created by zhw on 2019/8/23.
//  Copyright © 2019 zhw. All rights reserved.
//

#import "ViewController.h"
#import "AACPlayer.h"

@interface ViewController ()

@end

@implementation ViewController
{
    AACPlayer *_player;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _player = [[AACPlayer alloc] init];
    [_player play];
}


@end
