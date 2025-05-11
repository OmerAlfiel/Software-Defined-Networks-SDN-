# Create a Python script called measure_latency.py
import subprocess
import re
import time
import csv
import matplotlib.pyplot as plt
import numpy as np

def run_ping_test(target, count=10):
    """Run ping test and return average latency in ms"""
    cmd = f"ping -c {count} {target}"
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    
    # Extract average time
    match = re.search(r"avg = ([\d.]+)", result.stdout)
    if match:
        return float(match.group(1))
    else:
        return None

# Test scenarios
scenarios = [
    {"name": "Direct Forwarding (no VNFs)", "target": "10.0.0.3", "vnfs": []},
    {"name": "With Firewall VNF", "target": "10.0.0.3", "vnfs": ["firewall_vnf.py"]},
    {"name": "With Load Balancer VNF", "target": "10.0.0.100", "vnfs": ["load_balancer_vnf.py"]},
    {"name": "With Both VNFs", "target": "10.0.0.100", "vnfs": ["firewall_vnf.py", "load_balancer_vnf.py"]}
]

results = []

# Run tests for each scenario
for scenario in scenarios:
    print(f"Testing scenario: {scenario['name']}")
    
    # Start controller with appropriate VNFs
    controller_cmd = ["ryu-manager", "--verbose", "controller/sdn_controller.py"]
    controller_cmd.extend([f"controller/{vnf}" for vnf in scenario["vnfs"]])
    controller_process = subprocess.Popen(controller_cmd)
    
    # Wait for controller to initialize
    time.sleep(5)
    
    # Start Mininet
    mininet_process = subprocess.Popen(["sudo", "python3", "mininet/topology.py"])
    time.sleep(10)  # Wait for network to initialize
    
    # Run ping test
    latency = run_ping_test(scenario["target"])
    
    # Store results
    results.append({
        "scenario": scenario["name"],
        "latency": latency
    })
    
    # Clean up
    subprocess.run(["sudo", "mn", "-c"], shell=True)
    controller_process.terminate()
    mininet_process.terminate()
    time.sleep(3)

# Save results to CSV
with open('latency_results.csv', 'w', newline='') as csvfile:
    fieldnames = ['scenario', 'latency']
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    for result in results:
        writer.writerow(result)

# Create bar chart
scenarios = [r["scenario"] for r in results]
latencies = [r["latency"] for r in results]

plt.figure(figsize=(10, 6))
plt.bar(scenarios, latencies, color='skyblue')
plt.xlabel('Scenario')
plt.ylabel('Average Latency (ms)')
plt.title('Latency Comparison Across Different VNF Configurations')
plt.xticks(rotation=45, ha='right')
plt.tight_layout()
plt.savefig('latency_comparison.png')
plt.close()

print("Latency testing completed. Results saved to latency_results.csv")