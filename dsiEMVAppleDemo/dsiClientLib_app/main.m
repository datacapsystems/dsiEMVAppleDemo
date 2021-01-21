//
//  main.m
//  dsiClientLib_app
//
//  Created by datacap on 11/12/20.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#include <sys/select.h>

int main( int argc, char* argv[ ] )
{
    NSString* appDelegateClassName;
        
    @autoreleasepool
    {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass( [ AppDelegate class ] );
    }
    
    return UIApplicationMain( argc, argv, nil, appDelegateClassName );
}
