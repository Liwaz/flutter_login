import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_login/app.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const App());
}