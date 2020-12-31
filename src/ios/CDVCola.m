#import "CDVCola.h"
@import NetworkExtension;

@implementation CDVCola

-(void)pluginInitialize
{
    lastStatus = @"disconnected";
    onStatusCallbackId = nil;
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(onVPNStatusChanged:) name:NEVPNStatusDidChangeNotification object:nil];
}

-(void)dispose
{
    onStatusCallbackId = nil;
}


-(NSMutableDictionary*)getKeychainQuery:(NSString*)key {
    return[NSMutableDictionary dictionaryWithObjectsAndKeys:(id)kSecClassGenericPassword,(id)kSecClass,key,(id)kSecAttrService, key,(id)kSecAttrAccount,(id)kSecAttrAccessibleAfterFirstUnlock,(id)kSecAttrAccessible,nil];
}

-(void)uuid:(CDVInvokedUrlCommand *)command
{
    NSString *uuid = nil;
    NSString *key = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"] stringByAppendingString:@".uuid"];
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:key];
    [keychainQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    [keychainQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
    CFDataRef keyData = NULL;
    if(SecItemCopyMatching((CFDictionaryRef)keychainQuery,(CFTypeRef*)&keyData) ==noErr){
        @try{
            uuid =[NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData*)keyData];
        }@catch(NSException *e) {
            NSLog(@"Unarchiveof %@ failed: %@",key, e);
        }@finally{
        }
    }
    if(keyData) CFRelease(keyData);
    if([uuid isEqualToString:@""]||!uuid){
        uuid = [UIDevice currentDevice].identifierForVendor.UUIDString;
        keychainQuery = [self getKeychainQuery:key];
        SecItemDelete((CFDictionaryRef)keychainQuery);
        [keychainQuery setObject:[NSKeyedArchiver archivedDataWithRootObject:uuid]forKey:(id)kSecValueData];
        SecItemAdd((CFDictionaryRef)keychainQuery,NULL);
    }
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:uuid];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)platform:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"ios"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) onVPNStatusChanged: (NSNotification*) notification
{
    if (onStatusCallbackId!=nil) {
        NETunnelProviderSession *connection = notification.object;
        NSString* status = [self getVPNStatus:connection.status];
        if(![status isEqualToString:lastStatus]){ //lastStatus==nil||
            lastStatus = status;
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:status];
            [pluginResult setKeepCallbackAsBool:YES];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:onStatusCallbackId];
        }
    }
}

-(NSString *)getVPNStatus:(NEVPNStatus)vpnStatus
{
    NSString* status = nil;
    switch (vpnStatus) {
        case NEVPNStatusInvalid:
            status = @"invalid";
            break;
        case NEVPNStatusDisconnected:
            status = @"disconnected";
            break;
        case NEVPNStatusConnecting:
            status=@"connecting";
            break;
        case NEVPNStatusConnected:
            status=@"connected";
            break;
        case NEVPNStatusReasserting:
            status=@"reconnecting";
            break;
        case NEVPNStatusDisconnecting:
            status=@"disconnecting";
            break;
    }
    return status;
}

-(void)connect:(CDVInvokedUrlCommand *)command
{
    NSString* name = [command.arguments objectAtIndex:0];
    NSString* config = [command.arguments objectAtIndex:1];
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        NETunnelProviderManager *manager = managers.count > 0 ? managers[0] : [[NETunnelProviderManager alloc] init];
        NETunnelProviderProtocol *conf = [[NETunnelProviderProtocol alloc] init];
        NSString *bundleID = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
        conf.providerBundleIdentifier = [bundleID stringByAppendingString:@".PacketTunnel"];//@"com.gongxiaohu.TestVPN.PacketTunnel";
        conf.serverAddress = name; //@"XTun Server";
        conf.providerConfiguration = @{@"name" : name, @"config" : config};
        manager.protocolConfiguration = conf;
        manager.localizedDescription = name;//@"XTun"
        manager.enabled = YES;
        [manager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            [manager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                [manager.connection startVPNTunnelAndReturnError: nil];
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }];
        }];
    }];
}

-(void)disconnect:(CDVInvokedUrlCommand *)command
{
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        NETunnelProviderManager *manager = managers.count > 0 ? managers[0] : [[NETunnelProviderManager alloc] init];
        [manager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            [manager.connection stopVPNTunnel];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    }];
}

-(void)getStatus:(CDVInvokedUrlCommand *)command
{
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        NETunnelProviderManager *manager = managers.count > 0 ? managers[0] : [[NETunnelProviderManager alloc] init];
        [manager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            NSString* status = [self getVPNStatus:manager.connection.status];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:status];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    }];
}

-(void)onStatus:(CDVInvokedUrlCommand *)command
{
    onStatusCallbackId = command.callbackId;
}

@end
