FROM python:3.9

# Install dependencies
WORKDIR /app
RUN pip install ryu==4.34 eventlet==0.30.2 && \
    apt-get update && apt-get install -y net-tools iputils-ping

# Copy controller files
COPY controller/ /app/

# Expose OpenFlow port
EXPOSE 6653

# Create healthcheck script
RUN echo '#!/bin/bash\n\
if netstat -tuln | grep -q 6653; then\n\
  exit 0\n\
else\n\
  exit 1\n\
fi' > /app/healthcheck.sh && chmod +x /app/healthcheck.sh

# Add healthcheck
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
  CMD /app/healthcheck.sh

# Run all controller modules
CMD ["ryu-manager", "--verbose", "--ofp-listen-host=0.0.0.0", "--ofp-tcp-listen-port=6653", \
     "sdn_controller.py", "firewall_vnf.py", "load_balancer_vnf.py"]