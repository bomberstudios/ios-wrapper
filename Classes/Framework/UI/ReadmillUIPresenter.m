/*
 Copyright (c) 2011 Readmill LTD
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "ReadmillUIPresenter.h"
#import <QuartzCore/QuartzCore.h>

@interface ReadmillUIPresenter ()

//@property (nonatomic, readwrite, retain) UIViewController *contentViewController;

@end

@implementation ReadmillUIPresenter

-(id)initWithContentViewController:(UIViewController *)aContentViewController {
    if ((self = [super init])) {
        [self setContentViewController:aContentViewController];
    }
    return self;
}

-(void)dealloc {
    [spinner release];
    spinner = nil;
    
    [backgroundView release];
    backgroundView = nil;
    
    [contentContainerView removeObserver:self forKeyPath:@"frame"];
    [contentContainerView release];
    contentContainerView = nil;

    [self setView:nil];
    [self setContentViewController:nil];
    [super dealloc];
}

@synthesize contentViewController;

-(void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

-(void)dismissModalViewControllerAnimated:(BOOL)animated {
    [self dismissPresenterAnimated:animated];
}

#pragma mark -

#define kAnimationDuration 0.2
#define kBackgroundOpacity 0.3 

-(void)presentInViewController:(UIViewController *)theParentViewController animated:(BOOL)animated {
    if (![UIView areAnimationsEnabled]) {
        return;
    }
    [self retain];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contentViewControllerShouldBeDismissed:)
                                                 name:ReadmillUIPresenterShouldDismissViewNotification
                                               object:[self contentViewController]];
    
    UIView *parentView = [theParentViewController view];
    
    [[self view] setFrame:[parentView bounds]];
    [parentView addSubview:[self view]];
    
    [self viewDidAppear:animated];
    
    if (animated) {
        // Set up animation!
        [UIView beginAnimations:ReadmillUIPresenterDidAnimateIn context:nil];
        [UIView setAnimationDuration:kAnimationDuration];
        //[UIView setAnimationBeginsFromCurrentState:YES];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(animation:finished:context:)];
    }
    
    [[self view] setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:kBackgroundOpacity]];
    
    [contentContainerView setCenter:[[self view] center]];
    
    if (animated) {
        // Commit animation
        [UIView commitAnimations];
        //[UIView setAnimationsEnabled:NO];
    }
    DismissingView *dismiss = [[DismissingView alloc] initWithFrame:[[UIScreen mainScreen] bounds]
                                                           selector:@selector(dismissView:) 
                                                             target:self];
    [dismiss addToView:self.view];
    [dismiss release]; 
}
- (void)dismissView:(UIView *)dismissView {
    [[NSNotificationCenter defaultCenter] postNotificationName:ReadmillUIPresenterShouldDismissViewNotification object:[self contentViewController]];
}
- (void)contentViewControllerShouldBeDismissed:(NSNotification *)aNotification {
    [self dismissPresenterAnimated:YES];
}

- (void)dismissPresenterAnimated:(BOOL)animated {

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:ReadmillUIPresenterShouldDismissViewNotification
                                                  object:[self contentViewController]];
    
    if (animated) {
        
        [UIView beginAnimations:ReadmillUIPresenterDidAnimateOut context:nil];
        [UIView setAnimationDuration:kAnimationDuration];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
        //[UIView setAnimationBeginsFromCurrentState:YES];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(animation:finished:context:)];
        
        [[self view] setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.0]];
        
        [contentContainerView setCenter:CGPointMake(CGRectGetMidX([[self view] bounds]),
                                                    CGRectGetMaxY([[self view] bounds]) + (CGRectGetHeight([contentContainerView frame]) / 2))];
        
        [UIView commitAnimations];
        //[UIView setAnimationsEnabled:NO];

        
    } else {
        [[self view] removeFromSuperview];
        [self release];
    }
}

-(void)animation:(NSString*)animationID finished:(BOOL)didFinish context:(void *)context {
    //[UIView setAnimationsEnabled:YES];
    if ([animationID isEqualToString:ReadmillUIPresenterDidAnimateOut]) {
        [[self view] removeFromSuperview];
        [self release];
    }
    else if ([animationID isEqualToString:ReadmillUIPresenterDidAnimateIn]) {
        //[spinner setCenter:CGPointMake(CGRectGetMidX([contentContainerView frame]), CGRectGetMidY([contentContainerView frame]))];
        [spinner startAnimating];  
    }

}


#pragma mark - View lifecycle

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"frame"]) {
        [[contentContainerView layer] setShadowPath:[UIBezierPath bezierPathWithRect:contentContainerView.bounds].CGPath];  
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


// Implement loadView to create a view hierarchy programmatically, without using a nib.
-(void)loadView {

    backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 0.0, 0.0)];
    [backgroundView setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.0]];
    [backgroundView setOpaque:YES];
    [backgroundView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    
    [self setView:backgroundView];

    contentContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 600, 400)];
    [contentContainerView setBackgroundColor:[UIColor whiteColor]];
    [[contentContainerView layer] setShadowPath:[UIBezierPath bezierPathWithRect:contentContainerView.bounds].CGPath];
    [[contentContainerView layer] setShadowColor:[[UIColor blackColor] CGColor]];
    [[contentContainerView layer] setShadowRadius:8.0];
    [[contentContainerView layer] setShadowOpacity:0.5];
    [[contentContainerView layer] setShadowOffset:CGSizeMake(0.0, 5.0)];
    [contentContainerView setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin];
    
    [contentContainerView addObserver:self forKeyPath:@"frame" options:0 context:nil];
    
    spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [spinner setCenter:[contentContainerView center]];
    [contentContainerView addSubview:spinner];
    
    [backgroundView addSubview:contentContainerView];

    


    //[self setView:contentContainerView];
}
- (void)displayContentViewController {
    if ([self contentViewController] != nil) {
        [contentContainerView setFrame:[[[self contentViewController] view] bounds]];
        [contentContainerView setCenter:[[self view] center]];
        [contentContainerView addSubview:[[self contentViewController] view]];
    }
}
- (void)setAndDisplayContentViewController:(UIViewController *)aContentViewController {
    [self setContentViewController:aContentViewController];
    [spinner stopAnimating];
    [self displayContentViewController];
}

-(void)viewDidAppear:(BOOL)animated {

    [self displayContentViewController];
            
    [contentContainerView setCenter:CGPointMake(CGRectGetMidX([[self view] bounds]),
                                                CGRectGetMaxY([[self view] bounds]) + (CGRectGetHeight([contentContainerView frame]) / 2))];
}

-(void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    [spinner release];
    spinner = nil;
    
    [backgroundView release];
    backgroundView = nil;
    
    [contentContainerView removeObserver:self forKeyPath:@"frame"];
    [contentContainerView release];
    contentContainerView = nil;
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
	return YES;
}

@end