import 'package:dotenv/dotenv.dart';

class EnvService {
  final _dotenv = DotEnv();

  EnvService() {
    _dotenv.load();
  }

  String? get(String key) {
    return _dotenv[key];
  }
} 