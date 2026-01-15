// Stub implementations for web platform compatibility
// This file is used when compiling for web instead of dart:io

// Stub Platform class
class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
  static String get operatingSystem => 'web';
}

// Stub File class
class File {
  final String path;
  File(this.path);
  Future<bool> exists() async => false;
  Future<File> writeAsBytes(List<int> bytes) async => this;
}
