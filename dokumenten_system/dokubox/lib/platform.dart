import 'dart:io';

/// Handy/Tablet (Kamera, ML Kit, Android-Kanäle) – sonst Desktop (Windows).
bool get isMobile => Platform.isAndroid || Platform.isIOS;
bool get isDesktop => !isMobile;
