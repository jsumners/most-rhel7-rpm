#!/bin/bash

CWD=$(pwd)
VERSION="5.0.0a"
SPEC="files/most.spec"
SOURCE_URL="ftp://space.mit.edu/pub/davis/most/"

which wget > /dev/null
if [ $? -ne 0 ]; then
  echo "Aborting. Cannot continue without wget."
  exit 1
fi

which rpmbuild > /dev/null
if [ $? -ne 0 ]; then
  echo "Aborting. Cannot continue without rpmbuild from the rpm-build package."
  exit 1
fi

echo "Verifying dependencies..."
deps=(
  'slang-devel'
)
missingDeps=false
depsToInstall=""
for d in "${deps[@]}"; do
  rpm -qi ${d} 2>&1 1>/dev/null
  depInstalled=$?
  if [ ${depInstalled} -eq 1 ]; then
    providesList=$(rpm -q --whatprovides ${d})
    if [ "$providesList" != "" ]; then
      depInstalled=0
      for p in ${providesList}; do
        rpm -qi ${p} 2>&1 1>/dev/null
        i=$?
        depInstalled=$((depInstalled + i))
      done
    fi

    if [ $depInstalled -gt 0 ]; then
      missingDeps=true
      echo "Missing dependency: ${d}"
      depsToInstall="${depsToInstall} ${d}"
    fi
  fi
done

if [ "${missingDeps}" == "true" ]; then
  echo "Can't continue until all dependencies are installed!"
  echo -e "Issue: \`yum install ${depsToInstall}\`"
  exit 1
fi

echo "Creating RPM build path structure..."
mkdir -p rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS,tmp}

cp files/most.spec rpmbuild/SPECS/

echo "Downloading sources..."
cd rpmbuild/SOURCES
if [ ! -d "most-${VERSION}" ]; then
  wget "${SOURCE_URL}/most-${VERSION}.tar.gz"
  cd ${CWD}
fi

if [ -f ${CWD}/gpg-env ]; then
  echo "Building RPM with GPG signing..."
  cd ${CWD}

  source gpg-env
  if [ "${gpg_bin}" != "" ]; then
    rpmbuild --define "_topdir ${CWD}/rpmbuild" \
      --define "_signature ${signature}" \
      --define "_gpg_path ${gpg_path}" --define "_gpg_name ${gpg_name}" \
      --define "__gpg ${gpg_bin}" --sign -ba ${SPEC}
  else
    rpmbuild --define "_topdir ${CWD}/rpmbuild" \
      --define "_signature ${signature}" \
      --define "_gpg_path ${gpg_path}" --define "_gpg_name ${gpg_name}" \
      --sign --ba ${SPEC}
  fi
else
  echo "Building RPM..."
  cd ${CWD}
  rpmbuild --define "_topdir ${CWD}/rpmbuild" --ba ${SPEC}
fi
