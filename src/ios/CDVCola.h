#import <Cordova/CDVPlugin.h>

@interface CDVCola : CDVPlugin
{
    NSString *lastStatus;
    NSString *onStatusCallbackId;
}
- (void)uuid:(CDVInvokedUrlCommand*)command;
- (void)platform:(CDVInvokedUrlCommand*)command;
- (void)connect:(CDVInvokedUrlCommand*)command;
- (void)disconnect:(CDVInvokedUrlCommand*)command;
- (void)getStatus:(CDVInvokedUrlCommand*)command;
- (void)onStatus:(CDVInvokedUrlCommand*)command;
@end
