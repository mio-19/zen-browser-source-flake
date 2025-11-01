{
  buildNpmPackage,
  buildPackages,
  fetchFromGitHub,
  fetchurl,
  fetchpatch,
  lib,
  overrideCC,
  stdenv,

  # build time
  autoconf,
  cargo,
  dump_syms,
  git,
  gnum4,
  nodejs,
  patchelf,
  pkg-config,
  pkgsBuildBuild,
  pkgsCross,
  python3,
  runCommand,
  rsync,
  rustc,
  rust-cbindgen,
  rustPlatform,
  unzip,
  vips,
  wrapGAppsHook3,
  writeShellScript,

  # runtime
  alsa-lib,
  atk,
  cairo,
  cups,
  dbus,
  dbus-glib,
  ffmpeg,
  fontconfig,
  freetype,
  gdk-pixbuf,
  gtk3,
  glib,
  icu73,
  jemalloc,
  libGL,
  libGLU,
  libdrm,
  libevent,
  libffi,
  libglvnd,
  libjack2,
  libjpeg,
  libkrb5,
  libnotify,
  libpng,
  libpulseaudio,
  libstartup_notification,
  libva,
  libvpx,
  libwebp,
  libxkbcommon,
  libxml2,
  makeWrapper,
  mesa,
  nasm,
  nspr,
  nss_latest,
  pango,
  pciutils,
  pipewire,
  sndio,
  udev,
  xcb-util-cursor,
  xorg,
  zlib,

  # Generic changes the compatibility mode of the final binaries.
  #
  # Enabling generic will make the browser compatible with more devices at the
  # cost of disabling hardware-specific optimizations. It is highly recommended
  # to leave `generic` disabled.
  generic ? false,
  debugBuild ? false,

  # On 32bit platforms, we disable adding "-g" for easier linking.
  enableDebugSymbols ? !stdenv.hostPlatform.is32bit,
  alsaSupport ? stdenv.hostPlatform.isLinux,
  ffmpegSupport ? true,
  gssSupport ? true,
  jackSupport ? stdenv.hostPlatform.isLinux,
  jemallocSupport ? !stdenv.hostPlatform.isMusl,
  pipewireSupport ? waylandSupport && webrtcSupport,
  pulseaudioSupport ? stdenv.hostPlatform.isLinux,
  sndioSupport ? stdenv.hostPlatform.isLinux,
  waylandSupport ? true,

  privacySupport ? false,

  # WARNING: NEVER set any of the options below to `true` by default.
  # Set to `!privacySupport` or `false`.
  crashreporterSupport ?
    !privacySupport && !stdenv.hostPlatform.isRiscV && !stdenv.hostPlatform.isMusl,
  geolocationSupport ? !privacySupport,
  webrtcSupport ? !privacySupport,

  version,
  firefoxVersion,
}:
let
  surfer = buildNpmPackage {
    pname = "surfer";
    version = "1.11.22";

    src = fetchFromGitHub {
      owner = "zen-browser";
      repo = "surfer";
      rev = "0f163403d3a056ce4af586ed6f0e8b85bdffd411";
      hash = "sha256-1V/LbdhEgFh9zGjyaTl7tDPiWJA89ZPnUkY48A0XfAA=";
    };

    patches = [
      ./surfer-dont-check-update.patch
    ];

    npmDepsHash = "sha256-H0D9d2eQhYSWiDZLXOCL1ave+WtUioavYv474V9P+68=";
    makeCacheWritable = true;

    SHARP_IGNORE_GLOBAL_LIBVIPS = false;
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ vips ];
  };

  llvmPackages0 = rustc.llvmPackages;
  llvmPackagesBuildBuild0 = pkgsBuildBuild.rustc.llvmPackages;

  llvmPackages = llvmPackages0.override {
    bootBintoolsNoLibc = null;
    bootBintools = null;
  };
  llvmPackagesBuildBuild = llvmPackagesBuildBuild0.override {
    bootBintoolsNoLibc = null;
    bootBintools = null;
  };

  buildStdenv = overrideCC llvmPackages.stdenv (
    llvmPackages.stdenv.cc.override { bintools = buildPackages.rustc.llvmPackages.bintools; }
  );

  inherit (pkgsCross) wasi32;

  wasiSysRoot = runCommand "wasi-sysroot" { } ''
    mkdir -p "$out"/lib/wasm32-wasi
    for lib in ${wasi32.llvmPackages.libcxx}/lib/*; do
      ln -s "$lib" "$out"/lib/wasm32-wasi
    done
  '';

  firefox-l10n = fetchFromGitHub {
    owner = "mozilla-l10n";
    repo = "firefox-l10n";
    rev = "cb78eda133a3a962ebac181a94bc3480017bca92";
    hash = "sha256-+XdVM8bPg5Ro3Nuuo4ljpbPZt3TC7emdLdMKURx0GnY=";
  };
  disableAVX = if stdenv.hostPlatform.system == "aarch64-linux" then "--disable-wasm-avx" else "";
in
buildStdenv.mkDerivation (finalAttrs: {
  pname = "zen-browser-unwrapped";
  inherit version;

  src = fetchFromGitHub {
    owner = "zen-browser";
    repo = "desktop";
    rev = finalAttrs.version;
    hash = "sha256-MRxFzT4kVDEDc6M8r14LmD49/teImpMD21EYFRWPKcE=";
    fetchSubmodules = true;
  };

  # DO NOT UPDATE THE FIREFOX VERSION MANUALLY!
  #
  # Both `firefoxVersion` and `firefoxSrc` are managed by the `update.sh` script.
  # The Firefox version is specified by `zen-browser` in the `surfer.json` file.
  #
  # We need to manually set the version here to avoid IFD.
  inherit firefoxVersion;
  firefoxSrc = fetchurl {
    url = "mirror://mozilla/firefox/releases/${finalAttrs.firefoxVersion}/source/firefox-${finalAttrs.firefoxVersion}.source.tar.xz";
    hash = "sha256-6sRyLtJZAI1zAGxIlMGNKHFwLGYdFOJ1BYEjUd9igGs=";
  };

  SURFER_COMPAT = generic;

  nativeBuildInputs = [
    autoconf
    cargo
    git
    gnum4
    llvmPackagesBuildBuild.bintools
    makeWrapper
    nasm
    nodejs
    pkg-config
    python3
    rsync
    rust-cbindgen
    rustPlatform.bindgenHook
    rustc
    surfer
    unzip
    wrapGAppsHook3
    xorg.xvfb
  ]
  ++ lib.optionals crashreporterSupport [
    dump_syms
    patchelf
  ];

  buildInputs = [
    atk
    cairo
    cups
    dbus
    dbus-glib
    ffmpeg
    fontconfig
    freetype
    gdk-pixbuf
    gtk3
    glib
    icu73
    libGL
    libGLU
    libevent
    libffi
    libglvnd
    libjpeg
    libnotify
    libpng
    libstartup_notification
    libva
    libvpx
    libwebp
    libxml2
    mesa
    nspr
    nss_latest
    pango
    pciutils
    pipewire
    udev
    xcb-util-cursor
    xorg.libX11
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXft
    xorg.libXi
    xorg.libXrender
    xorg.libXt
    xorg.libXtst
    xorg.pixman
    xorg.xorgproto
    xorg.libxcb
    xorg.libXrandr
    xorg.libXcomposite
    xorg.libXfixes
    xorg.libXScrnSaver
    zlib
  ]
  ++ lib.optional alsaSupport alsa-lib
  ++ lib.optional jackSupport libjack2
  ++ lib.optional pulseaudioSupport libpulseaudio
  ++ lib.optional sndioSupport sndio
  ++ lib.optional gssSupport libkrb5
  ++ lib.optional jemallocSupport jemalloc
  ++ lib.optionals waylandSupport [
    libdrm
    libxkbcommon
  ];

  configureFlags = [
    "--disable-bootstrap"
    "--disable-updater"
    "${disableAVX}"
    "--enable-default-toolkit=cairo-gtk3${lib.optionalString waylandSupport "-wayland"}"
    "--enable-system-pixman"
    "--with-distribution-id=org.nixos"
    "--with-libclang-path=${llvmPackagesBuildBuild.libclang.lib}/lib"
    "--with-system-ffi"
    "--with-system-icu"
    "--with-system-jpeg"
    "--with-system-libevent"
    "--with-system-libvpx"
    "--with-system-nspr"
    "--with-system-nss"
    "--with-system-png" # needs APNG support
    "--with-system-webp"
    "--with-system-zlib"
    "--with-wasi-sysroot=${wasiSysRoot}"
    "--host=${buildStdenv.buildPlatform.config}"
    "--target=${buildStdenv.hostPlatform.config}"
  ]
  ++ [
    (lib.enableFeature alsaSupport "alsa")
    (lib.enableFeature ffmpegSupport "ffmpeg")
    (lib.enableFeature geolocationSupport "necko-wifi")
    (lib.enableFeature gssSupport "negotiateauth")
    (lib.enableFeature jackSupport "jack")
    (lib.enableFeature jemallocSupport "jemalloc")
    (lib.enableFeature pulseaudioSupport "pulseaudio")
    (lib.enableFeature sndioSupport "sndio")
    (lib.enableFeature webrtcSupport "webrtc")
    # --enable-release adds -ffunction-sections & LTO that require a big amount
    # of RAM, and the 32-bit memory space cannot handle that linking
    (lib.enableFeature (!debugBuild && !stdenv.hostPlatform.is32bit) "release")
    (lib.enableFeature enableDebugSymbols "debug-symbols")
  ];

  configureScript = writeShellScript "configureMozconfig" ''
    ${
      if stdenv.hostPlatform.system == "aarch64-linux" then
        ''
          echo "ac_add_options --with-libclang-path=/usr/lib64" >> ./configs/linux/mozconfig

          # linux mozconfig
          sed -i 's/x86-\(64\|64-v3\)/native/g' ./configs/linux/mozconfig
          sed -i 's/x86_64-pc-linux/aarch64-linux-gnu/g' ./configs/linux/mozconfig

          # eme/widevine must be disabled on arm64 (thx google)
          sed -i '/--enable-eme/s/^/# /' ./configs/common/mozconfig
          sed -i 's/-msse3//g' ./configs/linux/mozconfig
          sed -i 's/-mssse3//g' ./configs/linux/mozconfig
          sed -i 's/-msse4.1//g' ./configs/linux/mozconfig
          sed -i 's/-msse4.2//g' ./configs/linux/mozconfig
          sed -i 's/-mavx2//g' ./configs/linux/mozconfig
          sed -i 's/-mavx//g' ./configs/linux/mozconfig
          sed -i 's/-mfma//g' ./configs/linux/mozconfig
          sed -i 's/-maes//g' ./configs/linux/mozconfig
          sed -i 's/-mpopcnt//g' ./configs/linux/mozconfig
          sed -i 's/-mpclmul//g' ./configs/linux/mozconfig
          sed -i 's/+avx2//g' ./configs/linux/mozconfig
          sed -i 's/+sse4.1//g' ./configs/linux/mozconfig
        ''
      else
        ""
    }

    for flag in $@; do
      echo "ac_add_options $flag" >> mozconfig
    done
  '';

  # To the person reading this wondering what is going on here, this is what
  # happens when a build process relies on Git. Normally you would use `fetchgit`
  # with `leaveDotGit = true`, however that leads to reproducibility issues, so
  # instead we create our own Git repo with a single commit.
  #
  # `surfer` (the build tool made for zen-browser) uses git to read the latest
  # HEAD commit, `git apply`, and likely a few other operations.
  preConfigure = ''
    export HOME="$TMPDIR"
    git config --global user.email "nixbld@localhost"
    git config --global user.name "nixbld"
    git init
    git add --all
    git commit -m 'nixpkgs'

    export LLVM_PROFDATA=llvm-profdata
    export MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=system
    export WASM_CC=${wasi32.stdenv.cc}/bin/${wasi32.stdenv.cc.targetPrefix}cc
    export WASM_CXX=${wasi32.stdenv.cc}/bin/${wasi32.stdenv.cc.targetPrefix}c++

    export ZEN_RELEASE=1
    surfer ci --brand release --display-version ${finalAttrs.version}

    install -D ${finalAttrs.firefoxSrc} .surfer/engine/firefox-${finalAttrs.firefoxVersion}.source.tar.xz
    surfer download
    surfer import
    patchShebangs engine/mach engine/build engine/tools
  '';

  preBuild = ''
    mkdir -p l10n
    cp -r ${firefox-l10n} l10n/firefox-l10n

    for lang in $(cat ./l10n/supported-languages); do
      rsync -av --progress l10n/firefox-l10n/"$lang"/ l10n/"$lang" --exclude .git
    done

    sh scripts/copy-language-pack.sh en-US

    for lang in $(cat ./l10n/supported-languages); do
      sh scripts/copy-language-pack.sh "$lang"
    done

    Xvfb :2 -screen 0 1024x768x24 &
    export DISPLAY=:2
  '';

  buildPhase = ''
    runHook preBuild

    surfer build

    runHook postBuild
  '';

  preInstall = ''
    cd engine/obj-*
  '';

  meta = {
    mainProgram = "zen";
    description = "Firefox based browser with a focus on privacy and customization";
    homepage = "https://www.zen-browser.app/";
    license = lib.licenses.mpl20;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };

  enableParallelBuilding = true;
  requiredSystemFeatures = [ "big-parallel" ];

  passthru = {
    updateScript = ./update.sh;

    # These values are used by `wrapFirefox`.
    # ref; `pkgs/applications/networking/browsers/firefox/wrapper.nix'
    binaryName = finalAttrs.meta.mainProgram;
    applicationName = "Zen Browser";
    inherit alsaSupport;
    inherit jackSupport;
    inherit pipewireSupport;
    inherit sndioSupport;
    inherit nspr;
    inherit ffmpegSupport;
    inherit gssSupport;
    inherit gtk3;
    inherit wasiSysRoot;
  };
})
