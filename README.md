# Bartholomew Helm Test

This repository is built from the template for creating new [Bartholomew](https://github.com/fermyon/bartholomew) websites.

Why would anyone want to deploy Bartholomew this way? (Honestly, why wouldn't we want to deploy Bartholomew this way?! 😂)

## Inventory

I have added:

* a Dockerfile for Buildx (it is platform-independent)
* some GitHub Actions scripts and workflows
  * for downloading the latest release of Spin,
  * publishing the blog content to OCI, with an "immutable" tag
  * publishing a Spin shim that knows "what tag"
* a tiny Helm chart (based on the Helmet library chart)
  * and a workflow to publish the Helm chart as OCI.

In the CI environment, (hopefully) everything is cached which can be cached.
There is no need for a hosted runner IMHO, because this build returns so fast.

In the Buildx image, [multi-arch support][] we adapted for our build allows to
address multiple platforms with a single image tag. This simplifies downstream
deployment significantly, as our deployer need not make separate manifests or
patches, or even be aware of whether multiple architectures are in use at all.

### Dependencies

Spin itself is a Rust application that compiles for specific host platforms.

Some workflow has been copied and adapted from the FluxCD project, [Flux GitHub Action][]
that selects a latest release of Spin with the GitHub API, downloads a binary
for your chosen architecture, (GitHub runners are all `amd64`, so that's the
default, but if you've got your own runners, `arch: arm64` can also be used).

[multi-arch support]: https://blog.container-solutions.com/building-multiplatform-container-images
[Flux GitHub Action]: https://github.com/fluxcd/flux2/tree/main/action

### Bundling Static Content with OCI

Bartholomew and the static content server both are Wasm modules that we hosted
with the content; this is an OK decision even if they don't change as often as
the content, because they are small-ish. We should be second-guessing this idea
because it isn't sound, but it's OK for the demo (as it won't be solved today!)

In the Bindle model there can be even greater savings for large websites, since
the whole OCI artifact need not be downloaded again for every changed file; but
right now it isn't clear how well Bindle works with Kubernetes, and our site is
small so I'd posit that potential savings is all firmly imaginary for us today.

GitHub pays for it now (thanks!), so we maybe don't need to care about this.

I went ahead and used OCI based on that, and because Spin has recently added
support for OCI, that has parallels with Flux's OCI artifact push feature, it
made good sense also to put this in a Helm chart, (and that's also with OCI!)

Only binaries for the currently used platform are downloaded from a multi-arch
image manifest on any given node. There is some waste re-downloading the Wasm
binary every time an OCI pull is done, but you just can't sweat small stuff.

### Performance

Build and release with a warm cache takes ~40-50s from "push" to "publish",
even with multi-arch (2x architectures) – this means I can iterate very fast!

It's a bit slower when the cache needs to be freshed. I used a multi-stage
Dockerfile and probably could do better trimming out unneeded dependencies.

We're cheating just a bit to achieve this: the multi-arch rootfs doesn't
actually hold any site content that changes. It's just a shim and a pointer to
the actual content, which gets published in an OCI image. This is much faster!

Only one file changes: `/env.vars` – with `BUILD_ID` that we source and export
before `spin-up.sh`. Cold start is unfortunately slow because we download those
two Wasm modules every time, that each weighs a positive integer number of MB.

#### Why is Cold Start?

We really need these processes to share memory; if we wanted to see the promise
of Wasm on Kubernetes then we need to prevent those Wasm modules from being
downloaded again and again, even though they didn't change. But it's just 10MB.
(What are you, serving blog from a phone, on a mobile data plan or something?)

This is exactly what OCI is for!

The content doesn't care what platform it's on. This is also what Wasm is for!
Spin shows us here just what Wasm can do.  Sharing memory between sandboxed
pods, on the other hand, is evidently not exactly what Kubernetes was made to
do. That's why Cold Start is the way it is here, and that's why this is hard.

You should not have trusted me, nobody at Fermyon asked for any of this 😂

### How scale rly?

I think these scale issues are addressed better right now at the [Hippo
Factory][], where Spin is actually made to run and perform at its best.

That cold start issue is the problem I think I understand [Bindle][] as having
been created to solve, and we could likely show better performance here as well
by implementing a Bindle server on our Kubernetes too.

But this is already quite complicated and I've accomplished my own goals.

If you want to improve your cold starts, you're probably gonna wanna check out
Fermyon Cloud (or Hippo Factory, the Open Source version of Fermyon Cloud!)

[Hippo Factory]: https://fermyon.dev/
[Bindle]: https://github.com/deislabs/bindle

## Releasing

Everything is driven by manually tagging. You tag a Docker image, which knows
its own `BUILD_ID` that corresponds with an OCI content image (`spin registry
push`) and that's what Spin runs.

The `.github/workflows` all request `packages: write` permission. They will
push packages (Docker, OCI, and Helm) when you push a tag to eg. `0.1.2` or
`chart-1.0.3`.

If you don't want to push a new chart, you can always override `image.tag` in
the chart `values.yaml`.

Remember to run `spin up` before you commit and push your changes, so you don't
have to commit twice! (Measure twice, cut only once...)

Always increment both `version: 0.1.2` and `appVersion: "0.0.3"` whenever you
release a new version of the chart, and remember to update the `tag: 0.0.3`
in `values.yaml` matching `appVersion`. (Might want to script this process.)

## Directory Structure:

Refer to [fermyon/bartholomew-site-template][] for the recommended site structure.

A snapshot of the current tree is in `tree.txt` at the repository root.

Besides the original template content, this repo also includes some updated
top-level configuration, GitHub `action/` and `.github/workflows`,
`ci-scripts/`, `charts/bart/`, and some other files we created whilst following
the [Fermyon developer guide: Bartholomew Quickstart][].

[fermyon/bartholomew-site-template]: https://github.com/fermyon/bartholomew-site-template
[Fermyon developer guide: Bartholomew Quickstart]: https://developer.fermyon.com/bartholomew/quickstart

# Usage

You are expected to fork this repo, enable GitHub Actions workflows on your
fork, then start pushing commits and you should near immediately see the
results, pushing Packages.

This is a multi-arch Spin shim Docker image, that can run anywhere!

(Yes, even on Kubernetes and even with an unmodified `containerd`. To avoid
writing a whole Docker file, we could follow [kwasm-operator][], but that
requires privileged access to nodes that we wish to avoid.)

[kwasm-operator]: https://github.com/KWasm/kwasm-operator

## Installation of Spin

To use Bartholomew, you will need to install [Spin](https://spin.fermyon.dev).
Once you have Wagi installed, you can continue setting up Bartholomew.

To start your website, run the following command from this directory:

```console
$ spin up
spin up
Serving HTTP on address http://127.0.0.1:3000
Available Routes:
  bartholomew: http://127.0.0.1:3000 (wildcard)
  fileserver: http://127.0.0.1:3000/static (wildcard)
```

Now you can point your web browser to `http://localhost:3000/` and see your new Bartholomew site.

### Deploy with Flux

For more notes about how this Helm chart can be deployed on Kubernetes with an
automated workflow, see the `limnocentral` test cluster on [kingdon-ci/fleet-infra][].
This is all WIP.

Or look in that same repo for [fleet-infra/examples/wasm][] where I'll leave
the results of my experimentation, once this experiment has actually landed!

(Reminder, this is WIP. Catch me doing stupid things and you may copy them.)

[kingdon-ci/fleet-infra]: https://github.com/kingdon-ci/fleet-infra
[fleet-infra/examples/wasm]: https://github.com/kingdon-ci/fleet-infra/tree/main/examples/wasm

## About the License

This repository uses CC0. To the greatest extent possible, you are free to use this content however you want.
You may relicense the code in this repository to your own satisfaction, including proprietary licenses.
