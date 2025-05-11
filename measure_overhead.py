# Create a Python script called measure_overhead.py
import subprocess
import re
import time
import csv
import psutil
import matplotlib.pyplot as plt
import numpy as np
from mininet.net import Mininet
from mininet.topo import Topo
from mininet.node import Controller, RemoteController
from mininet.cli import CLI
from mininet.log import setLogLevel, info

class CustomTopo(Topo):
    def build(self, n=3):
        # Add switch
        switch = self.addSwitch('s1')
        # Add hosts
        for i in range(1, n+1):
            host = self.addHost(f'h{i}', ip=f'10.0.0.{i}/24', mac=f'00:00:00:00:00:0{i}')
            self.addLink(host, switch)

def measure_controller_overhead(controller_cmd, num_switches, num_hosts):
    """Measure CPU, memory, and flow setup time for the controller"""
    # Start controller
    controller_process = subprocess.Popen(controller_cmd)
    controller_pid = controller_process.pid
    time.sleep(5)  # Wait for controller to initialize
    
    # Start Mininet with custom topology
    topo = CustomTopo(n=num_hosts)
    net = Mininet(topo=topo, controller=lambda name: RemoteController(name, ip='127.0.0.1'))
    net.start()
    
    # Generate traffic to trigger flow setup
    start_time = time.time()
    net.ping(net.hosts)  # This will trigger flow setups
    flow_setup_time = (time.time() - start_time) * 1000 / (num_hosts * (num_hosts - 1))  # ms per flow
    
    # Measure CPU and memory
    proc = psutil.Process(controller_pid)
    cpu_percent = proc.cpu_percent(interval=1)
    memory_mb = proc.memory_info().rss / 1024 / 1024  # Convert bytes to MB
    
    # Clean up
    net.stop()
    controller_process.terminate()
    subprocess.run(["sudo", "mn", "-c"], shell=True)
    time.sleep(3)
    
    return {
        "cpu_percent": cpu_percent,
        "memory_mb": memory_mb,
        "flow_setup_time": flow_setup_time
    }

# Test scenarios with different network sizes
network_sizes = [
    {"switches": 1, "hosts": 3},
    {"switches": 3, "hosts": 9},
    {"switches": 5, "hosts": 15},
    {"switches": 10, "hosts": 30}
]

controller_cmd = ["ryu-manager", "--verbose", "controller/sdn_controller.py", 
                 "controller/firewall_vnf.py", "controller/load_balancer_vnf.py"]

results = []

for size in network_sizes:
    print(f"Testing network with {size['switches']} switches and {size['hosts']} hosts")
    metrics = measure_controller_overhead(controller_cmd, size['switches'], size['hosts'])
    results.append({
        "switches": size['switches'],
        "hosts": size['hosts'],
        "cpu_percent": metrics["cpu_percent"],
        "memory_mb": metrics["memory_mb"],
        "flow_setup_time": metrics["flow_setup_time"]
    })

# Save results to CSV
with open('overhead_results.csv', 'w', newline='') as csvfile:
    fieldnames = ['switches', 'hosts', 'cpu_percent', 'memory_mb', 'flow_setup_time']
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    for result in results:
        writer.writerow(result)

# Create line plots
plt.figure(figsize=(15, 10))

# CPU utilization plot
plt.subplot(3, 1, 1)
plt.plot([f"{r['switches']} sw, {r['hosts']} h" for r in results], 
         [r["cpu_percent"] for r in results], 'o-', color='blue')
plt.ylabel('CPU Utilization (%)')
plt.title('Controller Overhead vs Network Size')
plt.xticks(rotation=45)
plt.grid(True, linestyle='--', alpha=0.7)

# Memory usage plot
plt.subplot(3, 1, 2)
plt.plot([f"{r['switches']} sw, {r['hosts']} h" for r in results], 
         [r["memory_mb"] for r in results], 'o-', color='red')
plt.ylabel('Memory Usage (MB)')
plt.xticks(rotation=45)
plt.grid(True, linestyle='--', alpha=0.7)

# Flow setup time plot
plt.subplot(3, 1, 3)
plt.plot([f"{r['switches']} sw, {r['hosts']} h" for r in results], 
         [r["flow_setup_time"] for r in results], 'o-', color='green')
plt.ylabel('Flow Setup Time (ms)')
plt.xlabel('Network Size')
plt.xticks(rotation=45)
plt.grid(True, linestyle='--', alpha=0.7)

plt.tight_layout()
plt.savefig('controller_overhead.png')
plt.close()

print("Overhead testing completed. Results saved to overhead_results.csv")