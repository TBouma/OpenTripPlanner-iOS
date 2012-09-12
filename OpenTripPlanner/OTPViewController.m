//
//  OTPViewController.m
//  OpenTripPlanner
//
//  Created by asutula on 8/30/12.
//  Copyright (c) 2012 OpenPlans. All rights reserved.
//

#import "OTPViewController.h"
#import "OTPTransitTimesViewController.h"
#import "Plan.h"
#import "SMCalloutView.h"

@interface OTPViewController ()

- (void)displayItinerary:(Itinerary*)itinerary;
- (void)showUserLocation;
- (NSMutableArray *)decodePolyLine:(NSString *)encodedStr;
- (void)hideSearchBar;
- (IBAction)showDirectionsInput:(id)sender;

@end

@implementation OTPViewController

@synthesize mapView = _mapView;
@synthesize searchBar = _searchBar;
@synthesize toolbar;
@synthesize infoView;
@synthesize infoLabel;
@synthesize currentItinerary = _currentItinerary;
@synthesize currentLeg = _currentLeg;
@synthesize userLocation = _userLocation;

OTPDirectionsInputViewController *directionsInputViewController;
Plan *currentPlan;
CLLocationCoordinate2D currentLocationToOrFromPoint;
SEL currentLocationRoutingSelector;
BOOL needsRouting = NO;

#pragma mark OTP methods

- (void)planTripFrom:(CLLocationCoordinate2D)startPoint to:(CLLocationCoordinate2D)endPoint
{
    // TODO: Look at how time zone plays into all this.
    NSDate *now = [[NSDate alloc] init];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    NSString *dateString = [dateFormatter stringFromDate:now];
    [dateFormatter setDateFormat:@"HH:mm"];
    NSString *timeString = [dateFormatter stringFromDate:now];
    
    NSString *fromString = [NSString stringWithFormat:@"%f,%f", startPoint.latitude, startPoint.longitude];
    NSString *toString = [NSString stringWithFormat:@"%f,%f", endPoint.latitude, endPoint.longitude];
    
    
    NSDictionary* params = [NSDictionary dictionaryWithKeysAndObjects:
                            @"optimize", @"QUICK",
                            @"time", timeString,
                            @"arriveBy", @"false",
                            @"routerId", @"req-241",
                            @"maxWalkDistance", @"840",
                            @"fromPlace", fromString,
                            @"toPlace", toString,
                            @"date", dateString,
                            @"mode", @"TRANSIT,WALK",
                            nil];
    
    NSString* resourcePath = [@"/plan" stringByAppendingQueryParameters: params];
    
    RKObjectManager* objectManager = [RKObjectManager sharedManager];
    [objectManager loadObjectsAtResourcePath:resourcePath delegate:self];
}

- (void)planTripFromCurrentLocationTo:(CLLocationCoordinate2D)endPoint
{
    if (self.userLocation == nil) {
        needsRouting = YES;
        currentLocationRoutingSelector = @selector(planTripFromCurrentLocationTo:);
        currentLocationToOrFromPoint = endPoint;
        [self showUserLocation];
    } else {
        [self planTripFrom:self.userLocation.coordinate to:endPoint];
    }
}

- (void)planTripToCurrentLocationFrom:(CLLocationCoordinate2D)startPoint
{
    if (self.userLocation == nil) {
        needsRouting = YES;
        currentLocationRoutingSelector = @selector(planTripToCurrentLocationFrom:);
        currentLocationToOrFromPoint = startPoint;
        [self showUserLocation];
    } else {
        [self planTripFrom:startPoint to:self.userLocation.coordinate];
    }
}

- (void)showUserLocation
{
    self.mapView.userTrackingMode = RMUserTrackingModeNone;
    self.mapView.showsUserLocation = YES;
}

