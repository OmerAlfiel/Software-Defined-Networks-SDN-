# SDN Project with OpenFlow and Network Function Virtualization

## Overview

This project implements a Software-Defined Network (SDN) with Network Function Virtualization (NFV) using both NS-3 simulation and Mininet emulation with the Ryu controller. It demonstrates the SDN paradigm by separating the control plane from the data plane and virtualizing network functions such as firewall and load balancer.

## Objectives

- Create an OpenFlow-enabled network topology using both NS-3 and Mininet
- Implement a Ryu-based SDN controller with basic L2 forwarding
- Develop a firewall VNF to control traffic between nodes
- Develop a load balancer VNF to distribute traffic
- Demonstrate both simulation (NS-3) and emulation (Mininet) approaches to SDN

## Architecture

### Components

**Dual Implementation Approach:**

- **NS-3 Simulation:** Virtual network with 3 hosts, one OpenFlow switch, and TAP bridge
- **Mininet Emulation:** Virtual network with 3 hosts and one OpenFlow switch
- **Ryu Controller:** External SDN controller with:
  - L2 Forwarding
  - Firewall VNF
  - Load Balancer VNF

### SDN Architecture Explained

Our implementation follows the classic SDN architecture with three distinct layers:

- **Data Plane:** Represented by the OpenFlow switch (either NS-3 simulated or Mininet), responsible only for packet forwarding based on flow rules.
- **Control Plane:** Implemented by the Ryu controller, which makes all forwarding decisions and populates the switch's flow tables.
- **Application Plane:** Consists of our VNF applications (firewall and load balancer) that implement network policies.

### NFV Implementation Details

Network Function Virtualization (NFV) decouples network functions from dedicated hardware appliances. In our implementation:

- Network functions (firewall, load balancer) are implemented as software modules in the controller
- These functions operate on traffic flows rather than requiring dedicated hardware
- The VNFs can be easily modified, updated, or replaced without changing the underlying infrastructure

## Setup Procedure

### Requirements

- Ubuntu 20.04 or newer
- Python 3.8+
- Mininet 2.2+
- Ryu Controller
- NS-3.38 (optional, for simulation approach)

### Installation Options

#### Option 1: Mininet Setup (Recommended for Beginners)

```bash
sudo apt update
sudo apt install -y mininet python3-pip net-tools iperf
sudo pip3 install ryu
```

#### Option 2: NS-3 Setup (For Advanced Simulation)

```bash
sudo apt update
sudo apt install -y build-essential g++ python3 python3-pip git cmake libxml2-dev libboost-all-dev

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

## Project Structure

```
SDN-project/
├── controller/
│   ├── sdn_controller.py    # Basic L2 forwarding
│   ├── firewall_vnf.py      # Firewall rules implementation
│   ├── load_balancer_vnf.py # Load balancer implementation
├── mininet/
│   ├── topology.py          # Mininet topology implementation
├── ns3/
│   ├── topology.cc          # NS-3 topology implementation
├── share.txt                # Script for TAP interface setup (NS-3)
├── README.md                # Project documentation
```

## Implementation Details

### Mininet Topology

The Mininet topology creates a network with:

- 3 host nodes (h1, h2, h3) with IPs 10.0.0.1/24, 10.0.0.2/24, 10.0.0.3/24
- A virtual IP (10.0.0.100) configured on both h2 and h3 for load balancing
- 1 OpenFlow 1.3 switch connecting all hosts
- Links with 10 Mbps bandwidth

**Key features:**

- Automated tests for firewall functionality
- Automated tests for load balancer functionality
- Support for manual testing via Mininet CLI

### NS-3 Topology

The NS-3 implementation creates a similar topology using simulation:

- 3 hosts with IPs in the 10.0.0.0/24 subnet
- 1 OpenFlow switch (using OFSwitch13 module)
- TAP bridge for external controller communication
- CSMA links (100Mbps)

### Ryu Controller Modules

#### Basic SDN Controller (`sdn_controller.py`)

- MAC learning and L2 forwarding
- Installs flow rules for known hosts

#### Firewall VNF (`firewall_vnf.py`)

- Blocks specific MAC/TCP/UDP traffic
- Example rules:

```python
self.firewall_rules = [
  {'name': 'h1→h2', 'src_mac': '00:00:00:00:00:01', 'dst_mac': '00:00:00:00:00:02', 'action': 'block'},
  {'name': 'http→h3', 'dst_mac': '00:00:00:00:00:03', 'tcp_dst_port': 80, 'action': 'block'},
  {'name': 'dns-h1→h3', 'src_mac': '00:00:00:00:00:01', 'dst_mac': '00:00:00:00:00:03', 'udp_dst_port': 53, 'action': 'block'}
]
```

#### Load Balancer VNF (`load_balancer_vnf.py`)

- Virtual IP: 10.0.0.100
- Backend servers: h2, h3
- Features:
  - Session persistence
  - Health checks
  - TCP/UDP support
  - NAT and bidirectional flow installation

## Running the Project

### Option 1: Running with Mininet (Recommended)

**Terminal 1: Start Ryu Controller**

```bash
cd ~/SDN-project
ryu-manager --verbose controller/sdn_controller.py controller/firewall_vnf.py controller/load_balancer_vnf.py
```

You should see output indicating the controller has started and is waiting for switch connections.

**Terminal 2: Run Mininet Topology**

```bash
cd ~/SDN-project
sudo python3 mininet/topology.py
```

This will:

- Create the network with 3 hosts and 1 switch
- Configure the virtual IP for load balancing
- Run automated tests:
  - Test firewall: h1→h2 (should be blocked)
  - Test connectivity: h1→h3 (should work)
  - Test load balancer: h1→VIP (10.0.0.100)
- Launch the Mininet CLI for manual testing

**Testing in Mininet CLI**

```bash
# Test firewall (should fail)
mininet> h1 ping h2

