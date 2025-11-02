# SDN Project with OpenFlow and Network Function Virtualization

## 🚀 Quick Start - Automated Testing (NEW!)

**We now have comprehensive automated test scripts for all scenarios!**

```bash
# Make scripts executable (first time only)
chmod +x test_*.sh run_tests.sh

# Run interactive menu
./run_tests.sh
```

**CRITICAL for NS-3 tests:** Stop Open vSwitch daemon before running:

```bash
sudo systemctl stop openvswitch-switch
sudo pkill -9 ovs-vswitchd
```

📚 **See our testing guides:**

- [TESTING_QUICK_REFERENCE.md](TESTING_QUICK_REFERENCE.md) - Quick reference for all tests
- [TEST_SCRIPTS_SUMMARY.md](TEST_SCRIPTS_SUMMARY.md) - Summary of what was created
- [SDN_Implementation_Guide.txt](SDN_Implementation_Guide.txt) - Complete implementation guide with TRACK 10: AUTOMATED TEST SCRIPTS

### Available Test Scripts

**NS-3 Tests (Simulation):**

- `test_ns3_basic.sh` - Basic L2 forwarding
- `test_ns3_firewall.sh` - Firewall VNF
- `test_ns3_loadbalancer.sh` - Load Balancer VNF
- `test_ns3_both.sh` - Both VNFs combined

**Mininet Tests (Emulation):**

- `test_mininet_basic.sh` - Basic L2 forwarding
- `test_mininet_firewall.sh` - Firewall VNF with PASS/FAIL validation
- `test_mininet_loadbalancer.sh` - Load Balancer VNF
- `test_mininet_both.sh` - Both VNFs with comprehensive validation

**Master Script:**

- `run_tests.sh` - Interactive menu to run any or all tests

---

## Overview

This project implements a **Software-Defined Network (SDN)** with **Network Function Virtualization (NFV)** using **NS-3** simulation and the **Ryu controller**. It demonstrates the SDN paradigm by separating the control plane from the data plane and virtualizing network functions such as firewall and load balancer.

---

## Objectives

- Create an OpenFlow-enabled network topology using NS-3
- Implement a Ryu-based SDN controller with basic L2 forwarding
- Develop a **firewall VNF** to control traffic between nodes
- Develop a **load balancer VNF** to distribute traffic
- Establish communication between NS-3 and the Ryu controller via TAP interface

---

## Architecture

### Components

- **NS-3 Simulation Environment**: Virtual network with 3 hosts and one OpenFlow switch
- **OFSwitch13 Module**: Enables OpenFlow 1.3 in NS-3
- **TAP Bridge**: Links NS-3 simulation to the host OS
- **Ryu Controller**: External SDN controller with:
  - L2 Forwarding
  - Firewall VNF
  - Load Balancer VNF

### Communication Flow

1. NS-3 simulates a network topology
2. An OpenFlow switch connects to the Ryu controller via a TAP interface
3. NS-3 generates traffic, sending OpenFlow messages to the controller
4. Controller processes messages and installs flow rules
5. Firewall and load balancer VNFs apply filtering and distribution logic

### SDN Architecture Explained

Our implementation follows the classic SDN architecture with three distinct layers:

- **Data Plane**: Represented by the NS-3 simulated OpenFlow switch, responsible only for packet forwarding based on flow rules.
- **Control Plane**: Implemented by the Ryu controller, which makes all forwarding decisions and populates the switch's flow tables.
- **Application Plane**: Consists of our VNF applications (firewall and load balancer) that implement network policies.

This separation enables centralized network control, programmability, and the ability to dynamically change network behavior without modifying physical infrastructure.

### NFV Implementation Details

Network Function Virtualization (NFV) decouples network functions from dedicated hardware appliances. In our implementation:

- Network functions (firewall, load balancer) are implemented as software modules in the controller
- These functions operate on traffic flows rather than requiring dedicated hardware
- The VNFs can be easily modified, updated, or replaced without changing the underlying infrastructure
- Multiple VNFs can be chained together to create more complex service chains

---

## Setup Procedure

### Step 1: Install and Build NS-3 with OpenFlow Support

```bash
sudo apt update
sudo apt install -y build-essential g++ python3 python3-pip git mercurial cmake libxml2-dev libboost-all-dev

mkdir -p ~/workspace && cd ~/workspace
git clone https://gitlab.com/nsnam/bake.git && cd bake

./bake.py configure -e ns-allinone-3.38
./bake.py show
./bake.py download
./bake.py build

cd ../source/ns-3.38
./ns3 configure --enable-examples --enable-modules=ofswitch13,tap-bridge,csma,internet,internet-apps,applications
./ns3 build
```

### Step 2: Set Up Ryu Controller

```bash
# Option 1: System-wide installation
sudo apt update
sudo apt install python3-ryu

# Option 2: Using pip
pip install ryu
```

### Step 3: NS-3 Network Topology