- (void) displayItinerary: (Itinerary*)itinerary
{
    [self.mapView removeAllAnnotations];
    
    CLLocationCoordinate2D northEastPoint;
    CLLocationCoordinate2D southWestPoint;
    
    int legCounter = 0;
    for (Leg* leg in itinerary.legs) {
        if (legCounter == 0) {
            RMAnnotation* startAnnotation = [RMAnnotation
                                             annotationWithMapView:self.mapView
                                             coordinate:CLLocationCoordinate2DMake(leg.from.lat.floatValue, leg.from.lon.floatValue)
                                             andTitle:leg.from.name];
            RMMarker *marker = [[RMMarker alloc] initWithMapBoxMarkerImage:nil tintColor:[UIColor greenColor]];
            marker.zPosition = 10;
            startAnnotation.userInfo = [[NSMutableDictionary alloc] init];
            [startAnnotation.userInfo setObject:marker forKey:@"layer"];
            [self.mapView addAnnotation:startAnnotation];
        } else if (legCounter == itinerary.legs.count - 1) {
            RMAnnotation* endAnnotation = [RMAnnotation
                                             annotationWithMapView:self.mapView
                                             coordinate:CLLocationCoordinate2DMake(leg.to.lat.floatValue, leg.to.lon.floatValue)
                                             andTitle:leg.from.name];
            RMMarker *marker = [[RMMarker alloc] initWithMapBoxMarkerImage:nil tintColor:[UIColor redColor]];
            marker.zPosition = 10;
            endAnnotation.userInfo = [[NSMutableDictionary alloc] init];
            [endAnnotation.userInfo setObject:marker forKey:@"layer"];
            [self.mapView addAnnotation:endAnnotation];
        }
        
        NSMutableArray* decodedPoints = [self decodePolyLine:leg.legGeometry.points];
        
        RMShape *polyline = [[RMShape alloc] initWithView:self.mapView];
        polyline.lineColor = [UIColor colorWithRed:0 green:0 blue:1 alpha:0.5];
        polyline.lineWidth = 6;
        polyline.lineCap = kCALineCapRound;
        polyline.lineJoin = kCALineJoinRound;
        polyline.zPosition = 0;
        
        int counter = 0;
        
        for (CLLocation *loc in decodedPoints) {
            if (counter == 0) {
                [polyline moveToCoordinate:loc.coordinate];
            } else {
                [polyline addLineToCoordinate:loc.coordinate];
            }
            
            CLLocationCoordinate2D point = loc.coordinate;
            
            if (legCounter == 0) {
                northEastPoint = point;
                southWestPoint = point;
            } else {
                if (point.longitude > northEastPoint.longitude)
                    northEastPoint.longitude = point.longitude;
                if(point.latitude > northEastPoint.latitude)
                    northEastPoint.latitude = point.latitude;
                if (point.longitude < southWestPoint.longitude)
                    southWestPoint.longitude = point.longitude;
                if (point.latitude < southWestPoint.latitude)
                    southWestPoint.latitude = point.latitude;
            }
            counter++;
        }
        
        RMAnnotation *polylineAnnotation = [[RMAnnotation alloc] init];
        [polylineAnnotation setMapView:self.mapView];
        polylineAnnotation.coordinate = ((CLLocation*)[decodedPoints objectAtIndex:0]).coordinate;
        [polylineAnnotation setBoundingBoxFromLocations:decodedPoints];
        polylineAnnotation.userInfo = [[NSMutableDictionary alloc] init];
        [polylineAnnotation.userInfo setObject:polyline forKey:@"layer"];
        [self.mapView addAnnotation:polylineAnnotation];
        
        legCounter++;
    }
    //self.toolbar.hidden = NO;
    //self.infoView.hidden = NO;
    [self.mapView zoomWithLatitudeLongitudeBoundsSouthWest:southWestPoint northEast:northEastPoint animated:YES];
}

// http://code.google.com/apis/maps/documentation/utilities/polylinealgorithm.html
-(NSMutableArray *)decodePolyLine:(NSString *)encodedStr
{
    NSMutableString *encoded = [[NSMutableString alloc] initWithCapacity:[encodedStr length]];
    [encoded appendString:encodedStr];
    [encoded replaceOccurrencesOfString:@"\\\\" withString:@"\\"
                                options:NSLiteralSearch
                                  range:NSMakeRange(0, [encoded length])];
    NSInteger len = [encoded length];
    NSInteger index = 0;
    NSMutableArray *array = [[NSMutableArray alloc] init];
    NSInteger lat=0;
    NSInteger lng=0;
    while (index < len) {
        NSInteger b;
        NSInteger shift = 0;
        NSInteger result = 0;
        do {
            b = [encoded characterAtIndex:index++] - 63;
            result |= (b & 0x1f) << shift;
            shift += 5;
        } while (b >= 0x20);
        NSInteger dlat = ((result & 1) ? ~(result >> 1) : (result >> 1));
        lat += dlat;
        shift = 0;
        result = 0;
        do {
            b = [encoded characterAtIndex:index++] - 63;
            result |= (b & 0x1f) << shift;
            shift += 5;
        } while (b >= 0x20);
        NSInteger dlng = ((result & 1) ? ~(result >> 1) : (result >> 1));
        lng += dlng;
        NSNumber *latitude = [[NSNumber alloc] initWithFloat:lat * 1e-5];
        NSNumber *longitude = [[NSNumber alloc] initWithFloat:lng * 1e-5];
        //          printf("[%f,", [latitude doubleValue]);
        //          printf("%f]", [longitude doubleValue]);
        CLLocation *loc = [[CLLocation alloc] initWithLatitude:[latitude floatValue] longitude:[longitude floatValue]];
        [array addObject:loc];
    }
    return array;
}

