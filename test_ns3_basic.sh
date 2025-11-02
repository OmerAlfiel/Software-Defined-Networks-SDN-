#!/bin/bash
# NS-3 Test: Basic L2 Forwarding (No VNFs)

echo "=== NS-3 Test: Basic L2 Forwarding ==="
echo "Testing basic MAC learning switch without VNFs"
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

# Start basic controller (no VNFs)
echo "Starting basic controller (L2 forwarding only)..."
ryu-manager controller/sdn_controller.py > /tmp/controller_basic.log 2>&1 &
CONTROLLER_PID=$!
sleep 3

# Verify controller
if ! netstat -tln | grep -q ":6653"; then
    echo "❌ ERROR: Controller failed to start!"
    exit 1
fi
echo "✅ Controller ready"

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
echo "Running NS-3 Basic Test..."
echo "=========================================="
echo "Expected: All pings should succeed with 0% packet loss"
echo "This validates basic L2 MAC learning and forwarding"
echo ""
cd ~/workspace/bake/source/ns-3.38
./ns3 run "scratch/topology" --enable-sudo

# Display logs BEFORE cleanup
echo ""
echo "=========================================="
echo "Controller Logs (last 30 lines):"
echo "=========================================="
if [ -f /tmp/controller_basic.log ]; then
    tail -30 /tmp/controller_basic.log
    
    # Check for success indicators
    echo ""
    echo "=========================================="
    echo "Test Result Analysis:"
    echo "=========================================="
    if grep -q "Table-miss flow entry installed" /tmp/controller_basic.log; then
        echo "✅ Controller connected to switch successfully"
    fi
    if grep -q "Packet in switch" /tmp/controller_basic.log; then
        echo "✅ Controller receiving packet_in messages"
    fi
    if grep -q "SWITCH CONNECTED" /tmp/controller_basic.log; then
        echo "✅ Switch registered with controller"
    fi
    echo ""
    echo "Expected: MAC learning should show packets from h1, h2, h3"
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
echo "Full controller log: /tmp/controller_basic.log"