- 3 host nodes: `10.0.0.1`, `10.0.0.2`, `10.0.0.3`
- 1 OpenFlow switch
- TAP interface named `ctrl`
- CSMA links (100Mbps)
- Pinging apps for test traffic

#### Topology Implementation Details

The topology is implemented in C++ using NS-3's object model. Key aspects:

- **Node Creation**: We create three host nodes, one switch node, and a controller node
- **Channel Configuration**: The CSMA channel simulates an Ethernet-like network with configurable data rate and delay
- **IP Addressing**: Each host gets an IPv4 address in the 10.0.0.0/24 subnet
- **TAP Bridge**: Creates a virtual network interface on the host system that NS-3 can communicate with
- **OpenFlow Integration**: The switch is configured to use OpenFlow 1.3 protocol and connect to the external controller

The NS-3 simulation initializes the topology, establishes connections, and then generates test traffic using ping applications. The OFSwitch13 module creates OpenFlow channels between the switch and controller, allowing for the exchange of OpenFlow messages.

### Step 4: Ryu Controller Modules

#### Basic SDN Controller (`sdn_controller.py`)

- MAC learning and L2 forwarding
- Installs flow rules for known hosts

#### Firewall VNF (`firewall_vnf.py`)

- Blocks specific MAC/TCP/UDP traffic
- Stateful filtering (connection tracking)
- Example rules:

```python
self.firewall_rules = [
  {'name': 'h1→h2', 'src_mac': '00:00:00:00:00:01', 'dst_mac': '00:00:00:00:00:02', 'action': 'block'},
  {'name': 'http→h3', 'dst_mac': '00:00:00:00:00:03', 'tcp_dst_port': 80, 'action': 'block'},
  {'name': 'dns-h1→h3', 'src_mac': '00:00:00:00:00:01', 'dst_mac': '00:00:00:00:00:03', 'udp_dst_port': 53, 'action': 'block'}
]
```

#### Load Balancer VNF (`load_balancer_vnf.py`)

- Virtual IP: `10.0.0.100`
- Backend servers: `h2`, `h3`
- Features:
  - Session persistence
  - Health checks
  - TCP/UDP support
  - NAT and bidirectional flow installation

#### Controller Architecture Explained

The Ryu controller implementation follows a modular design with event-driven programming:

1. **Event Dispatching**: All modules register for OpenFlow events like packet-in messages
2. **Pipeline Processing**: When events occur, they're processed through each module in sequence
3. **Message Handling**: Each module can process messages and optionally pass them to the next module
4. **Flow Rule Installation**: Modules can install flow rules in the switch using OpenFlow messages

This modular architecture allows us to:

- Add or remove functionality without affecting other components
- Process the same events in different ways for different purposes
- Chain multiple network functions together in a service pipeline

---

## Running the Project

### First Terminal: Setup TAP and Launch Controller

```bash
cd ~/SDN-project
chmod +x share.txt
./share.txt
```

> `share.txt` creates the TAP interface, assigns IP `10.100.0.1/24`, enables IP forwarding, and launches the Ryu controller.

### Second Terminal: Confirm Controller is Listening

```bash
sudo lsof -i :6653
```

### Third Terminal: Run NS-3 Simulation

```bash
cd ~/workspace/bake/source/ns-3.38
NS_LOG="TapBridge=level_all|prefix_func|prefix_time:OFSwitch13Device=level_all" ./ns3 run scratch/topology --enable-sudo
```

### Docker-based Deployment (Alternative)

For containerized deployment, we provide Docker configuration files:

1. **Controller Container**: Runs the Ryu controller with all VNF modules
2. **NS-3 Container**: Runs the NS-3 simulation with OFSwitch13

To use the Docker deployment:

```bash
docker-compose up
```

This approach offers several advantages:

- Isolation from the host system
- Consistent environment across different machines
- Easy deployment and scaling
- Pre-configured networking between components

---

## OpenFlow Switch Implementation (OFSwitch13)

- Based on BOFUSS
- Supports OpenFlow 1.3:
  - 64 Flow Tables
  - Group/Meter Tables
  - Full match/action support
- Controller messages:
  - `HELLO`, `FEATURES_REQUEST`, `PACKET_IN`, `FLOW_MOD`
- Advanced Processing:
  - Multi-table pipeline
  - Priority-based rules
  - Counters and stats collection

---

## Testing & Validation

### 🤖 Automated Testing (Recommended)

We provide **9 automated test scripts** covering all scenarios. Each script includes:

- ✅ Proper cleanup (controllers, OVS, TAP, Mininet)
- ✅ Error checking and validation
- ✅ Clear expected outputs
- ✅ PASS/FAIL indicators (Mininet tests)

**Quick Start:**