- (void)showSearchBar:(id)sender
{
    CATransition *animation = [CATransition animation];
    animation.duration = 0.2;
    [self.searchBar.layer addAnimation:animation forKey:nil];
    self.searchBar.hidden = NO;
    [self.searchBar becomeFirstResponder];
}

- (void)hideSearchBar
{
    CATransition *animation = [CATransition animation];
    animation.duration = 0.2;
    [self.searchBar.layer addAnimation:animation forKey:nil];
    self.searchBar.hidden = YES;
    [self.searchBar resignFirstResponder];
}

- (void)showDirectionsInput:(id)sender
{
    if (!directionsInputViewController) {
        directionsInputViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"DirectionsInputView"];
    }
    directionsInputViewController.delegate = self;
    [self.view addSubview:directionsInputViewController.view];
addSubview:directionsInputViewController.view.hidden = NO;
}

#pragma mark UISearchBarDelegate methods

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self.mapView removeAllAnnotations];
    
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    
    CLLocationCoordinate2D regionCoordinate;
    if (self.userLocation != nil) {
        regionCoordinate = self.userLocation.coordinate;
    } else {
        regionCoordinate = self.mapView.centerCoordinate;
    }
    
    CLRegion *region = [[CLRegion alloc] initCircularRegionWithCenter:regionCoordinate radius:2000 identifier:@"test"];
    
    [geocoder geocodeAddressString:searchBar.text inRegion:region completionHandler:^(NSArray* placemarks, NSError* error) {
        
        int counter = 0;
        CLLocationCoordinate2D northEastPoint;
        CLLocationCoordinate2D southWestPoint;
        
        for (CLPlacemark* aPlacemark in placemarks) {
            RMAnnotation* placeAnnotation = [RMAnnotation
                                             annotationWithMapView:self.mapView
                                             coordinate:aPlacemark.location.coordinate
                                             andTitle:aPlacemark.name];
            RMMarker *marker = [[RMMarker alloc] initWithMapBoxMarkerImage:nil tintColor:[UIColor blueColor]];
            marker.zPosition = 10;
            placeAnnotation.userInfo = [[NSMutableDictionary alloc] init];
            [placeAnnotation.userInfo setObject:marker forKey:@"layer"];
            [self.mapView addAnnotation:placeAnnotation];
            
            if (counter == 0) {
                northEastPoint = aPlacemark.location.coordinate;
                southWestPoint = aPlacemark.location.coordinate;
            } else {
                if (aPlacemark.location.coordinate.longitude > northEastPoint.longitude)
                    northEastPoint.longitude = aPlacemark.location.coordinate.longitude;
                if(aPlacemark.location.coordinate.latitude > northEastPoint.latitude)
                    northEastPoint.latitude = aPlacemark.location.coordinate.latitude;
                if (aPlacemark.location.coordinate.longitude < southWestPoint.longitude)
                    southWestPoint.longitude = aPlacemark.location.coordinate.longitude;
                if (aPlacemark.location.coordinate.latitude < southWestPoint.latitude)
                    southWestPoint.latitude = aPlacemark.location.coordinate.latitude;
            }
            counter++;
        }
        if (placemarks.count > 0) {
            [self.mapView zoomWithLatitudeLongitudeBoundsSouthWest:southWestPoint northEast:northEastPoint animated:YES];
            [self hideSearchBar];
        } else {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"No search results." message:@"Try providing a more specific query." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
            [alertView show];
        }
    }];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self hideSearchBar];
}

#pragma mark RMMapViewDelegate methods

- (void)mapView:(RMMapView *)mapView didUpdateUserLocation:(RMUserLocation *)userLocation
{
    self.userLocation = userLocation;
    
    if (needsRouting) {
        //[self performSelector:currentLocationRoutingSelector withObject:currentLocationToOrFromPoint];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[OTPViewController instanceMethodSignatureForSelector:currentLocationRoutingSelector]];
        [invocation setSelector:currentLocationRoutingSelector];
        [invocation setTarget:self];
        [invocation setArgument:&currentLocationToOrFromPoint atIndex:2];
        [invocation performSelector:@selector(invoke)];
        needsRouting = NO;
    }
}

- (void)mapView:(RMMapView *)mapView didFailToLocateUserWithError:(NSError *)error
{
    // Alert user that location couldn't be detirmined.
}

- (RMMapLayer *)mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation
{
    return [annotation.userInfo objectForKey:@"layer"];
}

