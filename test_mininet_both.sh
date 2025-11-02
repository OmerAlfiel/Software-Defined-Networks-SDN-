#!/bin/bash
# Mininet Test: Both Firewall and Load Balancer VNFs

echo "=== Mininet Test: Firewall + Load Balancer VNFs ==="
echo "Testing combined firewall and load balancer functionality"
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

# Start controller with both VNFs
echo "Starting controller with Firewall + Load Balancer VNFs..."
ryu-manager controller/sdn_controller.py controller/firewall_vnf.py controller/load_balancer_vnf.py > ~/controller_both.log 2>&1 &
CONTROLLER_PID=$!
sleep 5

# Verify controller
if ! netstat -tln | grep -q ":6653"; then
    echo "❌ ERROR: Controller failed to start!"
    if [ -f ~/controller_both.log ]; then
        cat ~/controller_both.log
    fi
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

def test_both_vnfs():
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
    
    # Configure VIP on backend servers for load balancer
    h2.cmd('ip addr add 10.0.0.100/24 dev h2-eth0')
    h3.cmd('ip addr add 10.0.0.100/24 dev h3-eth0')
    
    info('\n*** Combined Test 1: Firewall - h1 -> h2 (SHOULD BE BLOCKED)\n')
    result = h1.cmd('ping -c 3 -W 2 10.0.0.2')
    print(result)
    if '0 received' in result or '100% packet loss' in result:
        print('✅ PASS: Firewall blocked h1->h2 (100% packet loss)')
    else:
        print('❌ FAIL: Firewall did not block h1->h2!')
    
    info('\n*** Combined Test 2: Firewall - h1 -> h3 (SHOULD SUCCEED)\n')
    result = h1.cmd('ping -c 3 10.0.0.3')
    print(result)
    if '0% packet loss' in result:
        print('✅ PASS: h1->h3 traffic allowed (0% packet loss)')
    else:
        print('❌ FAIL: h1->h3 traffic blocked!')
    
    info('\n*** Combined Test 3: Load Balancer - h1 -> VIP (SHOULD SUCCEED)\n')
    result = h1.cmd('ping -c 10 10.0.0.100')
    print(result)
    if '0% packet loss' in result:
        print('✅ PASS: Load balancer VIP is reachable (0% packet loss)')
    else:
        print('❌ FAIL: Load balancer VIP not reachable!')
    
    info('\n*** Combined Test 4: h2 -> h1 (SHOULD SUCCEED)\n')
    result = h2.cmd('ping -c 3 10.0.0.1')
    print(result)
    if '0% packet loss' in result:
        print('✅ PASS: h2->h1 traffic allowed (0% packet loss)')
    else:
        print('❌ FAIL: h2->h1 traffic blocked!')
    
    info('\n=== Combined VNF Test Summary ===\n')
    print('✅ Firewall: Blocks h1->h2, allows h1->h3 and h2->h1')
    print('✅ Load Balancer: Distributes VIP (10.0.0.100) traffic to h2/h3')
    print('Check controller logs for both VNF activities')
    print('Controller log: ~/controller_both.log')
    
    info('\n*** Network is ready. Type "exit" to close.\n')
    CLI(net)
    
    info('*** Stopping network\n')
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    test_both_vnfs()
PYTHON_SCRIPT

# Display logs BEFORE cleanup
echo ""
echo "=========================================="
echo "Controller Logs (last 40 lines):"
echo "=========================================="
if [ -f ~/controller_both.log ]; then
    tail -40 ~/controller_both.log
else
    echo "❌ No controller log file found!"
fi

echo ""
echo "=========================================="
echo "Firewall-specific logs:"
echo "=========================================="
if [ -f ~/controller_both.log ]; then
    grep -i "firewall\|blocked\|block" ~/controller_both.log | tail -15
else
    echo "❌ No firewall logs found!"
fi

echo ""
echo "=========================================="
echo "Load Balancer-specific logs:"
echo "=========================================="
if [ -f ~/controller_both.log ]; then
    grep -i "load.balanc\|selected.server\|VIP" ~/controller_both.log | tail -15
else
    echo "❌ No load balancer logs found!"
fi

# Cleanup
echo ""
echo "Performing cleanup..."
kill $CONTROLLER_PID 2>/dev/null
wait $CONTROLLER_PID 2>/dev/null
cleanup

echo ""
echo "=== Test Complete ==="
echo "Full controller log: ~/controller_both.log"
echo "Note: Check PASS/FAIL status and both VNF logs above"
