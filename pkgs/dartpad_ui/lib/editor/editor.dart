import 'package:flutter/material.dart';

import '../model.dart';

class EditorWidget extends StatelessWidget {
  const EditorWidget({
    super.key,
    required this.appModel,
    required this.appServices,
  });

  final AppModel appModel;
  final AppServices appServices;

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
