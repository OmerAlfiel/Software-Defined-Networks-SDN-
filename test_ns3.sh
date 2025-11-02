#!/bin/bash
# Final Production-Ready NS-3 SDN Testing Script

echo "=== NS-3 SDN Testing Script (Production) ==="
echo "This script ensures reliable NS-3 ↔ Ryu controller communication"
echo ""

# Complete cleanup function
cleanup() {
    echo "Performing complete cleanup..."
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

# Start controller
echo "Starting Ryu controller..."
ryu-manager controller/sdn_controller.py &
CONTROLLER_PID=$!
sleep 3

# Verify controller started
if ! netstat -tln | grep -q ":6653"; then
    echo "❌ ERROR: Controller failed to start on port 6653!"
    exit 1
fi
echo "✅ Controller is listening on port 6653"

# Check for unexpected connections (should be 0)
CONNS=$(sudo netstat -tn | grep :6653 | grep ESTABLISHED | wc -l)
if [ $CONNS -gt 0 ]; then
    echo "⚠️  WARNING: $CONNS unexpected connection(s) detected!"
    sudo netstat -tnp | grep :6653 | grep ESTABLISHED
    echo "Run: sudo systemctl stop openvswitch-switch"
    cleanup
    exit 1
else
    echo "✅ No unexpected connections - ready for NS-3"
fi

# Run NS-3
echo ""
echo "Running NS-3 simulation..."
cd ~/workspace/bake/source/ns-3.38
./ns3 run "scratch/topology" --enable-sudo

# Cleanup
echo ""
cleanup
kill $CONTROLLER_PID 2>/dev/null
wait $CONTROLLER_PID 2>/dev/null

echo ""
echo "=== Test Complete ===" 
