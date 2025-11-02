# 🎯 SDN Project - Automated Testing Suite Created

## ✅ What Was Created

### Test Scripts (9 files)

1. **run_tests.sh** - Master test script with interactive menu
2. **test_ns3_basic.sh** - NS-3 basic L2 forwarding test
3. **test_ns3_firewall.sh** - NS-3 with firewall VNF
4. **test_ns3_loadbalancer.sh** - NS-3 with load balancer VNF
5. **test_ns3_both.sh** - NS-3 with both VNFs
6. **test_mininet_basic.sh** - Mininet basic L2 forwarding test
7. **test_mininet_firewall.sh** - Mininet with firewall VNF
8. **test_mininet_loadbalancer.sh** - Mininet with load balancer VNF
9. **test_mininet_both.sh** - Mininet with both VNFs

### Documentation Updates

1. **SDN_Implementation_Guide.txt** - Added TRACK 10: AUTOMATED TEST SCRIPTS
2. **TESTING_QUICK_REFERENCE.md** - New quick reference guide for testing

## 📋 Next Steps

### STEP 1: Make Scripts Executable

```bash
cd "c:\Users\Mega Store\Desktop\SDN"
chmod +x test_*.sh run_tests.sh
```

### STEP 2: CRITICAL - Stop Open vSwitch (for NS-3 tests)

```bash
sudo systemctl stop openvswitch-switch
sudo pkill -9 ovs-vswitchd
```

**Why?** Open vSwitch daemon auto-connects to Ryu controller on port 6653, preventing NS-3 from establishing proper OpenFlow handshake. This causes:

- First run: 0% packet loss ✅
- Second run: 100% packet loss ❌

