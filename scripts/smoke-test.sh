#!/usr/bin/env bash
#
# Smoke tests run inside the images. The work directory is shared between the
# devel and runtime runs so that a program built with the devel image is
# executed in the runtime image, the same way the ADCIRC image is built.
#
# Usage (inside a container, without the entrypoint so that only the image
# ENV is used):
#   smoke-test.sh devel   <workdir>   compile and run the test programs
#   smoke-test.sh runtime <workdir>   run the programs built by devel
#   smoke-test.sh ci                  check the CI tooling
#
set -euo pipefail

mode="${1:?mode required}"
work="${2:-}"

check_libraries() {
  local missing
  missing="$(find -L /opt/views/view/bin /opt/views/view/lib /opt/views/view/lib64 \
      -maxdepth 1 -type f -print0 2>/dev/null | xargs -0 -r file | grep ELF | cut -d: -f1 | \
      xargs -r ldd 2>/dev/null | grep "not found" || true)"
  if [[ -n "${missing}" ]]; then
    echo "Unresolved shared libraries:" >&2
    echo "${missing}" >&2
    exit 1
  fi
  echo "All shared libraries resolve"
}

run_programs() {
  # The shared work directory holds the programs, which are read-only for the
  # other users the tests run as, so each run writes its output separately
  local output
  output="$(mktemp -d)/hello.nc"
  "${work}/hello_netcdf" "${output}"
  mpirun --oversubscribe -np 2 "${work}/hello_mpi"
  # grep reads all of the output; with -q, ncdump would fail with SIGPIPE
  ncdump -h "${output}" | grep "dimensions:" > /dev/null
  echo "Programs ran successfully"
}

case "${mode}" in
  devel)
    check_libraries
    cat > "${work}/hello_mpi.f90" << 'EOF'
program hello_mpi
  use mpi
  implicit none
  integer :: ierr, rank, nproc
  call mpi_init(ierr)
  call mpi_comm_rank(MPI_COMM_WORLD, rank, ierr)
  call mpi_comm_size(MPI_COMM_WORLD, nproc, ierr)
  print '(a,i0,a,i0)', 'rank ', rank, ' of ', nproc
  call mpi_finalize(ierr)
end program hello_mpi
EOF
    cat > "${work}/hello_netcdf.f90" << 'EOF'
program hello_netcdf
  use netcdf
  implicit none
  character(len=256) :: filename
  integer :: ncid, dimid, varid
  call get_command_argument(1, filename)
  call check(nf90_create(trim(filename), NF90_NETCDF4, ncid))
  call check(nf90_def_dim(ncid, "node", 4, dimid))
  call check(nf90_def_var(ncid, "zeta", NF90_DOUBLE, [dimid], varid))
  call check(nf90_enddef(ncid))
  call check(nf90_put_var(ncid, varid, [1d0, 2d0, 3d0, 4d0]))
  call check(nf90_close(ncid))
  print '(a)', 'wrote ' // trim(filename)
contains
  subroutine check(status)
    integer, intent(in) :: status
    if (status /= NF90_NOERR) then
      print '(a)', trim(nf90_strerror(status))
      error stop 1
    end if
  end subroutine check
end program hello_netcdf
EOF
    # nf-config reports Spack's build-time compiler wrapper, so pick the
    # compiler the same way ADCIRC's container build does
    if command -v ifx > /dev/null 2>&1; then fc=ifx; else fc=gfortran; fi
    mpif90 -o "${work}/hello_mpi" "${work}/hello_mpi.f90"
    # nf-config --flibs has no -L for netcdf-c, so link against the view,
    # which holds both at the same path in the devel and runtime images
    view=/opt/views/view
    "${fc}" -o "${work}/hello_netcdf" "${work}/hello_netcdf.f90" \
      -I"${view}/include" -L"${view}/lib" -lnetcdff -lnetcdf -Wl,-rpath,"${view}/lib"
    run_programs
    ;;
  runtime)
    check_libraries
    # The MPI wrapper scripts ship with OpenMPI; the compilers behind them
    # must not
    for compiler in icx ifx /opt/views/view/bin/gfortran; do
      if command -v "${compiler}" > /dev/null 2>&1; then
        echo "Compiler ${compiler} found in the runtime image" >&2
        exit 1
      fi
    done
    run_programs
    ;;
  ci)
    python3 -c "import boto3, cartopy, matplotlib, netCDF4, numpy, tqdm, xarray, yaml"
    aws --version
    echo "CI tooling available"
    ;;
  *)
    echo "Unknown mode: ${mode}" >&2
    exit 2
    ;;
esac
