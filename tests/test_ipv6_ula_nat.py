"""Test fixture for dual-region deployment with IPv6 ULA and Cloud NAT enabled."""

import ipaddress
import pathlib
from collections.abc import Generator
from typing import Any

import pytest
from google.cloud import compute_v1

from .conftest import run_tofu_in_workspace

FIXTURE_NAME = "ipv6-ula-nat"
FIXTURE_LABELS = {
    "fixture": FIXTURE_NAME,
}


@pytest.fixture(scope="module")
def fixture_name(prefix: str) -> str:
    """Return the name to use for resources in this module."""
    return f"{prefix}-{FIXTURE_NAME}"


@pytest.fixture(scope="module")
def fixture_labels(labels: dict[str, str]) -> dict[str, str] | None:
    """Return a dict of labels for this test module."""
    return FIXTURE_LABELS | labels


@pytest.fixture(scope="module")
def output(
    root_fixture_dir: pathlib.Path,
    project_id: str,
    fixture_name: str,
    fixture_labels: dict[str, str],
) -> Generator[dict[str, Any], None, None]:
    """Execute Tofu (or Terraform) with the input vars suitable for this fixture, yielding the module output."""
    with run_tofu_in_workspace(
        fixture=root_fixture_dir,
        workspace=fixture_name,
        tfvars={
            "project_id": project_id,
            "name": fixture_name,
            "regions": [
                "us-west1",
                "us-east1",
            ],
            "options": {
                "ipv6_ula": True,
            },
            "nat": {},
            "labels": fixture_labels,
        },
    ) as output:
        yield output


def test_output_values(output: dict[str, Any], project_id: str, fixture_name: str) -> None:
    """Verify the output values match expectations."""
    assert (
        output["self_link"]
        == f"https://www.googleapis.com/compute/v1/projects/{project_id}/global/networks/{fixture_name}"
    )
    assert output["id"] == f"projects/{project_id}/global/networks/{fixture_name}"
    assert output["subnets_by_name"]
    assert output["subnets_by_name"][f"{fixture_name}-us-we1"]
    subnet = output["subnets_by_name"][f"{fixture_name}-us-we1"]
    assert subnet["region"] == "us-west1"
    assert (
        subnet["self_link"]
        == f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-west1/subnetworks/{fixture_name}-us-we1"
    )
    assert subnet["id"] == f"projects/{project_id}/regions/us-west1/subnetworks/{fixture_name}-us-we1"
    assert subnet["primary_ipv4_cidr"] == "172.16.0.0/24"
    assert subnet["primary_ipv6_cidr"]
    ipv6_cidr = ipaddress.IPv6Network(subnet["primary_ipv6_cidr"])
    assert ipv6_cidr
    assert ipv6_cidr.is_global
    assert subnet["secondary_ipv4_cidrs"] == {}
    assert subnet["gateway_address"] == "172.16.0.1"
    assert output["subnets_by_name"][f"{fixture_name}-us-ea1"]
    subnet = output["subnets_by_name"][f"{fixture_name}-us-ea1"]
    assert subnet["region"] == "us-east1"
    assert (
        subnet["self_link"]
        == f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-east1/subnetworks/{fixture_name}-us-ea1"
    )
    assert subnet["id"] == f"projects/{project_id}/regions/us-east1/subnetworks/{fixture_name}-us-ea1"
    assert subnet["primary_ipv4_cidr"] == "172.16.1.0/24"
    assert subnet["primary_ipv6_cidr"]
    assert ipaddress.IPv6Network(subnet["primary_ipv6_cidr"])
    assert subnet["secondary_ipv4_cidrs"] == {}
    assert subnet["gateway_address"] == "172.16.1.1"

    assert output["subnets_by_region"]
    assert output["subnets_by_region"]["us-west1"]
    subnet = output["subnets_by_region"]["us-west1"]
    assert subnet["name"] == f"{fixture_name}-us-we1"
    assert (
        subnet["self_link"]
        == f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-west1/subnetworks/{fixture_name}-us-we1"
    )
    assert subnet["id"] == f"projects/{project_id}/regions/us-west1/subnetworks/{fixture_name}-us-we1"
    assert subnet["primary_ipv4_cidr"] == "172.16.0.0/24"
    assert subnet["primary_ipv6_cidr"]
    assert ipaddress.IPv6Network(subnet["primary_ipv6_cidr"])
    assert subnet["secondary_ipv4_cidrs"] == {}
    assert subnet["gateway_address"] == "172.16.0.1"
    assert output["subnets_by_region"]["us-east1"]
    subnet = output["subnets_by_region"]["us-east1"]
    assert subnet["name"] == f"{fixture_name}-us-ea1"
    assert (
        subnet["self_link"]
        == f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-east1/subnetworks/{fixture_name}-us-ea1"
    )
    assert subnet["id"] == f"projects/{project_id}/regions/us-east1/subnetworks/{fixture_name}-us-ea1"
    assert subnet["primary_ipv4_cidr"] == "172.16.1.0/24"
    assert subnet["primary_ipv6_cidr"]
    assert ipaddress.IPv6Network(subnet["primary_ipv6_cidr"])
    assert subnet["secondary_ipv4_cidrs"] == {}
    assert subnet["gateway_address"] == "172.16.1.1"


