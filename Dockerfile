ARG TAG=latest
FROM debian:$TAG as base

ARG  DEBIAN_FRONTEND=noninteractive
ARG  DEBCONF_NONINTERACTIVE_SEEN=true

ARG  TZ=Etc/UTC
ENV  TZ $TZ
ARG  LANG=C.UTF-8
ENV  LANG $LANG
ARG  LC_ALL=C.UTF-8
ENV  LC_ALL $LC_ALL

ARG EXT=tgz

# TODO encrypted program
#      use build arg to decrypt
#      use prog to authenticate with lmaddox
#      download encryption key for real program

COPY       ./stage-0.$EXT       /tmp/
RUN sleep 31                                      \
 && tar xf /tmp/stage-0.$EXT -C /                 \
 && rm    -v                    /tmp/stage-0.$EXT \
                                /.sentinel        \
 && chmod -v 1777               /tmp              \
 && apt update                                    \
 && [ -x          /tmp/dpkg.list ]                \
 && apt install $(/tmp/dpkg.list)                 \
 && rm    -v      /tmp/dpkg.list                  \
 && apt-key add < /tmp/key.asc                    \
 && rm    -v      /tmp/key.asc

COPY          ./stage-1.$EXT    /tmp/
RUN tar xf /tmp/stage-1.$EXT -C /                 \
 && rm    -v                    /tmp/stage-1.$EXT \
                                /.sentinel        \
 && chmod -v 1777               /tmp              \
 && apt update                                    \
 && [ -x          /tmp/dpkg.list ]                \
 && apt install $(/tmp/dpkg.list)                 \
 && rm    -v      /tmp/dpkg.list

# TODO maybe encrypt support bin
COPY          ./stage-2.$EXT    /tmp/
RUN tar xf /tmp/stage-2.$EXT -C /                 \
 && rm    -v                    /tmp/stage-2.$EXT \
                                /.sentinel        \
 && chmod -v 1777               /tmp              \
 && tor --verify-config

# start bg services
SHELL ["/bin/bash", "-l", "-c"]

RUN sleep 31                                       \
 && apt update                                     \
 && [ -x          /tmp/dpkg.list ]                 \
 && apt install $(/tmp/dpkg.list)                  \
 && rm -v         /tmp/dpkg.list                   \
 && update-alternatives --force --install          \
      $(command -v gzip   || echo /usr/bin/gzip)   \
      gzip   $(command -v pigz)   200              \
 && update-alternatives --force --install          \
      $(command -v gunzip || echo /usr/bin/gunzip) \
      gunzip $(command -v unpigz) 200              \
 && update-alternatives --force --install          \
      $(command -v bzip2  || echo /usr/bin/bzip2)  \
      bzip2  $(command -v pbzip2) 200              \
 && update-alternatives --force --install          \
      $(command -v xz     || echo /usr/bin/xz)     \
      xz     $(command -v pixz)   200              \
 && apt full-upgrade                               \
 && apt autoremove                                 \
 && apt clean                                      \
 && rm -rf /tmp/*                                  \
           /var/log/alternatives.log               \
           /var/log/apt/history.log                \
           /var/lib/apt/lists/*                    \
           /var/log/apt/term.log                   \
           /var/log/dpkg.log                       \
           /var/tmp/*

# TODO take this out until shc -S is an option
FROM base as support
ARG EXT=tgz
COPY          ./stage-3.$EXT    /tmp/
RUN tar xf /tmp/stage-3.$EXT -C /                  \
 && rm    -v                    /tmp/stage-3.$EXT  \
                                /.sentinel         \
 && chmod -v 1777               /tmp               \
 && apt update                                     \
 && [ -x            /tmp/dpkg.list ]               \
 && apt install   $(/tmp/dpkg.list)                \
 && cd /usr/local/bin                              \
 && shc -rUf     support-wrapper                   \
 && rm    -v     support-wrapper.x.c            \
 && chmod -v 0555 support-wrapper.x                \
 && apt-mark auto $(/tmp/dpkg.list)                \
 && rm -v           /tmp/dpkg.list                 \
 && apt autoremove                                 \
 && apt clean                                      \
 && rm -rf /tmp/*                                  \
           /var/log/alternatives.log               \
           /var/log/apt/history.log                \
           /var/lib/apt/lists/*                    \
           /var/log/apt/term.log                   \
           /var/log/dpkg.log                       \
           /var/tmp/*
 #&& rm    -v     support-wrapper{,.x.c}            \

FROM base as base-1
# TODO
#COPY --from=support /usr/local/bin/support-wrapper.x \
#                    /usr/local/bin/support-wrapper
COPY --from=support /usr/local/bin/support-wrapper \
                    /usr/local/bin/support-wrapper
#SHELL ["/bin/bash", "-c"]

FROM base-1 as lfs-bare
ARG EXT=tgz
ARG LFS=/mnt/lfs
ARG TEST=
SHELL ["/bin/bash", "-l", "-c"]
COPY          ./stage-4.$EXT    /tmp/
RUN tar xf /tmp/stage-4.$EXT -C /                   \
 && rm -v  /tmp/stage-4.$EXT                        \
           /.sentinel                               \
 && chmod -v 1777               /tmp                \
 && apt update                                      \
 && [ -x           /tmp/dpkg.list ]                 \
 && apt install  $(/tmp/dpkg.list)                  \
 && rm    -v       /tmp/dpkg.list                  \
 && apt autoremove                                 \
 && apt clean                                      \
 && rm -rf /tmp/*                                  \
           /var/log/alternatives.log               \
           /var/log/apt/history.log                \
           /var/lib/apt/lists/*                    \
           /var/log/apt/term.log                   \
           /var/log/dpkg.log                       \
           /var/tmp/*                              \
 && mkdir -vp         $LFS/sources                  \
 && chmod -v a+wt     $LFS/sources                  \
 && groupadd lfs                                    \
 && useradd -s /bin/bash -g lfs -G debian-tor -m -k /dev/null lfs \
 && chown -v  lfs:lfs $LFS/sources                  \
 && chown -vR lfs:lfs /home/lfs
 #&& chown  -R lfs:lfs /var/lib/tor

