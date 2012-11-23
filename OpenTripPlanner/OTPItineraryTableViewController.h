//
//  OTPItineraryTableViewController.h
//  OpenTripPlanner
//
//  Created by asutula on 10/1/12.
//  Copyright (c) 2012 OpenPlans. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MFMailComposeViewController.h>

#import "Itinerary.h"
#import "OTPItineraryMapViewController.h"
#import "RouteMe.h"
#import "PPRevealSideViewController.h"
#import "OTPGeocodedTextField.h"

@interface OTPItineraryTableViewController : UITableViewController <RMMapViewDelegate, PPRevealSideViewControllerDelegate, MFMailComposeViewControllerDelegate>

@property(strong, nonatomic) UIViewController *itineraryViewController;
@property(strong, nonatomic) Itinerary *itinerary;
@property(nonatomic, strong) OTPItineraryMapViewController *itineraryMapViewController;
@property(strong, nonatomic) OTPGeocodedTextField *fromTextField;
@property(strong, nonatomic) OTPGeocodedTextField *toTextField;
@property(strong, nonatomic) UINavigationBar *navBar;
@property(strong, nonatomic) NSMutableArray *cellHeights;
@property(nonatomic) BOOL mapShowedUserLocation;

- (void)displayItinerary;
- (void)displayItineraryOverview;
- (void)displayLeg:(Leg*)leg;
- (IBAction)displayFeedback:(id)sender;

@end
