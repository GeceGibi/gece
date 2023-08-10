import 'package:gece/printer.dart';

void main(List<String> args) {
  Printer.white.log('''
-- PLEASE RUN ONE OF THESE --

dart pub global run gece:reinstall
OR
dart pub global run gece:build -w 1.0.0 -p google -b
'''
      .trim());
}
