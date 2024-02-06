from ipaddress import ip_network
import sys
from rich.console import Console
from rich.table import Table

# Initialize rich console
console = Console()

def print_network_info(network):
    console.print(f'The network [bold cyan]{network}[/bold cyan] is {"private" if network.is_private else "public"}:', style="bold green")
    console.print(f'Mask: [bold yellow]{network.netmask}[/bold yellow]')
    console.print(f'Total addresses: [bold]{network.num_addresses:,}[/bold]')
    console.print(f'IP ranges: [bold]{network.network_address}[/bold] -> [bold]{network.broadcast_address}[/bold]')

    binary_mask_with_dots = '.'.join([
        f'{int(octet):08b}' 
        for octet in network.netmask.packed
    ])

    # Create a table for binary mask representation
    binary_mask_table = Table(show_header=True, header_style="bold magenta")
    binary_mask_table.add_column("System", style="dim", width=12)
    binary_mask_table.add_column("First", justify="center")
    binary_mask_table.add_column("Second", justify="center")
    binary_mask_table.add_column("Third", justify="center")
    binary_mask_table.add_column("Fourth", justify="center")

    binary_mask_table.add_row(
        "Decimal", 
        str(network.netmask).split('.')[0], 
        str(network.netmask).split('.')[1], 
        str(network.netmask).split('.')[2],
        str(network.netmask).split('.')[3]
    )

    binary_mask_table.add_row(
        "Binary", 
        binary_mask_with_dots.split('.')[0], 
        binary_mask_with_dots.split('.')[1], 
        binary_mask_with_dots.split('.')[2],
        binary_mask_with_dots.split('.')[3]
    )

    console.print(binary_mask_table)
    # Print colored footer to separate the outputs
    console.print("─" * 60, style="bold Red")

# Assuming the first argument is the network CIDR
cider = sys.argv[1]  
network = ip_network(cider)

print_network_info(network)

# Example for a second network, if provided
if len(sys.argv) > 2:
    cider_two = sys.argv[2]
    network_two = ip_network(cider_two)
    print_network_info(network_two)

    # Print "Summary:" in Red as header for summary section
    console.print("[bold red]Summary:[/bold red]")

    # Check if network_two is a subnet of network
    if network_two.subnet_of(network):
        console.print(f"The network [bold cyan]{network_two}[/bold cyan] is a subnet of [bold cyan]{network}[/bold cyan].", style="bold green")
        # Calculate and print the percentage
        percentage_network2_in_network1 = (network_two.num_addresses / network.num_addresses) * 100
        console.print(f"- [bold cyan]{network_two}[/bold cyan] represents [bold magenta]{percentage_network2_in_network1:.4f}%[/bold magenta] of the network [bold cyan]{network}[/bold cyan].", style="bold green")

        # How many of network_two can fit in network
        console.print(f"- You can fit [bold]{int(network.num_addresses / network_two.num_addresses)}[/bold] networks like [bold cyan]{network_two}[/bold cyan] in [bold cyan]{network}[/bold cyan].", style="bold green")
    else:
        console.print(f"The network [bold cyan]{network_two}[/bold cyan] is not a subnet of [bold cyan]{network}[/bold cyan].", style="bold green")
