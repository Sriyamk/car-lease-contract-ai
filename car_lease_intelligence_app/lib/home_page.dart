import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:dotted_border/dotted_border.dart';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
// REMOVED: void HomeScreen() and class CarLeaseApp
// This file now only exports HomeScreen widget

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showNavbar = true;
  double _lastScrollOffset = 0;

  bool isLoading = false;
  String? errorMessage;
  Map<String, dynamic>? results;
  String? selectedFileName;

  final TextEditingController vinController = TextEditingController();
  String? vinError;
  Map<String, dynamic>? vinResult;
  bool isVinLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final currentOffset = _scrollController.offset;
    
    if (currentOffset > 60) {
      if (currentOffset > _lastScrollOffset) {
        // Scrolling down
        if (_showNavbar) {
          setState(() => _showNavbar = false);
        }
      } else {
        // Scrolling up
        if (!_showNavbar) {
          setState(() => _showNavbar = true);
        }
      }
    }
    
    _lastScrollOffset = currentOffset;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    vinController.dispose();
    super.dispose();
  }

Future<void> _pickFile() async {
  // Pick PDF file with bytes available (works on web)
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    withData: true,
  );

  if (result != null && result.files.first.bytes != null) {
    setState(() {
      selectedFileName = result.files.first.name;
      isLoading = true;
      errorMessage = null;
      results = null;
    });

    await _uploadFile(result.files.first.bytes!, result.files.first.name);
  } else {
    setState(() {
      errorMessage = "No file selected or file data is empty.";
    });
  }
}

Future<void> _uploadFile(Uint8List bytes, String filename) async {
  try {
    var uri = Uri.parse('http://127.0.0.1:8000/lease/extract');
    var request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file', // must match backend field name
        bytes,
        filename: filename,
      ),
    );

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        results = data['lease_details']; // OCR + LLM results
        isLoading = false;
        errorMessage = null;
      });
    } else {
      final data = json.decode(response.body);
      throw Exception(data['detail'] ?? 'Failed to process PDF');
    }
  } catch (e) {
    setState(() {
      errorMessage = e.toString();
      isLoading = false;
    });
  }
}

Future<void> _lookupVIN() async {
  final vin = vinController.text.trim();

  if (vin.length != 17) {
    setState(() {
      vinError = 'VIN must be 17 characters';
      vinResult = null;
    });
    return;
  }

  setState(() {
    vinError = null;
    isVinLoading = true;
    vinResult = null;
  });

  try {
    final response = await http.get(
      Uri.parse('http://localhost:8000/vin/lookup/$vin'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        vinResult = data;
        isVinLoading = false;
      });
    } else {
      final data = json.decode(response.body);
      setState(() {
        vinError = data['detail'] ?? 'VIN lookup failed';
        isVinLoading = false;
      });
    }
  } catch (e) {
    setState(() {
      vinError = e.toString();
      isVinLoading = false;
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              Color(0xFF000000),
              Color(0xFF200B18),
              Color(0xFF765767),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Main Content
            RawScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 10,
              radius: const Radius.circular(10),
              thumbColor: const Color.fromARGB(255, 55, 29, 45),
              child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  const SizedBox(height: 100), // Space for navbar
                  
                  // Header
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: _HeaderSection(),
                  ),

                  // Main Card
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5B3D7),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 80,
                              spreadRadius: 30,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Upload Section
                            _UploadSection(
                              selectedFileName: selectedFileName,
                              onTap: _pickFile,
                            ),

                            // ========== VIN LOOKUP SECTION - NEW ==========
                            const SizedBox(height: 40),
                            _VINLookupSection(
                              vinController: vinController,
                              onLookup: _lookupVIN,
                              isLoading: isVinLoading,
                              error: vinError,
                              result: vinResult,
                            ),
                            // =============================================

                            // Loader
                            if (isLoading) ...[
                              const SizedBox(height: 30),
                              const _LoaderWidget(),
                            ],

                            // Error
                            if (errorMessage != null) ...[
                              const SizedBox(height: 20),
                              _ErrorWidget(message: errorMessage!),
                            ],

                            // Results
                            if (results != null) ...[
                              const SizedBox(height: 40),
                              _ResultsSection(results: results!),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
            ),

            // Animated Navbar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeInOut,
              top: _showNavbar ? 0 : -80,
              left: 0,
              right: 0,
              child: const _NavBar(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// VIN LOOKUP SECTION - NEW WIDGET
// ============================================================================

class _VINLookupSection extends StatelessWidget {
  final TextEditingController vinController;
  final VoidCallback onLookup;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? result;

  const _VINLookupSection({
    required this.vinController,
    required this.onLookup,
    required this.isLoading,
    this.error,
    this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VIN Lookup',
          style: TextStyle(
            color: Color(0xFFFB1597),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        
        // Input Row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: vinController,
                maxLength: 17,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Enter 17-character VIN',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.white,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFB1597), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _VINAnalyseButton(
              onTap: onLookup,
              isLoading: isLoading,
            ),
          ],
        ),
        
        // Error Message
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: const TextStyle(
              color: Color(0xFFFF6B93),
              fontSize: 14,
            ),
          ),
        ],
        
        // Loading Indicator
        if (isLoading) ...[
          const SizedBox(height: 12),
          const Text(
            'Fetching VIN details...',
            style: TextStyle(
              color: Color(0xFF170912),
              fontSize: 14,
            ),
          ),
        ],
        
        // VIN Result
        if (result != null && !isLoading) ...[
          const SizedBox(height: 12),
          _VINResultCard(result: result!),
        ],
      ],
    );
  }
}

