import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/device.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await MiaDevice.detect();
  runApp(const MiaStreamApp());
}
