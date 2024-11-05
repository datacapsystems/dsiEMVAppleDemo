# dsiEMVAppleDemo

The dsiEMVApple demo application provides a sample dsiEMVApple integration using Objective-C. Using header file dsiEMVApple.h, Swift applications can use any of the Datacap's xcframework functionality by creating a bridging header.


# Getting started with dsiEMVApple

### Add dsiEMVApple.xcframework to your Xcode project
1. In the project navigator, select the project or group within a project to which you want to add the framework.
2. Choose File > Add Files to “Your Project Name”.
3. Select the dsiEMVApple.xcframework, and click Add.
4. In the project settings, choose the Build Phases tab.
5. Under the Embed Frameworks section, choose "+" to add a new Embedded Framework.
6. Select the dsiEMVApple.framework bundle, and click Add.

### Include the framework in your code
```objective-c
#import <dsiEMVApple/dsiEMVApple.h>
```

### Initialize the library
```objective-c
// Create Datacap Apple client library class.
dsiEMVApple* m_dsiAppleClientLib = [ [ dsiEMVApple alloc ] init ];
```

### Example usage to connect to a Bluetooth device
```objective-c
NSString* m_nsReponse = [ m_dsiAppleClientLib EstablishBluetoothConnection : @"IDTECH-VP3300-79156" ];
```

### Example usage to process a transcation
```objective-c
NSString* nsRequest = nil;
NSString* nsResponse = nil;

// Build XML request
nsRequest = 
	@"<TStream>"
		"<Transaction>"
			"<IpPort>9000</IpPort>"
			"<MerchantID>DATACAPTEST</MerchantID>"
			"<UserTrace>Test</UserTrace>"
			"<TranCode>EMVSale</TranCode>"
			"<SecureDevice>EMV_VP3300_DATACAP</SecureDevice>"
			"<ComPort>1</ComPort>"
			"<RefNo>1</RefNo>"
			"<Amount>"
				"<Purchase>1.00</Purchase>"
			"</Amount>"
			"<InvoiceNo>10</InvoiceNo>"
			"<SequenceNo>0010010010</SequenceNo>"
			"<OperationMode>CERT</OperationMode>"
			"<BluetoothDeviceName>IDTECH-VP3300-79156</BluetoothDeviceName>"
		"</Transaction>"
	"</TStream>";

// Pass XML request to ProcessTransaction, read and process response
nsResponse = [ m_dsiAppleClientLib ProcessTransaction : nsRequest ];
```

### Optionally implement dsiEMVAppleDelegate

##### Implement the `dsiEMVAppleDelegate` protocol
```objective-c
@interface ViewController : UIViewController < dsiEMVAppleDelegate >
```

##### Implement `dsiEMVAppleDelegate` methods

On Bluetooth Connection:
```objective-c
- ( void ) connectionResponse : ( NSString* ) response
{
    // Called with response from EstablishBluetoothConnection
}
```

On Transaction Response:
```objective-c
- (void)transactionResponse : ( NSString* ) response
{
    // Called with response from ProcessTransaction or GetDevicesInfo
}
```

On Display Message:
```objective-c
- (void)displayMessage : ( NSString* ) message
{
  //  Called when a message is generated from payment capture device
}
```

On SAF Event Message
```objective-c
- ( void ) displaySAFEventMessage : ( NSString* ) message : ( const int ) iStateCode : ( const int ) iTotalOperations : ( const int ) iCurrentOperation
{
	// Called after a SAF_ForwardAll was sent, for every forwarded transaction

    // Method parameter description
    // (1) message: error text when iStateCode is non-zero or transaction response XML for current transaction forwarded when iStateCode is zero.
    // (2) iStateCode: zero when no error, or error code.
    // (3) iTotalOperations: zero when non-zero in iStateCode, or total number ot transactions to forward when iStateCode is zero.
    // (4) iCurrentOperation: zero when non-zero in iStateCode, or current transaction number while forwarding when iStateCode is zero.
}
```

On SAF Forward All Event Running
- ( void ) setSAFForwardAllEventRunning : ( const bool ) bIsRunning
{
    // Delegate called when a SAF_ForwardAll is started (bIsRunning is 'true'), and when it has completed (bIsRunning is 'false').
    // Note: Inbetween both of these calls, delegate displaySAFEventMessage will be called for each forwarded transaction. When bIsRunning
    // is 'false', that means that all forwarding has completed and the overall response XML will be generated and returned in the normal
    // way (non-delegate usage).
    
    if ( bIsRunning )
    {
        // Starting forward all process
    }
    else
    {
        // Completed forward all process
    }
}
```

### Report bugs
If you encounter any bugs or issues with the latest version of dsiEMVApple, please report them to us by opening a [GitHub Issue](https://github.com/datacapsystems/dsiEMVAppleDemo/issues)!