# Test normal connectivity (should succeed)
mininet> h1 ping h3

# Test load balancer (traffic distributed between h2 and h3)
mininet> h1 ping 10.0.0.100

# Check test logs
mininet> h1 cat /tmp/ping_h1_h2.log
mininet> h1 cat /tmp/ping_h1_h3.log
mininet> h1 cat /tmp/ping_h1_vip.log

# Exit when done
mininet> exit
```

Cleanup:

```bash
sudo mn -c
```

### Option 2: Running with NS-3 (Advanced)

**Terminal 1: Setup TAP and Launch Controller**

```bash
cd ~/SDN-project
chmod +x share.txt
./share.txt
```

**Terminal 2: Run NS-3 Simulation**

```bash
cd ~/workspace/bake/source/ns-3.38
NS_LOG="TapBridge=level_all|prefix_func|prefix_time:OFSwitch13Device=level_all" ./ns3 run scratch/topology --enable-sudo
```

## Testing & Validation

- **Connectivity Tests**
  - Ping h1 → h2: Fail (firewall block)
  - Ping h1 → h3: Success
  - Ping h1 → VIP (10.0.0.100): Distributed to h2 or h3

- **Firewall Tests**
  - Traffic from h1 → h2: Blocked (MAC)
  - HTTP to h3:80: Blocked (TCP)
  - DNS h1 → h3:53: Blocked (UDP)
  - All other traffic: Allowed

- **Load Balancer Tests**
  - Pings to VIP (10.0.0.100) reach either h2 or h3
  - Repeated pings maintain session persistence

## Troubleshooting

- **Mininet Issues**
  - "No module named 'mininet'": Ensure Mininet is properly installed with `sudo apt install mininet` or install from source.
  - Controller not connecting: Check if Ryu is running and listening on port 6653 with `sudo lsof -i :6653`.
  - Ping failures: Verify network setup with `mininet> net` and check controller logs for errors.

- **NS-3 Issues**
  - TAP Interface Not Found: Ensure `share.txt` script is executed correctly.
  - NS-3 Simulation Errors: Check NS-3 build logs and ensure all required modules are enabled.

- **Common Issues**
  - Permission issues: Most commands require sudo privileges
  - Port conflicts: Ensure no other applications are using port 6653
  - Path issues: Make sure you're running commands from the correct directory

## Conclusion

This project successfully demonstrates:

- SDN Architecture: Decoupling control and data planes
- NFV Concepts: Firewall and Load Balancer as virtual functions
- OpenFlow Integration: With external Ryu controller
- Dual Implementation: Both simulation (NS-3) and emulation (Mininet) approaches

The implementation showcases how SDN and NFV can be used to create flexible, programmable networks with virtualized network functions that can be dynamically configured and updated.

---

**Author:** Omer Ahmed  
**License:** MIT  
**Contact:** [omer.al7labe.oa@gmail.com]