```bash
# Run master menu
./run_tests.sh

# Or run individual tests
./test_mininet_basic.sh         # Quick basic test
./test_mininet_firewall.sh      # Show PASS/FAIL validation
./test_mininet_loadbalancer.sh  # Show distribution
./test_mininet_both.sh          # Show combined VNFs
```

**For NS-3 tests, first stop OVS:**

```bash
sudo systemctl stop openvswitch-switch
./test_ns3_basic.sh
```

See [TESTING_QUICK_REFERENCE.md](TESTING_QUICK_REFERENCE.md) for complete guide.

### 📊 Expected Results

| Test          | Platform | Expected Output                       |
| ------------- | -------- | ------------------------------------- |
| Basic         | NS-3     | 5 packets, 0% packet loss             |
| Firewall      | NS-3     | 5 packets, 100% packet loss (blocked) |
| Load Balancer | NS-3     | Alternating server responses          |
| Basic         | Mininet  | 0% dropped (6/6 received)             |
| Firewall      | Mininet  | 3 PASS tests                          |
| Load Balancer | Mininet  | Alternating servers                   |
| Both VNFs     | Mininet  | 4 PASS tests                          |

### Manual Testing (Original Method)

### Connectivity Tests

- Ping `h1 → h2`: **Fail** (firewall block)
- Ping `h1 → h3`: **Success**
- Ping `h1 → VIP (10.0.0.100)`: **Distributed** to `h2` or `h3`

### Firewall Tests

- Traffic from `h1 → h2`: Blocked (MAC)
- HTTP to `h3:80`: Blocked (TCP)
- DNS `h1 → h3:53`: Blocked (UDP)
- All other traffic: Allowed

### Load Balancer Tests

- Pings to VIP (`10.0.0.100`) reach either `h2` or `h3`
- Repeated pings maintain session persistence
- Backend stats and health checks logged

### Expected Controller Output

```bash
🟢 SWITCH CONNECTED! Datapath ID: 1
Table-miss flow entry installed on switch 1
Firewall switch features handler for switch 1
Load balancer switch features handler for switch 1
Packet in switch 1: src=00:00:00:00:00:01 dst=ff:ff:ff:ff:ff:ff in_port=1
Firewall packet in switch 1: src=00:00:00:00:00:01 dst=ff:ff:ff:ff:ff:ff in_port=1
```

### Testing Methodology

Our testing approach focuses on validating both the SDN infrastructure and the VNF functionality:

1. **Infrastructure Testing**: Verifies that the OpenFlow connection is established successfully between the NS-3 switch and Ryu controller.

2. **Firewall Testing**: Validates that the firewall VNF correctly enforces access control policies by blocking specific traffic patterns while allowing others. We test at the MAC, IP, and port levels.

3. **Load Balancer Testing**: Confirms that traffic to the VIP is properly distributed among backend servers, connection persistence is maintained, and health monitoring works correctly.

4. **Combined Service Chain**: Tests the entire pipeline where traffic passes through both the firewall and load balancer, ensuring that both VNFs operate correctly in sequence.

Test scenarios use ICMP ping tests for basic connectivity, as well as TCP and UDP traffic for testing protocol-specific filtering and load balancing.

---

## Troubleshooting

### TAP Interface

- Check TAP with: `ip addr show ctrl`
- Recreate if missing

### Controller Connection

- Verify port with: `sudo lsof -i :6653`
- Check traffic: `sudo tcpdump -i ctrl -n port 6653`

### NS-3 Simulation

- Check build errors: `./ns3 build`
- Verify OFSwitch13 is enabled
- Use NS_LOG for debugging

### Common Issues and Solutions

- **TAP Interface Not Found**: Ensure `share.txt` script is executed correctly and check for any errors.
- **Controller Not Listening**: Verify Ryu controller is running and listening on port 6653.
- **NS-3 Simulation Errors**: Check NS-3 build logs for any errors and ensure all required modules are enabled.

---

## Conclusion

This project successfully demonstrates:

- **SDN Architecture**: Decoupling control and data planes
- **NFV Concepts**: Firewall and Load Balancer as virtual functions
- **OpenFlow Integration**: With external Ryu controller
- **Real-world Use Cases**: Traffic filtering, distribution, and policy enforcement

### Key Learnings

Through this project, we've demonstrated several important concepts:

1. **Network Programmability**: SDN allows us to dynamically control network behavior through software, enabling rapid changes and innovation.

2. **Control-Data Plane Separation**: By decoupling decision-making (control) from packet forwarding (data), we gain flexibility and centralized management.

3. **Software-based Network Functions**: NFV enables network functions to be implemented as software modules rather than dedicated hardware, reducing costs and increasing flexibility.

4. **Service Chaining**: Multiple VNFs can be combined to create more complex network services, as demonstrated by our firewall and load balancer working together.

These concepts are increasingly important in modern networks, from data centers to wide-area networks and edge computing environments.

---

**Author**: Omer Ahmed  
**License**: MIT  
**Contact**: [omer.al7labe.oa@gmail.com]
