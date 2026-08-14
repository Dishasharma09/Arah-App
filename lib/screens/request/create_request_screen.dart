import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../app/theme/app_theme.dart';
import '../../provider/request_provider.dart';
import '../../provider/user_provider.dart';
import 'package:country_picker/country_picker.dart';
import '../../data/categories.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final List<String> _skills = [];


  String? _selectedCategory;
  String? _selectedSubCategory;
  String? _selectedExperience;
  DateTime? _selectedDate;
  Country? _selectedCountry;
  String? _selectedDeadline;

  final List<String> _experienceLevels = [
    "Beginner",
    "Intermediate",
    "Advanced",
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _skillsCtrl.dispose();
    _notesCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  final List<String> _deadlineOptions = [
    "Tomorrow",
    "3 Days",
    "1 Week",
    "2 Weeks",
    "Custom Date",
  ];
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = "${picked.day}-${picked.month}-${picked.year}";
      });
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showError("Task title is required");
      return;
    }

    if (_selectedCategory == null) {
      _showError("Please select a category");
      return;
    }
    if (subCategoriesFor(_selectedCategory!).isNotEmpty &&
        _selectedSubCategory == null) {
      _showError("Please select a sub-category");
      return;
    }
    if (_selectedExperience == null) {
      _showError("Please select experience level");
      return;
    }
    final price = double.tryParse(_priceCtrl.text);

    if (price == null || price <= 0) {
      _showError("Enter a valid price");
      return;
    }
    if (_selectedDeadline == null) {
      _showError("Please select a deadline");
      return;
    }

    if (_selectedDeadline == "Custom Date" && _selectedDate == null) {
      _showError("Please select a custom date");
      return;
    }

    final userProvider = context.read<UserProvider>();
    final requestProvider = context.read<RequestProvider>();

    final tags = List<String>.from(_skills);

    final success = await requestProvider.submitRequest(
      buyerId: userProvider.uid,
      buyerName: userProvider.name,
      title: _titleCtrl.text.trim(),
      category: _selectedCategory!,
      subCategory: _selectedSubCategory ?? '',
      experience: _selectedExperience!,
      tags: tags,
      price: _priceCtrl.text.trim(),
      deadline: _selectedDate,
      notes: _notesCtrl.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Task request posted successfully!"),
          backgroundColor: AppTheme.colorsOf(context).success,
        ),
      );
      Navigator.pop(context);
    } else {
      _showError(requestProvider.error ?? "Failed to post task request");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.colorsOf(context).error),
    );
  }

  Future<void> _pickDocument(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'zip', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );

      if (result != null) {
        context.read<RequestProvider>().addFiles(result.files);
      }
    } catch (e) {
      debugPrint("File picker error: $e");
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";

    const suffixes = ["B", "KB", "MB", "GB", "TB"];

    int i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _removeFile(BuildContext context, int index) {
    context.read<RequestProvider>().removeFile(index);
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 20.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 14,
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Theme.of(context).textTheme.bodyMedium?.color,
        fontSize: 14,
      ),
      filled: true,
      fillColor: AppTheme.colorsOf(context).searchBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestProvider = context.watch<RequestProvider>();
    final budgetType = requestProvider.budgetType;
    final attachedFiles = requestProvider.attachedFiles;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          "Create a Request",
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Task Title"),
              TextField(
                controller: _titleCtrl,
                decoration: _inputDeco(
                  "e.g. Need a Python script for data entry",
                ),
              ),

              _buildLabel("Category"),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: _inputDeco("Select category"),
                items: mainCategories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    // Reset sub-category whenever the main category changes so we
                    // never submit a sub-category that doesn't belong to it.
                    _selectedSubCategory = null;
                  });
                },
              ),

              if (_selectedCategory != null &&
                  subCategoriesFor(_selectedCategory!).isNotEmpty) ...[
                _buildLabel("Sub-category"),
                DropdownButtonFormField<String>(
                  value: _selectedSubCategory,
                  decoration: _inputDeco("Select sub-category"),
                  items: subCategoriesFor(_selectedCategory!).map((sub) {
                    return DropdownMenuItem(value: sub, child: Text(sub));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSubCategory = value;
                    });
                  },
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () {
                        showCountryPicker(
                          context: context,
                          showPhoneCode: false,
                          onSelect: (Country country) {
                            setState(() {
                              _selectedCountry = country;
                            });
                          },
                        );
                      },
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _selectedCountry?.flagEmoji ?? "🌍",
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedCountry?.name ?? "Country",
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    flex: 5,
                    child: TextField(
                      controller: _priceCtrl,
                      decoration: _inputDeco("Price"),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildLabel("Experience"),

              DropdownButtonFormField<String>(
                value: _selectedExperience,
                decoration: _inputDeco("Select..."),
                items: _experienceLevels.map((exp) {
                  return DropdownMenuItem(value: exp, child: Text(exp));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedExperience = val;
                  });
                },
              ),
              _buildLabel("Required Skills"),
              TextField(
                controller: _skillsCtrl,
                decoration: _inputDeco("Add a skill"),
              ),

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () {
                    if (_skillsCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        final skill = _skillsCtrl.text.trim();

                        if (!_skills.contains(skill)) {
                          _skills.add(skill);
                        }

                        _skillsCtrl.clear();
                      });
                    }
                  },
                  child: const Text("Add"),
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skills.map((skill) {
                  return Chip(
                    label: Text(skill),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _skills.remove(skill);
                      });
                    },
                  );
                }).toList(),
              ),
              _buildLabel("Payment Type"),

              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context
                            .read<RequestProvider>()
                            .updateBudgetType('Fixed Price'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: budgetType == 'Fixed Price'
                                ? AppTheme.colorsOf(context).chipSelectedBackground
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: budgetType == 'Fixed Price'
                                ? [
                                    BoxShadow(
                                      color: AppTheme.colorsOf(context).shadow,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Fixed Price',
                            style: TextStyle(
                              color: budgetType == 'Fixed Price'
                                  ? AppTheme.colorsOf(context).chipSelectedText
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                              fontWeight: budgetType == 'Fixed Price'
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context
                            .read<RequestProvider>()
                            .updateBudgetType('Negotiable'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: budgetType == 'Negotiable'
                                ? AppTheme.colorsOf(context).chipSelectedBackground
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: budgetType == 'Negotiable'
                                ? [
                                    BoxShadow(
                                      color: AppTheme.colorsOf(context).shadow,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Negotiable',
                            style: TextStyle(
                              color: budgetType == 'Negotiable'
                                  ? AppTheme.colorsOf(context).chipSelectedText
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                              fontWeight: budgetType == 'Negotiable'
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel("Estimated Completion Time"),

              TextField(decoration: _inputDeco("e.g. 2 days")),
              _buildLabel("Deadline"),

              DropdownButtonFormField<String>(
                value: _selectedDeadline,
                decoration: _inputDeco("Select Deadline"),
                items: _deadlineOptions.map((item) {
                  return DropdownMenuItem(value: item, child: Text(item));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDeadline = value;
                  });

                  if (value == "Custom Date") {
                    _selectDate(context);
                  }
                },
              ),

              if (_selectedDeadline == "Custom Date") ...[
                const SizedBox(height: 16),

                TextField(
                  controller: _dateCtrl,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  decoration: _inputDeco(
                    "dd-MM-yyyy",
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
              ],
              _buildLabel("Attachments"),
              GestureDetector(
                onTap: () => _pickDocument(context),
                child: CustomPaint(
                  painter: DashedRectPainter(
                    color: Theme.of(context).dividerColor,
                    strokeWidth: 1.2,
                    gap: 6.0,
                  ),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            "Upload File Attachments",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Images, PDFs, ZIP",
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (attachedFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: attachedFiles.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final file = attachedFiles[index];
                      IconData icon = Icons.insert_drive_file;
                      Color iconColor = AppTheme.colorsOf(context).secondaryText;
                      if (file.extension == 'pdf') {
                        icon = Icons.picture_as_pdf;
                        iconColor = AppTheme.colorsOf(context).error;
                      } else if ([
                        'jpg',
                        'jpeg',
                        'png',
                      ].contains(file.extension)) {
                        icon = Icons.image;
                        iconColor = AppTheme.colorsOf(context).info;
                      } else if (file.extension == 'zip') {
                        icon = Icons.folder_zip;
                        iconColor = AppTheme.colorsOf(context).warning;
                      }

                      return Container(
                        width: 200,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, color: iconColor, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    file.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatBytes(file.size),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _removeFile(context, index),
                              child: Icon(
                                Icons.close,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              _buildLabel("Additional Notes"),
              TextField(
                controller: _notesCtrl,
                maxLines: 4,
                decoration: _inputDeco("Provide any extra details here..."),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: requestProvider.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: requestProvider.isLoading
                      ? const SizedBox()
                      : const Text(
                          "Post Request",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedRectPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    var path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(12),
        ),
      );

    PathMetrics pathMetrics = path.computeMetrics();
    Path dashPath = Path();
    for (PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;
      bool draw = true;
      while (distance < pathMetric.length) {
        double length = draw ? gap : gap;
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += length;
        draw = !draw;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}