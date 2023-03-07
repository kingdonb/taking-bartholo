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
that selects a latest release of Spin with the GitHub API, then downloads a
binary for your chosen architecture.

GitHub runners are all `amd64`, so that's the default, but if you've got your
own, or a way to provision arm64 runners, then `arch: arm64` can also be used.

Note that while the build pipeline necessarily runs on one architecture,
everything after this point is multi-arch and the build pipeline is building
multiple architectures via BuildX and QEMU. This remains fast due to caching.

[multi-arch support]: https://blog.container-solutions.com/building-multiplatform-container-images
[Flux GitHub Action]: https://github.com/fluxcd/flux2/tree/main/action

### Bundling Static Content with OCI

Bartholomew and the static content server both are Wasm modules that we hosted
with the content; this is an OK decision even if they don't change as often as
the content, because they are small-ish.

We should probably be second-guessing this idea because it isn't sound, but
it's OK for the demo (as it must be, since it won't be solved today!)

In the Bindle model there can be even greater savings for large websites, while
the whole OCI artifact need not be downloaded again for every changed file; but
right now it isn't clear how well Bindle works with Kubernetes, and our site is
small so I'd posit that potential savings is all firmly imaginary for us today.

GitHub pays for the I/O now (thanks!), so we maybe don't need to care about this.

I went ahead and used one OCI image, an easy choice as Spin has recently added
the support for OCI registries. Flux's OCI push feature is similar, and it made
sense to me to also put this in a Helm chart (yet again, OCI!)

Only binaries for the currently used platform are downloaded from a multi-arch
image manifest on any given node. There is some waste re-downloading the Wasm
binary every time an OCI pull is done, but you just can't sweat small stuff.

### Performance

Build and release with a warm cache takes ~40-50s from "push" to "publish",
even with multi-arch (2x architectures) – this means I can iterate very fast!

It's a bit slower when the cache needs to be freshed. I used a multi-stage
Dockerfile and probably could do better trimming out unneeded dependencies.
The full build still finishes in [less than about 5 minutes][], which is great.

We're cheating just a bit to achieve this: the multi-arch rootfs builds in
parallel, and also doesn't hold any site content that changes. It's just a shim
and a pointer to the actual content, which gets published in an OCI image.

This is much faster!

Only one file changes: `/env.vars` – with `BUILD_ID` that we source and export
before `spin-up.sh`. Cold start is unfortunately slow because we download those
two Wasm modules every time, that each weighs a positive integer number of MB.

[less than about 5 minutes]: https://github.com/kingdonb/taking-bartholo/actions/runs/4327048077

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

You probably should not have followed me here, and there's definitely nobody at
Fermyon who asked for any of this 😂

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

Everything is driven by tagging.

Tagging a commit builds a Docker image, which knows its own `BUILD_ID`. That id
corresponds with a matching OCI content image tag (that contains the wasm, and
we use `spin registry push` to create it.)

At dev time, `BUILD_ID` is a tag with a timestamp. At release time, it's our
semantic app release version. The blog is our app, the shim spin is merely an
incidental bit of complexity that we have to carry around with us until the
`runtimeClass` in Deployment spec has more broad use and acceptance in K8s.

See also: [kwasm-operator][] for more about that idea!

That OCI content image is what Spin runs your Wasm application (our blog) from.
All of this image building happens in CI, on every branch and tag pushed.

### Testing Locally

There is no need to install Docker for local development at all, but you will
need to enable GitHub Actions on your own fork to push new images to GHCR.io.

<a id="tldr"/>

The `Makefile` has some provisions for testing locally, and now also releasing.

* `make` - with Docker installed, this should build an image and test it.

You can type `make` to build an image locally, but it will not work without the
corresponding OCI artifact that is made from the `consolidated.yaml` workflow.

You're meant to use CI with OCI. It's in the name, for real!

Don't try to do CI's whole job on your workstation. You can package versioned
releases of the "blog" as a Helm chart, just follow the guide below!

### Release tl;dr

The commands below are for previewing before tagging a release. You should be
able to use the images that CI produces for you to build the confidence.

When you are confident, follow the Release Guide below to push your Helm chart.

#### How to get confident

We push two images together, with a matching build-id from CI as explained.

So get CI running first, then run these and maybe read the `Makefile`:

* `gh repo set-default` - to tell the `gh` CLI about your fork.
* `make gh-latest-build-id` - to get the latest successful build-id.
* `make test-latest` - run `make test TAG=%s` where %s is the build-id.

You can use this to verify the output of CI is what you want to deploy.

Once you are confident, follow the Release Guide below!

(It should be quite OK to `tl;dr` beginning at this point!)

### Release Guide

Check the current version in `spin.toml`, and the Chart version in `Chart.yaml`

Decide what you want as the next

* `TAG` (`appVersion`), and
* `SEMVER` (Chart `version`)

Then, plug in your values and run these commands in sequence:

```
make version-set TAG=0.1.1-dev
make chart-ver-set SEMVER=0.2.1
# (Stop: commit the resulting changes and PR/merge them, or push to main)

make release    # this pushes both tags!
# ^– be sure that Docker Build from main is finished
#   (or the automated deployment you have downstream is likely to fail
#     with ImagePullBackOff!)
```

Taking into account the meaning of `MAJOR` and `MINOR` for communicating
changes that are "breaking" or "feature", the `values.yaml` is usually
considered a Helm Chart's "API" otherwise known as the public interface.

Helmet supports (hopefully) everything we need, so there isn't much to do
when it comes to Helm templating. You'll find we got away with a one-line
chart, thanks to the [Helmet][] chart library we've used as a dependency.

[Helmet]: https://github.com/companyinfo/helm-charts/tree/main/charts/helmet

### Guidelines for Versioning Helm Charts

Any changes to a Chart's default values other than `tag` are usually at least
considered as `MINOR` rather than `PATCH` level updates, (but this is at your
discretion as the publisher.)

Always increment both `appVersion` and the Chart `version` whenever you release
a new image, as Helm chart versions are made immutably for Helm, to facilitate
easy declarative rollback in any pipeline or Kubernetes deployment environment.

Helm charts are basically templates, and `values.yaml` is versioned as part of
the template. This by itself is not especially conducive to rapidly iterating.

For a declarative solution that allows you to override values, that does not
burden the deployer with managing always releasing a new chart or incrementing
a version by hand each time, please try out [Flux's Helm Controller][] if you
aren't using it already!

[Flux's Helm Controller]: https://fluxcd.io/flux/components/helm/helmreleases/#values-overrides

### Automated Iterative Development

With Image Update Automation and a few webhook receivers, this can be made to
work very smoothly (if you have any stamina left after publishing Helm chart.)

TODO: write this guide.

### Permissions

The `.github/workflows` all request `packages: write` permission. They will
push packages (Docker, OCI, and Helm) when you push a tag to eg. `0.1.2` or
`chart-1.0.3`.

If you don't want to push a new chart, you can always override `image.tag` in
the chart `values.yaml`.

### Testing Locally

Remember to run `spin up` before you commit and push your changes, so you don't
have to commit twice!

Spin is made for local development, you don't need a new pod every time to test
your changes – Spin is the server, and it runs anywhere.

Measure twice, cut once... Helm releases and pod sandboxes don't grow on trees!

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
requires some quite privileged access to nodes that we will need to avoid.)

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
