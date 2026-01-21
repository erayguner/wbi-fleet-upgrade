#!/usr/bin/env python3
"""
Vertex AI Workbench Instances Fleet Upgrade & Rollback Tool (REST v2)

- Upgrade instances (default)
- Rollback instances with --rollback

This script supports running directly from a source checkout that uses a
modern src/ layout. If the package is not installed and `fleet_upgrader`
cannot be imported, it will add the local `src/` directory to sys.path and
retry the import. For production use, prefer installing the project and
using the provided console script.
"""

import argparse
import os
import sys
from typing import List

# Add src/ to path to import modules directly
REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
SRC_PATH = os.path.join(REPO_ROOT, "src")
if SRC_PATH not in sys.path:
    sys.path.insert(0, SRC_PATH)

from upgrader import FleetUpgrader
from config import UpgraderConfig
from log_utils import setup_logging
from rollback import FleetRollback


def build_parser() -> argparse.ArgumentParser:
    """Build and return the CLI argument parser."""
    parser = argparse.ArgumentParser(
        description=(
            "Vertex AI Workbench Instances Fleet Upgrade & Rollback Tool\n\n"
            "Production-ready tool for managing WBI instance upgrades and rollbacks at scale.\n"
            "Supports fleet operations, automatic rollback, health checks, and comprehensive reporting."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  # Dry-run upgrade (check what would happen)\n"
            "  python3 main.py --project my-project --locations europe-west2-a --dry-run\n\n"
            "  # Upgrade fleet with rollback protection\n"
            "  python3 main.py --project my-project --locations europe-west2-a --rollback-on-failure\n\n"
            "  # Upgrade single instance\n"
            "  python3 main.py --project my-project --locations europe-west2-a --instance my-notebook\n\n"
            "  # Check rollback eligibility\n"
            "  python3 main.py --project my-project --locations europe-west2-a --rollback --dry-run\n\n"
            "  # Rollback instance\n"
            "  python3 main.py --project my-project --locations europe-west2-a --instance my-notebook --rollback\n\n"
            "Documentation: https://github.com/yourusername/wbi-fleet-upgrade\n"
            "Quickstart: See QUICKSTART.md for detailed setup instructions\n"
            "Operations: See OPERATIONS.md for production procedures"
        ),
    )

    # Required arguments
    required = parser.add_argument_group("required arguments")
    required.add_argument(
        "--project",
        required=True,
        metavar="PROJECT_ID",
        help="GCP project ID containing Workbench instances",
    )
    required.add_argument(
        "--locations",
        required=True,
        nargs="+",
        metavar="ZONE",
        help=(
            "One or more GCP zones to scan for instances "
            "(e.g., europe-west2-a us-central1-a)"
        ),
    )

    # Operation mode
    mode = parser.add_argument_group("operation mode")
    mode.add_argument(
        "--instance",
        metavar="INSTANCE_ID",
        help=(
            "Target specific instance by ID (single instance mode). "
            "If not specified, operates on all instances in the specified locations (fleet mode)."
        ),
    )
    mode.add_argument(
        "--rollback",
        action="store_true",
        help=(
            "Rollback mode: revert instances to previous version instead of upgrading. "
            "Only available if instance was recently upgraded and snapshot exists."
        ),
    )
    mode.add_argument(
        "--dry-run",
        action="store_true",
        help=(
            "Dry-run mode: simulate operations without making changes. "
            "ALWAYS run dry-run first to preview what will happen. "
            "(RECOMMENDED)"
        ),
    )

    # Safety and control
    safety = parser.add_argument_group("safety and control")
    safety.add_argument(
        "--rollback-on-failure",
        action="store_true",
        help=(
            "Automatically rollback if upgrade fails or times out (upgrade mode only). "
            "Recommended for production instances."
        ),
    )
    safety.add_argument(
        "--max-parallel",
        type=int,
        default=5,
        metavar="N",
        help=(
            "Maximum number of concurrent operations (default: 5). "
            "Lower values = safer/slower, higher values = faster but may cause API throttling. "
            "Recommended: 5-10 for production, 10-20 for development."
        ),
    )
    safety.add_argument(
        "--stagger-delay",
        type=float,
        default=3.0,
        metavar="SECONDS",
        help=(
            "Delay between starting operations to avoid API throttling (default: 3.0 seconds). "
            "Increase if experiencing rate limit errors."
        ),
    )

    # Timeouts
    timeouts = parser.add_argument_group("timeouts")
    timeouts.add_argument(
        "--timeout",
        type=int,
        default=7200,
        metavar="SECONDS",
        help=(
            "Maximum time to wait for each operation to complete (default: 7200 = 2 hours). "
            "Increase for large instances or slow regions."
        ),
    )
    timeouts.add_argument(
        "--health-check-timeout",
        type=int,
        default=600,
        metavar="SECONDS",
        help=(
            "Maximum time to wait for instance to become ACTIVE after operation (default: 600 = 10 minutes). "
            "Increase if instances take longer to start."
        ),
    )
    timeouts.add_argument(
        "--poll-interval",
        type=int,
        default=20,
        metavar="SECONDS",
        help=(
            "Time between operation status checks (default: 20 seconds). "
            "Lower values = more API calls, higher values = less frequent updates."
        ),
    )

    # Logging
    logging_group = parser.add_argument_group("logging and output")
    logging_group.add_argument(
        "--verbose",
        action="store_true",
        help=(
            "Enable verbose logging with detailed progress information. "
            "Useful for debugging and monitoring operations."
        ),
    )

    return parser


def main(argv: List[str] | None = None) -> None:
    """Entry point for CLI execution."""
    parser = build_parser()
    args = parser.parse_args(args=argv)

    # Use a dedicated log file for rollback runs (optional but nice)
    log_file = "workbench-rollback.log" if args.rollback else "workbench-upgrade.log"
    setup_logging(verbose=args.verbose, log_file=log_file)

    # Build config (assuming UpgraderConfig expects these arg names)
    config = UpgraderConfig.from_args(args)

    if args.rollback:
        runner = FleetRollback(
            project_id=config.project_id,
            locations=config.locations,
            dry_run=config.dry_run,
            max_parallel=config.max_parallel,
            timeout=config.timeout,
            poll_interval=config.poll_interval,
            health_check_timeout=config.health_check_timeout,
            stagger_delay=config.stagger_delay,
        )
        stats = runner.run(instance_id=args.instance)
    else:
        runner = FleetUpgrader(
            project_id=config.project_id,
            locations=config.locations,
            dry_run=config.dry_run,
            max_parallel=config.max_parallel,
            timeout=config.timeout,
            poll_interval=config.poll_interval,
            rollback_on_failure=config.rollback_on_failure,
            health_check_timeout=config.health_check_timeout,
            stagger_delay=config.stagger_delay,
        )
        stats = runner.run(instance_id=args.instance)

    sys.exit(1 if stats.get("failed", 0) > 0 else 0)


if __name__ == "__main__":
    main()