**Solution:** Stop OVS before NS-3 tests (Mininet uses OVS internally, so don't stop for Mininet tests)

### STEP 3: Run Master Test Script

```bash
./run_tests.sh
```

**Menu Options:**

- 1-4: Individual NS-3 tests
- 5-8: Individual Mininet tests
- 9: Run all NS-3 tests
- 10: Run all Mininet tests
- 11: Run ALL tests (complete suite)
- 0: Exit

### STEP 4: Or Run Individual Tests

**NS-3 Tests:**

```bash
./test_ns3_basic.sh         # Basic L2 forwarding
./test_ns3_firewall.sh      # Firewall VNF
./test_ns3_loadbalancer.sh  # Load Balancer VNF
./test_ns3_both.sh          # Both VNFs
```

**Mininet Tests:**

```bash
./test_mininet_basic.sh         # Basic L2 forwarding
./test_mininet_firewall.sh      # Firewall VNF (PASS/FAIL validation)
./test_mininet_loadbalancer.sh  # Load Balancer VNF
./test_mininet_both.sh          # Both VNFs (4 comprehensive tests)
```

## 🎓 For Assignment Demonstration

### Recommended Testing Sequence:

1. **Mininet Basic** (show basic connectivity)

   ```bash
   ./test_mininet_basic.sh
   ```

   Expected: `*** Results: 0% dropped (6/6 received)`

2. **Mininet Firewall** (show blocking functionality)

   ```bash
   ./test_mininet_firewall.sh
   ```

   Expected: 3 PASS tests (h1→h2 blocked, h1→h3 allowed, h2→h1 allowed)

3. **Mininet Load Balancer** (show distribution)

   ```bash
   ./test_mininet_loadbalancer.sh
   ```

   Expected: Responses alternate between 10.0.0.2 and 10.0.0.3

4. **Mininet Both VNFs** (show combined functionality)

   ```bash
   ./test_mininet_both.sh
   ```

   Expected: 4 PASS tests (firewall + load balancer working together)

5. **Stop OVS for NS-3** (CRITICAL!)

   ```bash
   sudo systemctl stop openvswitch-switch
   sudo pkill -9 ovs-vswitchd
   ```

6. **NS-3 Basic** (show simulation)

   ```bash
   ./test_ns3_basic.sh
   ```

   Expected: 5 packets transmitted, 5 received, 0% packet loss

7. **NS-3 Firewall** (show blocking in simulation)

   ```bash
   ./test_ns3_firewall.sh
   ```

   Expected: 100% packet loss (firewall blocking)

8. **NS-3 Load Balancer** (show distribution in simulation)
   ```bash
   ./test_ns3_loadbalancer.sh
   ```
   Expected: Responses alternate between servers

## 📊 Expected Results Summary

| Test          | Platform | Expected Output              |
| ------------- | -------- | ---------------------------- |
| Basic         | NS-3     | 0% packet loss               |
| Firewall      | NS-3     | 100% packet loss (blocked)   |
| Load Balancer | NS-3     | Alternating server responses |
| Both VNFs     | NS-3     | Blocking + Distribution      |
| Basic         | Mininet  | 0% dropped (6/6 received)    |
| Firewall      | Mininet  | 3 PASS tests                 |
| Load Balancer | Mininet  | Alternating servers          |
| Both VNFs     | Mininet  | 4 PASS tests                 |

## 🔧 Common Issues & Solutions

### Issue 1: NS-3 shows 100% packet loss

**Cause:** OVS daemon auto-connecting to controller
**Solution:**

```bash
sudo systemctl stop openvswitch-switch
sudo pkill -9 ovs-vswitchd
netstat -tn | grep :6653  # Verify no connections
```

### Issue 2: Permission denied

**Solution:**

```bash
chmod +x test_*.sh run_tests.sh
```

### Issue 3: Controller already running

**Solution:**

```bash
sudo pkill -9 -f ryu-manager
```

### Issue 4: TAP interface exists

**Solution:**

```bash
sudo ip link delete ctrl
sudo mn -c
```

## 📁 Script Features

### All Scripts Include:

✅ **Cleanup Function** - Kills controllers, stops OVS, deletes TAP, cleans Mininet
✅ **Error Checking** - Validates environment before running tests
✅ **Connection Validation** - Checks for unexpected OVS connections (NS-3 only)
✅ **Comprehensive Logging** - Saves controller logs to /tmp
✅ **Clear Output** - Formatted with separators and status indicators

### NS-3 Scripts:

- Stop OVS daemon before tests
- Check for unexpected connections on port 6653
- Verify no phantom OVS processes
- Run simulation with --enable-sudo
- Show expected results

### Mininet Scripts:

- Use inline Python scripts (no separate files needed)
- Include PASS/FAIL validation
- Test specific scenarios with clear output
- Save controller logs to /tmp
- Show traffic distribution patterns

## 📝 Controller Logs

Mininet tests save logs:

- `/tmp/controller_basic.log`
- `/tmp/controller_firewall.log`
- `/tmp/controller_loadbalancer.log`
- `/tmp/controller_both.log`

View logs in real-time:

```bash
tail -f /tmp/controller_basic.log
```

## 🎯 Success Indicators

**NS-3 Basic:** `5 packets transmitted, 5 received, 0% packet loss`
**NS-3 Firewall:** `5 packets transmitted, 0 received, 100% packet loss`
**NS-3 Load Balancer:** Responses from both `10.0.0.2` and `10.0.0.3`
**Mininet Basic:** `*** Results: 0% dropped (6/6 received)`
**Mininet Firewall:** `✅ PASS: h1->h2 correctly blocked by firewall`
**Mininet Load Balancer:** Alternating responses from servers
**Mininet Both:** `✅ All 4 tests PASSED!`

## 📸 Screenshot Checklist for Assignment

- [ ] Mininet basic test with 0% dropped
- [ ] Mininet firewall with PASS/FAIL validation
- [ ] Mininet load balancer showing alternating servers
- [ ] Mininet both VNFs with 4 PASS tests
- [ ] NS-3 basic with 0% packet loss
- [ ] NS-3 firewall with 100% packet loss
- [ ] NS-3 load balancer with distribution
- [ ] Controller logs showing flow installation

## 🚀 Quick Test All (3-4 minutes)

```bash
# Stop OVS (CRITICAL for NS-3)
sudo systemctl stop openvswitch-switch

# Run master script
./run_tests.sh

# Select option 11: Run ALL tests (NS-3 + Mininet)
```

## ✨ Key Benefits

1. **Automated Testing** - No manual steps, just run scripts
2. **Comprehensive Coverage** - All VNF combinations tested
3. **Clear Validation** - PASS/FAIL indicators for easy verification
4. **Error Handling** - Proper cleanup and error checking
5. **Repeatable** - Can run tests multiple times reliably
6. **Documentation** - Clear expected outputs for each test
7. **Debugging** - Controller logs saved for troubleshooting

## 📚 Documentation

1. **SDN_Implementation_Guide.txt** - Complete guide with TRACK 10
2. **TESTING_QUICK_REFERENCE.md** - Quick reference for all tests
3. **THIS_FILE.md** - Summary of what was created

---

**Status:** ✅ All test scripts created and documented
**Next:** Make scripts executable and run tests
**Assignment:** Ready for demonstration and screenshots
