import 'dart:io';
import 'package:args/args.dart';

import 'printer.dart';

class JobEntry {
  const JobEntry({
    required this.description,
    required this.command,
    required this.arguments,
    this.pwd,
  });

  final String description;
  final String command;
  final String? pwd;
  final String arguments;
}

Future<void> main(List<String> args) async {
  var parser = ArgParser()
    ..addFlag('clean', abbr: 'c', defaultsTo: true)
    ..addFlag('verbose', abbr: 'v', defaultsTo: false);

  final result = parser.parse(args);

  final pwd = Directory.current.path;

  final iosDirectory = Directory('$pwd/ios').path;
  final haveIOS = Directory(iosDirectory).existsSync();
  final haveL10n = File('$pwd/l10n.yaml').existsSync();

  final jobs = <JobEntry>[
    if (result['clean'])
      JobEntry(
        description: 'Clean Flutter Project',
        command: 'flutter',
        arguments: 'clean',
        pwd: pwd,
      ),
    JobEntry(
      description: 'Remove Pub Lock Project',
      command: 'rm',
      arguments: '-rf pubspec.lock',
      pwd: pwd,
    ),

    ///! iOS
    if (haveIOS) ...[
      JobEntry(
        description: 'Pod deintegrate',
        command: 'pod',
        arguments: 'deintegrate',
        pwd: iosDirectory,
      ),
      JobEntry(
        description: 'Remove Pod File',
        command: 'rm',
        arguments: '-rf Pods',
        pwd: iosDirectory,
      ),
      JobEntry(
        description: 'Remove Cached iOS Flutter Libs',
        command: 'rm',
        arguments: '-rf .symlinks',
        pwd: iosDirectory,
      ),
      JobEntry(
        description: 'Remove Podfile.lock',
        command: 'rm',
        arguments: '-rf Podfile.lock',
        pwd: iosDirectory,
      ),
    ],

    ///! Home
    JobEntry(
      description: 'Get flutter packages',
      command: 'flutter',
      arguments: 'pub get',
      pwd: pwd,
    ),

    ///! iOS
    if (haveIOS)
      JobEntry(
        description: 'Pod install & update',
        command: 'pod',
        arguments: 'install --repo-update',
        pwd: iosDirectory,
      ),

    ///! Home
    if (haveL10n)
      JobEntry(
        description: 'Generate L10N',
        command: 'flutter',
        arguments: 'gen-l10n',
        pwd: pwd,
      ),
    JobEntry(
      description: 'Generate Freezed Models',
      command: 'dart',
      pwd: pwd,
      arguments: 'run build_runner build --delete-conflicting-outputs',
    ),
  ];

  final ext = '#' * 24;

  Printer.yellow.log('\n$ext re-install started $ext\n');
  Printer.cyan.log('pwd: $pwd\n');

  for (final job in jobs) {
    Printer.blue.log('┌⏺ ${job.description}');
    Printer.green.log('├❯ ${job.command} ${job.arguments}');

    final process = await Process.run(
      job.command,
      job.arguments.split(' '),
      workingDirectory: job.pwd,
    );

    if (result['verbose']) {
      final out = (process.stdout as String).trim();
      if (out.isNotEmpty) {
        Printer.white.log(out.split('\n').map((line) => '├❯ $line').join('\n'));
      }
    }

    if (process.exitCode != 0) {
      Printer.red.log('└❯ exit(${process.exitCode}): ${process.stderr}');
    } else {
      Printer.green.log('└❯ exit(${process.exitCode})');
    }

    print('\n');
  }

  Printer.yellow.log('$ext re-install end $ext');
}
