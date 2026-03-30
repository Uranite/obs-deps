autoload -Uz log_debug log_error log_info log_status log_output

## Dependency Information
local name='nv-codec-headers'
local version='33a9ede8d9914299d9262539c576a15bd0a19621'
local url='https://github.com/ffmpeg/nv-codec-headers.git'
local hash='33a9ede8d9914299d9262539c576a15bd0a19621'

## Dependency Overrides
local targets=('windows-x*')

## Build Steps
setup() {
  log_info "Setup (%F{3}${target}%f)"
  setup_dep ${url} ${hash}
}

build() {
  autoload -Uz mkcd progress

  log_info "Build (%F{3}${target}%f)"
  cd ${dir}

  log_debug "Running make"
  make PREFIX="${target_config[output_dir]}"
}

install() {
  autoload -Uz progress

  log_info "Install (%F{3}${target}%f)"

  cd ${dir}

  make PREFIX="${target_config[output_dir]}" install
}
