//
//  DSIEMVApple.h
//
//  Created by datacap on 11/10/20.
//

#import <Foundation/Foundation.h>

//! Project version number for DSIEMVApple.
FOUNDATION_EXPORT double DSIEMVAppleVersionNumber;

//! Project version string for DSIClientLib_dynamic.
FOUNDATION_EXPORT const unsigned char DSIEMVAppleVersionString[];

@protocol dsiEMVAppleDelegate < NSObject >
@optional
    - ( void ) connectionResponse : ( NSString* ) response;     // Called from EstablishBluetoothConnection.
    - ( void ) displayMessage : ( NSString* ) message;          // Called when a message is generated from Datacap library calls.
    - ( void ) transactionResponse : ( NSString* ) response;    // Called from ProcessTransaction or GetDevicesInfo.
@end

@interface dsiEMVApple : NSObject
    - ( NSString* ) ProcessTransaction : ( NSString* ) nsRequest;
    - ( NSString* ) GetDevicesInfo;
    - ( void ) CanceRequest;
    - ( void ) Disconnect;
    - ( NSString* ) EstablishBluetoothConnection : ( NSString* ) nsBluetoothDeviceName;
    - ( bool ) IsBluetoothConnected;

    @property( nullable, nonatomic, weak ) id < dsiEMVAppleDelegate > delegate;
@end

