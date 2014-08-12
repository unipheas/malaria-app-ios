//
//  TRYAnalyticsScreenIIViewController.m
//  LoginTabbedApp
//
//  Created by shruti gupta on 18/07/14.
//  Copyright (c) 2014 Shruti Gupta. All rights reserved.
//

#import "TRYAnalyticsScreenIIViewController.h"

@interface TRYAnalyticsScreenIIViewController ()
@property (strong, nonatomic) IBOutlet UIImageView *background;

@end

@implementation TRYAnalyticsScreenIIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"background1.png"]]; 
}


@end
