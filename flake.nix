{
  description = "Gourmandly: recipes and shopping lists";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
                android_sdk.accept_license = true;
              };
            }
          )
        );

      # Tool sets, combined into one shell per CI job. A job's shell has
      # exactly what that job needs.
      toolsFor =
        pkgs:
        let
          # Versions Flutter's Gradle plugin expects; Gradle can't download
          # missing SDK components into the read-only Nix store.
          android = pkgs.androidenv.composeAndroidPackages {
            platformVersions = [ "36" ];
            buildToolsVersions = [
              "35.0.0"
              "36.0.0"
            ];
            includeNDK = true;
            ndkVersions = [ "28.2.13676358" ];
            cmakeVersions = [ "3.22.1" ];
            includeEmulator = false;
            includeSources = false;
          };
          sdk = "${android.androidsdk}/libexec/android-sdk";

          # JDK 21: required by the Firebase emulators, and runs Gradle.
          java = {
            packages = [ pkgs.jdk21 ];
            env.JAVA_HOME = pkgs.jdk21.home;
          };
        in
        {
          flutter = {
            packages = [ pkgs.flutter ];
          };
          android = {
            packages = java.packages ++ [ android.androidsdk ];
            env = java.env // {
              ANDROID_HOME = sdk;
              ANDROID_SDK_ROOT = sdk;
              GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${sdk}/build-tools/36.0.0/aapt2";
            };
          };
          node = {
            packages = [ pkgs.nodejs_24 ];
          };
          firebase = {
            packages = java.packages ++ [ pkgs.firebase-tools ];
            env = java.env;
          };
          # A browser and a chromedriver of the same major version, for
          # integration tests (flutter drive). Chromium isn't packaged for
          # macOS, so macOS uses Google Chrome.
          browser =
            let
              chrome =
                if pkgs.stdenv.hostPlatform.isDarwin then
                  "${pkgs.google-chrome}/bin/google-chrome-stable"
                else
                  "${pkgs.chromium}/bin/chromium";
            in
            {
              packages = [ pkgs.chromedriver ];
              env.CHROME_EXECUTABLE = chrome;
            };
        };

      packagesOf = pkgs: sets: pkgs.lib.concatMap (s: s.packages) sets;
      envOf = pkgs: sets: pkgs.lib.foldl' (acc: s: acc // (s.env or { })) { } sets;

      shell =
        pkgs: sets:
        pkgs.mkShell ({ packages = packagesOf pkgs sets; } // envOf pkgs sets);

      # A `nix run` target: a script from scripts/ with exactly the given tool
      # sets on its PATH.
      app =
        pkgs: name: sets: script:
        let
          drv = pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = packagesOf pkgs sets ++ [
              pkgs.git
              pkgs.curl
            ];
            runtimeEnv = envOf pkgs sets;
            text = builtins.readFile script;
          };
        in
        {
          type = "app";
          program = "${drv}/bin/${name}";
        };
    in
    {
      devShells = forAllSystems (
        pkgs:
        let
          t = toolsFor pkgs;
        in
        {
          # Local development: everything.
          default = shell pkgs [
            t.flutter
            t.android
            t.node
            t.firebase
            t.browser
          ];

          # CI jobs.
          dart = shell pkgs [ t.flutter ]; # domain package and app unit tests, web build
          android = shell pkgs [
            t.flutter
            t.android
          ];
          functions = shell pkgs [ t.node ];
          emulators = shell pkgs [
            t.node
            t.firebase
          ]; # rules tests, Functions integration tests
          integration = shell pkgs [
            t.flutter
            t.node
            t.firebase
            t.browser
          ]; # app tests against the emulators
        }
      );

      apps = forAllSystems (
        pkgs:
        let
          t = toolsFor pkgs;
        in
        {
          # Emulators plus the web app with hot reload.
          default = app pkgs "gourmandly-dev" [
            t.flutter
            t.node
            t.firebase
          ] ./scripts/dev.sh;
          emulators = app pkgs "gourmandly-emulators" [
            t.node
            t.firebase
          ] ./scripts/emulators.sh;
          test = app pkgs "gourmandly-test" [
            t.flutter
            t.node
            t.firebase
            t.browser
          ] ./scripts/test.sh;
          screenshots = app pkgs "gourmandly-screenshots" [
            t.flutter
            t.node
            t.firebase
            t.browser
          ] ./scripts/screenshots.sh;
        }
      );
    };
}
