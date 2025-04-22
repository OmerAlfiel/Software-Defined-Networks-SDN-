FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /ns3

# Install required dependencies
RUN apt-get update && apt-get install -y \
    build-essential g++ python3 python3-pip git mercurial cmake \
    libxml2-dev libboost-all-dev net-tools iputils-ping vim wget \
    libsqlite3-dev pkg-config software-properties-common bzip2 \
    && rm -rf /var/lib/apt/lists/*

# Set up bake and NS-3.38
RUN mkdir -p ~/workspace && cd ~/workspace && \
    git clone https://gitlab.com/nsnam/bake.git && \
    cd bake && \
    ./bake.py configure -e ns-allinone-3.38 && \
    ./bake.py download && \
    ./bake.py build

# Configure NS-3.38 with OFSwitch13 and TAP Bridge support
WORKDIR /root/workspace/source/ns-3.38
RUN ./ns3 configure --enable-examples --enable-modules=ofswitch13,tap-bridge,csma,internet,internet-apps,applications && \
    ./ns3 build

# Create a script to set up TAP interface and run topology
RUN echo '#!/bin/bash\n\
# Create TAP interface for controller communication\n\
ip link delete ctrl 2>/dev/null || true\n\
ip tuntap add dev ctrl mode tap\n\
ip link set dev ctrl up\n\
ip addr add 10.100.0.1/24 dev ctrl\n\
\n\
# Wait for controller\n\
until nc -z 172.20.0.2 6653; do\n\
  echo "Waiting for controller..."\n\
  sleep 1\n\
done\n\
\n\
# Copy topology file to scratch\n\
cp /ns3/scratch/topology.cc /root/workspace/source/ns-3.38/scratch/\n\
\n\
# Run the simulation\n\
cd /root/workspace/source/ns-3.38\n\
NS_LOG="TapBridge=level_all|prefix_func|prefix_time:OFSwitch13Device=level_all" \\\n\
  ./ns3 run "scratch/topology --verbose=1" --enable-sudo\n\
\n\
# Keep container running\n\
tail -f /dev/null\n\
' > /ns3/start.sh && chmod +x /ns3/start.sh

WORKDIR /ns3
CMD ["/ns3/start.sh"]