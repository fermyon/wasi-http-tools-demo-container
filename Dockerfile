FROM debian:bullseye-slim

# Build NGINX Unit wasi-http tech-preview from source. For more information see
# https://github.com/nginx/unit

RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y curl git gcc xz-utils vim tree pkg-config

RUN set -ex \
    && savedAptMark="$(apt-mark showmanual)" \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y ca-certificates build-essential libssl-dev libpcre2-dev pkg-config libclang-dev \
    && mkdir -p /usr/lib/unit/modules /usr/lib/unit/debug-modules \
    && mkdir -p /usr/src/unit \
    && cd /usr/src/unit \
    && git clone https://github.com/ac000/unit --branch wasm-wasi-http \
    && cd unit \
    && NCPU="$(getconf _NPROCESSORS_ONLN)" \
    && DEB_HOST_MULTIARCH="$(dpkg-architecture -q DEB_HOST_MULTIARCH)" \
    && CC_OPT="$(DEB_BUILD_MAINT_OPTIONS="hardening=+all,-pie" DEB_CFLAGS_MAINT_APPEND="-Wp,-D_FORTIFY_SOURCE=2 -fPIC" dpkg-buildflags --get CFLAGS)" \
    && LD_OPT="$(DEB_BUILD_MAINT_OPTIONS="hardening=+all,-pie" DEB_LDFLAGS_MAINT_APPEND="-Wl,--as-needed -pie" dpkg-buildflags --get LDFLAGS)" \
    && CONFIGURE_ARGS_MODULES="--prefix=/usr \
                --statedir=/var/lib/unit \
                --control=unix:/var/run/control.unit.sock \
                --runstatedir=/var/run \
                --pid=/var/run/unit.pid \
                --logdir=/var/log \
                --log=/var/log/unit.log \
                --tmpdir=/var/tmp \
                --user=unit \
                --group=unit \
                --openssl \
                --libdir=/usr/lib/$DEB_HOST_MULTIARCH" \
    && CONFIGURE_ARGS="$CONFIGURE_ARGS_MODULES \
                --njs" \
    && make -j $NCPU -C pkg/contrib .njs \
    && export PKG_CONFIG_PATH=$(pwd)/pkg/contrib/njs/build \
    && ./configure $CONFIGURE_ARGS --cc-opt="$CC_OPT" --ld-opt="$LD_OPT" --modulesdir=/usr/lib/unit/debug-modules --debug \
    && make -j $NCPU unitd \
    && install -pm755 build/sbin/unitd /usr/sbin/unitd-debug \
    && make clean \
    && ./configure $CONFIGURE_ARGS --cc-opt="$CC_OPT" --ld-opt="$LD_OPT" --modulesdir=/usr/lib/unit/modules \
    && make -j $NCPU unitd \
    && install -pm755 build/sbin/unitd /usr/sbin/unitd \
    && make clean \
    && export RUST_VERSION=1.71.0 \
    && export RUSTUP_HOME=/usr/src/unit/rustup \
    && export CARGO_HOME=/usr/src/unit/cargo \
    && export PATH=/usr/src/unit/cargo/bin:$PATH \
    && dpkgArch="$(dpkg --print-architecture)" \
    && case "${dpkgArch##*-}" in \
       amd64) rustArch="x86_64-unknown-linux-gnu"; rustupSha256="0b2f6c8f85a3d02fde2efc0ced4657869d73fccfce59defb4e8d29233116e6db" ;; \
       arm64) rustArch="aarch64-unknown-linux-gnu"; rustupSha256="673e336c81c65e6b16dcdede33f4cc9ed0f08bde1dbe7a935f113605292dc800" ;; \
       *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
    esac \
    && url="https://static.rust-lang.org/rustup/archive/1.26.0/${rustArch}/rustup-init" \
    && curl -L -O "$url" \
    && echo "${rustupSha256} *rustup-init" | sha256sum -c - \
    && chmod +x rustup-init \
    && ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host ${rustArch} \
    && rm rustup-init \
    && rustup --version \
    && cargo --version \
    && rustc --version \
    && ./configure $CONFIGURE_ARGS_MODULES --cc-opt="$CC_OPT" --modulesdir=/usr/lib/unit/modules \
    && make build/src/nxt_unit.o \
    && cargo build --release --manifest-path src/wasm-wasi-http/Cargo.toml \
    && install -pm755 src/wasm-wasi-http/target/release/libnxt_wasmtime.so /usr/lib/unit/modules/wasmtime.unit.so \
    && rm -rf src/wasm-wasi-http/target \
    && rm -rf /usr/src/unit \
    && for f in /usr/sbin/unitd /usr/lib/unit/modules/*.unit.so; do \
        ldd $f | awk '/=>/{print $(NF-1)}' | while read n; do dpkg-query -S $n; done | sed 's/^\([^:]\+\):.*$/\1/' | sort | uniq >> /requirements.apt; \
       done \
    && apt-mark showmanual | xargs apt-mark auto > /dev/null \
    && { [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; } \
    && /bin/true \
    && mkdir -p /var/lib/unit/ \
    && mkdir -p /docker-entrypoint.d/ \
    && groupadd --gid 999 unit \
    && useradd \
         --uid 999 \
         --gid unit \
         --no-create-home \
         --home /nonexistent \
         --comment "unit user" \
         --shell /bin/false \
         unit \
    && apt-get update \
    && apt-get --no-install-recommends --no-install-suggests -y install curl $(cat /requirements.apt) \
    && apt-get purge -y --auto-remove build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /requirements.apt \
    && ln -sf /dev/stdout /var/log/unit.log

# Install Spin
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y curl git \
    && curl -fsSL https://developer.fermyon.com/downloads/install.sh | bash -s -- -v v2.0.0-rc.1 \
    && mv ./spin /usr/local/bin/spin

# Install Rust tools to build component
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y curl \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && $HOME/.cargo/bin/rustup target install wasm32-wasi

ENV PATH="/root/.cargo/bin:${PATH}"

# Install Wasmtime and component tooling
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y libssl-dev \
    && curl https://wasmtime.dev/install.sh -sSf | bash \
    && cargo install --git https://github.com/bytecodealliance/cargo-component --locked cargo-component \
    && cargo install wasm-tools

# Create Spin app and build the component
RUN set -ex \
    && spin new -t http-rust spin-rust -a \
    && printf "\n[package.metadata.component]\npackage = \"demo:example\"\n" >> ./spin-rust/Cargo.toml \
    && cargo component build --manifest-path ./spin-rust/Cargo.toml --release

# Create a NGINX Unit configuration so we can simply start it up! 
COPY <<EOF /var/lib/unit/conf.json
{
    "listeners": {
        "*:3000": {
            "pass": "applications/wasm"
        }
    },

    "applications": {
        "wasm": {
            "type": "wasm-wasi-http",
            "component": "./spin-rust/target/wasm32-wasi/release/spin_rust.wasm"
        }
    }
}
EOF

# S T A R T U P
STOPSIGNAL SIGTERM

# Expose main traffic ports
EXPOSE 3000/tcp
