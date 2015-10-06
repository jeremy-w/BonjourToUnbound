# Bonjour to Unbound

Learning Idris while writing a tool to copy records from Bonjour and
inject them into Unbound with the local host renamed to an external host.

Assuming you're running Unbound on your local workstation,
and you have a single LAN host exposed to the WAN,
this solves the problem that you have a DNS record pointing
at your local network's public IP address, but your crummy router
doesn't implement [NAT hairpinning](https://en.wikipedia.org/wiki/Hairpinning).

That means you can always use the public URL of your host,
whether within or without the local network,
rather than needing to remember to use
YourNAS.local when you're at home
but YourAwesomeNAS.com when you're not.
