void main() {
  bool _isNewerVersion(String current, String release) {
    List<int> currentParts = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    List<int> releaseParts = release.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (int i = 0; i < releaseParts.length; i++) {
        int c = i < currentParts.length ? currentParts[i] : 0;
        int r = releaseParts[i];
        if (r > c) return true;
        if (r < c) return false;
    }
    return false;
  }
  
  print("1.0.0 vs 8: ${_isNewerVersion('1.0.0', '8')}");
  print("1.0.0 vs 1.0.0: ${_isNewerVersion('1.0.0', '1.0.0')}");
  print("1.0.0 vs 1.0.1: ${_isNewerVersion('1.0.0', '1.0.1')}");
}
