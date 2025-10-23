"""Test fixture for dual-region deployment with PSC."""

import pathlib
import re
from collections.abc import Generator
from typing import Any, cast

import pytest
from google.cloud import compute_v1

from .conftest import run_tofu_in_workspace

FIXTURE_NAME = "psc"
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
                "us-central1",
            ],
            "psc": {
                "address": "10.10.10.10",
            },
            "labels": fixture_labels,
        },
    ) as output:
        yield output


def test_output_values(output: dict[str, Any], project_id: str, fixture_name: str) -> None:
    """Verify the output values match expectations."""
    assert output == {
        "self_link": f"https://www.googleapis.com/compute/v1/projects/{project_id}/global/networks/{fixture_name}",
        "id": f"projects/{project_id}/global/networks/{fixture_name}",
        "subnets_by_name": {
            f"{fixture_name}-us-we1": {
                "region": "us-west1",
                "self_link": f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-west1/subnetworks/{fixture_name}-us-we1",
                "id": f"projects/{project_id}/regions/us-west1/subnetworks/{fixture_name}-us-we1",
                "primary_ipv4_cidr": "172.16.0.0/24",
                "primary_ipv6_cidr": "",
                "secondary_ipv4_cidrs": {},
                "gateway_address": "172.16.0.1",
            },
            f"{fixture_name}-us-ce1": {
                "region": "us-central1",
                "self_link": f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-central1/subnetworks/{fixture_name}-us-ce1",
                "id": f"projects/{project_id}/regions/us-central1/subnetworks/{fixture_name}-us-ce1",
                "primary_ipv4_cidr": "172.16.1.0/24",
                "primary_ipv6_cidr": "",
                "secondary_ipv4_cidrs": {},
                "gateway_address": "172.16.1.1",
            },
        },
        "subnets_by_region": {
            "us-west1": {
                "name": f"{fixture_name}-us-we1",
                "self_link": f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-west1/subnetworks/{fixture_name}-us-we1",
                "id": f"projects/{project_id}/regions/us-west1/subnetworks/{fixture_name}-us-we1",
                "primary_ipv4_cidr": "172.16.0.0/24",
                "primary_ipv6_cidr": "",
                "secondary_ipv4_cidrs": {},
                "gateway_address": "172.16.0.1",
            },
            "us-central1": {
                "name": f"{fixture_name}-us-ce1",
                "self_link": f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-central1/subnetworks/{fixture_name}-us-ce1",
                "id": f"projects/{project_id}/regions/us-central1/subnetworks/{fixture_name}-us-ce1",
                "primary_ipv4_cidr": "172.16.1.0/24",
                "primary_ipv6_cidr": "",
                "secondary_ipv4_cidrs": {},
                "gateway_address": "172.16.1.1",
            },
        },
    }


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
    assert not result.enable_ula_internal_ipv6
    assert result.mtu == 1460  # noqa: PLR2004
    assert result.name == fixture_name
    assert not result.peerings
    assert result.routing_config.routing_mode == "GLOBAL"
    assert result.subnetworks
    for subnetwork in result.subnetworks:
        assert subnetwork in [
            f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-west1/subnetworks/{fixture_name}-us-we1",
            f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-central1/subnetworks/{fixture_name}-us-ce1",
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
    assert not result.internal_ipv6_prefix
    assert result.ip_cidr_range == "172.16.0.0/24"
    assert not result.ipv6_cidr_range
    assert not result.log_config.enable
    assert result.name == f"{fixture_name}-us-we1"
    assert (
        result.network == f"https://www.googleapis.com/compute/v1/projects/{project_id}/global/networks/{fixture_name}"
    )
    assert result.private_ip_google_access
    assert result.private_ipv6_google_access == "DISABLE_GOOGLE_ACCESS"
    assert result.purpose == "PRIVATE"
    assert result.region == f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-west1"
    assert not result.role
    assert not result.secondary_ip_ranges
    assert result.stack_type == "IPV4_ONLY"
    assert not result.state


def test_subnetwork_us_central1(
    subnetworks_client: compute_v1.SubnetworksClient,
    project_id: str,
    fixture_name: str,
) -> None:
    """Verify the subnetwork exists and matches expectations."""
    result = subnetworks_client.get(
        request=compute_v1.GetSubnetworkRequest(
            subnetwork=f"{fixture_name}-us-ce1",
            project=project_id,
            region="us-central1",
        ),
    )
    assert result
    assert not result.description
    assert not result.enable_flow_logs
    assert not result.external_ipv6_prefix
    assert not result.internal_ipv6_prefix
    assert result.ip_cidr_range == "172.16.1.0/24"
    assert not result.ipv6_cidr_range
    assert not result.log_config.enable
    assert result.name == f"{fixture_name}-us-ce1"
    assert (
        result.network == f"https://www.googleapis.com/compute/v1/projects/{project_id}/global/networks/{fixture_name}"
    )
    assert result.private_ip_google_access
    assert result.private_ipv6_google_access == "DISABLE_GOOGLE_ACCESS"
    assert result.purpose == "PRIVATE"
    assert result.region == f"https://www.googleapis.com/compute/v1/projects/{project_id}/regions/us-central1"
    assert not result.role
    assert not result.secondary_ip_ranges
    assert result.stack_type == "IPV4_ONLY"
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
    assert len(restricted_apis_routes) == 0
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
    assert len(routers) == 0


def test_routers_us_central1(routers_client: compute_v1.RoutersClient, project_id: str, fixture_name: str) -> None:
    """Verify the router and NAT meets requirements."""
    routers = list(
        routers_client.list(
            request=compute_v1.ListRoutersRequest(
                project=project_id,
                region="us-central1",
                filter=f"network eq .*/{fixture_name}$",
            ),
        ),
    )
    assert len(routers) == 0


def test_psc(
    global_addresses_client: compute_v1.GlobalAddressesClient,
    global_forwarding_rules_client: compute_v1.GlobalForwardingRulesClient,
    project_id: str,
    fixture_name: str,
    fixture_labels: dict[str, str],
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
    assert len(global_addresses) == 1
    for global_address in global_addresses:
        assert global_address.name == fixture_name
        assert global_address.address == "10.10.10.10"
        assert global_address.address_type == "INTERNAL"
        assert global_address.purpose == "PRIVATE_SERVICE_CONNECT"
    global_forwarding_rules = list(
        global_forwarding_rules_client.list(
            request=compute_v1.ListGlobalForwardingRulesRequest(
                project=project_id,
                filter=f"network eq .*/{fixture_name}$",
            ),
        ),
    )
    assert len(global_forwarding_rules) == 1
    for global_forwarding_rule in global_forwarding_rules:
        expected_name = re.sub(r"[^a-z0-9]", "", fixture_name)[:20]
        assert global_forwarding_rule.name == expected_name
        labels = cast("dict[str, str]", global_forwarding_rule.labels)
        assert labels is not None
        assert all(item in labels.items() for item in fixture_labels.items())
        assert global_forwarding_rule.I_p_address == "10.10.10.10"
        assert global_forwarding_rule.I_p_protocol == "TCP"
        assert not global_forwarding_rule.all_ports
        assert not global_forwarding_rule.ports
        assert not global_forwarding_rule.allow_global_access
        assert not global_forwarding_rule.allow_psc_global_access
        assert not global_forwarding_rule.backend_service
        assert not global_forwarding_rule.external_managed_backend_bucket_migration_state
        assert not global_forwarding_rule.external_managed_backend_bucket_migration_testing_percentage
        assert not global_forwarding_rule.load_balancing_scheme
        assert global_forwarding_rule.target == "vpc-sc"
        assert global_forwarding_rule.service_directory_registrations
        assert len(global_forwarding_rule.service_directory_registrations) == 1
        for service_directory_registration in global_forwarding_rule.service_directory_registrations:
            assert service_directory_registration.namespace  # Google generated value
            assert not service_directory_registration.service
            assert service_directory_registration.service_directory_region == "us-central1"
