#!/bin/bash

gn gen out.gn/x64.release --args='is_debug=false target_cpu="x64" is_component_build = true'
