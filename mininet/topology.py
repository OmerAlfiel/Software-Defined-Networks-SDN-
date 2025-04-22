#!/usr/bin/env python3
# Mininet topology with 3 hosts and OpenFlow switch

from mininet.net import Mininet
from mininet.node import Controller, RemoteController
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.link import TCLink
from mininet.clean import cleanup

def createNet():
    # Clean up any previous Mininet runs
    cleanup()
    
    # Create a network with a remote controller
    net = Mininet(controller=RemoteController, link=TCLink)
    
    # Add controller
    info('*** Adding controller\n')
    c0 = net.addController('c0', controller=RemoteController, ip='127.0.0.1', port=6653)
    
    # Add three hosts
    info('*** Adding hosts\n')
    h1 = net.addHost('h1', mac='00:00:00:00:00:01', ip='10.0.0.1/24')
    h2 = net.addHost('h2', mac='00:00:00:00:00:02', ip='10.0.0.2/24')
    h3 = net.addHost('h3', mac='00:00:00:00:00:03', ip='10.0.0.3/24')
    
    # Add load balancer virtual IP to h2 and h3 (server side)
    info('*** Configuring virtual IP on backend servers\n')
    h2.cmd('ip addr add 10.0.0.100/24 dev h2-eth0')
    h3.cmd('ip addr add 10.0.0.100/24 dev h3-eth0')
    
    # Add one switch
    info('*** Adding switch\n')
    s1 = net.addSwitch('s1', protocols='OpenFlow13')
    
    # Connect hosts to switch
    info('*** Creating links\n')
    net.addLink(h1, s1, bw=10) # 10 Mbps link
    net.addLink(h2, s1, bw=10)
    net.addLink(h3, s1, bw=10)
    
    # Start network
    info('*** Starting network\n')
    net.start()
    
    # Set up basic connectivity test
    info('*** Setting up connectivity test\n')
    
    # Test firewall: h1 ping to h2 should fail (blocked)
    info('\n*** Testing firewall: h1 -> h2 (should be blocked)\n')
    h1.cmd('ping -c 3 10.0.0.2 > /tmp/ping_h1_h2.log 2>&1')
    
    # Test normal connectivity: h1 ping to h3 should work
    info('*** Testing normal connectivity: h1 -> h3 (should work)\n')
    h1.cmd('ping -c 3 10.0.0.3 > /tmp/ping_h1_h3.log 2>&1')
    
    # Test load balancer: h1 ping to virtual IP should reach either h2 or h3
    info('*** Testing load balancer: h1 -> VIP (10.0.0.100)\n')
    h1.cmd('ping -c 10 10.0.0.100 > /tmp/ping_h1_vip.log 2>&1')
    
    # Run CLI
    info('*** Running CLI\n')
    CLI(net)
    
    # Stop network
    info('*** Stopping network\n')
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    createNet()