//
//  ViewController.m
//
//  Created by datacap on 11/12/20.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "ViewController.h"
#import "dsiEMVApple.h"
#include <ifaddrs.h>
#include <arpa/inet.h>

@interface IPSocketServer : NSObject
    enum eError
    {
        eNoError,
        eSocketError,
        eBindError,
        eListenError,
        eAcceptError,
        eSelectError,
        eReceiveError,
        eWriteError
    };

    - ( id ) initStartServer : ( const char* ) pszIpAddr : ( const int ) iPort;
    - ( void ) HandleAcceptRequests : ( ViewController* ) _ViewController;
    - ( enum eError ) GetLastError;
@end


static NSString* static_nsNoDevice = @"NO DEVICE";


// NOTE: Make sure to add these two "Use Description" to the Info.plist for any project that uses Bluetooth,
// otherwise a crash and/or the application will fail to upload to the App Store and TestFlight.
// NSBluetoothAlwaysUsageDescription        "YOUR DESCRIPTION HERE"
// NSBluetoothPeripheralUsageDescription    "YOUR DESCRIPTION HERE"

@interface BLEApple : NSObject
@end

@interface BLEApple ( ) < CBCentralManagerDelegate, CBPeripheralDelegate >
    @property ( retain, strong ) CBCentralManager* m_cbCentralManager;
    @property ( retain, strong ) dispatch_queue_t m_dqDispatchQueue;
    @property ( retain, strong ) NSMutableArray* m_arrayDeviceNames;
@end

@implementation BLEApple

- ( instancetype ) init
{
    self.m_dqDispatchQueue = dispatch_queue_create( "com.datacap.test.worker-thread", DISPATCH_QUEUE_SERIAL );
    self.m_cbCentralManager = [ [ CBCentralManager alloc ] initWithDelegate : self queue : self.m_dqDispatchQueue options : nil ];
    self.m_arrayDeviceNames = [ [ NSMutableArray alloc ] init ];
    
    [ self.m_arrayDeviceNames addObject : static_nsNoDevice ];
            
    return self;
}

- ( void ) centralManagerDidUpdateState : ( nonnull CBCentralManager* ) central
{
    // Are we ready to go with Bluetooth?
    if ( CBCentralManagerStatePoweredOn == [ central state ] )
    {
        // Start scanning for peripherals.
        [ central scanForPeripheralsWithServices : nil options : nil ];
    }
}

- ( void ) centralManager:( CBCentralManager* ) central didDiscoverPeripheral : ( CBPeripheral* ) peripheral advertisementData : ( NSDictionary* ) advertisementData RSSI : ( NSNumber* ) RSSI
{
    // Retrieve the peripheral name from the advertisement data using the "kCBAdvDataLocalName" key.
    NSString* peripheralName = [ advertisementData objectForKey : @"kCBAdvDataLocalName" ];
    
    if ( nil != peripheralName )
    {
        // Only look for VP3300 device(s).
        if ( [ peripheralName containsString : @"VP3300" ] )
        {
            // Add the device name to the array of devices.
            [ self.m_arrayDeviceNames addObject : peripheralName ];
        }
    }
}

@end

@implementation ViewController
{
    dsiEMVApple*        m_dsiAppleClientLib;        // Datacap library public class instance.
    BLEApple*           m_bleApple;                 // Bluetooth manager class instance.
    IPSocketServer*     m_ipSocketServer;           // IP socket server that uses incoming Datacap Test App connections.
    NSThread*           m_nsWorkerThread;           // Thread class instance for worker thread.
    NSThread*           m_nsIPServerThread;         // Thread class for the IP server thread.
    NSString*           m_nsRequest;                // XML request to Datacap library calls.
    NSString*           m_nsReponse;                // XML responses from Datacap library calls.
    NSString*           m_nsSocketRequest;          // XML request from the socket server.
    NSString*           m_nsSocketResponse;         // XML response for the socket server.
    UIAlertController*  m_PleasewaitGettingDevices; // "Please Wait Getting Devices" message window.
    UIAlertController*  m_PleasewaitPairingDevice;  // "Please Wait Pairing Device" message window.
    bool                m_bSelectDevice;            // Is the "SELECT DEVICE" functionality being executed?
    int                 m_iWakeupType;              // What type of functionality should execute on the worker thread?
    int                 m_iDownloadDevice;          // Download device count (0, 1, or 2).
}

enum eThreadMethod
{
    eThreadSleeping         = 0,
    eSelectDevice           = 1,
    eSaleTransaction        = 2,
    eReturnTransaction      = 3,
    eCancelTranaction       = 4,
    eEMVParamDownload       = 5,
    eMerchantParamDownload  = 6,
    eDeviceInfo             = 7,
    ePairDevice             = 8,
    eStopThread             = 9,
    eSocketTransaction      = 10
};

