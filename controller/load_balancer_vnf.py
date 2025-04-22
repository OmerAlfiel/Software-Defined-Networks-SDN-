#!/usr/bin/env python3
# Load balancer VNF implementation with health monitoring

from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER, set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet, ether_types, ipv4, tcp, udp
import random
import time

class LoadBalancerVNF(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]
    
    def __init__(self, *args, **kwargs):
        super(LoadBalancerVNF, self).__init__(*args, **kwargs)
        self.mac_to_port = {}
        
        # Virtual service configuration
        self.virtual_ip = '10.0.0.100'
        self.virtual_mac = '00:00:00:00:00:64'  # 64 decimal = 100 hex
        
        # Backend servers
        self.servers = [
            {'ip': '10.0.0.2', 'mac': '00:00:00:00:00:02', 'weight': 1, 'active': True},
            {'ip': '10.0.0.3', 'mac': '00:00:00:00:00:03', 'weight': 1, 'active': True}
        ]
        
        # Session persistence table (client_ip -> server_index)
        self.client_to_server = {}
        
        # Load balancing statistics
        self.stats = {i: {'connections': 0, 'packets': 0, 'bytes': 0, 'last_seen': time.time()} 
                      for i in range(len(self.servers))}
        
        # Health check parameters
        self.health_check_interval = 30  # seconds
        self.last_health_check = time.time()
        
        self.logger.info("Load Balancer VNF initialized with VIP: %s", self.virtual_ip)
    
    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        
        # Install the table-miss flow entry
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER, ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)
        self.logger.info("Load balancer switch features handler for switch %s", datapath.id)
    
    def add_flow(self, datapath, priority, match, actions, buffer_id=None, idle_timeout=0, hard_timeout=0):
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        
        inst = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS, actions)]
        
        if buffer_id:
            mod = parser.OFPFlowMod(datapath=datapath, buffer_id=buffer_id,
                                    priority=priority, match=match,
                                    instructions=inst, idle_timeout=idle_timeout,
                                    hard_timeout=hard_timeout)
        else:
            mod = parser.OFPFlowMod(datapath=datapath, priority=priority,
                                    match=match, instructions=inst,
                                    idle_timeout=idle_timeout, 
                                    hard_timeout=hard_timeout)
        datapath.send_msg(mod)
    
    def select_server(self, client_ip, client_port=None, protocol=None):
        """Select a server for a new connection using weighted round-robin algorithm"""
        # Check for session persistence
        if client_ip in self.client_to_server:
            server_index = self.client_to_server[client_ip]
            # Verify server is still active
            if self.servers[server_index]['active']:
                return server_index
        
        # Filter only active servers
        active_servers = [(i, server) for i, server in enumerate(self.servers) if server['active']]
        if not active_servers:
            self.logger.error("No active servers available")
            return None
        
        # Use weighted selection based on server weights
        total_weight = sum(server['weight'] for _, server in active_servers)
        r = random.uniform(0, total_weight)
        upto = 0
        
        for i, server in active_servers:
            upto += server['weight']
            if upto >= r:
                # Store for session persistence
                self.client_to_server[client_ip] = i
                # Update statistics
                self.stats[i]['connections'] += 1
                self.stats[i]['last_seen'] = time.time()
                return i
        
        # Fallback to first active server
        i = active_servers[0][0]
        self.client_to_server[client_ip] = i
        self.stats[i]['connections'] += 1
        self.stats[i]['last_seen'] = time.time()
        return i
    
    def health_check(self):
        """Simulate health checks for backend servers"""
        current_time = time.time()
        if current_time - self.last_health_check < self.health_check_interval:
            return
        
        self.last_health_check = current_time
        self.logger.info("Performing health check on backend servers")
        
        # In a real implementation, this would ping servers or check a health endpoint
        # Here we'll simulate by marking servers inactive if they haven't been used in 2 minutes
        for i, server in enumerate(self.servers):
            last_seen = self.stats[i]['last_seen']
            if current_time - last_seen > 120:  # 2 minutes
                if server['active']:
                    self.logger.warning("Server %s marked inactive due to inactivity", server['ip'])
                    self.servers[i]['active'] = False
            else:
                if not server['active']:
                    self.logger.info("Server %s marked active again", server['ip'])
                    self.servers[i]['active'] = True
    
    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def _packet_in_handler(self, ev):
        # Run periodic health check
        self.health_check()
        
        msg = ev.msg
        datapath = msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        in_port = msg.match['in_port']
        
        pkt = packet.Packet(msg.data)
        eth = pkt.get_protocols(ethernet.ethernet)[0]
        
        if eth.ethertype == ether_types.ETH_TYPE_LLDP:
            # Ignore LLDP packets
            return
        
        dst_mac = eth.dst
        src_mac = eth.src
        dpid = datapath.id
        
        # Learn MAC address to avoid FLOOD next time
        self.mac_to_port.setdefault(dpid, {})
        self.mac_to_port[dpid][src_mac] = in_port
        
        # Check if this packet is destined for our virtual IP
        ip_pkt = pkt.get_protocol(ipv4.ipv4)
        if ip_pkt and ip_pkt.dst == self.virtual_ip:
            self.logger.info("Load balancer: received packet for VIP: %s from %s", self.virtual_ip, ip_pkt.src)
            
            # Get protocol-specific information
            tcp_pkt = pkt.get_protocol(tcp.tcp)
            udp_pkt = pkt.get_protocol(udp.udp)
            
            protocol = None
            src_port = None
            dst_port = None
            
            if tcp_pkt:
                protocol = 'tcp'
                src_port = tcp_pkt.src_port
                dst_port = tcp_pkt.dst_port
            elif udp_pkt:
                protocol = 'udp'
                src_port = udp_pkt.src_port
                dst_port = udp_pkt.dst_port
            
            # Select a server for this connection
            server_index = self.select_server(ip_pkt.src, src_port, protocol)
            if server_index is None:
                self.logger.error("No server available - dropping packet")
                return
            
            server = self.servers[server_index]
            self.logger.info("Load balancer: selected server %s for client %s", server['ip'], ip_pkt.src)
            
            # Set up actions to modify packet destination to selected server
            actions = [
                parser.OFPActionSetField(eth_dst=server['mac']),
                parser.OFPActionSetField(ipv4_dst=server['ip']),
                parser.OFPActionOutput(self.mac_to_port[dpid].get(server['mac'], ofproto.OFPP_FLOOD))
            ]
            
            # Update statistics
            self.stats[server_index]['packets'] += 1
            self.stats[server_index]['bytes'] += len(msg.data)
            
            # Install flow rule for subsequent packets in this flow
            if protocol == 'tcp':
                match = parser.OFPMatch(
                    eth_type=ether_types.ETH_TYPE_IP,
                    ip_proto=6,  # TCP
                    ipv4_src=ip_pkt.src,
                    ipv4_dst=self.virtual_ip,
                    tcp_src=src_port,
                    tcp_dst=dst_port
                )
                self.add_flow(datapath, 20, match, actions, idle_timeout=300)
                
                # Install reverse flow (server -> client)
                reverse_actions = [
                    parser.OFPActionSetField(eth_src=self.virtual_mac),
                    parser.OFPActionSetField(ipv4_src=self.virtual_ip),
                    parser.OFPActionOutput(in_port)
                ]
                reverse_match = parser.OFPMatch(
                    eth_type=ether_types.ETH_TYPE_IP,
                    ip_proto=6,  # TCP
                    ipv4_src=server['ip'],
                    ipv4_dst=ip_pkt.src,
                    tcp_src=dst_port,
                    tcp_dst=src_port
                )
                self.add_flow(datapath, 20, reverse_match, reverse_actions, idle_timeout=300)
                
            elif protocol == 'udp':
                match = parser.OFPMatch(
                    eth_type=ether_types.ETH_TYPE_IP,
                    ip_proto=17,  # UDP
                    ipv4_src=ip_pkt.src,
                    ipv4_dst=self.virtual_ip,
                    udp_src=src_port,
                    udp_dst=dst_port
                )
                self.add_flow(datapath, 20, match, actions, idle_timeout=300)
                
                # Install reverse flow (server -> client)
                reverse_actions = [
                    parser.OFPActionSetField(eth_src=self.virtual_mac),
                    parser.OFPActionSetField(ipv4_src=self.virtual_ip),
                    parser.OFPActionOutput(in_port)
                ]
                reverse_match = parser.OFPMatch(
                    eth_type=ether_types.ETH_TYPE_IP,
                    ip_proto=17,  # UDP
                    ipv4_src=server['ip'],
                    ipv4_dst=ip_pkt.src,
                    udp_src=dst_port,
                    udp_dst=src_port
                )
                self.add_flow(datapath, 20, reverse_match, reverse_actions, idle_timeout=300)
            
            # Send this packet to the selected server
            data = None
            if msg.buffer_id == ofproto.OFP_NO_BUFFER:
                data = msg.data
            
            out = parser.OFPPacketOut(
                datapath=datapath,
                buffer_id=msg.buffer_id,
                in_port=in_port,
                actions=actions,
                data=data
            )
            datapath.send_msg(out)
            return
        
        # Regular L2 forwarding for non-load balanced traffic
        if dst_mac in self.mac_to_port[dpid]:
            out_port = self.mac_to_port[dpid][dst_mac]
        else:
            out_port = ofproto.OFPP_FLOOD
        
        actions = [parser.OFPActionOutput(out_port)]
        
        # Install a flow to avoid packet_in next time
        if out_port != ofproto.OFPP_FLOOD:
            match = parser.OFPMatch(in_port=in_port, eth_dst=dst_mac)
            # Verify if we have a valid buffer_id, if yes avoid sending both flow_mod & packet_out
            if msg.buffer_id != ofproto.OFP_NO_BUFFER:
                self.add_flow(datapath, 1, match, actions, msg.buffer_id, idle_timeout=300)
                return
            else:
                self.add_flow(datapath, 1, match, actions, idle_timeout=300)
        
        # Forward the packet
        data = None
        if msg.buffer_id == ofproto.OFP_NO_BUFFER:
            data = msg.data
            
        out = parser.OFPPacketOut(datapath=datapath, buffer_id=msg.buffer_id,
                                  in_port=in_port, actions=actions, data=data)
        datapath.send_msg(out)