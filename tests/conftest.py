"""Common testing fixtures."""

import json
import os
import pathlib
import shutil
import subprocess
import tempfile
from collections.abc import Callable, Generator
from contextlib import contextmanager
from typing import Any

import pytest
from google import auth
from google.cloud import compute_v1

DEFAULT_PREFIX = "mrpn"
DEFAULT_TF_STATE_PREFIX = "tests/terraform-google-multi-region-private-network"


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
def tf_state_bucket() -> str:
    """Return the Google Cloud Storage bucket name to use for tofu/terraform state files."""
    bucket = os.getenv("TEST_GOOGLE_TF_STATE_BUCKET")
    if bucket:
        bucket = bucket.strip()
    assert bucket
    return bucket


@pytest.fixture(scope="session")
def tf_state_prefix() -> str:
    """Return the prefix to use for tofu/terraform state files in bucket.

    Preference will be given to the variable TEST_GOOGLE_TF_STATE_PREFIX with fallback to the default value of
    'tests/terraform-google-f5-bigip-ha'.
    """
    prefix = os.getenv("TEST_GOOGLE_TF_STATE_PREFIX", DEFAULT_TF_STATE_PREFIX)
    if prefix:
        prefix = prefix.strip()
    if not prefix:
        prefix = DEFAULT_TF_STATE_PREFIX
    assert prefix
    return prefix


@pytest.fixture(scope="session")
def backend_tf_builder(tf_state_bucket: str, tf_state_prefix: str) -> Callable[[pathlib.Path, str], None]:
    """Create or overwrite a _backend.tf file in the provided fixture_dir that configures GCS backend for state."""

    def _backend_tf(fixture_dir: pathlib.Path, name: str) -> None:
        assert fixture_dir.exists()
        assert name
        fixture_dir.joinpath("_backend.tf").write_text(
            "\n".join(
                [
                    "terraform {",
                    '  backend "gcs" {',
                    f'    bucket = "{tf_state_bucket}"',
                    f'    prefix = "{tf_state_prefix}/{name}"',
                    "  }",
                    "}",
                ],
            ),
        )

    return _backend_tf


@pytest.fixture(scope="session")
def common_fixture_dir_ignores() -> Callable[[Any, list[str]], set[str]]:
    """Return a set of ignore patterns that are unrelated to module sources or supporting files."""
    return shutil.ignore_patterns(".*", "*.md", "*.toml", "uv.lock", "tests")


@pytest.fixture(scope="session")
def root_fixture_dir(
    tmp_path_factory: pytest.TempPathFactory,
    backend_tf_builder: Callable[..., None],
    common_fixture_dir_ignores: Callable[[Any, list[str]], set[str]],
) -> Callable[[str], pathlib.Path]:
    """Return a builder that makes a copy of the root module with backend configured appropriately."""
    root_module_dir = pathlib.Path(__file__).parent.parent.resolve()
    assert root_module_dir.exists()
    assert root_module_dir.is_dir()
    assert root_module_dir.joinpath("main.tf").exists()
    assert root_module_dir.joinpath("outputs.tf").exists()
    assert root_module_dir.joinpath("variables.tf").exists()

    def _builder(name: str) -> pathlib.Path:
        fixture_dir = tmp_path_factory.mktemp(name)
        shutil.copytree(
            src=root_module_dir,
            dst=fixture_dir,
            dirs_exist_ok=True,
            ignore=common_fixture_dir_ignores,
        )
        backend_tf_builder(
            fixture_dir=fixture_dir,
            name=name,
        )
        return fixture_dir

    return _builder


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


def get_tf_command() -> str:
    """Return an explicit command to use for module execution or the first tofu or terraform binary found in PATH.

    NOTE: Preference will be given to the value of environment variable TEST_TF_COMMAND.
    """
    tf_command = os.getenv("TEST_TF_COMMAND") or shutil.which("tofu") or shutil.which("terraform")
    assert tf_command, "A tofu or terraform binary could not be determined"
    return tf_command


@contextmanager
def run_tofu_in_workspace(
    fixture: pathlib.Path,
    tfvars: dict[str, Any] | None,
    workspace: str | None = None,
    tf_command: str | None = None,
) -> Generator[dict[str, Any], None, None]:
    """Execute tofu fixture lifecycle in an optional workspace, yielding the output post-apply.

    NOTE: Resources will not be destroyed if the test case raises an error.
    """
    if tfvars is None:
        tfvars = {}
    if not tf_command:
        tf_command = get_tf_command()
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
        delete=True,
    ) as tfvar_file:
        json.dump(tfvars, tfvar_file, ensure_ascii=False, indent=2)
        tfvar_file.close()
        # Validate module
        subprocess.run(
            [
                tf_command,
                f"-chdir={fixture!s}",
                "validate",
                "-no-color",
                f"-var-file={tfvar_file.name}",
            ],
            check=True,
            capture_output=True,
        )
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
