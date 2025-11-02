#!/bin/bash
# Master Test Script - Run All SDN Tests

echo "=========================================="
echo "      SDN Project - Master Test Suite"
echo "=========================================="
echo ""
echo "This script will run all test scenarios:"
echo "  NS-3 Tests: Basic, Firewall, Load Balancer, Both VNFs"
echo "  Mininet Tests: Basic, Firewall, Load Balancer, Both VNFs"
echo ""

# Make all scripts executable
chmod +x test_ns3_basic.sh
chmod +x test_ns3_firewall.sh
chmod +x test_ns3_loadbalancer.sh
chmod +x test_ns3_both.sh
chmod +x test_mininet_basic.sh
chmod +x test_mininet_firewall.sh
chmod +x test_mininet_loadbalancer.sh
chmod +x test_mininet_both.sh

# Menu function
show_menu() {
    echo ""
    echo "=========================================="
    echo "Select Test to Run:"
    echo "=========================================="
    echo "NS-3 Tests:"
    echo "  1) Basic L2 Forwarding (No VNFs)"
    echo "  2) Firewall VNF"
    echo "  3) Load Balancer VNF"
    echo "  4) Both VNFs (Firewall + Load Balancer)"
    echo ""
    echo "Mininet Tests:"
    echo "  5) Basic L2 Forwarding (No VNFs)"
    echo "  6) Firewall VNF"
    echo "  7) Load Balancer VNF"
    echo "  8) Both VNFs (Firewall + Load Balancer)"
    echo ""
    echo "Batch Tests:"
    echo "  9) Run all NS-3 tests"
    echo "  10) Run all Mininet tests"
    echo "  11) Run ALL tests (NS-3 + Mininet)"
    echo ""
    echo "  0) Exit"
    echo "=========================================="
    echo -n "Enter choice [0-11]: "
}

# Main loop
while true; do
    show_menu
    read choice
    
    case $choice in
        1)
            echo ""
            echo "Running NS-3 Basic Test..."
            ./test_ns3_basic.sh
            ;;
        2)
            echo ""
            echo "Running NS-3 Firewall Test..."
            ./test_ns3_firewall.sh
            ;;
        3)
            echo ""
            echo "Running NS-3 Load Balancer Test..."
            ./test_ns3_loadbalancer.sh
            ;;
        4)
            echo ""
            echo "Running NS-3 Both VNFs Test..."
            ./test_ns3_both.sh
            ;;
        5)
            echo ""
            echo "Running Mininet Basic Test..."
            ./test_mininet_basic.sh
            ;;
        6)
            echo ""
            echo "Running Mininet Firewall Test..."
            ./test_mininet_firewall.sh
            ;;
        7)
            echo ""
            echo "Running Mininet Load Balancer Test..."
            ./test_mininet_loadbalancer.sh
            ;;
        8)
            echo ""
            echo "Running Mininet Both VNFs Test..."
            ./test_mininet_both.sh
            ;;
        9)
            echo ""
            echo "Running ALL NS-3 Tests..."
            ./test_ns3_basic.sh
            echo ""; echo "Press Enter to continue to next test..."; read
            ./test_ns3_firewall.sh
            echo ""; echo "Press Enter to continue to next test..."; read
            ./test_ns3_loadbalancer.sh
            echo ""; echo "Press Enter to continue to next test..."; read
            ./test_ns3_both.sh
            echo ""
            echo "All NS-3 tests completed!"
            ;;
        10)
            echo ""
            echo "Running ALL Mininet Tests..."
            ./test_mininet_basic.sh
            echo ""; echo "Press Enter to continue to next test..."; read
            ./test_mininet_firewall.sh
            echo ""; echo "Press Enter to continue to next test..."; read
            ./test_mininet_loadbalancer.sh
            echo ""; echo "Press Enter to continue to next test..."; read
            ./test_mininet_both.sh
            echo ""
            echo "All Mininet tests completed!"
            ;;
        11)
            echo ""
            echo "Running ALL Tests (NS-3 + Mininet)..."
            echo "This will take some time..."
            ./test_ns3_basic.sh
            echo ""; echo "Press Enter to continue..."; read
            ./test_ns3_firewall.sh
            echo ""; echo "Press Enter to continue..."; read
            ./test_ns3_loadbalancer.sh
            echo ""; echo "Press Enter to continue..."; read
            ./test_ns3_both.sh
            echo ""; echo "Press Enter to continue..."; read
            ./test_mininet_basic.sh
            echo ""; echo "Press Enter to continue..."; read
            ./test_mininet_firewall.sh
            echo ""; echo "Press Enter to continue..."; read
            ./test_mininet_loadbalancer.sh
            echo ""; echo "Press Enter to continue..."; read
            ./test_mininet_both.sh
            echo ""
            echo "=========================================="
            echo "All tests completed!"
            echo "=========================================="
            ;;
        0)
            echo ""
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo ""
            echo "Invalid choice. Please enter 0-11."
            ;;
    esac
    
    echo ""
    echo "Press Enter to return to menu..."
    read
done
