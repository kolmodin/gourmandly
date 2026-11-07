import 'package:flutter/material.dart';

import 'theme.dart';

/// Shows [builder]'s content over the screen: in a bottom sheet on a phone,
/// within reach of the thumb, and in a dialog in the middle of a wide screen.
Future<T?> showPanel<T>(BuildContext context, WidgetBuilder builder) =>
    MediaQuery.sizeOf(context).width >= wideBreakpoint
    ? showDialog<T>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Palette.enamel,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: builder(context),
          ),
        ),
      )
    : showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Palette.enamel,
        builder: builder,
      );
