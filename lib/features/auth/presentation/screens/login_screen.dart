import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../controllers/login_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref.read(loginControllerProvider.notifier).submit(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    if (ok && mounted) widget.onSuccess();
  }

  void _clearErrorOnEdit() =>
      ref.read(loginControllerProvider.notifier).clearError();

  Future<void> _openSupport() async {
    final uri = Uri.parse('mailto:support@megaboss.ma');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = AppStrings.of(locale.languageCode);
    final loginState = ref.watch(loginControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = s.isRtl;

    ref.listen<LoginState>(loginControllerProvider, (_, next) {
      if (next.status == LoginStatus.error || next.isCooldown) {
        // dismiss keyboard on error so error box is visible
        FocusScope.of(context).unfocus();
      }
    });

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: isDark ? mbDarkBg : mbSurface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: MbSpacing.lg,
                vertical: MbSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── A · Language selector ─────────────────────────
                      _LanguageSelector(current: locale.languageCode),
                      const SizedBox(height: MbSpacing.xl),

                      // ── B · Logo ──────────────────────────────────────
                      Center(
                        child: Image.asset(
                          isDark
                              ? 'assets/images/logo_white.png'
                              : 'assets/images/logo_color.png',
                          width: 180,
                          fit: BoxFit.contain,
                          semanticLabel: 'MegaBoss',
                        ),
                      ),
                      const SizedBox(height: MbSpacing.xl),

                      // ── C · Title + subtitle ──────────────────────────
                      Text(
                        s.authTitle,
                        style: MbTypography.h1(
                          isDark ? Colors.white : mbInk,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MbSpacing.xs),
                      Text(
                        s.authSubtitle,
                        style: MbTypography.sub(
                          isDark ? mbInk3 : mbInk2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MbSpacing.xl2),

                      // ── D · Email field ───────────────────────────────
                      _EmailField(
                        controller: _emailCtrl,
                        focusNode: _emailFocus,
                        nextFocus: _passwordFocus,
                        strings: s,
                        onChanged: (_) => _clearErrorOnEdit(),
                      ),
                      const SizedBox(height: MbSpacing.md),

                      // ── E · Password field ────────────────────────────
                      _PasswordField(
                        controller: _passwordCtrl,
                        focusNode: _passwordFocus,
                        obscure: _obscurePassword,
                        strings: s,
                        onToggleObscure: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        onChanged: (_) => _clearErrorOnEdit(),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: MbSpacing.md),

                      // ── F · Error / cooldown banner ───────────────────
                      _AnimatedErrorBox(
                        loginState: loginState,
                        strings: s,
                        isDark: isDark,
                      ),

                      // ── G · Submit button ─────────────────────────────
                      _SubmitButton(
                        loginState: loginState,
                        strings: s,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: MbSpacing.lg),

                      // ── H · Support link ──────────────────────────────
                      GestureDetector(
                        onTap: _openSupport,
                        child: Text(
                          s.authSupport,
                          style: MbTypography.sub(mbBlue).copyWith(
                            decoration: TextDecoration.underline,
                            decorationColor: mbBlue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: MbSpacing.xl2),

                      // ── I · Version footer ────────────────────────────
                      _VersionFooter(strings: s),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── A · Language selector ──────────────────────────────────────────────────────

class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector({required this.current});
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(localeProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LangChip(
          label: AppStrings.langFr,
          selected: current == 'fr',
          onTap: () => notifier.setLocale('fr'),
        ),
        const SizedBox(width: MbSpacing.xs),
        _LangChip(
          label: AppStrings.langAr,
          selected: current == 'ar',
          onTap: () => notifier.setLocale('ar'),
        ),
        const SizedBox(width: MbSpacing.xs),
        _LangChip(
          label: AppStrings.langEn,
          selected: current == 'en',
          onTap: () => notifier.setLocale('en'),
        ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: MbSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected
              ? mbBlue
              : isDark
                  ? mbDarkSurface
                  : mbSurface2,
          borderRadius: BorderRadius.circular(MbRadius.chip),
          border: Border.all(
            color: selected ? mbBlue : (isDark ? mbLine2 : mbLine),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: MbTypography.cap(
            selected ? Colors.white : (isDark ? mbInk3 : mbInk2),
          ),
        ),
      ),
    );
  }
}

// ── D · Email field ────────────────────────────────────────────────────────────

class _EmailField extends StatelessWidget {
  const _EmailField({
    required this.controller,
    required this.focusNode,
    required this.nextFocus,
    required this.strings,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode nextFocus;
  final AppStrings strings;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: onChanged,
      onFieldSubmitted: (_) => nextFocus.requestFocus(),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return strings.authEmailInvalid;
        final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
        if (!emailRe.hasMatch(v.trim())) return strings.authEmailInvalid;
        return null;
      },
      decoration: InputDecoration(
        labelText: strings.authEmailLabel,
        hintText: strings.authEmailHint,
      ),
    );
  }
}

// ── E · Password field ─────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.obscure,
    required this.strings,
    required this.onToggleObscure,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscure;
  final AppStrings strings;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: (v) {
        if (v == null || v.isEmpty) return strings.authPasswordRequired;
        return null;
      },
      decoration: InputDecoration(
        labelText: strings.authPasswordLabel,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
          ),
          tooltip: obscure ? strings.showPassword : strings.hidePassword,
          onPressed: onToggleObscure,
        ),
      ),
    );
  }
}

