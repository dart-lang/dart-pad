import 'package:flutter/material.dart';

import '../../model.dart';

class EditorWidgetImpl extends StatelessWidget {
  final AppModel appModel;
  final AppServices appServices;

  const EditorWidgetImpl({
    required this.appModel,
    required this.appServices,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Text('Editor Widget Implementation for MacOS');
  }
}
