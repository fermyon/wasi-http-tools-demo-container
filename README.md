# Demo Docker Container for wasi-http

This repository contains a Dockerfile, which creates a container to help demo wasi-http across
[Spin](https://github.com/fermyon/spin), [NGINX Unit](https://unit.nginx.org/),
and [Wastime](https://github.com/bytecodealliance/wasmtime).

To build the container:
`docker build -t fermyon/wasi-http-demo:latest .`

To run the container:
`docker run --rm --name wasi-http -it -p 3000:3000 fermyon/wasi-http-demo:latest`

> Note: Any process inside the container should bind to the `0.0.0.0` ip-address. `127.0.0.1` will not work.

## Demo steps

Imaginary steps for now...

1. Pull the Docker image
2. Run the component across
    1. Wasmtime
        - `wasmtime serve ./spin-rust/target/wasm32-wasi/release/spin_rust.wasm --addr 0.0.0.0:3000`
    2. Spin
        - `spin up -f ./spin-rust/spin.toml --listen 0.0.0.0:3000`
    3. NGINX Unit
        - `unitd --no-daemon`
3. Compose the middleware into the component
4. Go back to 2 and redo
    1. STRETCH - Showcase how the main component cannot get to the any of the data in the OAuth component

## What's in it?

All the tools you need:
- Spin 2.0
- Wastime 14
- Rust Dev tools
- WebAssembly component tooling

## References

### Wasi-http component examples

- https://github.com/fermyon/spin-fileserver
- https://github.com/fermyon/http-auth-middleware

