import 'package:flutter/material.dart';

import 'package:fmark_camera/src/presentation/camera/camera_screen.dart';
import 'package:fmark_camera/src/presentation/gallery/gallery_screen.dart';
import 'package:fmark_camera/src/presentation/profiles/profile_editor_screen.dart';
import 'package:fmark_camera/src/presentation/profiles/profiles_screen.dart';
import 'package:fmark_camera/src/presentation/settings/settings_screen.dart';
import 'package:fmark_camera/src/services/bootstrapper.dart';

class FmarkCameraApp extends StatefulWidget {
  const FmarkCameraApp({super.key});

  @override
  State<FmarkCameraApp> createState() => _FmarkCameraAppState();
}

class _FmarkCameraAppState extends State<FmarkCameraApp> {
  final Bootstrapper _bootstrapper = Bootstrapper();
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    await _bootstrapper.initialize();
    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Fmark Camera',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: CameraScreen(bootstrapper: _bootstrapper),
      routes: {
        ProfilesScreen.routeName: (context) =>
            ProfilesScreen(bootstrapper: _bootstrapper),
        ProfileEditorScreen.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is ProfileEditorArguments) {
            return ProfileEditorScreen(arguments: args);
          }
          final fallback = _bootstrapper.profilesController.activeProfile ??
              _bootstrapper.profilesController.profiles.first;
          return ProfileEditorScreen(
            arguments: ProfileEditorArguments(
              profileId: fallback.id,
              bootstrapper: _bootstrapper,
              fallbackCanvasSize: fallback.canvasSize,
            ),
          );
        },
        GalleryScreen.routeName: (_) =>
            GalleryScreen(bootstrapper: _bootstrapper),
        SettingsScreen.routeName: (_) =>
            SettingsScreen(bootstrapper: _bootstrapper),
      },
    );
  }
}
