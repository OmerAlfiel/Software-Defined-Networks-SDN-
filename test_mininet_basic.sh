#!/bin/bash
# Mininet Test: Basic L2 Forwarding (No VNFs)

echo "=== Mininet Test: Basic L2 Forwarding ==="
echo "Testing basic MAC learning switch without VNFs"
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

# Start basic controller (no VNFs)
echo "Starting basic controller (L2 forwarding only)..."
ryu-manager controller/sdn_controller.py > /tmp/controller_basic.log 2>&1 &
CONTROLLER_PID=$!
sleep 3

# Verify controller
if ! netstat -tln | grep -q ":6653"; then
    echo "❌ ERROR: Controller failed to start!"
    cat /tmp/controller_basic.log
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
from mininet.clean import cleanup

def test_basic():
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
    
    info('\n*** Test 1: Ping h1 -> h2\n')
    result_h1_h2 = h1.cmd('ping -c 3 10.0.0.2')
    print(result_h1_h2)
    
    info('\n*** Test 2: Ping h1 -> h3\n')
    result_h1_h3 = h1.cmd('ping -c 3 10.0.0.3')
    print(result_h1_h3)
    
    info('\n*** Test 3: Ping all hosts\n')
    net.pingAll()
    
    info('\n*** Network is ready. Type "exit" to close.\n')
    CLI(net)
    
    info('*** Stopping network\n')
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    test_basic()
PYTHON_SCRIPT

# Cleanup
echo ""
cleanup
kill $CONTROLLER_PID 2>/dev/null
wait $CONTROLLER_PID 2>/dev/null

echo ""
echo "=== Test Complete ==="
echo "Controller log saved to: /tmp/controller_basic.log"
