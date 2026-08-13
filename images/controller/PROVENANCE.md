# Description

This build of the NGINX Ingress controller is built with:

* [kubernetes/ingress-nginx@controller-v1.11.5](https://github.com/kubernetes/ingress-nginx/tree/controller-v1.11.5) ([permalink](https://github.com/kubernetes/ingress-nginx/tree/795b6964d3cbcdebf5c857faca12750d76158920)).
* [Lua modules](./etc/nginx/lua) for exporting metrics and for geohashing ([source](https://github.com/deckhouse/deckhouse/tree/49744cd7e11f86aacf493be4dec391901348ddda/modules/402-ingress-nginx/images/controller-1-10/rootfs/etc/nginx/lua)).
* A patched `nginx.conf` [template](./etc/nginx/template/nginx.tmpl). The patch is based on [deckhouse/deckhouse@91482468](https://raw.githubusercontent.com/deckhouse/deckhouse/91482468489526bc59623bd7fbd31228cd6a6b22/modules/402-ingress-nginx/images/controller-1-10/patches/nginx-tmpl.patch) sans the HTTP3 features. Dropping those is not cosmetic: `buildHTTP3Listener` is a deckhouse-only template function, and `text/template` fails at parse time on an unknown function, so keeping the blocks would break config rendering outright even with `UseHTTP3` off.
* [kubernetes/ingress-nginx#11843](./patches/11843.diff) ([source](https://github.com/kubernetes/ingress-nginx/pull/11843)).

## Notes on the 1.11.2 → 1.11.5 move

The `build-v1.11.2` branch carried an extra patch, [`13068.diff`](https://github.com/kubernetes/ingress-nginx/pull/13068), backporting the fix for [CVE-2025-1974](https://github.com/advisories/GHSA-mgvx-rpfc-9mpv) and friends onto 1.11.2. That patch is dropped here because 1.11.5 already contains the fix upstream — it no longer applies to this tree.

The template needed no edit at all. On 1.11.2 the `| quote` hardening of `CertificateAuth.MatchCN`, `externalAuth.URL` and `Mirror.Source` was carried here by hand; 1.11.5 ships it upstream. Regenerating the file from the 1.11.5 template plus the deckhouse patch reproduces the vendored one byte for byte, which is a useful check in both directions: the hardening is now inherited rather than maintained locally, and the vendored file is confirmed to be exactly upstream-plus-patch with nothing else in it.

`11843.diff` is vendored rather than fetched at build time. The upstream pull request is still open, so a `wget` of its `.diff` would let the build change under us without any commit here; the controller is built with `enable-ssl-passthrough`, which is exactly what that patch fixes for fragmented ClientHello.

The builder image is `golang:1.24-alpine`: 1.11.5 declares `go 1.24.1` in its `go.mod`, where 1.11.2 declared `go 1.22.6`.
