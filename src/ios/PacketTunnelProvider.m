#include <net/if.h>
#import "PacketTunnelProvider.h"

@interface PacketTunnelProvider ()
@property ColaCola *cola;
@property NWPath *lastPath;
@property BOOL started;
@end

@implementation PacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
    NSDictionary<NSString *,id> *configuration=((NETunnelProviderProtocol *)self.protocolConfiguration).providerConfiguration;
    NSString *config = [configuration objectForKey:@"config"];
    self.cola = [[ColaCola alloc] init:self config:config];
    [self.cola memoryGC:10 gcSec:30];
//    [self.cola printMemory:2];
    if(!self.started){
        [self addObserver:self forKeyPath:@"defaultPath" options:NSKeyValueObservingOptionInitial context:nil];
    }
    __weak PacketTunnelProvider *weakself = self;
    [self setTunnelNetwork:^(NSError * _Nullable error) {
        completionHandler(error);
        if(error == nil){
            NSNumber *fd = (NSNumber*)[weakself.packetFlow valueForKeyPath:@"socket.fileDescriptor"];
            [weakself.cola createTun:fd.intValue];
            [weakself.cola start:weakself];
        }
    }];
    self.started=true;
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    [self.cola stop];
    completionHandler();
}

- (void)control:(long)fd{
    int index = self.defaultPath.isExpensive?if_nametoindex("pdp_ip0"):if_nametoindex("en0");
    int status = setsockopt((int)fd, IPPROTO_IP, IP_BOUND_IF, &index, sizeof(index));
    if (status == -1) {
        NSLog(@"setsockopt IP_BOUND_IF error, %s", strerror(errno));
    }
}

- (void)onClose{
    [self cancelTunnelWithError:nil];
}

-(void)setTunnelNetwork:(nullable void (^)( NSError * __nullable error))completionHandler{
    NSArray<NSString *> *arr = [self.cola.cidr componentsSeparatedByString:@"/"];
    NEPacketTunnelNetworkSettings *networkSettings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:arr[0]];//remote
    networkSettings.DNSSettings = [[NEDNSSettings alloc]initWithServers:@[arr[0]]];//dns
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc]initWithAddresses:@[self.cola.clientIP] subnetMasks:@[[self prefixToMask:arr[1].intValue]]];
    ipv4Settings.includedRoutes = @[[NEIPv4Route defaultRoute]];
    if(self.cola.mode>1){
        NSString *routes;
        if(self.cola.smart==1){
            if(self.cola.mode==2){
                routes = [self.cola generateCIDRs:@"1/16" reverse:false];
            }else if(self.cola.mode==3){
                routes = [self.cola generateCIDRs:@"0,1/16" reverse:true];
            }
        }
        if(routes!=nil){
            NSArray<NSString *> *cidrs = [routes componentsSeparatedByString:@"\n"];
            NSMutableArray<NEIPv4Route *> *routes = [[NSMutableArray alloc] initWithCapacity:[cidrs count]];
            for(NSString *cidr in cidrs){
                NSArray<NSString *> *pair = [cidr componentsSeparatedByString:@"/"];
                //NSLog(@"%@",pair);
                [routes addObject:[[NEIPv4Route alloc] initWithDestinationAddress:pair[0] subnetMask:[self prefixToMask:pair[1].intValue]]];
            }
            ipv4Settings.excludedRoutes = routes;
        }
    }
    networkSettings.IPv4Settings = ipv4Settings;
    
    networkSettings.MTU = [NSNumber numberWithInt:(int)self.cola.mtu];
    //NSLog(@"%@",networkSettings.MTU);
    [self setTunnelNetworkSettings:networkSettings completionHandler:completionHandler];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if([keyPath isEqualToString:@"defaultPath"]){
        //NSLog(@"%@",self.defaultPath);
        if(self.defaultPath.status == NWPathStatusSatisfied && self.defaultPath!=nil){
            //NSLog(@"%@",self.defaultPath);
            if(self.lastPath == NULL){
                self.lastPath = self.defaultPath;
            } else if(self.lastPath!=self.defaultPath){
                //NSLog(@"received network change notifcation");
                [self.cola reset];
                self.lastPath = self.defaultPath;
            }
        }
    }
}

-(NSString *)prefixToMask:(int) prefix{
    uint8_t m[4];
    int n = prefix;
    for(int i=0;i<4;i++){
        if(n>=8){
            m[i]=0xff;
            n-=8;
            continue;
        }
        m[i] = ~((uint8_t)0xff>>n);
        n = 0;
    }
    NSString *subnetMask = [NSString stringWithFormat:@"%d.%d.%d.%d",m[0],m[1],m[2],m[3]];
    return subnetMask;
}
@end
