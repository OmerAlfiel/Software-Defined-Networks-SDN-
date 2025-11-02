#!/bin/bash
# Mininet Test: Both Firewall and Load Balancer VNFs

echo "=== Mininet Test: Firewall + Load Balancer VNFs ==="
echo "Testing combined firewall and load balancer functionality"
echo ""

# Cleanup function
cleanup() {
    echo "Performing cleanup..."
    sudo pkill -9 -f ryu-manager 2>/dev/null
    sudo mn -c 2>/dev/null
    sleep 2
}

# Initial cleanup
cleanup

# Start controller with both VNFs
echo "Starting controller with Firewall + Load Balancer VNFs..."
ryu-manager controller/sdn_controller.py controller/firewall_vnf.py controller/load_balancer_vnf.py > /tmp/controller_both.log 2>&1 &
CONTROLLER_PID=$!
sleep 3

# Verify controller
if ! netstat -tln | grep -q ":6653"; then
    echo "❌ ERROR: Controller failed to start!"
    cat /tmp/controller_both.log
    exit 1
fi
echo "✅ Controller ready with both VNFs"

# Run Mininet tests
echo ""
echo "Starting Mininet network..."
echo "Running combined VNF tests..."
echo ""

sudo python3 - <<'PYTHON_SCRIPT'
from mininet.net import Mininet
from mininet.node import RemoteController
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.clean import cleanup

def test_both_vnfs():
    cleanup()
    
    net = Mininet(controller=RemoteController)
    
    info('*** Adding controller\n')
    c0 = net.addController('c0', controller=RemoteController, ip='127.0.0.1', port=6653)
    
    info('*** Adding hosts\n')
    h1 = net.addHost('h1', mac='00:00:00:00:00:01', ip='10.0.0.1/24')
    h2 = net.addHost('h2', mac='00:00:00:00:00:02', ip='10.0.0.2/24')
    h3 = net.addHost('h3', mac='00:00:00:00:00:03', ip='10.0.0.3/24')
    
    info('*** Adding switch\n')
    s1 = net.addSwitch('s1', protocols='OpenFlow13')
    
    info('*** Creating links\n')
    net.addLink(h1, s1)
    net.addLink(h2, s1)
    net.addLink(h3, s1)
    
    info('*** Starting network\n')
    net.start()
    
    # Configure VIP on backend servers for load balancer
    h2.cmd('ip addr add 10.0.0.100/24 dev h2-eth0')
    h3.cmd('ip addr add 10.0.0.100/24 dev h3-eth0')
    
    info('\n*** Combined Test 1: Firewall - h1 -> h2 (SHOULD BE BLOCKED)\n')
    result = h1.cmd('ping -c 3 -W 2 10.0.0.2')
    print(result)
    if '0 received' in result or '100% packet loss' in result:
        print('✅ PASS: Firewall blocked h1->h2')
    else:
        print('❌ FAIL: Firewall did not block h1->h2!')
    
    info('\n*** Combined Test 2: Firewall - h1 -> h3 (SHOULD SUCCEED)\n')
    result = h1.cmd('ping -c 3 10.0.0.3')
    print(result)
    if '0% packet loss' in result:
        print('✅ PASS: h1->h3 traffic allowed')
    else:
        print('❌ FAIL: h1->h3 traffic blocked!')
    
    info('\n*** Combined Test 3: Load Balancer - h1 -> VIP (SHOULD SUCCEED)\n')
    result = h1.cmd('ping -c 10 10.0.0.100')
    print(result)
    if '0% packet loss' in result:
        print('✅ PASS: Load balancer VIP is reachable')
    else:
        print('❌ FAIL: Load balancer VIP not reachable!')
    
    info('\n*** Combined Test 4: h2 -> h1 (SHOULD SUCCEED)\n')
    result = h2.cmd('ping -c 3 10.0.0.1')
    print(result)
    
    info('\n*** Check controller logs for firewall blocks and load balancing\n')
    print('Controller log: /tmp/controller_both.log')
    
    info('\n*** Network is ready. Type "exit" to close.\n')
    CLI(net)
    
    info('*** Stopping network\n')
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    test_both_vnfs()
PYTHON_SCRIPT

# Cleanup
echo ""
cleanup
kill $CONTROLLER_PID 2>/dev/null
wait $CONTROLLER_PID 2>/dev/null

echo ""
echo "=== Test Complete ==="
echo "Controller log saved to: /tmp/controller_both.log"
