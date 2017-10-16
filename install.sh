#!/usr/bin/env bash

function run_command {
    command_name=$1;
    echo $command_name;
    shift;
    "$@"
    status=$?
    if [ $status -ne 0 ]; then
        echo "Error: $command_name";
        exit;
    fi
    echo "Passed: $command_name";
    return $status
}

if ! [ -x "$(command -v cpanm)" ]; then
  echo 'Error: cpanm is not installed. Installing...' >&2
  eval "curl -L https://cpanmin.us | perl - --sudo App::cpanminus"
fi

eval "cpanm -L . --installdeps ." > /dev/null 2>&1

mkdir tmp

run_command "TESTING get-gene-info.pl" eval "./get-gene-info.pl -type=ncbi -file=test.txt -column=hgnc_id -column=symbol -column=name -column=entrez_id > /dev/null 2>&1"