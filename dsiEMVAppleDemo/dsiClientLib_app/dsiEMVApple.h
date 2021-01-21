#import <Foundation/Foundation.h>

@protocol dsiEMVAppleDelegate < NSObject >
@optional
    - ( void ) connectionResponse : ( NSString* ) response;     // Called from EstablishBluetoothConnection.
    - ( void ) displayMessage : ( NSString* ) message;          // Called when a message is generated from Datacap library calls.
    - ( void ) transactionResponse : ( NSString* ) response;    // Called from ProcessTransaction or GetDevicesInfo.
@end

@interface dsiEMVApple : NSObject
    - ( NSString* ) ProcessTransaction : ( NSString* ) nsRequest;
    - ( NSString* ) GetDevicesInfo;
    - ( void ) CancelTransaction;
    - ( void ) Disconnect;
    - ( NSString* ) EstablishBluetoothConnection :  ( NSString* ) nsBluetoothDeviceName;
    - ( bool ) IsBluetoothConnected;

    @property( nullable, nonatomic, weak ) id < dsiEMVAppleDelegate > delegate;
@end
