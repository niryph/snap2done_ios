import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'pages/review_todo_list_page.dart'; // Add this import
import 'dart:io';
import 'utils/app_lifecycle_observer.dart';
import 'dart:developer' as developer;
import 'services/vision_service.dart'; // Import the real vision service
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'utils/background_patterns.dart'; // Add this import
import 'package:provider/provider.dart' as provider_pkg;
import 'utils/theme_provider.dart'; // Add this import

class ImageCapturePage extends StatefulWidget {
  final Function(Map<String, dynamic>)? onCardCreated;

  const ImageCapturePage({
    super.key,
    this.onCardCreated,
  });

  @override
  State<ImageCapturePage> createState() => _ImageCapturePageState();
}

class _ImageCapturePageState extends State<ImageCapturePage> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  int _selectedIndex = 0;
  final TextEditingController _textController = TextEditingController();
  late AppLifecycleObserver _lifecycleObserver;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';

  // Background widget with programmatically generated pattern
  Widget get backgroundWidget {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    return Container(
      color: themeProvider.isDarkMode ? Color(0xFF1E1E2E) : Colors.transparent,
      child: themeProvider.isDarkMode
          ? BackgroundPatterns.darkThemeBackground()
          : BackgroundPatterns.lightThemeBackground(),
    );
  }

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = AppLifecycleObserver(
      onPause: () {
        if (_controller != null && _controller!.value.isInitialized) {
          _controller!.dispose();
        }
      },
      onResume: () {
        if (_controller == null || !_controller!.value.isInitialized) {
          _initializeCamera();
        }
      },
    );
    _lifecycleObserver.register();
    _initializeCamera();
    _speech = stt.SpeechToText();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras!.isEmpty) return;
      
      _controller = CameraController(cameras![0], ResolutionPreset.high);
      await _controller!.initialize();
      
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      developer.log('Error initializing camera: $e', name: 'Camera');
    }
  }

  Future<void> _captureImage() async {
    if (!_isCameraInitialized || _isCapturing) return;
    
    setState(() {
      _isCapturing = true;
    });
    
    try {
      developer.log('Capturing image from camera', name: 'Camera');
      final image = await _controller!.takePicture();
      developer.log('Image captured: ${image.path}', name: 'Camera');
      
      // Process the image with Vision API and go to review page
      _processImageWithVisionAPI(image.path);
      
      setState(() {
        _isCapturing = false;
      });
    } catch (e) {
      developer.log('Error capturing image: $e', name: 'Camera');
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<void> _pickImage() async {
    developer.log('Picking image from gallery', name: 'ImagePicker');
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      developer.log('Image picked: ${image.path}', name: 'ImagePicker');
      
      // Process the image with Vision API and go to review page
      _processImageWithVisionAPI(image.path);
    } else {
      developer.log('No image selected', name: 'ImagePicker');
    }
  }

  // New method to process image with Vision API and navigate to review page
  Future<void> _processImageWithVisionAPI(String imagePath) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      );
      
      // Process the image with Vision API
      final String ocrText = await VisionService.performOCR(imagePath);
      
      // Close loading indicator
      Navigator.pop(context);
      
      // Navigate to review page with OCR text
      _navigateToReviewPage(ocrText);
    } catch (e) {
      // Close loading indicator if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
    }
  }

  void _generateListFromText() {
    if (_textController.text.isNotEmpty) {
      developer.log('Generating list from direct text input', name: 'TextInput');
      developer.log('Text length: ${_textController.text.length} characters', name: 'TextInput');
      
      // Skip Vision API and go directly to OpenAI
      developer.log('Sending text directly to OpenAI (skipping Vision API)', name: 'TextInput');
      _navigateToReviewPage(_textController.text);
    } else {
      developer.log('Text input is empty', name: 'TextInput');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter some text first')),
      );
    }
  }

  void _navigateToReviewPage(String text, {Map<String, dynamic>? initialResult}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewTodoListPage(
          ocrText: text,
          initialResult: initialResult ?? {},
          onSaveCard: widget.onCardCreated ?? (_) {},
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_selectedIndex) {
      case 0: // Home - no view needed as it navigates away
        return Container(); // Empty container as this case should never be shown
      case 1: // Camera (Snap)
        return _buildCameraPreview();
      case 2: // Upload
        return _buildUploadView();
      case 3: // Text Entry
        return _buildTextEntryView();
      case 4: // Dictate
        return _buildDictateView();
      default:
        return _buildCameraPreview();
    }
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    
    // Get the screen size
    final size = MediaQuery.of(context).size;
    
    return Container(
      width: size.width,
      height: size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview that fills the screen
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
          // Red circle capture button
          Positioned(
            bottom: 30,
            right: 30,
            child: GestureDetector(
              onTap: _captureImage,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadView() {    
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Center(      
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF282A40) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file, size: 64, color: isDarkMode ? Colors.white70 : null),
              SizedBox(height: 16),
              Text(
                'Choose an image from your gallery',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextEntryView() {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Text area - taking most of the space
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: isDarkMode ? Color(0xFF282A40) : Colors.white,
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.all(16),
                    hintText: 'Type or paste your text here...',
                    hintStyle: TextStyle(color: isDarkMode ? Colors.grey[500] : Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Action button
            Container(
              height: 50,
              child: ElevatedButton(
                onPressed: _generateListFromText,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Generate List',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDictateView() {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 16),
          Text(
            _isListening ? 'Tap to stop Voice Input' : 'Tap to start Voice Input',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _toggleDictation,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isListening ? Colors.red : Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: CircleBorder(),
            ),
            child: Icon(_isListening ? Icons.stop : Icons.mic, size: 48),
          ),
          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Text(
                'Listening... $_text',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
  
  void _toggleDictation() {
    if (_isListening) {
      _stopDictation();
    } else {
      _startDictation();
    }
  }
  
  void _stopDictation() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      );
      
      // Mock processing delay (Replace with actual API call in production)
      await Future.delayed(Duration(seconds: 2));
      
      // Close loading indicator
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Navigate to review page with the captured text
      if (_text.isNotEmpty) {
        _navigateToReviewPage(_text);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No speech detected. Please try again.')),
        );
      }
    }
  }
  
  void _startDictation() async {
    // Check if the platform is supported (iOS, Android, Web)
    bool isPlatformSupported = Platform.isIOS || Platform.isAndroid || kIsWeb;
    
    if (!isPlatformSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Speech recognition is not supported on this platform.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      bool available = await _speech.initialize(
        onStatus: (val) => developer.log('onStatus: $val', name: 'Dictation'),
        onError: (val) => developer.log('onError: $val', name: 'Dictation'),
      );
      
      if (available) {
        setState(() {
          _isListening = true;
          _text = '';
        });
        
        _speech.listen(
          onResult: (val) {
            setState(() {
              _text = val.recognizedWords;
            });
          },
        );
      } else {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speech recognition unavailable')),
        );
      }
    } catch (e) {
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing speech recognition: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Stack(
      children: [
        // Make sure the background covers the entire screen
        Positioned.fill(child: backgroundWidget),
        
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          body: SafeArea(
            child: _buildCurrentView(),
          ),
          bottomNavigationBar: Theme(
            data: Theme.of(context).copyWith(
              canvasColor: isDarkMode ? DarkThemeColors.cardColor : Colors.white,
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                if (index == 0) {
                  // Home icon - navigate back to home
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else {
                  setState(() => _selectedIndex = index);
                }
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Color(0xFF6C5CE7),
              unselectedItemColor: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.camera_alt),
                  label: 'Snap',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.upload),
                  label: 'Upload',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.text_fields),
                  label: 'Text',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.mic),
                  label: 'Voice',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _textController.dispose();
    
    // Stop speech recognition if it's active
    if (_isListening) {
      _speech.stop();
    }
    
    if (_controller != null) {
      _controller!.dispose();
    }
    super.dispose();
  }
}