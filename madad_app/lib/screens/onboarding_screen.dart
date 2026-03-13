import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'welcome_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'title': 'No Food Waste !',
      'description':
          'One Third Of All Food Produced Is Lost Or Wasted Around 1.3 Billion Tonnes Of Food.',
      'image': 'assets/images/onboarding1.png',
    },
    {
      'title': 'Just One Tap .',
      'description': 'Save Food. Help Neighbors. One Click Away.',
      'image': 'assets/images/onboarding2.png',
    },
    {
      'title': 'We Are In Together.',
      'description': 'We Can Be The Ones Who Ends Hunger.',
      'image': 'assets/images/onboarding3.png',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  void _goToPrev() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          // ── FULL SCREEN PAGE VIEW
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) =>
                setState(() => _currentPage = index),
            itemBuilder: (_, index) =>
                _buildSlide(_slides[index]),
          ),

          // ── BOTTOM BAR (dots + buttons)
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                // Previous
                GestureDetector(
                  onTap: _goToPrev,
                  child: Text(
                    'Previous',
                    style: TextStyle(
                      color: _currentPage == 0
                          ? Colors.transparent
                          : kWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Dots
                Row(
                  children: List.generate(
                    _slides.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? kWhite
                            : kWhite.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                // Next / Get Started
                GestureDetector(
                  onTap: _goToNext,
                  child: Text(
                    _currentPage == _slides.length - 1
                        ? 'Start'
                        : 'Next',
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(Map<String, String> slide) {
    return Stack(
      children: [

        // ── FULL SCREEN IMAGE
        Positioned.fill(
          child: Image.asset(
            slide['image']!,
            fit: BoxFit.cover,
          ),
        ),

        // ── TEAL GRADIENT OVERLAY (bottom half)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  kTeal.withValues(alpha: 0.85),
                ],
                stops: const [0.4, 1.0],
              ),
            ),
          ),
        ),

        // ── TEXT at bottom left
        Positioned(
          bottom: 100,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slide['title']!,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: kWhite,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                slide['description']!,
                style: const TextStyle(
                  fontSize: 14,
                  color: kWhite,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}