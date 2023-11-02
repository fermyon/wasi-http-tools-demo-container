FROM debian:bullseye-slim
EXPOSE 3000/tcp

# Pre-reqs
RUN apt-get update
RUN apt-get -y install curl git gcc xz-utils pkg-config libssl-dev vim tree

# Install Spin
RUN curl -fsSL https://developer.fermyon.com/downloads/install.sh | bash -s -- -v v2.0.0-rc.1
RUN mv ./spin /usr/local/bin/spin

# Install Rust tools for development demo apps
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup target install wasm32-wasi

# Install Wasmtime and component tooling
RUN curl https://wasmtime.dev/install.sh -sSf | bash
RUN cargo install --git https://github.com/bytecodealliance/cargo-component --locked cargo-component
RUN cargo install wasm-tools

RUN spin new -t http-rust spin-rust -a
RUN spin build -f ./spin-rust/spin.toml
