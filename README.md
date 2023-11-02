# Demo Docker Container for wasi-http

This repository contains a Dockerfile, whcih creates a container to help demo wasi-http across Spin, Nginx Unit, and Wastime.

To run the container:
`docker run --rm --name wasi-http -it -p 3000:3000 fermyon/wasi-http-demo:latest`

To run the container and start the test Spin app:
`docker run --rm --name wasi-http -it -p 3000:3000 fermyon/wasi-http-demo:latest bash -c "spin up -f ./spin-rust/spin.toml --listen 0.0.0.0:3000"`

> Note: Any process inside the container shoudl bind to the `0.0.0.0` ip-address. `127.0.0.1` will not work.

## Demo steps

Imaginary steps for now...

1. Pull the Docker image
2. Run the component across
    1. Wasmtime
    2. Spin
    3. Unit
3. Compose the middleware into the component
4. Go back to 2 and redo
    1. STRETCH - Showcase how the main component cannot get to the any of the data in the OAuth component

## What's in it?

All the tools you need:
- Spin 2.0
- Wastime 14
- Rust Dev tools
- WebAssembly component tooling
- A sample Spin application (in `./spin-rust`) - Simply run `spin up -f ./spin-rust/spin.toml --listen 0.0.0.0:3000

## References

### Wasi-http component examples

- https://github.com/fermyon/spin-fileserver/pull/43
- https://github.com/fermyon/http-auth-middleware

