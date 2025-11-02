#!/bin/bash
# NS-3 Test: Load Balancer VNF

echo "=== NS-3 Test: Load Balancer VNF ==="
echo "Testing load balancer with VIP 10.0.0.100"
echo ""

# Cleanup function
cleanup() {
    echo "Performing cleanup..."
    sudo pkill -9 -f ryu-manager 2>/dev/null
    sudo systemctl stop openvswitch-switch 2>/dev/null || true
    sudo pkill -9 ovs-vswitchd 2>/dev/null || true
    sudo pkill -9 ovsdb-server 2>/dev/null || true
    sudo ip link delete ctrl 2>/dev/null || true
    sudo mn -c 2>/dev/null || true
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
    exit 1
fi
echo "✅ Controller ready with Load Balancer VNF"

# Check for unexpected connections
CONNS=$(sudo netstat -tn | grep :6653 | grep ESTABLISHED | wc -l)
if [ $CONNS -gt 0 ]; then
    echo "⚠️  WARNING: Unexpected OVS connection detected!"
    sudo netstat -tnp | grep :6653 | grep ESTABLISHED
    cleanup
    exit 1
fi
echo "✅ No unexpected connections"

# Run NS-3
echo ""
echo "=========================================="
echo "Running NS-3 Load Balancer Test..."
echo "=========================================="
echo "Expected: Traffic to VIP 10.0.0.100 distributed to backend servers"
echo "Load balancer should select h2 (10.0.0.2) or h3 (10.0.0.3)"
echo ""
cd ~/workspace/bake/source/ns-3.38
./ns3 run "scratch/topology --destination=10.0.0.100" --enable-sudo

# Display logs BEFORE cleanup
echo ""
echo "=========================================="
echo "Controller Logs (last 30 lines):"
echo "=========================================="
if [ -f /tmp/controller_loadbalancer.log ]; then
    tail -30 /tmp/controller_loadbalancer.log
    
    # Check for success indicators
    echo ""
    echo "=========================================="
    echo "Test Result Analysis:"
    echo "=========================================="
    if grep -q "VIP 10.0.0.100 configured" /tmp/controller_loadbalancer.log; then
        echo "✅ VIP configured on backend servers"
    fi
    if grep -q "Load Balancer VNF initialized" /tmp/controller_loadbalancer.log; then
        echo "✅ Load balancer VNF initialized"
    fi
    if grep -q "selected server" /tmp/controller_loadbalancer.log; then
        echo "✅ Load balancer actively distributing traffic"
    fi
else
    echo "❌ No controller log file found!"
fi

echo ""
echo "=========================================="
echo "Load Balancer-specific logs:"
echo "=========================================="
if [ -f /tmp/controller_loadbalancer.log ]; then
    grep -i "load.balanc\|selected.server\|VIP" /tmp/controller_loadbalancer.log | tail -20
    echo ""
    echo "Expected: Look for 'Selected server 10.0.0.2' or 'Selected server 10.0.0.3'"
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
echo "Full controller log: /tmp/controller_loadbalancer.log"
echo "Note: Look for 'Selected server' and 'Load balanced' messages"
