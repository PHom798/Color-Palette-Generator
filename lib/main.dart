import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color Palette Generator',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ColorPaletteScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ColorPaletteScreen extends StatefulWidget {
  @override
  _ColorPaletteScreenState createState() => _ColorPaletteScreenState();
}

class _ColorPaletteScreenState extends State<ColorPaletteScreen>
    with TickerProviderStateMixin {
  File? _selectedImage;
  List<Color> _extractedColors = [];
  bool _isProcessing = false;
  late AnimationController _animationController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _isProcessing = true;
          _extractedColors.clear();
        });
        await _extractColors();
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e');
    }
  }

  Future<void> _extractColors() async {
    if (_selectedImage == null) return;

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final ui.Image image = await decodeImageFromList(bytes);

      final ByteData? byteData = await image.toByteData();
      if (byteData == null) return;

      final List<Color> colors = [];
      final Uint8List pixels = byteData.buffer.asUint8List();

      // Sample colors from different regions of the image
      final int width = image.width;
      final int height = image.height;
      final int step = (pixels.length / 4 / 50).round(); // Sample ~50 colors

      Set<String> uniqueColors = {};

      for (int i = 0; i < pixels.length - 3; i += step * 4) {
        final int r = pixels[i];
        final int g = pixels[i + 1];
        final int b = pixels[i + 2];
        final int a = pixels[i + 3];

        if (a > 128) { // Only consider non-transparent pixels
          final Color color = Color.fromARGB(255, r, g, b);
          final String colorKey = '${r}_${g}_${b}';

          if (!uniqueColors.contains(colorKey)) {
            uniqueColors.add(colorKey);
            colors.add(color);
          }
        }
      }

      // Sort by brightness and take diverse colors
      colors.sort((a, b) => _getColorBrightness(b).compareTo(_getColorBrightness(a)));

      List<Color> finalColors = [];
      for (Color color in colors) {
        if (finalColors.length >= 8) break;

        bool isDifferentEnough = finalColors.every((existingColor) =>
        _getColorDistance(color, existingColor) > 30);

        if (isDifferentEnough) {
          finalColors.add(color);
        }
      }

      setState(() {
        _extractedColors = finalColors;
        _isProcessing = false;
      });

      _animationController.forward();

    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showSnackBar('Error extracting colors: $e');
    }
  }

  double _getColorBrightness(Color color) {
    return (color.red * 0.299 + color.green * 0.587 + color.blue * 0.114);
  }

  double _getColorDistance(Color color1, Color color2) {
    return ((color1.red - color2.red).abs() +
        (color1.green - color2.green).abs() +
        (color1.blue - color2.blue).abs()) /
        3.0;
  }

  void _copyColorToClipboard(Color color) {
    final String hexColor = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
    Clipboard.setData(ClipboardData(text: hexColor));
    _showSnackBar('Copied $hexColor to clipboard!');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.purple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Color Palette Generator',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.palette, size: 48, color: Colors.purple),
                    SizedBox(height: 12),
                    Text(
                      'Extract Beautiful Colors',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Pick an image and get its color palette',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Image Picker Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: Icon(Icons.camera_alt),
                    label: Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: Icon(Icons.photo_library),
                    label: Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[300],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Selected Image
            if (_selectedImage != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _selectedImage!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            if (_isProcessing)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.purple),
                    SizedBox(height: 16),
                    Text(
                      'Extracting colors...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

            // Color Palette
            if (_extractedColors.isNotEmpty && !_isProcessing) ...[
              SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Extracted Colors',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap any color to copy its hex code',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _extractedColors.length,
                        itemBuilder: (context, index) {
                          final color = _extractedColors[index];
                          final hexColor = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';

                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: _animationController,
                              curve: Interval(
                                index * 0.1,
                                (index * 0.1) + 0.3,
                                curve: Curves.easeOut,
                              ),
                            )),
                            child: FadeTransition(
                              opacity: _animationController,
                              child: GestureDetector(
                                onTap: () => _copyColorToClipboard(color),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          borderRadius: BorderRadius.only(
                                            bottomLeft: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: Text(
                                          hexColor,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}