import 'package:flutter/material.dart';
import '../login/authselect.dart';
import '../onboarding_service.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const SplashScreen({Key? key, required this.onCompleted}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animationController;
  late Animation<double> _leafAnimation;

  final List<SplashPage> _pages = [
    SplashPage(
      centerImage: 'assets/images/splash1_center.png',
      title: 'Welcome to Bayangida',
      description: 'Connecting farmers, consumers, and drivers for faster deliveries.',
      buttonText: 'Next',
    ),
    SplashPage(
      centerImage: 'assets/images/splash2_center.png',
      title: 'Manage Orders Easily',
      description: 'Accept, track, and deliver farm produce in real time..',
      buttonText: 'Next',
    ),
    SplashPage(
      centerImage: 'assets/images/splash3_center.png',
      title: 'Deliver Fast, Earn More',
      description: 'Grow your business and get paid instantly after deliveries.',
      buttonText: 'Get Started',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 4),
    )..repeat(reverse: true);

    _leafAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive scaling factors
    final scaleFactorWidth = screenWidth / 375; // Base width (iPhone 11)
    final scaleFactorHeight = screenHeight / 812; // Base height (iPhone 11)

    // Function to get responsive width
    double responsiveWidth(double size) => size * scaleFactorWidth;

    // Function to get responsive height
    double responsiveHeight(double size) => size * scaleFactorHeight;

    // Function to get responsive font size
    double responsiveFont(double size) => size * scaleFactorWidth;

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Spacer(),
            InkWell(
                onTap: () async {
                  // Mark onboarding as completed when skipped
                  await PreferencesService.setOnboardingCompleted(true);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => Authselect()),
                  );
                },
                child: Padding(
                    padding: EdgeInsets.all(responsiveWidth(6)),
                    child: Text('Skip',
                      style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Cabinet Grotesk',
                          fontSize: responsiveFont(20)
                      ),
                    )
                )
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Animated leaf vectors
          AnimatedBuilder(
            animation: _leafAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  // First leaf (top right)
                  Positioned(
                    top: responsiveHeight(-200.35) + _leafAnimation.value,
                    left: responsiveWidth(30.6) + _leafAnimation.value,
                    child: Transform.rotate(
                      angle: 19.19 * (3.1415926535 / 180),
                      child: Image.asset(
                        'assets/images/leaf_vector.png',
                        width: responsiveWidth(418.01),
                        height: responsiveHeight(646.45),
                      ),
                    ),
                  ),
                  // Second leaf (bottom left) - directly under the first one in the visual hierarchy
                  Positioned(
                    top: responsiveHeight(51.85) + _leafAnimation.value * 1.5,
                    right: responsiveWidth(15.37) - _leafAnimation.value,
                    child: Transform.rotate(
                      angle: 42.2 * (3.1415926535 / 180),
                      child: Image.asset(
                        'assets/images/leaf_vector1.png',
                        width: responsiveWidth(418.01),
                        height: responsiveHeight(646.45),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Page content
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: responsiveHeight(43)),
                    // Center image
                    Container(
                      width: responsiveWidth(328),
                      height: responsiveHeight(317),
                      margin: EdgeInsets.symmetric(horizontal: responsiveWidth(33)),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(responsiveWidth(20)),
                        border: Border.all(width: 1, color: Color(0xFF9EF84A)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(responsiveWidth(20)),
                        child: Image.asset(
                          _pages[index].centerImage,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(height: responsiveHeight(10)),
                    // Title with leaf icon
                    Container(
                      width: responsiveWidth(360),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: responsiveWidth(300),
                              child: Text(
                                _pages[index].title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Cabinet Grotesk',
                                  fontSize: responsiveFont(36),
                                  color: Color(0xFF00B7F40),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: responsiveHeight(10)),
                    // Description
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: responsiveWidth(40)),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(left: responsiveWidth(25.0)),
                          child: Container(
                            width: responsiveWidth(328),
                            child: Text(
                              _pages[index].description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Cabinet Grotesk',
                                fontSize: responsiveFont(20),
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: responsiveHeight(40)),
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        return Container(
                          width: responsiveWidth(8),
                          height: responsiveWidth(8),
                          margin: EdgeInsets.symmetric(horizontal: responsiveWidth(4)),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == i ? Color(0xFF4CAF50) : Color(0xFF9EF84A)
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: responsiveHeight(80)), // Extra space for navigation buttons
                  ],
                ),
              );
            },
          ),

          // Navigation buttons
          Positioned(
            bottom: responsiveHeight(40),
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: responsiveWidth(32)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Prev button (white background)
                  if (_currentPage > 0)
                    ElevatedButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(responsiveWidth(8)),
                        ),
                        padding: EdgeInsets.symmetric(
                            horizontal: responsiveWidth(24),
                            vertical: responsiveHeight(12)
                        ),
                      ),
                      child: Text(
                        'Prev',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: responsiveFont(16),
                          color: Color(0xFF0B3D2E),
                        ),
                      ),
                    )
                  else
                    SizedBox(width: responsiveWidth(80)), // Placeholder for alignment

                  // Next/Get Started button
                  ElevatedButton(
                    onPressed: () async {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        // Mark onboarding as completed
                        await PreferencesService.setOnboardingCompleted(true);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => Authselect()),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0B7F40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(responsiveWidth(8)),
                      ),
                      padding: EdgeInsets.symmetric(
                          horizontal: responsiveWidth(32),
                          vertical: responsiveHeight(12)
                      ),
                    ),
                    child: Text(
                      _pages[_currentPage].buttonText,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: responsiveFont(16),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SplashPage {
  final String centerImage;
  final String title;
  final String description;
  final String buttonText;

  SplashPage({
    required this.centerImage,
    required this.title,
    required this.description,
    required this.buttonText,
  });
}