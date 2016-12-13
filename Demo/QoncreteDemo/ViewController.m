//
//  ViewController.m
//  QoncreteDemo
//
//  Created by luo on 2016/12/12.
//  Copyright © 2016年 Qoncrete. All rights reserved.
//

#import "ViewController.h"
#import "Qoncrete.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    Qoncrete *client = [Qoncrete sharedSingleton];
    client.sourceID = @"SOURCE_ID";
    client.apiToken = @"API_TOKEN";
    client.errorLogger = ^(NSDictionary *err){
        NSLog(@"err: %@",err);
    };
    [client endConfig];
    
    [client send:@{ @"user": @"toto", @"action": @"purchase", @"price": @99.99 }];

}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
