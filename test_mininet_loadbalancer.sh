#!/bin/bash
# Mininet Test: Load Balancer VNF

echo "=== Mininet Test: Load Balancer VNF ==="
echo "Testing load balancer with VIP 10.0.0.100"
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

# Start controller with load balancer VNF
echo "Starting controller with Load Balancer VNF..."
ryu-manager controller/sdn_controller.py controller/load_balancer_vnf.py > /tmp/controller_loadbalancer.log 2>&1 &
CONTROLLER_PID=$!
sleep 3

# Verify controller
if ! netstat -tln | grep -q ":6653"; then
    echo "❌ ERROR: Controller failed to start!"
    cat /tmp/controller_loadbalancer.log
    exit 1
fi
echo "✅ Controller ready with Load Balancer VNF"

# Run Mininet tests
echo ""
echo "Starting Mininet network..."
echo "Running load balancer tests..."
echo ""

sudo python3 - <<'PYTHON_SCRIPT'
from mininet.net import Mininet
from mininet.node import RemoteController
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.clean import cleanup

def test_loadbalancer():
    cleanup()
    
    net = Mininet(controller=RemoteController)
    
    info('*** Adding controller\n')
    c0 = net.addController('c0', controller=RemoteController, ip='127.0.0.1', port=6653)
    
    info('*** Adding hosts\n')
    h1 = net.addHost('h1', mac='00:00:00:00:00:01', ip='10.0.0.1/24')
    h2 = net.addHost('h2', mac='00:00:00:00:00:02', ip='10.0.0.2/24')
    h3 = net.addHost('h3', mac='00:00:00:00:00:03', ip='10.0.0.3/24')
    
    info('*** Configuring virtual IP on backend servers\n')
    # Add VIP to h2 and h3 (backend servers)
    
    info('*** Adding switch\n')
    s1 = net.addSwitch('s1', protocols='OpenFlow13')
    
    info('*** Creating links\n')
    net.addLink(h1, s1)
    net.addLink(h2, s1)
    net.addLink(h3, s1)
    
    info('*** Starting network\n')
    net.start()
    
    # Configure VIP on backend servers
    h2.cmd('ip addr add 10.0.0.100/24 dev h2-eth0')
    h3.cmd('ip addr add 10.0.0.100/24 dev h3-eth0')
    
    info('\n*** Load Balancer Test 1: Ping VIP from h1\n')
    result = h1.cmd('ping -c 10 10.0.0.100')
    print(result)
    if '0% packet loss' in result:
        print('✅ PASS: VIP is reachable')
    else:
        print('❌ FAIL: VIP is not reachable!')
    
    info('\n*** Load Balancer Test 2: Direct ping to h2\n')
    result = h1.cmd('ping -c 3 10.0.0.2')
    print(result)
    
    info('\n*** Load Balancer Test 3: Direct ping to h3\n')
    result = h1.cmd('ping -c 3 10.0.0.3')
    print(result)
    
    info('\n*** Check controller logs to see load balancing distribution\n')
    print('Note: Controller log at /tmp/controller_loadbalancer.log')
    
    info('\n*** Network is ready. Type "exit" to close.\n')
    CLI(net)
    
    info('*** Stopping network\n')
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    test_loadbalancer()
PYTHON_SCRIPT

# Cleanup
echo ""
cleanup
kill $CONTROLLER_PID 2>/dev/null
wait $CONTROLLER_PID 2>/dev/null

echo ""
echo "=== Test Complete ==="
echo "Controller log saved to: /tmp/controller_loadbalancer.log"
