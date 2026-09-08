// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The preset viewport and device modes for the preview panel.
enum DeviceMode {
  /// Responsive mode using the available preview container dimensions.
  current,

  /// Mobile device viewport preset (390 x 846).
  mobile((390, 846)),

  /// Tablet device viewport preset (760 x 576).
  tablet((760, 576));

  const DeviceMode([this.size]);

  /// The width and height dimensions in pixels, or `null` for responsive sizing.
  final (int, int)? size;

  String get title => switch (this) {
    DeviceMode.current => 'Current screen size',
    DeviceMode.mobile => 'Mobile',
    DeviceMode.tablet => 'Tablet',
  };

  String get icon => switch (this) {
    DeviceMode.current => 'devices',
    DeviceMode.mobile => 'smartphone',
    DeviceMode.tablet => 'tablet',
  };
}
