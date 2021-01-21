#!/bin/bash

./base-scenario/run.sh $(pwd)/one_per_line_sqlite_subset
./javacc-original/run.sh $(pwd)/one_per_line_sqlite_subset
./javacc-modified/run.sh $(pwd)/one_per_line_sqlite_subset
./jflex/run.sh $(pwd)/one_per_line_sqlite_subset
