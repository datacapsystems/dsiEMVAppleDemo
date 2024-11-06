# dsiEMVAppleDemo

The dsiEMVApple demo application provides a sample dsiEMVApple integration using Objective-C. Using header file dsiEMVApple.h, Swift applications can use any of Datacap's xcframework functionality by creating a bridging header.

# Getting started with dsiEMVAppleDemo and dsiEMVApple xcframework

### dsiEMVAppleDemo application and dsiEMVApple.xcframework
1. Using Git, clone dsiEMVAppleDemo application or download the project ZIP file. Install/copy the project files into Xcode's project directory/folder. 
2. [Download Datacap's xcframework](https://datacapsystems.com/software/dsiEMVApple/dsiEMVApple.xcframework.zip). Unzip dsiEMVApple.xcframework into the directory/folder where other frameworks are located. Note: The dsiEMVApple.xcframework contains three frameworks: 1) iOS (ios-arm64_armv7), 2) Simulator (ios-arm64_i386_x86_64-simulator), 3) Mac Catalyst (ios-arm64_x86_64-maccatalyst).
3. In Xcode, open dsiEMVAppleDemo by selecting dsiClientLib_app.xcodeproj project directory/folder.
4. In the "Build Phases" tab, within the "Link Binary With Libraries", there should a framework in the list (dsiEMVApple.framework), this has been left in place as an example. It may be removed by using the "minus". Using the "plus", the "Choose frameworks and libraries to add:" form will be displayed. Select the appropriate dsiEMVApple framework from the dsiEMVApple.xcframework that was unzipped in step #2.
5. At this point, the product can be built and run as either an iOS, Simulator, or a Mac Catalyst application.
6. The GUI is very simplistic. Looking through the source code in file ViewController.m, one can see how to interact with the functionality (the APIs) in dsiEMVApple.xcframework.
7. In addition to the GUI, there is a very basic IP server that takes Datacap's transaction XML, process that XML, and returns response XML. In the upper left corner of the GUI, the IP address of the server is displayed (use 8080 as the port number).
		  
### Include the framework in your code
```objective-c
#import < dsiEMVApple/dsiEMVApple.h >
```

### Initialize the library
```objective-c
// Create Datacap's Apple client library class.
dsiEMVApple* m_dsiAppleClientLib = [ [ dsiEMVApple alloc ] init ];
```

### Example usage to connect to a Bluetooth device
```objective-c
NSString* m_nsReponse = [ m_dsiAppleClientLib EstablishBluetoothConnection : @"IDTECH-VP3300-79156" ];
```

### Example usage to process a transaction
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

### Optionally implement delegates using dsiEMVAppleDelegate

##### Implement the `dsiEMVAppleDelegate` protocol
```objective-c
@interface ViewController : UIViewController < dsiEMVAppleDelegate >
```

##### Implement `dsiEMVAppleDelegate` delegate methods

On Bluetooth Connection:
```objective-c
- ( void ) connectionResponse : ( NSString* ) response
{
	// Called with response from EstablishBluetoothConnection
}
```

On Transaction Response:
```objective-c
- ( void ) transactionResponse : ( NSString* ) response
{
	// Called with response from ProcessTransaction or GetDevicesInfo
}
```

On Display Message:
```objective-c
- ( void ) displayMessage : ( NSString* ) message
{
	//  Called when a message is generated from payment capture device
}
```

On SAF Event Message
```objective-c
- ( void ) displaySAFEventMessage : ( NSString* ) message : ( const int ) iStateCode : ( const int ) iTotalOperations : ( const int ) iCurrentOperation
{
	// Called after a SAF_ForwardAll was sent, for every transaction after that transaction has been forwarded and a response generated. If no error, the message is the response to the transaction.

	// Method parameter description
	// (1) message: error text when iStateCode is non-zero or transaction response XML for current transaction forwarded when iStateCode is zero.
	// (2) iStateCode: zero when no error, or error code.
	// (3) iTotalOperations: zero when non-zero in iStateCode, or total number ot transactions to forward when iStateCode is zero.
	// (4) iCurrentOperation: zero when non-zero in iStateCode, or current transaction number while forwarding when iStateCode is zero.
}
```

On SAF Forward All Event Running
```objective-c
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
If you encounter any bugs or issues with the latest version of dsiEMVApple, please report them to us by opening a [GitHub Issue](https://github.com/datacapsystems/dsiEMVAppleDemo/issues).