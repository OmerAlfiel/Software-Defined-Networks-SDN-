#!/bin/bash
# NS-3 Test: Firewall VNF

echo "=== NS-3 Test: Firewall VNF ==="
echo "Testing firewall rules (h1→h2 should be blocked)"
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

# Start controller with firewall VNF
echo "Starting controller with Firewall VNF..."
ryu-manager controller/sdn_controller.py controller/firewall_vnf.py &
CONTROLLER_PID=$!
sleep 3

# Verify controller
if ! netstat -tln | grep -q ":6653"; then
    echo "❌ ERROR: Controller failed to start!"
    exit 1
fi
echo "✅ Controller ready with Firewall VNF"

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
echo "Running NS-3 simulation..."
echo "Expected: h1→h2 blocked by firewall (ping may fail or succeed to other hosts)"
echo ""
cd ~/workspace/bake/source/ns-3.38
./ns3 run "scratch/topology" --enable-sudo

# Cleanup
echo ""
cleanup
kill $CONTROLLER_PID 2>/dev/null
wait $CONTROLLER_PID 2>/dev/null

echo ""
echo "=== Test Complete ==="
echo "Note: Check controller logs to verify firewall rules were applied"
