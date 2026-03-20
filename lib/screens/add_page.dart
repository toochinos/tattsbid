import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/services/photo_service.dart';
import '../core/services/tattoo_request_service.dart';

/// Add tab: customer uploads reference photo, adds description and starting bid.
class AddPage extends StatefulWidget {
  const AddPage({super.key, this.onRequestSubmitted});

  /// Called after a request is successfully submitted (e.g. to switch to Explore).
  final VoidCallback? onRequestSubmitted;

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _placementController = TextEditingController();
  final _sizeController = TextEditingController();
  final _startingBidController = TextEditingController();

  String? _colourPreference; // 'colour' or 'black_and_grey'
  String? _timeframe; // 'asap', 'during_the_week', 'when_you_can_book_me_in'
  bool _artistCreativeFreedom = true;
  bool _uploading = false;
  bool _submitting = false;
  String? _errorMessage;
  String? _uploadedUrl;
  bool _showDetailsForm = false;
  bool _submitted = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _placementController.dispose();
    _sizeController.dispose();
    _startingBidController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.of(context).pop();
    final xFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;

    final path = xFile.path;
    if (path.isEmpty) return;

    setState(() {
      _uploading = true;
      _errorMessage = null;
      _uploadedUrl = null;
      _showDetailsForm = false;
      _submitted = false;
    });
    try {
      final url = await PhotoService.uploadPhoto(File(path));
      if (!mounted) return;
      setState(() {
        _uploadedUrl = url;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Take a photo'),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Upload from gallery'),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startOver() {
    setState(() {
      _uploadedUrl = null;
      _showDetailsForm = false;
      _submitted = false;
      _descriptionController.clear();
      _placementController.clear();
      _sizeController.clear();
      _colourPreference = null;
      _timeframe = null;
      _artistCreativeFreedom = true;
      _startingBidController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _uploadedUrl == null) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final startingBid =
          double.tryParse(_startingBidController.text.trim()) ?? 0.0;
      await TattooRequestService.createRequest(
        imageUrl: _uploadedUrl!,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        placement: _placementController.text.trim().isEmpty
            ? null
            : _placementController.text.trim(),
        size: _sizeController.text.trim().isEmpty
            ? null
            : _sizeController.text.trim(),
        colourPreference: _colourPreference,
        artistCreativeFreedom: _artistCreativeFreedom,
        timeframe: _timeframe,
        startingBid: startingBid,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
      widget.onRequestSubmitted?.call();
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = e.toString();
      });
      debugPrint('Submit request error: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_uploading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Uploading...'),
                  ],
                )
              else if (_submitted)
                _buildSuccessState(context)
              else if (_showDetailsForm && _uploadedUrl != null)
                _buildDetailsForm(context)
              else if (_uploadedUrl != null)
                _buildPhotoPreview(context)
              else
                _buildInitialState(context),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.add_a_photo,
          size: 80,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 16),
        Text(
          'Add a reference photo',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Take a photo or choose from your gallery',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _showPhotoOptions,
          icon: const Icon(Icons.add),
          label: const Text('Add photo'),
        ),
      ],
    );
  }

  Widget _buildPhotoPreview(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            _uploadedUrl!,
            width: 280,
            height: 280,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, size: 80),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Photo uploaded successfully',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Happy with this photo? Add a description and starting bid.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => setState(() => _showDetailsForm = true),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text("I'm happy — add details"),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _showPhotoOptions,
          icon: const Icon(Icons.refresh),
          label: const Text('Choose different photo'),
        ),
      ],
    );
  }

  Widget _buildDetailsForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _uploadedUrl!,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, size: 60),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'What do you want for your tattoo?',
              hintText: 'Describe your vision...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _placementController,
            decoration: const InputDecoration(
              labelText: 'Placement',
              hintText: 'Where on the body? (e.g. arm, back, leg)',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _sizeController,
            decoration: const InputDecoration(
              labelText: 'Size',
              hintText: 'Small, medium, large, or dimensions',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          Text(
            'Colour or black and grey',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Colour'),
                selected: _colourPreference == 'colour',
                onSelected: (selected) {
                  setState(
                      () => _colourPreference = selected ? 'colour' : null);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Black and grey'),
                selected: _colourPreference == 'black_and_grey',
                onSelected: (selected) {
                  setState(() =>
                      _colourPreference = selected ? 'black_and_grey' : null);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Time frame',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('ASAP'),
                selected: _timeframe == 'asap',
                onSelected: (selected) {
                  setState(() => _timeframe = selected ? 'asap' : null);
                },
              ),
              ChoiceChip(
                label: const Text('During the week'),
                selected: _timeframe == 'during_the_week',
                onSelected: (selected) {
                  setState(
                      () => _timeframe = selected ? 'during_the_week' : null);
                },
              ),
              ChoiceChip(
                label: const Text('Whenever you can book me in'),
                selected: _timeframe == 'when_you_can_book_me_in',
                onSelected: (selected) {
                  setState(() =>
                      _timeframe = selected ? 'when_you_can_book_me_in' : null);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _artistCreativeFreedom,
            onChanged: (v) =>
                setState(() => _artistCreativeFreedom = v ?? true),
            title: const Text(
              'Allow the artist to have creative freedom',
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _startingBidController,
            decoration: const InputDecoration(
              labelText: 'Starting bid (\$)',
              hintText: '0',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            validator: (v) {
              final n = double.tryParse(v?.trim() ?? '');
              if (n == null || n < 0) {
                return 'Enter a valid amount (0 or more)';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submitRequest,
            child: _submitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit request'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _submitting
                ? null
                : () => setState(() => _showDetailsForm = false),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.check_circle,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Request submitted!',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Artists can now view your request and place bids.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _startOver,
          icon: const Icon(Icons.add),
          label: const Text('Add another request'),
        ),
      ],
    );
  }
}