enum eControlId
{
    eTransactionResultsViewId   = 1,
    eMerchantId                 = 2,
    eAmountId                   = 3,
    eDeviceNameId               = 4,
    eIPAddressId                = 5,
    eCancelButtonId             = 6,
    eDeviceNamePickerId         = 7,
    eCloseDeviceNamePickerId    = 8,
    eMessageDisplayViewId       = 9,
    eSelectDeviceId             = 10
};

- ( instancetype ) init
{
    m_dsiAppleClientLib         = nil;
    m_bleApple                  = nil;
    m_ipSocketServer            = nil;
    m_nsWorkerThread            = nil;
    m_nsIPServerThread          = nil;
    m_nsRequest                 = nil;
    m_nsReponse                 = nil;
    m_nsSocketRequest           = nil;
    m_nsSocketResponse          = nil;
    m_PleasewaitGettingDevices  = nil;
    m_PleasewaitPairingDevice   = nil;
    m_bSelectDevice             = false;
    m_iWakeupType               = eThreadSleeping;
    m_iDownloadDevice           = 0;
    
    return self;
}

- ( void ) viewDidLoad
{
    [ super viewDidLoad ];
        
    [ self InitViewController ];
}

- ( void ) InitViewController
{
    [ self init ];
    
    [ self StartWorkerThread ];
    
    [ self StartIPServerThread ];
    
    // BEGIN: Set control attributes
    for ( UIView* subView in self.view.subviews )
    {
        if ( [ subView isMemberOfClass : [ UIButton class ] ] )
        {
            //( ( UIButton* ) subView ).layer.borderWidth = 1.0f;
            UIColor* uicLiteGray =  [ UIColor colorWithRed : ( 220.0 / 255.0 ) green : ( 220.0 / 255.0  ) blue : ( 220.0 / 255.0  ) alpha : 1.0  ];
            [ ( ( UIButton* ) subView ) setBackgroundColor : uicLiteGray ];
        }
     }
    
    ( (  UIButton*  ) [ self.view viewWithTag : eCloseDeviceNamePickerId ] ).hidden = true;
    ( (  UITextView*  ) [ self.view viewWithTag : eTransactionResultsViewId ] ).editable = NO;
    ( (  UITextField*  ) [ self.view viewWithTag : eIPAddressId ] ).text = [ self GetIPAddress ];
    ( (  UIPickerView*  ) [ self.view viewWithTag : eDeviceNamePickerId ] ).dataSource = self;
    ( (  UIPickerView*  ) [ self.view viewWithTag : eDeviceNamePickerId ] ).delegate = self;
    ( (  UIPickerView*  ) [ self.view viewWithTag : eDeviceNamePickerId ] ).layer.borderWidth = 1.0f;
    // END: Set control attributes
    
    // Create Datacap Apple client library class.
    m_dsiAppleClientLib = [ [ dsiEMVApple alloc ] init ];
    
    // If want to use any of the three delete methods, assign now.
    m_dsiAppleClientLib.delegate = ( id< dsiEMVAppleDelegate > ) self;
}

- ( IBAction ) CloseSelectDevicePicker : ( id ) sender
{
    [ self _CloseSelectDevicePicker ];
 }

- ( IBAction ) MerchantEntered : (  id ) sender
{
    [ ( UITextField* ) sender resignFirstResponder ];
}

- ( IBAction ) AmountEntered : ( id ) sender
{
    [ ( UITextField* ) sender resignFirstResponder ];
}

- ( IBAction ) SelectDevice : ( id ) sender
{
    if ( !m_bSelectDevice )
    {
        ( (  UIButton*  ) [ self.view viewWithTag : eSelectDeviceId ] ).enabled = false;
        ( (  UIButton*  ) [ self.view viewWithTag : eMerchantId ] ).enabled = false;
        ( (  UIButton*  ) [ self.view viewWithTag : eAmountId ] ).enabled = false;
        
        [ self PleaseWaitGettingDevices : true ];
        
        [ self ClearTextViews ];
        
        if ( nil != m_bleApple )
        {
            [ m_bleApple.m_arrayDeviceNames removeAllObjects ];
        }
        
        [ ( (  UIPickerView*  ) [ self.view viewWithTag : eDeviceNamePickerId ] ) reloadComponent : 0 ];
        
        if ( nil != m_bleApple )
        {
            [ m_bleApple.m_arrayDeviceNames addObject : static_nsNoDevice ];
        }
                
        [ self WakeupThread : eSelectDevice ];
        [ self OpenDevicePicker ];
        [ NSTimer scheduledTimerWithTimeInterval : 3.5 target : self selector : @selector( ContinueSelectDevice ) userInfo : nil repeats : NO ];
    }
}

- ( void ) CancelTransaction
{
    [ m_dsiAppleClientLib CancelTransaction ];
}

- ( IBAction ) CancelTransaction : ( id ) sender
{
    [ self CancelTransaction ];
}

