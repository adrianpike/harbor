> Hey friends - please note, that as of 2016, this project has been abandoned in favor of a ✨day job ✨. Please feel free to read through it, learn from it, lampoon me for bad code, or otherwise do with it what you will. FWIW, I have used many of the concepts I've hacked on in here in subsequent projects, generally using Docker for containerization and process management. Hit me up if you're curious about any choices I made. <3.


harbor
======

Harbor is a routing layer and set of deployment tools for
[12factor](http://12factor.net) microservice infrastructures. It allows
engineering teams to easily deploy releases onto production infrastructure
without downtime, and cut traffic over to individual services at their leisure.

It's designed to be modular and pluggable - if you want to run your own PaaS,
harbor will do that. If you want to run your services on Heroku, harbor
will help with the coordination of that as well.

In short, as an engineer, it makes life as simple as this;

```bash
adrian$ harbor deploy
# Harbor firing a deploy for "Thunderchicken"
# - Thunderchicken#backend-service-1 has new revision, spawning on prod-1.foobarapp.com
# - Thunderchicken#backend-service-1#c211f listening on port 4921
# - New build `020864f02d7c4c832aca7d204ca9b9cd59934287` released
adrian$ harbor route production 020864f02d7c4c832aca7d204ca9b9cd59934287
# Harbor routing production traffic to 020864f02d7c4c832aca7d204ca9b9cd59934287
# - Thunderchicken#backend-service-1#a3321 is orphaned and can reaped from all hosts.
```

A lot just happened - I committed some changes to `backend-service-1`, and
released a new build of our entire app. Anything other than `backend-service-1`
was untouched, and no traffic touched the new revision until I asked to move
traffic over.

If you want to jump right in, install the [harbor_cli](http://adrianpike.github.com/harbor-cli)
gem, and run `harbor init`. It'll walk you through what you need.

Under the hood, here's what's happening;

 - I requested a deploy, and a Harborfile was read, to determine
   all the services that make up this app and understand a little about my
   deployment environment.
 - My local Git SHAs were compared against running SHAs across the entire
   collection of Harbor servers.
 - A new SHA was discovered, a Harbor server was selected to deploy to, and a
   new process was spawned on that server running the newest code for that
   service.
 - Any DNS references to internal services were updated to point to the correct
   revisions in the code I just deployed for `backend-service-1`.
 - A `build` was determined, which is a collection of service SHAs to consider
   as one running build.
 - All the build, service, and revision hosts, ports and SHAs were updated in
   our port registry.
 - I flipped production traffic over to that latest `build`, and traffic began
   to flow to the new revision of `backend-service-1`, and since I didn't bump
   any other services, everything else remained.

Quickstart
----------

```blockquote
Please note, as of March 3rd, 2015, Harbor is under active development and
should be used with care. Things will be shifting around underneath you in
the next few weeks, it's untested.

With that said, it _is_ currently handling production traffic for a handful
of sites.
```

There's some important assumptions we'll make out of the gate.

 - You're using git as your VCS. There are no plans at this time to support others.
 - You've got more than one service. Otherwise, just use Heroku, life will be easier!
 - You're using HTTP to communicate between services.
 - Services listen on a $PORT environment variable, and we've decided on some
   unique ports to use for inter-service communication and development.

```
As of March 2nd, 2015 the only way to host apps is through the native harbord.
The next hosting layer to be supported is Heroku.
```

### harbord Setup

1) Clone [harbor](http://github.com/adrianpike/harbor) (this repo) somewhere
on the server(s) you want to deploy to.

2) `npm install`

3) Edit `etc/config.json` to point to a shared Redis instance for persistent
storage.

4) Run `bin/harbord`

5) Ensure your control port (default 6060) is closed off to public traffic.
The Harbor CLI uses SSH tunneling for its access.

### Client Setup

1) Install [harbor_cli](http://github.com/adrianpike/harbor_cli). Then come back here.

2) Initialize your Harborfile with `harbor init`. Follow the prompts.

```bash
adrian$ cd src/my_amazing_project/
adrian$ harbor init
Starting Harborfile generated from your Procfile. You should review and edit it.
##### Finishing Up #####
1. Any places where you're referencing external services need to be changed to
   the .harbor suffix. Please see http://adrianpike.github.io/harbor/ for more
   information.
2. You need to set up local DNS to resolve .harbor to 127.0.0.1.
3. Use Foreman as usual.
```

3) Ensure you're set up for passwordless SSH to any hosts you want to deploy to.

You're ready to go! If you want to dive in, start playing with the Harbor CLI.
If you want to learn more about what's happening, read on.

About Harbor
------------

### A Service

A Service is a single [12factor](http://12factor.net) service which is a component of a larger
application. Services are given dynamic ports via the PORT environment variable.
A service listens on this port for HTTP traffic, and has traffic routed to it
via the `Routing Layer`.

### The build step

```
The build process is within the CLI, and is currently in flux to move to Heroku
buildpacks.
```

### The Routing Layer

The routing layer is how HTTP traffic is routed to the correct instance of a
service. The lifecycle of an HTTP request can be complicated as it moves
through the appropriate versioning systems.

 - TCP Port - [Service] -> Service Name
 - Domain - [Route] -> Deploy/Release SHA
 - Deploy/Release SHA - [Deploy] -> Service SHA
 - Service SHA - [Port Registry] -> Instance

### Service Versioning

```
Service versioning is currently in flux.
```

### The Harborfile

The Harborfile is how the CLI is configured. It specifies what your services
are, where they can be found locally, what deploy method(s) you're using, and
anything else that might need to be configured. You shouldn't be creating your
Harborfile from scratch though - the CLI has the `harbor init` command to walk
you through it and auto-discover what it can.

An example is below;

```yaml
services:
  web:
    port: 80
    cmd: bundle exec unicorn -p $PORT -c ./config/unicorn.rb
    path: ./
  cuckoo:
    port: 6060
    cmd: supervisor -w cuckoo -- ./cuckoo/cuckoo.coffee
    path: ../cuckoo
  arterial:
    port: 5252
    cmd: supervisor -w arterial -- ./arterial/lib/server.coffee
    path: ../arterial
harbor:
  app: elapse
  deploy_dir: '/home/apps/deploys'
  deploy_user: apps
  servers:
    - type: http+ssh
      host: sea1.adrianpike.com
```


Immediate TODO
--------------

Prerelease
- Use Heroku buildpacks correctly in the CLI
- Development mode
- Persistent services

- Harbord namespaced per application (v0)

- Backend hosting layers
  - Heroku (v1)
  - Native method (v0)

- Routing layers
  - Native (v1)
  - Direct DNS (icebox)
  - offload to a haproxy (v2)

- Inter-process routing method
  - Multiple instances of Upstream services (v2)
  - Header passing through magic (v1)

- Persistence Backend layers
  - Redis (v1)
  - etcd (v2)
  - consul (v2)

- Logging layers
  - capture to files (v1)

- Metrics layers (v2)
  - statsd
  - stdout
  - graphite

