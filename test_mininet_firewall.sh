#!/bin/bash
# Mininet Test: Firewall VNF

echo "=== Mininet Test: Firewall VNF ==="
echo "Testing firewall with h1→h2 blocking"
echo ""

# Setup Open vSwitch function
setup_ovs() {
    echo "=========================================="
    echo "Setting up Open vSwitch for Mininet..."
    echo "=========================================="
    
    # Check if OVS is installed
    if ! command -v ovs-vsctl &> /dev/null; then
        echo "⚠️  Open vSwitch not found. Installing..."
        sudo apt-get update
        sudo apt-get install -y openvswitch-switch openvswitch-common
    else
        echo "✅ Open vSwitch is installed"
    fi
    
    # Start Open vSwitch service
    echo "Starting Open vSwitch service..."
    sudo service openvswitch-switch start 2>/dev/null || sudo systemctl start openvswitch-switch 2>/dev/null
    sleep 2
    
    # Verify service is running
    if sudo ovs-vsctl show &> /dev/null; then
        echo "✅ Open vSwitch is running"
        echo ""
    else
        echo "❌ ERROR: Open vSwitch failed to start!"
        echo "Please run: sudo service openvswitch-switch start"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    echo "Performing cleanup..."
    sudo pkill -9 -f ryu-manager 2>/dev/null
    sudo mn -c 2>/dev/null
    sleep 2
}

# Setup OVS before cleanup
setup_ovs

# Initial cleanup
cleanup

# Wait for cleanup to complete fully
sleep 1

# Start controller with firewall VNF
echo "Starting controller with Firewall VNF..."
ryu-manager controller/sdn_controller.py controller/firewall_vnf.py > ~/controller_firewall.log 2>&1 &
CONTROLLER_PID=$!
sleep 5

# Verify controller
if ! netstat -tln | grep -q ":6653"; then
    echo "❌ ERROR: Controller failed to start!"
    if [ -f ~/controller_firewall.log ]; then
        cat ~/controller_firewall.log
    fi
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

def test_firewall():
    # Don't call cleanup() here - it kills the controller!
    # Cleanup was already done by the bash script
    
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
        print('✅ PASS: Firewall successfully blocked h1->h2 (100% packet loss)')
    else:
        print('❌ FAIL: Firewall did not block h1->h2!')
    
    info('\n*** Firewall Test 2: h1 -> h3 (SHOULD SUCCEED)\n')
    result = h1.cmd('ping -c 3 10.0.0.3')
    print(result)
    if '0% packet loss' in result:
        print('✅ PASS: h1->h3 traffic allowed (0% packet loss)')
    else:
        print('❌ FAIL: h1->h3 traffic was incorrectly blocked!')
    
    info('\n*** Firewall Test 3: h2 -> h1 (SHOULD SUCCEED)\n')
    result = h2.cmd('ping -c 3 10.0.0.1')
    print(result)
    if '0% packet loss' in result:
        print('✅ PASS: h2->h1 traffic allowed (firewall is directional)')
    else:
        print('❌ FAIL: h2->h1 traffic was blocked!')
    
    info('\n=== Firewall Test Summary ===\n')
    print('Expected: h1->h2 blocked, h1->h3 allowed, h2->h1 allowed')
    print('Firewall rule: Block all traffic from 10.0.0.1 to 10.0.0.2')
    
    info('\n*** Network is ready. Type "exit" to close.\n')
    CLI(net)
    
    info('*** Stopping network\n')
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    test_firewall()
PYTHON_SCRIPT

# Display logs BEFORE cleanup
echo ""
echo "=========================================="
echo "Controller Logs (last 30 lines):"
echo "=========================================="
if [ -f ~/controller_firewall.log ]; then
    tail -30 ~/controller_firewall.log
else
    echo "❌ No controller log file found!"
fi

echo ""
echo "=========================================="
echo "Firewall-specific logs:"
echo "=========================================="
if [ -f ~/controller_firewall.log ]; then
    grep -i "firewall\|blocked\|block" ~/controller_firewall.log | tail -20
else
    echo "❌ No firewall logs found!"
fi

# Cleanup
echo ""
echo "Performing cleanup..."
kill $CONTROLLER_PID 2>/dev/null
wait $CONTROLLER_PID 2>/dev/null
cleanup

echo ""
echo "=== Test Complete ==="
echo "Full controller log: ~/controller_firewall.log"
echo "Note: Look for PASS/FAIL status and 'blocked' messages"
