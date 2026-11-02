#!/usr/bin/env python3
"""Build and run offline checks using the App's actual academic Swift sources."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--swiftsoup-path", type=Path, required=True,
                        help="An existing trusted SwiftSoup checkout; no download is performed")
    args = parser.parse_args()
    soup = args.swiftsoup_path.resolve()
    if not (soup / "Package.swift").is_file():
        parser.error("SwiftSoup checkout is missing Package.swift")
    repository = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="ntpuone-academic-checks-") as directory:
        root = Path(directory)
        sources = root / "Sources" / "AcademicChecks"
        sources.mkdir(parents=True)
        (root / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "AcademicChecks", platforms: [.macOS(.v13)], dependencies: [.package(path: SOUP)], targets: [.executableTarget(name: "AcademicChecks", dependencies: [.product(name: "SwiftSoup", package: "SwiftSoup")])])
'''.replace("SOUP", json.dumps(str(soup))))
        for name in ("AcademicPolicy.swift", "AcademicAPI.swift", "CourseCatalogService.swift"):
            (sources / name).symlink_to(repository / "NTPUOne" / "Academic" / name)
        (sources / "AcademicIntegrationChecks.swift").symlink_to(repository / "tests/AcademicIntegrationChecks.swift")
        course_source = (repository / "NTPUOne/CourseList/CourseGet.swift").read_text()
        model = course_source[course_source.index("struct CourseG:"):course_source.index("// ViewModel")]
        (sources / "CourseModel.swift").write_text("import Foundation\n" + model)
        result = subprocess.run(["swift", "run", "--package-path", str(root), "AcademicChecks"], check=False)
        return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
