autoload -Uz log_debug log_error log_info log_status log_output

## Dependency Information
local name='uthash'
local version='2.3.0'
local url='https://github.com/troydhanson/uthash.git'
local hash='a49bed0b4abb7dff16c73906dcdc8a9718d582d2'

## Build Steps
setup() {
  log_info "Setup (%F{3}${target}%f)"
  setup_dep ${url} ${hash}
}

install() {
  autoload -Uz progress

  log_info "Install (%F{3}${target}%f)"
  cd ${dir}

  mkdir -p ${target_config[output_dir]}/include

  log_debug "Copying headers to ${target_config[output_dir]}/include"
  cp src/(utarray.h|uthash.h|utlist.h|utringbuffer.h|utstack.h|utstring.h) ${target_config[output_dir]}/include
  log_status "Copied headers to ${target_config[output_dir]}/include"
}
