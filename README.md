# Gno's Awesome Toolkit
Have you ever wanted a specific script? Well, maybe I've made it (or maybe not, who knows...). This repository will contain a lot of scripts that can be useful for homelab management, or else.

## Scripts
### Used Ports Management
This script shows which ports on your computer are currently in use, by which processes, and allows generating unused port(s) in specific ranges. It supports both system processes and Docker containers.

```
sudo ./used-ports.sh --help
./used-ports.sh : List or get information about used ports

Usage:
   -d,  --docker      Show only Docker containers
   -p,  --process     Show only system processes
   -c,  --compact     Compact view (just ports without name)
   -gr, --get-random  RANGE Get a random unused port
                      Range can be:
                         privileged  0-1023
                         registered   1024-49151
                         dynamic      49152-65535
                         [MIN-MAX]    custom range, e.g., [9100-9200]
   -gp, --get-port    Filter output by specific port or process name
                      Can be a number (port) or a string (proc name)
   --help             Show this help message and exit

Notes:
   You'll need to execute the command using sudo, since Docker need a
   root access.

Examples:
   sudo ./used-ports.sh
      List all ports and associated processed or Docker containers

   sudo ./used-ports.sh -c
      Show all used ports in a compact format

   sudo ./used-ports.sh -gr registered
      Returns a random unused registered port (1024-49151)

   sudo ./used-ports.sh -gr [9100-9200]
      Returns a random unused port in the custom range 9100-9200

   sudo ./used-ports.sh -gr [100:9000-9200,9400-9550]
      Returns 100 consecutive ports in the range 9000-9200 or 9400-9550
      If there is not range, print a message

   sudo ./used-ports.sh -gp 80
      Filters output for port 80

   sudo ./used-ports.sh -gp nginx
      Filters output for the process named "nginx"
```

**Installation**
```bash
curl -O https://raw.githubusercontent.com/gnoooo/Gno-s-Awesome-Toolkit/main/scripts/used-ports.sh
chmod +x used-ports.sh
mv path/to/your/bin
```
