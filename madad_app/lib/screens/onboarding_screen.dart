import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'register_screen.dart'; // we will create this next

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  
  // Controls the sliding between pages
  final PageController _pageController = PageController();
  int _currentPage = 0; // tracks which page we are on

  // Your 3 onboarding slides data
  final List<Map<String, String>> _slides = [
    {
      'title': 'No Food Waste !',
      'description':
          'One Third Of All Food Produced Is Wasted. Together, We Can Change That.',
      'image': 'assets/images/onboarding1.png', // add your image later
    },
    {
      'title': 'We Are In Together',
      'description':
          'We Can Do This Together With Our Community. Join Us Today.',
      'image': 'assets/images/onboarding2.png',
    },
    {
      'title': 'Just One Tap',
      'description':
          'Save Food Near You, One Click Away.',
      'image': 'assets/images/onboarding3.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      body: SafeArea(
        child: Column(
          children: [

            // ── SKIP button (top right)
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _goToRegister,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: kSage, fontSize: 14),
                ),
              ),
            ),

            // ── SLIDES (takes most of the screen)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _buildSlide(_slides[index]);
                },
              ),
            ),

            // ── DOTS indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => _buildDot(index),
              ),
            ),

            const SizedBox(height: 30),

            // ── NEXT / GET STARTED button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,  // full width
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerra,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    if (_currentPage < _slides.length - 1) {
                      // go to next slide
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      // last slide → go to register
                      _goToRegister();
                    }
                  },
                  child: Text(
                    _currentPage < _slides.length - 1 ? 'Next' : 'Get Started',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kWhite,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ── BUILD each slide
  Widget _buildSlide(Map<String, String> slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image placeholder (replace with your real image)
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: kSage.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Icon(Icons.eco, size: 100, color: kTeal),
            ),
            // Later replace with:
            // Image.asset(slide['image']!, fit: BoxFit.cover)
          ),
          const SizedBox(height: 32),
          Text(
            slide['title']!,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: kTeal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide['description']!,
            style: const TextStyle(
              fontSize: 14,
              color: kSage,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── BUILD dot indicator
  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 24 : 8,  // active dot is wider
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? kTerra : kSage,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // ── NAVIGATE to register screen
  void _goToRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }
}