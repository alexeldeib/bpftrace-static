ARG distro=xenial

FROM ubuntu:${distro} as base

ARG distro=xenial
ARG bcc_ref="v0.12.0"
ARG LLVM_VERSION="8"
ENV DISTRO=${distro}
ENV LLVM_VERSION=$LLVM_VERSION

RUN apt-get update && apt-get install -y curl gnupg &&\
    llvmRepository="\n\
deb http://apt.llvm.org/${DISTRO}/ llvm-toolchain-${DISTRO} main\n\
deb-src http://apt.llvm.org/${DISTRO}/ llvm-toolchain-${DISTRO} main\n\
deb http://apt.llvm.org/${DISTRO}/ llvm-toolchain-${DISTRO}-${LLVM_VERSION} main\n\
deb-src http://apt.llvm.org/${DISTRO}/ llvm-toolchain-${DISTRO}-${LLVM_VERSION} main\n" &&\
    echo $llvmRepository >> /etc/apt/sources.list && \
    curl -L https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -

RUN apt-get update && apt-get install -y \
    bison \
    binutils-dev \
    flex \
    make \
    g++ \
    git \
    libelf-dev \
    zlib1g-dev \
    libiberty-dev \
    libbfd-dev \
    libedit-dev \
    clang-${LLVM_VERSION} \
    libclang-${LLVM_VERSION}-dev \
    libclang-common-${LLVM_VERSION}-dev \
    libclang1-${LLVM_VERSION} \
    llvm-${LLVM_VERSION} \
    llvm-${LLVM_VERSION}-dev \
    llvm-${LLVM_VERSION}-runtime \
    libllvm${LLVM_VERSION} \
    systemtap-sdt-dev \
    python \
    quilt \
    luajit \
    luajit-5.1-dev

RUN apt remove --purge --auto-remove cmake
RUN apt install -y libssl-dev
RUN version=3.16 \
    && build=2 \
    && mkdir -p /tmp \
    && cd /tmp \
    && curl -OL https://cmake.org/files/v$version/cmake-$version.$build.tar.gz \
    && tar -xzvf cmake-$version.$build.tar.gz \
    && cd cmake-$version.$build/ \
    && ./bootstrap \
    && make -j$(nproc) \
    && make install

RUN export IOVISOR_KEY_TMP=/tmp/iovisor-release.key \
    export IOVISOR_URL=https://repo.iovisor.org/GPG-KEY \
    && curl -fsSL $IOVISOR_URL -o $IOVISOR_KEY_TMP \
    && apt-key add $IOVISOR_KEY_TMP \
    && echo "deb https://repo.iovisor.org/apt/$(lsb_release -cs) $(lsb_release -cs) main" >  /etc/apt/sources.list.d/iovisor.list \
    && apt-get update \
    && apt-get install bcc-tools libbcc-examples

# RUN git clone https://github.com/iovisor/bcc.git \
#     && mkdir bcc/build; cd bcc/build \
#     && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local .. \
#     && make \
#     && make install &&  mkdir -p /usr/local/lib && \
#     cp src/cc/libbcc.a /usr/local/lib/libbcc.a && \
#     cp src/cc/libbcc-loader-static.a /usr/local/lib/libbcc-loader-static.a && \
#     cp ./src/cc/libbcc_bpf.a /usr/local/lib/libbpf.a 

RUN git clone https://github.com/iovisor/bpftrace.git \
    && mkdir bpftrace/build; cd bpftrace/build \
    && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DWARNINGS_AS_ERRORS:BOOL=OFF \
      -DSTATIC_LINKING:BOOL=ON -DSTATIC_LIBC:BOOL=OFF \
      -DEMBED_LLVM:BOOL=ON -DEMBED_CLANG:BOOL=ON \
      -DEMBED_LIBCLANG_ONLY:BOOL=OFF \
      -DLLVM_VERSION=$LLVM_VERSION \
      -DCMAKE_CXX_FLAGS="-include /usr/local/include/bcc/compat/linux/bpf.h -D__LINUX_BPF_H__" ../  \
    && make -j$(nproc) embedded_llvm \
    && make -j$(nproc) embedded_clang \
    && make -j$(nproc) \
    && make -j$(nproc) install

RUN strip --keep-symbol BEGIN_trigger /usr/local/bin/bpftrace

# at end of build, expect:
# /usr/local/bin/bpftrace contains static binary
# /usr/local/share/bpftrace/tools contains bpftrace shared programs
# /usr/local/share/bcc/tools contains bcc shared programs
# and some static bcc libs