def test_network(networks_client: compute_v1.NetworksClient, project_id: str, fixture_name: str) -> None:
    """Verify the network exists and matches expectations."""
    result = networks_client.get(
        request=compute_v1.GetNetworkRequest(
            network=fixture_name,
            project=project_id,
        ),
    )
    assert result
    assert not result.auto_create_subnetworks
    assert result.description == "custom vpc"
    assert result.enable_ula_internal_ipv6
    assert result.mtu == 1460  # noqa: PLR2004
    assert result.name == fixture_name
    assert not result.peerings
    assert result.routing_config.routing_mode == "GLOBAL"
    assert result.subnetworks
    for subnetwork in result.subnetworks:
        assert subnetwork in [
            f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-west1/subnetworks/{fixture_name}-us-we1",
            f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-east1/subnetworks/{fixture_name}-us-ea1",
        ]


def test_subnetwork_us_west1(
    subnetworks_client: compute_v1.SubnetworksClient,
    project_id: str,
    fixture_name: str,
) -> None:
    """Verify the subnetwork exists and matches expectations."""
    result = subnetworks_client.get(
        request=compute_v1.GetSubnetworkRequest(
            subnetwork=f"{fixture_name}-us-we1",
            project=project_id,
            region="us-west1",
        ),
    )
    assert result
    assert not result.description
    assert not result.enable_flow_logs
    assert not result.external_ipv6_prefix
    assert result.internal_ipv6_prefix
    assert ipaddress.IPv6Network(result.internal_ipv6_prefix)
    assert result.ip_cidr_range == "172.16.0.0/24"
    assert result.ipv6_cidr_range
    ipv6_cidr = ipaddress.IPv6Network(result.ipv6_cidr_range)
    assert ipv6_cidr
    assert ipv6_cidr.is_global
    assert not result.log_config.enable
    assert result.name == f"{fixture_name}-us-we1"
    assert (
        result.network == f"https://www.googleapis.com/compute/v1/projects/{project_id}/global/networks/{fixture_name}"
    )
    assert result.private_ip_google_access
    assert result.private_ipv6_google_access == "ENABLE_OUTBOUND_VM_ACCESS_TO_GOOGLE"
    assert result.purpose == "PRIVATE"
    assert result.region == f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-west1"
    assert not result.role
    assert not result.secondary_ip_ranges
    assert result.stack_type == "IPV4_IPV6"
    assert not result.state


def test_subnetwork_us_east1(
    subnetworks_client: compute_v1.SubnetworksClient,
    project_id: str,
    fixture_name: str,
) -> None:
    """Verify the subnetwork exists and matches expectations."""
    result = subnetworks_client.get(
        request=compute_v1.GetSubnetworkRequest(
            subnetwork=f"{fixture_name}-us-ea1",
            project=project_id,
            region="us-east1",
        ),
    )
    assert result
    assert not result.description
    assert not result.enable_flow_logs
    assert not result.external_ipv6_prefix
    assert result.internal_ipv6_prefix
    assert ipaddress.IPv6Network(result.internal_ipv6_prefix)
    assert result.ip_cidr_range == "172.16.1.0/24"
    assert result.ipv6_cidr_range
    ipv6_cidr = ipaddress.IPv6Network(result.ipv6_cidr_range)
    assert ipv6_cidr
    assert ipv6_cidr.is_global
    assert not result.log_config.enable
    assert result.name == f"{fixture_name}-us-ea1"
    assert (
        result.network == f"https://www.googleapis.com/compute/v1/projects/{project_id}/global/networks/{fixture_name}"
    )
    assert result.private_ip_google_access
    assert result.private_ipv6_google_access == "ENABLE_OUTBOUND_VM_ACCESS_TO_GOOGLE"
    assert result.purpose == "PRIVATE"
    assert result.region == f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-east1"
    assert not result.role
    assert not result.secondary_ip_ranges
    assert result.stack_type == "IPV4_IPV6"
    assert not result.state