// ── F · Animated error / cooldown banner ──────────────────────────────────────

class _AnimatedErrorBox extends StatelessWidget {
  const _AnimatedErrorBox({
    required this.loginState,
    required this.strings,
    required this.isDark,
  });

  final LoginState loginState;
  final AppStrings strings;
  final bool isDark;

  String? get _message {
    if (loginState.status == LoginStatus.cooldown) {
      return strings.authCooldown(loginState.cooldownSecondsLeft);
    }
    if (loginState.status == LoginStatus.error) {
      return switch (loginState.errorType) {
        LoginErrorType.credentials => strings.authErrCredentials,
        LoginErrorType.network => strings.authErrNetwork,
        LoginErrorType.server => strings.authErrServer,
        LoginErrorType.none => null,
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    final visible = message != null;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1.0 : 0.0,
        child: visible
            ? Container(
                margin: const EdgeInsets.only(bottom: MbSpacing.md),
                padding: const EdgeInsets.symmetric(
                  horizontal: MbSpacing.md,
                  vertical: MbSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? mbErr.withAlpha(0x33)
                      : mbErrBg,
                  borderRadius: BorderRadius.circular(MbRadius.field),
                  border: Border.all(color: mbErr.withAlpha(0x66), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      loginState.status == LoginStatus.cooldown
                          ? Icons.timer_outlined
                          : Icons.error_outline,
                      color: mbErr,
                      size: 16,
                    ),
                    const SizedBox(width: MbSpacing.xs),
                    Expanded(
                      child: Text(
                        message,
                        style: MbTypography.sub(mbErr),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

// ── G · Submit button ──────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.loginState,
    required this.strings,
    required this.onPressed,
  });

  final LoginState loginState;
  final AppStrings strings;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final canSubmit = loginState.canSubmit;

    Widget buttonChild;
    if (loginState.isLoading) {
      buttonChild = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: Colors.white,
          backgroundColor: Colors.white.withAlpha(0x44),
          strokeWidth: 2.2,
          strokeCap: StrokeCap.round,
        ),
      );
    } else if (loginState.isCooldown) {
      buttonChild = Text(
        strings.authCooldown(loginState.cooldownSecondsLeft),
        style: MbTypography.body(Colors.white).copyWith(
          fontWeight: FontWeight.w700,
        ),
      );
    } else {
      buttonChild = Text(
        strings.authLogin,
        style: MbTypography.body(Colors.white).copyWith(
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: SizedBox(
        key: ValueKey(loginState.isLoading),
        height: kMbMinTouchTarget,
        child: FilledButton(
          onPressed: canSubmit ? onPressed : null,
          child: buttonChild,
        ),
      ),
    );
  }
}

// ── I · Version footer ─────────────────────────────────────────────────────────

class _VersionFooter extends ConsumerWidget {
  const _VersionFooter({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);
    final version = versionAsync.valueOrNull ?? '1.0.0';
    return Text(
      strings.authFooter(version),
      style: MbTypography.cap(mbInk3),
      textAlign: TextAlign.center,
    );
  }
}
