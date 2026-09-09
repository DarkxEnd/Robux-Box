import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the deploy workflow against dropping an environment variable the
/// Cloud Functions actually read.
///
/// `.github/workflows/deploy-firebase.yml` writes `functions/.env`; the
/// handlers read `process.env.X`. Nothing connects the two but the spelling,
/// and a mismatch is invisible until a payout quietly stops: the workflow
/// wrote `LOOTWALLS_SECRET` while the handler read `LOOTWALLS_POSTBACK_SECRET`,
/// so every Lootwalls completion was answered 503 and no one was credited.
/// Neither side is wrong on its own, which is why only a check across both
/// catches it.
void main() {
  /// Variables the code reads that the workflow is not expected to supply,
  /// with the reason each is exempt. Anything else read by the functions must
  /// appear in the workflow.
  const suppliedElsewhere = <String, String>{
    // Set by the deploy step itself from the service-account secret.
    'GOOGLE_APPLICATION_CREDENTIALS': 'written to GITHUB_ENV by the deploy job',
    // Optional runtime toggles with safe defaults in code.
    'ENFORCE_APP_CHECK': 'optional toggle, defaults in code',
    'STRICT_SSV': 'optional toggle, defaults in code',
    // One-off bootstrap and Play integration, configured out of band.
    'ADMIN_BOOTSTRAP_EMAIL': 'one-off admin bootstrap, set by hand',
    'PLAY_SERVICE_ACCOUNT_JSON_BASE64': 'Play integration, set by hand',
  };

  late final Set<String> readByFunctions;
  late final Set<String> writtenByWorkflow;

  setUpAll(() {
    final srcDir = Directory('functions/src');
    expect(
      srcDir.existsSync(),
      isTrue,
      reason: 'functions/src must exist for this check to mean anything',
    );
    final sources = srcDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.ts'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    readByFunctions = RegExp(
      r'process\.env\.([A-Z0-9_]+)',
    ).allMatches(sources).map((m) => m.group(1)!).toSet();

    final workflow = File('.github/workflows/deploy-firebase.yml');
    expect(workflow.existsSync(), isTrue);
    final yaml = workflow.readAsStringSync();
    // The `echo "NAME=$NAME"` lines that build functions/.env.
    writtenByWorkflow = RegExp(
      r'echo "([A-Z0-9_]+)=',
    ).allMatches(yaml).map((m) => m.group(1)!).toSet();
  });

  test(
    'every env var the functions read is written by the deploy workflow',
    () {
      expect(
        readByFunctions,
        isNotEmpty,
        reason: 'could not find any process.env reads — the scan is broken',
      );
      final missing =
          readByFunctions
              .difference(writtenByWorkflow)
              .where((v) => !suppliedElsewhere.containsKey(v))
              .toList()
            ..sort();
      expect(
        missing,
        isEmpty,
        reason:
            'these are read at runtime but never written to functions/.env, so '
            'they are empty in production: ${missing.join(', ')}. Add them to '
            'the "Set function secrets" step, or list them in '
            'suppliedElsewhere with the reason they do not belong there.',
      );
    },
  );

  test('the workflow writes nothing the functions never read', () {
    // A stale name here is not dangerous, but it is a lie: it reads like the
    // value is in use, and the real variable next to it may be missing.
    final unused =
        writtenByWorkflow
            .difference(readByFunctions)
            .where((v) => !suppliedElsewhere.containsKey(v))
            .toList()
          ..sort();
    expect(
      unused,
      isEmpty,
      reason:
          'written to functions/.env but read by nothing: ${unused.join(', ')}',
    );
  });
}