class _VINAnalyseButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const _VINAnalyseButton({
    required this.onTap,
    required this.isLoading,
  });

  @override
  State<_VINAnalyseButton> createState() => _VINAnalyseButtonState();
}

class _VINAnalyseButtonState extends State<_VINAnalyseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFB1597), Color(0xFFFD86C8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFFFB1597).withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.isLoading ? 'Loading...' : 'Analyse VIN',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _VINResultCard extends StatelessWidget {
  final Map<String, dynamic> result;

  const _VINResultCard({required this.result});

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C0B14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Details',
            style: TextStyle(
              color: Color(0xFFFB1597),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          // VIN
          if (result['vin'] != null)
            _VINDataRow(
              label: 'VIN',
              value: result['vin'].toString(),
            ),
          
          // Status
          if (result['status'] != null)
            _VINDataRow(
              label: 'Status',
              value: result['status'].toString(),
            ),
          
          // Vehicle Details
          if (result['vehicle_details'] != null &&
              result['vehicle_details'] is Map<String, dynamic>) ...[
            const SizedBox(height: 8),
            const Text(
              'Vehicle Info',
              style: TextStyle(
                color: Color(0xFFFB1597),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...(result['vehicle_details'] as Map<String, dynamic>)
                .entries
                .map((entry) => _VINDataRow(
                      label: _formatKey(entry.key),
                      value: entry.value.toString(),
                    ))
                .toList(),
          ],
        ],
      ),
    );
  }
}

class _VINDataRow extends StatelessWidget {
  final String label;
  final String value;

  const _VINDataRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFB1597),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// NAVBAR
// ============================================================================