- ( IBAction ) ParamDownLoad : ( id ) sender
{
    [ self ClearTextViews ];
    ( (  UITextView*  ) [ self.view viewWithTag : eMessageDisplayViewId ] ).text = @"LOADING MERCHANT PARAMETERS...";
    [ self WakeupThread : eMerchantParamDownload ];
}

- ( IBAction ) DeviceInfo : ( id ) sender
{
    [ self ClearTextViews ];
    [ self WakeupThread : eDeviceInfo ];
}

- ( IBAction ) ReturnTransaction : ( id ) sender
{
    if ( [ self IsPaired ] )
    {
        [ self ClearTextViews ];
        [ self WakeupThread : eReturnTransaction ];
    }
}

- ( IBAction ) SaleTransation : ( id ) sender
{
    if ( [ self IsPaired ] )
    {
        [ self ClearTextViews ];
        [ self WakeupThread : eSaleTransaction ];
    }
}

- ( bool ) IsDeviceInfoSocketRequest
{
     return NSNotFound != [ m_nsSocketRequest rangeOfString : @"GetDevicesInfo" ].location;
}

- ( void ) SocketTransaction : ( NSString* ) nsTransactionXML
{
    m_nsSocketResponse = nil;
    m_nsSocketRequest = nsTransactionXML;
     
    [ self ClearTextViews ];
    [ self WakeupThread : eSocketTransaction ];
}

- ( bool ) IsPaired
{
    return ![ ( (  UITextView*  ) [ self.view viewWithTag : eDeviceNameId ] ).text  isEqualToString : static_nsNoDevice ];
}

- ( NSString* ) GetSocketTransactionResponse
{
    return m_nsSocketResponse;
}

- ( NSString* ) GetRequestXML : ( const bool ) bTransaction : ( NSString* ) nsTranCode
{
    NSString* nsFormat = nil;
    NSString* nsRequest = nil;
    
    if ( bTransaction )
    {
        nsFormat = @
            "<TStream>"
                "<Transaction>"
                    "<IpPort>9000</IpPort>"
                    "<MerchantID>%@</MerchantID>"
                    "<UserTrace>Test</UserTrace>"
                    "<POSPackageID>EMVUSClient:1.27</POSPackageID>"
                    "<TranCode>%@</TranCode>"
                    "<SecureDevice>EMV_VP3300_DATACAP</SecureDevice>"
                    "<ComPort>1</ComPort>"
                    "<RefNo>1</RefNo>"
                    "<Amount>"
                        "<Purchase>%@</Purchase>"
                    "</Amount>"
                    "<InvoiceNo>10</InvoiceNo>"
                    "<SequenceNo>0010010010</SequenceNo>"
                    "<OperationMode>CERT</OperationMode>"
                    "<BluetoothDeviceName>%@</BluetoothDeviceName>"
                "</Transaction>"
            "</TStream>";

        nsRequest = [ NSString stringWithFormat : nsFormat,
                ( (  UITextView*  ) [ self.view viewWithTag : eMerchantId ] ).text,
                nsTranCode,
                ( (  UITextView*  ) [ self.view viewWithTag : eAmountId ] ).text,
                ( (  UITextView*  ) [ self.view viewWithTag : eDeviceNameId ] ).text ];
    }
    else
    {
        nsFormat = @
            "<TStream>\n"
            "<Admin>"
                "<IpPort>9000</IpPort>"
                "<MerchantID>%@</MerchantID>"
                "<UserTrace>Test</UserTrace>"
                "<POSPackageID>EMVUSClient:1.27</POSPackageID>"
                "<TranCode>EMVParamDownload</TranCode>"
                "<SecureDevice>EMV_VP3300_DATACAP</SecureDevice>"
                "<ComPort>1</ComPort>"
                "<SequenceNo>0010010010</SequenceNo>"
                "<DisplayTextHandle>000306AE</DisplayTextHandle>"
                "<OperationMode>TEST</OperationMode>"
                "<BluetoothDeviceName>%@</BluetoothDeviceName>"
            "</Admin>"
        "</TStream>";
        
        nsRequest = [ NSString stringWithFormat : nsFormat,
                ( (  UITextView*  ) [ self.view viewWithTag : eMerchantId ] ).text,
                nsTranCode,
                ( (  UITextView*  ) [ self.view viewWithTag : eDeviceNameId ] ).text ];
    }
    
    return nsRequest;
}

