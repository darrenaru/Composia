import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final Widget? leading;

  const CustomAppBar({
    super.key,
    this.title,
    this.actions,
    this.onBack,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: leading ??
          IconButton(
            onPressed: onBack ?? () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary),
          ),
      title: title != null ? Text(title!) : null,
      actions: actions,
    );
  }
}