def test_routes(routes_client: compute_v1.RoutesClient, project_id: str, fixture_name: str) -> None:
    """Verify the routes meet expectations."""
    routes = list(
        routes_client.list(
            request=compute_v1.ListRoutesRequest(
                project=project_id,
                filter=f"network eq .*/{fixture_name}$",
            ),
        ),
    )
    default_routes = [route for route in routes if route.dest_range in ["0.0.0.0/0", "::/0"] and not route.tags]
    assert len(default_routes) == 0
    restricted_apis_routes = [route for route in routes if route.dest_range == "199.36.153.4/30"]
    assert len(restricted_apis_routes) == 1
    for route in restricted_apis_routes:
        assert route.name == f"{fixture_name}-restricted-apis"
        assert route.description == "Route for restricted Google API access"
        assert (
            route.next_hop_gateway
            == f"https://www.googleapis.com/compute/v1/projects/{project_id}/global/gateways/default-internet-gateway"
        )
        assert route.priority == 1000  # noqa: PLR2004
    private_apis_routes = [route for route in routes if route.dest_range == "199.36.153.8/30"]
    assert len(private_apis_routes) == 0
    tagged_routes = [route for route in routes if route.tags]
    assert len(tagged_routes) == 0


def test_routers_us_west1(routers_client: compute_v1.RoutersClient, project_id: str, fixture_name: str) -> None:
    """Verify the router and NAT meets requirements."""
    routers = list(
        routers_client.list(
            request=compute_v1.ListRoutersRequest(
                project=project_id,
                region="us-west1",
                filter=f"network eq .*/{fixture_name}$",
            ),
        ),
    )
    assert len(routers) == 1
    for router in routers:
        assert router.name == f"{fixture_name}-us-we1"
        assert len(router.nats) == 1
        for nat in router.nats:
            assert nat.name == f"{fixture_name}-us-we1"
            assert not nat.log_config.enable
            assert nat.log_config.filter == "ALL"


def test_routers_us_east1(routers_client: compute_v1.RoutersClient, project_id: str, fixture_name: str) -> None:
    """Verify the router and NAT meets requirements."""
    routers = list(
        routers_client.list(
            request=compute_v1.ListRoutersRequest(
                project=project_id,
                region="us-east1",
                filter=f"network eq .*/{fixture_name}$",
            ),
        ),
    )
    assert len(routers) == 1
    for router in routers:
        assert router.name == f"{fixture_name}-us-ea1"
        assert len(router.nats) == 1
        for nat in router.nats:
            assert nat.name == f"{fixture_name}-us-ea1"
            assert not nat.log_config.enable
            assert nat.log_config.filter == "ALL"


def test_psc(
    global_addresses_client: compute_v1.GlobalAddressesClient,
    global_forwarding_rules_client: compute_v1.GlobalForwardingRulesClient,
    project_id: str,
    fixture_name: str,
) -> None:
    """Verify PSC meets requirements."""
    global_addresses = list(
        global_addresses_client.list(
            request=compute_v1.ListGlobalAddressesRequest(
                project=project_id,
                filter=f"network eq .*/{fixture_name}$",
            ),
        ),
    )
    assert len(global_addresses) == 0
    global_forwarding_rules = list(
        global_forwarding_rules_client.list(
            request=compute_v1.ListGlobalForwardingRulesRequest(
                project=project_id,
                filter=f"network eq .*/{fixture_name}$",
            ),
        ),
    )
    assert len(global_forwarding_rules) == 0
