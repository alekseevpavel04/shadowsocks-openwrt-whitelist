Shadowsocks VPN for GL.iNet Router
====================================

FOLDER STRUCTURE:
  vpn-start.bat      - Turn VPN ON (+ upload lists)
  vpn-stop.bat       - Turn VPN OFF
  vpn-update.bat     - Download fresh lists from GitHub
  lists/
    domains_all.lst  - Blocked domains (Re:filter, auto-updated)
    community.lst    - Popular blocked services (Re:filter, auto-updated)
    my-domains.txt   - YOUR custom domains (edit manually, never overwritten)

FIRST TIME SETUP:
  1. Run vpn-update.bat (downloads lists)
  2. Run vpn-start.bat (starts VPN)

DAILY USE:
  - VPN auto-starts when router reboots (no action needed)
  - To update lists: run vpn-update.bat, then vpn-start.bat
  - To stop VPN: run vpn-stop.bat
  - To add your own domains: edit lists/my-domains.txt, then vpn-start.bat

NOTES:
  - Password input is invisible in console (this is normal)
  - Update lists once a week for best results
  - my-domains.txt is never overwritten by vpn-update.bat
