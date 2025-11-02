#!/bin/bash
# NS-3 Test: Both Firewall and Load Balancer VNFs

echo "=== NS-3 Test: Firewall + Load Balancer VNFs ==="
echo "Testing combined firewall and load balancer functionality"
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

# Start controller with both VNFs
echo "Starting controller with Firewall + Load Balancer VNFs..."
ryu-manager controller/firewall_vnf.py controller/load_balancer_vnf.py > /tmp/controller_both.log 2>&1 &
CONTROLLER_PID=$!
sleep 3

# Verify controller
if ! netstat -tln | grep -q ":6653"; then
    echo "❌ ERROR: Controller failed to start!"
    exit 1
fi
echo "✅ Controller ready with both VNFs"

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
echo "Running NS-3 Combined VNF Test..."
echo "=========================================="
echo "Expected outcomes:"
echo "  1. Firewall blocks direct h1→h2 traffic"
echo "  2. Load balancer distributes VIP traffic to h2 or h3"
echo "  3. VIP (10.0.0.100) should be reachable with 0% packet loss"
echo ""
cd ~/workspace/bake/source/ns-3.38
./ns3 run "scratch/topology --destination=10.0.0.100" --enable-sudo

# Display logs BEFORE cleanup
echo ""
echo "=========================================="
echo "Controller Logs (last 40 lines):"
echo "=========================================="
if [ -f /tmp/controller_both.log ]; then
    tail -40 /tmp/controller_both.log
    
    # Check for success indicators
    echo ""
    echo "=========================================="
    echo "Test Result Analysis:"
    echo "=========================================="
    if grep -q "Firewall VNF initialized" /tmp/controller_both.log; then
        echo "✅ Firewall VNF loaded successfully"
    fi
    if grep -q "Load Balancer VNF initialized" /tmp/controller_both.log; then
        echo "✅ Load Balancer VNF loaded successfully"
    fi
    if grep -q "Installed firewall rule.*Block 10.0.0.1" /tmp/controller_both.log; then
        echo "✅ Firewall blocking rule installed"
    fi
    if grep -q "selected server" /tmp/controller_both.log; then
        echo "✅ Load balancer distributing traffic"
    fi
else
    echo "❌ No controller log file found!"
fi

echo ""
echo "=========================================="
echo "Firewall-specific logs:"
echo "=========================================="
if [ -f /tmp/controller_both.log ]; then
    grep -i "firewall\|blocked\|block" /tmp/controller_both.log | tail -15
    echo ""
    echo "Expected: Firewall should block 10.0.0.1 → 10.0.0.2"
else
    echo "❌ No firewall logs found!"
fi

echo ""
echo "=========================================="
echo "Load Balancer-specific logs:"
echo "=========================================="
if [ -f /tmp/controller_both.log ]; then
    grep -i "load.balanc\|selected.server\|VIP" /tmp/controller_both.log | tail -15
    echo ""
    echo "Expected: Load balancer should select h2 or h3 for VIP traffic"
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
echo "Full controller log: /tmp/controller_both.log"
echo "Note: Check logs for both firewall blocks and load balancing"
