"""Common testing fixtures."""

import json
import os
import pathlib
import subprocess
import tempfile
from collections.abc import Generator
from contextlib import contextmanager
from typing import Any

import pytest
from google import auth
from google.cloud import compute_v1

DEFAULT_PREFIX = "mrpn"


@pytest.fixture(scope="session")
def prefix() -> str:
    """Return the prefix to use for test resources.

    Preference will be given to the environment variable TEST_PREFIX with default value of 'mrpn'.
    """
    prefix = os.getenv("TEST_PREFIX", DEFAULT_PREFIX)
    if prefix:
        prefix = prefix.strip()
    if not prefix:
        prefix = DEFAULT_PREFIX
    assert prefix
    return prefix


@pytest.fixture(scope="session")
def project_id() -> str:
    """Return the project id to use for tests.

    Preference will be given to the environment variables TEST_GOOGLE_CLOUD_PROJECT and GOOGLE_CLOUD_PROJECT followed by
    the default project identifier associated with local ADC credentials.
    """
    project_id = os.getenv("TEST_GOOGLE_CLOUD_PROJECT") or os.getenv("GOOGLE_CLOUD_PROJECT")
    if project_id:
        project_id = project_id.strip()
    if not project_id:
        _, project_id = auth.default()
    assert project_id
    return project_id


@pytest.fixture(scope="session")
def labels() -> dict[str, str]:
    """Return a dict of labels to apply to resources from environment variable TEST_GOOGLE_LABELS.

    If the environment variable TEST_GOOGLE_LABELS is not empty and can be parsed as a comma-separated list of key:value
    pairs then return a dict of keys to values.
    """
    raw = os.getenv("TEST_GOOGLE_LABELS")
    if not raw:
        return {}
    return dict([x.split(":") for x in raw.split(",")])


@pytest.fixture(scope="session")
def root_fixture_dir() -> pathlib.Path:
    """Return the fully-qualified directory at the fixture at the root of this repo."""
    root_fixture_dir = pathlib.Path(__file__).parent.joinpath("fixtures/root").resolve()
    assert root_fixture_dir.exists()
    assert root_fixture_dir.is_dir()
    assert root_fixture_dir.joinpath("main.tf").exists()
    assert root_fixture_dir.joinpath("outputs.tf").exists()
    assert root_fixture_dir.joinpath("variables.tf").exists()
    return root_fixture_dir


@pytest.fixture(scope="session")
def networks_client() -> compute_v1.NetworksClient:
    """Return an initialized compute v1 NetworksClient."""
    return compute_v1.NetworksClient()


@pytest.fixture(scope="session")
def subnetworks_client() -> compute_v1.SubnetworksClient:
    """Return an initialized compute v1 SubnetworksClient."""
    return compute_v1.SubnetworksClient()


@pytest.fixture(scope="session")
def routes_client() -> compute_v1.RoutesClient:
    """Return an initialized compute v1 RoutesClient."""
    return compute_v1.RoutesClient()


@pytest.fixture(scope="session")
def routers_client() -> compute_v1.RoutersClient:
    """Return an initialized compute v1 RoutersClient."""
    return compute_v1.RoutersClient()


@pytest.fixture(scope="session")
def global_addresses_client() -> compute_v1.GlobalAddressesClient:
    """Return an initialized compute v1 GlobalAddressesClient."""
    return compute_v1.GlobalAddressesClient()


@pytest.fixture(scope="session")
def global_forwarding_rules_client() -> compute_v1.GlobalForwardingRulesClient:
    """Return an initialized compute v1 GlobalForwardingRulesClient."""
    return compute_v1.GlobalForwardingRulesClient()


def skip_destroy_phase() -> bool:
    """Determine if tofu destroy phase should be skipped for successful fixtures."""
    return os.getenv("TEST_SKIP_DESTROY_PHASE", "False").lower() in ["true", "t", "yes", "y", "1"]


@contextmanager
def run_tofu_in_workspace(
    fixture: pathlib.Path,
    workspace: str | None,
    tfvars: dict[str, Any] | None,
) -> Generator[dict[str, Any], None, None]:
    """Execute tofu fixture lifecycle in an optional workspace, yielding the output post-apply.

    NOTE: Resources will not be destroyed if the test case raises an error.
    """
    if tfvars is None:
        tfvars = {}
    tf_command = os.getenv("TEST_TF_COMMAND", "tofu")
    if workspace is not None and workspace != "":
        subprocess.run(
            [
                tf_command,
                f"-chdir={fixture!s}",
                "workspace",
                "select",
                "-or-create",
                workspace,
            ],
            check=True,
            capture_output=True,
        )
    subprocess.run(
        [
            tf_command,
            f"-chdir={fixture!s}",
            "init",
            "-no-color",
            "-input=false",
        ],
        check=True,
        capture_output=True,
    )
    with tempfile.NamedTemporaryFile(
        mode="w",
        prefix="tfvars",
        suffix=".json",
        encoding="utf-8",
        delete_on_close=False,
        delete=False,
    ) as tfvar_file:
        json.dump(tfvars, tfvar_file, ensure_ascii=False, indent=2)
        tfvar_file.close()
        # Execute plan then apply with a common plan file.
        with tempfile.NamedTemporaryFile(
            mode="w+b",
            prefix="tf",
            suffix=".plan",
            delete_on_close=False,
            delete=True,
        ) as plan_file:
            plan_file.close()
            subprocess.run(
                [
                    tf_command,
                    f"-chdir={fixture!s}",
                    "plan",
                    "-no-color",
                    "-input=false",
                    f"-var-file={tfvar_file.name}",
                    f"-out={plan_file.name}",
                ],
                check=True,
                capture_output=True,
            )
            subprocess.run(
                [
                    tf_command,
                    f"-chdir={fixture!s}",
                    "apply",
                    "-no-color",
                    "-input=false",
                    "-auto-approve",
                    plan_file.name,
                ],
                check=True,
                capture_output=True,
            )

        # Run plan again with -detailed-exitcode flag, which will only return an exit code of 0 if there are no further
        # changes. This is to find subtle issues in the Terraform declaration which inadvertently triggers unexpected
        # resource updates or recreations.
        subprocess.run(
            [
                tf_command,
                f"-chdir={fixture!s}",
                "plan",
                "-no-color",
                "-input=false",
                "-detailed-exitcode",
                f"-var-file={tfvar_file.name}",
            ],
            check=True,
            capture_output=True,
        )
        output = subprocess.run(
            [
                tf_command,
                f"-chdir={fixture!s}",
                "output",
                "-no-color",
                "-json",
            ],
            check=True,
            capture_output=True,
        )
        try:
            yield {k: v["value"] for k, v in json.loads(output.stdout).items()}
            if not skip_destroy_phase():
                subprocess.run(
                    [
                        tf_command,
                        f"-chdir={fixture!s}",
                        "destroy",
                        "-no-color",
                        "-input=false",
                        "-auto-approve",
                        f"-var-file={tfvar_file.name}",
                    ],
                    check=True,
                    capture_output=True,
                )
        finally:
            subprocess.run(
                [
                    tf_command,
                    f"-chdir={fixture!s}",
                    "workspace",
                    "select",
                    "default",
                ],
                check=True,
                capture_output=True,
            )
