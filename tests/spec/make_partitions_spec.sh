# shellcheck shell=sh

Describe "pgp-make-partitions"
  # NOTE: Generating test cases dynamically from files
  Parameters:dynamic
    for input in tests/fixtures/make_partitions/*.yaml
    do
      name="$(basename "${input%.yaml}")"
      %data "$input" "${input%.yaml}.expected" "/tmp/V1__${name}.result"
    done
  End
  Data < "$1" # NOTE: Treat a file as stdin data

  It "makes partitions with valid config ($1)"
    When run script pgp-make-partitions -c "$1"
    The output should be present # See: https://github.com/shellspec/shellspec/issues/122
    diff -u "$2" "$3"
    The status should be success
    # Clean up dynamically created result file
    rm -f "$3"

  End
End
