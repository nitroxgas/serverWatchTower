set -euo pipefail

inventory_parse() {
  local inventory_path="$1"
  local host_only="${2:-}"
  local tags_filter="${3:-}"

  [[ -r "$inventory_path" ]] || die "cannot read inventory: $inventory_path"

  local line
  local is_header=1

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue

    if [[ $is_header -eq 1 ]]; then
      is_header=0
      continue
    fi

    local id address ssh_user ssh_port tags
    IFS=',' read -r id address ssh_user ssh_port tags <<<"$line"

    id="${id//[$'\r\n\t ']/}"
    address="${address//[$'\r\n\t ']/}"

    [[ -n "$id" ]] || continue
    [[ -n "$address" ]] || continue

    if [[ -n "$host_only" ]] && [[ "$host_only" != "$id" ]]; then
      continue
    fi

    if [[ -n "$tags_filter" ]] && ! inventory_tags_match "$tags" "$tags_filter"; then
      continue
    fi

    printf '%s,%s,%s,%s,%s\n' "$id" "$address" "${ssh_user:-}" "${ssh_port:-}" "${tags:-}"
  done <"$inventory_path"
}

inventory_tags_match() {
  local tags="${1:-}"
  local required_csv="${2:-}"

  local req
  IFS=',' read -ra reqs <<<"$required_csv"

  local r
  for r in "${reqs[@]}"; do
    r="${r//[$'\r\n\t ']/}"
    [[ -z "$r" ]] && continue
    case "$tags" in
      *"$r"*)
        ;;
      *)
        return 1
        ;;
    esac
  done

  return 0
}