class _NavBar extends StatelessWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0.0, 0.2),
          radius: 10,
          colors: [
            Color.fromARGB(255, 104, 5, 61),
            Color(0xFF230317),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    _NavItem(text: 'About Us'),
                    SizedBox(width: 24),
                    _NavItem(text: 'Analyse', isActive: true),
                    SizedBox(width: 24),
                    _NavItem(text: 'Blogs'),
                  ],
                ),
                Row(
                  children: const [
                    _NavItem(text: 'Contact Us'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String text;
  final bool isActive;

  const _NavItem({
    required this.text,
    this.isActive = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // Navigation logic
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            gradient: widget.isActive
                ? const LinearGradient(
                    colors: [Color(0xFFFD86C8), Color(0xFFFB1597)],
                  )
                : null,
            color: _isHovered && !widget.isActive
                ? Colors.white.withOpacity(0.08)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              color: widget.isActive ? const Color(0xFF021F1A) : const Color(0xFFD4FFF7),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HEADER SECTION
// ============================================================================

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _GradientText(
          'Car Lease Intelligence',
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF546A9),
              Color(0xFF940958),
            ],
          ),
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 50),
        SelectableText(
          'AI-powered car lease contract analysis',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


class _GradientText extends StatelessWidget {
  final String text;
  final Gradient gradient;
  final TextStyle style;

  const _GradientText(
    this.text, {
    required this.gradient,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}

// ============================================================================
// UPLOAD SECTION
// ============================================================================

class _UploadSection extends StatefulWidget {
  final String? selectedFileName;
  final VoidCallback onTap;

  const _UploadSection({
    this.selectedFileName,
    required this.onTap,
  });

  @override
  State<_UploadSection> createState() => _UploadSectionState();
}

class _UploadSectionState extends State<_UploadSection> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedSlide(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeOut,
  offset: _isHovered ? const Offset(0, -0.01) : Offset.zero,
  child: CustomPaint(
    painter: _DashedBorderPainter(
      color: const Color(0xFFFFC2E1),
      radius: 14,
      strokeWidth: 2.3,
      dashWidth: 4,
      dashGap: 2,
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
      decoration: BoxDecoration(
        color: _isHovered
            ? const Color(0xFFFDCBE6)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text(
            'Upload Lease PDF',
            style: TextStyle(
              color: Color(0xFFFB1597),
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.selectedFileName ?? 'Drag & drop or click to select',
            style: const TextStyle(
              color: Color(0xFF170912),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 50),
          _GradientButton(
            text: 'Select File',
            onTap: widget.onTap,
          ),
        ],
      ),
    ),
  ),
),

      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool isDisabled;

  const _GradientButton({
    required this.text,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.isDisabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isDisabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _isHovered ? -1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFB1597), Color(0xFFFD86C8)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFFFB1597).withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Opacity(
            opacity: widget.isDisabled ? 0.6 : 1.0,
            child: Text(
              widget.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}



// ============================================================================
// LOADER WIDGET
// ============================================================================

class _LoaderWidget extends StatelessWidget {
  const _LoaderWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB1597)),
            backgroundColor: Color(0xFF000000),
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Analyzing contract with AI…',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ERROR WIDGET
// ============================================================================

class _ErrorWidget extends StatelessWidget {
  final String message;

  const _ErrorWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3F1D2B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFFDA4D6),
          fontSize: 14,
        ),
      ),
    );
  }
}

// ============================================================================
// RESULTS SECTION
// ============================================================================

class _ResultsSection extends StatelessWidget {
  final Map<String, dynamic> results;

  const _ResultsSection({required this.results});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: results.entries.map((section) {
        return _SectionCard(
          title: section.key,
          data: section.value,
        );
      }).toList(),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final dynamic data;

  const _SectionCard({
    required this.title,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF23101A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFF1D9D),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 15),
          if (data is Map<String, dynamic>) ..._buildRows(data),
        ],
      ),
    );
  }

  List<Widget> _buildRows(Map<String, dynamic> data) {
    final widgets = <Widget>[];
    
    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        // Nested section
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key,
                  style: const TextStyle(
                    color: Color(0xFFFF1D9D),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ..._buildRows(value),
              ],
            ),
          ),
        );
      } else {
        widgets.add(_DataRow(label: key, value: value.toString()));
      }
    });
    
    return widgets;
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 280,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFF1D9D),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}





class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final segmentLength = dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, distance + segmentLength),
          paint,
        );
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}