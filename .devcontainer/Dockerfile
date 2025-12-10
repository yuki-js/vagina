# ---- download stage ----
FROM ghcr.io/yuki-js/dotfiles/dotimage:latest AS download
USER root
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        wget \
        unzip \
        xz-utils \
        git \
    && rm -rf /var/lib/apt/lists/*
# Download Android cmdline-tools
ARG CMDLINE_TOOLS_REV=13114758
RUN mkdir -p /opt/android-sdk && \
    cd /opt/android-sdk && \
    wget -qO cmdline-tools.zip "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_REV}_latest.zip" && \
    unzip -q cmdline-tools.zip -d /opt/android-sdk/cmdline-tools-tmp && \
    mkdir -p /opt/android-sdk/cmdline-tools/latest && \
    mv /opt/android-sdk/cmdline-tools-tmp/cmdline-tools/* /opt/android-sdk/cmdline-tools/latest/ && \
    rm -rf /opt/android-sdk/cmdline-tools-tmp cmdline-tools.zip

# Install fvm and Flutter 3.27.1
RUN git clone https://github.com/leoafarias/fvm.git /opt/fvm && \
    cd /opt/fvm && \
    git checkout tags/3.3.2 && \
    dart pub get && \
    dart compile exe bin/main.dart -o /usr/local/bin/fvm

# Download Flutter 3.27.1 via fvm
ENV FVM_HOME=/opt/fvm_home
RUN mkdir -p $FVM_HOME && \
    cd $FVM_HOME && \
    fvm install 3.27.1 && \
    fvm global 3.27.1

# ---- main stage ----
FROM ghcr.io/yuki-js/dotfiles/dotimage:latest
USER root
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openjdk-21-jdk git && \
    rm -rf /var/lib/apt/lists/*
# Android/Flutter environment
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV FVM_HOME=/opt/fvm_home
# Prefer fvm and Flutter tooling first in PATH
ENV PATH="/usr/local/bin:$FVM_HOME/default/bin:$FVM_HOME/default/bin/cache/dart-sdk/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
# Pin toolchain paths to values observed at runtime to avoid Gradle scanning/downloads
ENV ANDROID_NDK_ROOT=/opt/android-sdk/ndk/28.2.13676358
ENV ANDROID_NDK_HOME=/opt/android-sdk/ndk/28.2.13676358
ENV CMAKE_HOME=/opt/android-sdk/cmake/3.22.1

# Copy hoisted files from download stage
COPY --from=download --chown=user:user /opt/android-sdk/cmdline-tools/latest /opt/android-sdk/cmdline-tools/latest
COPY --from=download --chown=user:user /usr/local/bin/fvm /usr/local/bin/fvm
COPY --from=download --chown=user:user /opt/fvm_home /opt/fvm_home

# Latest cmdline-tools revision (discovered externally)
ARG CMDLINE_TOOLS_REV=13114758

# Install Android cmdline-tools and MINIMAL packages only
RUN set -eux; \
    yes | sdkmanager --licenses > /dev/null || true; \
    sdkmanager "platform-tools" "platforms;android-36" "platforms;android-35" "build-tools;35.0.0" "cmake;3.22.1" "ndk;28.2.13676358"

# Switch back to user
USER user

# Copy codex config file
RUN mkdir -p ~/.codex
COPY --chown=user:user .devcontainer/codex-config/config.toml /home/user/.codex/config.toml
RUN set -eux; \
    git config --global --add safe.directory $FVM_HOME/default; \
    fvm flutter config --android-sdk "$ANDROID_SDK_ROOT"; 

CMD ["/bin/zsh"]
