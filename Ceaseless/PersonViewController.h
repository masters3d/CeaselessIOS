//
//  PersonViewController.h
//  Ceaseless
//
//  Created by Christopher Lim on 3/6/15.
//  Copyright (c) 2015 Christopher Lim. All rights reserved.
//

#import "DataViewController.h"
#import "PersonView.h"

@interface PersonViewController : DataViewController
    @property (strong, nonatomic) IBOutlet PersonView *personView;
@end