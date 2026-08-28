Name: zig-markdown-viewer
Version: 1.0
Release: 1%{?dist}
License: MIT
BuildRequires: zig

%description
A native Markdown viewer.

%build
flags="-Doptimize=ReleaseSmall"
./build.sh "$flags"

%install
mkdir -p %{buildroot}/usr/bin
cp viewer %{buildroot}/usr/bin/

%files
%doc README.md
/usr/bin/viewer

%changelog
* Thu Aug 27 2026 Viewer <viewer@example.test> - 1.0-1
- Initial package
