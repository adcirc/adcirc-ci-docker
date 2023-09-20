#!/usr/bin/env python3

import yaml
import argparse
import json

p = argparse.ArgumentParser(description="Add Flags to Spack Compilers File In Place")
p.add_argument("filename", type=str, help="Name of the file to perform the replacement")
p.add_argument("compiler", type=str, help="Approximate name of the compiler to run for")

args = p.parse_args()
fflags = "-heap-arrays 8192"

print("Spack Compiler Editor", flush=True)
print(
    "Begin adding flags to selected compiler: {:s}, {:s}".format(
        args.compiler, fflags, args.filename
    ),
    flush=True,
)

with open(args.filename, "r") as f:
    yml = yaml.safe_load(f)

for c in yml["compilers"]:
    if args.compiler in c["compiler"]["spec"]:
        print(
            "Found compiler in spec: {:s}, Adding flags {:s}".format(
                c["compiler"]["spec"], fflags
            ),
            flush=True,
        )
        c["compiler"]["flags"]["fflags"] = fflags

print("Modified compilers.yaml below: ", flush=True)
print(json.dumps(yml, indent=2), flush=True)

with open(args.filename, "w") as f:
    yaml.dump(yml, f)