- (void)longSingleTapOnMap:(RMMapView *)map at:(CGPoint)point
{
    NSLog(@"Long tap.");
    [self.mapView removeAllAnnotations];
    
    RMAnnotation* placeAnnotation = [RMAnnotation
                                     annotationWithMapView:self.mapView
                                     coordinate:[self.mapView pixelToCoordinate:point]
                                     andTitle:@"Dropped Pin"];
    
    RMMarker *marker = [[RMMarker alloc] initWithMapBoxMarkerImage:nil tintColor:[UIColor blueColor]];
    marker.zPosition = 10;
    
    SMCalloutView *callout = [[SMCalloutView alloc] init];
    callout.title = @"test";
    marker.label = callout;
    
    placeAnnotation.userInfo = [[NSMutableDictionary alloc] init];
    [placeAnnotation.userInfo setObject:marker forKey:@"layer"];
    [self.mapView addAnnotation:placeAnnotation];
}

- (void)tapOnAnnotation:(RMAnnotation *)annotation onMap:(RMMapView *)map
{
    NSLog(@"Tapped on annotation");
    //RMMarker* marker = [[annotation userInfo] objectForKey:@"layer"];
    //SMCalloutView *callout = [[SMCalloutView alloc] init];
    //callout.title = @"test";
    //[(SMCalloutView*)marker.label ];
}

#pragma mark OTPDirectionsInputViewDelegate methods

- (void)directionsInputViewCancelButtonClicked:(OTPDirectionsInputViewController *)directionsInputView
{
    directionsInputViewController.view.hidden = YES;
    [directionsInputViewController.view removeFromSuperview];
}

- (void)directionsInputViewRouteButtonClicked:(OTPDirectionsInputViewController *)directionsInputView
{
    
}

- (void)directionsInputView:(OTPDirectionsInputViewController *)directionsInputView geocodedPlacemark:(CLPlacemark *)placemark
{
    [self.mapView removeAllAnnotations];
    RMAnnotation* placeAnnotation = [RMAnnotation
                                     annotationWithMapView:self.mapView
                                     coordinate:placemark.location.coordinate
                                     andTitle:placemark.name];
    RMMarker *marker = [[RMMarker alloc] initWithMapBoxMarkerImage:nil tintColor:[UIColor blueColor]];
    marker.zPosition = 10;
    placeAnnotation.userInfo = [[NSMutableDictionary alloc] init];
    [placeAnnotation.userInfo setObject:marker forKey:@"layer"];
    [self.mapView addAnnotation:placeAnnotation];
    
    CLLocationCoordinate2D swCoordinate = CLLocationCoordinate2DMake(placemark.location.coordinate.latitude - 0.015, placemark.location.coordinate.longitude - 0.015);
    CLLocationCoordinate2D nwCoordinate = CLLocationCoordinate2DMake(placemark.location.coordinate.latitude + 0.015, placemark.location.coordinate.longitude + 0.015);
    
    [self.mapView zoomWithLatitudeLongitudeBoundsSouthWest:swCoordinate northEast:nwCoordinate animated:YES];
}

- (void)directionsInputView:(OTPDirectionsInputViewController *)directionsInputView choseRouteFrom:(CLPlacemark *)from to:(CLPlacemark *)to
{
    directionsInputViewController.view.hidden = YES;
    [directionsInputViewController.view removeFromSuperview];
    [self planTripFrom:from.location.coordinate to:to.location.coordinate];
}

#pragma mark RKObjectLoaderDelegate methods

- (void)request:(RKRequest*)request didLoadResponse:(RKResponse*)response
{
    NSLog(@"Loaded payload: %@", [response bodyAsString]);
}

- (void)objectLoader:(RKObjectLoader*)objectLoader didLoadObjects:(NSArray*)objects
{
    NSLog(@"Loaded plan: %@", objects);
    currentPlan = (Plan*)[objects objectAtIndex:0];
    [self displayItinerary:[currentPlan.itineraries objectAtIndex:0]];
}

- (void)objectLoader:(RKObjectLoader*)objectLoader didFailWithError:(NSError*)error
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    NSLog(@"Hit error: %@", error);
}

#pragma mark segue methods

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // pass itineraries to next view controller
    //((OTPTransitTimesViewController*)((UINavigationController*)segue.destinationViewController).topViewController).itineraries = currentPlan.itineraries;
}

#pragma mark UIViewController methods

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
    
	// Do any additional setup after loading the view.
    
    self.searchBar.hidden = YES;
    self.toolbar.hidden = YES;
    self.infoView.hidden = YES;
    
    CGFloat scale = [[UIScreen mainScreen] scale];
    NSString *mapUrl = nil;
    if (scale == 1) {
        mapUrl = @"http://a.tiles.mapbox.com/v3/openplans.map-ky03eiac.jsonp";
    } else {
        mapUrl = @"http://a.tiles.mapbox.com/v3/openplans.map-pq6tfzg7.jsonp";
    }
    RMMapBoxSource* source = [[RMMapBoxSource alloc] initWithReferenceURL:[NSURL URLWithString:mapUrl]];
    self.mapView.adjustTilesForRetinaDisplay = NO;
    self.mapView.tileSource = source;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end