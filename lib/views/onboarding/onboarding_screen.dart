import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = const [
    _OnboardingPage(
      icon: Icons.volunteer_activism_rounded,
      title: 'Give blood.\nGive someone time.',
      detail:
          'A single donation can make a life-changing difference for a family in need.',
      color: Color(0xFFFFE8E8),
    ),
    _OnboardingPage(
      icon: Icons.location_on_rounded,
      title: 'Find help\nclose to home.',
      detail:
          'Discover eligible donors nearby and connect with your community when every minute matters.',
      color: Color(0xFFE6F4F1),
    ),
    _OnboardingPage(
      icon: Icons.notifications_active_rounded,
      title: 'Be there\nwhen it matters.',
      detail:
          'Post a request, respond to patients, and follow every update in one trusted place.',
      color: Color(0xFFFFF1D9),
    ),
  ];
  final _controller = PageController();
  int _index = 0;

  Future<void> _finish() async {
    await StorageService.instance.completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastPage = _index == _pages.length - 1;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: lastPage
                  ? const SizedBox(height: 48)
                  : TextButton(onPressed: _finish, child: const Text('Skip')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 230,
                          height: 230,
                          decoration: BoxDecoration(
                            color: page.color,
                            borderRadius: BorderRadius.circular(72),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(page.icon,
                                  size: 100, color: AppColors.primary),
                              const Positioned(
                                right: 28,
                                bottom: 24,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(Icons.favorite_rounded,
                                        color: AppColors.primary, size: 22),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 44),
                        Text(page.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  height: 1.12,
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                )),
                        const SizedBox(height: 16),
                        Text(page.detail,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      height: 1.55,
                                      color: colors.onSurfaceVariant,
                                    )),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _index == index ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _index == index
                        ? colors.primary
                        : colors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: lastPage
                      ? _finish
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          ),
                  child: Text(lastPage ? 'Get started' : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;
}
