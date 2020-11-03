#import "CsZBar.h"
#import <AVFoundation/AVFoundation.h>
#import "AlmaZBarReaderViewController.h"

#pragma mark - State

@interface CsZBar ()
@property bool scanInProgress;
@property NSString *scanCallbackId;
@property AlmaZBarReaderViewController *scanReader;

@end

#pragma mark - Synthesize

@implementation CsZBar

@synthesize scanInProgress;
@synthesize scanCallbackId;
@synthesize scanReader;

#pragma mark - Cordova Plugin

- (void)pluginInitialize {
    self.scanInProgress = NO;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    return;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - Plugin API

- (void)scan: (CDVInvokedUrlCommand*)command;
{
    if (self.scanInProgress) {
        [self.commandDelegate
         sendPluginResult: [CDVPluginResult
                            resultWithStatus: CDVCommandStatus_ERROR
                            messageAsString:@"A scan is already in progress."]
         callbackId: [command callbackId]];
    } else {
        self.scanInProgress = YES;
        self.scanCallbackId = [command callbackId];
        self.scanReader = [AlmaZBarReaderViewController new];
        [self.scanReader setShowsZBarControls:NO];

        self.scanReader.readerDelegate = self;
        self.scanReader.supportedOrientationsMask = ZBarOrientationMask(UIInterfaceOrientationPortrait);

        // Get user parameters
        NSDictionary *params = (NSDictionary*) [command argumentAtIndex:0];
        NSString *camera = [params objectForKey:@"camera"];
        if([camera isEqualToString:@"front"]) {
            // We do not set any specific device for the default "back" setting,
            // as not all devices will have a rear-facing camera.
            self.scanReader.cameraDevice = UIImagePickerControllerCameraDeviceFront;
        }
        self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;

        NSString *flash = [params objectForKey:@"flash"];
        
        if ([flash isEqualToString:@"on"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        } else if ([flash isEqualToString:@"off"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        }else if ([flash isEqualToString:@"auto"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
        }
        
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        CGFloat screenHeight = screenRect.size.height;
        
        BOOL drawSight = [params objectForKey:@"drawSight"] ? [[params objectForKey:@"drawSight"] boolValue] : true;
        UIToolbar *toolbarViewFlash = [[UIToolbar alloc] init];
        float topToolbarSize = self.viewController.view.safeAreaInsets.top + 44.0;
        //The bar length it depends on the orientation
        toolbarViewFlash.frame = CGRectMake(0.0, 0, (screenWidth > screenHeight ?screenWidth:screenHeight), topToolbarSize);
        toolbarViewFlash.barStyle = UIBarStyleBlackOpaque;
        
        float bottomPosition = screenHeight - self.viewController.view.safeAreaInsets.bottom - 44.0;
        float bottomToolbarSize = self.viewController.view.safeAreaInsets.bottom + 44.0;
        UIToolbar *bottomToolbarView = [[UIToolbar alloc] init];
        bottomToolbarView.frame = CGRectMake(0.0, bottomPosition, (screenWidth > screenHeight ?screenWidth:screenHeight), bottomToolbarSize);
        bottomToolbarView.barStyle = UIBarStyleBlackOpaque;
        
        UIBarButtonItem *buttonFlash = [[UIBarButtonItem alloc] initWithTitle:@"Flash" style:UIBarButtonItemStyleDone target:self action:@selector(toggleflash)];
        
        NSArray *topButtons = [NSArray arrayWithObjects: buttonFlash, nil];
        [toolbarViewFlash setItems:topButtons animated:NO];
        
        UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        
        [cancelButton addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
        [cancelButton setTitle:@"Cancelar" forState:UIControlStateNormal];
        cancelButton.frame = CGRectMake(16, 8, 40.0, 40.0);
        cancelButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        [cancelButton sizeToFit];
        
        [bottomToolbarView addSubview:cancelButton];
        
        [self.scanReader.view addSubview:toolbarViewFlash];
        [self.scanReader.view addSubview:bottomToolbarView];

        if (drawSight) {
            CGFloat dim = screenWidth < screenHeight ? screenWidth / 1.1 : screenHeight / 1.1;
            UIView *polygonView = [[UIView alloc] initWithFrame: CGRectMake  ( (screenWidth/2) - (dim/2), (screenHeight/2) - (dim/2), dim, dim)];
            
            UIView *lineView = [[UIView alloc] initWithFrame:CGRectMake(0,dim / 2, dim, 1)];
            lineView.backgroundColor = [UIColor redColor];
            [polygonView addSubview:lineView];

            self.scanReader.cameraOverlayView = polygonView;
        }
        [self.scanReader setModalPresentationStyle:UIModalPresentationFullScreen];
        [self.viewController presentViewController:self.scanReader animated:YES completion:nil];
    }
}
- (void)cancel {
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"cancelled"]];
    }];
}
- (void)toggleflash {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    [device lockForConfiguration:nil];
    if (device.torchAvailable == 1) {
        if (device.torchMode == 0) {
            [device setTorchMode:AVCaptureTorchModeOn];
            [device setFlashMode:AVCaptureFlashModeOn];
        } else {
            [device setTorchMode:AVCaptureTorchModeOff];
            [device setFlashMode:AVCaptureFlashModeOff];
        }
    }
    
    [device unlockForConfiguration];
}

#pragma mark - Helpers

- (void)sendScanResult: (CDVPluginResult*)result {
    [self.commandDelegate sendPluginResult: result callbackId: self.scanCallbackId];
}

#pragma mark - ZBarReaderDelegate

- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    return;
}

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info {
    if ([self.scanReader isBeingDismissed]) {
        return;
    }
    
    id<NSFastEnumeration> results = [info objectForKey: ZBarReaderControllerResults];
    
    ZBarSymbol *symbol = nil;
    for (symbol in results) break; // get the first result

    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                               resultWithStatus: CDVCommandStatus_OK
                               messageAsString: symbol.data]];
    }];
}

- (void) imagePickerControllerDidCancel:(UIImagePickerController*)picker {
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"cancelled"]];
    }];
}

- (void) readerControllerDidFailToRead:(ZBarReaderController*)reader withRetry:(BOOL)retry {
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"Failed"]];
    }];
}

@end
