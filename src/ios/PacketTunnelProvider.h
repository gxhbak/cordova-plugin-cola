#import <NetworkExtension/NetworkExtension.h>
@import Cola;

@interface PacketTunnelProvider : NEPacketTunnelProvider <ColaProtector, ColaCloser>

@end
