import 'package:flutter/widgets.dart';

bool reducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