- ( NSString* ) GetIPAddress
{
    NSString* nsAddress = @"IP address error.";
    struct ifaddrs* interfaces = nil;
    struct ifaddrs* temp_addr = nil;
    const int success = getifaddrs( &interfaces ); // retrieve the current interfaces - returns 0 on success

    if ( 0 == success )
    {
        // Loop through linked list of interfaces.
        temp_addr = interfaces;

        while ( nil != temp_addr )
        {
            if ( AF_INET == temp_addr->ifa_addr->sa_family )
            {
                // Check if interface is en0 which is the wifi connection on the iPhone.
                if ( [ [ NSString stringWithUTF8String : temp_addr->ifa_name ] isEqualToString : @"en0" ] )
                {
                    // Get NSString from C String.
                    nsAddress = [ NSString stringWithUTF8String : inet_ntoa( ( ( struct sockaddr_in* ) temp_addr->ifa_addr )->sin_addr ) ];
                    break;
                }
            }

            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs( interfaces );
    
    return nsAddress;
}

- ( void ) WakeupThread : ( const int ) iWakeupType
{
    // Only continue if worker thread is sleeping.
    if ( eThreadSleeping == m_iWakeupType )
    {
        m_iWakeupType = iWakeupType;
        
        // Call function in the worker thread to "wakeup".
        [ self performSelector : @selector( WakeUpThreadRunLoop ) onThread : m_nsWorkerThread withObject : nil waitUntilDone : NO ];
    }
}

- ( void ) WakeUpThreadRunLoop
{
    CFRunLoopWakeUp( CFRunLoopGetCurrent( ) );
}

- ( bool ) StartWorkerThread
{
    bool bRet = false;

    // Creating a worker thread to handle Bluetooth LE calls to get the name of device(s) and also performing Datacap library calls so
    // the primary thread would be not be affected and no user interface sluggishness. The functionality could have also been done with
    // GCD threading. But with Bluetooth LE, its based on delegates which uses a dispatch queue so the dispatch queue was created and
    // used on this worker thread, so as not to interfere with the primary thread. And since we have this worker thread, it could also
    // be used to execute Datacap library calls. With the Datacap library calls being executing on this worker thread, it's easy to allow
    // the Datacap library function "CancelTransaction" to be called from the main thread an not affect perform on the main thread.

    if ( nil == m_nsWorkerThread )
    {
        [ NSThread detachNewThreadSelector : @selector( _StartWorkerThread : ) toTarget : [ ViewController class ] withObject : self ];
            
        bRet = true;
    }

    return bRet;
}

- ( bool ) StartIPServerThread
{
    bool bRet = false;
    
    // Creating a socket server thread to allow for connectons from the "EMV US Client Test App" so that additional XML transactions
    // could be sent through this "reference app" other then the two "built in" transactions in this reference app.
    
    if ( nil == m_nsIPServerThread )
    {
        [ NSThread detachNewThreadSelector : @selector( _StartIPServerThread : ) toTarget : [ ViewController class ] withObject : self ];
            
        bRet = true;
    }

   return bRet;
}

+ ( void ) _StartWorkerThread : ( id ) param
{
    ViewController* _ViewController = param;
    
    @autoreleasepool
    {
        _ViewController->m_nsWorkerThread = [ NSThread currentThread ];
        
        // Create a "dummy" source for worker thread to wait on. Creating a dummy because this is a trival use of a source.
        CFRunLoopSourceContext context = { 0 };
        CFRunLoopSourceRef source = CFRunLoopSourceCreate( NULL, 0, &context );
        
        // Add the source to the worker thread.
        CFRunLoopAddSource( CFRunLoopGetCurrent( ), source, kCFRunLoopCommonModes );
        
        // Starting infinite loop which can be stopped by changing the return value of method ProcessWakeupType
        do
        {
            // Sleep until woken up by a call to WakeUpThreadRunLoop.
            [ [ NSRunLoop currentRunLoop ] runMode : NSDefaultRunLoopMode beforeDate : [ NSDate distantFuture ] ];
            
            // Process commands until thread should be stopped.
            if  ( ![ self ProcessWakeupType : _ViewController ] )
            {
                break;
            }
        
        } while ( true );
        
        // Garbage collect source.
        CFRunLoopRemoveSource( CFRunLoopGetCurrent( ), source, kCFRunLoopCommonModes );
        CFRelease( source);
    }

    return;
}

+ ( void ) _StartIPServerThread : ( id ) param
{
    ViewController* _ViewController = param;
    
    _ViewController->m_ipSocketServer = [ [ IPSocketServer alloc ] initStartServer : "127.0.0.1" : 8080 ];
    
    @autoreleasepool
    {
        _ViewController->m_nsIPServerThread = [ NSThread currentThread ];
        
        // Starting infinite loop which can be stopped by setting m_iWakeupType to eStopThread.
        //
        // Note: the functionality to set m_iWakeupType to eStopThread has not been implemented.
        // If needed, update function ProcessWakeupType.
        
        while ( true )
        {
            [ _ViewController->m_ipSocketServer HandleAcceptRequests : _ViewController ];
            
            [ NSThread sleepForTimeInterval : 0.25f ];
            
            if ( eStopThread == _ViewController->m_iWakeupType )
            {
                break;
            }
        }
    }

    return;
}

+ ( bool ) ProcessWakeupType : ( ViewController* ) _ViewController
{
    const bool bRet = !( eStopThread == _ViewController->m_iWakeupType );
    NSString* nsTranCode = nil;

    if ( bRet )
    {
        switch ( _ViewController->m_iWakeupType )
        {
            case eSelectDevice:
                if ( nil == _ViewController->m_bleApple )
                {
                    _ViewController->m_bleApple = [ [ BLEApple alloc ] init ];
                }
                else
                {
                    [ _ViewController->m_bleApple.m_cbCentralManager scanForPeripheralsWithServices : nil options : nil ];
                }
                break;
                
            case eSocketTransaction:
                if  ( nil != _ViewController->m_nsSocketRequest )
                {
                    if ( [ _ViewController IsDeviceInfoSocketRequest ] )
                    {
                        _ViewController->m_nsSocketResponse = [ _ViewController->m_dsiAppleClientLib GetDevicesInfo ];
                    }
                    else
                    {
                        _ViewController->m_nsSocketResponse = [ _ViewController->m_dsiAppleClientLib  ProcessTransaction : _ViewController->m_nsSocketRequest ];
                    }
                    // Note: response can also be returned in dsiEMVAppleDelegate, method "transactionResponse"
                }
                break;
                
            case eSaleTransaction:
            case eReturnTransaction:
            case eMerchantParamDownload:
            case eEMVParamDownload:
                {
                    if ( eSaleTransaction == _ViewController->m_iWakeupType )
                    {
                        nsTranCode = @"EMVSale";
                    }
                    else if ( eReturnTransaction == _ViewController->m_iWakeupType )
                    {
                        nsTranCode = @"EMVReturn";
                    }
                    else if ( eMerchantParamDownload == _ViewController->m_iWakeupType )
                    {
                        nsTranCode = @"LoadParams";
                    }
                    else
                    {
                        nsTranCode = @"EMVParamDownload";
                    }
                    
                    dispatch_sync( dispatch_get_main_queue( ),
                    ^{
                        _ViewController->m_nsRequest = nil;
                        _ViewController->m_nsRequest = [ _ViewController GetRequestXML : true : nsTranCode ];
                    });
                        
                    if  ( nil != _ViewController->m_nsRequest )
                    {
                        _ViewController->m_nsReponse = [ _ViewController->m_dsiAppleClientLib  ProcessTransaction : _ViewController->m_nsRequest ];
                        // Note: response can also be returned in dsiEMVAppleDelegate, method "transactionResponse"
                    }
                }
                break;
                    
            case eDeviceInfo:
                _ViewController->m_nsReponse = [ _ViewController->m_dsiAppleClientLib GetDevicesInfo ];
                // Note: response can also be returned in dsiEMVAppleDelegate, method "transactionResponse"
                break;
                
            case ePairDevice:
                dispatch_sync( dispatch_get_main_queue( ),
                ^{
                    _ViewController->m_nsRequest = nil;
                    _ViewController->m_nsRequest = ( (  UITextView*  ) [ _ViewController.view viewWithTag : eDeviceNameId ] ).text;
                    
                });
                
                _ViewController->m_nsReponse = [ _ViewController->m_dsiAppleClientLib EstablishBluetoothConnection : _ViewController->m_nsRequest ];
                // Note: response can also be returned in dsiEMVAppleDelegate, method "connectionResponse"
                break;
                
                //case eThreadSleeping:
                //    break;
                //case eCancelTranaction:
                //    break;
                //case eCancelTranaction:
                //    break;
                //case eStopThread:
                //    break;
        }
        
        if ( eMerchantParamDownload == _ViewController->m_iWakeupType )
        {
            _ViewController->m_iWakeupType = eEMVParamDownload;
            _ViewController->m_iDownloadDevice = 1;
            [ self ProcessWakeupType : _ViewController ];
        }
        
        _ViewController->m_iWakeupType = eThreadSleeping;
    }
    
    return bRet;
}

- ( void ) ContinueSelectDevice
{
    if ( m_bSelectDevice )
    {
        [ self PleaseWaitGettingDevices : false ];
        
        // Stop scanning for Bluetooth LE peripherals.
        [ m_bleApple.m_cbCentralManager stopScan ];
        
        // Did we find any devices?
        if ( [ m_bleApple.m_arrayDeviceNames count ] > 0 )
        {
            [ ( (  UIPickerView*  ) [ self.view viewWithTag : eDeviceNamePickerId ] ) reloadComponent : 0 ];
        }
        else
        {
            ( (  UIPickerView*  ) [ self.view viewWithTag : eDeviceNamePickerId ] ).hidden = true;
            ( (  UITextView*  ) [ self.view viewWithTag : eTransactionResultsViewId ] ).text = @"Cannot find any VP3300 devices.";
        }
    }
}

- ( void ) didReceiveMemoryWarning
{
    [ super didReceiveMemoryWarning ];
}

- ( NSInteger ) numberOfComponentsInPickerView : ( UIPickerView* ) pickerView
{
     return 1;
}

- ( NSInteger ) pickerView : ( UIPickerView* ) pickerView numberOfRowsInComponent : ( NSInteger ) component
 {
     int iRet = 0;
     
     if ( nil != m_bleApple )
     {
         iRet = ( int ) [ m_bleApple.m_arrayDeviceNames count ];
     }

     return iRet;
}

- ( UIView* ) pickerView : ( UIPickerView* ) pickerView viewForRow : ( NSInteger ) row forComponent : ( NSInteger ) component reusingView : ( UIView* ) view
{
    UILabel* tView = ( UILabel* )view;
    
    if ( nil == tView )
    {
       tView = [ [ UILabel alloc ] init ];
       [ tView setFont : [ UIFont fontWithName : @"Helvetica" size : 14 ] ];
    }
    
    tView.text = m_bleApple.m_arrayDeviceNames[ row ];
    
   return tView;
}

- ( void ) pickerView : ( UIPickerView* ) pickerView didSelectRow : ( NSInteger ) row inComponent : ( NSInteger ) component
{
    NSString* nsCurrentDeviceName = ( (  UITextView*  ) [ self.view viewWithTag : eDeviceNameId ] ).text;
    NSString* nsNewDeviceName = m_bleApple.m_arrayDeviceNames[ row ];
    bool bPair = false;
 
    [ ( (  UIPickerView*  ) [ self.view viewWithTag : eDeviceNamePickerId ] ) resignFirstResponder ];
    ( (  UITextView*  ) [ self.view viewWithTag : eDeviceNameId ] ).text = nsNewDeviceName;
    
    if ( ![ nsNewDeviceName isEqualToString : static_nsNoDevice ] )
    {
        if ( ![ nsNewDeviceName isEqualToString : nsCurrentDeviceName ] )
        {
            bPair = true;
        }
    }
    
    [ self CloseDevicePicker : bPair ];
}

- ( void ) CloseDevicePicker : ( const bool ) bPair
{
    ( (  UIPickerView*  ) [ self.view viewWithTag : eDeviceNamePickerId ] ).hidden = true;
    ( (  UIButton*  ) [ self.view viewWithTag : eCloseDeviceNamePickerId] ).hidden = true;
    ( (  UIButton*  ) [ self.view viewWithTag : eSelectDeviceId ] ).enabled = true;
    ( (  UIButton*  ) [ self.view viewWithTag : eMerchantId ] ).enabled = true;
    ( (  UIButton*  ) [ self.view viewWithTag : eAmountId ] ).enabled = true;
    
    m_bSelectDevice = false;
    
    [  m_dsiAppleClientLib Disconnect ];
    
    if ( bPair )
    {
        [ self PleaseWaitPairingDevice : true ];
        [ self WakeupThread : ePairDevice ];
    }
}

- ( void ) OpenDevicePicker
{
    ( (  UIPickerView*  ) [ self.view viewWithTag : eDeviceNamePickerId ] ).hidden = false;
    ( (  UIButton*  ) [ self.view viewWithTag : eCloseDeviceNamePickerId ] ).hidden = false;
    m_bSelectDevice = true;

}

- ( void ) PleaseWaitGettingDevices : ( const bool ) bWait
{
    if ( nil == m_PleasewaitGettingDevices )
    {
        m_PleasewaitGettingDevices = [ UIAlertController alertControllerWithTitle : @"Getting VP3300 Bluetooth LE devices\n\nPlease wait..." message : nil preferredStyle : UIAlertControllerStyleAlert ];
        UIAlertAction* cancelAction = [ UIAlertAction actionWithTitle : @"Cancel" style : UIAlertActionStyleCancel handler : ^( UIAlertAction* action ) { [ self _CloseSelectDevicePicker ];  [ self PleaseWaitGettingDevices : false ]; } ];
      
        [ m_PleasewaitGettingDevices addAction : cancelAction ];
        [ m_PleasewaitGettingDevices.view setTintColor : [ UIColor blackColor ] ];
    }
    
    if (  bWait )
    {
        [ self presentViewController : m_PleasewaitGettingDevices animated : YES completion : nil ];
    }
    else
    {
        [ self dismissViewControllerAnimated : true completion : nil ];
    }
}

- ( void ) PleaseWaitPairingDevice : ( const bool ) bWait
{
    if ( nil == m_PleasewaitPairingDevice )
    {
        m_PleasewaitPairingDevice = [ UIAlertController alertControllerWithTitle : @"Pairing VP3300 Bluetooth LE device\n\nPlease wait..." message : nil preferredStyle : UIAlertControllerStyleAlert ];
        UIAlertAction* cancelAction = [ UIAlertAction actionWithTitle : @"Cancel" style : UIAlertActionStyleCancel handler : ^( UIAlertAction* action ) {  [ self CancelTransaction ]; ( (  UITextView*  ) [ self.view viewWithTag : eDeviceNameId ] ).text = static_nsNoDevice; } ];
      
        [ m_PleasewaitPairingDevice addAction : cancelAction ];
        [ m_PleasewaitPairingDevice.view setTintColor : [ UIColor blackColor ] ];
    }
    
    if (  bWait )
    {
        [ self presentViewController : m_PleasewaitPairingDevice animated : YES completion : nil ];
    }
    else
    {
        [ self dismissViewControllerAnimated : true completion : nil ];
    }
}


- ( void ) _CloseSelectDevicePicker
{
    [ self CloseDevicePicker : false ];
    [ m_bleApple.m_cbCentralManager stopScan ];
}

- ( void ) ClearTextViews
{
    ( (  UITextView*  ) [ self.view viewWithTag : eMessageDisplayViewId ] ).text = @"";
    ( (  UITextView*  ) [ self.view viewWithTag : eTransactionResultsViewId ] ).text = @"";
}

- ( void ) connectionResponse : ( NSString* ) response
{
    // Delegate called Datacap library call: EstablishBluetoothConnection
    [ self PleaseWaitPairingDevice : false ];
    ( (  UITextView*  ) [ self.view viewWithTag : eTransactionResultsViewId ] ).text = response;
}

- ( void ) displayMessage : ( NSString* ) message
{
    // Delegate called when a message is generated from Datacap library calls.
    ( (  UITextView*  ) [ self.view viewWithTag : eMessageDisplayViewId ] ).text = message;
}

- ( void ) transactionResponse : ( NSString* ) response
{
    // Delegate called when ProcessTransaction or GetDevicesInfo is called.
    
    if ( 2 == m_iDownloadDevice )
    {
        NSString* prevText = ( (  UITextView*  ) [ self.view viewWithTag : eTransactionResultsViewId ] ).text;
        NSMutableString* mutableText = [ NSMutableString stringWithString : prevText ];
        [ mutableText appendString : @"\n\n" ];
        [ mutableText appendString : response ];
        ( (  UITextView*  ) [ self.view viewWithTag : eTransactionResultsViewId ] ).text = mutableText;
        
        m_iDownloadDevice = 0;
    }
    else
    {
        ( (  UITextView*  ) [ self.view viewWithTag : eTransactionResultsViewId ] ).text = response;
        
        if ( 1 == m_iDownloadDevice )
        {
            ++m_iDownloadDevice;
        }
    }
}

@end


@implementation IPSocketServer
{
    int m_iListenfd;
    enum eError m_eErrorCode;
}

- ( instancetype ) initStartServer : ( const char* ) pszIpAddr : ( const int ) iPort
{
       self = [ super init ];
    
       if ( nil != self )
       {
           
           struct sockaddr_in servaddr;
           
           m_iListenfd = 0;
           m_eErrorCode = eNoError;
           
           // Create the socket
           if ( ( m_iListenfd = socket( AF_INET, SOCK_STREAM, 0 ) ) < 0 )
           {
               m_eErrorCode = eSocketError;
           }
           else
           {
               const int iListQ = 1024;
               
               memset( &servaddr, 0, sizeof( servaddr ) );
               
               servaddr.sin_family = AF_INET;
               servaddr.sin_addr.s_addr = htonl( INADDR_ANY ); // Using INADDR_ANY and not using function parameter "pszIpAddr".
               servaddr.sin_port = htons( iPort );
               
               // Give the socket a name
               if ( bind( m_iListenfd, ( struct sockaddr* ) &servaddr, sizeof( servaddr ) ) < 0 )
               {
                   m_eErrorCode = eBindError;
               }
               // Set the socket up to accept connections.
               else if ( ( listen( m_iListenfd, iListQ ) ) < 0 )
               {
                   m_eErrorCode = eListenError;
               }
           }
       }
    
       return self;
}

- ( enum eError ) GetLastError
{
    return m_eErrorCode;
}

- ( void ) HandleAcceptRequests : ( ViewController* ) _ViewController
{
    fd_set read_fd_set;
    struct timeval timeout = { 0, 10000 }; // tenth of a second

    FD_ZERO( &read_fd_set );
    FD_SET( m_iListenfd, &read_fd_set );

    // Wait up to one tenth of second until input arrives on one or more active sockets.
    if ( select( FD_SETSIZE, &read_fd_set, NULL, NULL, &timeout ) < 0 )
    {
       m_eErrorCode = eSelectError;
    }
    else
    {
        // Service all the sockets with input pending.
        for ( int i = 0; i < FD_SETSIZE; ++i )
        {
            if ( FD_ISSET( i, &read_fd_set ) )
            {
                if ( i == m_iListenfd )
                {
                    int connfd;
                    socklen_t clilen;
                    struct sockaddr_in cliaddr;

                    clilen = sizeof( cliaddr );
                      
                    // Connection request on original socket.
                    if ( ( connfd = accept( m_iListenfd, ( struct sockaddr* ) &cliaddr, &clilen ) ) < 0 )
                    {
                        if ( EINTR != errno )
                        {
                            m_eErrorCode = eAcceptError;
                        }
                    }
                    else
                    {
                        m_eErrorCode = eNoError;

                        // Process the transaction on a seperate thread.
                        dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 ), ^{ [ self ProcessTransaction : _ViewController : connfd ]; } );
                    }
                }
            }
        }
    }
}

