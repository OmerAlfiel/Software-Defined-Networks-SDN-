#!/usr/bin/env python3
# Firewall VNF with L2-L4 filtering capabilities

from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER, set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet, ether_types, ipv4, tcp, udp

class L2SwitchWithFirewall(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]
    
    def __init__(self, *args, **kwargs):
        super(L2SwitchWithFirewall, self).__init__(*args, **kwargs)
        self.mac_to_port = {}
        # Firewall rules definition
        self.firewall_rules = [
            # Block all traffic from h1 to h2
            {'name': 'h1→h2', 'src_mac': '00:00:00:00:00:01', 'dst_mac': '00:00:00:00:00:02', 'action': 'block'},
            # Block TCP traffic to h3 on port 80 (HTTP)
            {'name': 'http→h3', 'dst_mac': '00:00:00:00:00:03', 'tcp_dst_port': 80, 'action': 'block'},
            # Block UDP traffic from h1 to h3 on port 53 (DNS)
            {'name': 'dns-h1→h3', 'src_mac': '00:00:00:00:00:01', 'dst_mac': '00:00:00:00:00:03', 
             'udp_dst_port': 53, 'action': 'block'}
        ]
        self.connection_track = {}  # Track connections for DoS protection
        self.connection_limit = 50  # Max connections per source
        self.logger.info("Firewall VNF initialized")
    
    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        
        # Install the table-miss flow entry
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER, ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)
        self.logger.info("Firewall switch features handler for switch %s", datapath.id)
    
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
    
    def check_firewall_rules(self, datapath, parser, pkt, in_port, eth_src, eth_dst):
        # Check if packet matches any firewall rule
        ip_pkt = pkt.get_protocol(ipv4.ipv4)
        tcp_pkt = pkt.get_protocol(tcp.tcp)
        udp_pkt = pkt.get_protocol(udp.udp)
        
        for rule in self.firewall_rules:
            # Skip rule if src_mac is specified and doesn't match
            if 'src_mac' in rule and rule['src_mac'] != eth_src:
                continue
                
            # Skip rule if dst_mac is specified and doesn't match
            if 'dst_mac' in rule and rule['dst_mac'] != eth_dst:
                continue
            
            # Skip rule if ip_proto is specified and packet is not IP
            if ('ip_proto' in rule or 'src_ip' in rule or 'dst_ip' in rule) and not ip_pkt:
                continue
                
            # Skip rule if src_ip is specified and doesn't match
            if 'src_ip' in rule and rule['src_ip'] != ip_pkt.src:
                continue
                
            # Skip rule if dst_ip is specified and doesn't match
            if 'dst_ip' in rule and rule['dst_ip'] != ip_pkt.dst:
                continue
            
            # TCP specific checks
            if 'tcp_src_port' in rule or 'tcp_dst_port' in rule:
                if not tcp_pkt:
                    continue
                if 'tcp_src_port' in rule and rule['tcp_src_port'] != tcp_pkt.src_port:
                    continue
                if 'tcp_dst_port' in rule and rule['tcp_dst_port'] != tcp_pkt.dst_port:
                    continue
            
            # UDP specific checks
            if 'udp_src_port' in rule or 'udp_dst_port' in rule:
                if not udp_pkt:
                    continue
                if 'udp_src_port' in rule and rule['udp_src_port'] != udp_pkt.src_port:
                    continue
                if 'udp_dst_port' in rule and rule['udp_dst_port'] != udp_pkt.dst_port:
                    continue
            
            # If we get here, all specified conditions match
            if rule['action'] == 'block':
                self.logger.info("Firewall: blocked traffic by rule %s: %s → %s", 
                                rule['name'], eth_src, eth_dst)
                
                # Create a match for this rule
                match_fields = {}
                match_fields['eth_src'] = eth_src
                match_fields['eth_dst'] = eth_dst
                
                if ip_pkt:
                    match_fields['eth_type'] = ether_types.ETH_TYPE_IP
                    match_fields['ipv4_src'] = ip_pkt.src
                    match_fields['ipv4_dst'] = ip_pkt.dst
                    
                    if tcp_pkt and ('tcp_src_port' in rule or 'tcp_dst_port' in rule):
                        match_fields['ip_proto'] = 6  # TCP
                        if 'tcp_src_port' in rule:
                            match_fields['tcp_src'] = tcp_pkt.src_port
                        if 'tcp_dst_port' in rule:
                            match_fields['tcp_dst'] = tcp_pkt.dst_port
                    
                    if udp_pkt and ('udp_src_port' in rule or 'udp_dst_port' in rule):
                        match_fields['ip_proto'] = 17  # UDP
                        if 'udp_src_port' in rule:
                            match_fields['udp_src'] = udp_pkt.src_port
                        if 'udp_dst_port' in rule:
                            match_fields['udp_dst'] = udp_pkt.dst_port
                
                # Install a flow to block this traffic
                match = parser.OFPMatch(**match_fields)
                self.add_flow(datapath, 100, match, [], hard_timeout=3600)  # Priority 100, 1 hour timeout
                return True
        
        # DoS protection - track connections per source
        if ip_pkt and tcp_pkt:
            src_ip = ip_pkt.src
            if src_ip not in self.connection_track:
                self.connection_track[src_ip] = 1
            else:
                self.connection_track[src_ip] += 1
                
            if self.connection_track[src_ip] > self.connection_limit:
                self.logger.warning("DoS protection: blocking excess connections from %s", src_ip)
                match = parser.OFPMatch(eth_type=ether_types.ETH_TYPE_IP, ipv4_src=src_ip)
                self.add_flow(datapath, 90, match, [], hard_timeout=300)  # Block for 5 minutes
                return True
        
        return False  # Not blocked
    
    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def _packet_in_handler(self, ev):
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
        
        dst = eth.dst
        src = eth.src
        dpid = datapath.id
        
        self.logger.info("Firewall packet in switch %s: src=%s dst=%s in_port=%s", dpid, src, dst, in_port)
        
        # Check firewall rules
        if self.check_firewall_rules(datapath, parser, pkt, in_port, src, dst):
            return  # Packet blocked, no need to process further
        
        # Learn MAC address to avoid FLOOD next time
        self.mac_to_port.setdefault(dpid, {})
        self.mac_to_port[dpid][src] = in_port
        
        # If the destination is known, forward to the specific port
        # Otherwise, flood to all ports
        if dst in self.mac_to_port[dpid]:
            out_port = self.mac_to_port[dpid][dst]
        else:
            out_port = ofproto.OFPP_FLOOD
        
        actions = [parser.OFPActionOutput(out_port)]
        
        # Install a flow to avoid packet_in next time
        if out_port != ofproto.OFPP_FLOOD:
            match = parser.OFPMatch(in_port=in_port, eth_dst=dst)
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