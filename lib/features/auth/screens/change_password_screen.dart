import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text.trim();
    final next = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Fill all password fields")));
      return;
    }
    if (next != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("New passwords don't match")),
      );
      return;
    }

    setState(() => _loading = true);
    final error = await context.read<AuthProvider>().changePassword(
      currentPassword: current,
      newPassword: next,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Password changed successfully")),
    );
    Navigator.pop(context);
  }

  InputDecoration _decoration(
    BuildContext context,
    String hint, {
    required IconData leadingIcon,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.48),
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(leadingIcon, color: AppTheme.brandOrange),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.035)
          : Colors.white.withValues(alpha: 0.72),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.13),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.13),
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppTheme.brandOrange, width: 1.5),
      ),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = context.rs;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF050B12) : const Color(0xFFFFFCF8),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF07131F), Color(0xFF03070C)]
                : const [Color(0xFFFFFCF8), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(r(24), r(12), r(24), r(28)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: theme.colorScheme.onSurface,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    SizedBox(width: r(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Change Password',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                              ),
                              SizedBox(width: r(10)),
                              const Icon(
                                Icons.verified_user_outlined,
                                color: AppTheme.brandOrange,
                                size: 22,
                              ),
                            ],
                          ),
                          SizedBox(height: r(6)),
                          Text(
                            'Keep your account safe',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.58,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r(54)),
                Center(child: _securityHero(context)),
                SizedBox(height: r(38)),
                _passwordCard(context),
                SizedBox(height: r(38)),
                _submitButton(context),
                SizedBox(height: r(34)),
                _securityTip(context),
                SizedBox(height: r(80)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = context.rs;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r(20)),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.055) : Colors.white,
        borderRadius: BorderRadius.circular(r(24)),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 30,
            offset: const Offset(0, 16),
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _passwordLabel(context, 'Current Password'),
          SizedBox(height: r(12)),
          TextField(
            controller: _currentController,
            obscureText: !_showCurrent,
            decoration: _decoration(
              context,
              'Enter your current password',
              leadingIcon: Icons.lock_outline_rounded,
              visible: _showCurrent,
              onToggle: () => setState(() => _showCurrent = !_showCurrent),
            ),
          ),
          SizedBox(height: r(26)),
          _passwordLabel(context, 'New Password'),
          SizedBox(height: r(12)),
          TextField(
            controller: _newController,
            obscureText: !_showNew,
            decoration: _decoration(
              context,
              'Enter your new password',
              leadingIcon: Icons.key_rounded,
              visible: _showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
            ),
          ),
          SizedBox(height: r(10)),
          Padding(
            padding: EdgeInsets.only(left: r(6)),
            child: Text(
              'Use at least 8 characters with a mix of letters,\nnumbers & symbols',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
                height: 1.45,
              ),
            ),
          ),
          SizedBox(height: r(28)),
          _passwordLabel(context, 'Confirm New Password'),
          SizedBox(height: r(12)),
          TextField(
            controller: _confirmController,
            obscureText: !_showConfirm,
            decoration: _decoration(
              context,
              'Confirm your new password',
              leadingIcon: Icons.verified_user_outlined,
              visible: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    );
  }

  Widget _submitButton(BuildContext context) {
    final r = context.rs;

    return SizedBox(
      width: double.infinity,
      height: r(58),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r(28)),
          gradient: const LinearGradient(
            colors: [AppTheme.brandOrange, AppTheme.brandOrangeLight],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.brandOrange.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(r(28)),
            onTap: _loading ? null : _submit,
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.white,
                        ),
                        SizedBox(width: r(14)),
                        const Text(
                          'Update Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _securityHero(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = context.rs;

    return SizedBox(
      height: r(190),
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: r(40),
            top: r(42),
            child: Icon(
              Icons.cloud_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              size: r(46),
            ),
          ),
          Positioned(
            right: r(24),
            top: r(44),
            child: Icon(
              Icons.cloud_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              size: r(52),
            ),
          ),
          for (final offset in const [
            Offset(-86, -36),
            Offset(-116, 8),
            Offset(98, -28),
            Offset(118, 18),
          ])
            Transform.translate(
              offset: Offset(r(offset.dx), r(offset.dy)),
              child: Container(
                width: r(8),
                height: r(8),
                decoration: BoxDecoration(
                  color: AppTheme.brandOrange.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Container(
            width: r(128),
            height: r(148),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        AppTheme.brandOrangeLight.withValues(alpha: 0.95),
                        AppTheme.brandOrange.withValues(alpha: 0.35),
                      ]
                    : [
                        AppTheme.brandOrangeLight.withValues(alpha: 0.34),
                        AppTheme.brandOrange.withValues(alpha: 0.08),
                      ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(r(52)),
                topRight: Radius.circular(r(52)),
                bottomLeft: Radius.circular(r(38)),
                bottomRight: Radius.circular(r(38)),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandOrange.withValues(
                    alpha: isDark ? 0.28 : 0.10,
                  ),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: r(68),
                height: r(68),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppTheme.brandOrangeLight,
                      AppTheme.brandOrange,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(r(18)),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: r(36),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityTip(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = context.rs;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r(20)),
      decoration: BoxDecoration(
        color: AppTheme.brandOrange.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(r(20)),
        border: Border.all(
          color: AppTheme.brandOrange.withValues(alpha: isDark ? 0.35 : 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: AppTheme.brandOrange,
            size: r(36),
          ),
          SizedBox(width: r(18)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Tip',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: r(8)),
                Text(
                  "Choose a strong password that you haven't used before.",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
