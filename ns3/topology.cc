#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/csma-module.h"
#include "ns3/internet-module.h"
#include "ns3/internet-apps-module.h"
#include "ns3/ofswitch13-module.h"
#include "ns3/tap-bridge-module.h"

using namespace ns3;

int
main (int argc, char *argv[])
{
    // Enable checksum computations (required by OFSwitch13 module)
    GlobalValue::Bind("ChecksumEnabled", BooleanValue(true));
    
    // Use real-time simulation for external controller
    GlobalValue::Bind("SimulatorImplementationType", StringValue("ns3::RealtimeSimulatorImpl"));

    // 1) Create nodes: 3 hosts, 1 switch, 1 "controller" node
    NodeContainer hosts;    hosts.Create (3);
    NodeContainer switches; switches.Create (1);
    Ptr<Node> ctrlNode = CreateObject<Node> ();

    // 2) Set up CSMA channel for host↔switch links
    CsmaHelper csma;
    csma.SetChannelAttribute ("DataRate", DataRateValue (DataRate ("100Mbps")));
    csma.SetChannelAttribute ("Delay", TimeValue (MilliSeconds (2)));

    // 3) Install devices: track host‑side vs switch‑side ports
    NetDeviceContainer hostDevices, switchPorts;
    for (uint32_t i = 0; i < hosts.GetN (); ++i)
    {
        NodeContainer pair (hosts.Get (i), switches.Get (0));
        NetDeviceContainer link = csma.Install (pair);
        hostDevices.Add (link.Get (0));  // host port
        switchPorts.Add (link.Get (1));  // switch port
    }

    // 4) Give each host an IP address
    InternetStackHelper internet;
    internet.Install (hosts);
    Ipv4AddressHelper ipv4;
    ipv4.SetBase ("10.0.0.0", "255.255.255.0");
    ipv4.Assign (hostDevices);

    // 5) Configure the OFSwitch13 helper for an external controller
    Ptr<OFSwitch13ExternalHelper> of13 = CreateObject<OFSwitch13ExternalHelper> ();
    
    // a) Install the switch datapath with its ports
    of13->InstallSwitch (switches.Get (0), switchPorts);
    
    // b) Install the external controller
    Ptr<NetDevice> ctrlDev = of13->InstallExternalController (ctrlNode);
    
    // c) Set up TapBridge to connect controller
    TapBridgeHelper tap;
    tap.SetAttribute ("Mode", StringValue ("ConfigureLocal"));
    tap.SetAttribute ("DeviceName", StringValue ("ctrl"));
    tap.SetAttribute ("Gateway", Ipv4AddressValue ("10.100.0.1"));        
    tap.SetAttribute ("Netmask", Ipv4MaskValue ("255.255.255.0"));       
    tap.Install (ctrlNode, ctrlDev);
    
    // d) Create OpenFlow channels
    of13->CreateOpenFlowChannels ();

    // 6) Turn on OFSwitch13 logging
    LogComponentEnable ("OFSwitch13Helper", LOG_LEVEL_INFO);
    LogComponentEnable ("OFSwitch13Device", LOG_LEVEL_INFO);
    LogComponentEnable ("OFSwitch13Port", LOG_LEVEL_INFO);
    LogComponentEnable ("OFSwitch13SocketHandler", LOG_LEVEL_ALL);
    LogComponentEnable ("TapBridge", LOG_LEVEL_INFO);

    // Add ping application between hosts (FIXED: Removed invalid Verbose attribute)
    PingHelper ping (Ipv4Address ("10.0.0.2")); 
    ping.SetAttribute ("Count", UintegerValue (5));                      
    ApplicationContainer apps = ping.Install (hosts.Get (0));
    apps.Start (Seconds (2.0)); 
    apps.Stop (Seconds (8.0));   

    // 7) Run for 10 seconds
    Simulator::Stop (Seconds (10.0));
    
    std::cout << "=== Starting NS-3 SDN Simulation ===" << std::endl;
    std::cout << "Controller should connect to: 127.0.0.1:6653" << std::endl;
    std::cout << "TAP interface: ctrl (10.100.0.1/24)" << std::endl;
    
    Simulator::Run ();
    Simulator::Destroy ();
    
    std::cout << "=== Simulation Complete ===" << std::endl;
    return 0;
}