# shellcheck shell=sh

Describe "pgp-expire-partitions"
    # NOTE: Generating test cases dynamically from files
    Parameters:dynamic
        for input in tests/fixtures/expire_partitions/*.yaml; do
            # Get the file name
            file_name="${input%.yaml}"
            file_name="${file_name##*/}"
            %data "$input" "${input%.yaml}.expected" "tests/migrations/${file_name}.result"
        done
    End
    Data < "$1" # NOTE: Treat a file as stdin data

    It "expires partitions with valid config ($1)"
        When run script pgp-expire-partitions -c "$1"
        #The output should be present # See: https://github.com/shellspec/shellspec/issues/122
        #diff -u "$2" "$3"
        The status should be success
    End
End