- ( void ) ProcessTransaction : ( ViewController* ) _ViewController : ( const int ) iSockfd
{
    // Read the HTTP request.
    NSString* nsTransactionXML = [ self Read : iSockfd ];
    
    if ( nil != nsTransactionXML )
    {
        const unsigned int uiMaxWaitTime = 1200; // 300 seconds ( 1200 X 0.25 seconds )
        
        // Start the process of starting the transaction using Datacap's library.
        dispatch_sync( dispatch_get_main_queue( ),
        ^{
            [ _ViewController SocketTransaction : nsTransactionXML ];
        });
        
        // Wait for the transaction to complete (up to 30 seconds).
        
        for ( unsigned int ui = 0; ui < uiMaxWaitTime; ++ui )
        {
            NSString* nsSocketTransactiionRepsonse = [ _ViewController GetSocketTransactionResponse ];
            
            if ( nil != nsSocketTransactiionRepsonse )
            {
                NSString* nsFormat = @
                    "HTTP/1.0 200 OK\r\n"
                    "Content-Type: text/html; charset=utf-8\r\n"
                    "Content-Length: %d\r\n"
                    "\r\n"
                    "%@";
                   
                // Wrap the transaction XML with HTTP minimal info.
                NSString* nsRequest = [ NSString stringWithFormat : nsFormat, nsSocketTransactiionRepsonse.length, nsSocketTransactiionRepsonse ];
        
                // Write HTTP response to the client.
                [ self Write : iSockfd : [ nsRequest UTF8String ]: nsRequest.length ];
                break;
            }
            
            // Sleep a quarter of second.
            [ NSThread sleepForTimeInterval : 0.25f ];
        }
    }
    
    // Done with the socket, close it.
    close( iSockfd );
}

