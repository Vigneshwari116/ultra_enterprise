import 'device_name_io.dart' if (dart.library.html) 'device_name_web.dart' as device_name_impl;

/// Web: Chrome or Edge (or Web). Android and Windows use the names the API stores.
String currentDeviceName() => device_name_impl.currentDeviceName();
