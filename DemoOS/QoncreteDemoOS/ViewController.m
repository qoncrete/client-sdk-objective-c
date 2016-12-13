//
//  ViewController.m
//  QoncreteDemoOS
//
//  Created by luo on 2016/12/12.
//  Copyright © 2016年 Qoncrete. All rights reserved.
//

#import "ViewController.h"
#import "Qoncrete.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    Qoncrete *client = [Qoncrete sharedSingleton];
    client.sourceID = @"SOURCE_ID";
    client.apiToken = @"API_TOKEN";
    client.errorLogger = ^(NSDictionary *err){
        NSLog(@"err: %@",err);
    };
    [client endConfig];
    
    [client send:@{ @"user": @"toto", @"action": @"purchase", @"price": @99.99 }];

}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
