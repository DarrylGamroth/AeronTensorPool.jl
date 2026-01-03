#!/usr/bin/env julia

using SBE

# Define paths
const PACKAGE_ROOT = dirname(@__DIR__)
const SCHEMA_PATH = joinpath(PACKAGE_ROOT, "schemas", "wire-schema.xml")
const OUTPUT_FILE = joinpath(PACKAGE_ROOT, "src", "gen", "ShmTensorpoolControl.jl")

# Generate code from schema
SBE.generate(SCHEMA_PATH, OUTPUT_FILE)
