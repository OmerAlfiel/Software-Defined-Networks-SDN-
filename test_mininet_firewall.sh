#!/bin/bash
# Mininet Test: Firewall VNF

echo "=== Mininet Test: Firewall VNF ==="
echo "Testing firewall rules (h1→h2 blocked, h1→h3 allowed)"
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

# Start controller with firewall VNF
echo "Starting controller with Firewall VNF..."
ryu-manager controller/sdn_controller.py controller/firewall_vnf.py > /tmp/controller_firewall.log 2>&1 &
CONTROLLER_PID=$!
sleep 3

# Verify controller
if ! netstat -tln | grep -q ":6653"; then
    echo "❌ ERROR: Controller failed to start!"
    cat /tmp/controller_firewall.log
    exit 1
fi
echo "✅ Controller ready with Firewall VNF"

# Run Mininet tests
echo ""
echo "Starting Mininet network..."
echo "Running firewall tests..."
echo ""

sudo python3 - <<'PYTHON_SCRIPT'
from mininet.net import Mininet
from mininet.node import RemoteController
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.clean import cleanup

def test_firewall():
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
    
    info('\n*** Firewall Test 1: h1 -> h2 (SHOULD BE BLOCKED)\n')
    result = h1.cmd('ping -c 3 -W 2 10.0.0.2')
    print(result)
    if '0 received' in result or '100% packet loss' in result:
        print('✅ PASS: h1->h2 traffic blocked by firewall')
    else:
        print('❌ FAIL: h1->h2 traffic was not blocked!')
    
    info('\n*** Firewall Test 2: h1 -> h3 (SHOULD SUCCEED)\n')
    result = h1.cmd('ping -c 3 10.0.0.3')
    print(result)
    if '0% packet loss' in result:
        print('✅ PASS: h1->h3 traffic allowed')
    else:
        print('❌ FAIL: h1->h3 traffic was blocked!')
    
    info('\n*** Firewall Test 3: h2 -> h1 (SHOULD SUCCEED)\n')
    result = h2.cmd('ping -c 3 10.0.0.1')
    print(result)
    if '0% packet loss' in result:
        print('✅ PASS: h2->h1 traffic allowed')
    else:
        print('❌ FAIL: h2->h1 traffic was blocked!')
    
    info('\n*** Network is ready. Type "exit" to close.\n')
    CLI(net)
    
    info('*** Stopping network\n')
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    test_firewall()
PYTHON_SCRIPT

# Cleanup
echo ""
cleanup
kill $CONTROLLER_PID 2>/dev/null
wait $CONTROLLER_PID 2>/dev/null

echo ""
echo "=== Test Complete ==="
echo "Controller log saved to: /tmp/controller_firewall.log"
