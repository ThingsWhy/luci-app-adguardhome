#!/bin/sh
set -eu

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

script_files="root/etc/init.d/AdGuardHome
root/usr/share/AdGuardHome/addhost.sh
root/usr/share/AdGuardHome/getsyslog.sh
root/usr/share/AdGuardHome/gfw2adg.sh
root/usr/share/AdGuardHome/gfwipset2adg.sh
root/usr/share/AdGuardHome/update_core.sh
root/usr/share/AdGuardHome/waitnet.sh
root/usr/share/AdGuardHome/watchconfig.sh"

echo "[1/6] Checking executable bits"
printf '%s\n' "$script_files" | while IFS= read -r file; do
    [ -n "$file" ] || continue
    mode="$(git ls-files -s -- "$file" | awk '{print $1}')"
    [ "$mode" = "100755" ] || fail "$file has git mode ${mode:-missing}, expected 100755"
done

echo "[2/6] Checking BusyBox ash syntax and shebangs"
printf '%s\n' "$script_files" | while IFS= read -r file; do
    [ -f "$file" ] || fail "missing script: $file"
    first_line="$(sed -n '1p' "$file")"
    case "$first_line" in
        '#!/bin/sh'|'#!/bin/sh /etc/rc.common') ;;
        *) fail "$file uses unsupported shebang: $first_line" ;;
    esac
    busybox sh -n "$file"
done

echo "[3/6] Checking Lua syntax"
find luasrc -type f -name '*.lua' -print | while IFS= read -r file; do
    luac5.1 -p "$file"
done

echo "[4/6] Checking JSON syntax"
find root -type f -name '*.json' -print | while IFS= read -r file; do
    jq empty "$file"
done

echo "[5/6] Checking translation catalogs"
find po -type f -name '*.po' -print | while IFS= read -r file; do
    msgfmt --check -o /dev/null "$file"
done

echo "[6/6] Checking explicit first-run policy"
[ ! -e root/usr/share/AdGuardHome/AdGuardHome_template.yaml ] || fail "bundled AdGuard Home template must not be shipped"
if grep -R -n -E 'AdGuardHome_template\.yaml|gettemplateconfig|get_template_config|use_template|Fast config|Use template' \
    luasrc root README.md README.CN.md po; then
    fail "legacy template/fast-config coupling detected"
fi

echo "Static checks passed."
