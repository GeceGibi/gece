import 'dart:io';

import 'package:args/args.dart';
import 'package:intl/intl.dart';
import 'package:yaml/yaml.dart';

import 'printer.dart';
// ignore_for_file: avoid_print

enum Platform { google, huawei, ios }

Platform getPlatform(String platform) {
  switch (platform) {
    case 'google':
      return Platform.google;

    case 'huawei':
      return Platform.huawei;

    case 'ios':
    default:
      return Platform.ios;
  }
}

class Build {
  Build({
    required String platform,
    required this.version,
    this.major,
    this.number,
  }) : platform = getPlatform(platform);

  final Platform platform;
  final String version;
  final int? major;
  final int? number;

  final pwd = Directory.current.path;

  Future<bool> call() async {
    try {
      final (version, number) = getVersion();

      await updateYaml(version, number);
      await updatePList(version, number);

      logVersion(version, number);
    } catch (e) {
      return false;
    }

    return true;
  }

  (String, int)? readVersionFromYaml() {
    final pubspec = File('$pwd/pubspec.yaml');

    if (!pubspec.existsSync()) {
      return null;
    }

    final yaml = loadYaml(pubspec.readAsStringSync());

    if (yaml is! YamlMap || !yaml.containsKey('version')) {
      return null;
    }
    final version = yaml['version'] as String;
    final hasPlus = version.contains('+');
    final divided = version.split('+');

    return hasPlus ? (divided.first, int.parse(divided.last)) : (version, 0);
  }

  (String, int) getVersion() {
    if (number != null) {
      return (version, number!);
    }

    final formatBase = platform == Platform.ios ? 'yyMMDD' : 'yyMMDDHH';
    final format = '${(major ?? '')}$formatBase';

    return (version, int.parse(DateFormat(format).format(DateTime.now())));
  }

  Future<void> updateYaml(String version, int build) async {
    final pubspec = File('$pwd/pubspec.yaml');
    final lines = await pubspec.readAsLines();

    final file = lines.map((line) {
      if (line.startsWith('version:')) {
        return 'version: $version+$build';
      }

      return line;
    });

    await pubspec.writeAsString(file.join('\n'));
  }

  Future<void> updatePList(String version, int build) async {
    final plist = File('$pwd/ios/Runner/Info.plist');
    final lines = await plist.readAsLines();
    final pattern = RegExp(r'\t');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.contains('CFBundleShortVersionString')) {
        final indent = '\t' * pattern.allMatches(line).length;
        lines[i + 1] = '$indent<string>$version</string>';
      } else if (line.contains('CFBundleVersion')) {
        final indent = '\t' * pattern.allMatches(line).length;
        lines[i + 1] = '$indent<string>$build</string>';
      }
    }

    await plist.writeAsString(lines.join('\n'));
  }

  void logVersion(String version, int build) {
    final symbol = '#';
    final ornamental = symbol * 50;

    print('');
    Printer.green.log(ornamental);
    Printer.green.log('');
    Printer.green.log('');
    Printer.green.log(' Platform        :    ${platform.name}');
    Printer.green.log(' Version Name    :    $version');
    Printer.green.log(' Version Code    :    $build');
    // Printer.green.log(' Commit ID       :    \$COMMIT_ID');
    Printer.green.log('');
    Printer.green.log('');
    Printer.green.log(ornamental);
    print('');
  }
}

void main(List<String> args) async {
  final parser = ArgParser();

  parser

    //
    ..addFlag('build', abbr: 'b', defaultsTo: false)
    ..addFlag('obfuscate', abbr: 'o', defaultsTo: true)

    //
    ..addOption('major', abbr: 'm')
    ..addOption('number', abbr: 'n')
    ..addOption('version', abbr: 'v')
    ..addOption('platform', abbr: 'p', allowed: ['google', 'huawei', 'ios']);

  final arguments = parser.parse(args);
  final argVersion = arguments['version'];

  final versionPattern = RegExp(r'^[0-9]{1,2}.[0-9]{1,2}.[0-9]{1,2}$');

  if (!versionPattern.hasMatch(argVersion)) {
    print(
      '$argVersion has not valid version format. (pattern=${versionPattern.pattern})',
    );
    exit(1);
  }

  final build = Build(
    platform: arguments['platform'],
    version: argVersion,
    major: int.tryParse(arguments['major'] ?? ''),
    number: int.tryParse(arguments['number'] ?? ''),
  );

  if (await build() && arguments['build']) {
    final packageType = Platform.ios == build.platform ? 'ipa' : 'appbundle';

    final process = await Process.run('flutter', [
      'build',
      packageType,
      '--release',
      '--obfuscate',
      '--split-debug-info=build/${build.platform}/symbols'
    ]);

    if (process.exitCode != 0) {
      print(process.stderr);
    } else {
      print(process.stdout);
    }
  }
}