- ( NSString* ) Read : ( const int ) iSockfd
{
    const size_t stMaxLine = 4096;
    char buf[ stMaxLine ] = { 0 };
    NSMutableString* strTemp = [ [ NSMutableString alloc ] init ];
    NSString* strContentLen = @"\r\nContent-Length: ";
    NSString* nsRet = nil;
    NSRange ContentLenPos = { 0 };
    ssize_t stBytesRec;
    int iStartContentPos = -1;
    int iContentLen = -1;

    ContentLenPos.location = NSNotFound;
    
    // Read from socket,
    while ( ( stBytesRec = recv( iSockfd, buf, stMaxLine - 1, 0 ) ) > 0 )
    {
        [ strTemp appendString : @( buf ) ];
          
        // Looking for the HTTP request content size.
        
        if ( NSNotFound == ContentLenPos.location )
        {
            ContentLenPos = [ strTemp rangeOfString : strContentLen ];

            if ( NSNotFound != ContentLenPos.location )
            {
                const int iLen = ( strTemp.length - ( ContentLenPos.location + ContentLenPos.length ) );

                NSString* substr = [ strTemp substringWithRange : NSMakeRange( ( ContentLenPos.location + ContentLenPos.length ), iLen )];

                NSRange tempRange = [ substr rangeOfString : @"\r\n\r\n" ];

                if ( NSNotFound != tempRange.location )
                {
                    NSString* strContentLen = [ substr substringWithRange : NSMakeRange( 0, tempRange.location )];

                    iContentLen = strContentLen.intValue;

                    if ( ( substr.length - tempRange.length ) >= iContentLen )
                    {
                        // Get the starting position of the HTTP body text.
                        iStartContentPos = ( ( ContentLenPos.location + ContentLenPos.length ) + tempRange.length + strContentLen.length );
                        break;
                    }
                }
            }
        }
    }

    if ( strTemp.length > iContentLen )
    {
        // Get the HTTP body text.
        nsRet = [ strTemp substringWithRange : NSMakeRange( iStartContentPos, iContentLen ) ];
    }
    else if ( -1 == stBytesRec )
    {
        m_eErrorCode = eReceiveError;
    }

    return nsRet;
  }

- ( ssize_t ) Write : ( const int ) sockfd  : ( const char* const ) vptr  : ( const size_t ) stCount
{
    size_t stLeft;
    ssize_t stWritten;
    ssize_t stRet = stCount;
    const char* ptr;

    ptr = vptr;
    stLeft = stCount;

    while ( stLeft > 0 )
    {
        // Write to socket
        if ( ( stWritten = write( sockfd, ptr, stLeft ) ) <= 0 )
        {
            if ( ( stWritten < 0 ) && ( errno == EINTR ) )
            {
                stWritten = 0;  /* and call write() again */
            }
            else
            {
                m_eErrorCode = eWriteError;
                stRet = -1;     /* error */
                break;
            }
        }
        
        stLeft -= stWritten;
        ptr += stWritten;
     }
       
    return stRet;
}

@end




