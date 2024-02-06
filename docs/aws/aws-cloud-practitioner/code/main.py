import sys
from ipaddress import ip_network

# get cider as argument passed to the script
cider: str = sys.argv[1]

# Define the network
network = ip_network(cider)

def print_network_info(network):
    print(f'The network {network} is {"private" if network.is_private else "public"}:')
    print(f'Mask: {network.netmask}')
    binary_mask_with_dots = '.'.join([
        f'{int(octet):08b}' 
        for octet in network.netmask.packed
    ])
    print(f'Binary mask: {binary_mask_with_dots}')
    print(f'Total addresses: {network.num_addresses:,}')
    print(f'IP ranges: {network.network_address} -> {network.broadcast_address}')

print_network_info(network)

if sys.argv[2]:
    cider_two: str = sys.argv[2]
    network_two = ip_network(cider_two)

    print_network_info(network_two)

    # Calculate the total number of addresses in each network
    total_addresses_network1 = network.num_addresses
    total_addresses_network2 = network_two.num_addresses

    # Calculate the percentage of network_two in network
    percentage_network2_in_network1 = (total_addresses_network2 / total_addresses_network1) * 100

    print(f'The network {network_two} represents {percentage_network2_in_network1}% of the network {network}.')
