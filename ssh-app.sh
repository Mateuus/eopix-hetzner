#!/bin/bash
# Script helper para conectar no servidor APP
APP_IP=$(hcloud server describe eopix-app -o format='{{.PublicNet.IPv4.IP}}' 2>/dev/null || echo "5.161.176.10")
ssh -i ~/.ssh/eopix_kubernetes root@${APP_IP}
