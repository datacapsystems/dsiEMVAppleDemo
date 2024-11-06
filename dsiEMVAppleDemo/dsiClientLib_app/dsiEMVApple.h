#import <Foundation/Foundation.h>

// Controls the naming convention of the framework APIs (PascalCase vs. CamelCase or use both).
//
// This was needed for Swift as it doesn't allow PascalCase, only CamelCase.
// The __BRIDGING__ #define exists to remove the PascalCase for the framework APIs otherwise an "ambiguous use" will occur.
// When using the framework from an Objective-C project, comment out the following #define.
// #define __BRIDGING__

@protocol dsiEMVAppleDelegate < NSObject >
@optional
    - ( void ) connectionResponse : ( NSString* ) response;     		// Called from EstablishBluetoothConnection.
    - ( void ) displayMessage : ( NSString* ) message;          		// Called when a message is generated from Datacap library calls.
    - ( void ) transactionResponse : ( NSString* ) response;    		// Called from ProcessTransaction or GetDevicesInfo.
    - ( void ) displaySAFEventMessage : ( NSString* ) message : ( const int ) iStateCode : ( const int ) iTotalOperations : ( const int ) iCurrentOperation; // Called from DisplaySAFEventMessage.
    - ( void ) setSAFForwardAllEventRunning : ( const bool ) bIsRunning;// Called from SetSAFForwardAllEventRunning.
@end

@interface dsiEMVApple : NSObject
	#ifndef __BRIDGING__
		// PascalCase for 'C', C++, and Objective-C.
		- ( NSString* ) ProcessTransaction : ( NSString* ) nsRequest;
		- ( NSString* ) GetDevicesInfo;
		- ( NSString* ) CollectCardData : ( NSString* ) nsRequest;
		- ( void ) CancelTransaction;
		- ( void ) Disconnect;
	    - ( NSString* ) EstablishBluetoothConnection : ( NSString* ) nsBluetoothDeviceName;
	    - ( bool ) IsBluetoothConnected;
	#endif

	// CamelCase for Swift and Objective-C
	- ( NSString* ) processTransaction : ( NSString* ) nsRequest;
	- ( NSString* ) getDevicesInfo;
	- ( NSString* ) collectCardData : ( NSString* ) nsRequest;
	- ( void ) cancelTransaction;
	- ( void ) disconnect;
    - ( NSString* ) establishBluetoothConnection : ( NSString* ) nsBluetoothDeviceName;
    - ( bool ) isBluetoothConnected;

    @property( nullable, nonatomic, weak ) id < dsiEMVAppleDelegate > delegate;
@end  