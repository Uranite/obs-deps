autoload -Uz log_debug log_error log_info log_status log_output

## Dependency Information
local name='websocketpp'
local version='0.8.2'
local url='https://github.com/zaphoyd/websocketpp.git'
local hash='4dfe1be74e684acca19ac1cf96cce0df9eac2a2d'
local patches=()

## Build Steps
setup() {
  log_info "Setup (%F{3}${target}%f)"
  setup_dep ${url} ${hash}
}

clean() {
  cd ${dir}

  if [[ ${clean_build} -gt 0 && -d build_${arch} ]] {
    log_info "Clean build directory (%F{3}${target}%f)"

    rm -rf build_${arch}
  }
}

patch() {
  autoload -Uz apply_patch

  log_info "Patch (%F{3}${target}%f)"
  cd ${dir}

  local patch
  local _url
  local _hash
  for patch (${patches}) {
    read _url _hash <<< "${patch}"
    apply_patch ${_url} ${_hash}
  }
}

config() {
  autoload -Uz mkcd progress

  log_info "Config (%F{3}${target}%f)"

  args=(
    ${cmake_flags}
    -DENABLE_CPP11=ON
    -DBUILD_EXAMPLES=OFF
    -DBUILD_TESTS=OFF
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  )

  cd ${dir}
  log_debug "CMake configure options: ${args}"
  progress cmake -S . -B build_${arch} -G Ninja ${args}
}

build() {
  autoload -Uz mkcd

  log_info "Build (%F{3}${target}%f)"

  cd ${dir}
  cmake --build build_${arch} --config ${config}
}

install() {
  autoload -Uz progress

  log_info "Install (%F{3}${target}%f)"

  args=(
    --install build_${arch}
    --config ${config}
  )

  cd ${dir}
  progress cmake ${args}
}
