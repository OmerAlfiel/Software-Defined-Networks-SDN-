#!/bin/bash
# Mininet Test: Basic L2 Forwarding (No VNFs)

echo "=== Mininet Test: Basic L2 Forwarding ==="
echo "Testing basic MAC learning switch without VNFs"
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

# Start basic controller (no VNFs)
echo "Starting basic controller (L2 forwarding only)..."
ryu-manager controller/sdn_controller.py > ~/controller_basic.log 2>&1 &
CONTROLLER_PID=$!
sleep 5

# Verify controller
if ! netstat -tln | grep -q ":6653"; then
    echo "❌ ERROR: Controller failed to start!"
    if [ -f ~/controller_basic.log ]; then
        cat ~/controller_basic.log
    fi
    exit 1
fi
echo "✅ Controller ready"

# Run Mininet tests
echo ""
echo "Starting Mininet network..."
echo "Running connectivity tests..."
echo ""

sudo python3 - <<'PYTHON_SCRIPT'
from mininet.net import Mininet
from mininet.node import RemoteController
from mininet.cli import CLI
from mininet.log import setLogLevel, info

def test_basic():
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
    
    info('\n*** Test 1: Ping h1 -> h2\n')
    result_h1_h2 = h1.cmd('ping -c 3 10.0.0.2')
    print(result_h1_h2)
    if '0% packet loss' in result_h1_h2:
        print('✅ PASS: h1->h2 connectivity successful (0% packet loss)')
    else:
        print('❌ FAIL: h1->h2 connectivity failed!')
    
    info('\n*** Test 2: Ping h1 -> h3\n')
    result_h1_h3 = h1.cmd('ping -c 3 10.0.0.3')
    print(result_h1_h3)
    if '0% packet loss' in result_h1_h3:
        print('✅ PASS: h1->h3 connectivity successful (0% packet loss)')
    else:
        print('❌ FAIL: h1->h3 connectivity failed!')
    
    info('\n*** Test 3: Ping all hosts\n')
    result = net.pingAll()
    if result == 0:
        print('✅ PASS: All hosts can communicate (0% packet loss)')
    else:
        print(f'❌ FAIL: Packet loss detected ({result}% dropped)')
    
    info('\n*** Network is ready. Type "exit" to close.\n')
    CLI(net)
    
    info('*** Stopping network\n')
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    test_basic()
PYTHON_SCRIPT

# Display logs BEFORE cleanup
echo ""
echo "=========================================="
echo "Controller Logs (last 30 lines):"
echo "=========================================="
if [ -f ~/controller_basic.log ]; then
    tail -30 ~/controller_basic.log
else
    echo "❌ No controller log file found!"
fi

# Cleanup
echo ""
echo "Performing cleanup..."
kill $CONTROLLER_PID 2>/dev/null
wait $CONTROLLER_PID 2>/dev/null
cleanup

echo ""
echo "=== Test Complete ==="
echo "Full controller log: ~/controller_basic.log"
