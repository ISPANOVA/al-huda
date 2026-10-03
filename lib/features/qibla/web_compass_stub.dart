/// Native build: flutter_compass is used instead.
bool get webCompassNeedsPermission => false;

/// Native build: flutter_compass is used instead.
Future<bool> requestWebCompassPermission() async => true;

/// Native build: flutter_compass is used instead.
Stream<double> webCompassHeadings() => const Stream.empty();
