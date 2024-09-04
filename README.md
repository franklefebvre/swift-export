## What is swift-export?

`swift-export` is a command-line tool used to generate signed and notarized installer packages for macOS. The generated installer packages can contain any executable file (built from a Swift Package Manager project) and optional payloads, such as LaunchDaemons plist files. It runs on macOS 13 and above.

You can download the installer here: [swift-export.pkg](https://raw.githubusercontent.com/franklefebvre/swift-export/main/swift-export.pkg), or build the tool from source.

## Basic Usage

- build a universal binary from a Swift package
- sign it
- generate a signed and notarized installer package

### Command-line options

Assuming the working directory is the directory containing the `Package.swift` file:

`swift export --identifier <identifier> --executable-certificate <application cert> --package-certificate <installer cert> --package-version <version> --notary-profile <notary profile name>`

- `identifier`: a unique identifier for the executable, typically in the form `com.your-domain.executable-name`
- `application cert` and `installer cert`: certificates to be used for code signing (see [Code signing identities](#code-signing-identities) below)
- `version`: the version of the installer package
- `notary profile name`: the name of the profile stored in the keychain for notarization (see [Notary identity](#notary-identity) below)

### Configuration file and environment

If the project contains a file named "export.yml", either at its root or in a directory named "export", with the following contents:

```
executable:
  identifier: com.your-domain.executable-name
package:
  version: 1.0
```

and these environment variables are defined:

```
SWIFT_EXPORT_EXECUTABLE_CERTIFICATE=<application cert>
SWIFT_EXPORT_PACKAGE_CERTIFICATE=<installer cert>
SWIFT_EXPORT_NOTARY_PROFILE=<notary profile name>
```

then the command can be reduced to `swift export`.

## Advanced Usage

### Sandboxing and entitlements

By default the executable is built with the hardened runtime enabled, without sandboxing. For other situations (e.g. to enable sandboxing or to give additional entitlements), it is possible to provide an entitlements file. It should be named "hardened.entitlements" in the same directory as the `export.yml` file, or its path can be specified in the config file.

### Installation destination

By default the executable is installed in `/usr/local/bin`. This can be changed by adding this entry to the `export.yml` file:

```
package:
  executable:
    destination: /path/to/install/directory
```

### Additional installer payload

It is possible to provide additional files to be part of the installer package. For instance if the executable is a daemon, a plist file (e.g. `com.your-domain.service-name.plist`) should be installed in `/Library/LaunchDaemons`:

- add the `com.your-domain.service-name.plist` file to your project

- add the following lines to `export.yml`:

```
package:
  resources:
  - source: com.your-domain.service-name.plist
    destination: /Library/LaunchDaemons
```

## Option precedence

Some settings can be given as command-line options and defined in the configuration file or as environment variables. In that case, the command-line option has priority over the configuration file setting, which has priority over the environment variable.

The following elements are mandatory, whether they are provided as environment variables, in the config file, or on the command line:

- executable identifier
- executable certificate
- package certificate
- package version
- notary profile

Everything else is optional.

## Command-line options

### `--config-dir <path>`

Specifies the directory containing the configuration and code-signing files. The path can be either absolute or relative to the current directory.

By default, if a directory named `export` is found in the current directory, it is used; otherwise the current directory is used.

### `--export-config <path>`

The path to the `export.yaml`, `export.yml` or `export.plist` file containing the export configuration. The path can be either absolute or relative to the directory specified by `--config-dir`.

By default, files `export.yaml`, `export.yml` and `export.plist` are searched, in this order.

### `--identifier <identifier>`

The identifier used to sign the executable binary. Same format as a bundle identifier, e.g. "com.example.MyAwesomeTool".

This option overrides the identifier specified in `executable.identifier` in the export configuration.

### `--executable-certificate <identity>`

The "Developer ID Application" certificate used to sign the executable file. Either the common name or the SHA-1 hash of the certificate can be provided.

This option overrides the SWIFT_EXPORT_EXECUTABLE_CERTIFICATE environment variable and the value specified in `executable.certificate` in the export configuration.

### `--package-certificate <identity>`

The "Developer ID Installer" certificate used to sign the installer package. Either the common name or the SHA-1 hash of the certificate can be provided.

This option overrides the SWIFT_EXPORT_PACKAGE_CERTIFICATE environment variable and the value specified in `package.certificate` in the export configuration.

### `--entitlements <path>`

The path to the entitlements file used for code signing. The path can be either absolute or relative to the directory containing the export configuration file.

This option overrides the path specified in `executable.entitlements` in the export configuration.

Default value: `hardened.entitlements` if this file exists. Otherwise default entitlements will be provided, with hardened runtime enabled and sandbox disabled.

### `--output <path>`

The output path (either pkg file or parent directory). The path can be either absolute or relative to the current directory.

If a directory is provided, the name of the package will be based on the project name.

Default value: current directory.

### `--package-identifier <identifier>`

The identifier used to sign the installer package. Same format as a bundle identifier, e.g. "com.example.MyAwesomeTool".

This option overrides the identifier specified in `package.identifier` in the export configuration.

Default value: same as executable identifier.

### `--package-version <version>`

The version number of the installer package.

This option overrides the identifier specified in `package.version` in the export configuration.

### `--notary-profile <name>`

The keychain profile name used to identify the developer account when submitting the package for notarization.

This option overrides the SWIFT_EXPORT_NOTARY_PROFILE environment variable and the name specified in `notary.profile` in the export configuration.

### `--verbose`

Print debugging and progress messages.

### `--dry-run`

Print the commands to be performed, without actually performing them.

### `--help`

Show help information.

## Configuration file

The configuration file can be in either YAML or plist format.

If an explicit filename is specified with the `--export-config` option, it is used. Otherwise `swift export` searches for a file named "export.yaml", "export.yml" or "export.plist" in the directory specified by the `--config-dir` option.

If neither the `--export-config` option no the `--config-dir` option is given, the configuration file is searched in an "export" directory if it exists, then in the current directory.

The configuration file has the following structure (all fields are optional):

- `executable`
  - `architectures`: list of target architectures as an array of strings, default: [arm64, x86_64]
  - `identifier`: unique identifier used for code signing
  - `certificate`: Developer ID Application certificate name or hash
  - `entitlements`: path to an entitlements file (defaults to "hardened.entitlements" if such a file exists in the configuration directory, otherwise the executable is built with hardened runtime enabled and sandboxing disabled)
- `package`
  - `identifer`: unique identifier used for code signing (default: same as executable.identifier)
  - `version`: version of the .pkg file
  - `certificate`: Developer ID Installer certificate name or hash
  - `executable`
    - `source`: name of the executable to be built (default: determined by Package.swift)
    - `destination`: path where the executable should be installed (default: /usr/local/bin)
  - `resources`: array of additional files to be installed; for each file:
    - `source`: name or path of the resource to be copied to the installer package
    - `destination`: path where it should be installed
- `notary`
  - `keychain-profile`: name of the saved credentials in the keychain (see [Notary identity](#notary-identity))

## Environment

Some settings should not appear in a git repository, either for security reasons, or because they can differ across users. For this reason, these settings can be provided as environment variables:

- `SWIFT_EXPORT_EXECUTABLE_CERTIFICATE`: the common name or SHA-1 hash of the "Developer ID Application" certificate
- `SWIFT_EXPORT_PACKAGE_CERTIFICATE`: the common name or SHA-1 hash of the "Developer ID Installer" certificate
- `SWIFT_EXPORT_NOTARY_PROFILE`: the name of the keychain profile used for notarization

Since these settings are likely to be shared across projects for a given user, a recommendation is to declare them in a shell profile (`~/.profile`, `~/.zshrc`, etc).

```
export SWIFT_EXPORT_EXECUTABLE_CERTIFICATE=...
export SWIFT_EXPORT_PACKAGE_CERTIFICATE=...
export SWIFT_EXPORT_NOTARY_PROFILE=...
```

## Code signing identities

`swift export` needs two certificates: a "Developer ID Application" certificate to sign the executable, and a "Developer ID Installer" certificate to sign the installer package.

These certificates can be created on your Apple Developer account: https://developer.apple.com/account/resources/certificates/add

Later on these certificates can be referred to by either their common names (typically "Developer ID Application: your name (team id)" and "Developer ID Installer: your name (team id)") or by their SHA-1 hashes, visible at the bottom of the Details section of the certificates in the keychain application.

Note:

- Search by common name is case-sensitive
- SHA-1 hashes must consist of exactly 40 hexadecimal digits (no spaces)

## Notary identity

In order to submit your package for notarization, you need to provide the Apple ID of your developer account to the notary service. A secure way to achieve this is to create an app-specific password and to store it in the keychain.

First generate an app-specific password on https://appleid.apple.com, by following these instructions: https://support.apple.com/en-us/102654

Then run this command: `xcrun notarytool store-credentials`. The tool will interactively prompt you for a profile name, your developer Apple ID, your app-specific password, and your Team ID.

Your credentials are stored in the keychain, and you can now provide `notarytool` with the profile name whenever you need to submit any application or package for notarization.

