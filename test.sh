#!/bin/bash

# Test script for SDN Project
echo "===== SDN Project Test Script ====="

# Step 1: Terminal 1 - Setup TAP and start Ryu controller
echo "STEP 1: Start the setup script in Terminal 1:"
echo "chmod +x share.txt"
echo "./share.txt"
echo ""

# Step 2: Terminal 2 - Confirm controller is running and listening
echo "STEP 2: Check controller is running (Terminal 2):"
echo "sudo lsof -i :6653"
echo "Expected output: ryu-manager process listening on port 6653"
echo ""

# Step 3: Terminal 3 - Run NS-3 simulation
echo "STEP 3: Run NS-3 simulation (Terminal 3):"
echo "cd ~/workspace/bake/source/ns-3.38"
echo "NS_LOG=\"TapBridge=level_all|prefix_func|prefix_time:OFSwitch13Device=level_all\" ./ns3 run scratch/topology --enable-sudo"
echo ""

# Step 4: Check results
echo "STEP 4: Expected results:"
echo "- Controller terminal should show: 🟢 SWITCH CONNECTED!"
echo "- Firewall should block pings from h1 to h2"
echo "- Pings from h1 to h3 should work"
echo "- Load balancer should distribute traffic if pinging the VIP (10.0.0.100)"
echo ""

echo "===== Troubleshooting Tips ====="
echo "1. If NS-3 can't find ctrl interface: Verify TAP interface was created with 'ip a'"
echo "2. If connection not established: Check 'sudo tcpdump -i ctrl -n port 6653'"
echo "3. If controller doesn't receive anything: Verify controller IP matches topology.cc"
echo "4. If still not working: Try rebooting the VM"
echo "===== End of Test Script ====="