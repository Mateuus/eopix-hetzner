#!/bin/bash
# Script helper para conectar no servidor DB
DB_IP=$(hcloud server describe eopix-db -o format='{{.PublicNet.IPv4.IP}}' 2>/dev/null || echo "5.161.223.50")
ssh -i ~/.ssh/eopix_kubernetes root@${DB_IP}
