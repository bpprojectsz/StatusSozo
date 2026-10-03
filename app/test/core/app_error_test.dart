import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/errors/error_codes.dart';

void main() {
  // Rows: kind -> [listLoad, userAction, startup].
  const Map<AppErrorKind, List<ErrorTreatment>> expected =
      <AppErrorKind, List<ErrorTreatment>>{
        AppErrorKind.accessLost: <ErrorTreatment>[
          ErrorTreatment.accessScreen,
          ErrorTreatment.toast,
          ErrorTreatment.accessScreen,
        ],
        AppErrorKind.wrongFolder: <ErrorTreatment>[
          ErrorTreatment.toast,
          ErrorTreatment.toast,
          ErrorTreatment.toast,
        ],
        AppErrorKind.pickerCancelled: <ErrorTreatment>[
          ErrorTreatment.toast,
          ErrorTreatment.toast,
          ErrorTreatment.toast,
        ],
        AppErrorKind.notFound: <ErrorTreatment>[
          ErrorTreatment.emptyState,
          ErrorTreatment.toast,
          ErrorTreatment.emptyState,
        ],
        AppErrorKind.io: <ErrorTreatment>[
          ErrorTreatment.inlineError,
          ErrorTreatment.toast,
          ErrorTreatment.inlineError,
        ],
        AppErrorKind.permissionLost: <ErrorTreatment>[
          ErrorTreatment.inlineError,
          ErrorTreatment.toast,
          ErrorTreatment.toast,
        ],
        AppErrorKind.unsupported: <ErrorTreatment>[
          ErrorTreatment.fullScreen,
          ErrorTreatment.toast,
          ErrorTreatment.fullScreen,
        ],
        AppErrorKind.persistence: <ErrorTreatment>[
          ErrorTreatment.stickyToast,
          ErrorTreatment.stickyToast,
          ErrorTreatment.stickyToast,
        ],
        AppErrorKind.unexpected: <ErrorTreatment>[
          ErrorTreatment.fullScreen,
          ErrorTreatment.toast,
          ErrorTreatment.fullScreen,
        ],
      };

  // kind -> [recoverable, retriable, userCaused].
  const Map<AppErrorKind, List<bool>> flags = <AppErrorKind, List<bool>>{
    AppErrorKind.accessLost: <bool>[true, false, false],
    AppErrorKind.wrongFolder: <bool>[true, true, true],
    AppErrorKind.pickerCancelled: <bool>[true, true, true],
    AppErrorKind.notFound: <bool>[true, false, false],
    AppErrorKind.io: <bool>[true, true, false],
    AppErrorKind.permissionLost: <bool>[true, false, false],
    AppErrorKind.unsupported: <bool>[false, false, false],
    AppErrorKind.persistence: <bool>[true, false, false],
    AppErrorKind.unexpected: <bool>[false, false, false],
  };

  test('the table covers all 9 kinds', () {
    expect(AppErrorKind.values, hasLength(9));
    expect(expected.keys.toSet(), AppErrorKind.values.toSet());
    expect(flags.keys.toSet(), AppErrorKind.values.toSet());
  });

  group('treatmentFor', () {
    for (final AppErrorKind kind in AppErrorKind.values) {
      for (final ErrorScope scope in ErrorScope.values) {
        test('${kind.name} in ${scope.name}', () {
          expect(
            treatmentFor(AppError(kind), scope),
            expected[kind]![scope.index],
          );
        });
      }
    }
  });

  group('flags', () {
    for (final AppErrorKind kind in AppErrorKind.values) {
      test(kind.name, () {
        final AppError error = AppError(kind);
        expect(error.recoverable, flags[kind]![0], reason: 'recoverable');
        expect(error.retriable, flags[kind]![1], reason: 'retriable');
        expect(error.userCaused, flags[kind]![2], reason: 'userCaused');
      });
    }
  });

  group('appErrorFromCode', () {
    test('maps every native code', () {
      expect(
        appErrorFromCode(ErrorCodes.accessLost).kind,
        AppErrorKind.accessLost,
      );
      expect(
        appErrorFromCode(ErrorCodes.notFound).kind,
        AppErrorKind.notFound,
      );
      expect(appErrorFromCode(ErrorCodes.io).kind, AppErrorKind.io);
      expect(
        appErrorFromCode(ErrorCodes.permissionLost).kind,
        AppErrorKind.permissionLost,
      );
      expect(appErrorFromCode(ErrorCodes.tooLarge).kind, AppErrorKind.io);
      expect(
        appErrorFromCode(ErrorCodes.unsupported).kind,
        AppErrorKind.unsupported,
      );
    });

    test('unknown codes become unexpected', () {
      expect(appErrorFromCode('SOMETHING_NEW').kind, AppErrorKind.unexpected);
      expect(appErrorFromCode('').kind, AppErrorKind.unexpected);
    });

    test('keeps the code, message and cause for logs', () {
      final Object cause = StateError('boom');
      final AppError error = appErrorFromCode(
        ErrorCodes.io,
        message: 'disk gone',
        cause: cause,
      );
      expect(error.detail, 'IO: disk gone');
      expect(error.cause, same(cause));
      expect(appErrorFromCode(ErrorCodes.io).detail, 'IO');
    });

    test('code strings match the native contract', () {
      expect(ErrorCodes.accessLost, 'ACCESS_LOST');
      expect(ErrorCodes.notFound, 'NOT_FOUND');
      expect(ErrorCodes.io, 'IO');
      expect(ErrorCodes.permissionLost, 'PERMISSION_LOST');
      expect(ErrorCodes.tooLarge, 'TOO_LARGE');
      expect(ErrorCodes.unsupported, 'UNSUPPORTED');
    });
  });
}
