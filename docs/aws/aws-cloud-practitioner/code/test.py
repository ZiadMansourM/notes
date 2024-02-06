from ipaddress import ip_network
import sys
from rich.console import Console
from rich.table import Table
from rich.layout import Layout
# Import Panel to display the network information
from rich.panel import Panel

# Initialize rich console
console = Console()

def create_network_info_table(network):
    table = Table(show_header=True, header_style="bold magenta")
    table.add_column("System", style="dim", width=12)
    table.add_column("First", justify="center")
    table.add_column("Second", justify="center")
    table.add_column("Third", justify="center")
    table.add_column("Fourth", justify="center")

    binary_mask_with_dots = '.'.join([
        f'{int(octet):08b}'
        for octet in network.netmask.packed
    ])

    table.add_row(
        "Decimal",
        *str(network.netmask).split('.')
    )

    table.add_row(
        "Binary",
        *binary_mask_with_dots.split('.')
    )

    return table

def print_network_info(layout, network, side):
    layout[side].update(Panel(f'[bold cyan]Network {network}[/bold cyan]\n\n' +
                              f'The network is {"private" if network.is_private else "public"}\n' +
                              f'Mask: [bold yellow]{network.netmask}[/bold yellow]\n' +
                              f'Total addresses: [bold]{network.num_addresses:,}[/bold]\n' +
                              f'IP ranges: [bold]{network.network_address}[/bold] -> [bold]{network.broadcast_address}[/bold]\n',
                              expand=True))
    layout[side].update(create_network_info_table(network))

cider = sys.argv[1]
network = ip_network(cider)

# Check if a second network is provided
if len(sys.argv) > 2:
    cider_two = sys.argv[2]
    network_two = ip_network(cider_two)

    layout = Layout()
    layout.split_column(
        Layout(name="left"),
        Layout(name="right")
    )

    print_network_info(layout, network, "left")
    print_network_info(layout, network_two, "right")

    console.print(layout)

    # Calculate and print the percentage
    percentage_network2_in_network1 = (network_two.num_addresses / network.num_addresses) * 100
    console.print(f"The network [bold cyan]{network_two}[/bold cyan] represents [bold magenta]{percentage_network2_in_network1:.4f}%[/bold magenta] of the network [bold cyan]{network}[/bold cyan].", style="bold green")
else:
    # Single network display
    table = create_network_info_table(network)
    console.print(table)
