#!/bin/bash

TEST_FILE=$(pwd)/one_per_line_sqlite_subset

./base-scenario/run.sh "$TEST_FILE"

./javacc-original/run.sh "$TEST_FILE"
./javacc-modified/run.sh "$TEST_FILE"
./jflex/run.sh "$TEST_FILE"

./javacc-extractor-original/run.sh "$TEST_FILE"
./jflex-extractor/run.sh "$TEST_FILE"

if (! diff -w ./javacc-modified/out ./javacc-original > /dev/null)
then
  echo -e "\033[1;31mERROR:\033[0m javacc-modified has different output than javacc-original"
fi
if (! diff -w ./jflex/out ./javacc-original > /dev/null)
then
  echo -e "\033[1;31mERROR:\033[0m jflex has different output than javacc-original"
fi

if (! diff -w ./jflex-extractor/out ./javacc-extractor-original > /dev/null)
then
  echo -e "\033[1;31mERROR:\033[0m jflex-extractor has different output than javacc-extractor-original"
fi

echo -e "\n\n\033[1;32mRESULTS:\033[0m"
find . -name "*.jfr" -exec echo $(pwd)/{} \;