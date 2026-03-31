autoload -Uz log_debug log_error log_info log_status log_output

## Dependency Information
local name='ntv2'
local version='2d7636d86b6180bb4c5075fea040b1b812cc8b57'
local url='https://github.com/aja-video/libajantv2.git'
local hash='2d7636d86b6180bb4c5075fea040b1b812cc8b57'
local -a patches=(
  "* ${0:a:h}/patches/ajantv2/0001-install-m31-headers.patch \
    D77DCCB550A1E9C1522ABEAD997C479065ECCCD251393BFF5CBF3B7BA6E222CB"
)

## Dependency Overrides
local -i shared_libs=0

## Build Steps
setup() {
  log_info "Setup (%F{3}${target}%f)"
  setup_dep ${url} ${hash}
}

patch() {
  autoload -Uz apply_patch

  log_info "Patch (%F{3}${target}%f)"
  cd ${dir}

  local patch
  local _target
  local _url
  local _hash
  for patch (${patches}) {
    read _target _url _hash <<< "${patch}"

    if [[ ${target%%-*} == ${~_target} ]] apply_patch ${_url} ${_hash}
  }
}

clean() {
  cd ${dir}

  if [[ ${clean_build} -gt 0 && -d build_${arch} ]] {
    log_info "Clean build directory (%F{3}${target}%f)"

    rm -rf build_${arch}
  }
}

config() {
  autoload -Uz mkcd progress

  log_info "Config (%F{3}${target}%f)"

  local _onoff=(OFF ON)

  args=(
    ${cmake_flags}
    -DAJA_BUILD_SHARED="${_onoff[(( shared_libs + 1 ))]}"
    -DAJANTV2_DISABLE_DEMOS=ON
    -DAJANTV2_DISABLE_DRIVER=ON
    -DAJANTV2_DISABLE_TESTS=ON
    -DAJANTV2_DISABLE_TOOLS=ON
    -DAJANTV2_DISABLE_PLUGINS=ON
    -DAJA_INSTALL_SOURCES=OFF
    -DAJA_INSTALL_HEADERS=ON
    -DAJA_INSTALL_MISC=OFF
    -DAJA_INSTALL_CMAKE=OFF
  )

  cd ${dir}
  log_debug "CMake configure options: ${args}"
  progress cmake -S . -B "build_${arch}" -G Ninja ${args}
}

build() {
  autoload -Uz mkcd

  log_info "Build (%F{3}${target}%f)"

  cd ${dir}
  
  args=(
    --build build_${arch}
    --config ${config}
  )

  if (( _loglevel > 1 )) args+=(--verbose)

  cmake ${args}
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
